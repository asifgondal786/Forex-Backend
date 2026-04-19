import os
import time
from unittest.mock import patch

from fastapi.testclient import TestClient

os.environ["FOREX_STREAM_ENABLED"] = "false"

from app.main import app
from app import websocket_routes
from app.enhanced_websocket_manager import ws_manager

FAKE_CLAIMS = {"uid": "test_ws_user", "email": "ws@example.com"}
HEARTBEAT_CLAIMS = {"uid": "heartbeat_user", "email": "heartbeat@example.com"}
AUTH_HEADERS = {"Authorization": "Bearer fake-ws-token"}


def _clear_ws_state():
    ws_manager.active_connections.clear()
    ws_manager.all_connections.clear()
    ws_manager.connection_registry.clear()
    ws_manager.websocket_to_connection_id.clear()
    websocket_routes._ws_rate_limit_store.clear()


def test_ws_global_ping_pong_and_registry_lifecycle():
    _clear_ws_state()
    p1 = patch("app.websocket_routes.verify_firebase_token", return_value=FAKE_CLAIMS)
    p2 = patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS)
    with p1, p2:
        client = TestClient(app, raise_server_exceptions=False)
        with client.websocket_connect("/api/ws?user_id=test_ws_user", headers=AUTH_HEADERS) as websocket:
            welcome = websocket.receive_json()
            assert welcome["type"] == "success"
            connection_state = client.get("/api/updates/connections", headers=AUTH_HEADERS)
            assert connection_state.status_code == 200
            payload = connection_state.json()
            assert payload["total_connections"] >= 1
            assert len(payload["registry"]) >= 1
            websocket.send_text("ping")
            assert websocket.receive_text() == "pong"
    time.sleep(0.05)
    with patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS):
        with TestClient(app, raise_server_exceptions=False) as c:
            after_close = c.get("/api/updates/connections", headers=AUTH_HEADERS).json()
    assert after_close["total_connections"] == 0
    assert after_close["registry"] == {}


def test_ws_heartbeat_emits_ping_when_idle(monkeypatch):
    heartbeat_claims = {"uid": "heartbeat_user", "email": "heartbeat@example.com"}
    _clear_ws_state()
    monkeypatch.setattr(websocket_routes, "_ws_heartbeat_interval", 1)
    monkeypatch.setattr(websocket_routes, "_ws_heartbeat_timeout", 4)
    p1 = patch("app.websocket_routes.verify_firebase_token", return_value=FAKE_CLAIMS)
    p2 = patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS)
    with p1, p2:
        client = TestClient(app, raise_server_exceptions=False)
        with client.websocket_connect("/api/ws?user_id=test_ws_user", headers=AUTH_HEADERS) as websocket:
            _ = websocket.receive_json()
            heartbeat = websocket.receive_json()
            assert heartbeat["type"] == "ping"
            assert heartbeat["task_id"] == "global"
