"""
app/services/auto_trade_scheduler.py

Full-auto pipeline — runs every 5 minutes.
Checks if full-auto mode is ON, fetches the latest signal,
validates it, and executes via Pepperstone FIX without human tap.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone

logger = logging.getLogger("app.auto_trade_scheduler")


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


async def run_full_auto_pipeline() -> None:
    """Main job — called every 5 minutes by APScheduler."""
    try:
        from app.database import supabase
        from app.services.pepperstone_fix_client import pepperstone

        if supabase is None:
            return

        # 1. Find all users with full-auto enabled
        config_result = (
            supabase.table("auto_trade_config")
            .select("*")
            .eq("trade_mode", "live")
            .eq("enabled", True)
            .execute()
        )
        users = config_result.data or []
        if not users:
            return

        logger.debug("Full-auto pipeline running for %d user(s)", len(users))

        for config in users:
            try:
                await _process_user(supabase, pepperstone, config)
            except Exception as e:
                logger.error(
                    "Full-auto pipeline error for user %s: %s",
                    config.get("user_id"), e
                )

    except Exception as e:
        logger.error("Full-auto pipeline batch error: %s", e)


async def _process_user(supabase, pepperstone, config: dict) -> None:
    user_id = config.get("user_id")
    if not user_id:
        return

    # 2. Kill switch check
    kill_result = (
        supabase.table("auto_trade_config")
        .select("enabled")
        .eq("user_id", user_id)
        .single()
        .execute()
    )
    if not (kill_result.data or {}).get("enabled", False):
        logger.info("Full-auto skipped for user %s — kill switch is ON", user_id)
        return

    # 3. Risk gate — enforce max open trades
    max_daily = int(config.get("max_daily_trades") or 5)
    open_result = (
        supabase.table("paper_trades")
        .select("id")
        .eq("user_id", user_id)
        .eq("status", "open")
        .execute()
    )
    open_count = len(open_result.data or [])
    if open_count >= max_daily:
        logger.debug(
            "Full-auto skipped for user %s — %d/%d trades open",
            user_id, open_count, max_daily
        )
        return

    # 4. Fetch latest pending signal from trade_signals (NOT auto_trade_log)
    signal_result = (
        supabase.table("trade_signals")
        .select("*")
        .eq("user_id", user_id)
        .eq("status", "pending")
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )
    signals = signal_result.data or []
    if not signals:
        return

    signal = signals[0]

    # 5. Confidence check
    min_confidence = float(config.get("min_confidence") or 0.75)
    signal_confidence = float(signal.get("confidence") or 0)
    if signal_confidence < min_confidence:
        logger.info(
            "Full-auto skipped signal %s — confidence %.2f below threshold %.2f",
            signal.get("id"), signal_confidence, min_confidence
        )
        supabase.table("trade_signals").update({
            "status": "rejected",
            "rejection_reason": f"Confidence {signal_confidence:.0%} below threshold {min_confidence:.0%}"
        }).eq("id", signal["id"]).execute()
        supabase.table("auto_trade_log").insert({
            "user_id": user_id,
            "pair": signal.get("pair"),
            "direction": signal.get("action"),
            "confidence": signal_confidence,
            "action_taken": "blocked_confidence",
            "reason": f"Confidence {signal_confidence:.0%} below threshold {min_confidence:.0%}",
            "trade_id": str(signal["id"]),
            "created_at": _utcnow(),
        }).execute()
        return

    # 6. NEWS BLACKOUT CHECK — Phase 2A calendar filter
    from app.services.calendar_filter import is_news_blackout
    pair_raw = signal.get("pair", "")
    if await is_news_blackout(pair=pair_raw):
        logger.info(
            "Full-auto skipped signal %s — news blackout for pair %s",
            signal.get("id"), pair_raw
        )
        supabase.table("auto_trade_log").insert({
            "user_id": user_id,
            "pair": pair_raw,
            "direction": signal.get("action"),
            "confidence": signal_confidence,
            "action_taken": "blocked_news",
            "reason": "High-impact news event within blackout window",
            "trade_id": str(signal["id"]),
            "created_at": _utcnow(),
        }).execute()
        return

    # 7. Check FIX is ready
    if not pepperstone.trade_ready:
        logger.warning("Full-auto skipped — FIX trade session not connected")
        return

    # 8. Prepare order — uses 'action' column not 'direction'
    pair = pair_raw.replace("_", "").replace("/", "")
    side = (signal.get("action") or "buy").lower()
    lot_size = float(signal.get("lot_size") or 0.01)
    stop_loss = signal.get("stop_loss")
    take_profit = signal.get("take_profit")
    entry_price = signal.get("entry_price")

    # 9. Execute via FIX
    logger.info(
        "Full-auto executing | user=%s pair=%s side=%s lot=%.2f confidence=%.2f",
        user_id, pair, side, lot_size, signal_confidence
    )

    order_result = await pepperstone.execute_order(
        symbol=pair,
        side=side,
        quantity=lot_size,
        order_type="market",
        stop_loss=stop_loss,
        take_profit=take_profit,
    )

    if not order_result.get("success"):
        error_msg = order_result.get("error", "FIX execution failed")
        supabase.table("trade_signals").update({
            "status": "failed",
            "rejection_reason": error_msg,
        }).eq("id", signal["id"]).execute()
        supabase.table("auto_trade_log").insert({
            "user_id": user_id,
            "pair": pair_raw,
            "direction": side,
            "confidence": signal_confidence,
            "action_taken": "executed",
            "reason": f"FIX failed: {error_msg}",
            "trade_id": str(signal["id"]),
            "created_at": _utcnow(),
        }).execute()
        logger.error("Full-auto FIX failed | user=%s error=%s", user_id, error_msg)
        return

    fill_price = order_result.get("executed_price") or entry_price

    # 10. Mark signal approved
    supabase.table("trade_signals").update({
        "status": "approved",
        "approved_at": _utcnow(),
    }).eq("id", signal["id"]).execute()

    # 11. Log to paper_trades
    supabase.table("paper_trades").insert({
        "user_id": user_id,
        "pair": pair_raw,
        "direction": side,
        "entry_price": float(fill_price) if fill_price else None,
        "lot_size": lot_size,
        "stop_loss": float(stop_loss) if stop_loss else None,
        "take_profit": float(take_profit) if take_profit else None,
        "status": "open",
        "signal_id": str(signal["id"]),
        "opened_at": _utcnow(),
    }).execute()

    # 12. Audit log
    supabase.table("auto_trade_log").insert({
        "user_id": user_id,
        "pair": pair_raw,
        "direction": side,
        "confidence": signal_confidence,
        "action_taken": "executed",
        "reason": f"Full-auto executed at {fill_price}",
        "trade_id": str(signal["id"]),
        "created_at": _utcnow(),
    }).execute()

    logger.info(
        "Full-auto trade executed | user=%s pair=%s fill=%s order=%s",
        user_id, pair, fill_price, order_result.get("broker_order_id")
    )


def start_auto_trade_scheduler() -> None:
    """Call this from main.py lifespan — registers the 5-minute job."""
    from app.services.price_updater import scheduler
    scheduler.add_job(
        run_full_auto_pipeline,
        "interval",
        minutes=5,
        id="full_auto_pipeline",
        replace_existing=True,
    )
    logger.info("Full-auto pipeline scheduled — running every 5 minutes")
