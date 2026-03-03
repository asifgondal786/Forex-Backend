from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.middleware.audit import AuditMiddleware


def _app() -> FastAPI:
    app = FastAPI()
    app.add_middleware(AuditMiddleware)

    @app.post("/auth/login")
    async def login(payload: dict):
        return {"ok": True, "echo": bool(payload)}

    @app.get("/boom")
    async def boom():
        return {"ok": True}

    return app


def test_audit_middleware_does_not_break_auth_post_payload():
    client = TestClient(_app())
    response = client.post("/auth/login", json={"email": "a@b.com", "password": "redacted"})
    assert response.status_code == 200
    assert response.json()["ok"] is True


def test_audit_middleware_skips_health_paths():
    app = _app()

    @app.get("/health")
    async def health():
        return {"status": "ok"}

    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"
