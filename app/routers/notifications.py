"""
Phase 13 — Multi-Channel Notifications
Router: /api/v1/notifications/...
"""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.dependencies import get_current_user          # existing auth dep
from app.services.notification_dispatcher import NotificationDispatcher
from app.services.push_service import PushService
from app.database import supabase                      # existing Supabase client

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])
dispatcher  = NotificationDispatcher()
push_svc    = PushService()


# ── Models ────────────────────────────────────────────────────────────────────

class DeviceRegisterRequest(BaseModel):
    fcm_token: str
    platform: str   # "android" | "ios" | "web"

class NotificationPrefsRequest(BaseModel):
    email_enabled:    Optional[bool] = None
    push_enabled:     Optional[bool] = None
    whatsapp_enabled: Optional[bool] = None


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/device/register")
async def register_device(body: DeviceRegisterRequest, user=Depends(get_current_user)):
    """Store or refresh FCM token for this device."""
    supabase.table("device_push_tokens").upsert(
        {
            "user_id":   user["uid"],
            "fcm_token": body.fcm_token,
            "platform":  body.platform,
        },
        on_conflict="user_id,fcm_token"
    ).execute()
    return {"status": "registered"}


@router.get("/email/test")
async def test_email(event: str = "trade", user=Depends(get_current_user)):
    """
    Fire a test email for a given event type.
    event: trade | risk | signal | market
    """
    valid = {"trade", "risk", "signal", "market"}
    if event not in valid:
        raise HTTPException(400, f"event must be one of {valid}")

    test_payloads = {
        "trade":  {"pair": "EUR/USD", "direction": "BUY",  "price": "1.0842", "size": "0.1 lot"},
        "risk":   {"pair": "GBP/USD", "drawdown": "8.2%",  "threshold": "8%"},
        "signal": {"pair": "USD/JPY", "signal": "SELL",    "confidence": "83%"},
        "market": {"pair": "AUD/USD", "event": "RBA Rate Decision", "time": "14:30 UTC"},
    }
    await dispatcher.dispatch(user["uid"], event, test_payloads[event], channels=["email"])
    return {"status": "test email sent", "event": event}


@router.get("/push/test")
async def test_push(user=Depends(get_current_user)):
    """Send a test push notification to all registered devices for this user."""
    await push_svc.send(
        user_id = user["uid"],
        title   = "Tajir — Test Push",
        body    = "Push notifications are working correctly.",
        data    = {"event_type": "test"}
    )
    return {"status": "test push sent"}


@router.get("/log")
async def notification_log(limit: int = 50, user=Depends(get_current_user)):
    """Return the last N notifications sent to this user."""
    rows = (
        supabase.table("notification_log")
        .select("*")
        .eq("user_id", user["uid"])
        .order("sent_at", desc=True)
        .limit(limit)
        .execute()
    )
    return {"notifications": rows.data}


@router.patch("/prefs")
async def update_prefs(body: NotificationPrefsRequest, user=Depends(get_current_user)):
    """Update user notification preferences."""
    updates = {k: v for k, v in body.dict().items() if v is not None}
    if not updates:
        raise HTTPException(400, "No preferences provided")
    supabase.table("user_preferences").upsert(
        {"user_id": user["uid"], **updates},
        on_conflict="user_id"
    ).execute()
    return {"status": "preferences updated", "updated": updates}