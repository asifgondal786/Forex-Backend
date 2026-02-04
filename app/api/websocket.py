"""
WebSocket API endpoints
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import json

from app.services.connection_manager import manager

router = APIRouter()


@router.websocket("/ws/{task_id}")
async def websocket_endpoint(websocket: WebSocket, task_id: str):
    """WebSocket endpoint for live updates"""
    await manager.connect(task_id, websocket)
    
    try:
        while True:
            # Keep connection alive and handle heartbeat
            data = await websocket.receive_text()
            
            # Echo back for heartbeat
            await websocket.send_text(
                json.dumps({"status": "connected", "task_id": task_id})
            )
            
    except WebSocketDisconnect:
        manager.disconnect(task_id)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(task_id)