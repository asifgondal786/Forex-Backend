"""
WebSocket Connection Manager
"""
from fastapi import WebSocket
from typing import Dict
import logging

logger = logging.getLogger(__name__)


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
    
    async def connect(self, task_id: str, websocket: WebSocket):
        """Accept and store WebSocket connection"""
        self.active_connections[task_id] = websocket
        logger.info(f"✓ Client connected: {task_id}")
    
    def disconnect(self, task_id: str):
        """Remove WebSocket connection"""
        if task_id in self.active_connections:
            del self.active_connections[task_id]
            logger.info(f"✗ Client disconnected: {task_id}")
    
    async def send_update(self, task_id: str, update):
        """Send live update to specific task's WebSocket"""
        if task_id in self.active_connections:
            try:
                await self.active_connections[task_id].send_text(
                    update.model_dump_json()
                )
            except Exception as e:
                logger.error(f"Error sending update: {e}")
                self.disconnect(task_id)
    
    def is_connected(self, task_id: str) -> bool:
        """Check if task has active WebSocket connection"""
        return task_id in self.active_connections


# Global instance
manager = ConnectionManager()