import os
import pytest
from fastapi.testclient import TestClient

os.environ["ALLOW_DEV_USER_ID"] = "true"
os.environ["DEV_USER_LOCALHOST_ONLY"] = "false"

from app.main import app

client = TestClient(app)

def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()

def test_health():
    response = client.get("/api/health", headers={"x-user-id": "test_user"})
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
