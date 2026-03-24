from __future__ import annotations
import asyncio
from datetime import datetime, date
from app.database import supabase

def get_auto_config(user_id: str) -> dict | None:
    row = supabase.table("auto_trade_config") \
        .select("*").eq("user_id", user_id).single().execute()
    return row.data

def upsert_auto_config(user_id: str, config: dict) -> dict:
    config["user_id"] = user_id
    config["updated_at"] = datetime.utcnow().isoformat()
    result = supabase.table("auto_trade_config").upsert(config).execute()
    return result.data[0]

def enable_autonomous(user_id: str) -> dict:
    return upsert_auto_config(user_id, {"enabled": True})

def disable_autonomous(user_id: str) -> dict:
    return upsert_auto_config(user_id, {"enabled": False})

def get_auto_log(user_id: str, limit: int = 50) -> list:
    result = supabase.table("auto_trade_log") \
        .select("*").eq("user_id", user_id) \
        .order("created_at", desc=True).limit(limit).execute()
    return result.data or []

async def evaluate_and_execute(user_id: str, signal: dict) -> dict:
    """
    Core autonomous decision engine.
    Called whenever a new signal is generated for a user with auto mode on.
    Checks all guardrails before executing.
    """
    config = get_auto_config(user_id)
    if not config or not config.get("enabled"):
        return {"action": "skipped", "reason": "autonomous_mode_disabled"}

    pair       = signal.get("pair", "")
    direction  = signal.get("direction", "")
    confidence = float(signal.get("confidence") or 0)

    # Guardrail 1: confidence threshold
    min_conf = float(config.get("min_confidence") or 0.75)
    if confidence < min_conf:
        return _log_and_return(user_id, pair, direction, confidence,
            "blocked_confidence",
            f"Confidence {confidence:.2f} below threshold {min_conf:.2f}")

    # Guardrail 2: allowed pairs filter
    allowed = config.get("allowed_pairs") or []
    if allowed and pair not in allowed:
        return _log_and_return(user_id, pair, direction, confidence,
            "blocked_pair_filter",
            f"{pair} not in allowed pairs list")

    # Guardrail 3: macro news shield
    if config.get("pause_on_news", True):
        try:
            from app.services.forex_factory_service import ForexFactoryService
            ff = ForexFactoryService()
            shield = await ff.get_macro_shield_status()
            if shield.get("shield_active"):
                return _log_and_return(user_id, pair, direction, confidence,
                    "blocked_news",
                    f"News shield active: {shield.get('event_name','High impact event')}")
        except Exception:
            pass

    # Guardrail 4: daily trade limit
    max_daily = int(config.get("max_daily_trades") or 5)
    today_count = _count_todays_executions(user_id)
    if today_count >= max_daily:
        return _log_and_return(user_id, pair, direction, confidence,
            "blocked_daily_limit",
            f"Daily limit of {max_daily} trades reached ({today_count} executed today)")

    # Guardrail 5: daily drawdown kill switch
    max_dd = float(config.get("max_daily_drawdown") or 3.0)
    if _daily_drawdown_breached(user_id, max_dd):
        return _log_and_return(user_id, pair, direction, confidence,
            "blocked_drawdown",
            f"Daily drawdown of {max_dd}% breached — autonomous mode paused for today")

    # All guardrails passed — execute
    trade_mode = config.get("trade_mode", "paper")
    risk_pct   = float(config.get("max_risk_per_trade") or 1.0)

    try:
        if trade_mode == "paper":
            from app.services import paper_trading_service as pts
            trade = await pts.open_paper_trade(
                user_id=user_id,
                pair=pair,
                direction=direction,
                entry_price=float(signal.get("entry_price") or 0),
                stop_loss=float(signal.get("stop_loss") or 0),
                take_profit=float(signal.get("take_profit") or 0),
                lot_size=0.1,
            )
        else:
            from app.services.trading_bot_service import TradingBotService
            from app.services.forex_data_service import ForexDataService
            from app.services.ai_analysis_service import AIAnalysisService
            from app.services.notification_service import NotificationService
            bot = TradingBotService(
                ForexDataService(), AIAnalysisService(), NotificationService())
            trade = await bot.execute_trade(user_id, {
                "currency_pair": pair,
                "action": direction.lower(),
                "stop_loss":   signal.get("stop_loss"),
                "take_profit": signal.get("take_profit"),
            })
        _log_execution(user_id, pair, direction, confidence,
               str(trade.get("trade", {}).get("id") or trade.get("id") or "")
        return {"action": "executed", "trade": trade,
                "mode": trade_mode, "confidence": confidence}
    except Exception as e:
        return _log_and_return(user_id, pair, direction, confidence,
            "skipped", f"Execution error: {str(e)[:120]}")

def _count_todays_executions(user_id: str) -> int:
    today = date.today().isoformat()
    result = supabase.table("auto_trade_log") \
        .select("id", count="exact") \
        .eq("user_id", user_id) \
        .eq("action_taken", "executed") \
        .gte("created_at", today).execute()
    return result.count or 0

def _daily_drawdown_breached(user_id: str, max_dd_pct: float) -> bool:
    today = date.today().isoformat()
    rows = supabase.table("paper_trades") \
        .select("realized_pnl") \
        .eq("user_id", user_id) \
        .eq("status", "closed") \
        .gte("closed_at", today).execute()
    daily_pnl = sum((r.get("realized_pnl") or 0) for r in (rows.data or []))
    return daily_pnl <= -(max_dd_pct * 100)

def _log_and_return(user_id, pair, direction, confidence,
                    action, reason) -> dict:
    _log_execution(user_id, pair, direction, confidence, None, action, reason)
    return {"action": action, "reason": reason,
            "pair": pair, "confidence": confidence}

def _log_execution(user_id, pair, direction, confidence,
                   trade_id=None, action="executed", reason=None):
    supabase.table("auto_trade_log").insert({
        "user_id": user_id, "pair": pair, "direction": direction,
        "confidence": confidence, "action_taken": action,
        "reason": reason, "trade_id": trade_id,
    }).execute()





