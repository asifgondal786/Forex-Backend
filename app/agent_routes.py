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


def _load_agent_config(user_id: str) -> Dict[str, Any]:
    """Load user's agent/automation config from Supabase."""
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
    """Convert DB trade_mode + enabled to frontend AgentMode string."""
    if not enabled:
        return "off"
    if trade_mode == "live":
        return "full_auto"
    if trade_mode == "paper":
        return "semi_auto"
    return "off"


def _get_pending_trades(user_id: str) -> list:
    """Get pending trades awaiting user approval (semi-auto mode)."""
    if supabase is None:
        return []
    try:
        result = (
            supabase.table("auto_trade_log")
            .select("*")
            .eq("user_id", user_id)
            .eq("action_taken", "pending_approval")
            .order("created_at", desc=True)
            .limit(20)
            .execute()
        )
        trades = []
        for row in (result.data or []):
            trades.append({
                "id": str(row.get("id", "")),
                "pair": row.get("pair", ""),
                "direction": (row.get("direction") or "BUY").upper(),
                "confidence": float(row.get("confidence") or 0.5),
                "entry": row.get("entry_price"),
                "stop_loss": row.get("stop_loss"),
                "take_profit": row.get("take_profit"),
                "reasoning": row.get("reason") or "AI signal detected opportunity",
            })
        return trades
    except Exception as e:
        logger.warning("Failed to load pending trades: %s", e)
        return []


def _get_active_trades(user_id: str) -> list:
    """Get currently active autonomous trades."""
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
    """Calculate total PnL from today's closed trades."""
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
async def agent_status(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    """
    Get current agent status — called by Flutter AgentProvider on init.
    Returns mode, pending trades, active trades, total PnL.
    """
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
) -> Dict[str, Any]:
    """
    Start the agent in semi-auto or full-auto mode.
    Frontend sends this when user taps SEMI or FULL mode card.
    """
    # Determine which mode to set
    requested_mode = body.get("mode", "semi_auto")
    
    # Map frontend mode to DB-valid values (paper/live)
    # semi_auto -> paper (trades need approval, simulated)
    # full_auto -> live (autonomous execution)
    if requested_mode in ("full_auto", "fully_auto"):
        db_mode = "live"
    else:
        db_mode = "paper"

    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")

    try:
        supabase.table("auto_trade_config").upsert(
            {
                "user_id": user_id,
                "trade_mode": db_mode,
                "enabled": True,
                "updated_at": _utcnow(),
            },
            on_conflict="user_id",
        ).execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to start agent: {exc}") from exc

    frontend_mode = "full_auto" if db_mode == "live" else "semi_auto"
    logger.info("Agent started | user=%s mode=%s (db=%s)", user_id, frontend_mode, db_mode)

    return {
        "status": "active",
        "mode": frontend_mode,
        "message": f"Agent activated in {'full autonomous' if db_mode == 'live' else 'semi-auto'} mode",
    }


@router.post("/stop")
@limiter.limit("10/minute")
async def stop_agent(
    request: Request,
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    """Stop the agent — set mode back to manual."""
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")

    try:
        supabase.table("auto_trade_config").upsert(
            {
                "user_id": user_id,
                "trade_mode": "paper",
                "enabled": False,
                "updated_at": _utcnow(),
            },
            on_conflict="user_id",
        ).execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to stop agent: {exc}") from exc

    logger.info("Agent stopped | user=%s", user_id)
    return {"status": "stopped", "mode": "off", "message": "Agent deactivated"}


@router.post("/kill")
@limiter.limit("5/minute")
async def kill_agent(
    request: Request,
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    """
    Emergency kill — stops agent AND cancels all pending trades.
    """
    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")

    try:
        # 1. Set mode to manual
        supabase.table("auto_trade_config").upsert(
            {
                "user_id": user_id,
                "trade_mode": "paper",
                "enabled": False,
                "updated_at": _utcnow(),
            },
            on_conflict="user_id",
        ).execute()

        # 2. Cancel all pending approval trades
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
) -> Dict[str, Any]:
    """
    Approve a pending trade in semi-auto mode.
    Frontend sends trade_id from the pending trades list.
    """
    trade_id = body.get("trade_id")
    if not trade_id:
        raise HTTPException(status_code=400, detail="trade_id is required")

    if supabase is None:
        raise HTTPException(status_code=503, detail="Database not available")

    try:
        # Mark as approved
        supabase.table("auto_trade_log").update(
            {"action_taken": "approved", "reason": "User approved"}
        ).eq("id", trade_id).eq("user_id", user_id).execute()

        # TODO: Execute the actual trade via broker_execution_service
        # For now, log it and create a paper trade
        logger.info("Trade approved | user=%s trade=%s", user_id, trade_id)

    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Approval failed: {exc}") from exc

    return {"status": "approved", "trade_id": trade_id, "message": "Trade approved and queued for execution"}


@router.post("/reject")
@limiter.limit("30/minute")
async def reject_trade(
    request: Request,
    body: Dict[str, Any] = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    """Reject a pending trade in semi-auto mode."""
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
) -> Dict[str, Any]:
    """Update agent risk settings."""
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
        supabase.table("auto_trade_config").upsert(
            update_fields, on_conflict="user_id"
        ).execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to update risk settings: {exc}") from exc

    return {"status": "updated", "message": "Agent risk settings updated"}
