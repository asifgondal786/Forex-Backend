"""
Forex Companion - Complete FastAPI Application
"""
from pathlib import Path
from typing import Any
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import os
import time
import json
import uuid
import asyncio
from collections import defaultdict, deque
from urllib.parse import urlparse
from dotenv import load_dotenv

# Load environment variables from Backend/.env if present.
# override=True ensures local .env values win over accidental shell-level vars.
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env", override=True)


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        parsed = int(value.strip())
    except Exception:
        return default
    return parsed if parsed > 0 else default


def _normalize_url(value: str) -> str:
    candidate = (value or "").strip()
    if not candidate:
        return ""
    if not candidate.startswith("http://") and not candidate.startswith("https://"):
        candidate = f"https://{candidate}"
    return candidate.rstrip("/")


def _parse_host(value: str) -> str:
    parsed = urlparse(_normalize_url(value))
    return (parsed.hostname or "").lower()


def _is_local_host(host: str) -> bool:
    return host in {"localhost", "127.0.0.1"}


def _is_local_origin(origin: str) -> bool:
    return _is_local_host(_parse_host(origin))


def _is_https_url(value: str) -> bool:
    parsed = urlparse(_normalize_url(value))
    return (parsed.scheme or "").lower() == "https"


def _public_api_base_url() -> str:
    explicit = _normalize_url(os.getenv("PUBLIC_API_BASE_URL") or "")
    if explicit:
        return explicit

    api_base = _normalize_url(os.getenv("API_BASE_URL") or "")
    if api_base:
        return api_base

    return "http://localhost:8080" if _env_bool("DEBUG", False) else ""


def _public_ws_base_url() -> str:
    explicit = _normalize_url(os.getenv("PUBLIC_WS_BASE_URL") or "")
    if explicit:
        parsed = urlparse(explicit)
        scheme = parsed.scheme.lower()
        if scheme == "https":
            scheme = "wss"
        elif scheme == "http":
            scheme = "ws"
        return f"{scheme}://{parsed.netloc}"

    api_base = _public_api_base_url()
    if not api_base:
        return ""

    parsed = urlparse(api_base)
    scheme = "wss" if (parsed.scheme or "").lower() == "https" else "ws"
    return f"{scheme}://{parsed.netloc}"


def _public_ws_endpoint() -> str:
    ws_base = _public_ws_base_url()
    if not ws_base:
        return "/api/ws/{task_id}"
    return f"{ws_base}/api/ws/{{task_id}}"


def _redact(value: str, *, keep: int = 4) -> str:
    raw = (value or "").strip()
    if not raw:
        return ""
    if len(raw) <= keep:
        return "*" * len(raw)
    return f"{raw[:keep]}***"


def _startup_snapshot() -> dict:
    return {
        "debug": _env_bool("DEBUG", False),
        "email_provider": (os.getenv("EMAIL_PROVIDER") or "auto").strip().lower(),
        "frontend_app_url": _normalize_url(os.getenv("FRONTEND_APP_URL") or ""),
        "password_reset_continue_url": _normalize_url(
            os.getenv("PASSWORD_RESET_CONTINUE_URL") or ""
        ),
        "email_verification_continue_url": _normalize_url(
            os.getenv("EMAIL_VERIFICATION_CONTINUE_URL") or ""
        ),
        "cors_origins": _get_cors_origins(),
        "has_brevo_api_key": bool((os.getenv("BREVO_API_KEY") or "").strip()),
        "has_mailjet_api_key": bool((os.getenv("MAILJET_API_KEY") or "").strip()),
        "has_firebase_api_key": bool((os.getenv("FIREBASE_API_KEY") or "").strip()),
        "firebase_project_id": (os.getenv("FIREBASE_PROJECT_ID") or "").strip(),
        "api_base_url_hint": _normalize_url(os.getenv("API_BASE_URL") or ""),
        "firebase_auth_domain_check_enabled": _env_bool(
            "FIREBASE_AUTH_DOMAIN_CHECK_ENABLED",
            True,
        ),
        "firebase_auth_domain_check_fail_fast": _env_bool(
            "FIREBASE_AUTH_DOMAIN_CHECK_FAIL_FAST",
            not _env_bool("DEBUG", False),
        ),
        "redacted_service_account_path": _redact(
            os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH") or "",
            keep=8,
        ),
    }


def _validate_env_urls() -> None:
    if _env_bool("DEBUG", False):
        return

    for key in [
        "FRONTEND_APP_URL",
        "PASSWORD_RESET_CONTINUE_URL",
        "EMAIL_VERIFICATION_CONTINUE_URL",
    ]:
        value = (os.getenv(key) or "").strip()
        if not value:
            raise RuntimeError(f"{key} must be configured in production.")
        if not _is_https_url(value):
            raise RuntimeError(f"{key} must use HTTPS in production.")

    for origin in _get_cors_origins():
        if _is_local_origin(origin):
            raise RuntimeError("CORS_ORIGINS must not include localhost in production.")
        if not _is_https_url(origin):
            raise RuntimeError(f"CORS origin must use HTTPS in production: {origin}")

# Import routers
from .users import router as users_router
from .websocket_routes import router as websocket_router
from .engagement_routes import router as engagement_router
from .auth_status_routes import router as auth_status_router
from .header_routes import router as header_router
from .notifications_routes import router as notifications_router
from .settings_routes import router as settings_router

try:
    from .ai_task_routes import router as ai_task_router
    AI_ROUTES_AVAILABLE = True
except ImportError:
    AI_ROUTES_AVAILABLE = False
    print("[WARN] AI task routes not available")

try:
    from .advanced_features_routes import router as advanced_router
    ADVANCED_FEATURES_AVAILABLE = True
except ImportError:
    ADVANCED_FEATURES_AVAILABLE = False
    print("[WARN] Advanced features routes not available")

try:
    from .accounts_routes import router as accounts_router
    ACCOUNTS_ROUTES_AVAILABLE = True
except ImportError:
    ACCOUNTS_ROUTES_AVAILABLE = False
    print("[WARN] Accounts routes not available")

try:
    from .subscription_routes import router as subscription_router
    SUBSCRIPTION_ROUTES_AVAILABLE = True
except ImportError:
    SUBSCRIPTION_ROUTES_AVAILABLE = False
    print("[WARN] Subscription routes not available")

try:
    from .credential_vault_routes import router as credential_vault_router
    CREDENTIAL_VAULT_ROUTES_AVAILABLE = True
except ImportError:
    CREDENTIAL_VAULT_ROUTES_AVAILABLE = False
    print("[WARN] Credential vault routes not available")

try:
    from .public_auth_routes import router as public_auth_router
    PUBLIC_AUTH_ROUTES_AVAILABLE = True
except ImportError:
    PUBLIC_AUTH_ROUTES_AVAILABLE = False
    print("[WARN] Public auth routes not available")

try:
    from .ops_routes import router as ops_router
    OPS_ROUTES_AVAILABLE = True
except ImportError:
    OPS_ROUTES_AVAILABLE = False
    print("[WARN] Ops routes not available")

try:
    from .monitoring_routes import router as monitoring_router
    MONITORING_ROUTES_AVAILABLE = True
except ImportError:
    MONITORING_ROUTES_AVAILABLE = False
    print("[WARN] Monitoring routes not available")

from .enhanced_websocket_manager import ws_manager
from .forex_data_service import forex_service
from .services.task_queue_service import task_queue_service
from .services.redis_store import redis_store
from .services.observability import health_checker
from .utils.firestore_client import (
    check_firebase_authorized_domain,
    get_firebase_config_status,
    init_firebase,
)
from .schemas.api_response import (
    error_payload,
    is_api_response_payload,
    success_payload,
)
from .security import verify_http_request


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan events"""
    print("=" * 60)
    print("[Startup] Forex Companion AI Backend Starting...")
    print("=" * 60)
    
    try:
        public_api_base = _public_api_base_url()
        print(f"[Startup] WebSocket: {_public_ws_endpoint()}")
        print(f"[Startup] API Docs: {f'{public_api_base}/docs' if public_api_base else '/docs'}")
        print(f"[Startup] AI Engine: {'ACTIVE' if AI_ROUTES_AVAILABLE else 'DISABLED'}")
        print(f"[Startup] Advanced Features: {'ACTIVE' if ADVANCED_FEATURES_AVAILABLE else 'DISABLED'}")
    except Exception as e:
        print(f"[Startup] Warning: Could not print startup info: {e}")
    
    print("=" * 60)

    # Fail fast on invalid production URL configuration (graceful).
    try:
        _validate_env_urls()
    except Exception as e:
        print(f"[Startup] Warning: URL validation failed (non-blocking): {e}")

    # Startup checklist (no secrets / redacted).
    try:
        print(
            json.dumps(
                {
                    "event": "startup_checklist",
                    **_startup_snapshot(),
                }
            )
        )
    except Exception as e:
        print(f"[Startup] Warning: Could not generate startup snapshot: {e}")

    # Firebase Admin SDK startup health check
    firebase_initialized = False
    try:
        status = get_firebase_config_status()
        if status["credential_source"] != "none":
            init_firebase()
            status = get_firebase_config_status()
            firebase_initialized = True
            print(
                f"[Firebase] Initialized via {status['credential_source']} "
                f"(project_id={status['project_id']})"
            )
        else:
            print("[Firebase] Not configured (no credentials found).")
            if os.getenv("REQUIRE_FIREBASE", "").lower() == "true":
                raise RuntimeError("Firebase configuration required but not found.")
    except Exception as exc:
        print(f"[Firebase] Startup check failed: {exc}")
        if os.getenv("REQUIRE_FIREBASE", "").lower() == "true":
            raise
    
    # Register health checks (Phase 6: Observability)
    try:
        async def check_firebase() -> bool:
            return firebase_initialized
        
        async def check_redis() -> bool:
            return redis_store.is_connected() or not redis_store.is_enabled()
        
        async def check_firestore() -> bool:
            # Firestore health check would go here
            return True
        
        health_checker.register_check("firebase", check_firebase)
        health_checker.register_check("redis", check_redis)
        health_checker.register_check("firestore", check_firestore)
    except Exception as e:
        print(f"[Startup] Warning: Could not register health checks: {e}")

    # Optional startup guard for Firebase Auth Authorized Domains.
    if firebase_initialized and _env_bool("FIREBASE_AUTH_DOMAIN_CHECK_ENABLED", True):
        frontend_host = _parse_host(os.getenv("FRONTEND_APP_URL") or "")
        if frontend_host:
            check_fail_fast = _env_bool(
                "FIREBASE_AUTH_DOMAIN_CHECK_FAIL_FAST",
                not _env_bool("DEBUG", False),
            )
            check_timeout = _env_int("FIREBASE_AUTH_DOMAIN_CHECK_TIMEOUT_SECONDS", 10)
            try:
                domain_check = check_firebase_authorized_domain(
                    frontend_host,
                    timeout_seconds=check_timeout,
                )
                log_payload = {
                    "event": "firebase_authorized_domain_check",
                    "project_id": domain_check.get("project_id"),
                    "domain": domain_check.get("domain"),
                    "authorized": bool(domain_check.get("authorized")),
                    "authorized_domain_count": len(
                        domain_check.get("authorized_domains") or []
                    ),
                    "fail_fast": check_fail_fast,
                }
                if _env_bool("DEBUG", False):
                    log_payload["authorized_domains"] = (
                        domain_check.get("authorized_domains") or []
                    )
                print(json.dumps(log_payload))

                if not domain_check.get("authorized"):
                    message = (
                        f"Firebase Auth domain '{frontend_host}' is not allowlisted. "
                        "Add it in Firebase Console -> Authentication -> Settings -> "
                        "Authorized domains."
                    )
                    if check_fail_fast:
                        raise RuntimeError(message)
                    print(f"[Firebase] WARNING: {message}")
            except Exception as exc:
                if check_fail_fast:
                    raise
                print(f"[Firebase] WARNING: Authorized-domain check skipped: {exc}")
    
    forex_stream_enabled = os.getenv("FOREX_STREAM_ENABLED", "false").lower() == "true"
    forex_stream_interval = _env_int("FOREX_STREAM_INTERVAL", 10)
    task_queue_enabled = _env_bool("TASK_QUEUE_ENABLED", False)
    task_queue_workers = _env_int("TASK_QUEUE_WORKERS", 2)
    task_queue_max_size = _env_int("TASK_QUEUE_MAX_SIZE", 200)

    if task_queue_enabled:
        try:
            await asyncio.wait_for(
                task_queue_service.start(
                    workers=task_queue_workers,
                    max_size=task_queue_max_size,
                ),
                timeout=10.0  # 10 second timeout
            )
        except asyncio.TimeoutError:
            print("[Startup] WARNING: Task queue startup timed out (non-blocking)")
        except Exception as e:
            print(f"[Startup] WARNING: Task queue startup failed: {e}")

    if forex_stream_enabled:
        try:
            await asyncio.wait_for(
                ws_manager.start_forex_stream(interval=forex_stream_interval),
                timeout=10.0  # 10 second timeout
            )
        except asyncio.TimeoutError:
            print("[Startup] WARNING: Forex stream startup timed out (non-blocking)")
        except Exception as e:
            print(f"[Startup] WARNING: Forex stream startup failed: {e}")

    yield

    if forex_stream_enabled:
        ws_manager.stop_forex_stream()
    try:
        await forex_service.close()
    except Exception:
        pass
    if task_queue_enabled:
        await task_queue_service.stop()
    await redis_store.close()
    print("[Shutdown] complete")


app = FastAPI(
    title="Forex Companion AI API",
    description="AI-Powered Autonomous Forex Trading System",
    version="2.0.0",
    lifespan=lifespan
)


def _request_id_from_request(request: Request) -> str | None:
    from_state = getattr(request.state, "request_id", None)
    if isinstance(from_state, str) and from_state.strip():
        return from_state.strip()
    from_header = (request.headers.get("x-request-id") or "").strip()
    return from_header or None


def _derive_success_message(payload: Any) -> str:
    if isinstance(payload, dict):
        candidate = payload.get("message")
        if isinstance(candidate, str) and candidate.strip():
            return candidate.strip()
    return "OK"


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    detail = exc.detail
    message = detail if isinstance(detail, str) and detail.strip() else "Request failed"
    data = None if isinstance(detail, str) else {"detail": detail}
    return JSONResponse(
        status_code=exc.status_code,
        content=error_payload(
            message=message,
            data=data,
            request_id=_request_id_from_request(request),
        ),
        headers=exc.headers,
    )


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content=error_payload(
            message="Validation error",
            data={"errors": exc.errors()},
            request_id=_request_id_from_request(request),
        ),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    request_id = _request_id_from_request(request)
    print(
        f"[UnhandledError] request_id={request_id} path={request.url.path} error={type(exc).__name__}: {exc}"
    )
    return JSONResponse(
        status_code=500,
        content=error_payload(
            message="Internal server error",
            data={"error": "internal_server_error"},
            request_id=request_id,
        ),
    )


@app.middleware("http")
async def request_id_middleware(request: Request, call_next):
    request_id = (request.headers.get("x-request-id") or "").strip() or str(uuid.uuid4())
    request.state.request_id = request_id
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response


@app.middleware("http")
async def api_response_envelope_middleware(request: Request, call_next):
    response = await call_next(request)

    path = request.url.path
    if (
        not path.startswith("/api")
        or path.startswith("/api/ws")
        or request.method == "OPTIONS"
        or response.status_code >= 400
    ):
        return response

    content_type = (response.headers.get("content-type") or "").lower()
    if "application/json" not in content_type:
        return response

    raw_body = getattr(response, "body", None)
    if raw_body is None:
        return response

    try:
        decoded = json.loads(raw_body) if raw_body else None
    except Exception:
        return response

    if is_api_response_payload(decoded):
        payload = decoded
        request_id = _request_id_from_request(request)
        if request_id:
            payload.setdefault("requestId", request_id)
    else:
        payload = success_payload(
            data=decoded,
            message=_derive_success_message(decoded),
            request_id=_request_id_from_request(request),
        )

    wrapped = JSONResponse(status_code=response.status_code, content=payload)
    for header, value in response.headers.items():
        header_name = header.lower()
        if header_name in {"content-length", "content-type", "x-request-id"}:
            continue
        wrapped.headers[header] = value
    return wrapped


# Security headers middleware
@app.middleware("http")
async def security_headers_middleware(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Permissions-Policy"] = "geolocation=(), microphone=(), camera=()"
    response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
    response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    if _env_bool("ENABLE_CSP", True):
        response.headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none';"
    if _env_bool("ENABLE_HSTS", not _env_bool("DEBUG", False)):
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    if request.url.path.startswith("/api"):
        response.headers["Cache-Control"] = "no-store"
    if request.method == "OPTIONS":
        response.headers["Access-Control-Max-Age"] = str(
            _env_int("CORS_MAX_AGE_SECONDS", 86400)
        )
    return response

# Rate limiting middleware (simple in-memory)
_rate_limit_enabled = os.getenv("RATE_LIMIT_ENABLED", "true").lower() == "true"
_rate_limit_max = int(os.getenv("RATE_LIMIT_MAX", "120"))
_rate_limit_window = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
_rate_limit_store = defaultdict(deque)
_rate_limit_exempt = {"/", "/health", "/healthz", "/api/health", "/docs", "/openapi.json", "/redoc"}
_max_request_body_bytes = _env_int("MAX_REQUEST_BODY_BYTES", 1_048_576)

_auth_rate_limit_enabled = _env_bool("AUTH_RATE_LIMIT_ENABLED", True)
_auth_rate_limit_max = _env_int("AUTH_RATE_LIMIT_MAX", 10)
_auth_rate_limit_window = _env_int("AUTH_RATE_LIMIT_WINDOW_SECONDS", 300)
_auth_rate_limit_store = defaultdict(deque)
_auth_rate_limited_paths = {
    "/auth/password-reset",
    "/auth/email-verification",
    "/auth/login",
    "/auth/signup",
}


@app.middleware("http")
async def request_size_limit_middleware(request: Request, call_next):
    if request.method in {"POST", "PUT", "PATCH"} and request.url.path.startswith("/api"):
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > _max_request_body_bytes:
                    return JSONResponse(
                        status_code=413,
                        content=error_payload(
                            message="Request payload too large",
                            request_id=_request_id_from_request(request),
                        ),
                    )
            except ValueError:
                return JSONResponse(
                    status_code=400,
                    content=error_payload(
                        message="Invalid Content-Length header",
                        request_id=_request_id_from_request(request),
                    ),
                )
    return await call_next(request)


@app.middleware("http")
async def auth_rate_limit_middleware(request: Request, call_next):
    if not _auth_rate_limit_enabled:
        return await call_next(request)

    if request.method == "OPTIONS":
        return await call_next(request)

    path = request.url.path
    if path not in _auth_rate_limited_paths:
        return await call_next(request)

    client_host = request.client.host if request.client else "unknown"
    key = f"{client_host}:{path}"
    now = time.time()
    window_start = now - _auth_rate_limit_window
    bucket = _auth_rate_limit_store[key]
    while bucket and bucket[0] <= window_start:
        bucket.popleft()
    if len(bucket) >= _auth_rate_limit_max:
        return JSONResponse(
            status_code=429,
            content=error_payload(
                message="Too many auth requests. Please wait and retry.",
                request_id=_request_id_from_request(request),
            ),
            headers={"Retry-After": str(_auth_rate_limit_window)},
        )
    bucket.append(now)
    return await call_next(request)


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    if not _rate_limit_enabled:
        return await call_next(request)

    path = request.url.path
    if path in _rate_limit_exempt or path.startswith("/docs"):
        return await call_next(request)

    client_host = request.client.host if request.client else "unknown"
    now = time.time()
    window_start = now - _rate_limit_window
    bucket = _rate_limit_store[client_host]
    while bucket and bucket[0] <= window_start:
        bucket.popleft()
    if len(bucket) >= _rate_limit_max:
        return JSONResponse(
            status_code=429,
            content=error_payload(
                message="Rate limit exceeded",
                request_id=_request_id_from_request(request),
            ),
        )
    bucket.append(now)
    return await call_next(request)

@app.middleware("http")
async def strict_auth_middleware(request: Request, call_next):
    if request.method == "OPTIONS":
        return await call_next(request)

    path = request.url.path
    if path.startswith("/api"):
        try:
            await verify_http_request(request)
        except Exception as exc:
            status_code = getattr(exc, "status_code", 401)
            detail = getattr(exc, "detail", "Unauthorized")
            message = detail if isinstance(detail, str) else "Unauthorized"
            data = None if isinstance(detail, str) else {"detail": detail}
            return JSONResponse(
                status_code=status_code,
                content=error_payload(
                    message=message,
                    data=data,
                    request_id=_request_id_from_request(request),
                ),
            )

    return await call_next(request)

# CORS
def _get_cors_origins():
    if _env_bool("CORS_ALLOW_ALL"):
        return ["*"]
    raw = os.getenv("CORS_ORIGINS", "")
    debug_mode = _env_bool("DEBUG", False)
    if raw:
        origins = [origin.strip() for origin in raw.split(",") if origin.strip()]
        if not debug_mode:
            origins = [origin for origin in origins if not _is_local_origin(origin)]
        return origins
    if not debug_mode:
        # Production default: restrict to explicitly configured frontend origin(s).
        origins: list[str] = []
        frontend_app_url = _normalize_url(os.getenv("FRONTEND_APP_URL") or "")
        if frontend_app_url:
            origins.append(frontend_app_url)

        deduped: list[str] = []
        for origin in origins:
            if origin and origin not in deduped:
                deduped.append(origin)
        return deduped
    # Local dev defaults
    return [
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ]

def _get_cors_origin_regex() -> str | None:
    if _env_bool("CORS_ALLOW_ALL"):
        return None
    explicit = os.getenv("CORS_ORIGIN_REGEX", "").strip()
    debug_mode = _env_bool("DEBUG", False)
    allow_localhost = _env_bool("CORS_ALLOW_LOCALHOST", True)
    localhost_pattern = r"^https?://(localhost|127[.]0[.]0[.]1)(:[0-9]+)?$"

    if explicit:
        if debug_mode and allow_localhost:
            # In local development, always allow localhost random dev ports even when
            # an explicit regex is provided.
            return f"(?:{explicit})|(?:{localhost_pattern})"
        return explicit

    if not debug_mode:
        return None
    # Default to allowing localhost/127.0.0.1 any port for dev tooling
    # (Flutter web, Vite, React, etc). Can be disabled via CORS_ALLOW_LOCALHOST=false.
    if allow_localhost:
        return localhost_pattern
    return None

_cors_allow_all = _env_bool("CORS_ALLOW_ALL")
_cors_allow_credentials = _env_bool("CORS_ALLOW_CREDENTIALS") and not _cors_allow_all
_cors_origin_regex = _get_cors_origin_regex()

app.add_middleware(
    CORSMiddleware,
    allow_origins=_get_cors_origins(),
    allow_credentials=_cors_allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
    allow_origin_regex=_cors_origin_regex,
    max_age=_env_int("CORS_MAX_AGE_SECONDS", 86400),
)

_trusted_hosts = [h.strip() for h in os.getenv("ALLOWED_HOSTS", "").split(",") if h.strip()]
if _trusted_hosts:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=_trusted_hosts)

# Phase 6: Add observability middleware
try:
    from .middleware.observability_middleware import (
        DistributedTracingMiddleware,
        ErrorTrackingMiddleware,
        MetricsMiddleware,
    )
    app.add_middleware(MetricsMiddleware)
    app.add_middleware(ErrorTrackingMiddleware)
    app.add_middleware(DistributedTracingMiddleware)
except Exception as exc:
    print(f"[WARN] Could not load observability middleware: {exc}")

# Include routers
app.include_router(users_router)
app.include_router(websocket_router)
app.include_router(engagement_router)
app.include_router(auth_status_router)
app.include_router(header_router)
app.include_router(notifications_router)
app.include_router(settings_router)
if AI_ROUTES_AVAILABLE:
    app.include_router(ai_task_router)
if ADVANCED_FEATURES_AVAILABLE:
    app.include_router(advanced_router)
if ACCOUNTS_ROUTES_AVAILABLE:
    app.include_router(accounts_router)
if SUBSCRIPTION_ROUTES_AVAILABLE:
    app.include_router(subscription_router)
if CREDENTIAL_VAULT_ROUTES_AVAILABLE:
    app.include_router(credential_vault_router)
if PUBLIC_AUTH_ROUTES_AVAILABLE:
    app.include_router(public_auth_router)
if OPS_ROUTES_AVAILABLE:
    app.include_router(ops_router)
if MONITORING_ROUTES_AVAILABLE:
    app.include_router(monitoring_router)

if MONITORING_ROUTES_AVAILABLE:
    app.include_router(monitoring_router)


@app.get("/")
async def root():
    return {
        "message": "Forex Companion AI - Autonomous Trading Copilot",
        "version": "3.0.0",
        "status": "online",
        "ai_enabled": AI_ROUTES_AVAILABLE,
        "advanced_features": ADVANCED_FEATURES_AVAILABLE,
        "ops_routes": OPS_ROUTES_AVAILABLE,
        "endpoints": {
            "docs": "/docs",
            "websocket": _public_ws_endpoint(),
            "create_task": "/api/tasks/create" if AI_ROUTES_AVAILABLE else "Not Available",
            "advanced_features": "/api/advanced/copilot/status/{user_id}" if ADVANCED_FEATURES_AVAILABLE else "Not Available",
            "ops_status": "/api/ops/status" if OPS_ROUTES_AVAILABLE else "Not Available",
        },
        "features": {
            "autonomous_trading": ADVANCED_FEATURES_AVAILABLE,
            "risk_management": ADVANCED_FEATURES_AVAILABLE,
            "prediction_explainability": ADVANCED_FEATURES_AVAILABLE,
            "execution_intelligence": ADVANCED_FEATURES_AVAILABLE,
            "paper_trading": ADVANCED_FEATURES_AVAILABLE,
            "natural_language_commands": ADVANCED_FEATURES_AVAILABLE,
            "security_compliance": ADVANCED_FEATURES_AVAILABLE,
            "multi_channel_notifications": ADVANCED_FEATURES_AVAILABLE,
            "subscription_gates": SUBSCRIPTION_ROUTES_AVAILABLE,
            "credential_vault": CREDENTIAL_VAULT_ROUTES_AVAILABLE,
            "public_password_reset": PUBLIC_AUTH_ROUTES_AVAILABLE,
        }
    }


@app.get("/health")
async def health():
    # CRITICAL: Must respond instantly with NO dependencies
    # Railway healthcheck relies on this endpoint
    return {"status": "ok"}


@app.get("/healthz")
async def healthz():
    return {
        "status": "ok",
        "service": "forex-companion-backend",
    }


@app.get("/api/health")
async def api_health():
    firebase_status = get_firebase_config_status() if os.getenv("DEBUG", "").lower() == "true" else "hidden"
    return {
        "status": "healthy",
        "ai_engine": "active" if AI_ROUTES_AVAILABLE else "disabled",
        "connections": ws_manager.get_connection_count(),
        "firebase": firebase_status,
    }
