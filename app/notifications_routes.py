from fastapi import APIRouter, Depends
from pydantic import BaseModel
from typing import List, Optional

from .security import get_current_user_id
from .services.enhanced_notification_service import EnhancedNotificationService

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])
_service: EnhancedNotificationService | None = None


def _get_service() -> EnhancedNotificationService:
    global _service
    if _service is None:
        _service = EnhancedNotificationService()
    return _service


class NotificationPreferences(BaseModel):
    enabled_channels: Optional[List[str]] = None
    disabled_categories: Optional[List[str]] = None
    quiet_hours_start: Optional[str] = None
    quiet_hours_end: Optional[str] = None
    max_per_hour: Optional[int] = None
    digest_mode: Optional[bool] = None
    autonomous_mode: Optional[bool] = None
    autonomous_profile: Optional[str] = None
    autonomous_min_confidence: Optional[float] = None
    channel_settings: Optional[dict] = None


class NotificationRequest(BaseModel):
    template_id: str
    category: str
    priority: str = "medium"
    variables: dict = {}


class AutonomousStudyRequest(BaseModel):
    pair: str = "EUR/USD"
    user_instruction: Optional[str] = None
    priority: Optional[str] = None


@router.get("")
async def list_notifications(
    unread_only: bool = False,
    limit: int = 20,
    user_id: str = Depends(get_current_user_id),
):
    return await _get_service().get_notifications(user_id=user_id, unread_only=unread_only, limit=limit)


@router.post("/{notification_id}/read")
async def mark_notification_read(
    notification_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return await _get_service().mark_as_read(notification_id, user_id=user_id)


@router.post("/preferences")
async def set_notification_preferences(
    preferences: NotificationPreferences,
    user_id: str = Depends(get_current_user_id),
):
    return await _get_service().set_notification_preferences(
        user_id=user_id,
        enabled_channels=preferences.enabled_channels,
        disabled_categories=preferences.disabled_categories,
        quiet_hours_start=preferences.quiet_hours_start,
        quiet_hours_end=preferences.quiet_hours_end,
        max_per_hour=preferences.max_per_hour,
        digest_mode=preferences.digest_mode,
        autonomous_mode=preferences.autonomous_mode,
        autonomous_profile=preferences.autonomous_profile,
        autonomous_min_confidence=preferences.autonomous_min_confidence,
        channel_settings=preferences.channel_settings,
    )


@router.get("/preferences")
async def get_notification_preferences(
    user_id: str = Depends(get_current_user_id),
):
    return await _get_service().get_notification_settings_panel(user_id=user_id)


@router.post("/send")
async def send_notification(
    request: NotificationRequest,
    user_id: str = Depends(get_current_user_id),
):
    return await _get_service().send_notification(
        user_id=user_id,
        template_id=request.template_id,
        category=request.category,
        priority=request.priority,
        **request.variables
    )


@router.post("/autonomous-study")
async def send_autonomous_study_notification(
    request: AutonomousStudyRequest,
    user_id: str = Depends(get_current_user_id),
):
    return await _get_service().send_autonomous_study_notification(
        user_id=user_id,
        pair=request.pair,
        user_instruction=request.user_instruction,
        priority=request.priority,
    )


@router.get("/deep-study")
async def get_deep_study(
    pair: str = "EUR/USD",
    max_headlines_per_source: int = 3,
    user_id: str = Depends(get_current_user_id),
):
    _ = user_id
    return await _get_service().get_deep_study(
        pair=pair,
        max_headlines_per_source=max_headlines_per_source,
    )


@router.get("/digest")
async def get_notification_digest(
    period: str = "daily",
    user_id: str = Depends(get_current_user_id),
):
    return await _get_service().generate_digest(user_id=user_id, period=period)
