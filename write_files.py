"""
Run from D:\\Tajir\\Backend:
    python write_files.py
Writes all 3 DeepSeek-replaced files directly into the project.
"""
from pathlib import Path

# ── FILE 1: app/services/signal_service.py ────────────────────────────────
signal_service = '''"""
app/services/signal_service.py
Phase 4 - AI Signal Fusion
Flow: Prices + News + RSI/MACD -> DeepSeek -> Fused confidence score + 3-level explainer
"""
import os
import json
import logging
import httpx
from datetime import datetime, timezone
from pydantic import BaseModel
from typing import Optional, List
from app.services.market_data_service import get_market_prices
from app.services.technical_analysis_service import get_technical_indicators
from app.ai.deepseek_client import DeepSeekClient

logger = logging.getLogger(__name__)

NEWS_API_KEY  = os.getenv("NEWS_API_KEY", "")
SUPABASE_URL  = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY  = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
NEWS_API_BASE = "https://newsapi.org/v2"
AI_MODEL      = "deepseek-chat"


class TradeSignal(BaseModel):
    pair:             str
    action:           str
    confidence:       float
    entry_price:      float
    stop_loss:        float
    take_profit:      float
    reasoning:        str
    sentiment:        str
    news_summary:     str
    generated_at:     str
    model:            str
    technical_bias:   Optional[str] = None
    rsi:              Optional[float] = None
    macd_bias:        Optional[str] = None
    indicator_tags:   List[str] = []
    explain_simple:   Optional[str] = None
    explain_standard: Optional[str] = None
    explain_advanced: Optional[str] = None


class SignalResponse(BaseModel):
    signals:      list[TradeSignal]
    generated_at: str
    pairs:        list[str]


async def _fetch_news(query: str = "forex currency trading") -> list[str]:
    if not NEWS_API_KEY:
        return []
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                f"{NEWS_API_BASE}/everything",
                params={
                    "q":        query,
                    "language": "en",
                    "sortBy":   "publishedAt",
                    "pageSize": 5,
                    "apiKey":   NEWS_API_KEY,
                },
            )
        resp.raise_for_status()
        articles = resp.json().get("articles", [])
        return [a.get("title", "") for a in articles if a.get("title")]
    except Exception as e:
        logger.error("NewsAPI fetch failed: %s", e)
        return []


async def _save_signal_to_supabase(signal: TradeSignal) -> None:
    if not SUPABASE_URL or not SUPABASE_KEY:
        return
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            await client.post(
                f"{SUPABASE_URL}/rest/v1/trade_signals",
                headers={
                    "apikey":        SUPABASE_KEY,
                    "Authorization": f"Bearer {SUPABASE_KEY}",
                    "Content-Type":  "application/json",
                    "Prefer":        "return=minimal",
                },
                json=signal.model_dump(),
            )
    except Exception as e:
        logger.error("Supabase save failed: %s", e)


def _fuse_confidence(
    ai_conf: float,
    technical_bias: str,
    ai_sentiment: str,
    action: str,
) -> float:
    score = ai_conf
    action_bias = "bullish" if action == "BUY" else "bearish" if action == "SELL" else "neutral"
    if technical_bias == action_bias:
        score = min(score + 0.08, 0.95)
    elif technical_bias != "neutral" and technical_bias != action_bias:
        score = max(score - 0.10, 0.25)
    return round(score, 3)


def _build_ai_prompt(pair: str, price: float, headlines: list[str], technical: dict) -> str:
    news_block = "\\n".join(f"- {h}" for h in headlines) if headlines else "- No news available"
    tech_block = ""
    if technical.get("available"):
        rsi = technical.get("rsi")
        macd = technical.get("macd") or {}
        tech_block = f"""
Technical Indicators:
- RSI (14): {rsi:.1f} -> {technical.get("technical_bias", "neutral").upper()}
- MACD: {macd.get("bias", "neutral").upper()} (histogram: {macd.get("histogram", 0):.6f})
"""
    return f"""You are an expert forex analyst. Analyze and return a trade signal.

Currency Pair: {pair}
Current Price: {price}
{tech_block}
Latest Forex News Headlines:
{news_block}

Return ONLY a valid JSON object with exactly these fields:
{{
  "action": "BUY" or "SELL" or "HOLD",
  "confidence": 0.0 to 1.0,
  "stop_loss": <price as float>,
  "take_profit": <price as float>,
  "reasoning": "<one sentence technical explanation>",
  "sentiment": "bullish" or "bearish" or "neutral",
  "news_summary": "<one sentence news summary>",
  "explain_simple": "<explain to a complete beginner in 1-2 simple sentences>",
  "explain_standard": "<explain to an intermediate trader in 2-3 sentences>",
  "explain_advanced": "<explain to an expert with RSI, MACD, S/R levels in 3-4 sentences>"
}}

Rules:
- stop_loss must be below entry for BUY, above entry for SELL
- take_profit must be above entry for BUY, below entry for SELL
- confidence above 0.7 means strong signal
- Return only JSON, no markdown, no explanation
"""


async def generate_signals(
    pairs: list[str] | None = None,
    redis_client=None,
) -> SignalResponse:
    if not pairs:
        pairs = ["EUR_USD", "GBP_USD", "USD_JPY"]

    now_iso = datetime.now(timezone.utc).isoformat()
    price_response = await get_market_prices(pairs=pairs, redis_client=redis_client)
    price_map = {q.instrument: q.mid for q in price_response.prices}

    if not price_map:
        return SignalResponse(signals=[], generated_at=now_iso, pairs=pairs)

    headlines = await _fetch_news("forex USD EUR GBP JPY trading")
    signals: list[TradeSignal] = []
    _ai_client = DeepSeekClient()

    for pair in pairs:
        price = price_map.get(pair)
        if not price:
            continue

        technical = await get_technical_indicators(pair)
        prompt = _build_ai_prompt(pair, price, headlines, technical)
        raw = _ai_client.generate_json(
            model_name=AI_MODEL,
            prompt=prompt,
            fallback={
                "action":           "HOLD",
                "confidence":       0.5,
                "stop_loss":        round(price * 0.995, 5),
                "take_profit":      round(price * 1.005, 5),
                "reasoning":        "AI unavailable - default HOLD signal",
                "sentiment":        "neutral",
                "news_summary":     "No news data available",
                "explain_simple":   "No AI explanation available right now.",
                "explain_standard": "Signal generation requires DeepSeek API key.",
                "explain_advanced": "Configure DEEPSEEK_API_KEY for full technical analysis.",
            },
        )

        action = raw.get("action", "HOLD").upper()
        ai_conf = float(raw.get("confidence", 0.5))
        fused_conf = _fuse_confidence(
            ai_conf=ai_conf,
            technical_bias=technical.get("technical_bias", "neutral"),
            ai_sentiment=raw.get("sentiment", "neutral"),
            action=action,
        )
        macd_data = technical.get("macd") or {}

        signal = TradeSignal(
            pair=pair,
            action=action,
            confidence=fused_conf,
            entry_price=price,
            stop_loss=float(raw.get("stop_loss", round(price * 0.995, 5))),
            take_profit=float(raw.get("take_profit", round(price * 1.005, 5))),
            reasoning=raw.get("reasoning", ""),
            sentiment=raw.get("sentiment", "neutral"),
            news_summary=raw.get("news_summary", ""),
            generated_at=now_iso,
            model=AI_MODEL,
            technical_bias=technical.get("technical_bias"),
            rsi=technical.get("rsi"),
            macd_bias=macd_data.get("bias"),
            indicator_tags=technical.get("indicator_tags", []),
            explain_simple=raw.get("explain_simple"),
            explain_standard=raw.get("explain_standard"),
            explain_advanced=raw.get("explain_advanced"),
        )

        await _save_signal_to_supabase(signal)
        signals.append(signal)
        try:
            import asyncio as _asyncio
            from app.services.notification_service import notify_new_signal
            _asyncio.create_task(notify_new_signal(user_id="broadcast", signal_data=signal.model_dump()))
        except Exception as _ne:
            logger.warning("Signal notification task failed: %s", _ne)
        logger.info(
            "Signal [Phase4] %s %s conf=%.2f->%.2f tech=%s",
            action, pair, ai_conf, fused_conf,
            technical.get("technical_bias", "n/a"),
        )

    return SignalResponse(signals=signals, generated_at=now_iso, pairs=pairs)
'''

# ── FILE 2: app/services/execution_intelligence_service.py ────────────────
execution_intelligence_service = '''"""
Execution Intelligence Service
Handles conditional automation, time-bound orders, and session-aware trading
Uses DeepSeek AI for intelligent condition analysis
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from enum import Enum
import asyncio
import os
from dotenv import load_dotenv

from app.ai.deepseek_client import DeepSeekClient

load_dotenv()
_ai_client = DeepSeekClient()


class TradingSession(Enum):
    ASIAN    = "asian"
    LONDON   = "london"
    NEW_YORK = "new_york"
    OFF_HOURS = "off_hours"


class OrderType(Enum):
    MARKET     = "market"
    LIMIT      = "limit"
    STOP_LOSS  = "stop_loss"
    TAKE_PROFIT = "take_profit"
    OCO        = "one_cancels_other"
    IF_TOUCHED = "if_touched"


class OrderStatus(Enum):
    PENDING   = "pending"
    TRIGGERED = "triggered"
    EXECUTED  = "executed"
    CANCELLED = "cancelled"
    EXPIRED   = "expired"


@dataclass
class Condition:
    condition_type: str
    operator: str
    value: float
    description: str


@dataclass
class ConditionalOrder:
    order_id: str
    user_id: str
    pair: str
    action: str
    conditions: List[Condition]
    all_conditions_must_match: bool = True
    position_size: float = 0
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    max_execution_time: Optional[datetime] = None
    session_filter: Optional[TradingSession] = None
    status: OrderStatus = OrderStatus.PENDING
    created_at: datetime = field(default_factory=datetime.now)
    executed_at: Optional[datetime] = None
    execution_price: Optional[float] = None
    order_type: OrderType = OrderType.MARKET
    notes: Optional[str] = None


@dataclass
class SessionStatistics:
    session: TradingSession
    average_volatility: float
    average_spread: float
    typical_volume: str
    best_trading_pairs: List[str]
    peak_activity_hours: List[int]


class ExecutionIntelligenceService:

    def __init__(self):
        self.pending_orders: Dict[str, List[ConditionalOrder]] = {}
        self.order_history: List[ConditionalOrder] = []
        self.session_stats = self._initialize_session_stats()
        self.monitoring_tasks: Dict[str, asyncio.Task] = {}

    def _initialize_session_stats(self) -> Dict[TradingSession, SessionStatistics]:
        return {
            TradingSession.ASIAN: SessionStatistics(
                session=TradingSession.ASIAN,
                average_volatility=0.6, average_spread=1.2, typical_volume="medium",
                best_trading_pairs=["USD/JPY", "AUD/USD", "NZD/USD"],
                peak_activity_hours=[0, 1, 2, 3, 4, 5, 6, 7]
            ),
            TradingSession.LONDON: SessionStatistics(
                session=TradingSession.LONDON,
                average_volatility=1.2, average_spread=0.8, typical_volume="high",
                best_trading_pairs=["EUR/USD", "GBP/USD", "EUR/GBP"],
                peak_activity_hours=[8, 9, 10, 11, 12]
            ),
            TradingSession.NEW_YORK: SessionStatistics(
                session=TradingSession.NEW_YORK,
                average_volatility=1.0, average_spread=0.9, typical_volume="high",
                best_trading_pairs=["EUR/USD", "GBP/USD", "USD/CAD"],
                peak_activity_hours=[13, 14, 15, 16, 17, 18, 19, 20]
            ),
        }

    async def create_conditional_order(
        self, user_id, pair, action, conditions, position_size,
        stop_loss=None, take_profit=None, max_hours=12,
        session_filter=None, order_type="market", notes=""
    ) -> Dict:
        parsed_conditions = [
            Condition(
                condition_type=c.get("type"), operator=c.get("operator"),
                value=c.get("value"), description=c.get("description", "")
            ) for c in conditions
        ]
        order_id = f"order_{user_id}_{datetime.now().timestamp()}"
        max_exec_time = datetime.now() + timedelta(hours=max_hours) if max_hours else None
        session = None
        if session_filter:
            try:
                session = TradingSession[session_filter.upper()]
            except KeyError:
                pass
        order = ConditionalOrder(
            order_id=order_id, user_id=user_id, pair=pair, action=action,
            conditions=parsed_conditions, position_size=position_size,
            stop_loss=stop_loss, take_profit=take_profit,
            max_execution_time=max_exec_time, session_filter=session,
            order_type=OrderType[order_type.upper()] if order_type else OrderType.MARKET,
            notes=notes
        )
        if user_id not in self.pending_orders:
            self.pending_orders[user_id] = []
        self.pending_orders[user_id].append(order)
        task = asyncio.create_task(self._monitor_order(order))
        self.monitoring_tasks[order_id] = task
        return {
            "success": True, "order_id": order_id,
            "message": f"Conditional order created with {len(parsed_conditions)} conditions",
            "details": {
                "pair": pair, "action": action,
                "conditions": [c.description for c in parsed_conditions],
                "max_execution_time": max_exec_time.isoformat() if max_exec_time else "indefinite",
                "session_filter": session_filter or "any"
            }
        }

    async def _monitor_order(self, order: ConditionalOrder):
        while order.status == OrderStatus.PENDING:
            if order.max_execution_time and datetime.now() > order.max_execution_time:
                order.status = OrderStatus.EXPIRED
                break
            if order.session_filter:
                if self._get_current_session() != order.session_filter:
                    await asyncio.sleep(60)
                    continue
            if await self._evaluate_conditions(order):
                order.status = OrderStatus.TRIGGERED
                order.executed_at = datetime.now()
                break
            await asyncio.sleep(30)

    async def analyze_conditions_with_ai(self, user_id: str, conditions: List[Dict]) -> Dict:
        """Use DeepSeek AI to analyze conditions and provide recommendations"""
        try:
            if not _ai_client.available:
                return {"success": False, "message": "AI unavailable - configure DEEPSEEK_API_KEY", "analysis": None}
            conditions_text = "\\n".join([f"- {c[\'description\']}" for c in conditions])
            prompt = f"""You are an expert forex trading analyst.

Analyze the following trading conditions for potential success:

{conditions_text}

Provide:
1. Analysis of each condition\'s effectiveness
2. Overall probability of conditions being met (0-100%)
3. Risk assessment
4. Alternative conditions to improve success rate
5. Timeframe recommendations

Return only a JSON object, no markdown."""
            analysis = await _ai_client.chat_completion_json(
                messages=[{"role": "user", "content": prompt}],
                fallback={"confidence": 50, "risk_level": "medium",
                          "analysis": "AI analysis unavailable",
                          "suggestions": ["Configure DEEPSEEK_API_KEY for full analysis"]}
            )
            return {"success": True, "message": "Conditions analyzed successfully", "analysis": analysis}
        except Exception as e:
            return {"success": False, "message": f"AI analysis failed: {str(e)}", "analysis": None}

    # Aliases for backward compatibility with any existing callers
    async def analyze_conditions_with_gemini(self, user_id: str, conditions: List[Dict]) -> Dict:
        return await self.analyze_conditions_with_ai(user_id, conditions)

    async def analyze_conditions_with_deepseek(self, user_id: str, conditions: List[Dict]) -> Dict:
        return await self.analyze_conditions_with_ai(user_id, conditions)

    async def generate_conditions_with_ai(self, user_id: str, pair: str, action: str, strategy: str) -> Dict:
        """Use DeepSeek AI to generate trading conditions from natural language strategy"""
        try:
            if not _ai_client.available:
                return {"success": False, "message": "AI unavailable - configure DEEPSEEK_API_KEY", "conditions": None}
            prompt = f"""You are an expert forex trading condition generator.

Generate trading conditions for:
- Currency Pair: {pair}
- Action: {action}
- Strategy: {strategy}

Each condition must have: condition_type, operator, value, description.
Return only a JSON array of conditions, no markdown."""
            result = await _ai_client.chat_completion_json(
                messages=[{"role": "user", "content": prompt}],
                fallback={}
            )
            conditions = result if isinstance(result, list) else result.get("conditions", [])
            return {"success": True, "message": "Conditions generated successfully", "conditions": conditions}
        except Exception as e:
            return {"success": False, "message": f"AI condition generation failed: {str(e)}", "conditions": None}

    # Aliases for backward compatibility
    async def generate_conditions_with_gemini(self, user_id: str, pair: str, action: str, strategy: str) -> Dict:
        return await self.generate_conditions_with_ai(user_id, pair, action, strategy)

    async def generate_conditions_with_deepseek(self, user_id: str, pair: str, action: str, strategy: str) -> Dict:
        return await self.generate_conditions_with_ai(user_id, pair, action, strategy)

    async def _evaluate_conditions(self, order: ConditionalOrder) -> bool:
        return False

    def _get_current_session(self) -> TradingSession:
        hour = datetime.utcnow().hour
        if hour >= 22 or hour < 8:
            return TradingSession.ASIAN
        elif 8 <= hour < 16:
            return TradingSession.LONDON
        elif 13 <= hour < 22:
            return TradingSession.NEW_YORK
        return TradingSession.OFF_HOURS

    async def get_order_status(self, order_id: str) -> Dict:
        for orders_list in self.pending_orders.values():
            for order in orders_list:
                if order.order_id == order_id:
                    return {
                        "order_id": order_id, "status": order.status.value,
                        "pair": order.pair, "action": order.action,
                        "conditions": [{"type": c.condition_type, "operator": c.operator,
                                        "value": c.value, "description": c.description}
                                       for c in order.conditions],
                        "created_at": order.created_at.isoformat(),
                        "max_execution_time": order.max_execution_time.isoformat() if order.max_execution_time else None,
                        "executed_at": order.executed_at.isoformat() if order.executed_at else None,
                    }
        return {"error": "Order not found"}

    async def cancel_order(self, order_id: str) -> Dict:
        for user_id, orders_list in self.pending_orders.items():
            for order in orders_list:
                if order.order_id == order_id:
                    order.status = OrderStatus.CANCELLED
                    if order_id in self.monitoring_tasks:
                        self.monitoring_tasks[order_id].cancel()
                    return {"success": True, "message": f"Order {order_id} cancelled",
                            "order_details": {"pair": order.pair, "action": order.action,
                                              "reason": "User initiated cancellation"}}
        return {"error": "Order not found"}

    async def get_active_orders(self, user_id: str) -> Dict:
        orders = self.pending_orders.get(user_id, [])
        active = [o for o in orders if o.status == OrderStatus.PENDING]
        return {"orders": [{"order_id": o.order_id, "pair": o.pair, "action": o.action,
                             "conditions_count": len(o.conditions),
                             "session_filter": o.session_filter.value if o.session_filter else "any",
                             "max_execution_time": o.max_execution_time.isoformat() if o.max_execution_time else None,
                             "created_at": o.created_at.isoformat()} for o in active]}

    async def get_session_analysis(self) -> Dict:
        current_session = self._get_current_session()
        return {
            "current_session": current_session.value,
            "sessions": {
                session.value: {
                    "average_volatility": stats.average_volatility,
                    "average_spread": f"{stats.average_spread} pips",
                    "volume": stats.typical_volume,
                    "best_pairs": stats.best_trading_pairs,
                    "activity": f"Peak between {min(stats.peak_activity_hours):02d}:00 - {max(stats.peak_activity_hours):02d}:00 UTC"
                } for session, stats in self.session_stats.items()
            },
            "recommendation": await self._get_session_recommendation(current_session)
        }

    async def _get_session_recommendation(self, current_session: TradingSession) -> str:
        if current_session == TradingSession.LONDON:
            return "Highest volatility and volume - excellent for scalping and swing trades"
        elif current_session == TradingSession.NEW_YORK:
            return "High volatility with strong trends - good for trend-following strategies"
        elif current_session == TradingSession.ASIAN:
            return "Lower volatility but good for pairs like USD/JPY - suited for patience"
        return "Off-hours trading - lower liquidity, wider spreads, consider waiting"

    async def create_time_bound_order(self, user_id, pair, action, position_size,
                                       stop_loss, take_profit, execution_window_hours=12,
                                       session_preference=None) -> Dict:
        condition = Condition(condition_type="time", operator="<=",
                              value=execution_window_hours,
                              description=f"Execute within next {execution_window_hours} hours")
        return await self.create_conditional_order(
            user_id=user_id, pair=pair, action=action,
            conditions=[{"type": condition.condition_type, "operator": condition.operator,
                         "value": condition.value, "description": condition.description}],
            position_size=position_size, stop_loss=stop_loss, take_profit=take_profit,
            max_hours=execution_window_hours, session_filter=session_preference, order_type="limit"
        )

    async def create_session_aware_order(self, user_id, pair, action, position_size,
                                          stop_loss, take_profit, preferred_session="london") -> Dict:
        return await self.create_conditional_order(
            user_id=user_id, pair=pair, action=action,
            conditions=[{"type": "session", "operator": "==", "value": preferred_session,
                         "description": f"Trade only during {preferred_session.upper()} session"}],
            position_size=position_size, stop_loss=stop_loss, take_profit=take_profit,
            session_filter=preferred_session, max_hours=24
        )

    async def get_execution_intelligence_panel(self) -> Dict:
        current_session = self._get_current_session()
        stats = self.session_stats[current_session]
        return {
            "current_trading_environment": {
                "session": current_session.value.upper(),
                "volatility": "HIGH" if stats.average_volatility > 1.0 else "MEDIUM" if stats.average_volatility > 0.7 else "LOW",
                "spread": f"~{stats.average_spread} pips",
                "volume": stats.typical_volume.upper(),
                "optimal_pairs": stats.best_trading_pairs,
            },
            "recommendations": {
                "order_type": "MARKET" if current_session != TradingSession.OFF_HOURS else "LIMIT",
                "position_sizing": "Normal" if current_session in [TradingSession.LONDON, TradingSession.NEW_YORK] else "Conservative",
                "session_lock": current_session != TradingSession.OFF_HOURS,
                "message": await self._get_session_recommendation(current_session)
            },
            "next_session": self._get_next_session(current_session).value.upper(),
        }

    def _get_next_session(self, current: TradingSession) -> TradingSession:
        order = [TradingSession.ASIAN, TradingSession.LONDON, TradingSession.NEW_YORK]
        try:
            return order[(order.index(current) + 1) % len(order)]
        except ValueError:
            return TradingSession.ASIAN

    async def get_order_history(self, user_id: str, limit: int = 20) -> List[Dict]:
        recent = [o for o in self.order_history if o.user_id == user_id][-limit:]
        return [{"order_id": o.order_id, "pair": o.pair, "action": o.action,
                 "status": o.status.value, "created_at": o.created_at.isoformat(),
                 "executed_at": o.executed_at.isoformat() if o.executed_at else None,
                 "execution_price": o.execution_price, "conditions": len(o.conditions)}
                for o in recent]
'''

# ── FILE 3: app/ai_forex_engine.py ────────────────────────────────────────
ai_forex_engine = '''"""
AI-Powered Forex Trading Engine
Autonomous trading system that works while you sleep
Uses DeepSeek AI for intelligent decision-making
"""
import aiohttp
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
import numpy as np
from dataclasses import dataclass
import json

from .ai import RiskEngine, StrategyEngine, deepseek_client


@dataclass
class TradingSignal:
    pair: str
    action: str
    confidence: float
    entry_price: float
    stop_loss: float
    take_profit: float
    reason: str
    timestamp: datetime


@dataclass
class MarketCondition:
    pair: str
    current_price: float
    trend: str
    volatility: float
    support_level: float
    resistance_level: float
    rsi: float
    macd: Dict[str, float]


class ForexAIEngine:

    def __init__(self):
        self.session: Optional[aiohttp.ClientSession] = None
        self.active_positions: Dict[str, Dict] = {}
        self.user_preferences: Dict[str, Any] = {}
        self.strategy_engine = StrategyEngine()
        self.risk_engine = RiskEngine()

    async def initialize(self):
        if not self.session:
            self.session = aiohttp.ClientSession()

    async def close(self):
        if self.session:
            await self.session.close()
            self.session = None

    async def fetch_live_rates(self) -> Dict[str, float]:
        try:
            url = "https://api.exchangerate-api.com/v4/latest/USD"
            async with self.session.get(url, timeout=10) as response:
                if response.status == 200:
                    data = await response.json()
                    return {
                        "EUR/USD": 1 / data["rates"]["EUR"],
                        "GBP/USD": 1 / data["rates"]["GBP"],
                        "USD/JPY": data["rates"]["JPY"],
                        "USD/CHF": data["rates"]["CHF"],
                        "AUD/USD": 1 / data["rates"]["AUD"],
                        "USD/CAD": data["rates"]["CAD"],
                        "NZD/USD": 1 / data["rates"]["NZD"],
                        "EUR/GBP": data["rates"]["GBP"] / data["rates"]["EUR"],
                    }
        except Exception as e:
            print(f"Error fetching rates: {e}")
        return {}

    def calculate_rsi(self, prices: List[float], period: int = 14) -> float:
        if len(prices) < period + 1:
            return 50.0
        deltas = np.diff(prices)
        gains = np.where(deltas > 0, deltas, 0)
        losses = np.where(deltas < 0, -deltas, 0)
        avg_gain = np.mean(gains[:period])
        avg_loss = np.mean(losses[:period])
        if avg_loss == 0:
            return 100.0
        return 100 - (100 / (1 + avg_gain / avg_loss))

    def calculate_macd(self, prices: List[float]) -> Dict[str, float]:
        if len(prices) < 26:
            return {"macd": 0, "signal": 0, "histogram": 0}
        prices_array = np.array(prices)
        ema_12 = self._calculate_ema(prices_array, 12)
        ema_26 = self._calculate_ema(prices_array, 26)
        macd_line = ema_12 - ema_26
        signal_line = self._calculate_ema(np.array([macd_line]), 9)
        return {"macd": macd_line, "signal": signal_line, "histogram": macd_line - signal_line}

    def _calculate_ema(self, prices: np.ndarray, period: int) -> float:
        multiplier = 2 / (period + 1)
        ema = prices[0]
        for price in prices[1:]:
            ema = (price * multiplier) + (ema * (1 - multiplier))
        return ema

    def identify_support_resistance(self, prices: List[float]) -> Tuple[float, float]:
        recent = prices[-50:] if len(prices) > 50 else prices
        return min(recent), max(recent)

    async def analyze_market_conditions(self, pair: str, historical_prices: List[float]) -> MarketCondition:
        current_price = historical_prices[-1]
        rsi = self.calculate_rsi(historical_prices)
        macd = self.calculate_macd(historical_prices)
        support, resistance = self.identify_support_resistance(historical_prices)
        sma_20 = np.mean(historical_prices[-20:])
        sma_50 = np.mean(historical_prices[-50:]) if len(historical_prices) >= 50 else sma_20
        if sma_20 > sma_50 and current_price > sma_20:
            trend = "BULLISH"
        elif sma_20 < sma_50 and current_price < sma_20:
            trend = "BEARISH"
        else:
            trend = "SIDEWAYS"
        return MarketCondition(
            pair=pair, current_price=current_price, trend=trend,
            volatility=float(np.std(historical_prices[-20:])),
            support_level=support, resistance_level=resistance, rsi=rsi, macd=macd
        )

    async def generate_trading_signal_with_ai(
        self, pair: str, market_condition: MarketCondition,
        user_strategy: Dict, historical_data: List[Dict]
    ) -> TradingSignal:
        try:
            if not deepseek_client.available:
                return await self.generate_trading_signal(pair, market_condition, user_strategy)

            prompt = f"""You are an expert forex trading signal generator.

MARKET CONDITIONS FOR {pair}:
- Current Price: {market_condition.current_price:.5f}
- Trend: {market_condition.trend}
- RSI: {market_condition.rsi:.1f}
- MACD: {market_condition.macd["macd"]:.3f}
- Volatility: {market_condition.volatility:.5f}
- Support: {market_condition.support_level:.5f}
- Resistance: {market_condition.resistance_level:.5f}

USER STRATEGY:
{json.dumps(user_strategy, indent=2)}

Generate a trading signal. Return only a JSON object with:
action, confidence, entry_price, stop_loss, take_profit, reason"""

            signal_data = deepseek_client.generate_json(model_name="deepseek-chat", prompt=prompt)
            if not signal_data:
                return await self.generate_trading_signal(pair, market_condition, user_strategy)

            return TradingSignal(
                pair=pair,
                action=signal_data.get("action", "HOLD"),
                confidence=signal_data.get("confidence", 0.0),
                entry_price=signal_data.get("entry_price", market_condition.current_price),
                stop_loss=signal_data.get("stop_loss", 0.0),
                take_profit=signal_data.get("take_profit", 0.0),
                reason=signal_data.get("reason", "AI analysis"),
                timestamp=datetime.now()
            )
        except Exception as e:
            print(f"AI signal generation failed: {e}")
            return await self.generate_trading_signal(pair, market_condition, user_strategy)

    # Aliases for backward compatibility
    async def generate_trading_signal_with_gemini(self, pair, market_condition, user_strategy, historical_data):
        return await self.generate_trading_signal_with_ai(pair, market_condition, user_strategy, historical_data)

    async def generate_trading_signal_with_deepseek(self, pair, market_condition, user_strategy, historical_data):
        return await self.generate_trading_signal_with_ai(pair, market_condition, user_strategy, historical_data)

    async def generate_trading_signal(self, pair, market_condition, user_strategy) -> TradingSignal:
        _ = user_strategy
        decision = self.strategy_engine.generate_signal(market_condition)
        return TradingSignal(
            pair=pair, action=decision.action, confidence=decision.confidence,
            entry_price=decision.entry_price, stop_loss=decision.stop_loss,
            take_profit=decision.take_profit, reason=decision.reason, timestamp=datetime.now()
        )

    async def analyze_portfolio_performance(self, portfolio_data: Dict) -> Dict[str, Any]:
        try:
            if not deepseek_client.available:
                return self._get_default_portfolio_analysis(portfolio_data)
            prompt = f"""You are an expert portfolio analyst.
Analyze this forex trading portfolio:
{json.dumps(portfolio_data, indent=2)}
Return only a JSON object with: performance, risk_level, profitability, recommendations, next_steps."""
            analysis = deepseek_client.generate_json(model_name="deepseek-chat", prompt=prompt)
            if analysis:
                analysis["timestamp"] = datetime.now().isoformat()
                return analysis
        except Exception as e:
            print(f"Portfolio analysis failed: {e}")
        return self._get_default_portfolio_analysis(portfolio_data)

    def _get_default_portfolio_analysis(self, portfolio_data: Dict) -> Dict[str, Any]:
        return {
            "timestamp": datetime.now().isoformat(),
            "performance": "stable", "risk_level": "moderate",
            "profitability": {"overall": portfolio_data.get("total_pnl", 0)},
            "recommendations": ["Review trading strategy", "Monitor key pairs"],
            "next_steps": ["Continue monitoring", "Consider adjustments"]
        }

    async def execute_auto_trade(self, signal: TradingSignal, user_limits: Dict) -> Dict:
        allowed, reason = self.risk_engine.can_execute_signal(signal, min_confidence=0.6)
        if not allowed:
            return {"executed": False, "reason": reason}
        trade = self.risk_engine.build_trade(signal, user_limits)
        self.active_positions[signal.pair] = trade
        return {"executed": True, "trade": trade, "signal": signal}

    async def monitor_positions(self, current_rates: Dict[str, float]):
        closed_trades = []
        for pair, position in list(self.active_positions.items()):
            if pair not in current_rates:
                continue
            closed_trade = self.risk_engine.evaluate_position(position, float(current_rates[pair]))
            if closed_trade:
                closed_trades.append(closed_trade)
                del self.active_positions[pair]
        return closed_trades

    async def forecast_price_movement(self, pair, historical_prices, horizon_hours=24) -> Dict:
        if len(historical_prices) < 10:
            return {"error": "Insufficient data"}
        x = np.arange(len(historical_prices))
        y = np.array(historical_prices)
        coeffs = np.polyfit(x, y, 1)
        forecasted_price = np.polyval(coeffs, len(historical_prices) - 1 + horizon_hours)
        y_pred = np.polyval(coeffs, x)
        ss_res = np.sum((y - y_pred) ** 2)
        ss_tot = np.sum((y - np.mean(y)) ** 2)
        return {
            "pair": pair, "current_price": historical_prices[-1],
            "forecasted_price": float(forecasted_price),
            "expected_change": float(forecasted_price - historical_prices[-1]),
            "confidence": float(1 - ss_res / ss_tot),
            "trend": "UP" if coeffs[0] > 0 else "DOWN",
            "horizon_hours": horizon_hours
        }


ai_engine = ForexAIEngine()
'''

# ── Write all files ────────────────────────────────────────────────────────
files = {
    Path("app/services/signal_service.py"):                  signal_service,
    Path("app/services/execution_intelligence_service.py"):  execution_intelligence_service,
    Path("app/ai_forex_engine.py"):                          ai_forex_engine,
}

for path, content in files.items():
    path.write_text(content, encoding="utf-8")
    print(f"[OK] Written: {path}  ({len(content.splitlines())} lines)")

print("\n[DONE] All 3 files written. Now run the verification scan:")
print('Get-ChildItem -Path app -Recurse -Filter "*.py" | Select-String -Pattern "gemini|GeminiClient|google.generativeai|genai\\." | Select-Object Filename, LineNumber, Line')
