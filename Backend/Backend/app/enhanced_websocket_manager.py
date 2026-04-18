"""
Enhanced WebSocket Manager with Live Forex Data Integration
"""
from fastapi import WebSocket
from typing import Any, Dict, Set, Optional
import asyncio
import uuid
from datetime import datetime
import os

from .services.redis_store import redis_store


class EnhancedWebSocketManager:
    """Manages WebSocket connections and broadcasts live forex updates"""

    def __init__(self):
        # Store active connections: {task_id: Set[WebSocket]}
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        # Store all connections for broadcasts
        self.all_connections: Set[WebSocket] = set()
        # Connection registry for diagnostics and lifecycle tracking
        self.connection_registry: Dict[str, Dict[str, Any]] = {}
        self.websocket_to_connection_id: Dict[int, str] = {}
        # Track streaming tasks
        self.streaming_tasks: Dict[str, asyncio.Task] = {}
        # Track forex stream interval
        try:
            self.forex_stream_interval = int(os.getenv("FOREX_STREAM_INTERVAL", "10"))
        except ValueError:
            self.forex_stream_interval = 10
        # Engagement logging (Firestore)
        self.engagement_logging_enabled = os.getenv("ENABLE_ENGAGEMENT_LOGGING", "").lower() != "false"
        self._activity_logger = None

    def _schedule_background_task(self, coroutine):
        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            return
        loop.create_task(coroutine)

    async def connect(
        self,
        websocket: WebSocket,
        task_id: str = "global",
        user_id: Optional[str] = None,
    ) -> str:
        """Accept a new WebSocket connection"""
        await websocket.accept()

        # Add to task-specific connections
        if task_id not in self.active_connections:
            self.active_connections[task_id] = set()
        self.active_connections[task_id].add(websocket)

        # Add to all connections
        self.all_connections.add(websocket)

        connection_id = str(uuid.uuid4())
        now = datetime.now().isoformat()
        self.connection_registry[connection_id] = {
            "connection_id": connection_id,
            "task_id": task_id,
            "user_id": user_id,
            "connected_at": now,
            "last_seen": now,
        }
        self.websocket_to_connection_id[id(websocket)] = connection_id
        await redis_store.set_ws_connection(connection_id, self.connection_registry[connection_id])

        print(f"WebSocket connected for task: {task_id}")
        print(f"Total connections: {len(self.all_connections)}")

        # Send welcome message
        await self.send_update(
            task_id=task_id,
            message=f"Connected to live forex updates for task: {task_id}",
            update_type="success",
            websocket=websocket
        )
        return connection_id

    def disconnect(
        self,
        websocket: WebSocket,
        task_id: Optional[str] = None,
        reason: Optional[str] = None,
    ):
        """Remove a WebSocket connection"""
        resolved_task = task_id or self._find_task_for_websocket(websocket) or "global"

        # Remove from task-specific connections
        if resolved_task in self.active_connections:
            self.active_connections[resolved_task].discard(websocket)
            if not self.active_connections[resolved_task]:
                del self.active_connections[resolved_task]

        # Remove from all connections
        self.all_connections.discard(websocket)

        connection_id = self.websocket_to_connection_id.pop(id(websocket), None)
        if connection_id and connection_id in self.connection_registry:
            if reason:
                self.connection_registry[connection_id]["disconnect_reason"] = reason
            del self.connection_registry[connection_id]
            self._schedule_background_task(redis_store.remove_ws_connection(connection_id))

        print(f"WebSocket disconnected for task: {resolved_task}")
        print(f"Remaining connections: {len(self.all_connections)}")

    def mark_connection_alive(self, websocket: WebSocket):
        """Update heartbeat timestamp for a connected websocket."""
        connection_id = self.websocket_to_connection_id.get(id(websocket))
        if not connection_id:
            return
        metadata = self.connection_registry.get(connection_id)
        if metadata:
            metadata["last_seen"] = datetime.now().isoformat()
            self._schedule_background_task(
                redis_store.patch_ws_connection(
                    connection_id,
                    {"last_seen": metadata["last_seen"]},
                )
            )

    def _find_task_for_websocket(self, websocket: WebSocket) -> Optional[str]:
        for candidate_task_id, sockets in self.active_connections.items():
            if websocket in sockets:
                return candidate_task_id
        return None

    def get_task_registry_snapshot(self, task_id: Optional[str] = None) -> Dict[str, Dict[str, Any]]:
        """Return filtered connection metadata for diagnostics."""
        if task_id is None:
            return {key: dict(value) for key, value in self.connection_registry.items()}
        return {
            key: dict(value)
            for key, value in self.connection_registry.items()
            if value.get("task_id") == task_id
        }

    async def get_task_registry_snapshot_async(self, task_id: Optional[str] = None) -> Dict[str, Dict[str, Any]]:
        """Return registry snapshot, preferring Redis when available."""
        if await redis_store.ensure_connected():
            return await redis_store.get_ws_registry(task_id=task_id)
        return self.get_task_registry_snapshot(task_id=task_id)

    async def send_update(
        self,
        task_id: str,
        message: str,
        update_type: str = "info",
        progress: Optional[float] = None,
        data: Optional[dict] = None,
        websocket: Optional[WebSocket] = None,
        user_id: Optional[str] = None,
        activity_type: Optional[str] = None,
    ):
        """Send an update to specific task connections or single websocket"""
        update = {
            "id": str(uuid.uuid4()),
            "task_id": task_id,
            "message": message,
            "type": update_type,
            "timestamp": datetime.now().isoformat(),
            "progress": progress,
            "data": data
        }

        await self._maybe_log_activity(
            user_id=user_id,
            update_type=update_type,
            message=message,
            data=data,
            activity_type=activity_type,
        )

        try:
            if websocket:
                await websocket.send_json(update)
                self.mark_connection_alive(websocket)
            elif task_id in self.active_connections:
                # Use a copy to avoid issues if the set is modified during iteration
                connections = list(self.active_connections[task_id])
                for connection in connections:
                    try:
                        await connection.send_json(update)
                        self.mark_connection_alive(connection)
                    except Exception:
                        self.disconnect(connection, task_id=task_id, reason="send_failure")
        except Exception as e:
            if websocket is not None:
                self.disconnect(websocket, task_id=task_id, reason="send_failure")
            print(f"Error in send_update: {e}")

    async def _maybe_log_activity(
        self,
        user_id: Optional[str],
        update_type: str,
        message: str,
        data: Optional[dict] = None,
        activity_type: Optional[str] = None,
    ):
        if not user_id or not self.engagement_logging_enabled:
            return
        if update_type == "progress":
            return
        if not self._has_firebase_config():
            return

        activity = activity_type or self._map_update_type(update_type, data)
        emoji = data.get("emoji") if isinstance(data, dict) else None
        color = data.get("color") if isinstance(data, dict) else None

        try:
            if self._activity_logger is None:
                from .services.engagement_activity_service import EngagementActivityService
                self._activity_logger = EngagementActivityService()

            await asyncio.to_thread(
                self._activity_logger.log_activity,
                user_id,
                activity,
                message,
                emoji,
                color,
            )
        except Exception as e:
            print(f"Activity log failed: {e}")

    def _map_update_type(self, update_type: str, data: Optional[dict]) -> str:
        if isinstance(data, dict):
            explicit = data.get("activity_type")
            if explicit:
                return explicit

        if update_type == "success":
            return "decision"
        if update_type in {"warning", "error"}:
            return "alert"
        return "monitor"

    def _has_firebase_config(self) -> bool:
        return bool(
            os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
            or os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH")
            or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
        )

    async def broadcast(self, message: str, update_type: str = "info", data: Optional[dict] = None):
        """Broadcast a message to all connected clients"""
        update = {
            "id": str(uuid.uuid4()),
            "task_id": "broadcast",
            "message": message,
            "type": update_type,
            "timestamp": datetime.now().isoformat(),
            "data": data
        }

        # Use a copy to avoid issues if the set is modified during iteration
        all_connections_copy = list(self.all_connections)
        for connection in all_connections_copy:
            try:
                await connection.send_json(update)
                self.mark_connection_alive(connection)
            except Exception:
                self.disconnect(connection, reason="broadcast_send_failure")

    async def send_forex_update(self, forex_data: dict):
        """Send forex market data to all connected clients"""
        await self.broadcast(
            message="Live forex market update received",
            update_type="info",
            data=forex_data
        )

    async def send_task_progress(self, task_id: str, step: str, progress: float, message: str):
        """Send task progress update"""
        await self.send_update(
            task_id=task_id,
            message=f"{step}: {message}",
            update_type="progress",
            progress=progress,
            data={"step": step}
        )

    async def send_task_complete(self, task_id: str, result: dict, user_id: Optional[str] = None):
        """Send task completion notification"""
        await self.send_update(
            task_id=task_id,
            message="Task completed successfully!",
            update_type="success",
            progress=1.0,
            data=result,
            user_id=user_id
        )

    async def send_error(self, task_id: str, error_message: str, user_id: Optional[str] = None):
        """Send error notification"""
        await self.send_update(
            task_id=task_id,
            message=f"Error: {error_message}",
            update_type="error",
            user_id=user_id
        )

    def get_connection_count(self, task_id: Optional[str] = None) -> int:
        """Get number of active connections"""
        if task_id:
            return len(self.active_connections.get(task_id, set()))
        return len(self.all_connections)

    def is_forex_stream_running(self) -> bool:
        """Check if the forex stream task is running."""
        task = self.streaming_tasks.get("forex_stream")
        return bool(task and not task.done())

    def get_forex_stream_interval(self) -> int:
        """Get the current forex stream interval."""
        return int(self.forex_stream_interval)

    async def start_forex_stream(self, interval: int = 10):
        """Start streaming live forex data to all clients"""
        from .forex_data_service import forex_service

        interval = int(interval)
        if self.is_forex_stream_running():
            if interval == self.forex_stream_interval:
                print("Forex stream is already running.")
                return
            self.stop_forex_stream()
        self.forex_stream_interval = interval

        async def stream_callback(forex_data):
            await self.send_forex_update(forex_data)

        def should_poll() -> bool:
            return bool(self.all_connections)

        task = asyncio.create_task(
            forex_service.stream_live_data(
                stream_callback,
                interval,
                should_poll=should_poll,
            )
        )
        self.streaming_tasks["forex_stream"] = task
        print(f"Started forex data stream (interval: {interval}s)")

    def stop_forex_stream(self):
        """Stop the forex data stream"""
        if "forex_stream" in self.streaming_tasks:
            self.streaming_tasks["forex_stream"].cancel()
            del self.streaming_tasks["forex_stream"]
            print("Stopped forex data stream")


# Global manager instance
ws_manager = EnhancedWebSocketManager()
