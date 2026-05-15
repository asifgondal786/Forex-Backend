"""
Agent Routes — /api/v1/agent/*
Powers the Flutter AgentProvider (semi-auto + full-auto trading modes).
Bridges to automation_routes config + autonomous_service execution.
"""
from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.database import supabase
from app.security import get_current_user_id
from app.limiter import limiter

logger = logging.getLogger("app.agent_routes")

router = APIRouter(prefix="/api/v1/agent", tags=["agent"])

# ═══════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════

def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_agent_config(user_id: str) -> dict:
    if supabase is None:
        return {"trade_mode": "paper", "enabled": False}
    try:
        result = (
            supabase.table("auto_trade_config")
            .select("*")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        row = (result.data or [None])[0]
        if not row:
            return {"trade_mode": "paper", "enabled": False}
        return row
    except Exception as e:
        logger.warning("Failed to load agent config: %s", e)
        return {"trade_mode": "paper", "enabled": False}


def _mode_to_frontend(trade_mode: str, enabled: bool = False) -> str:
    if not enabled:
        return "off"
    if trade_mode == "live":
        return "full_auto"
    if trade_mode == "paper":
        return "semi_auto"
    return "off"


def _get_pending_trades(user_id: str) -> list:
    if supabase is None:
        return []
    try:
        result = (
            supabase.table("trade_signals")
            .select("*")
            .eq("user_id", user_id)
            .eq("status", "pending")
            .order("created_at", desc=True)
            .limit(20)
            .execute()
        )
        trades = []
        for row in (result.data or []):
            trades.append({
                "id": str(row.get("id", "")),
                "pair": row.get("pair", ""),
                "direction": (row.get("action") or "BUY").upper(),
                "confidence": float(row.get("confidence") or 0.5),
                "entry": row.get("entry_price"),
                "stop_loss": row.get("stop_loss"),
                "take_profit": row.get("take_profit"),
                "reasoning": row.get("reasoning") or "AI signal detected opportunity",
            })
        return trades
    except Exception as e:
        logger.warning("Failed to load pending trades: %s", e)
        return []


def _get_active_trades(user_id: str) -> list:
    if supabase is None:
        return []
    try:
        result = (
            supabase.table("paper_trades")
            .select("*")
            .eq("user_id", user_id)
            .eq("status", "open")
            .order("opened_at", desc=True)
            .limit(20)
            .execute()
        )
        trades = []
        for row in (result.data or []):
            trades.append({
                "id": str(row.get("id", "")),
                "pair": row.get("pair") or row.get("currency_pair", ""),
                "direction": (row.get("direction") or "BUY").upper(),
                "lot_size": float(row.get("lot_size") or 0.1),
                "open_price": float(row.get("entry_price") or row.get("open_price") or 0),
                "current_price": row.get("current_price"),
                "pnl": float(row.get("unrealized_pnl") or row.get("pnl") or 0),
                "opened_at": row.get("opened_at") or row.get("created_at", ""),
            })
        return trades
    except Exception as e:
        logger.warning("Failed to load active trades: %s", e)
        return []


def _calculate_total_pnl(user_id: str) -> float:
    if supabase is None:
        return 0.0
    try:
        from datetime import date
        today = date.today().isoformat()
        result = (
            supabase.table("paper_trades")
            .select("realized_pnl")
            .eq("user_id", user_id)
            .eq("status", "closed")
            .gte("closed_at", today)
            .execute()
        )
        return sum(float(r.get("realized_pnl") or 0) for r in (result.data or []))
    except Exception:
        return 0.0


# ═══════════════════════════════════════════════════════════
# ENDPOINTS
# ═══════════════════════════════════════════════════════════

@router.get("/status")
async def agent_status(user_id: str = Depends(get_current_user_id)) -> dict:
    config = _load_agent_config(user_id)
    mode = _mode_to_frontend(config.get("trade_mode", "paper"), config.get("enabled", False))
    pending = _get_pending_trades(user_id) if mode == "semi_auto" else []
    active = _get_active_trades(user_id) if mode in ("semi_auto", "full_auto") else []
    total_pnl = _calculate_total_pnl(user_id) if mode != "off" else 0.0
    return {
        "mode": mode,
        "pending_trades": pending,
        "active_trades": active,
        "total_pnl": total_pnl,
        "config": {
            "min_confidence": float(config.get("min_confidence") or 0.75),
            "max_daily_trades": int(config.get("max_daily_trades") or 5),
            "max_risk_per_trade": float(config.get("max_risk_per_trade") or 1.0),
            "allowed_pairs": config.get("allowed_pairs") or [],
        },
    }


@router.post("/start")
@limiter.limit("10/minute")
async def start_agent(
    request: Request,
    body: Dict[str, Any] = Body(default={}),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    requested_mode = body.get("mode", "semi_auto")
    if requested_mode in ("full_auto", "fully_auto"):
        db_mode = "live"
    else:
        db_mode = "paper"
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")
    try:
        supabase.table("auto_trade_config").upsert(
            {"user_id": user_id, "trade_mode": db_mode, "enabled": True, "updated_at": _utcnow()},
            on_conflict="user_id",
        ).execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to start agent: {exc}") from exc
    frontend_mode = "full_auto" if db_mode == "live" else "semi_auto"
    logger.info("Agent started | user=%s mode=%s", user_id, frontend_mode)
    return {"status": "active", "mode": frontend_mode, "message": f"Agent activated in {frontend_mode} mode"}


@router.post("/stop")
@limiter.limit("10/minute")
async def stop_agent(request: Request, user_id: str = Depends(get_current_user_id)) -> dict:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")
    try:
        supabase.table("auto_trade_config").upsert(
            {"user_id": user_id, "trade_mode": "paper", "enabled": False, "updated_at": _utcnow()},
            on_conflict="user_id",
        ).execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to stop agent: {exc}") from exc
    logger.info("Agent stopped | user=%s", user_id)
    return {"status": "stopped", "mode": "off", "message": "Agent deactivated"}


@router.post("/kill")
@limiter.limit("5/minute")
async def kill_agent(request: Request, user_id: str = Depends(get_current_user_id)) -> dict:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")
    try:
        supabase.table("auto_trade_config").upsert(
            {"user_id": user_id, "trade_mode": "paper", "enabled": False, "updated_at": _utcnow()},
            on_conflict="user_id",
        ).execute()
        supabase.table("auto_trade_log").update(
            {"action_taken": "cancelled", "reason": "Agent killed by user"}
        ).eq("user_id", user_id).eq("action_taken", "pending_approval").execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Kill failed: {exc}") from exc
    logger.warning("Agent KILLED | user=%s", user_id)
    return {"status": "killed", "mode": "off", "message": "Agent killed — all pending trades cancelled"}


@router.post("/approve")
@limiter.limit("30/minute")
async def approve_trade(
    request: Request,
    body: Dict[str, Any] = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    """Approve a pending trade — reads from trade_signals (NOT auto_trade_log)."""
    trade_id = body.get("trade_id")
    if not trade_id:
        raise HTTPException(status_code=400, detail="trade_id is required")
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")
    try:
        # 1. Fetch signal from trade_signals
        signal_result = (
            supabase.table("trade_signals")
            .select("*")
            .eq("id", trade_id)
            .eq("user_id", user_id)
            .eq("status", "pending")
            .single()
            .execute()
        )
        if not signal_result.data:
            raise HTTPException(status_code=404, detail="Pending signal not found")
        trade = signal_result.data

        # 2. Risk gate
        config = _load_agent_config(user_id)
        max_daily = int(config.get("max_daily_trades") or 5)
        open_trades = (
            supabase.table("paper_trades")
            .select("id")
            .eq("user_id", user_id)
            .eq("status", "open")
            .execute()
        )
        if len(open_trades.data or []) >= max_daily:
            raise HTTPException(status_code=400, detail=f"Max {max_daily} open trades already reached")

        # 3. Prepare order parameters
        pair = (trade.get("pair") or "EURUSD").replace("_", "").replace("/", "")
        side = (trade.get("action") or "buy").lower()
        lot_size = float(trade.get("lot_size") or 0.01)
        stop_loss = trade.get("stop_loss")
        take_profit = trade.get("take_profit")
        entry_price = trade.get("entry_price")

        # 4. Execute via Pepperstone FIX
        from app.services.pepperstone_fix_client import pepperstone
        if not pepperstone.trade_ready:
            raise HTTPException(status_code=503, detail="Pepperstone FIX trade session not connected")
        order_result = await pepperstone.execute_order(
            symbol=pair, side=side, quantity=lot_size,
            order_type="market", stop_loss=stop_loss, take_profit=take_profit,
        )
        if not order_result.get("success"):
            supabase.table("trade_signals").update({
                "status": "failed",
                "rejection_reason": order_result.get("error", "FIX execution failed")
            }).eq("id", trade_id).execute()
            raise HTTPException(status_code=500, detail=f"FIX execution failed: {order_result.get('error')}")

        fill_price = order_result.get("executed_price") or entry_price

        # 5. Mark signal approved
        supabase.table("trade_signals").update({
            "status": "approved",
            "approved_at": _utcnow(),
        }).eq("id", trade_id).execute()

        # 6. Insert into paper_trades
        supabase.table("paper_trades").insert({
            "user_id": user_id,
            "pair": trade.get("pair", pair),
            "direction": side,
            "entry_price": float(fill_price) if fill_price else None,
            "lot_size": lot_size,
            "stop_loss": float(stop_loss) if stop_loss else None,
            "take_profit": float(take_profit) if take_profit else None,
            "status": "open",
            "signal_id": str(trade_id),
            "opened_at": _utcnow(),
        }).execute()

        # 7. Audit log
        supabase.table("auto_trade_log").insert({
            "user_id": user_id,
            "pair": trade.get("pair", pair),
            "direction": side,
            "confidence": trade.get("confidence"),
            "action_taken": "executed",
            "reason": "User approved via semi-auto",
            "trade_id": str(trade_id),
            "created_at": _utcnow(),
        }).execute()

        logger.info("Trade executed via FIX | user=%s signal=%s fill=%s", user_id, trade_id, fill_price)

    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Approval failed: {exc}") from exc

    return {
        "status": "executed",
        "trade_id": trade_id,
        "broker_order_id": order_result.get("broker_order_id"),
        "fill_price": order_result.get("executed_price"),
        "message": "Trade approved and executed via Pepperstone FIX",
    }


@router.post("/reject")
@limiter.limit("30/minute")
async def reject_trade(
    request: Request,
    body: Dict[str, Any] = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    trade_id = body.get("trade_id")
    if not trade_id:
        raise HTTPException(status_code=400, detail="trade_id is required")
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")
    try:
        supabase.table("auto_trade_log").update(
            {"action_taken": "rejected", "reason": "User rejected"}
        ).eq("id", trade_id).eq("user_id", user_id).execute()
        logger.info("Trade rejected | user=%s trade=%s", user_id, trade_id)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Rejection failed: {exc}") from exc
    return {"status": "rejected", "trade_id": trade_id, "message": "Trade rejected"}


@router.post("/risk")
@limiter.limit("20/minute")
async def update_agent_risk(
    request: Request,
    body: Dict[str, Any] = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> dict:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")
    update_fields: Dict[str, Any] = {"user_id": user_id, "updated_at": _utcnow()}
    if "min_confidence" in body:
        update_fields["min_confidence"] = float(body["min_confidence"])
    if "max_daily_trades" in body:
        update_fields["max_daily_trades"] = int(body["max_daily_trades"])
    if "max_risk_per_trade" in body:
        update_fields["max_risk_per_trade"] = float(body["max_risk_per_trade"])
    if "allowed_pairs" in body:
        update_fields["allowed_pairs"] = body["allowed_pairs"]
    try:
        supabase.table("auto_trade_config").upsert(update_fields, on_conflict="user_id").execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to update risk settings: {exc}") from exc
    return {"status": "updated", "message": "Agent risk settings updated"}
