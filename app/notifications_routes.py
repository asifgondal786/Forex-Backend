from fastapi import APIRouter, Depends

from .security import get_current_user_id
from .services.enhanced_notification_service import EnhancedNotificationService

router = APIRouter(prefix="/api/notifications", tags=["Notifications"])
_service: EnhancedNotificationService | None = None


def _get_service() -> EnhancedNotificationService:
    global _service
    if _service is None:
        _service = EnhancedNotificationService()
    return _service


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
