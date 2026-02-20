"""
Risk Management & Governance Service
Implements comprehensive trading safety controls
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from enum import Enum
import asyncio
import os
import json
import hashlib
import secrets


class RiskLevel(Enum):
    """Risk levels for trading"""
    SAFE = "safe"
    MODERATE = "moderate"
    HIGH = "high"
    EXTREME = "extreme"


@dataclass
class RiskLimits:
    """User's risk management parameters"""
    max_trade_size: float  # Maximum position size in units
    daily_loss_limit: float  # Stop trading after this loss (-%)
    max_open_positions: int  # Maximum concurrent open trades
    max_drawdown_percent: float  # Maximum allowed drawdown (%)
    mandatory_stop_loss: bool = True
    mandatory_take_profit: bool = True
    kill_switch_enabled: bool = True


@dataclass
class TradeExecution:
    """Track individual trade execution"""
    trade_id: str
    user_id: str
    pair: str
    action: str  # BUY, SELL
    entry_price: float
    stop_loss: float
    take_profit: float
    position_size: float
    timestamp: datetime
    status: str  # "open", "closed", "pending"
    exit_price: Optional[float] = None
    profit_loss: Optional[float] = None
    reason: Optional[str] = None
    is_paper_trade: bool = False


@dataclass
class DailyTradingStats:
    """Daily statistics for a user"""
    date: str
    total_trades: int = 0
    winning_trades: int = 0
    losing_trades: int = 0
    total_profit_loss: float = 0.0
    max_drawdown: float = 0.0
    trades: List[TradeExecution] = field(default_factory=list)
    kill_switch_triggered: bool = False


@dataclass
class ProbationPolicy:
    """Entry requirements before enabling real autonomous trading."""
    min_paper_trades: int = 20
    min_win_rate_percent: float = 55.0
    max_drawdown_percent: float = 12.0
    min_active_days: int = 5


@dataclass
class RiskBudget:
    """Risk budget constraints to protect capital in autonomous mode."""
    max_risk_per_trade_percent: float = 1.0
    daily_loss_limit_percent: float = 3.0
    weekly_loss_limit_percent: float = 8.0
    max_drawdown_percent: float = 12.0


@dataclass
class AutonomyState:
    """Current autonomous governance state for a user."""
    user_id: str
    level: str = "assisted"  # manual, assisted, guarded_auto, full_auto
    probation_passed: bool = False
    paused: bool = False
    pause_reason: Optional[str] = None
    pause_until: Optional[datetime] = None
    last_probation_check: Optional[datetime] = None
    recent_consensus_scores: List[float] = field(default_factory=list)


class RiskManagementService:
    """
    Comprehensive risk management and trading safety governance system
    """
    
    def __init__(self):
        self.user_limits: Dict[str, RiskLimits] = {}
        self.daily_stats: Dict[str, DailyTradingStats] = {}
        self.active_trades: Dict[str, List[TradeExecution]] = {}
        self.kill_switch_active: Dict[str, bool] = {}
        self.prediction_accuracy: Dict[str, Dict] = {}  # Track accuracy per user
        self.probation_policy: Dict[str, ProbationPolicy] = {}
        self.risk_budgets: Dict[str, RiskBudget] = {}
        self.weekly_profit_loss: Dict[str, Dict[str, float]] = {}
        self.autonomy_state: Dict[str, AutonomyState] = {}
        self.pending_explain_tokens: Dict[str, Dict] = {}
        self.require_broker_fail_safe = (
            os.getenv("REQUIRE_BROKER_FAIL_SAFE", "true").lower() != "false"
        )
        self.require_explain_token = (
            os.getenv("REQUIRE_EXPLAIN_BEFORE_EXECUTE", "true").lower() != "false"
        )
        self.explain_token_ttl_seconds = int(
            os.getenv("EXPLAIN_TOKEN_TTL_SECONDS", "300")
        )
        allow_dev_probation = os.getenv("ALLOW_DEV_PROBATION_BYPASS")
        if allow_dev_probation is None:
            self.allow_dev_probation_bypass = os.getenv("DEBUG", "").lower() == "true"
        else:
            self.allow_dev_probation_bypass = allow_dev_probation.lower() == "true"

    def _get_or_create_probation_policy(self, user_id: str) -> ProbationPolicy:
        if user_id not in self.probation_policy:
            self.probation_policy[user_id] = ProbationPolicy()
        return self.probation_policy[user_id]

    def _get_or_create_risk_budget(self, user_id: str) -> RiskBudget:
        if user_id not in self.risk_budgets:
            self.risk_budgets[user_id] = RiskBudget()
        return self.risk_budgets[user_id]

    def _get_or_create_autonomy_state(self, user_id: str) -> AutonomyState:
        if user_id not in self.autonomy_state:
            self.autonomy_state[user_id] = AutonomyState(user_id=user_id)
        return self.autonomy_state[user_id]

    def _get_week_key(self, dt: Optional[datetime] = None) -> str:
        stamp = dt or datetime.now()
        return stamp.strftime("%Y-W%U")

    def _to_float(self, value: object, fallback: float = 0.0) -> float:
        if value is None:
            return fallback
        if isinstance(value, (int, float)):
            return float(value)
        raw = str(value).strip().replace("%", "")
        try:
            return float(raw)
        except Exception:
            return fallback

    def _normalize_trade_fingerprint_payload(self, trade_params: Dict) -> Dict:
        """Normalize trade params to a stable payload for explain-token binding."""
        keys = [
            "pair",
            "action",
            "entry_price",
            "stop_loss",
            "take_profit",
            "position_size",
            "risk_percent",
            "is_paper_trade",
        ]
        payload = {}
        for key in keys:
            if key not in trade_params:
                continue
            value = trade_params.get(key)
            if isinstance(value, float):
                payload[key] = round(value, 8)
            else:
                payload[key] = value
        return payload

    def _trade_fingerprint(self, trade_params: Dict) -> str:
        normalized = self._normalize_trade_fingerprint_payload(trade_params)
        serialized = json.dumps(normalized, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(serialized.encode("utf-8")).hexdigest()

    async def issue_explain_execution_token(
        self,
        user_id: str,
        trade_params: Dict,
        guard_passed: bool,
    ) -> Dict:
        is_paper_trade = bool(trade_params.get("is_paper_trade", False))
        required = self.require_explain_token and not is_paper_trade
        if not required:
            return {
                "required": False,
                "token": None,
                "expires_at": None,
                "ttl_seconds": 0,
            }
        if not guard_passed:
            return {
                "required": True,
                "token": None,
                "expires_at": None,
                "ttl_seconds": self.explain_token_ttl_seconds,
            }

        token = secrets.token_urlsafe(24)
        expires_at = datetime.now() + timedelta(seconds=self.explain_token_ttl_seconds)
        self.pending_explain_tokens[token] = {
            "user_id": user_id,
            "fingerprint": self._trade_fingerprint(trade_params),
            "created_at": datetime.now(),
            "expires_at": expires_at,
            "used": False,
        }
        return {
            "required": True,
            "token": token,
            "expires_at": expires_at.isoformat(),
            "ttl_seconds": self.explain_token_ttl_seconds,
        }

    async def consume_explain_execution_token(
        self,
        user_id: str,
        trade_params: Dict,
        token: Optional[str],
    ) -> Tuple[bool, str]:
        is_paper_trade = bool(trade_params.get("is_paper_trade", False))
        required = self.require_explain_token and not is_paper_trade
        if not required:
            return True, "Explain token not required"

        if not token:
            return False, "Missing explain execution token"

        token_data = self.pending_explain_tokens.get(token)
        if not token_data:
            return False, "Explain execution token not found"

        if token_data.get("used"):
            return False, "Explain execution token already used"

        expires_at = token_data.get("expires_at")
        if isinstance(expires_at, datetime) and datetime.now() > expires_at:
            self.pending_explain_tokens.pop(token, None)
            return False, "Explain execution token expired"

        if token_data.get("user_id") != user_id:
            return False, "Explain execution token user mismatch"

        expected_fingerprint = token_data.get("fingerprint")
        current_fingerprint = self._trade_fingerprint(trade_params)
        if expected_fingerprint != current_fingerprint:
            return False, "Trade parameters changed after explain-before-execute"

        token_data["used"] = True
        token_data["used_at"] = datetime.now()
        self.pending_explain_tokens[token] = token_data
        return True, "Explain execution token accepted"

    def _extract_paper_metrics(self, paper_summary: Dict) -> Dict[str, float]:
        statistics = paper_summary.get("statistics", {}) if isinstance(paper_summary, dict) else {}
        balance = paper_summary.get("balance", {}) if isinstance(paper_summary, dict) else {}
        created_at_raw = paper_summary.get("created_at")
        created_at = None
        if isinstance(created_at_raw, str):
            try:
                created_at = datetime.fromisoformat(created_at_raw.replace("Z", "+00:00"))
            except Exception:
                created_at = None
        age_days = max(0, (datetime.now() - created_at).days) if created_at else 0

        return {
            "total_trades": self._to_float(statistics.get("total_trades"), 0.0),
            "win_rate_percent": self._to_float(statistics.get("win_rate"), 0.0),
            "max_drawdown_percent": self._to_float(statistics.get("max_drawdown"), 100.0),
            "return_percent": self._to_float(balance.get("return_percent"), 0.0),
            "age_days": float(age_days),
        }

    async def configure_autonomy_guardrails(
        self,
        user_id: str,
        probation: Optional[Dict] = None,
        risk_budget: Optional[Dict] = None,
        level: Optional[str] = None,
    ) -> Dict:
        policy = self._get_or_create_probation_policy(user_id)
        budget = self._get_or_create_risk_budget(user_id)
        state = self._get_or_create_autonomy_state(user_id)

        if isinstance(probation, dict):
            policy.min_paper_trades = int(probation.get("min_paper_trades", policy.min_paper_trades))
            policy.min_win_rate_percent = float(
                probation.get("min_win_rate_percent", policy.min_win_rate_percent)
            )
            policy.max_drawdown_percent = float(
                probation.get("max_drawdown_percent", policy.max_drawdown_percent)
            )
            policy.min_active_days = int(probation.get("min_active_days", policy.min_active_days))

        if isinstance(risk_budget, dict):
            budget.max_risk_per_trade_percent = float(
                risk_budget.get("max_risk_per_trade_percent", budget.max_risk_per_trade_percent)
            )
            budget.daily_loss_limit_percent = float(
                risk_budget.get("daily_loss_limit_percent", budget.daily_loss_limit_percent)
            )
            budget.weekly_loss_limit_percent = float(
                risk_budget.get("weekly_loss_limit_percent", budget.weekly_loss_limit_percent)
            )
            budget.max_drawdown_percent = float(
                risk_budget.get("max_drawdown_percent", budget.max_drawdown_percent)
            )

        if isinstance(level, str):
            normalized = level.strip().lower()
            if normalized in {"manual", "assisted", "guarded_auto", "full_auto"}:
                state.level = normalized

        return await self.get_autonomy_guardrails(user_id=user_id)

    async def evaluate_probation(self, user_id: str, paper_summary: Optional[Dict]) -> Dict:
        policy = self._get_or_create_probation_policy(user_id)
        state = self._get_or_create_autonomy_state(user_id)

        if not isinstance(paper_summary, dict) or paper_summary.get("error"):
            state.probation_passed = False
            state.last_probation_check = datetime.now()
            return {
                "passed": False,
                "reason": "Paper trading account not available",
                "requirements": {
                    "min_paper_trades": policy.min_paper_trades,
                    "min_win_rate_percent": policy.min_win_rate_percent,
                    "max_drawdown_percent": policy.max_drawdown_percent,
                    "min_active_days": policy.min_active_days,
                },
            }

        metrics = self._extract_paper_metrics(paper_summary)
        checks = {
            "paper_trades": metrics["total_trades"] >= policy.min_paper_trades,
            "win_rate": metrics["win_rate_percent"] >= policy.min_win_rate_percent,
            "drawdown": metrics["max_drawdown_percent"] <= policy.max_drawdown_percent,
            "age_days": metrics["age_days"] >= policy.min_active_days,
        }
        passed = all(checks.values())
        state.probation_passed = passed
        state.last_probation_check = datetime.now()

        if passed:
            if state.level in {"manual", "assisted"}:
                state.level = "guarded_auto"
            if (
                metrics["total_trades"] >= (policy.min_paper_trades * 2)
                and metrics["win_rate_percent"] >= (policy.min_win_rate_percent + 10.0)
                and metrics["max_drawdown_percent"] <= (policy.max_drawdown_percent * 0.7)
            ):
                state.level = "full_auto"

        failed_items = [name for name, ok in checks.items() if not ok]
        reason = "Probation requirements satisfied"
        if failed_items:
            reason = "Probation incomplete: " + ", ".join(failed_items)

        return {
            "passed": passed,
            "reason": reason,
            "checks": checks,
            "metrics": metrics,
            "requirements": {
                "min_paper_trades": policy.min_paper_trades,
                "min_win_rate_percent": policy.min_win_rate_percent,
                "max_drawdown_percent": policy.max_drawdown_percent,
                "min_active_days": policy.min_active_days,
            },
        }

    async def assess_anomaly_and_drift(self, user_id: str, deep_study: Optional[Dict]) -> Dict:
        state = self._get_or_create_autonomy_state(user_id)
        if not isinstance(deep_study, dict):
            return {"triggered": False, "reason": "deep_study_missing"}

        chart_analysis = deep_study.get("chart_analysis", {})
        volatility = str(chart_analysis.get("volatility", "unknown")).lower()
        consensus_score = self._to_float(deep_study.get("consensus_score"), 0.0)
        source_coverage = deep_study.get("source_coverage", {})
        coverage_ratio = self._to_float(source_coverage.get("coverage_ratio"), 0.0)

        state.recent_consensus_scores.append(consensus_score)
        if len(state.recent_consensus_scores) > 8:
            state.recent_consensus_scores = state.recent_consensus_scores[-8:]

        score_range = 0.0
        if state.recent_consensus_scores:
            score_range = max(state.recent_consensus_scores) - min(state.recent_consensus_scores)

        anomaly = volatility == "high" and coverage_ratio < 0.45
        drift = len(state.recent_consensus_scores) >= 4 and score_range >= 0.28

        if anomaly or drift:
            state.paused = True
            if anomaly and drift:
                state.pause_reason = "Anomaly pause: high volatility + unstable model consensus"
            elif anomaly:
                state.pause_reason = "Anomaly pause: high volatility with low source coverage"
            else:
                state.pause_reason = "Anomaly pause: model drift detected in consensus signals"
            state.pause_until = datetime.now() + timedelta(hours=2)
            if state.level == "full_auto":
                state.level = "guarded_auto"
            return {
                "triggered": True,
                "reason": state.pause_reason,
                "volatility": volatility,
                "coverage_ratio": coverage_ratio,
                "score_range": round(score_range, 4),
                "pause_until": state.pause_until.isoformat(),
            }

        if state.pause_until and datetime.now() >= state.pause_until:
            state.paused = False
            state.pause_reason = None
            state.pause_until = None

        return {
            "triggered": False,
            "volatility": volatility,
            "coverage_ratio": coverage_ratio,
            "score_range": round(score_range, 4),
        }

    def _apply_budget_and_autonomy(self, user_id: str):
        budget = self._get_or_create_risk_budget(user_id)
        state = self._get_or_create_autonomy_state(user_id)
        daily = self.daily_stats.get(user_id)
        daily_pnl = daily.total_profit_loss if daily else 0.0
        max_drawdown = daily.max_drawdown if daily else 0.0
        week_key = self._get_week_key()
        weekly_pnl = self.weekly_profit_loss.get(user_id, {}).get(week_key, 0.0)

        if daily_pnl <= -budget.daily_loss_limit_percent:
            state.paused = True
            state.pause_reason = (
                f"Budget pause: daily loss budget breached ({daily_pnl:.2f}% <= -{budget.daily_loss_limit_percent:.2f}%)"
            )
            state.level = "assisted"
        elif weekly_pnl <= -budget.weekly_loss_limit_percent:
            state.paused = True
            state.pause_reason = (
                f"Budget pause: weekly loss budget breached ({weekly_pnl:.2f}% <= -{budget.weekly_loss_limit_percent:.2f}%)"
            )
            state.level = "assisted"
        elif max_drawdown >= budget.max_drawdown_percent:
            state.paused = True
            state.pause_reason = (
                f"Budget pause: drawdown budget breached ({max_drawdown:.2f}% >= {budget.max_drawdown_percent:.2f}%)"
            )
            state.level = "assisted"
        else:
            if state.paused and state.pause_reason and state.pause_reason.startswith("Budget pause:"):
                # Keep anomaly pause handling separate; clear budget-driven pause when safe again.
                state.paused = False
                state.pause_reason = None

            # Progressive downgrade near budget limits.
            near_daily = daily_pnl <= -(0.7 * budget.daily_loss_limit_percent)
            near_weekly = weekly_pnl <= -(0.7 * budget.weekly_loss_limit_percent)
            near_drawdown = max_drawdown >= (0.7 * budget.max_drawdown_percent)
            if near_daily or near_weekly or near_drawdown:
                if state.level == "full_auto":
                    state.level = "guarded_auto"
                elif state.level == "guarded_auto":
                    state.level = "assisted"

    async def get_autonomy_guardrails(self, user_id: str) -> Dict:
        policy = self._get_or_create_probation_policy(user_id)
        budget = self._get_or_create_risk_budget(user_id)
        state = self._get_or_create_autonomy_state(user_id)
        self._apply_budget_and_autonomy(user_id)
        week_key = self._get_week_key()
        return {
            "user_id": user_id,
            "autonomy_state": {
                "level": state.level,
                "probation_passed": state.probation_passed,
                "paused": state.paused,
                "pause_reason": state.pause_reason,
                "pause_until": state.pause_until.isoformat() if state.pause_until else None,
            },
            "probation_policy": {
                "min_paper_trades": policy.min_paper_trades,
                "min_win_rate_percent": policy.min_win_rate_percent,
                "max_drawdown_percent": policy.max_drawdown_percent,
                "min_active_days": policy.min_active_days,
            },
            "risk_budget": {
                "max_risk_per_trade_percent": budget.max_risk_per_trade_percent,
                "daily_loss_limit_percent": budget.daily_loss_limit_percent,
                "weekly_loss_limit_percent": budget.weekly_loss_limit_percent,
                "max_drawdown_percent": budget.max_drawdown_percent,
                "weekly_pnl_percent": self.weekly_profit_loss.get(user_id, {}).get(week_key, 0.0),
            },
        }

    async def can_execute_autonomous_trade(
        self,
        user_id: str,
        trade_params: Dict,
        paper_summary: Optional[Dict] = None,
        deep_study: Optional[Dict] = None,
    ) -> Tuple[bool, str, Dict]:
        state = self._get_or_create_autonomy_state(user_id)
        budget = self._get_or_create_risk_budget(user_id)
        self._apply_budget_and_autonomy(user_id)

        if (
            state.paused
            and state.pause_until
            and state.pause_reason
            and state.pause_reason.startswith("Anomaly pause:")
            and datetime.now() >= state.pause_until
        ):
            state.paused = False
            state.pause_reason = None
            state.pause_until = None

        if state.paused:
            return False, state.pause_reason or "Autonomy paused by guardrails", {
                "autonomy_level": state.level,
                "paused": state.paused,
            }

        is_paper_trade = bool(trade_params.get("is_paper_trade", False))
        if not is_paper_trade and state.level == "manual":
            return False, "Autonomy level is manual. Enable assisted/guarded/full mode first.", {
                "autonomy_level": state.level,
                "paused": state.paused,
            }

        probation_result = {"passed": True, "reason": "Paper trade path"}
        if not is_paper_trade:
            if self.allow_dev_probation_bypass and user_id.startswith("dev_"):
                probation_result = {
                    "passed": True,
                    "reason": "Dev probation bypass enabled",
                    "checks": {"dev_bypass": True},
                }
            else:
                probation_result = await self.evaluate_probation(user_id, paper_summary)
                if not probation_result.get("passed"):
                    return False, probation_result.get("reason", "Probation requirements not met"), {
                        "probation": probation_result,
                        "autonomy_level": state.level,
                    }

        risk_percent = self._to_float(trade_params.get("risk_percent"), -1.0)
        if risk_percent < 0:
            entry_price = self._to_float(trade_params.get("entry_price"), 0.0)
            stop_loss = self._to_float(trade_params.get("stop_loss"), 0.0)
            if entry_price > 0 and stop_loss > 0:
                risk_percent = abs((entry_price - stop_loss) / entry_price) * 100
            else:
                risk_percent = 0.0

        if risk_percent > budget.max_risk_per_trade_percent:
            return False, (
                f"Trade risk {risk_percent:.2f}% exceeds budget {budget.max_risk_per_trade_percent:.2f}%"
            ), {
                "probation": probation_result,
                "risk_percent": risk_percent,
                "budget": budget.max_risk_per_trade_percent,
            }

        anomaly = await self.assess_anomaly_and_drift(user_id, deep_study)
        if anomaly.get("triggered"):
            return False, str(anomaly.get("reason") or "Anomaly detected"), {
                "anomaly": anomaly,
                "probation": probation_result,
            }

        return True, "Autonomous guardrails passed", {
            "autonomy_level": state.level,
            "probation": probation_result,
            "risk_percent": round(risk_percent, 4),
            "risk_budget": budget.max_risk_per_trade_percent,
            "anomaly": anomaly,
        }

    async def build_explain_before_execute(
        self,
        user_id: str,
        trade_params: Dict,
        risk_assessment: Dict,
        deep_study: Dict,
        guardrail_decision: Dict,
    ) -> Dict:
        coverage = deep_study.get("source_coverage", {}) if isinstance(deep_study, dict) else {}
        chart = deep_study.get("chart_analysis", {}) if isinstance(deep_study, dict) else {}
        consensus = self._to_float(deep_study.get("consensus_score"), 0.0)
        recommendation = str(deep_study.get("recommendation", "wait_for_confirmation"))

        return {
            "title": "Explain Before Execute",
            "user_id": user_id,
            "trade": {
                "pair": trade_params.get("pair"),
                "action": trade_params.get("action"),
                "entry_price": trade_params.get("entry_price"),
                "stop_loss": trade_params.get("stop_loss"),
                "take_profit": trade_params.get("take_profit"),
            },
            "deep_study": {
                "consensus_score": round(consensus, 4),
                "confidence_percent": round(consensus * 100, 2),
                "recommendation": recommendation,
                "sources_analyzed": coverage.get("analyzed", 0),
                "sources_requested": coverage.get("requested", 0),
                "coverage_ratio": coverage.get("coverage_ratio", 0.0),
                "volatility": chart.get("volatility", "unknown"),
                "market_risk": chart.get("risk_level", "unknown"),
            },
            "risk_assessment": {
                "risk_level": risk_assessment.get("risk_level", "unknown"),
                "kill_switch_active": risk_assessment.get("kill_switch_active", False),
                "current_status": risk_assessment.get("current_status", {}),
            },
            "guardrail_decision": guardrail_decision,
            "rationale": [
                "Trade execution is blocked if probation, risk budget, or anomaly checks fail.",
                "Position sizing is constrained by max-risk-per-trade budget.",
                "Autonomy level is automatically downgraded when risk budget pressure rises.",
            ],
            "timestamp": datetime.now().isoformat(),
        }

    async def initialize_user_limits(self, user_id: str, limits: RiskLimits):
        """Initialize risk limits for a user"""
        self.user_limits[user_id] = limits
        self.active_trades[user_id] = []
        self.kill_switch_active[user_id] = False
        self._get_or_create_probation_policy(user_id)
        self._get_or_create_risk_budget(user_id)
        self._get_or_create_autonomy_state(user_id)
        if user_id not in self.weekly_profit_loss:
            self.weekly_profit_loss[user_id] = {}
        
        # Initialize today's stats
        today = datetime.now().strftime("%Y-%m-%d")
        self.daily_stats[user_id] = DailyTradingStats(date=today)
        
        return {
            "status": "success",
            "message": f"Risk limits initialized for user {user_id}",
            "limits": {
                "max_trade_size": limits.max_trade_size,
                "daily_loss_limit": limits.daily_loss_limit,
                "max_open_positions": limits.max_open_positions,
            }
        }

    async def validate_trade(self, user_id: str, trade_params: Dict) -> Tuple[bool, str]:
        """
        Validate if a trade can be executed based on risk limits
        Returns: (is_valid, reason_if_invalid)
        """
        if not self.user_limits.get(user_id):
            return False, "User risk limits not configured"
        
        if self.kill_switch_active.get(user_id, False):
            return False, "KILL SWITCH ACTIVE - All trading disabled"
        
        limits = self.user_limits[user_id]
        is_paper_trade = bool(trade_params.get("is_paper_trade", False))
        action = str(trade_params.get("action", "")).upper()
        pair = str(trade_params.get("pair", "")).upper()

        if self.require_broker_fail_safe and not is_paper_trade:
            if trade_params.get("broker_fail_safe_confirmed") is not True:
                return False, (
                    "Broker fail-safe protection is mandatory for live trades. "
                    "Set broker_fail_safe_confirmed=true."
                )

        # Check 0: Input sanity for execution-critical fields
        if action not in {"BUY", "SELL"}:
            return False, "Action must be BUY or SELL"
        if len(pair) != 7 or "/" not in pair:
            return False, "Pair must be in XXX/YYY format"
        if not all(part.isalpha() and len(part) == 3 for part in pair.split("/", 1)):
            return False, "Pair must be in XXX/YYY format"

        position_size = self._to_float(trade_params.get("position_size"), -1.0)
        if position_size <= 0:
            return False, "Position size must be greater than zero"

        entry_price = self._to_float(trade_params.get("entry_price"), 0.0)
        stop_loss = self._to_float(trade_params.get("stop_loss"), 0.0)
        take_profit = self._to_float(trade_params.get("take_profit"), 0.0)
        if entry_price <= 0 or stop_loss <= 0 or take_profit <= 0:
            return False, "Entry, Stop-Loss, and Take-Profit must be greater than zero"

        if action == "BUY":
            if not (stop_loss < entry_price < take_profit):
                return False, "For BUY trades, require stop_loss < entry_price < take_profit"
        else:
            if not (take_profit < entry_price < stop_loss):
                return False, "For SELL trades, require take_profit < entry_price < stop_loss"

        sl_distance = abs((entry_price - stop_loss) / entry_price) * 100 if entry_price else 0.0
        tp_distance = abs((take_profit - entry_price) / entry_price) * 100 if entry_price else 0.0
        if sl_distance < 0.2:
            return False, "Stop-Loss too close to entry (0.2% minimum)"
        if sl_distance > 5.0:
            return False, "Stop-Loss too far from entry (5.0% maximum)"
        if tp_distance <= 0:
            return False, "Take-Profit distance is invalid"
        rr_ratio = tp_distance / sl_distance if sl_distance > 0 else 0.0
        if rr_ratio < 1.2:
            return False, "Risk-reward ratio too low (minimum 1.2)"

        # Check 1: Position size limit
        if position_size > limits.max_trade_size:
            return False, f"Position size {position_size} exceeds max {limits.max_trade_size}"
        
        # Check 2: Open positions limit
        open_positions = len(self.active_trades.get(user_id, []))
        if open_positions >= limits.max_open_positions:
            return False, f"Already have {open_positions} open positions (max: {limits.max_open_positions})"
        
        # Check 3: Daily loss limit
        today = datetime.now().strftime("%Y-%m-%d")
        daily_stat = self.daily_stats.get(user_id)
        if daily_stat and daily_stat.total_profit_loss < -limits.daily_loss_limit:
            return False, f"Daily loss limit reached: {daily_stat.total_profit_loss}% (limit: -{limits.daily_loss_limit}%)"
        
        # Check 4: Mandatory Stop-Loss & Take-Profit
        if limits.mandatory_stop_loss and not trade_params.get("stop_loss"):
            return False, "Stop-Loss is mandatory but not set"
        
        if limits.mandatory_take_profit and not trade_params.get("take_profit"):
            return False, "Take-Profit is mandatory but not set"

        if not is_paper_trade:
            account_id = str(trade_params.get("account_id", "")).strip()
            if not account_id:
                return False, "Live trade requires bound broker account_id"
            if trade_params.get("server_side_stop_loss") is False:
                return False, "Server-side Stop-Loss protection must remain enabled"
            if trade_params.get("server_side_take_profit") is False:
                return False, "Server-side Take-Profit protection must remain enabled"

        return True, "Trade validation passed"

    async def execute_trade_with_safety(self, user_id: str, trade_params: Dict) -> Dict:
        """
        Execute trade with all safety checks and logging
        """
        is_valid, reason = await self.validate_trade(user_id, trade_params)
        
        if not is_valid:
            return {
                "success": False,
                "error": reason,
                "risk_check_failed": True
            }
        
        # Create trade record
        trade_id = f"trade_{user_id}_{datetime.now().timestamp()}"
        trade = TradeExecution(
            trade_id=trade_id,
            user_id=user_id,
            pair=trade_params.get("pair"),
            action=trade_params.get("action"),
            entry_price=trade_params.get("entry_price"),
            stop_loss=trade_params.get("stop_loss"),
            take_profit=trade_params.get("take_profit"),
            position_size=trade_params.get("position_size"),
            timestamp=datetime.now(),
            status="open",
            reason=trade_params.get("reason"),
            is_paper_trade=trade_params.get("is_paper_trade", False)
        )
        
        # Add to active trades
        if user_id not in self.active_trades:
            self.active_trades[user_id] = []
        self.active_trades[user_id].append(trade)
        
        # Update daily stats
        today = datetime.now().strftime("%Y-%m-%d")
        if user_id not in self.daily_stats:
            self.daily_stats[user_id] = DailyTradingStats(date=today)
        self.daily_stats[user_id].total_trades += 1
        self.daily_stats[user_id].trades.append(trade)
        
        return {
            "success": True,
            "trade_id": trade_id,
            "message": f"Trade executed successfully",
            "trade_details": {
                "pair": trade.pair,
                "action": trade.action,
                "entry_price": trade.entry_price,
                "position_size": trade.position_size,
                "is_paper_trade": trade.is_paper_trade,
                "account_id": trade_params.get("account_id"),
                "broker_order_id": trade_params.get("broker_order_id"),
            },
        }

    async def close_trade(self, user_id: str, trade_id: str, exit_price: float) -> Dict:
        """Close an open trade and update P&L"""
        active_trades = self.active_trades.get(user_id, [])
        trade = next((t for t in active_trades if t.trade_id == trade_id), None)
        
        if not trade:
            return {"success": False, "error": "Trade not found"}
        
        # Calculate P&L
        if trade.action == "BUY":
            profit_loss = (exit_price - trade.entry_price) * trade.position_size
        else:  # SELL
            profit_loss = (trade.entry_price - exit_price) * trade.position_size
        
        # Update trade
        trade.exit_price = exit_price
        trade.profit_loss = profit_loss
        trade.status = "closed"
        
        # Update daily stats
        daily_stat = self.daily_stats.get(user_id)
        if daily_stat:
            daily_stat.total_profit_loss += (profit_loss / trade.position_size) if trade.position_size else 0
            if profit_loss > 0:
                daily_stat.winning_trades += 1
            else:
                daily_stat.losing_trades += 1

        # Update weekly budget tracking (stored as percent-like aggregate)
        week_key = self._get_week_key()
        if user_id not in self.weekly_profit_loss:
            self.weekly_profit_loss[user_id] = {}
        self.weekly_profit_loss[user_id][week_key] = (
            self.weekly_profit_loss[user_id].get(week_key, 0.0)
            + ((profit_loss / trade.position_size) if trade.position_size else 0.0)
        )
        self._apply_budget_and_autonomy(user_id)
        
        return {
            "success": True,
            "trade_id": trade_id,
            "profit_loss": profit_loss,
            "exit_price": exit_price,
            "message": f"Trade closed with P&L: {profit_loss:.2f}"
        }

    async def activate_kill_switch(self, user_id: str) -> Dict:
        """
        Emergency: Immediately stop all trading for this user
        """
        self.kill_switch_active[user_id] = True
        
        # Close all open trades at market price (simulated)
        active_trades = self.active_trades.get(user_id, [])
        closed_count = 0
        for trade in active_trades:
            if trade.status == "open":
                trade.status = "closed_emergency"
                closed_count += 1
        
        # Update daily stats
        if user_id in self.daily_stats:
            self.daily_stats[user_id].kill_switch_triggered = True
        
        return {
            "success": True,
            "message": "KILL SWITCH ACTIVATED - All trading disabled",
            "trades_emergency_closed": closed_count,
            "timestamp": datetime.now().isoformat()
        }

    async def get_risk_assessment(self, user_id: str) -> Dict:
        """Get current risk assessment and status"""
        limits = self.user_limits.get(user_id)
        daily_stat = self.daily_stats.get(user_id)
        active_trades = self.active_trades.get(user_id, [])
        state = self._get_or_create_autonomy_state(user_id)
        budget = self._get_or_create_risk_budget(user_id)
        
        # Provide default limits if not configured
        if not limits:
            limits = RiskLimits(
                max_trade_size=10000,
                daily_loss_limit=10,
                max_open_positions=5,
                max_drawdown_percent=20,
                mandatory_stop_loss=True,
                mandatory_take_profit=True,
                kill_switch_enabled=True
            )
            # Initialize user with default limits
            await self.initialize_user_limits(user_id, limits)
        
        # Calculate risk level
        risk_level = await self._calculate_risk_level(user_id, limits, daily_stat, active_trades)
        self._apply_budget_and_autonomy(user_id)
        week_key = self._get_week_key()
        
        return {
            "user_id": user_id,
            "risk_level": risk_level,
            "kill_switch_active": self.kill_switch_active.get(user_id, False),
            "autonomy_guardrails": {
                "level": state.level,
                "probation_passed": state.probation_passed,
                "paused": state.paused,
                "pause_reason": state.pause_reason,
                "pause_until": state.pause_until.isoformat() if state.pause_until else None,
            },
            "risk_budget": {
                "max_risk_per_trade_percent": budget.max_risk_per_trade_percent,
                "daily_loss_limit_percent": budget.daily_loss_limit_percent,
                "weekly_loss_limit_percent": budget.weekly_loss_limit_percent,
                "max_drawdown_percent": budget.max_drawdown_percent,
                "weekly_profit_loss_percent": self.weekly_profit_loss.get(user_id, {}).get(week_key, 0.0),
            },
            "limits": {
                "max_trade_size": limits.max_trade_size,
                "daily_loss_limit": limits.daily_loss_limit,
                "max_open_positions": limits.max_open_positions,
            },
            "current_status": {
                "open_positions": len([t for t in active_trades if t.status == "open"]),
                "max_open_positions": limits.max_open_positions,
                "daily_profit_loss": daily_stat.total_profit_loss if daily_stat else 0,
                "daily_loss_limit": -limits.daily_loss_limit,
                "total_trades_today": daily_stat.total_trades if daily_stat else 0,
                "win_rate": (daily_stat.winning_trades / max(daily_stat.total_trades, 1) * 100) if daily_stat else 0,
            },
            "timestamp": datetime.now().isoformat()
        }

    async def _calculate_risk_level(self, user_id: str, limits: RiskLimits, 
                                   daily_stat: Optional[DailyTradingStats], 
                                   active_trades: List[TradeExecution]) -> str:
        """Calculate current risk level"""
        danger_score = 0
        
        # Check daily loss
        if daily_stat and daily_stat.total_profit_loss < -limits.daily_loss_limit * 0.5:
            danger_score += 2
        
        # Check open positions
        if len(active_trades) > limits.max_open_positions * 0.7:
            danger_score += 1
        
        # Check recent losing streak
        if daily_stat and daily_stat.losing_trades > 3:
            danger_score += 1
        
        if danger_score >= 3:
            return RiskLevel.EXTREME.value
        elif danger_score >= 2:
            return RiskLevel.HIGH.value
        elif danger_score >= 1:
            return RiskLevel.MODERATE.value
        else:
            return RiskLevel.SAFE.value

    async def get_trading_analytics(self, user_id: str, days: int = 30) -> Dict:
        """Get comprehensive trading analytics for user"""
        daily_stat = self.daily_stats.get(user_id)
        
        if not daily_stat:
            return {"error": "No trading history"}
        
        total_trades = daily_stat.total_trades
        winning = daily_stat.winning_trades
        losing = daily_stat.losing_trades
        
        return {
            "summary": {
                "total_trades": total_trades,
                "winning_trades": winning,
                "losing_trades": losing,
                "win_rate": (winning / max(total_trades, 1) * 100),
                "total_profit_loss": daily_stat.total_profit_loss,
                "max_drawdown": daily_stat.max_drawdown,
            },
            "daily_breakdown": {
                "date": daily_stat.date,
                "trades_count": total_trades,
                "profit_loss": daily_stat.total_profit_loss,
            },
            "risk_metrics": {
                "kill_switch_triggered": daily_stat.kill_switch_triggered,
                "emergency_closures": len([t for t in daily_stat.trades if t.status == "closed_emergency"]),
            }
        }
