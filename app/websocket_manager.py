from fastapi import WebSocket, WebSocketDisconnect
from typing import Dict, Set
import json
import asyncio
from datetime import datetime
import uuid

class ConnectionManager:
    def __init__(self):
        # Map of task_id to set of WebSocket connections
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        # Map of WebSocket to task_id for cleanup
        self.connection_tasks: Dict[WebSocket, str] = {}
    
    async def connect(self, websocket: WebSocket, task_id: str):
        """Connect a client to a specific task's updates"""
        await websocket.accept()
        
        if task_id not in self.active_connections:
            self.active_connections[task_id] = set()
        
        self.active_connections[task_id].add(websocket)
        self.connection_tasks[websocket] = task_id
        
        print(f"Client connected to task {task_id}. Total connections: {len(self.active_connections[task_id])}")
    
    def disconnect(self, websocket: WebSocket):
        """Disconnect a client and cleanup"""
        if websocket in self.connection_tasks:
            task_id = self.connection_tasks[websocket]
            
            if task_id in self.active_connections:
                self.active_connections[task_id].discard(websocket)
                
                # Clean up empty task connection sets
                if not self.active_connections[task_id]:
                    del self.active_connections[task_id]
            
            del self.connection_tasks[websocket]
            print(f"Client disconnected from task {task_id}")
    
    async def send_update(self, task_id: str, update: dict):
        """Send an update to all clients subscribed to a task"""
        if task_id not in self.active_connections:
            return
        
        # Create list of connections to avoid modification during iteration
        connections = list(self.active_connections[task_id])
        disconnected = []
        
        for connection in connections:
            try:
                await connection.send_json(update)
            except Exception as e:
                print(f"Error sending to connection: {e}")
                disconnected.append(connection)
        
        # Clean up disconnected clients
        for connection in disconnected:
            self.disconnect(connection)
    
    async def broadcast_update(self, update: dict):
        """Broadcast an update to all connected clients"""
        for task_id in list(self.active_connections.keys()):
            await self.send_update(task_id, update)
    
    def get_connection_count(self, task_id: str) -> int:
        """Get the number of active connections for a task"""
        return len(self.active_connections.get(task_id, set()))


class LiveUpdateService:
    def __init__(self, manager: ConnectionManager):
        self.manager = manager
    
    async def send_info(self, task_id: str, message: str):
        """Send an info update"""
        await self._send_update(task_id, message, "info")
    
    async def send_success(self, task_id: str, message: str):
        """Send a success update"""
        await self._send_update(task_id, message, "success")
    
    async def send_warning(self, task_id: str, message: str):
        """Send a warning update"""
        await self._send_update(task_id, message, "warning")
    
    async def send_error(self, task_id: str, message: str):
        """Send an error update"""
        await self._send_update(task_id, message, "error")
    
    async def send_progress(self, task_id: str, message: str, progress: float):
        """Send a progress update"""
        await self._send_update(task_id, message, "progress", progress)
    
    async def _send_update(self, task_id: str, message: str, update_type: str, progress: float = None):
        """Internal method to send updates"""
        update = {
            "id": str(uuid.uuid4()),
            "task_id": task_id,
            "message": message,
            "type": update_type,
            "timestamp": datetime.utcnow().isoformat(),
            "progress": progress
        }
        
        await self.manager.send_update(task_id, update)


# Global instance
manager = ConnectionManager()
live_update_service = LiveUpdateService(manager)