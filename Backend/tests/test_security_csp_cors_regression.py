import pytest
from fastapi.testclient import TestClient

from app import main as app_main
from app.main import app


client = TestClient(app)


def _cors_kwargs() -> dict:
    for middleware in app.user_middleware:
        if middleware.cls.__name__ == "CORSMiddleware":
            return middleware.kwargs
    raise AssertionError("CORSMiddleware is not registered")


def _pick_allowed_origin() -> str:
    kwargs = _cors_kwargs()
    allow_origins = kwargs.get("allow_origins") or []

    if "*" in allow_origins:
        return "https://forexcompanion-e5a28.web.app"

    preferred = [
        "https://forexcompanion-e5a28.web.app",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8080",
    ]
    for origin in preferred:
        if origin in allow_origins:
            return origin

    if allow_origins:
        return allow_origins[0]
    raise AssertionError("No allow_origins configured")


def _response_csp_header(response) -> str:
    return (
        response.headers.get("content-security-policy")
        or response.headers.get("content-security-policy-report-only")
        or ""
    )


def test_csp_header_not_default_none():
    response = client.get("/health")
    csp = _response_csp_header(response)

    assert csp
    assert "default-src 'none'" not in csp
    assert "default-src 'self'" in csp
    assert "object-src 'none'" in csp


def test_docs_csp_allows_swagger_assets():
    response = client.get("/docs")
    assert response.status_code in {200, 404}
    if response.status_code == 404:
        pytest.skip("Docs endpoint disabled in this environment.")

    csp = _response_csp_header(response)
    assert "script-src" in csp
    assert "style-src" in csp
    assert "https://cdn.jsdelivr.net" in csp


def test_build_csp_supports_explicit_override(monkeypatch):
    monkeypatch.setenv("CSP_HEADER_OVERRIDE", "default-src 'self'; object-src 'none';")
    csp = app_main._build_csp_header(docs_mode=False)
    assert csp == "default-src 'self'; object-src 'none';"


def test_build_csp_docs_mode_includes_docs_requirements():
    csp = app_main._build_csp_header(docs_mode=True)
    assert "script-src" in csp
    assert "style-src" in csp
    assert "https://cdn.jsdelivr.net" in csp
    assert "'unsafe-inline'" in csp


def test_cors_middleware_configuration_is_strict():
    kwargs = _cors_kwargs()

    assert "OPTIONS" in kwargs.get("allow_methods", [])
    assert "Authorization" in kwargs.get("allow_headers", [])
    assert "Content-Type" in kwargs.get("allow_headers", [])
    assert kwargs.get("allow_credentials") in {True, False}

    if kwargs.get("allow_origins") == ["*"]:
        # Wildcard mode is acceptable only when credentials are disabled.
        assert kwargs.get("allow_credentials") is False


def test_preflight_options_returns_cors_headers_for_allowed_origin():
    origin = _pick_allowed_origin()
    response = client.options(
        "/auth/password-reset",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "authorization,content-type",
        },
    )

    assert response.status_code == 200
    allow_origin = response.headers.get("access-control-allow-origin")
    assert allow_origin in {origin, "*"}

    allow_headers = (response.headers.get("access-control-allow-headers") or "").lower()
    assert "authorization" in allow_headers
    assert "content-type" in allow_headers


def test_public_auth_endpoint_is_not_jwt_gated():
    origin = _pick_allowed_origin()
    response = client.post(
        "/auth/password-reset",
        headers={"Origin": origin, "Content-Type": "application/json"},
        json={"email": "test@example.com"},
    )

    # Public endpoint should never fail specifically due to missing Authorization.
    assert response.status_code != 401
    allow_origin = response.headers.get("access-control-allow-origin")
    assert allow_origin in {origin, "*"}
