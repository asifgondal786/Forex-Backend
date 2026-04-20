from typing import Optional, Dict, Callable

from fastapi import APIRouter, Depends, HTTPException, status

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
from .security import get_current_user_id

router = APIRouter(prefix="/api", tags=["Engagement"])
_service_cache: Dict[str, object] = {}


def _get_service(key: str, factory: Callable[[], object]):
    existing = _service_cache.get(key)
    if existing is not None:
        return existing
    try:
        service = factory()
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase is not configured for engagement services.",
        ) from exc
    _service_cache[key] = service
    return service


def _get_activity_service() -> EngagementActivityService:
    return _get_service("activity", EngagementActivityService)  # type: ignore[return-value]


def _get_insights_service() -> EngagementInsightsService:
    return _get_service("insights", EngagementInsightsService)  # type: ignore[return-value]


def _get_explanation_service() -> EngagementExplanationService:
    return _get_service("explanation", EngagementExplanationService)  # type: ignore[return-value]


def _get_nudge_service() -> EngagementNudgeService:
    return _get_service("nudge", EngagementNudgeService)  # type: ignore[return-value]


def _get_progress_service() -> EngagementProgressService:
    return _get_service("progress", EngagementProgressService)  # type: ignore[return-value]

@router.get("/ai/activity-feed", response_model=AIActivityFeedResponse)
async def get_activity_feed(
    limit: int = 10,
    cursor: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
):
    return _get_activity_service().get_activity_feed(user_id=user_id, limit=limit, cursor=cursor)


@router.post("/ai/log-activity", response_model=dict)
async def log_activity(
    payload: AIActivityCreate,
    user_id: str = Depends(get_current_user_id),
):
    return _get_activity_service().log_activity(
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
    return _get_insights_service().get_confidence_history(user_id=user_id, period=period, points=points)


@router.get("/ai/alerts", response_model=AIAlertListResponse)
async def get_alerts(
    active: bool = True,
    limit: int = 10,
    user_id: str = Depends(get_current_user_id),
):
    return _get_insights_service().get_active_alerts(user_id=user_id, active=active, limit=limit)


@router.post("/ai/explain-decision", response_model=AIExplanationResponse)
async def explain_decision(
    payload: AIExplanationRequest,
    user_id: str = Depends(get_current_user_id),
):
    result = _get_explanation_service().create_explanation(
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
    result = _get_explanation_service().get_explanation(explanation_id)
    if not result or result.get("userId") != user_id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Explanation not found")
    return result


@router.get("/ai/nudges", response_model=AINudgeListResponse)
async def get_nudges(
    context: str = "active",
    limit: int = 5,
    user_id: str = Depends(get_current_user_id),
):
    return _get_nudge_service().get_nudges(user_id=user_id, context=context, limit=limit)


@router.post("/ai/nudge-response", response_model=dict)
async def record_nudge_response(
    payload: AINudgeResponseRequest,
    user_id: str = Depends(get_current_user_id),
):
    return _get_nudge_service().record_response(
        user_id=user_id,
        nudge_id=payload.nudge_id,
        response=payload.response,
    )


@router.get("/user/progress", response_model=UserProgressResponse)
async def get_progress(
    period: str = "week",
    user_id: str = Depends(get_current_user_id),
):
    return _get_progress_service().get_progress(user_id=user_id, period=period)


@router.get("/user/achievements", response_model=AchievementListResponse)
async def get_achievements(
    user_id: str = Depends(get_current_user_id),
):
    return _get_progress_service().get_achievements(user_id=user_id)


@router.post("/user/achievements/{achievement_id}", response_model=dict)
async def mark_achievement_seen(
    achievement_id: str,
    user_id: str = Depends(get_current_user_id),
):
    return _get_progress_service().mark_achievement_seen(user_id=user_id, achievement_id=achievement_id)
