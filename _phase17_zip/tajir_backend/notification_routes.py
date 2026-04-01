from fastapi import APIRouter, Depends, Body, HTTPException
from app.auth import get_current_user
from app.limiter import limiter
from app.database import supabase
from fastapi import Request
from datetime import datetime, timezone

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])

# Category key mapping — matches NotifCategory enum in Flutter
CATEGORY_MAP = {
    "trades": "trades",
    "risk":   "risk",
    "market": "market",
    "ai":     "ai",
    "all":    None,
}


@router.get("")
async def get_notifications(
    current_user=Depends(get_current_user),
    category: str = "all",
    limit: int = 50,
    offset: int = 0
):
    """
    Fetch notifications for the authenticated user.
    Maps to NotificationProvider.load(token).

    Query params:
      category: "all" | "trades" | "risk" | "market" | "ai"
      limit:    max results (default 50)
      offset:   pagination offset

    Response shape matches AppNotification model:
      id, title, body, category, timestamp (ISO), is_read
    """
    uid = str(current_user["uid"])

    query = supabase.table("notifications") \
        .select("id, title, body, type, created_at, is_read") \
        .eq("user_id", uid) \
        .order("created_at", desc=True) \
        .range(offset, offset + limit - 1)

    # Filter by category (stored as 'type' in the notifications table)
    if category != "all" and category in CATEGORY_MAP:
        query = query.eq("type", category)

    rows = query.execute()

    notifications = []
    for r in (rows.data or []):
        notifications.append({
            "id":        r["id"],
            "title":     r.get("title", ""),
            "body":      r.get("body", ""),
            "category":  r.get("type", "all"),
            "timestamp": r["created_at"],
            "is_read":   r.get("is_read", False),
        })

    unread_count = supabase.table("notifications") \
        .select("id", count="exact") \
        .eq("user_id", uid).eq("is_read", False).execute()

    return {
        "notifications": notifications,
        "count":         len(notifications),
        "unread_count":  unread_count.count or 0,
    }


@router.patch("/{notification_id}/read")
@limiter.limit("60/minute")
async def mark_read(
    request: Request,
    notification_id: str,
    current_user=Depends(get_current_user)
):
    """
    Mark a single notification as read.
    Maps to NotificationProvider.markRead(id).
    """
    uid = str(current_user["uid"])

    result = supabase.table("notifications") \
        .update({"is_read": True}) \
        .eq("id", notification_id).eq("user_id", uid).execute()

    if not result.data:
        raise HTTPException(404, "Notification not found")

    return {"id": notification_id, "is_read": True}


@router.post("/read-all")
@limiter.limit("10/minute")
async def mark_all_read(
    request: Request,
    current_user=Depends(get_current_user)
):
    """
    Mark all notifications as read.
    Maps to NotificationProvider.markAllRead().
    """
    uid = str(current_user["uid"])
    supabase.table("notifications") \
        .update({"is_read": True}) \
        .eq("user_id", uid).eq("is_read", False).execute()

    return {"message": "All notifications marked as read"}


@router.delete("/{notification_id}")
@limiter.limit("30/minute")
async def dismiss_notification(
    request: Request,
    notification_id: str,
    current_user=Depends(get_current_user)
):
    """
    Swipe-to-dismiss: delete a notification.
    Maps to NotificationProvider.dismiss(id).
    """
    uid = str(current_user["uid"])
    supabase.table("notifications") \
        .delete() \
        .eq("id", notification_id).eq("user_id", uid).execute()

    return {"id": notification_id, "deleted": True}


@router.get("/unread-count")
async def get_unread_count(current_user=Depends(get_current_user)):
    """
    Fast endpoint for bottom nav badge.
    Maps to NotificationProvider.unreadCount getter.
    """
    uid = str(current_user["uid"])
    result = supabase.table("notifications") \
        .select("id", count="exact") \
        .eq("user_id", uid).eq("is_read", False).execute()

    return {"unread_count": result.count or 0}


@router.post("/push-token")
@limiter.limit("5/minute")
async def register_push_token(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Register FCM device push token.
    Maps to NotificationProvider.grantPushPermission() flow.
    Body: { "token": "FCM_TOKEN_HERE", "platform": "android" | "ios" | "web" }
    """
    uid = str(current_user["uid"])
    fcm_token = body.get("token", "")
    platform  = body.get("platform", "web")

    if not fcm_token:
        raise HTTPException(400, "token is required")

    supabase.table("device_push_tokens").upsert({
        "user_id":    uid,
        "fcm_token":  fcm_token,
        "platform":   platform,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }, on_conflict="user_id,fcm_token").execute()

    return {"message": "Push token registered", "platform": platform}
