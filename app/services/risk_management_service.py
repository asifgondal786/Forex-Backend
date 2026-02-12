"""
Risk Management & Governance Service
Implements comprehensive trading safety controls
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from enum import Enum
import asyncio


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

    async def initialize_user_limits(self, user_id: str, limits: RiskLimits):
        """Initialize risk limits for a user"""
        self.user_limits[user_id] = limits
        self.active_trades[user_id] = []
        self.kill_switch_active[user_id] = False
        
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
        
        # Check 1: Position size limit
        position_size = trade_params.get("position_size", 0)
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
        
        # Check 5: Validate Stop-Loss distance
        entry_price = trade_params.get("entry_price", 0)
        stop_loss = trade_params.get("stop_loss", 0)
        if entry_price and stop_loss:
            sl_distance = abs((entry_price - stop_loss) / entry_price) * 100
            if sl_distance < 0.5:  # Less than 0.5% stop loss
                return False, f"Stop-Loss too close to entry (0.5% minimum)"
        
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
                "is_paper_trade": trade.is_paper_trade
            }
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
        
        return {
            "user_id": user_id,
            "risk_level": risk_level,
            "kill_switch_active": self.kill_switch_active.get(user_id, False),
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
