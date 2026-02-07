from datetime import datetime
from typing import List, Optional, Literal, Dict, Any
from pydantic import BaseModel, Field, ConfigDict


class BaseSchema(BaseModel):
    model_config = ConfigDict(populate_by_name=True)


class AIActivity(BaseSchema):
    id: str
    user_id: str = Field(alias="userId")
    type: Literal["scan", "evaluate", "monitor", "alert", "decision"]
    message: str
    timestamp: datetime
    emoji: Optional[str] = None
    color: Optional[str] = None


class AIActivityCreate(BaseSchema):
    type: Literal["scan", "evaluate", "monitor", "alert", "decision"]
    message: str
    emoji: Optional[str] = None
    color: Optional[str] = None


class AIActivityFeedResponse(BaseSchema):
    activities: List[AIActivity]
    next_cursor: Optional[str] = None


class AIConfidenceHistoryResponse(BaseSchema):
    current: float
    trend: Literal["up", "down", "flat"]
    change_24h: float
    reason: str
    historical: List[float]
    timestamp: datetime


class AIAlert(BaseSchema):
    id: str
    user_id: str = Field(alias="userId")
    type: str
    icon: str
    title: str
    message: str
    severity: Literal["info", "warning", "success"]
    action: Optional[str] = None
    timestamp: datetime
    active: bool = True


class AIAlertListResponse(BaseSchema):
    alerts: List[AIAlert]


class AIExplanationFactor(BaseSchema):
    category: str
    score: float
    components: List[Dict[str, Any]]


class AIExplanationRequest(BaseSchema):
    decision_id: str = Field(alias="decisionId")
    type: str
    factors: Optional[List[AIExplanationFactor]] = None
    overall_reasoning: Optional[str] = Field(default=None, alias="overallReasoning")


class AIExplanationResponse(BaseSchema):
    id: str
    user_id: str = Field(alias="userId")
    decision_id: str = Field(alias="decisionId")
    type: str
    factors: List[AIExplanationFactor]
    overall_reasoning: str = Field(alias="overallReasoning")
    timestamp: datetime


class AINudge(BaseSchema):
    id: str
    user_id: str = Field(alias="userId")
    type: Literal["suggestion", "praise", "alert", "tip"]
    emoji: str
    title: str
    message: str
    action: Optional[str] = None
    priority: Literal["low", "medium", "high"]
    display_until: Optional[datetime] = Field(default=None, alias="displayUntil")
    timestamp: datetime
    active: bool = True


class AINudgeListResponse(BaseSchema):
    nudges: List[AINudge]


class AINudgeResponseRequest(BaseSchema):
    nudge_id: str = Field(alias="nudgeId")
    response: Literal["accepted", "dismissed", "snoozed"]


class Achievement(BaseSchema):
    id: str
    user_id: str = Field(alias="userId")
    title: str
    description: str
    seen: bool
    timestamp: datetime


class UserProgressResponse(BaseSchema):
    period: str
    metrics: Dict[str, Any]
    achievements: List[Achievement]
    timestamp: datetime


class AchievementListResponse(BaseSchema):
    achievements: List[Achievement]
