"""
ML Task request/response models
"""
from pydantic import BaseModel
from typing import Optional, Dict


class MLTask(BaseModel):
    task_type: str  # "train", "predict", "evaluate"
    data: Optional[Dict] = None
    model_name: Optional[str] = "random_forest"


class TaskResponse(BaseModel):
    task_id: str
    status: str
    message: str


class TaskStatusResponse(BaseModel):
    task_id: str
    has_model: bool
    status: str