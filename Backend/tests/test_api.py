import os
import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_DEV_USER_ID"] = "true"
os.environ["DEV_USER_LOCALHOST_ONLY"] = "false"

from app.main import app

client = TestClient(app)


def _payload_or_data(response_json: dict) -> dict:
    if isinstance(response_json, dict) and isinstance(response_json.get("data"), dict):
        return response_json["data"]
    return response_json


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()

def test_health():
    response = client.get("/api/health", headers={"x-user-id": "test_user"})
    assert response.status_code == 200
    payload = _payload_or_data(response.json())
    assert payload["status"] == "healthy"


def test_task_queue_status():
    response = client.get("/api/tasks/queue/status", headers={"x-user-id": "test_user"})
    assert response.status_code == 200

    payload = _payload_or_data(response.json())
    assert "started" in payload
    assert "workers" in payload
    assert "max_size" in payload
    assert "queue_size" in payload
    assert "enqueued" in payload
    assert "completed" in payload
    assert "failed" in payload
