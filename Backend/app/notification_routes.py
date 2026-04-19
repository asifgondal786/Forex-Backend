"""
Phase 17 notification routes.

These endpoints expose a simple /api/v1/notifications surface that matches the
newer Flutter NotificationProvider while coexisting with the richer internal
notification services already present in the backend.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, List

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from app.database import supabase
from app.limiter import limiter
from app.security import get_current_user_id

router = APIRouter(prefix="/api/v1/notifications", tags=["notifications"])

VALID_CATEGORIES = {"all", "trades", "risk", "market", "ai"}


class PushTokenRequest(BaseModel):
    token: str = Field(..., min_length=16, max_length=4096)
    platform: str = Field(default="web", min_length=2, max_length=32)


def _require_supabase() -> Any:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase is not configured")
    return supabase


def _safe_bool(value: Any) -> bool:
    return bool(value)


def _normalize_category(raw_value: Any) -> str:
    raw = str(raw_value or "").strip().lower()
    if raw in {"trades", "trade", "trade_execution", "execution"}:
        return "trades"
    if raw in {"risk", "risk_warning", "drawdown", "loss"}:
        return "risk"
    if raw in {"market", "news", "news_alert", "macro", "event"}:
        return "market"
    if raw in {"ai", "prediction", "signal", "performance", "assistant"}:
        return "ai"
    return "all"


def _extract_body(row: Dict[str, Any]) -> str:
    return str(row.get("body") or row.get("message") or "")


def _extract_timestamp(row: Dict[str, Any]) -> str:
    value = row.get("timestamp") or row.get("created_at") or row.get("sent_at")
    if isinstance(value, datetime):
        return value.isoformat()
    return str(value or "")


def _serialize_notification(row: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": str(row.get("id") or row.get("notification_id") or ""),
        "title": str(row.get("title") or ""),
        "body": _extract_body(row),
        "category": _normalize_category(
            row.get("category") or row.get("type") or row.get("event_type")
        ),
        "timestamp": _extract_timestamp(row),
        "is_read": _safe_bool(row.get("is_read") or row.get("read")),
    }


@router.get("")
async def get_notifications(
    category: str = Query(default="all"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    unread_only: bool = Query(default=False),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    category = category.strip().lower()
    if category not in VALID_CATEGORIES:
        raise HTTPException(status_code=400, detail=f"Invalid category. Must be one of: {sorted(VALID_CATEGORIES)}")

    if supabase is None:
        return {"notifications": [], "count": 0, "unread_count": 0}

    try:
        result = (
            supabase.table("notifications")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load notifications: {exc}") from exc

    all_rows = [_serialize_notification(row) for row in (result.data or [])]
    unread_count = sum(1 for row in all_rows if not row["is_read"])

    rows = all_rows
    if unread_only:
        rows = [row for row in rows if not row["is_read"]]
    if category != "all":
        rows = [row for row in rows if row["category"] == category]

    paged = rows[offset : offset + limit]
    return {
        "notifications": paged,
        "count": len(paged),
        "unread_count": unread_count,
    }


@router.patch("/{notification_id}/read")
@limiter.limit("60/minute")
async def mark_read(
    request: Request,
    notification_id: str,
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    try:
        existing = (
            client.table("notifications")
            .select("id")
            .eq("id", notification_id)
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load notification: {exc}") from exc

    if not existing.data:
        raise HTTPException(status_code=404, detail="Notification not found")

    update_payload = {
        "is_read": True,
        "read_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        client.table("notifications").update(update_payload).eq("id", notification_id).eq("user_id", user_id).execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not mark notification as read: {exc}") from exc

    return {"id": notification_id, "is_read": True}


@router.post("/read-all")
@limiter.limit("10/minute")
async def mark_all_read(
    request: Request,
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    try:
        (
            client.table("notifications")
            .update({"is_read": True, "read_at": datetime.now(timezone.utc).isoformat()})
            .eq("user_id", user_id)
            .eq("is_read", False)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not mark all notifications as read: {exc}") from exc

    return {"message": "All notifications marked as read"}


@router.delete("/{notification_id}")
@limiter.limit("30/minute")
async def dismiss_notification(
    request: Request,
    notification_id: str,
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    try:
        (
            client.table("notifications")
            .delete()
            .eq("id", notification_id)
            .eq("user_id", user_id)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not dismiss notification: {exc}") from exc

    return {"id": notification_id, "deleted": True}


@router.get("/unread-count")
async def get_unread_count(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    if supabase is None:
        return {"unread_count": 0}

    try:
        result = (
            supabase.table("notifications")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("is_read", False)
            .execute()
        )
        return {"unread_count": int(result.count or 0)}
    except Exception:
        try:
            result = (
                supabase.table("notifications")
                .select("*")
                .eq("user_id", user_id)
                .execute()
            )
            unread_count = sum(
                1 for row in (_serialize_notification(item) for item in (result.data or [])) if not row["is_read"]
            )
            return {"unread_count": unread_count}
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not compute unread count: {exc}") from exc


@router.post("/push-token")
@limiter.limit("5/minute")
async def register_push_token(
    request: Request,
    payload: PushTokenRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    body = {
        "user_id": user_id,
        "fcm_token": payload.token,
        "platform": payload.platform.strip().lower() or "web",
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }
    try:
        client.table("device_push_tokens").upsert(body, on_conflict="user_id,fcm_token").execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not register push token: {exc}") from exc

    return {"message": "Push token registered", "platform": body["platform"]}
