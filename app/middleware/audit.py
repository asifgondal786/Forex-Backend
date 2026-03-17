from __future__ import annotations

import hashlib
import json
import logging
import time
from typing import Callable

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

_AUDIT_LOGGER = logging.getLogger("audit")
_SENSITIVE_MARKERS = {
    "password",
    "token",
    "secret",
    "api_key",
    "authorization",
    "bearer",
}


def _client_ip(request: Request) -> str:
    forwarded = (request.headers.get("x-forwarded-for") or "").strip()
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def _is_audit_path(path: str) -> bool:
    if path.startswith("/auth/"):
        return True
    return any(
        path.startswith(prefix)
        for prefix in (
            "/api/users",
            "/api/subscription",
            "/api/credentials",
            "/api/ops",
        )
    )


def _contains_sensitive_marker(payload: bytes) -> bool:
    lowered = payload.lower()
    return any(marker.encode("utf-8") in lowered for marker in _SENSITIVE_MARKERS)


class AuditMiddleware(BaseHTTPMiddleware):
    """Log auth-sensitive requests and error responses without leaking secrets."""

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        path = request.url.path
        if path in {"/health", "/healthz", "/api/health"}:
            return await call_next(request)

        started = time.monotonic()
        request_id = getattr(request.state, "request_id", None)
        audit_path = _is_audit_path(path)

        if audit_path:
            entry: dict[str, object] = {
                "event": "request_audit",
                "method": request.method,
                "path": path,
                "client_ip": _client_ip(request),
                "user_agent": (request.headers.get("user-agent") or "").strip(),
                "request_id": request_id,
            }
            if request.method in {"POST", "PUT", "PATCH"}:
                try:
                    body = await request.body()
                except Exception:
                    body = b""
                if not body:
                    entry["body_state"] = "empty"
                elif _contains_sensitive_marker(body):
                    entry["body_state"] = "redacted_sensitive_payload"
                elif len(body) > 64 * 1024:
                    entry["body_state"] = "redacted_large_payload"
                    entry["body_size_bytes"] = len(body)
                else:
                    entry["body_sha256"] = hashlib.sha256(body).hexdigest()
                    entry["body_size_bytes"] = len(body)
            _AUDIT_LOGGER.info(json.dumps(entry, ensure_ascii=True))

        response = None
        try:
            response = await call_next(request)
        except Exception as exc:
            duration_ms = round((time.monotonic() - started) * 1000.0, 2)
            _AUDIT_LOGGER.error(
                json.dumps(
                    {
                        "event": "request_exception",
                        "path": path,
                        "method": request.method,
                        "client_ip": _client_ip(request),
                        "duration_ms": duration_ms,
                        "error_type": type(exc).__name__,
                        "request_id": request_id,
                    },
                    ensure_ascii=True,
                )
            )
            raise
        status_code = getattr(response, "status_code", 500)
        if status_code >= 400:
            duration_ms = round((time.monotonic() - started) * 1000.0, 2)
            error_entry = {
                "event": "request_error",
                "path": path,
                "method": request.method,
                "status_code": status_code,
                "duration_ms": duration_ms,
                "client_ip": _client_ip(request),
                "request_id": request_id,
            }
            if status_code >= 500:
                _AUDIT_LOGGER.error(json.dumps(error_entry, ensure_ascii=True))
            else:
                _AUDIT_LOGGER.warning(json.dumps(error_entry, ensure_ascii=True))

        return response if response is not None else JSONResponse(status_code=500, content={"status": "error"})


