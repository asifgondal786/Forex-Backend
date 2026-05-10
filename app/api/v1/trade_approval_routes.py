"""
app/api/v1/trade_approval_routes.py
Semi-Auto mode: endpoints for listing, approving, and rejecting pending trade signals.
"""
from fastapi import APIRouter, HTTPException, Request
from typing import Optional
from app.database import supabase

router = APIRouter(prefix="/api/v1/trades", tags=["Trade Approval"])


@router.get("/pending")
async def list_pending_trades(user_id: Optional[str] = None) -> dict:
    """List all trade signals pending user approval."""
    try:
        q = supabase.table("trade_signals") \
            .select("*") \
            .eq("status", "pending_approval") \
            .order("created_at", desc=True) \
            .limit(20)
        if user_id:
            q = q.eq("user_id", user_id)
        result = q.execute()
        return {
            "status":  "ok",
            "count":   len(result.data or []),
            "signals": result.data or [],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/{signal_id}/approve")
async def approve_trade(signal_id: str, user_id: str = None):
    try:
        row = supabase.table("trade_signals").select("*").eq("id", signal_id).single().execute()
        if not row.data: raise __import__("fastapi").HTTPException(status_code=404, detail="Signal not found")
        signal = row.data
        if signal.get("status") != "pending_approval":
            raise __import__("fastapi").HTTPException(status_code=400, detail="Signal is not pending")
        supabase.table("trade_signals").update({"status": "approved", "approved_at": "now()"}).eq("id", signal_id).execute()
        return {"status": "approved", "signal_id": signal_id, "pair": signal.get("pair"), "direction": signal.get("action")}
    except __import__("fastapi").HTTPException: raise
    except Exception as e: raise __import__("fastapi").HTTPException(status_code=500, detail=str(e))

async def reject_trade(signal_id: str, request: Request) -> dict:
    body = await request.json()
    reason = body.get("reason")
    """Reject a pending trade signal."""
    try:
        row = supabase.table("trade_signals") \
            .select("id,status").eq("id", signal_id).single().execute()
        if not row.data:
            raise HTTPException(status_code=404, detail="Signal not found")

        supabase.table("trade_signals") \
            .update({"status": "rejected", "rejection_reason": reason or "User rejected"}) \
            .eq("id", signal_id).execute()

        return {"status": "rejected", "signal_id": signal_id, "reason": reason}

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



