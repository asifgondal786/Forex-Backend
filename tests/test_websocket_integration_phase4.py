import os
import time

from fastapi.testclient import TestClient

os.environ["ALLOW_DEV_USER_ID"] = "true"
os.environ["DEV_USER_LOCALHOST_ONLY"] = "false"
os.environ["FOREX_STREAM_ENABLED"] = "false"

from app.main import app
from app import websocket_routes
from app.enhanced_websocket_manager import ws_manager


def _clear_ws_state():
    ws_manager.active_connections.clear()
    ws_manager.all_connections.clear()
    ws_manager.connection_registry.clear()
    ws_manager.websocket_to_connection_id.clear()


def test_ws_global_ping_pong_and_registry_lifecycle():
    _clear_ws_state()
    client = TestClient(app)
    headers = {"x-user-id": "test_ws_user"}

    with client.websocket_connect("/api/ws?user_id=test_ws_user", headers=headers) as websocket:
        welcome = websocket.receive_json()
        assert welcome["type"] == "success"

        connection_state = client.get("/api/updates/connections", headers=headers)
        assert connection_state.status_code == 200
        payload = connection_state.json()
        assert payload["total_connections"] >= 1
        assert len(payload["registry"]) >= 1

        websocket.send_text("ping")
        assert websocket.receive_text() == "pong"

    time.sleep(0.05)
    after_close = client.get("/api/updates/connections", headers=headers).json()
    assert after_close["total_connections"] == 0
    assert after_close["registry"] == {}


def test_ws_heartbeat_emits_ping_when_idle(monkeypatch):
    _clear_ws_state()
    client = TestClient(app)
    headers = {"x-user-id": "heartbeat_user"}

    monkeypatch.setattr(websocket_routes, "_ws_heartbeat_interval", 1)
    monkeypatch.setattr(websocket_routes, "_ws_heartbeat_timeout", 4)

    with client.websocket_connect("/api/ws?user_id=heartbeat_user", headers=headers) as websocket:
        _ = websocket.receive_json()  # welcome
        heartbeat = websocket.receive_json()
        assert heartbeat["type"] == "ping"
        assert heartbeat["task_id"] == "global"
