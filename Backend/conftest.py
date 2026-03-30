import pytest
from unittest.mock import patch
from fastapi.testclient import TestClient

FAKE_UID = "test-user-uid-001"
FAKE_CLAIMS = {"uid": FAKE_UID, "email": "testuser@example.com", "name": "Test User"}


@pytest.fixture(scope="session")
def app():
    with patch("app.utils.firestore_client.init_firebase", return_value=None):
        from app.main import app as fastapi_app
        yield fastapi_app


@pytest.fixture(scope="session")
def client(app):
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


@pytest.fixture(scope="session")
def auth_client(app):
    with patch("app.utils.firestore_client.verify_firebase_token", return_value=FAKE_CLAIMS):
        with TestClient(app, raise_server_exceptions=False) as c:
            c.headers.update({"Authorization": "Bearer fake-test-token"})
            yield c
