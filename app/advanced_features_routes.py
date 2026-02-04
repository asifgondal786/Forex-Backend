"""
Advanced Features API Routes
Integrates all autonomous trading features
Risk Management, Explainability, Execution Intelligence, Paper Trading, NLP
"""
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional, List, Dict
from datetime import datetime

# Import services
from .services.risk_management_service import RiskManagementService, RiskLimits
from .services.prediction_explainability_service import PredictionExplainabilityService
from .services.execution_intelligence_service import ExecutionIntelligenceService
from .services.security_compliance_service import SecurityComplianceService
from .services.enhanced_notification_service import EnhancedNotificationService
from .services.paper_trading_engine import PaperTradingEngine
from .services.natural_language_service import NaturalLanguageService

# Initialize services (in production, use dependency injection)
risk_manager = RiskManagementService()
explainability_svc = PredictionExplainabilityService()
execution_svc = ExecutionIntelligenceService()
security_svc = SecurityComplianceService()
notification_svc = EnhancedNotificationService()
paper_trading = PaperTradingEngine()
nlp_svc = NaturalLanguageService()

router = APIRouter(prefix="/api/advanced", tags=["Advanced Trading Features"])

# ============================================================================
# RISK MANAGEMENT ENDPOINTS
# ============================================================================

class RiskLimitsRequest(BaseModel):
    max_trade_size: float
    daily_loss_limit: float
    max_open_positions: int
    max_drawdown_percent: float
    mandatory_stop_loss: bool = True
    mandatory_take_profit: bool = True


@router.post("/risk/initialize-limits")
async def initialize_risk_limits(user_id: str, limits: RiskLimitsRequest):
    """Initialize risk management limits for a user"""
    risk_limits = RiskLimits(
        max_trade_size=limits.max_trade_size,
        daily_loss_limit=limits.daily_loss_limit,
        max_open_positions=limits.max_open_positions,
        max_drawdown_percent=limits.max_drawdown_percent,
        mandatory_stop_loss=limits.mandatory_stop_loss,
        mandatory_take_profit=limits.mandatory_take_profit,
    )
    return await risk_manager.initialize_user_limits(user_id, risk_limits)


@router.post("/risk/validate-trade")
async def validate_trade(user_id: str, trade_params: Dict):
    """Validate if a trade meets risk requirements"""
    is_valid, reason = await risk_manager.validate_trade(user_id, trade_params)
    return {
        "valid": is_valid,
        "reason": reason,
        "timestamp": datetime.now().isoformat()
    }


@router.post("/risk/execute-trade")
async def execute_trade_with_risk_check(user_id: str, trade_params: Dict):
    """Execute trade with automatic risk checks"""
    return await risk_manager.execute_trade_with_safety(user_id, trade_params)


@router.post("/risk/close-trade")
async def close_trade_with_pl(user_id: str, trade_id: str, exit_price: float):
    """Close a trade and calculate P&L"""
    return await risk_manager.close_trade(user_id, trade_id, exit_price)


@router.post("/risk/kill-switch")
async def activate_kill_switch(user_id: str):
    """
    EMERGENCY: Activate kill switch to stop all trading immediately
    """
    result = await risk_manager.activate_kill_switch(user_id)
    
    # Send critical notification
    await notification_svc.send_notification(
        user_id=user_id,
        template_id="risk_warning",
        category="RISK_WARNING",
        priority="critical",
        warning_text="KILL SWITCH ACTIVATED - All trading disabled"
    )
    
    return result


@router.get("/risk/assessment/{user_id}")
async def get_risk_assessment(user_id: str):
    """Get comprehensive risk assessment"""
    return await risk_manager.get_risk_assessment(user_id)


@router.get("/risk/analytics/{user_id}")
async def get_trading_analytics(user_id: str, days: int = 30):
    """Get trading analytics"""
    return await risk_manager.get_trading_analytics(user_id, days)


# ============================================================================
# PREDICTION EXPLAINABILITY ENDPOINTS
# ============================================================================

@router.post("/explain/generate-prediction")
async def generate_prediction_explanation(
    pair: str,
    action: str,
    technical_indicators: List[Dict],
    sentiment_data: Dict,
    news_data: Dict,
    support_resistance: Dict,
    confidence_score: float
):
    """Generate detailed explanation for a prediction"""
    explanation = await explainability_svc.generate_prediction_explanation(
        pair=pair,
        action=action,
        technical_indicators=technical_indicators,
        sentiment_data=sentiment_data,
        news_data=news_data,
        support_resistance=support_resistance,
        confidence_score=confidence_score
    )
    return {
        "prediction_id": explanation.prediction_id,
        "pair": pair,
        "action": action,
        "confidence": f"{confidence_score:.1f}%",
        "why_this_trade": {
            "key_reasons": explanation.key_reasons,
            "bullish_factors": explanation.bullish_factors,
            "bearish_factors": explanation.bearish_factors,
        },
        "sentiment": explanation.sentiment.value,
        "indicators_summary": {
            "bullish": explanation.indicators_bullish,
            "bearish": explanation.indicators_bearish,
            "neutral": explanation.indicators_neutral,
        },
        "convergence_strength": f"{explanation.convergence_strength:.1f}%",
        "timestamp": datetime.now().isoformat()
    }


@router.get("/explain/detailed/{prediction_id}")
async def get_detailed_explanation(prediction_id: str):
    """Get detailed explanation panel for a prediction"""
    return await explainability_svc.get_detailed_explanation(prediction_id)


@router.get("/explain/history")
async def get_prediction_history(pair: Optional[str] = None, limit: int = 10):
    """Get prediction history"""
    return await explainability_svc.get_prediction_history(pair, limit)


@router.get("/explain/accuracy-report")
async def get_accuracy_report(pair: Optional[str] = None, days: int = 30):
    """Get prediction accuracy report"""
    return await explainability_svc.get_accuracy_report(pair, days)


# ============================================================================
# EXECUTION INTELLIGENCE ENDPOINTS
# ============================================================================

class ConditionalOrderRequest(BaseModel):
    pair: str
    action: str
    conditions: List[Dict]
    position_size: float
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    max_hours: int = 12
    session_filter: Optional[str] = None
    notes: Optional[str] = None


@router.post("/execution/conditional-order")
async def create_conditional_order(user_id: str, request: ConditionalOrderRequest):
    """
    Create conditional order
    Example: "Sell USD at 289 PKR only if RSI < 70 and trend is bearish"
    """
    return await execution_svc.create_conditional_order(
        user_id=user_id,
        pair=request.pair,
        action=request.action,
        conditions=request.conditions,
        position_size=request.position_size,
        stop_loss=request.stop_loss,
        take_profit=request.take_profit,
        max_hours=request.max_hours,
        session_filter=request.session_filter,
        notes=request.notes
    )


@router.get("/execution/order-status/{order_id}")
async def get_order_status(order_id: str):
    """Get status of a conditional order"""
    return await execution_svc.get_order_status(order_id)


@router.delete("/execution/cancel-order/{order_id}")
async def cancel_order(order_id: str):
    """Cancel a pending order"""
    return await execution_svc.cancel_order(order_id)


@router.get("/execution/active-orders/{user_id}")
async def get_active_orders(user_id: str):
    """Get all active conditional orders"""
    return await execution_svc.get_active_orders(user_id)


@router.get("/execution/session-analysis")
async def get_session_analysis():
    """Get trading session analysis"""
    return await execution_svc.get_session_analysis()


@router.post("/execution/time-bound-order")
async def create_time_bound_order(
    user_id: str,
    pair: str,
    action: str,
    position_size: float,
    stop_loss: float,
    take_profit: float,
    execution_window_hours: int = 12
):
    """Create time-bound order"""
    return await execution_svc.create_time_bound_order(
        user_id=user_id,
        pair=pair,
        action=action,
        position_size=position_size,
        stop_loss=stop_loss,
        take_profit=take_profit,
        execution_window_hours=execution_window_hours
    )


@router.get("/execution/intelligence-panel")
async def get_execution_intelligence_panel():
    """Get execution intelligence panel"""
    return await execution_svc.get_execution_intelligence_panel()


# ============================================================================
# SECURITY & COMPLIANCE ENDPOINTS
# ============================================================================

@router.post("/security/api-key/create")
async def create_api_key(
    user_id: str,
    broker: str,
    scope: str = "trade_only",
    expires_in_days: Optional[int] = 365
):
    """Create API key for broker connection"""
    return await security_svc.create_api_key(user_id, broker, scope, expires_in_days)


@router.post("/security/api-key/revoke/{key_id}")
async def revoke_api_key(key_id: str, user_id: str):
    """Revoke an API key"""
    return await security_svc.revoke_api_key(key_id, user_id)


@router.get("/security/api-keys/{user_id}")
async def get_api_keys(user_id: str):
    """Get user's API keys (censored)"""
    return await security_svc.get_user_api_keys(user_id)


@router.post("/security/legal-acknowledge")
async def accept_legal_terms(
    user_id: str,
    ip_address: str,
    risk_disclaimer: bool = True,
    losses_understood: bool = True,
    autonomous_trading: bool = True,
    api_usage: bool = True,
    privacy: bool = True,
    terms: bool = True
):
    """Accept legal terms and compliance requirements"""
    return await security_svc.create_legal_acknowledgement(
        user_id=user_id,
        ip_address=ip_address,
        risk_disclaimer=risk_disclaimer,
        losses_understood=losses_understood,
        autonomous_trading=autonomous_trading,
        api_usage=api_usage,
        privacy=privacy,
        terms=terms
    )


@router.get("/security/legal-status/{user_id}")
async def get_legal_status(user_id: str):
    """Get legal compliance status"""
    return await security_svc.get_legal_status(user_id)


@router.get("/security/audit-log/{user_id}")
async def get_audit_log(user_id: str, limit: int = 50, days: int = 30):
    """Get audit log"""
    return await security_svc.get_audit_log(user_id, limit, days)


@router.get("/security/compliance-report/{user_id}")
async def generate_compliance_report(user_id: str):
    """Generate compliance report"""
    return await security_svc.generate_compliance_report(user_id)


@router.get("/security/dashboard/{user_id}")
async def get_security_dashboard(user_id: str):
    """Get security dashboard"""
    return await security_svc.get_security_dashboard(user_id)


# ============================================================================
# NOTIFICATIONS ENDPOINTS
# ============================================================================

@router.post("/notifications/preferences")
async def set_notification_preferences(
    user_id: str,
    enabled_channels: Optional[List[str]] = None,
    disabled_categories: Optional[List[str]] = None,
    quiet_hours_start: Optional[str] = None,
    quiet_hours_end: Optional[str] = None
):
    """Set notification preferences"""
    return await notification_svc.set_notification_preferences(
        user_id=user_id,
        enabled_channels=enabled_channels,
        disabled_categories=disabled_categories,
        quiet_hours_start=quiet_hours_start,
        quiet_hours_end=quiet_hours_end
    )


@router.post("/notifications/send")
async def send_notification(
    user_id: str,
    template_id: str,
    category: str,
    priority: str = "medium",
    **kwargs
):
    """Send notification"""
    return await notification_svc.send_notification(
        user_id=user_id,
        template_id=template_id,
        category=category,
        priority=priority,
        **kwargs
    )


@router.get("/notifications/list/{user_id}")
async def get_notifications(user_id: str, unread_only: bool = False, limit: int = 20):
    """Get user notifications"""
    return await notification_svc.get_notifications(user_id, unread_only, limit)


@router.post("/notifications/mark-read/{notification_id}")
async def mark_notification_read(notification_id: str):
    """Mark notification as read"""
    return await notification_svc.mark_as_read(notification_id)


@router.get("/notifications/settings/{user_id}")
async def get_notification_settings(user_id: str):
    """Get notification settings panel"""
    return await notification_svc.get_notification_settings_panel(user_id)


# ============================================================================
# PAPER TRADING ENDPOINTS
# ============================================================================

@router.post("/paper/account/create")
async def create_paper_account(user_id: str, starting_balance: float = 10000.0):
    """Create paper trading account"""
    return await paper_trading.create_paper_trading_account(user_id, starting_balance)


@router.post("/paper/trade/open")
async def open_paper_trade(
    user_id: str,
    pair: str,
    action: str,
    position_size: float,
    entry_price: Optional[float] = None,
    stop_loss: float = 0,
    take_profit: float = 0
):
    """Open paper trade"""
    return await paper_trading.open_paper_trade(
        user_id=user_id,
        pair=pair,
        action=action,
        position_size=position_size,
        entry_price=entry_price,
        stop_loss=stop_loss,
        take_profit=take_profit
    )


@router.post("/paper/trade/close/{trade_id}")
async def close_paper_trade(user_id: str, trade_id: str, exit_price: Optional[float] = None):
    """Close paper trade"""
    return await paper_trading.close_paper_trade(user_id, trade_id, exit_price)


@router.get("/paper/account/summary/{user_id}")
async def get_paper_account_summary(user_id: str):
    """Get paper account summary"""
    return await paper_trading.get_paper_account_summary(user_id)


@router.get("/paper/trades/{user_id}")
async def get_paper_trades(user_id: str, status: str = "all"):
    """Get paper trades"""
    return await paper_trading.get_paper_trades(user_id, status)


@router.post("/paper/update-prices")
async def update_paper_prices(price_data: Dict[str, float]):
    """Update simulated prices"""
    return await paper_trading.update_live_prices(price_data)


@router.get("/paper/guide")
async def get_paper_trading_guide():
    """Get paper trading guide"""
    return await paper_trading.get_paper_trading_guide()


# ============================================================================
# NATURAL LANGUAGE PROCESSING ENDPOINTS
# ============================================================================

@router.post("/nlp/parse-command")
async def parse_natural_language_command(text: str):
    """
    Parse natural language command
    Examples: "Buy EUR/USD at 1.1050", "Sell when RSI drops", etc.
    """
    parsed = await nlp_svc.parse_command(text)
    result = await nlp_svc.execute_parsed_command(parsed)
    response = await nlp_svc.generate_nlp_response(parsed, result)
    
    return {
        "success": result.get("success"),
        "command_type": result.get("command_type"),
        "confidence": result.get("confidence"),
        "ai_response": response,
        "parameters": result.get("parameters"),
        "next_steps": result.get("next_steps"),
    }


@router.get("/nlp/examples")
async def get_command_examples():
    """Get example commands"""
    return await nlp_svc.get_command_examples()


# ============================================================================
# AUTONOMOUS TRADING COPILOT STATUS
# ============================================================================

@router.get("/copilot/status/{user_id}")
async def get_copilot_status(user_id: str):
    """Get comprehensive copilot status"""
    risk_status = await risk_manager.get_risk_assessment(user_id)
    legal_status = await security_svc.get_legal_status(user_id)
    
    return {
        "user_id": user_id,
        "copilot_active": legal_status.get("compliant", False),
        "risk_level": risk_status.get("risk_level", "unknown"),
        "legal_compliant": legal_status.get("compliant", False),
        "features": {
            "autonomous_trading": legal_status.get("compliant", False),
            "predictive_analysis": True,
            "conditional_orders": True,
            "session_aware": True,
            "paper_trading": True,
            "natural_language_commands": True,
            "multi_channel_alerts": True,
        },
        "timestamp": datetime.now().isoformat()
    }


@router.get("/health")
async def health_check():
    """Health check for all services"""
    return {
        "status": "healthy",
        "services": {
            "risk_management": "operational",
            "explainability": "operational",
            "execution_intelligence": "operational",
            "security_compliance": "operational",
            "notifications": "operational",
            "paper_trading": "operational",
            "natural_language": "operational",
        },
        "timestamp": datetime.now().isoformat()
    }
