"""
REST API endpoints
"""
from fastapi import APIRouter, BackgroundTasks
import uuid

from app.models.ml_task import MLTask, TaskResponse, TaskStatusResponse
from app.services.ml_processor import ml_processor

router = APIRouter(prefix="/api", tags=["ML Operations"])


@router.post("/train", response_model=TaskResponse)
async def train_model(task: MLTask, background_tasks: BackgroundTasks):
    """Start ML model training with live updates"""
    task_id = str(uuid.uuid4())
    
    background_tasks.add_task(
        ml_processor.train_model,
        task_id,
        task.data or {}
    )
    
    return TaskResponse(
        task_id=task_id,
        status="started",
        message="Training task started. Connect to WebSocket for live updates."
    )


@router.post("/predict/{task_id}", response_model=TaskResponse)
async def predict(task_id: str, task: MLTask, background_tasks: BackgroundTasks):
    """Make predictions with existing model"""
    
    if not ml_processor.has_model(task_id):
        return TaskResponse(
            task_id=task_id,
            status="error",
            message="No trained model found for this task_id. Train a model first."
        )
    
    background_tasks.add_task(
        ml_processor.predict,
        task_id,
        task.data or {}
    )
    
    return TaskResponse(
        task_id=task_id,
        status="started",
        message="Prediction task started. Connect to WebSocket for live updates."
    )


@router.get("/tasks/{task_id}/status", response_model=TaskStatusResponse)
async def get_task_status(task_id: str):
    """Check if task has an active model"""
    has_model = ml_processor.has_model(task_id)
    model_info = ml_processor.get_model_info(task_id)
    
    return TaskStatusResponse(
        task_id=task_id,
        has_model=has_model,
        status="ready" if has_model else "no_model",
        **{"model_info": model_info} if model_info else {}
    )


@router.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "ML Live Update Backend",
        "version": "1.0.0"
    }