from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import uuid

# Import the WebSocket manager
from .websocket_manager import manager, live_update_service

router = APIRouter(prefix="/api/updates", tags=["updates"])


class UpdateRequest(BaseModel):
    task_id: str
    message: str
    type: str  # info, success, warning, error, progress
    progress: Optional[float] = None


@router.websocket("/ws/{task_id}")
async def websocket_endpoint(websocket: WebSocket, task_id: str):
    """
    WebSocket endpoint for receiving live updates for a specific task
    Connect from Flutter: ws://localhost:8000/api/updates/ws/{task_id}
    """
    await manager.connect(websocket, task_id)
    
    try:
        # Send initial connection confirmation
        await websocket.send_json({
            "id": str(uuid.uuid4()),
            "task_id": task_id,
            "message": "Connected to live updates",
            "type": "info",
            "timestamp": datetime.utcnow().isoformat(),
            "progress": None
        })
        
        # Keep connection alive and handle incoming messages
        while True:
            # Wait for any message from client (ping/pong or commands)
            data = await websocket.receive_text()
            
            # Echo back to confirm connection is alive
            if data == "ping":
                await websocket.send_text("pong")
    
    except WebSocketDisconnect:
        manager.disconnect(websocket)
        print(f"Client disconnected from task {task_id}")
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(websocket)


@router.post("/send")
async def send_update(update: UpdateRequest):
    """
    HTTP endpoint to send updates to all clients watching a task
    This is called by your backend services to push updates
    """
    try:
        if update.type == "info":
            await live_update_service.send_info(update.task_id, update.message)
        elif update.type == "success":
            await live_update_service.send_success(update.task_id, update.message)
        elif update.type == "warning":
            await live_update_service.send_warning(update.task_id, update.message)
        elif update.type == "error":
            await live_update_service.send_error(update.task_id, update.message)
        elif update.type == "progress":
            if update.progress is None:
                raise HTTPException(status_code=400, detail="Progress value required for progress updates")
            await live_update_service.send_progress(update.task_id, update.message, update.progress)
        else:
            raise HTTPException(status_code=400, detail="Invalid update type")
        
        return {"status": "sent", "task_id": update.task_id}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/connections/{task_id}")
async def get_connection_count(task_id: str):
    """Get the number of active connections for a task"""
    count = manager.get_connection_count(task_id)
    return {"task_id": task_id, "connections": count}