from fastapi import APIRouter, Depends, HTTPException, status

from .schemas.settings import SettingsResponse, SettingsUpdateRequest
from .services.settings_service import SettingsService
from .security import get_current_user_id

router = APIRouter(prefix="/api", tags=["Settings"])
_service: SettingsService | None = None


def _get_service() -> SettingsService:
    global _service
    if _service is not None:
        return _service
    try:
        _service = SettingsService()
        return _service
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase is not configured for settings.",
        ) from exc


@router.get("/settings", response_model=SettingsResponse)
async def get_settings(user_id: str = Depends(get_current_user_id)):
    return _get_service().get_settings(user_id=user_id)


@router.patch("/settings", response_model=SettingsResponse)
async def update_settings(
    payload: SettingsUpdateRequest,
    user_id: str = Depends(get_current_user_id),
):
    return _get_service().update_settings(
        user_id=user_id,
        updates=payload.settings,
        replace=payload.replace,
    )
