"""
app/services/paper_trading_service.py
Phase 5 - Paper Trading Engine
Virtual trade execution against live Twelve Data prices.
Persists to Supabase paper_trades table.
"""
from __future__ import annotations

import logging
import os
from datetime import datetime, timezone
from typing import Dict, List, Optional
import httpx

logger = logging.getLogger(__name__)

SUPABASE_URL = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
TABLE        = "paper_trades"


# ── Helpers ───────────────────────────────────────────────────────────────────

def _headers() -> Dict:
    return {
        "apikey":        SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type":  "application/json",
        "Prefer":        "return=representation",
    }


def _pnl(entry: float, current: float, direction: str, lot_size: float = 1000) -> float:
    """Calculate unrealized P&L in USD."""
    diff = (current - entry) if direction == "BUY" else (entry - current)
    return round(diff * lot_size, 2)


# ── Main service functions ────────────────────────────────────────────────────

async def open_paper_trade(
    user_id: str,
    pair: str,
    direction: str,
    entry_price: float,
    stop_loss: float,
    take_profit: float,
    lot_size: float = 1000.0,
    signal_id: Optional[str] = None,
    reasoning: Optional[str] = None,
) -> Dict:
    """Open a new virtual paper trade."""
    now = datetime.now(timezone.utc).isoformat()
    trade = {
        "user_id":     user_id,
        "pair":        pair,
        "direction":   direction.lower(),
        "entry_price": entry_price,
        "stop_loss":   stop_loss,
        "take_profit": take_profit,
        "lot_size":    lot_size,
        "status":      "open",
        "opened_at":   now,
        "signal_id":   signal_id,
        "reasoning":   reasoning or "",
        "unrealized_pnl": 0.0,
    }

    if not SUPABASE_URL or not SUPABASE_KEY:
        trade["id"] = f"local_{now}"
        return {"success": True, "trade": trade, "source": "local"}

    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.post(
                f"{SUPABASE_URL}/rest/v1/{TABLE}",
                headers=_headers(),
                json=trade,
            )
        if resp.status_code in (200, 201):
            data = resp.json()
            saved = data[0] if isinstance(data, list) else data
            return {"success": True, "trade": saved, "source": "supabase"}
        logger.error("Supabase open trade failed %s: %s", resp.status_code, resp.text)
        trade["id"] = f"local_{now}"
        return {"success": True, "trade": trade, "source": "local_fallback"}
    except Exception as e:
        logger.error("open_paper_trade error: %s", e)
        trade["id"] = f"local_{now}"
        return {"success": True, "trade": trade, "source": "local_fallback"}


async def close_paper_trade(
    trade_id: str,
    close_price: float,
    close_reason: str = "manual",
) -> Dict:
    """Close an open paper trade and calculate realized P&L."""
    now = datetime.now(timezone.utc).isoformat()

    # Fetch trade first
    trade = await get_trade_by_id(trade_id)
    if not trade:
        return {"success": False, "error": "Trade not found"}

    direction   = trade.get("direction", "BUY")
    entry_price = float(trade.get("entry_price", 0))
    lot_size    = float(trade.get("lot_size", 1000))
    realized_pnl = _pnl(entry_price, close_price, direction, lot_size)

    update = {
        "status":       "closed",
        "close_price":  close_price,
        "closed_at":    now,
        "close_reason": close_reason,
        "realized_pnl": realized_pnl,
        "unrealized_pnl": 0.0,
    }

    if not SUPABASE_URL or not SUPABASE_KEY:
        return {"success": True, "trade": {**trade, **update}, "realized_pnl": realized_pnl}

    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.patch(
                f"{SUPABASE_URL}/rest/v1/{TABLE}?id=eq.{trade_id}",
                headers=_headers(),
                json=update,
            )
        if resp.status_code in (200, 204):
            data = resp.json()
            updated = (data[0] if isinstance(data, list) and data else {**trade, **update})
            return {"success": True, "trade": updated, "realized_pnl": realized_pnl}
        return {"success": False, "error": f"Supabase error {resp.status_code}"}
    except Exception as e:
        logger.error("close_paper_trade error: %s", e)
        return {"success": False, "error": str(e)}


async def get_open_trades(user_id: str) -> List[Dict]:
    """Fetch all open paper trades for a user."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        return []
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(
                f"{SUPABASE_URL}/rest/v1/{TABLE}",
                headers={**_headers(), "Prefer": ""},
                params={
                    "user_id": f"eq.{user_id}",
                    "status":  "eq.open",
                    "order":   "opened_at.desc",
                },
            )
        if resp.status_code == 200:
            return resp.json()
        return []
    except Exception as e:
        logger.error("get_open_trades error: %s", e)
        return []


async def get_trade_history(user_id: str, limit: int = 50) -> List[Dict]:
    """Fetch closed trade history for a user."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        return []
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(
                f"{SUPABASE_URL}/rest/v1/{TABLE}",
                headers={**_headers(), "Prefer": ""},
                params={
                    "user_id": f"eq.{user_id}",
                    "status":  "eq.closed",
                    "order":   "closed_at.desc",
                    "limit":   str(limit),
                },
            )
        if resp.status_code == 200:
            return resp.json()
        return []
    except Exception as e:
        logger.error("get_trade_history error: %s", e)
        return []


async def get_performance_stats(user_id: str) -> Dict:
    """Calculate win rate, total P&L, avg R:R from closed trades."""
    history = await get_trade_history(user_id, limit=200)
    if not history:
        return {
            "total_trades": 0,
            "win_rate": 0.0,
            "total_pnl": 0.0,
            "avg_pnl_per_trade": 0.0,
            "wins": 0,
            "losses": 0,
            "best_trade": 0.0,
            "worst_trade": 0.0,
        }

    pnls = [float(t.get("realized_pnl") or 0) for t in history]
    wins = [p for p in pnls if p > 0]
    losses = [p for p in pnls if p <= 0]

    return {
        "total_trades":    len(pnls),
        "wins":            len(wins),
        "losses":          len(losses),
        "win_rate":        round(len(wins) / len(pnls), 4) if pnls else 0.0,
        "total_pnl":       round(sum(pnls), 2),
        "avg_pnl_per_trade": round(sum(pnls) / len(pnls), 2) if pnls else 0.0,
        "best_trade":      round(max(pnls), 2) if pnls else 0.0,
        "worst_trade":     round(min(pnls), 2) if pnls else 0.0,
    }


async def get_trade_by_id(trade_id: str) -> Optional[Dict]:
    """Fetch a single trade by ID."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        return None
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            resp = await client.get(
                f"{SUPABASE_URL}/rest/v1/{TABLE}",
                headers={**_headers(), "Prefer": ""},
                params={"id": f"eq.{trade_id}", "limit": "1"},
            )
        if resp.status_code == 200:
            data = resp.json()
            return data[0] if data else None
        return None
    except Exception as e:
        logger.error("get_trade_by_id error: %s", e)
        return None

# ── Phase 13: Notification wiring ────────────────────────────────────────
from app.services.notification_dispatcher import NotificationDispatcher
_dispatcher_pt = NotificationDispatcher()

async def _notify_trade(user_id: str, pair: str, direction: str, price: float, size: float):
    """Call this immediately after a trade is saved to fire multi-channel alerts."""
    await _dispatcher_pt.dispatch(
        user_id    = user_id,
        event_type = "trade",
        payload    = {
            "pair":      pair,
            "direction": direction.upper(),
            "price":     str(round(price, 5)),
            "size":      f"{size} lot",
        }
    )
# ── End Phase 13 ─────────────────────────────────────────────────────────
