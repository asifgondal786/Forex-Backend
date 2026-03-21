from app.market_routes import router as market_router
from app.risk_routes import router as risk_router
from app.signal_routes import router as signal_router
from app.news_routes import router as news_router
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
import collections
import json
import uuid
import asyncio
import logging
import importlib
from urllib.parse import urlparse
from dotenv import load_dotenv
from .config.audit import log_config_snapshot
from .config.index import get_config, startup_snapshot as config_startup_snapshot
from .config.logging import setup_logging
from .config.validate_env import log_payload as env_validation_log_payload
from .config.validate_env import validate_environment

# Load environment variables from Backend/.env if present.
# override=True ensures local .env values win over accidental shell-level vars.
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env", override=True)
setup_logging()
logger = logging.getLogger("app.main")
rate_limit_logger = logging.getLogger("rate_limit")


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


def _current_environment() -> str:
    explicit = (os.getenv("ENVIRONMENT") or "").strip().lower()
    if explicit:
        return explicit
    return "development" if _env_bool("DEBUG", False) else "production"


def _is_development_environment() -> bool:
    return _current_environment() in {"dev", "development", "local", "test", "testing"}


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
    config = get_config()
    snapshot = config_startup_snapshot(config)
    snapshot.update(
        {
            "cors_origins": _get_cors_origins(),
            "trusted_hosts": _get_trusted_hosts(),
            "cors_allow_credentials": _cors_allow_credentials,
            "cors_allow_all": _cors_allow_all,
            "csp_report_only": _env_bool("CSP_REPORT_ONLY", False),
            "has_mailjet_api_key": bool((os.getenv("MAILJET_API_KEY") or "").strip()),
            "api_base_url_hint": _normalize_url(os.getenv("API_BASE_URL") or ""),
            "railway_public_domain": (os.getenv("RAILWAY_PUBLIC_DOMAIN") or "").strip(),
            "redacted_service_account_path": _redact(
                os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH") or "",
                keep=8,
            ),
        }
    )
    return snapshot


def _init_sentry_if_configured() -> None:
    config = get_config()
    if not config.runtime.is_production:
        return
    if not config.monitoring.sentry_dsn:
        return
    try:
        sentry_sdk = importlib.import_module("sentry_sdk")
        fastapi_integration_module = importlib.import_module("sentry_sdk.integrations.fastapi")
        fastapi_integration_cls = getattr(fastapi_integration_module, "FastApiIntegration")

        sentry_sdk.init(
            dsn=config.monitoring.sentry_dsn,
            integrations=[fastapi_integration_cls()],
            traces_sample_rate=config.monitoring.sentry_traces_sample_rate,
            environment=config.runtime.environment,
            release=config.monitoring.app_release or None,
        )
        logger.info(
            json.dumps(
                {
                    "event": "sentry_initialized",
                    "environment": config.runtime.environment,
                    "release": config.monitoring.app_release,
                    "traces_sample_rate": config.monitoring.sentry_traces_sample_rate,
                }
            )
        )
    except Exception as exc:
        logger.warning(
            json.dumps(
                {
                    "event": "sentry_init_failed",
                    "error": str(exc),
                }
            )
        )


def _validate_env_urls() -> None:
    if _is_development_environment():
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

    if _env_bool("CORS_ALLOW_ALL", False):
        raise RuntimeError("CORS_ALLOW_ALL must be disabled in production.")

    allow_localhost = _env_bool("CORS_ALLOW_LOCALHOST_IN_PRODUCTION", True)
    for origin in _get_cors_origins():
        if origin == "*":
            raise RuntimeError("Wildcard CORS origin is not allowed in production.")
        if _is_local_origin(origin):
            if not allow_localhost:
                raise RuntimeError(
                    "Localhost CORS origins are disabled in production by "
                    "CORS_ALLOW_LOCALHOST_IN_PRODUCTION=false."
                )
            continue
        if not _is_https_url(origin):
            raise RuntimeError(f"CORS origin must use HTTPS in production: {origin}")

# Import routers
from .users import router as users_router  # noqa: E402
from .websocket_routes import router as websocket_router  # noqa: E402
from .engagement_routes import router as engagement_router  # noqa: E402
from .auth_status_routes import router as auth_status_router  # noqa: E402
from .header_routes import router as header_router  # noqa: E402
from .notifications_routes import router as notifications_router  # noqa: E402
from .settings_routes import router as settings_router  # noqa: E402

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

try:
    from .routers.ai_proxy import router as ai_proxy_router
    AI_PROXY_AVAILABLE = True
except ImportError:
    AI_PROXY_AVAILABLE = False
    print("[WARN] AI proxy routes not available")

from .enhanced_websocket_manager import ws_manager  # noqa: E402
from .forex_data_service import forex_service  # noqa: E402
from .services.task_queue_service import task_queue_service  # noqa: E402
from .services.redis_store import redis_store  # noqa: E402
from .services.rate_limiter import RateLimiter  # noqa: E402
from fastapi.routing import APIRouter as _APIRouter  # noqa: E402
from .services.observability import health_checker  # noqa: E402
from .utils.firestore_client import (  # noqa: E402
    check_firebase_authorized_domain,
    get_firebase_config_status,
    init_firebase,
)
from .schemas.api_response import (  # noqa: E402
    error_payload,
    is_api_response_payload,
    success_payload,
)
from .security import verify_http_request  # noqa: E402


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan events"""
    logger.info("=" * 60)
    logger.info("[Startup] Forex Companion AI Backend Starting...")
    logger.info("=" * 60)

    try:
        public_api_base = _public_api_base_url()
        logger.info(f"[Startup] WebSocket: {_public_ws_endpoint()}")
        logger.info(f"[Startup] API Docs: {f'{public_api_base}/docs' if public_api_base else '/docs'}")
        logger.info(f"[Startup] AI Engine: {'ACTIVE' if AI_ROUTES_AVAILABLE else 'DISABLED'}")
        logger.info(f"[Startup] Advanced Features: {'ACTIVE' if ADVANCED_FEATURES_AVAILABLE else 'DISABLED'}")
    except Exception as e:
        logger.warning(f"[Startup] Warning: Could not print startup info: {e}")

    logger.info("=" * 60)

    # Configure optional monitoring integrations.
    _init_sentry_if_configured()

    # Structured environment validation (no secret values in logs).
    try:
        env_validation_result = validate_environment()
        payload = env_validation_log_payload(env_validation_result)
        if env_validation_result.errors:
            logger.error(json.dumps(payload))
        elif env_validation_result.warnings:
            logger.warning(json.dumps(payload))
        else:
            logger.info(json.dumps(payload))
        if env_validation_result.errors and get_config().runtime.validation_fail_fast:
            raise RuntimeError("Environment validation failed with one or more errors.")
    except Exception as e:
        logger.error(f"[Startup] ERROR: Environment validation failed: {e}")
        if get_config().runtime.validation_fail_fast:
            raise

    # Fail fast on invalid production URL configuration (graceful).
    try:
        _validate_env_urls()
    except Exception as e:
        logger.warning(f"[Startup] Warning: URL validation failed (non-blocking): {e}")

    # Startup checklist (no secrets / redacted).
    try:
        logger.info(
            json.dumps(
                {
                    "event": "startup_checklist",
                    **_startup_snapshot(),
                }
            )
        )
        log_config_snapshot(get_config())
    except Exception as e:
        logger.warning(f"[Startup] Warning: Could not generate startup snapshot: {e}")

    # Firebase Admin SDK startup health check
    firebase_initialized = False
    firebase_status_snapshot = {}
    try:
        status = get_firebase_config_status()
        firebase_status_snapshot = status
        if status["credential_source"] != "none":
            init_firebase()
            status = get_firebase_config_status()
            firebase_status_snapshot = status
            firebase_initialized = True
            logger.info(
                f"[Firebase] Initialized via {status['credential_source']} "
                f"(project_id={status['project_id']})"
            )
            identity_payload = {
                "event": "firebase_runtime_identity",
                "credential_source": status.get("credential_source"),
                "env_project_id": status.get("env_project_id"),
                "app_project_id": status.get("app_project_id"),
                "credential_project_id": status.get("credential_project_id"),
                "project_id_match": status.get("project_id_match"),
                "credential_client_email": status.get("credential_client_email"),
                "has_service_account_json_b64": status.get("has_service_account_json_b64"),
                "has_service_account_json": status.get("has_service_account_json"),
                "has_service_account_path": status.get("has_service_account_path"),
            }
            if status.get("credential_metadata_error"):
                identity_payload["credential_metadata_error"] = status.get(
                    "credential_metadata_error"
                )
            if status.get("init_error"):
                identity_payload["init_error"] = status.get("init_error")
            logger.info(json.dumps(identity_payload))
            if status.get("project_id_match") is False:
                logger.warning(
                    "[Firebase] WARNING: FIREBASE_PROJECT_ID does not match "
                    "initialized Firebase app project."
                )
        else:
            logger.warning("[Firebase] Not configured (no credentials found).")
            logger.info(
                json.dumps(
                    {
                        "event": "firebase_runtime_identity",
                        "credential_source": status.get("credential_source"),
                        "env_project_id": status.get("env_project_id"),
                        "has_service_account_json_b64": status.get("has_service_account_json_b64"),
                        "has_service_account_json": status.get("has_service_account_json"),
                        "has_service_account_path": status.get("has_service_account_path"),
                    }
                )
            )
            if os.getenv("REQUIRE_FIREBASE", "").lower() == "true":
                raise RuntimeError("Firebase configuration required but not found.")
    except Exception as exc:
        logger.error(f"[Firebase] Startup check failed: {exc}")
        if firebase_status_snapshot:
            logger.info(
                json.dumps(
                    {
                        "event": "firebase_runtime_identity",
                        "credential_source": firebase_status_snapshot.get("credential_source"),
                        "env_project_id": firebase_status_snapshot.get("env_project_id"),
                        "app_project_id": firebase_status_snapshot.get("app_project_id"),
                        "project_id_match": firebase_status_snapshot.get("project_id_match"),
                        "has_service_account_json_b64": firebase_status_snapshot.get("has_service_account_json_b64"),
                        "has_service_account_json": firebase_status_snapshot.get("has_service_account_json"),
                        "has_service_account_path": firebase_status_snapshot.get("has_service_account_path"),
                        "init_error": firebase_status_snapshot.get("init_error"),
                    }
                )
            )
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
        logger.warning(f"[Startup] Warning: Could not register health checks: {e}")

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
                logger.info(json.dumps(log_payload))

                if not domain_check.get("authorized"):
                    message = (
                        f"Firebase Auth domain '{frontend_host}' is not allowlisted. "
                        "Add it in Firebase Console -> Authentication -> Settings -> "
                        "Authorized domains."
                    )
                    if check_fail_fast:
                        raise RuntimeError(message)
                    logger.warning(f"[Firebase] WARNING: {message}")
            except Exception as exc:
                if check_fail_fast:
                    raise
                logger.warning(f"[Firebase] WARNING: Authorized-domain check skipped: {exc}")

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
            logger.warning("[Startup] WARNING: Task queue startup timed out (non-blocking)")
        except Exception as e:
            logger.warning(f"[Startup] WARNING: Task queue startup failed: {e}")

    if forex_stream_enabled:
        try:
            await asyncio.wait_for(
                ws_manager.start_forex_stream(interval=forex_stream_interval),
                timeout=10.0  # 10 second timeout
            )
        except asyncio.TimeoutError:
            logger.warning("[Startup] WARNING: Forex stream startup timed out (non-blocking)")
        except Exception as e:
            logger.warning(f"[Startup] WARNING: Forex stream startup failed: {e}")

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
    logger.info("[Shutdown] complete")


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


def _split_csv_values(raw: str) -> list[str]:
    return [value.strip() for value in (raw or "").split(",") if value.strip()]


def _dedupe_values(values: list[str]) -> list[str]:
    unique: list[str] = []
    for value in values:
        if value and value not in unique:
            unique.append(value)
    return unique


def _origin_to_ws_source(origin: str) -> str:
    parsed = urlparse(_normalize_url(origin))
    scheme = (parsed.scheme or "").lower()
    host = parsed.netloc or ""
    if not host:
        return ""
    if scheme == "https":
        return f"wss://{host}"
    if scheme == "http":
        return f"ws://{host}"
    return ""


def _csp_connect_sources() -> list[str]:
    sources = ["'self'"]
    origins = _get_cors_origins()

    if "*" in origins:
        # Keep wildcard mode dev-only and protocol-scoped for CSP.
        sources.extend(["https:", "http:", "wss:", "ws:"])
        return _dedupe_values(sources)

    normalized_origins = [_normalize_url(origin) for origin in origins if origin and origin != "*"]
    normalized_origins = [origin for origin in normalized_origins if origin]
    sources.extend(normalized_origins)
    sources.extend(
        [
            ws_source
            for ws_source in (_origin_to_ws_source(origin) for origin in normalized_origins)
            if ws_source
        ]
    )
    return _dedupe_values(sources)


def _serialize_csp_directives(directives: dict[str, list[str]]) -> str:
    parts: list[str] = []
    for directive, values in directives.items():
        cleaned = _dedupe_values([value.strip() for value in values if value and value.strip()])
        if cleaned:
            parts.append(f"{directive} {' '.join(cleaned)}")
    return "; ".join(parts)


def _build_csp_header(*, docs_mode: bool) -> str:
    explicit = (
        os.getenv("CSP_HEADER_OVERRIDE")
        or os.getenv("CSP_OVERRIDE")
        or ""
    ).strip()
    if explicit:
        return explicit

    if _is_development_environment() and _env_bool("CSP_DEV_LOOSE", False):
        return (
            "default-src * data: blob:; "
            "script-src * 'unsafe-inline' 'unsafe-eval' data: blob:; "
            "style-src * 'unsafe-inline'; "
            "img-src * data: blob:; "
            "font-src * data:; "
            "connect-src * ws: wss:;"
        )

    directives: dict[str, list[str]] = {
        "default-src": ["'self'"],
        "base-uri": ["'self'"],
        "frame-ancestors": ["'none'"],
        "object-src": ["'none'"],
        "form-action": ["'self'"],
        "connect-src": _csp_connect_sources(),
        "img-src": ["'self'", "data:"],
        "font-src": ["'self'", "data:"],
    }

    if docs_mode:
        directives["script-src"] = [
            "'self'",
            "https://cdn.jsdelivr.net",
            "'unsafe-inline'",
        ]
        directives["style-src"] = [
            "'self'",
            "https://cdn.jsdelivr.net",
            "'unsafe-inline'",
        ]
        directives["img-src"].append("https://fastapi.tiangolo.com")
    else:
        directives["script-src"] = ["'self'"]
        directives["style-src"] = ["'self'"]

    return _serialize_csp_directives(directives)


def _is_docs_route(path: str) -> bool:
    return (
        path == "/docs"
        or path == "/redoc"
        or path == "/openapi.json"
        or path.startswith("/docs/")
        or path.startswith("/redoc/")
    )


def _csp_header_name() -> str:
    if _env_bool("CSP_REPORT_ONLY", False):
        return "Content-Security-Policy-Report-Only"
    return "Content-Security-Policy"


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
    logger.exception(
        "[UnhandledError] request_id=%s path=%s error=%s: %s",
        request_id,
        request.url.path,
        type(exc).__name__,
        exc,
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
        or path.startswith("/api/v1/market")
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
        csp_header_name = _csp_header_name()
        existing_csp = (
            response.headers.get("Content-Security-Policy")
            or response.headers.get("Content-Security-Policy-Report-Only")
        )
        if not existing_csp:
            csp_header_value = _build_csp_header(docs_mode=_is_docs_route(request.url.path))
            response.headers[csp_header_name] = csp_header_value
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
_runtime_config = get_config()
_rate_limit_enabled = _runtime_config.security.rate_limit_enabled
_rate_limit_max = _runtime_config.security.rate_limit_max
_rate_limit_store: dict = {}
_rate_limit_window = _runtime_config.security.rate_limit_window_seconds
_global_limiter = RateLimiter(limit=_rate_limit_max, window=_rate_limit_window)
_rate_limit_exempt = {"/", "/health", "/healthz", "/api/health", "/api/v1/signals/health", "/api/v1/signals/generate",
    "/api/v1/signals/indicators/EUR_USD",
    "/api/v1/signals/indicators/GBP_USD",
    "/api/v1/signals/indicators/USD_JPY",
    "/api/v1/news/feed",
    "/api/v1/news/events",
    "/api/v1/news/macro-shield",
    "/api/v1/news/health", "/docs", "/openapi.json", "/redoc"}
_max_request_body_bytes = _env_int("MAX_REQUEST_BODY_BYTES", 1_048_576)


def _normalize_middleware_path(path: str) -> str:
    if not path:
        return "/"
    if path != "/" and path.endswith("/"):
        normalized = path.rstrip("/")
        return normalized or "/"
    return path


_auth_rate_limit_enabled = _runtime_config.security.auth_rate_limit_enabled
_auth_rate_limit_max = _runtime_config.security.auth_rate_limit_max
_auth_rate_limit_store: dict = {}
_auth_rate_limit_window = _runtime_config.security.auth_rate_limit_window_seconds
_auth_global_limiter = RateLimiter(limit=_rate_limit_max, window=_rate_limit_window)
_auth_rate_limited_paths = {
    "/auth/password-reset",
    "/auth/email-verification",
    "/auth/login",
    "/auth/signup",
    "/auth/email-provider-status",   # ÃƒÂ¢Ã¢â‚¬Â Ã‚Â add this
}
# app/main.py ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â find this set:
_public_unauthenticated_auth_paths = {
    "/auth/password-reset",
    "/auth/email-verification",
    "/auth/email-provider-status",
    "/api/ai/health",
    "/api/health",        # ÃƒÂ¢Ã¢â‚¬Â Ã‚Â add this line
    "/api/v1/market/prices",
    "/api/v1/market/health",
    "/api/v1/market/supported",
    "/api/v1/market/ohlc",
    "/api/v1/risk/simulate",
    "/api/v1/risk/health",
    "/api/v1/signals/health",
    "/api/v1/signals/generate",
    "/api/v1/signals/indicators/EUR_USD",
    "/api/v1/signals/indicators/GBP_USD",
    "/api/v1/signals/indicators/USD_JPY",
    "/api/v1/news/feed",
    "/api/v1/news/events",
    "/api/v1/news/macro-shield",
    "/api/v1/news/health",
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

    path = _normalize_middleware_path(request.url.path)
    if path not in _auth_rate_limited_paths:
        return await call_next(request)

    client_host = request.client.host if request.client else "unknown"
    key = f"{client_host}:{path}"
    now = time.time()
    window_start = now - _auth_rate_limit_window
    if key not in _auth_rate_limit_store:
        _auth_rate_limit_store[key] = collections.deque()
    bucket = _auth_rate_limit_store[key]
    while bucket and bucket[0] <= window_start:
        bucket.popleft()
    if len(bucket) >= _auth_rate_limit_max:
        rate_limit_logger.warning(
            json.dumps(
                {
                    "event": "auth_rate_limit_exceeded",
                    "client_ip": client_host,
                    "path": path,
                    "limit": _auth_rate_limit_max,
                    "window_seconds": _auth_rate_limit_window,
                    "request_id": _request_id_from_request(request),
                }
            )
        )
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

    path = _normalize_middleware_path(request.url.path)
    if path in _rate_limit_exempt or path.startswith("/docs"):
        return await call_next(request)

    client_host = request.client.host if request.client else "unknown"
    now = time.time()
    window_start = now - _rate_limit_window
    if client_host not in _rate_limit_store:
        _rate_limit_store[client_host] = collections.deque()
    bucket = _rate_limit_store[client_host]
    while bucket and bucket[0] <= window_start:
        bucket.popleft()
    if len(bucket) >= _rate_limit_max:
        rate_limit_logger.warning(
            json.dumps(
                {
                    "event": "global_rate_limit_exceeded",
                    "client_ip": client_host,
                    "path": path,
                    "limit": _rate_limit_max,
                    "window_seconds": _rate_limit_window,
                    "request_id": _request_id_from_request(request),
                }
            )
        )
        return JSONResponse(
            status_code=429,
            content=error_payload(
                message="Rate limit exceeded",
                request_id=_request_id_from_request(request),
            ),
            headers={"Retry-After": str(_rate_limit_window)},   # ÃƒÂ¢Ã¢â‚¬Â Ã‚Â add this
        )
    bucket.append(now)
    return await call_next(request)

@app.middleware("http")
async def strict_auth_middleware(request: Request, call_next):
    if request.method == "OPTIONS":
        return await call_next(request)

    path = _normalize_middleware_path(request.url.path)
    if path in _public_unauthenticated_auth_paths:
        return await call_next(request)

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
_FRONTEND_PROD_ORIGIN = "https://forexcompanion-e5a28.web.app"
_FRONTEND_DEV_ORIGINS = [
    "http://localhost:3000",
    "http://localhost:5000",
    "http://localhost:8080",
]


def _split_csv(raw: str) -> list[str]:
    return [value.strip() for value in (raw or "").split(",") if value.strip()]


def _dedupe(values: list[str]) -> list[str]:
    unique: list[str] = []
    for value in values:
        if value and value not in unique:
            unique.append(value)
    return unique


def _parse_origin_list(raw: str) -> list[str]:
    parsed = [_normalize_url(value) for value in _split_csv(raw)]
    return _dedupe([value for value in parsed if value])


def _default_cors_origins() -> list[str]:
    frontend_prod = (
        _normalize_url(os.getenv("FRONTEND_APP_URL") or "")
        or _normalize_url(os.getenv("FRONTEND_PROD_URL") or "")
        or _FRONTEND_PROD_ORIGIN
    )
    origins: list[str] = [frontend_prod, *_FRONTEND_DEV_ORIGINS]
    origins.extend(_parse_origin_list(os.getenv("CORS_EXTRA_ORIGINS") or ""))
    return _dedupe([value for value in origins if value])


def _get_cors_origins() -> list[str]:
    origins = _default_cors_origins()
    origins.extend(_parse_origin_list(os.getenv("CORS_ORIGINS") or ""))
    origins.extend(_parse_origin_list(os.getenv("CORS_ALLOWED_ORIGINS") or ""))
    return _dedupe(origins)


def _get_cors_origin_regex() -> str | None:
    explicit = (
        os.getenv("CORS_ALLOWED_ORIGIN_REGEX")
        or os.getenv("CORS_ORIGIN_REGEX")
        or ""
    ).strip()
    return explicit or None


def _get_cors_allow_methods() -> list[str]:
    explicit = [value.upper() for value in _split_csv(os.getenv("CORS_ALLOW_METHODS") or "")]
    if explicit:
        return _dedupe(explicit)
    return ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]


def _get_cors_allow_headers() -> list[str]:
    explicit = _split_csv(os.getenv("CORS_ALLOW_HEADERS") or "")
    if explicit:
        return _dedupe(explicit)
    return [
        "Authorization",
        "Content-Type",
        "Accept",
        "Origin",
        "User-Agent",
        "X-Request-ID",
        "X-User-Id",
        "X-Dev-Auth",
    ]


def _get_cors_expose_headers() -> list[str]:
    explicit = _split_csv(os.getenv("CORS_EXPOSE_HEADERS") or "")
    if explicit:
        return _dedupe(explicit)
    return ["X-Request-ID"]


def _get_cors_allow_all() -> bool:
    if not _env_bool("CORS_ALLOW_ALL", False):
        return False
    if _is_development_environment():
        return True
    print("[CORS] Warning: CORS_ALLOW_ALL=true ignored outside development.")
    return False


def _get_trusted_hosts() -> list[str]:
    explicit_hosts = _split_csv_values(os.getenv("ALLOWED_HOSTS", ""))
    if not explicit_hosts:
        return []

    hosts = [value.lower() for value in explicit_hosts]

    # Railway sets this in deployed environments; include it when host filtering is enabled.
    railway_public_domain = (os.getenv("RAILWAY_PUBLIC_DOMAIN") or "").strip().lower()
    if railway_public_domain:
        hosts.append(railway_public_domain)

    # If a public API base URL is configured, allow that host as well.
    public_api_host = _parse_host(_public_api_base_url())
    if public_api_host:
        hosts.append(public_api_host)

    return _dedupe_values(hosts)


_cors_allow_all = _get_cors_allow_all()
_cors_allow_credentials = _runtime_config.security.cors_allow_all is False and _env_bool(
    "CORS_ALLOW_CREDENTIALS",
    True,
)
_cors_origins = ["*"] if _cors_allow_all else _get_cors_origins()
_cors_origin_regex = None if _cors_allow_all else _get_cors_origin_regex()

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=_cors_allow_credentials,
    allow_methods=_get_cors_allow_methods(),
    allow_headers=_get_cors_allow_headers(),
    expose_headers=_get_cors_expose_headers(),
    allow_origin_regex=_cors_origin_regex,
    max_age=_env_int("CORS_MAX_AGE_SECONDS", 86400),
)

_trusted_hosts = _get_trusted_hosts()
if _trusted_hosts:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=_trusted_hosts)

# Phase 6: Add observability middleware
try:
    from .middleware.observability_middleware import (
        DistributedTracingMiddleware,
        ErrorTrackingMiddleware,
        MetricsMiddleware,
    )
    # Observability middleware temporarily disabled
    # app.add_middleware(MetricsMiddleware)
    # app.add_middleware(ErrorTrackingMiddleware)
    # app.add_middleware(DistributedTracingMiddleware)
except Exception as exc:
    logger.warning(f"[WARN] Could not load observability middleware: {exc}")

# Phase 7: Add audit middleware for auth-sensitive paths and error responses.
try:
    from .middleware.audit import AuditMiddleware

    app.add_middleware(AuditMiddleware)
except Exception as exc:
    logger.warning(f"[WARN] Could not load audit middleware: {exc}")

# ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ API v1 versioned router ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
# All /api/* routes are mounted under /api/v1 via this wrapper.
# Unversioned routes (/health, /healthz, /api/health, /auth) are registered
# directly on `app` below and remain unaffected.
_v1 = _APIRouter(prefix="/v1")

_v1.include_router(users_router)
_v1.include_router(websocket_router)
_v1.include_router(engagement_router)
_v1.include_router(auth_status_router)
_v1.include_router(header_router)
_v1.include_router(notifications_router)
_v1.include_router(settings_router)
if AI_ROUTES_AVAILABLE:
    _v1.include_router(ai_task_router)
if ADVANCED_FEATURES_AVAILABLE:
    _v1.include_router(advanced_router)
if ACCOUNTS_ROUTES_AVAILABLE:
    _v1.include_router(accounts_router)
if SUBSCRIPTION_ROUTES_AVAILABLE:
    _v1.include_router(subscription_router)
if CREDENTIAL_VAULT_ROUTES_AVAILABLE:
    _v1.include_router(credential_vault_router)
if OPS_ROUTES_AVAILABLE:
    _v1.include_router(ops_router)
if MONITORING_ROUTES_AVAILABLE:
    _v1.include_router(monitoring_router)
if AI_PROXY_AVAILABLE:
    _v1.include_router(ai_proxy_router)

# Mount v1 router ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â all /api/* routes become /api/v1/*
app.include_router(_v1)
app.include_router(market_router)
app.include_router(risk_router)
app.include_router(signal_router)
app.include_router(news_router)

# Unversioned routes (public auth, no /api prefix)
if PUBLIC_AUTH_ROUTES_AVAILABLE:
    app.include_router(public_auth_router)


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














