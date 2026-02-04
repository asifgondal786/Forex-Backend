"""
Execution Intelligence Service
Handles conditional automation, time-bound orders, and session-aware trading
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Callable
from enum import Enum
import asyncio


class TradingSession(Enum):
    """Major forex trading sessions"""
    ASIAN = "asian"  # 22:00 UTC - 08:00 UTC (previous day)
    LONDON = "london"  # 08:00 UTC - 16:00 UTC
    NEW_YORK = "new_york"  # 13:00 UTC - 22:00 UTC
    OFF_HOURS = "off_hours"


class OrderType(Enum):
    """Types of conditional orders"""
    MARKET = "market"
    LIMIT = "limit"
    STOP_LOSS = "stop_loss"
    TAKE_PROFIT = "take_profit"
    OCO = "one_cancels_other"
    IF_TOUCHED = "if_touched"


class OrderStatus(Enum):
    """Status of a conditional order"""
    PENDING = "pending"
    TRIGGERED = "triggered"
    EXECUTED = "executed"
    CANCELLED = "cancelled"
    EXPIRED = "expired"


@dataclass
class Condition:
    """Single condition for order execution"""
    condition_type: str  # "price_level", "indicator_value", "time", "sentiment"
    operator: str  # "==", ">", "<", ">=", "<=", "!=", "crosses"
    value: float
    description: str


@dataclass
class ConditionalOrder:
    """Order with multiple execution conditions"""
    order_id: str
    user_id: str
    pair: str
    action: str  # BUY, SELL
    conditions: List[Condition]
    
    # Optional fields (with defaults)
    all_conditions_must_match: bool = True  # AND vs OR logic
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
    """Statistics for trading sessions"""
    session: TradingSession
    average_volatility: float
    average_spread: float
    typical_volume: str  # "low", "medium", "high"
    best_trading_pairs: List[str]
    peak_activity_hours: List[int]


class ExecutionIntelligenceService:
    """
    Handles conditional automation and intelligent order execution
    """
    
    def __init__(self):
        self.pending_orders: Dict[str, List[ConditionalOrder]] = {}
        self.order_history: List[ConditionalOrder] = []
        self.session_stats = self._initialize_session_stats()
        self.monitoring_tasks: Dict[str, asyncio.Task] = {}

    def _initialize_session_stats(self) -> Dict[TradingSession, SessionStatistics]:
        """Initialize known session statistics"""
        return {
            TradingSession.ASIAN: SessionStatistics(
                session=TradingSession.ASIAN,
                average_volatility=0.6,
                average_spread=1.2,
                typical_volume="medium",
                best_trading_pairs=["USD/JPY", "AUD/USD", "NZD/USD"],
                peak_activity_hours=[0, 1, 2, 3, 4, 5, 6, 7]
            ),
            TradingSession.LONDON: SessionStatistics(
                session=TradingSession.LONDON,
                average_volatility=1.2,
                average_spread=0.8,
                typical_volume="high",
                best_trading_pairs=["EUR/USD", "GBP/USD", "EUR/GBP"],
                peak_activity_hours=[8, 9, 10, 11, 12]
            ),
            TradingSession.NEW_YORK: SessionStatistics(
                session=TradingSession.NEW_YORK,
                average_volatility=1.0,
                average_spread=0.9,
                typical_volume="high",
                best_trading_pairs=["EUR/USD", "GBP/USD", "USD/CAD"],
                peak_activity_hours=[13, 14, 15, 16, 17, 18, 19, 20]
            ),
        }

    async def create_conditional_order(
        self,
        user_id: str,
        pair: str,
        action: str,
        conditions: List[Dict],
        position_size: float,
        stop_loss: Optional[float] = None,
        take_profit: Optional[float] = None,
        max_hours: int = 12,
        session_filter: Optional[str] = None,
        order_type: str = "market",
        notes: str = ""
    ) -> Dict:
        """
        Create a conditional order
        Example: "Sell USD at 289 PKR only if RSI < 70 and trend is bearish"
        """
        
        # Parse conditions
        parsed_conditions = []
        for cond in conditions:
            parsed_conditions.append(Condition(
                condition_type=cond.get("type"),
                operator=cond.get("operator"),
                value=cond.get("value"),
                description=cond.get("description", "")
            ))
        
        # Create order
        order_id = f"order_{user_id}_{datetime.now().timestamp()}"
        max_exec_time = datetime.now() + timedelta(hours=max_hours) if max_hours else None
        
        session = None
        if session_filter:
            try:
                session = TradingSession[session_filter.upper()]
            except KeyError:
                pass
        
        order = ConditionalOrder(
            order_id=order_id,
            user_id=user_id,
            pair=pair,
            action=action,
            conditions=parsed_conditions,
            position_size=position_size,
            stop_loss=stop_loss,
            take_profit=take_profit,
            max_execution_time=max_exec_time,
            session_filter=session,
            order_type=OrderType[order_type.upper()] if order_type else OrderType.MARKET,
            notes=notes
        )
        
        # Store order
        if user_id not in self.pending_orders:
            self.pending_orders[user_id] = []
        self.pending_orders[user_id].append(order)
        
        # Start monitoring task
        task = asyncio.create_task(self._monitor_order(order))
        self.monitoring_tasks[order_id] = task
        
        return {
            "success": True,
            "order_id": order_id,
            "message": f"Conditional order created with {len(parsed_conditions)} conditions",
            "details": {
                "pair": pair,
                "action": action,
                "conditions": [c.description for c in parsed_conditions],
                "max_execution_time": max_exec_time.isoformat() if max_exec_time else "indefinite",
                "session_filter": session_filter or "any"
            }
        }

    async def _monitor_order(self, order: ConditionalOrder):
        """Monitor a conditional order for execution"""
        while order.status == OrderStatus.PENDING:
            # Check if expired
            if order.max_execution_time and datetime.now() > order.max_execution_time:
                order.status = OrderStatus.EXPIRED
                break
            
            # Check session filter
            if order.session_filter:
                current_session = self._get_current_session()
                if current_session != order.session_filter:
                    await asyncio.sleep(60)  # Check every minute
                    continue
            
            # Check conditions (simulated)
            # In production, this would fetch live data and evaluate conditions
            conditions_met = await self._evaluate_conditions(order)
            
            if conditions_met:
                order.status = OrderStatus.TRIGGERED
                order.executed_at = datetime.now()
                break
            
            await asyncio.sleep(30)  # Check every 30 seconds

    async def _evaluate_conditions(self, order: ConditionalOrder) -> bool:
        """Evaluate if all conditions for an order are met"""
        # Placeholder: In production, fetch live data and evaluate
        # For now, return False (conditions not met)
        return False

    def _get_current_session(self) -> TradingSession:
        """Determine current trading session based on UTC time"""
        hour = datetime.utcnow().hour
        
        # Asian: 22:00 - 08:00 (previous day)
        if hour >= 22 or hour < 8:
            return TradingSession.ASIAN
        # London: 08:00 - 16:00
        elif hour >= 8 and hour < 16:
            return TradingSession.LONDON
        # New York: 13:00 - 22:00
        elif hour >= 13 and hour < 22:
            return TradingSession.NEW_YORK
        else:
            return TradingSession.OFF_HOURS

    async def get_order_status(self, order_id: str) -> Dict:
        """Get status of a conditional order"""
        for orders_list in self.pending_orders.values():
            for order in orders_list:
                if order.order_id == order_id:
                    return {
                        "order_id": order_id,
                        "status": order.status.value,
                        "pair": order.pair,
                        "action": order.action,
                        "conditions": [
                            {
                                "type": c.condition_type,
                                "operator": c.operator,
                                "value": c.value,
                                "description": c.description
                            }
                            for c in order.conditions
                        ],
                        "created_at": order.created_at.isoformat(),
                        "max_execution_time": order.max_execution_time.isoformat() if order.max_execution_time else None,
                        "executed_at": order.executed_at.isoformat() if order.executed_at else None,
                    }
        
        return {"error": "Order not found"}

    async def cancel_order(self, order_id: str) -> Dict:
        """Cancel a pending conditional order"""
        for user_id, orders_list in self.pending_orders.items():
            for order in orders_list:
                if order.order_id == order_id:
                    order.status = OrderStatus.CANCELLED
                    if order_id in self.monitoring_tasks:
                        self.monitoring_tasks[order_id].cancel()
                    return {
                        "success": True,
                        "message": f"Order {order_id} cancelled",
                        "order_details": {
                            "pair": order.pair,
                            "action": order.action,
                            "reason": "User initiated cancellation"
                        }
                    }
        
        return {"error": "Order not found"}

    async def get_active_orders(self, user_id: str) -> List[Dict]:
        """Get all active conditional orders for a user"""
        orders = self.pending_orders.get(user_id, [])
        active = [o for o in orders if o.status == OrderStatus.PENDING]
        
        return [
            {
                "order_id": o.order_id,
                "pair": o.pair,
                "action": o.action,
                "conditions_count": len(o.conditions),
                "session_filter": o.session_filter.value if o.session_filter else "any",
                "max_execution_time": o.max_execution_time.isoformat() if o.max_execution_time else None,
                "created_at": o.created_at.isoformat(),
            }
            for o in active
        ]

    async def get_session_analysis(self) -> Dict:
        """Get analysis for all trading sessions"""
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
                }
                for session, stats in self.session_stats.items()
            },
            "recommendation": await self._get_session_recommendation(current_session)
        }

    async def _get_session_recommendation(self, current_session: TradingSession) -> str:
        """Get trading recommendation for current session"""
        if current_session == TradingSession.LONDON:
            return "Highest volatility and volume - excellent for scalping and swing trades"
        elif current_session == TradingSession.NEW_YORK:
            return "High volatility with strong trends - good for trend-following strategies"
        elif current_session == TradingSession.ASIAN:
            return "Lower volatility but good for pairs like USD/JPY - suited for patience"
        else:
            return "Off-hours trading - lower liquidity, wider spreads, consider waiting"

    async def create_time_bound_order(
        self,
        user_id: str,
        pair: str,
        action: str,
        position_size: float,
        stop_loss: float,
        take_profit: float,
        execution_window_hours: int = 12,
        session_preference: Optional[str] = None
    ) -> Dict:
        """
        Create a time-bound order that only executes within specified window
        Example: "Execute this limit order only within next 12 hours"
        """
        
        condition = Condition(
            condition_type="time",
            operator="<=",
            value=execution_window_hours,
            description=f"Execute within next {execution_window_hours} hours"
        )
        
        result = await self.create_conditional_order(
            user_id=user_id,
            pair=pair,
            action=action,
            conditions=[{
                "type": condition.condition_type,
                "operator": condition.operator,
                "value": condition.value,
                "description": condition.description
            }],
            position_size=position_size,
            stop_loss=stop_loss,
            take_profit=take_profit,
            max_hours=execution_window_hours,
            session_filter=session_preference,
            order_type="limit"
        )
        
        return result

    async def create_session_aware_order(
        self,
        user_id: str,
        pair: str,
        action: str,
        position_size: float,
        stop_loss: float,
        take_profit: float,
        preferred_session: str = "london"  # "asian", "london", "new_york"
    ) -> Dict:
        """
        Create order that only executes during specified trading session
        Useful for pairs that trade best in specific sessions
        """
        
        return await self.create_conditional_order(
            user_id=user_id,
            pair=pair,
            action=action,
            conditions=[{
                "type": "session",
                "operator": "==",
                "value": preferred_session,
                "description": f"Trade only during {preferred_session.upper()} session"
            }],
            position_size=position_size,
            stop_loss=stop_loss,
            take_profit=take_profit,
            session_filter=preferred_session,
            max_hours=24  # Valid for 24 hours
        )

    async def get_execution_intelligence_panel(self) -> Dict:
        """Get comprehensive execution intelligence panel for UI"""
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
        """Get next trading session"""
        order = [TradingSession.ASIAN, TradingSession.LONDON, TradingSession.NEW_YORK]
        try:
            idx = order.index(current)
            return order[(idx + 1) % len(order)]
        except ValueError:
            return TradingSession.ASIAN

    async def get_order_history(self, user_id: str, limit: int = 20) -> List[Dict]:
        """Get order execution history"""
        all_orders = [o for o in self.order_history if o.user_id == user_id]
        recent = all_orders[-limit:]
        
        return [
            {
                "order_id": o.order_id,
                "pair": o.pair,
                "action": o.action,
                "status": o.status.value,
                "created_at": o.created_at.isoformat(),
                "executed_at": o.executed_at.isoformat() if o.executed_at else None,
                "execution_price": o.execution_price,
                "conditions": len(o.conditions),
            }
            for o in recent
        ]
