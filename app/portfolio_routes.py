"""
Phase 17 portfolio routes.

These endpoints align with the Flutter PortfolioProvider and gracefully handle
schema drift between the existing paper-trading tables and the newer frontend
models.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from app.database import supabase
from app.limiter import limiter
from app.security import get_current_user_id

router = APIRouter(prefix="/api/v1/portfolio", tags=["portfolio"])

STARTING_BALANCE = 10000.0


class MarkToMarketRequest(BaseModel):
    prices: Dict[str, float] = Field(default_factory=dict)


def _require_supabase() -> Any:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase is not configured")
    return supabase


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _normalize_pair(pair: str) -> str:
    return (pair or "").strip().upper().replace("_", "/")


def _price_digits(pair: str) -> int:
    normalized = _normalize_pair(pair)
    if "JPY" in normalized:
        return 3
    if normalized.startswith("XAU/") or normalized.startswith("XAG/"):
        return 2
    return 5


def _round_price(pair: str, value: float) -> float:
    return round(float(value), _price_digits(pair))


def _same_day(timestamp: Optional[str], today: str) -> bool:
    return bool(timestamp) and str(timestamp)[:10] == today


def _serialize_open_trade(row: Dict[str, Any]) -> Dict[str, Any]:
    pair = _normalize_pair(row.get("pair") or "")
    return {
        "id": str(row.get("id") or ""),
        "pair": pair,
        "direction": str(row.get("direction") or "buy").upper(),
        "entry_price": _round_price(pair, _safe_float(row.get("entry_price"))),
        "lot_size": _safe_float(row.get("lot_size"), 0.01),
        "leverage": _safe_float(row.get("leverage"), 1.0),
        "stop_loss": row.get("stop_loss"),
        "take_profit": row.get("take_profit"),
        "opened_at": row.get("opened_at"),
        "pnl": round(_safe_float(row.get("unrealized_pnl")), 2),
        "status": row.get("status") or "open",
    }


def _serialize_closed_trade(row: Dict[str, Any]) -> Dict[str, Any]:
    pair = _normalize_pair(row.get("pair") or "")
    exit_price = row.get("exit_price")
    if exit_price is None:
        exit_price = row.get("close_price")
    if exit_price is None:
        exit_price = row.get("entry_price")
    return {
        "id": str(row.get("id") or ""),
        "pair": pair,
        "direction": str(row.get("direction") or "buy").upper(),
        "entry_price": _round_price(pair, _safe_float(row.get("entry_price"))),
        "exit_price": _round_price(pair, _safe_float(exit_price)),
        "lot_size": _safe_float(row.get("lot_size"), 0.01),
        "realized_pnl": round(_safe_float(row.get("realized_pnl")), 2),
        "opened_at": row.get("opened_at"),
        "closed_at": row.get("closed_at"),
    }


def _compute_stats(open_rows: List[Dict[str, Any]], closed_rows: List[Dict[str, Any]]) -> Dict[str, Any]:
    open_trades = [_serialize_open_trade(row) for row in open_rows]
    history = [_serialize_closed_trade(row) for row in closed_rows]

    open_pnl = sum(trade["pnl"] for trade in open_trades)
    closed_pnl = sum(trade["realized_pnl"] for trade in history)
    equity = STARTING_BALANCE + closed_pnl + open_pnl
    balance = STARTING_BALANCE + closed_pnl

    today = date.today().isoformat()
    daily_closed_pnl = sum(
        trade["realized_pnl"]
        for trade in history
        if _same_day(trade.get("closed_at"), today)
    )
    daily_pnl = daily_closed_pnl + open_pnl

    wins = [trade for trade in history if trade["realized_pnl"] > 0]
    losses = [trade for trade in history if trade["realized_pnl"] <= 0]
    total = len(history)
    win_rate = (len(wins) / total * 100.0) if total else 0.0
    avg_win = sum(trade["realized_pnl"] for trade in wins) / len(wins) if wins else 0.0
    avg_loss = (
        sum(abs(trade["realized_pnl"]) for trade in losses) / len(losses)
        if losses
        else 0.0
    )

    streak = 0
    for trade in history:
        if trade["realized_pnl"] > 0:
            streak += 1
        else:
            break

    running = STARTING_BALANCE
    equity_curve = [round(running, 2)]
    for trade in reversed(history):
        running += trade["realized_pnl"]
        equity_curve.append(round(running, 2))
    if open_trades:
        equity_curve.append(round(equity, 2))

    return {
        "equity": round(equity, 2),
        "balance": round(balance, 2),
        "daily_pnl": round(daily_pnl, 2),
        "win_rate": round(win_rate, 2),
        "avg_win": round(avg_win, 2),
        "avg_loss": round(avg_loss, 2),
        "win_streak": streak,
        "equity_curve": equity_curve,
        "open_count": len(open_trades),
        "closed_count": total,
    }


def _fetch_rows(user_id: str, status_value: str, *, limit: Optional[int] = None, offset: int = 0) -> List[Dict[str, Any]]:
    client = _require_supabase()
    query = (
        client.table("paper_trades")
        .select("*")
        .eq("user_id", user_id)
        .eq("status", status_value)
    )
    order_field = "opened_at" if status_value == "open" else "closed_at"
    query = query.order(order_field, desc=True)
    if limit is not None:
        query = query.range(offset, offset + limit - 1)
    result = query.execute()
    return result.data or []


@router.get("/stats")
async def get_stats(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    if supabase is None:
        return {
            "equity": STARTING_BALANCE,
            "balance": STARTING_BALANCE,
            "daily_pnl": 0.0,
            "win_rate": 0.0,
            "avg_win": 0.0,
            "avg_loss": 0.0,
            "win_streak": 0,
            "equity_curve": [STARTING_BALANCE],
            "open_count": 0,
            "closed_count": 0,
        }

    try:
        open_rows = _fetch_rows(user_id, "open")
        closed_rows = _fetch_rows(user_id, "closed")
        return _compute_stats(open_rows, closed_rows)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not compute portfolio stats: {exc}") from exc


@router.get("/trades/open")
async def get_open_trades(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    if supabase is None:
        return {"trades": [], "count": 0}

    try:
        rows = _fetch_rows(user_id, "open")
        trades = [_serialize_open_trade(row) for row in rows]
        return {"trades": trades, "count": len(trades)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load open trades: {exc}") from exc


@router.post("/trades/open/{trade_id}/close")
@limiter.limit("20/minute")
async def close_trade(
    request: Request,
    trade_id: str,
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    try:
        rows = (
            client.table("paper_trades")
            .select("*")
            .eq("id", trade_id)
            .eq("user_id", user_id)
            .eq("status", "open")
            .limit(1)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load trade: {exc}") from exc

    row = (rows.data or [None])[0]
    if not row:
        raise HTTPException(status_code=404, detail="Trade not found or already closed")

    pair = _normalize_pair(row.get("pair") or "")
    direction = str(row.get("direction") or "buy").lower()
    entry = _safe_float(row.get("entry_price"))
    lot_size = _safe_float(row.get("lot_size"), 0.01)
    exit_price = entry * (1.0008 if direction == "buy" else 0.9992)
    exit_price = _round_price(pair, exit_price)
    realized_pnl = round(
        ((exit_price - entry) if direction == "buy" else (entry - exit_price)) * lot_size * 10000,
        2,
    )
    now = datetime.now(timezone.utc).isoformat()

    update_payload = {
        "status": "closed",
        "exit_price": exit_price,
        "close_price": exit_price,
        "realized_pnl": realized_pnl,
        "closed_at": now,
        "unrealized_pnl": 0.0,
    }

    try:
        client.table("paper_trades").update(update_payload).eq("id", trade_id).eq("user_id", user_id).execute()
    except Exception:
        fallback_update = {
            key: value
            for key, value in update_payload.items()
            if key != "exit_price"
        }
        try:
            client.table("paper_trades").update(fallback_update).eq("id", trade_id).eq("user_id", user_id).execute()
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not close trade: {exc}") from exc

    return {
        "id": trade_id,
        "pair": pair,
        "direction": direction.upper(),
        "entry_price": _round_price(pair, entry),
        "exit_price": exit_price,
        "lot_size": lot_size,
        "realized_pnl": realized_pnl,
        "closed_at": now,
        "message": "Trade closed successfully",
    }


@router.get("/trades/history")
async def get_trade_history(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    if supabase is None:
        return {"trades": [], "count": 0}

    try:
        rows = _fetch_rows(user_id, "closed", limit=limit, offset=offset)
        trades = [_serialize_closed_trade(row) for row in rows]
        return {"trades": trades, "count": len(trades)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load trade history: {exc}") from exc


@router.get("/all")
async def load_all(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    if supabase is None:
        return {
            "open_trades": [],
            "trade_history": [],
            "stats": {
                "equity": STARTING_BALANCE,
                "balance": STARTING_BALANCE,
                "daily_pnl": 0.0,
                "win_rate": 0.0,
                "avg_win": 0.0,
                "avg_loss": 0.0,
                "win_streak": 0,
                "equity_curve": [STARTING_BALANCE],
                "open_count": 0,
                "closed_count": 0,
            },
        }

    try:
        open_rows = _fetch_rows(user_id, "open")
        closed_rows = _fetch_rows(user_id, "closed", limit=100)
        return {
            "open_trades": [_serialize_open_trade(row) for row in open_rows],
            "trade_history": [_serialize_closed_trade(row) for row in closed_rows],
            "stats": _compute_stats(open_rows, closed_rows),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load portfolio bundle: {exc}") from exc


@router.post("/mark-to-market")
@limiter.limit("60/minute")
async def mark_to_market(
    request: Request,
    payload: MarkToMarketRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    price_map = {
        _normalize_pair(pair): price for pair, price in payload.prices.items()
    }

    try:
        rows = _fetch_rows(user_id, "open")
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load open trades: {exc}") from exc

    updated = 0
    for row in rows:
        pair = _normalize_pair(row.get("pair") or "")
        price = price_map.get(pair)
        if price is None:
            price = price_map.get(pair.replace("/", "_"))
        if price is None:
            continue

        entry = _safe_float(row.get("entry_price"))
        lot_size = _safe_float(row.get("lot_size"), 0.01)
        direction = str(row.get("direction") or "buy").lower()
        price_diff = (price - entry) if direction == "buy" else (entry - price)
        pnl = round(price_diff * lot_size * 10000, 2)

        try:
            (
                client.table("paper_trades")
                .update({"unrealized_pnl": pnl})
                .eq("id", row.get("id"))
                .eq("user_id", user_id)
                .execute()
            )
            updated += 1
        except Exception:
            continue

    return {"updated": updated, "message": f"Updated {updated} open positions"}
