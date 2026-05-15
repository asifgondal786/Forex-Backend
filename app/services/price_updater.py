"""
app/services/price_updater.py

Runs every 30 seconds — fetches live prices from Pepperstone FIX
and writes unrealized_pnl back to paper_trades.
Also auto-closes trades when TP or SL is hit.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger("app.price_updater")
scheduler = AsyncIOScheduler()


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


async def update_open_trade_prices() -> None:
    """Main job — called every 30 seconds by APScheduler."""
    try:
        from app.database import supabase
        from app.services.pepperstone_fix_client import pepperstone

        if supabase is None:
            return
        if not pepperstone.price_ready:
            logger.warning("Price updater skipped — FIX price session not ready")
            return

        # Fetch all open trades across all users
        result = (
            supabase.table("paper_trades")
            .select("*")
            .eq("status", "open")
            .execute()
        )
        open_trades = result.data or []
        if not open_trades:
            return

        logger.debug("Price updater running — %d open trades", len(open_trades))

        for trade in open_trades:
            try:
                await _process_trade(supabase, pepperstone, trade)
            except Exception as e:
                logger.error("Price update failed for trade %s: %s", trade.get("id"), e)

    except Exception as e:
        logger.error("Price updater batch error: %s", e)


async def _process_trade(supabase, pepperstone, trade: dict) -> None:
    pair = (trade.get("pair") or "").replace("_", "").replace("/", "")
    if not pair:
        return

    # Get live price from FIX price session cache
    price_data = pepperstone.get_price(pair)
    if not price_data:
        logger.debug("No price data yet for %s", pair)
        return

    # Use mid price: (bid + ask) / 2
    try:
        bid = float(price_data.get("bid") or 0)
        ask = float(price_data.get("ask") or 0)
        if bid == 0 and ask == 0:
            return
        current_price = round((bid + ask) / 2, 5)
    except (TypeError, ValueError):
        return

    entry = float(trade.get("entry_price") or 0)
    lot = float(trade.get("lot_size") or 0.01)
    direction = (trade.get("direction") or "buy").lower()

    # PnL calculation — pip value approximation
    # For JPY pairs: 1 pip = 0.01, others: 1 pip = 0.0001
    is_jpy = pair.endswith("JPY")
    pip = 0.01 if is_jpy else 0.0001
    pip_value = 10 * lot  # USD per pip for standard lot sizing

    price_diff = (current_price - entry) if direction == "buy" else (entry - current_price)
    pnl = round((price_diff / pip) * pip_value, 2)

    # Check TP / SL
    tp = trade.get("take_profit")
    sl = trade.get("stop_loss")

    tp_hit = tp and (
        (direction == "buy" and current_price >= float(tp)) or
        (direction == "sell" and current_price <= float(tp))
    )
    sl_hit = sl and (
        (direction == "buy" and current_price <= float(sl)) or
        (direction == "sell" and current_price >= float(sl))
    )

    if tp_hit:
        await _close_trade(supabase, trade, current_price, pnl, "take_profit")
    elif sl_hit:
        await _close_trade(supabase, trade, current_price, pnl, "stop_loss")
    else:
        # Just update PnL
        supabase.table("paper_trades").update({
            "unrealized_pnl": pnl,
        }).eq("id", trade["id"]).execute()


async def _close_trade(supabase, trade: dict, close_price: float, pnl: float, reason: str) -> None:
    supabase.table("paper_trades").update({
        "status": "closed",
        "close_price": close_price,
        "close_reason": reason,
        "realized_pnl": pnl,
        "unrealized_pnl": 0.0,
        "closed_at": _utcnow(),
    }).eq("id", trade["id"]).execute()
    logger.info(
        "Trade %s auto-closed via %s at %s | PnL: %s",
        trade["id"], reason, close_price, pnl
    )


def start_price_updater() -> None:
    scheduler.add_job(
        update_open_trade_prices,
        "interval",
        seconds=30,
        id="price_updater",
        replace_existing=True,
    )
    scheduler.start()
    logger.info("Price updater started — ticking every 30s")