import pytest

from app.enhanced_websocket_manager import EnhancedWebSocketManager


class FakeWebSocket:
    def __init__(self):
        self.accepted = False
        self.sent_messages = []

    async def accept(self):
        self.accepted = True

    async def send_json(self, payload):
        self.sent_messages.append(payload)


@pytest.mark.asyncio
async def test_connection_registry_tracks_connect_and_disconnect():
    manager = EnhancedWebSocketManager()
    ws = FakeWebSocket()

    connection_id = await manager.connect(ws, task_id="task-1", user_id="user-1")
    snapshot = manager.get_task_registry_snapshot(task_id="task-1")

    assert ws.accepted is True
    assert manager.get_connection_count("task-1") == 1
    assert connection_id in snapshot
    assert snapshot[connection_id]["user_id"] == "user-1"
    assert snapshot[connection_id]["task_id"] == "task-1"

    manager.mark_connection_alive(ws)
    refreshed = manager.get_task_registry_snapshot(task_id="task-1")[connection_id]
    assert refreshed["last_seen"]

    manager.disconnect(ws, task_id="task-1", reason="test_complete")
    assert manager.get_connection_count("task-1") == 0
    assert connection_id not in manager.get_task_registry_snapshot()


@pytest.mark.asyncio
async def test_send_update_disconnects_broken_connection():
    manager = EnhancedWebSocketManager()
    ws = FakeWebSocket()

    await manager.connect(ws, task_id="task-err", user_id="user-2")

    async def _boom(_payload):
        raise RuntimeError("socket write failed")

    ws.send_json = _boom
    await manager.send_update(task_id="task-err", message="hello")

    assert manager.get_connection_count("task-err") == 0
    assert manager.get_task_registry_snapshot(task_id="task-err") == {}
