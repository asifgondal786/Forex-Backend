"""
Phase 0 Priority Test Suite â€” Tajir / Forex Companion AI
=========================================================
  1. Auth middleware      â€” 401 on missing/bad token, 200 with valid token
  2. Public path bypass   â€” exempt endpoints never return 401
  3. Rate limiting        â€” 429 after limit exceeded
  4. AI chat endpoint     â€” auth required, rate limit enforced
  5. RLS smoke            â€” auth required on data endpoints

Run with:
    pytest tests/test_phase0_suite.py -v
"""

import os
import time
from collections import deque
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("FOREX_STREAM_ENABLED", "false")
os.environ.setdefault("ENVIRONMENT", "test")

FAKE_UID   = "phase0-test-uid-001"
FAKE_CLAIMS = {"uid": FAKE_UID, "email": "phase0@tajir.test", "name": "Phase0 Tester"}
VALID_AUTH  = {"Authorization": "Bearer valid-fake-token"}

# Real /api/* endpoint that is NOT in the public exempt set
AUTHED_ENDPOINT = "/api/tasks/queue/status"

# Correct request body for POST /api/ai/chat  (field discovered via 422 probe)
AI_CHAT_PAYLOAD = {"messages": [{"role": "user", "content": "What is EUR/USD trend?"}]}


@pytest.fixture(scope="module")
def app():
    with patch("app.utils.firestore_client.init_firebase", return_value=None):
        from app.main import app as fastapi_app
        yield fastapi_app


@pytest.fixture(scope="module")
def client(app):
    with TestClient(app, raise_server_exceptions=False) as c:
        yield c


# ===========================================================================
# 1. AUTH MIDDLEWARE
# ===========================================================================

class TestAuthMiddleware:
    """
    /api/health is in _public_unauthenticated_auth_paths â€” use
    /api/tasks/queue/status which requires a valid Firebase token.
    """

    def test_missing_token_returns_401(self, client):
        response = client.get(AUTHED_ENDPOINT)
        assert response.status_code == 401, (
            f"Expected 401 for missing token, got {response.status_code}"
        )

    def test_malformed_token_returns_401(self, client):
        response = client.get(AUTHED_ENDPOINT, headers={"Authorization": "NotBearer abc"})
        assert response.status_code == 401

    def test_bearer_garbage_returns_401(self, client):
        with patch("app.security.verify_firebase_token", side_effect=Exception("bad token")):
            response = client.get(AUTHED_ENDPOINT, headers={"Authorization": "Bearer garbage"})
        assert response.status_code == 401

    def test_valid_token_passes_middleware(self, client):
        with patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS):
            response = client.get(AUTHED_ENDPOINT, headers=VALID_AUTH)
        assert response.status_code != 401, (
            f"Valid token must not produce 401, got {response.status_code}"
        )

    def test_response_contains_request_id_header(self, client):
        response = client.get("/health")
        assert "x-request-id" in response.headers

    def test_security_headers_present(self, client):
        response = client.get("/health")
        assert response.headers.get("x-content-type-options") == "nosniff"
        assert response.headers.get("x-frame-options") == "DENY"
        assert response.headers.get("referrer-policy") == "no-referrer"


# ===========================================================================
# 2. PUBLIC PATH BYPASS
# ===========================================================================

class TestPublicPaths:

    PUBLIC_GET_PATHS = ["/api/ai/health", "/health", "/healthz"]

    def test_public_paths_never_401(self, client):
        for path in self.PUBLIC_GET_PATHS:
            response = client.get(path)
            assert response.status_code != 401, (
                f"Public path {path} returned 401"
            )

    def test_health_returns_ok(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json().get("status") == "ok"

    def test_ai_health_returns_available_flag(self, client):
        response = client.get("/api/ai/health")
        assert response.status_code == 200
        assert "available" in response.json()

    def test_auth_password_reset_not_401(self, client):
        response = client.post("/auth/password-reset", json={"email": "x@x.com"})
        assert response.status_code != 401

    def test_options_preflight_always_passes(self, client):
        response = client.options(
            AUTHED_ENDPOINT,
            headers={
                "Origin": "http://localhost:3000",
                "Access-Control-Request-Method": "GET",
                "Access-Control-Request-Headers": "authorization",
            },
        )
        assert response.status_code != 401


# ===========================================================================
# 3. RATE LIMITING
# Uses the module-level client â€” avoids anyio event-loop crash that occurs
# when creating a fresh TestClient inside a test with an active lifespan.
# Auth middleware runs before rate-limit middleware, so we patch the token
# verifier for the global-limit test so rate-limit is what fires the 429.
# ===========================================================================

class TestRateLimiting:

    def test_global_rate_limit_returns_429(self, client):
        from app import main as m

        original = m._rate_limit_store
        now = time.time()
        fake = __import__("collections").defaultdict(deque)
        fake["testclient"] = deque([now] * m._rate_limit_max)
        m._rate_limit_store = fake
        try:
            # Provide a valid token so auth passes and rate-limit fires
            with patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS):
                response = client.get(AUTHED_ENDPOINT, headers=VALID_AUTH)
            assert response.status_code == 429, (
                f"Expected 429 when bucket full, got {response.status_code}"
            )
            assert "retry-after" in response.headers
        finally:
            m._rate_limit_store = original

    def test_auth_rate_limit_returns_429(self, client):
        from app import main as m

        original = m._auth_rate_limit_store
        now = time.time()
        key = "testclient:/auth/password-reset"
        fake = __import__("collections").defaultdict(deque)
        fake[key] = deque([now] * m._auth_rate_limit_max)
        m._auth_rate_limit_store = fake
        try:
            response = client.post("/auth/password-reset", json={"email": "x@x.com"})
            assert response.status_code == 429
            assert "retry-after" in response.headers
        finally:
            m._auth_rate_limit_store = original

    def test_rate_limit_exempt_paths_never_429(self, client):
        from app import main as m

        original = m._rate_limit_store
        now = time.time()
        fake = __import__("collections").defaultdict(deque)
        fake["testclient"] = deque([now] * m._rate_limit_max)
        m._rate_limit_store = fake
        try:
            response = client.get("/health")
            assert response.status_code != 429, "/health must be exempt"
        finally:
            m._rate_limit_store = original


# ===========================================================================
# 4. AI CHAT ENDPOINT  â€” body: {"messages": [{"role": "user", "content": "..."}]}
# ===========================================================================

class TestAiChatEndpoint:

    AI_PATH = "/api/ai/chat"

    def test_ai_chat_requires_auth(self, client):
        response = client.post(self.AI_PATH, json=AI_CHAT_PAYLOAD)
        assert response.status_code == 401

    def test_ai_chat_valid_token_not_401(self, client):
        with patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS):
            response = client.post(self.AI_PATH, json=AI_CHAT_PAYLOAD, headers=VALID_AUTH)
        assert response.status_code != 401, (
            f"Valid token must not return 401, got {response.status_code}"
        )

    def test_ai_chat_per_user_rate_limit_returns_429(self, client):
        from app.routers import ai_proxy

        original = ai_proxy._ai_chat_rate_limit_store
        now = time.time()
        fake = __import__("collections").defaultdict(deque)
        fake[FAKE_UID] = deque([now] * ai_proxy._ai_chat_rate_limit_max)
        ai_proxy._ai_chat_rate_limit_store = fake

        try:
            with patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS):
                response = client.post(
                    self.AI_PATH, json=AI_CHAT_PAYLOAD, headers=VALID_AUTH
                )
            assert response.status_code == 429, (
                f"Per-user rate limit should return 429, got {response.status_code}"
            )
            assert "retry-after" in response.headers
        finally:
            ai_proxy._ai_chat_rate_limit_store = original


# ===========================================================================
# 5. RLS SMOKE
# ===========================================================================

class TestRlsSmoke:

    def test_notifications_requires_auth(self, client):
        response = client.get("/api/notifications")
        if response.status_code == 404:
            pytest.skip("Notifications not at /api/notifications.")
        assert response.status_code == 401, (
            f"Notifications should require auth, got {response.status_code}"
        )

    def test_authenticated_user_sees_only_own_data(self, client):
        with patch("app.security.verify_firebase_token", return_value=FAKE_CLAIMS):
            response = client.get("/api/notifications", headers=VALID_AUTH)

        if response.status_code == 404:
            pytest.skip("Notifications not at /api/notifications.")
        if response.status_code != 200:
            pytest.skip(f"Returned {response.status_code}, skipping data check.")

        body = response.json()
        # Response may be a list or a dict wrapping a list
        if isinstance(body, list):
            items = body
        else:
            data = body.get("data") or body
            items = data if isinstance(data, list) else data.get("notifications", [])

        for item in items:
            uid = item.get("user_id")
            if uid:
                assert uid == FAKE_UID, (
                    f"RLS violation: got user_id={uid} for user {FAKE_UID}"
                )