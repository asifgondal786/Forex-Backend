import os
import pytest

from fastapi.testclient import TestClient

os.environ["ALLOW_DEV_USER_ID"] = "true"
os.environ["DEV_USER_LOCALHOST_ONLY"] = "false"
os.environ["FOREX_STREAM_ENABLED"] = "false"

from app.main import app
from app import ops_routes

client = TestClient(app)


def _payload_or_data(response_json: dict) -> dict:
    if isinstance(response_json, dict) and isinstance(response_json.get("data"), dict):
        return response_json["data"]
    return response_json


def test_ops_status_endpoint():
    response = client.get("/api/ops/status", headers={"x-user-id": "ops_user"})
    assert response.status_code == 200
    payload = _payload_or_data(response.json())

    assert "timestamp" in payload
    assert "queue" in payload
    assert "websocket" in payload
    assert "forex" in payload
    assert "alerts" in payload
    assert "alert_summary" in payload
    assert "total_connections" in payload["websocket"]
    assert "started" in payload["queue"]


def test_ops_alerts_endpoint():
    response = client.get("/api/ops/alerts", headers={"x-user-id": "ops_user"})
    assert response.status_code == 200
    payload = _payload_or_data(response.json())

    assert "timestamp" in payload
    assert "alerts" in payload
    assert "total" in payload
    assert isinstance(payload["alerts"], list)
    assert payload["total"] == len(payload["alerts"])


def test_ops_metrics_endpoint():
    response = client.get("/api/ops/metrics", headers={"x-user-id": "ops_user"})
    assert response.status_code == 200
    content_type = response.headers.get("content-type", "")
    assert "text/plain" in content_type

    body = response.text
    assert "forex_backend_queue_started" in body
    assert "forex_backend_queue_size" in body
    assert "forex_backend_websocket_connections_total" in body
    assert "forex_backend_alerts_total" in body


@pytest.mark.asyncio
async def test_emit_alert_hooks_sends_webhook_on_trigger_and_resolve(monkeypatch):
    events = []
    ops_routes._alert_latch.clear()

    async def _capture(event_type, alert):
        events.append((event_type, alert["id"]))

    monkeypatch.setenv("OPS_ALERT_HOOKS_ENABLED", "true")
    monkeypatch.setenv("OPS_ALERT_WEBHOOK_URL", "https://hooks.slack.test/services/demo")
    monkeypatch.setattr(ops_routes, "_send_alert_webhook", _capture)

    sample_alert = {
        "id": "queue_depth_warning",
        "severity": "warning",
        "message": "Task queue depth is high",
        "value": 10,
        "threshold": 5,
    }

    await ops_routes._emit_alert_hooks([sample_alert])
    await ops_routes._emit_alert_hooks([])

    assert ("triggered", "queue_depth_warning") in events
    assert ("resolved", "queue_depth_warning") in events


def test_ops_readiness_endpoint():
    response = client.get("/api/ops/readiness", headers={"x-user-id": "ops_user"})
    assert response.status_code == 200
    payload = _payload_or_data(response.json())

    assert "ready" in payload
    assert "checks" in payload
    assert "queue" in payload["checks"]
    assert "firebase" in payload["checks"]
    assert "websocket_manager" in payload["checks"]
