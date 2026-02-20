from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from .security import get_current_user_id
from .services.subscription_service import subscription_service

router = APIRouter(prefix="/api/subscription", tags=["Subscription"])


class SubscriptionUpdateRequest(BaseModel):
    plan: str
    status: str = "active"
    source: Optional[str] = None
    renews_on: Optional[str] = None
    expires_on: Optional[str] = None


@router.get("/me")
async def get_my_subscription(user_id: str = Depends(get_current_user_id)):
    return subscription_service.get_subscription(user_id)


@router.get("/me/features")
async def get_my_feature_access(user_id: str = Depends(get_current_user_id)):
    return subscription_service.get_feature_matrix(user_id)


@router.post("/me/plan")
async def update_my_subscription_plan(
    payload: SubscriptionUpdateRequest,
    user_id: str = Depends(get_current_user_id),
):
    if not subscription_service.allow_self_service_management and not user_id.startswith("dev_"):
        raise HTTPException(
            status_code=403,
            detail="Subscription plan changes are disabled for self-service.",
        )

    return subscription_service.set_subscription(
        user_id=user_id,
        plan=payload.plan,
        status=payload.status,
        source=payload.source or "self_service",
        renews_on=payload.renews_on,
        expires_on=payload.expires_on,
    )
