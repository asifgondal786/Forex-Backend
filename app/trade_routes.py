"""
Phase 17 trade execution routes.

These endpoints are designed to match the newer Flutter trade-setup flow while
staying compatible with the existing paper-trading schema already used in the
backend. They are intentionally conservative about required columns so they can
work before every migration has landed.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional
from uuid import uuid4

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.database import supabase
from app.limiter import limiter
from app.security import get_current_user_id

router = APIRouter(prefix="/api/v1/trades", tags=["trades"])


class OpenPaperTradeRequest(BaseModel):
    pair: str = Field(..., min_length=3, max_length=32)
    direction: str = Field(..., min_length=3, max_length=8)
    lot_size: float = Field(default=0.01, gt=0)
    leverage: float = Field(default=10.0, ge=1)
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    entry_price: Optional[float] = None


class ClosePaperTradeRequest(BaseModel):
    exit_price: Optional[float] = None


def _require_supabase() -> Any:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase is not configured")
    return supabase


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _normalize_pair(pair: str) -> str:
    return (pair or "").strip().upper().replace("_", "/")


def _pair_key(pair: str) -> str:
    return _normalize_pair(pair).replace("/", "_")


def _price_digits(pair: str) -> int:
    normalized = _normalize_pair(pair)
    if "JPY" in normalized:
        return 3
    if normalized.startswith("XAU/") or normalized.startswith("XAG/"):
        return 2
    return 5


def _round_price(pair: str, value: float) -> float:
    return round(float(value), _price_digits(pair))


def _fallback_entry_price(pair: str) -> float:
    defaults = {
        "EUR/USD": 1.08450,
        "GBP/USD": 1.26300,
        "USD/JPY": 149.500,
        "GBP/JPY": 188.500,
        "AUD/USD": 0.65100,
        "USD/CHF": 0.89800,
        "XAU/USD": 2340.00,
    }
    normalized = _normalize_pair(pair)
    return defaults.get(normalized, 1.00000)


def _resolve_entry_price(pair: str, requested_price: Optional[float]) -> float:
    if requested_price is not None:
        return _round_price(pair, requested_price)

    client = _require_supabase()
    try:
        result = (
            client.table("market_prices")
            .select("bid, ask, mid")
            .eq("pair", _pair_key(pair))
            .limit(1)
            .execute()
        )
        row = (result.data or [None])[0]
        if row:
            for key in ("mid", "bid", "ask"):
                if row.get(key) is not None:
                    return _round_price(pair, row[key])
    except Exception:
        pass

    return _round_price(pair, _fallback_entry_price(pair))


def _validate_setup(
    *,
    pair: str,
    direction: str,
    lot_size: float,
    leverage: float,
    stop_loss: Optional[float],
    take_profit: Optional[float],
) -> str:
    if not pair:
        return "pair is required"
    if direction not in {"buy", "sell"}:
        return "direction must be 'buy' or 'sell'"
    if lot_size <= 0:
        return "lot_size must be greater than 0"
    if leverage < 1:
        return "leverage must be at least 1"
    if stop_loss is not None and take_profit is not None:
        if direction == "buy" and stop_loss >= take_profit:
            return "stop_loss must be below take_profit for a BUY"
        if direction == "sell" and stop_loss <= take_profit:
            return "stop_loss must be above take_profit for a SELL"
    return ""


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


@router.post("/paper/open")
@limiter.limit("30/minute")
async def open_paper_trade(
    request: Request,
    payload: OpenPaperTradeRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    pair = _normalize_pair(payload.pair)
    direction = payload.direction.strip().lower()
    lot_size = float(payload.lot_size)
    leverage = float(payload.leverage)
    stop_loss = payload.stop_loss
    take_profit = payload.take_profit

    error = _validate_setup(
        pair=pair,
        direction=direction,
        lot_size=lot_size,
        leverage=leverage,
        stop_loss=stop_loss,
        take_profit=take_profit,
    )
    if error:
        raise HTTPException(status_code=400, detail=error)

    entry_price = _resolve_entry_price(pair, payload.entry_price)
    now = _utcnow().isoformat()
    trade_id = str(uuid4())
    client = _require_supabase()

    insert_payload = {
        "id": trade_id,
        "user_id": user_id,
        "pair": pair,
        "direction": direction,
        "entry_price": entry_price,
        "lot_size": lot_size,
        "leverage": leverage,
        "stop_loss": _round_price(pair, stop_loss) if stop_loss is not None else None,
        "take_profit": _round_price(pair, take_profit) if take_profit is not None else None,
        "status": "open",
        "unrealized_pnl": 0.0,
        "realized_pnl": None,
        "opened_at": now,
    }

    try:
        client.table("paper_trades").insert(insert_payload).execute()
    except Exception:
        fallback_payload = {
            key: value
            for key, value in insert_payload.items()
            if key != "leverage"
        }
        try:
            client.table("paper_trades").insert(fallback_payload).execute()
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not open trade: {exc}") from exc

    response = _serialize_open_trade(insert_payload)
    response["message"] = f"Paper trade opened: {direction.upper()} {pair} at {entry_price}"
    return response


@router.post("/paper/close/{trade_id}")
@limiter.limit("30/minute")
async def close_paper_trade(
    request: Request,
    trade_id: str,
    payload: Optional[ClosePaperTradeRequest] = Body(default=None),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    try:
        result = (
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

    row = (result.data or [None])[0]
    if not row:
        raise HTTPException(status_code=404, detail="Open trade not found")

    pair = _normalize_pair(row.get("pair") or "")
    direction = str(row.get("direction") or "buy").lower()
    entry = _safe_float(row.get("entry_price"))
    lot_size = _safe_float(row.get("lot_size"), 0.01)

    exit_price = payload.exit_price if payload else None
    if exit_price is None:
        exit_price = entry * (1.0008 if direction == "buy" else 0.9992)
    exit_price = _round_price(pair, exit_price)

    price_diff = (exit_price - entry) if direction == "buy" else (entry - exit_price)
    realized_pnl = round(price_diff * lot_size * 10000, 2)
    now = _utcnow().isoformat()

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


@router.get("/paper/open")
async def list_open_trades(
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    if supabase is None:
        return {"trades": [], "count": 0}

    try:
        result = (
            supabase.table("paper_trades")
            .select("*")
            .eq("user_id", user_id)
            .eq("status", "open")
            .order("opened_at", desc=True)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not list open trades: {exc}") from exc

    trades = [_serialize_open_trade(row) for row in (result.data or [])]
    return {"trades": trades, "count": len(trades)}
