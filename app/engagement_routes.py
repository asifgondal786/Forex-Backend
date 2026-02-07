import os
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status, Header
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from .schemas.engagement import (
    AIActivityCreate,
    AIActivityFeedResponse,
    AIConfidenceHistoryResponse,
    AIAlertListResponse,
    AIExplanationRequest,
    AIExplanationResponse,
    AINudgeListResponse,
    AINudgeResponseRequest,
    UserProgressResponse,
    AchievementListResponse,
)
from .services.engagement_activity_service import EngagementActivityService
from .services.engagement_insights_service import EngagementInsightsService
from .services.engagement_explanation_service import EngagementExplanationService
from .services.engagement_nudge_service import EngagementNudgeService
from .services.engagement_progress_service import EngagementProgressService
from .utils.firestore_client import verify_firebase_token

router = APIRouter(prefix="/api", tags=["Engagement"])
security = HTTPBearer(auto_error=False)

activity_service = EngagementActivityService()
insights_service = EngagementInsightsService()
explanation_service = EngagementExplanationService()
nudge_service = EngagementNudgeService()
progress_service = EngagementProgressService()


async def get_current_user_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    x_user_id: Optional[str] = Header(default=None),
) -> str:
    allow_dev = os.getenv("ALLOW_DEV_USER_ID", "").lower() == "true"
    if x_user_id and allow_dev:
        return x_user_id

    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing Authorization header",
        )

    try:
        decoded = verify_firebase_token(credentials.credentials)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token",
        )

    user_id = decoded.get("uid") or decoded.get("user_id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Firebase token payload",
        )

    return user_id


@router.get("/ai/activity-feed", response_model=AIActivityFeedResponse)
async def get_activity_feed(
    limit: int = 10,
    cursor: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
):
    return activity_service.get_activity_feed(user_id=user_id, limit=limit, cursor=cursor)


@router.post("/ai/log-activity", response_model=dict)
async def log_activity(
    payload: AIActivityCreate,
    user_id: str = Depends(get_current_user_id),
):
    return activity_service.log_activity(
        user_id=user_id,
        activity_type=payload.type,
        message=payload.message,
        emoji=payload.emoji,
        color=payload.color,
    )


@router.get("/ai/confidence-history", response_model=AIConfidenceHistoryResponse)
async def get_confidence_history(
    period: str = "24h",
    points: int = 7,
    user_id: str = Depends(get_current_user_id),
):
    return insights_service.get_confidence_history(user_id=user_id, period=period, points=points)


@router.get("/ai/alerts", response_model=AIAlertListResponse)
async def get_alerts(
    active: bool = True,
    limit: int = 10,
    user_id: str = Depends(get_current_user_id),
):
    return insights_service.get_active_alerts(user_id=user_id, active=active, limit=limit)


@router.post("/ai/explain-decision", response_model=AIExplanationResponse)
async def explain_decision(
    payload: AIExplanationRequest,
    user_id: str = Depends(get_current_user_id),
):
    result = explanation_service.create_explanation(
        user_id=user_id,
        decision_id=payload.decision_id,
        explanation_type=payload.type,
        factors=[factor.model_dump() for factor in (payload.factors or [])],
        overall_reasoning=payload.overall_reasoning,
    )
    return result


@router.get("/ai/explanation/{explanation_id}", response_model=AIExplanationResponse)
async def get_explanation(
    explanation_id: str,
    user_id: str = Depends(get_current_user_id),
):
    result = explanation_service.get_explanation(explanation_id)
    if not result or result.get("userId") != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Explanation not found")
    return result


@router.get("/ai/nudges", response_model=AINudgeListResponse)
async def get_nudges(
    context: str = "active",
    limit: int = 5,
    user_id: str = Depends(get_current_user_id),
):
    return nudge_service.get_nudges(user_id=user_id, context=context, limit=limit)


@router.post("/ai/nudge-response", response_model=dict)
async def record_nudge_response(
    payload: AINudgeResponseRequest,
    user_id: str = Depends(get_current_user_id),
):
    return nudge_service.record_response(
        user_id=user_id,
        nudge_id=payload.nudge_id,
        response=payload.response,
    )


@router.get("/user/progress", response_model=UserProgressResponse)
async def get_progress(
    period: str = "week",
    user_id: str = Depends(get_current_user_id),
):
    return progress_service.get_progress(user_id=user_id, period=period)


@router.get("/user/achievements", response_model=AchievementListResponse)
async def get_achievements(
    user_id: str = Depends(get_current_user_id),
):
    return progress_service.get_achievements(user_id=user_id)


@router.post("/user/achievements/{achievement_id}", response_model=dict)
async def mark_achievement_seen(
    achievement_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return progress_service.mark_achievement_seen(user_id=user_id, achievement_id=achievement_id)
