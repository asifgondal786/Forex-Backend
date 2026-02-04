"""
Forex Companion Backend - Main Application
"""
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import logging
import json
import uuid
import asyncio
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Import services (we'll create these)
from app.services.connection_manager import manager
from app.services.ml_processor import ml_processor
from app.models.live_update import LiveUpdate, UpdateType

# ============================================================================
# DATA MODELS
# ============================================================================

class TaskCreate(BaseModel):
    title: str
    description: str
    priority: str  # "low", "medium", "high"

class Task(BaseModel):
    id: str
    userId: Optional[str] = None
    title: str
    description: str
    status: str  # "pending", "running", "completed", "failed", "paused"
    priority: str
    createdAt: datetime
    startTime: Optional[datetime] = None
    endTime: Optional[datetime] = None
    currentStep: int = 0
    totalSteps: int = 0
    steps: List[dict] = []
    resultFileUrl: Optional[str] = None
    resultFileName: Optional[str] = None
    resultFileSize: Optional[int] = None

# ============================================================================
# IN-MEMORY STORAGE (Replace with database in production)
# ============================================================================

tasks_db: dict = {}  # task_id: Task

# ============================================================================
# BACKGROUND TASK PROCESSORS
# ============================================================================

async def process_forex_analysis_task(task_id: str, task_data: dict):
    """
    Process a forex analysis task with live updates
    """
    try:
        task = tasks_db.get(task_id)
        if not task:
            return
        
        # Update task status
        task["status"] = "running"
        task["startTime"] = datetime.now().isoformat()
        
        # Define steps
        steps = [
            {"name": "Initializing AI analysis", "isCompleted": False},
            {"name": "Fetching market data", "isCompleted": False},
            {"name": "Analyzing trends", "isCompleted": False},
            {"name": "Generating predictions", "isCompleted": False},
            {"name": "Compiling report", "isCompleted": False},
        ]
        task["steps"] = steps
        task["totalSteps"] = len(steps)
        
        # Send live updates for each step
        for i, step in enumerate(steps):
            # Update step status
            task["currentStep"] = i + 1
            step["isCompleted"] = True
            step["completedAt"] = datetime.now().isoformat()
            
            # Send live update via WebSocket
            update = LiveUpdate(
                id=str(uuid.uuid4()),
                task_id=task_id,
                message=f"✓ {step['name']}...",
                type=UpdateType.PROGRESS if i < len(steps) - 1 else UpdateType.SUCCESS,
                timestamp=datetime.now().isoformat() + "Z",
                progress=(i + 1) / len(steps)
            )
            await manager.send_update(task_id, update)
            
            # Simulate processing time
            await asyncio.sleep(2)
        
        # Mark task as completed
        task["status"] = "completed"
        task["endTime"] = datetime.now().isoformat()
        task["resultFileName"] = f"forex_analysis_{task_id}.pdf"
        task["resultFileUrl"] = f"https://example.com/results/{task_id}.pdf"
        task["resultFileSize"] = 128000  # 128 KB
        
        # Send final success update
        final_update = LiveUpdate(
            id=str(uuid.uuid4()),
            task_id=task_id,
            message="🎉 Analysis complete! Report is ready for download.",
            type=UpdateType.SUCCESS,
            timestamp=datetime.now().isoformat() + "Z",
            progress=1.0
        )
        await manager.send_update(task_id, final_update)
        
        logger.info(f"Task {task_id} completed successfully")
        
    except Exception as e:
        logger.error(f"Error processing task {task_id}: {e}")
        if task_id in tasks_db:
            tasks_db[task_id]["status"] = "failed"
            
            error_update = LiveUpdate(
                id=str(uuid.uuid4()),
                task_id=task_id,
                message=f"❌ Task failed: {str(e)}",
                type=UpdateType.ERROR,
                timestamp=datetime.now().isoformat() + "Z"
            )
            await manager.send_update(task_id, error_update)

async def process_ml_training_task(task_id: str, task_data: dict):
    """
    Process ML model training with live updates
    """
    try:
        await ml_processor.train_model(task_id, {})
        
        # Update task in database
        if task_id in tasks_db:
            tasks_db[task_id]["status"] = "completed"
            tasks_db[task_id]["endTime"] = datetime.now().isoformat()
            
    except Exception as e:
        logger.error(f"ML training failed for task {task_id}: {e}")
        if task_id in tasks_db:
            tasks_db[task_id]["status"] = "failed"

# ============================================================================
# APPLICATION LIFECYCLE
# ============================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("🚀 Starting Forex Companion Backend...")
    logger.info("📊 Server ready to accept connections")
    logger.info(f"🔧 Environment: {os.getenv('DEBUG', 'False')}")
    yield
    # Shutdown
    logger.info("👋 Shutting down Forex Companion Backend...")

# ============================================================================
# FASTAPI APPLICATION
# ============================================================================

app = FastAPI(
    title="Forex Companion API",
    description="AI-powered Forex trading assistant backend",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================================
# HEALTH CHECK ENDPOINTS
# ============================================================================

@app.get("/")
async def root():
    return {
        "message": "Forex Companion API",
        "status": "running",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "services": {
            "websocket": "operational",
            "ml_processor": "operational"
        }
    }

# ============================================================================
# WEBSOCKET ENDPOINT
# ============================================================================

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, user_id: str = None):
    task_id = None
    try:
        await websocket.accept()
        logger.info(f"WebSocket connection accepted for user: {user_id}")
        
        # Wait for subscription message
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)
            
            if message.get("type") == "subscribe":
                task_id = message.get("task_id")
                await manager.connect(task_id, websocket)
                logger.info(f"Client subscribed to task: {task_id}")
                
                # Send confirmation
                await websocket.send_text(json.dumps({
                    "type": "connection",
                    "message": f"Subscribed to task {task_id}",
                    "timestamp": datetime.now().isoformat()
                }))
            
            elif message.get("type") == "unsubscribe":
                if task_id:
                    manager.disconnect(task_id)
                    logger.info(f"Client unsubscribed from task: {task_id}")
                    task_id = None
                    
    except WebSocketDisconnect:
        if task_id:
            manager.disconnect(task_id)
        logger.info(f"WebSocket disconnected for user: {user_id}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        if task_id:
            manager.disconnect(task_id)

# ============================================================================
# TASK MANAGEMENT ENDPOINTS
# ============================================================================

@app.get("/api/tasks/")
async def get_tasks(user_id: str = "default_user"):
    """Get all tasks for a user"""
    user_tasks = [
        task for task in tasks_db.values() 
        if task.get("userId") == user_id or task.get("userId") is None
    ]
    return {
        "tasks": user_tasks,
        "total": len(user_tasks)
    }

@app.post("/api/tasks/")
async def create_task(
    task_data: TaskCreate, 
    background_tasks: BackgroundTasks,
    user_id: str = "default_user"
):
    """Create a new task"""
    task_id = str(uuid.uuid4())
    
    task = {
        "id": task_id,
        "userId": user_id,
        "title": task_data.title,
        "description": task_data.description,
        "status": "pending",
        "priority": task_data.priority,
        "createdAt": datetime.now().isoformat(),
        "startTime": None,
        "endTime": None,
        "currentStep": 0,
        "totalSteps": 0,
        "steps": [],
        "resultFileUrl": None,
        "resultFileName": None,
        "resultFileSize": None
    }
    
    tasks_db[task_id] = task
    
    # Determine task type and start background processing
    if "market" in task_data.title.lower() or "forex" in task_data.title.lower():
        background_tasks.add_task(process_forex_analysis_task, task_id, task)
    elif "train" in task_data.title.lower() or "ml" in task_data.title.lower():
        background_tasks.add_task(process_ml_training_task, task_id, task)
    else:
        # Default processing
        background_tasks.add_task(process_forex_analysis_task, task_id, task)
    
    logger.info(f"Created task: {task_id} - {task_data.title}")
    
    return task

@app.get("/api/tasks/{task_id}")
async def get_task(task_id: str):
    """Get a specific task"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    return tasks_db[task_id]

@app.put("/api/tasks/{task_id}/stop")
async def stop_task(task_id: str):
    """Stop a running task"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    tasks_db[task_id]["status"] = "paused"
    tasks_db[task_id]["endTime"] = datetime.now().isoformat()
    
    return tasks_db[task_id]

@app.put("/api/tasks/{task_id}/pause")
async def pause_task(task_id: str):
    """Pause a running task"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    tasks_db[task_id]["status"] = "paused"
    
    return tasks_db[task_id]

@app.put("/api/tasks/{task_id}/resume")
async def resume_task(task_id: str):
    """Resume a paused task"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    tasks_db[task_id]["status"] = "running"
    
    return tasks_db[task_id]

@app.delete("/api/tasks/{task_id}")
async def delete_task(task_id: str):
    """Delete a task"""
    if task_id not in tasks_db:
        raise HTTPException(status_code=404, detail="Task not found")
    
    del tasks_db[task_id]
    
    return {"message": "Task deleted", "id": task_id}

# ============================================================================
# USER MANAGEMENT ENDPOINTS
# ============================================================================

@app.get("/api/users/me")
async def get_current_user():
    """Get current user info"""
    return {
        "id": "user_1",
        "email": "sohaib@forexcompanion.com",
        "name": "Sohaib"
    }

# ============================================================================
# RUN SERVER
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=port, 
        reload=True,
        log_level="info"
    )