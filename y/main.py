from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import logging
from typing import List
import json
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        logger.info(f"Client connected. Total connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        logger.info(f"Client disconnected. Total connections: {len(self.active_connections)}")

    async def send_personal_message(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except Exception as e:
                logger.error(f"Error broadcasting message: {e}")

manager = ConnectionManager()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    logger.info("🚀 Starting Forex Companion Backend...")
    logger.info("📊 Server ready to accept connections")
    yield
    # Shutdown
    logger.info("👋 Shutting down Forex Companion Backend...")

# Create FastAPI app
app = FastAPI(
    title="Forex Companion API",
    description="AI-powered Forex trading assistant backend",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint
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
        "timestamp": datetime.now().isoformat()
    }

# WebSocket endpoint
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, user_id: str = None):
    await manager.connect(websocket)
    try:
        # Send welcome message
        await manager.send_personal_message(
            json.dumps({
                "type": "connection",
                "message": "Connected to Forex Companion",
                "timestamp": datetime.now().isoformat()
            }),
            websocket
        )
        
        # Listen for messages
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            # Echo back for now (you can add real logic later)
            response = {
                "type": "echo",
                "received": message_data,
                "timestamp": datetime.now().isoformat()
            }
            await manager.send_personal_message(json.dumps(response), websocket)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        logger.info("Client disconnected normally")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)

# API Routes
@app.get("/api/tasks/")
async def get_tasks():
    """Get all tasks"""
    return {
        "tasks": [],
        "total": 0
    }

@app.post("/api/tasks/")
async def create_task(task_data: dict):
    """Create a new task"""
    return {
        "message": "Task created",
        "task": task_data
    }

@app.get("/api/tasks/{task_id}")
async def get_task(task_id: str):
    """Get a specific task"""
    return {
        "id": task_id,
        "message": "Task details"
    }

@app.put("/api/tasks/{task_id}/stop")
async def stop_task(task_id: str):
    """Stop a running task"""
    return {
        "id": task_id,
        "status": "stopped"
    }

@app.put("/api/tasks/{task_id}/pause")
async def pause_task(task_id: str):
    """Pause a running task"""
    return {
        "id": task_id,
        "status": "paused"
    }

@app.put("/api/tasks/{task_id}/resume")
async def resume_task(task_id: str):
    """Resume a paused task"""
    return {
        "id": task_id,
        "status": "running"
    }

@app.delete("/api/tasks/{task_id}")
async def delete_task(task_id: str):
    """Delete a task"""
    return {
        "message": "Task deleted",
        "id": task_id
    }

@app.get("/api/users/me")
async def get_current_user():
    """Get current user info"""
    return {
        "id": "user_1",
        "email": "user@example.com",
        "name": "Test User"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080, reload=True)