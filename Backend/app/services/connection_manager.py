"""
WebSocket Connection Manager
"""
from fastapi import WebSocket
from typing import Dict
from app.models.live_update import LiveUpdate


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
    
    async def connect(self, task_id: str, websocket: WebSocket):
        """Accept and store WebSocket connection"""
        await websocket.accept()
        self.active_connections[task_id] = websocket
        print(f"✓ Client connected: {task_id}")
    
    def disconnect(self, task_id: str):
        """Remove WebSocket connection"""
        if task_id in self.active_connections:
            del self.active_connections[task_id]
            print(f"✗ Client disconnected: {task_id}")
    
    async def send_update(self, task_id: str, update: LiveUpdate):
        """Send live update to specific task's WebSocket"""
        if task_id in self.active_connections:
            try:
                await self.active_connections[task_id].send_text(
                    update.model_dump_json()
                )
            except Exception as e:
                print(f"Error sending update: {e}")
                self.disconnect(task_id)
    
    def is_connected(self, task_id: str) -> bool:
        """Check if task has active WebSocket connection"""
        return task_id in self.active_connections


# Global instance
manager = ConnectionManager()