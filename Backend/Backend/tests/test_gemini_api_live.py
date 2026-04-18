import os
import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient

os.environ["FOREX_STREAM_ENABLED"] = "false"

from app.main import app

FAKE_CLAIMS = {"uid": "test_user", "email": "test@example.com"}
AUTH_HEADERS = {"Authorization": "Bearer fake-test-token"}


def _authed_client():
    return TestClient(app, raise_server_exceptions=False)


def _payload_or_data(response_json: dict) -> dict:
    if isinstance(response_json, dict) and isinstance(response_json.get("data"), dict):
        return response_json["data"]
    return response_json


def test_root():
    with _authed_client() as client:
        response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()


def test_health():
    # /api/health is exempt â€” no token required once main.py one-liner is applied.
    # Until then, we mock to confirm the endpoint itself works correctly.
    with patch("app.utils.firestore_client.verify_firebase_token", return_value=FAKE_CLAIMS):
        with _authed_client() as client:
            response = client.get("/api/health", headers=AUTH_HEADERS)
    assert response.status_code == 200
    payload = _payload_or_data(response.json())
    assert payload["status"] == "healthy"


def test_task_queue_status():
    with patch("app.utils.firestore_client.verify_firebase_token", return_value=FAKE_CLAIMS):
        with _authed_client() as client:
            response = client.get("/api/tasks/queue/status", headers=AUTH_HEADERS)
    assert response.status_code == 200
    payload = _payload_or_data(response.json())
    assert "started" in payload
    assert "workers" in payload
    assert "max_size" in payload
    assert "queue_size" in payload
    assert "enqueued" in payload
    assert "completed" in payload
    assert "failed" in payload