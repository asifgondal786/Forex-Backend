from typing import Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status, Body

from .schemas.header import HeaderResponse, HeaderUpdateRequest, HeaderStreamUpdateRequest
from .services.header_service import HeaderService
from .security import get_token_claims
from .enhanced_websocket_manager import ws_manager

router = APIRouter(prefix="/api", tags=["Header"])
_service: HeaderService | None = None


def _get_service() -> HeaderService:
    global _service
    if _service is not None:
        return _service
    try:
        _service = HeaderService()
        return _service
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase is not configured for header data.",
        ) from exc


def _get_user_id_from_claims(claims: Dict[str, Any]) -> str:
    user_id = claims.get("uid") or claims.get("user_id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token payload",
        )
    return user_id


@router.get("/header", response_model=HeaderResponse)
async def get_header(
    claims: Dict[str, Any] = Depends(get_token_claims),
):
    user_id = _get_user_id_from_claims(claims)
    return _get_service().get_header(user_id=user_id, claims=claims)


@router.patch("/header", response_model=HeaderResponse)
async def update_header(
    payload: HeaderUpdateRequest,
    claims: Dict[str, Any] = Depends(get_token_claims),
):
    user_id = _get_user_id_from_claims(claims)
    updates = payload.model_dump(exclude_none=True, by_alias=False)
    return _get_service().update_header(user_id=user_id, updates=updates, claims=claims)


@router.post("/header/stream", response_model=HeaderResponse)
async def update_header_stream(
    payload: HeaderStreamUpdateRequest = Body(default_factory=HeaderStreamUpdateRequest),
    claims: Dict[str, Any] = Depends(get_token_claims),
):
    user_id = _get_user_id_from_claims(claims)
    enabled = payload.enabled
    interval = payload.interval or ws_manager.get_forex_stream_interval()

    if enabled is None:
        enabled = not ws_manager.is_forex_stream_running()

    if enabled:
        await ws_manager.start_forex_stream(interval=interval)
    else:
        ws_manager.stop_forex_stream()

    return _get_service().get_header(user_id=user_id, claims=claims)
