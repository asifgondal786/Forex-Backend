"""
LiveUpdate model matching Flutter implementation
"""
from pydantic import BaseModel
from typing import Optional
from enum import Enum
from datetime import datetime


class UpdateType(str, Enum):
    INFO = "info"
    SUCCESS = "success"
    WARNING = "warning"
    ERROR = "error"
    PROGRESS = "progress"


class LiveUpdate(BaseModel):
    id: str
    task_id: str
    message: str
    type: UpdateType
    timestamp: str
    progress: Optional[float] = None

    class Config:
        json_schema_extra = {
            "example": {
                "id": "uuid-123",
                "task_id": "task-456",
                "message": "Training in progress...",
                "type": "progress",
                "timestamp": "2026-01-14T10:30:00.000Z",
                "progress": 0.5
            }
        }