"""
Forex Companion - Complete FastAPI Application
"""
from pathlib import Path
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
<<<<<<< HEAD
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from contextlib import asynccontextmanager
import os
import time
from collections import defaultdict, deque
from dotenv import load_dotenv

# Load environment variables from Backend/.env if present
load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")


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
=======
from contextlib import asynccontextmanager
>>>>>>> 6ea3e47c (AI task button files)

# Import routers
from .users import router as users_router
from .websocket_routes import router as websocket_router
<<<<<<< HEAD
from .engagement_routes import router as engagement_router
from .auth_status_routes import router as auth_status_router
from .header_routes import router as header_router
from .notifications_routes import router as notifications_router
from .settings_routes import router as settings_router

=======
>>>>>>> 6ea3e47c (AI task button files)
try:
    from .ai_task_routes import router as ai_task_router
    AI_ROUTES_AVAILABLE = True
except ImportError:
    AI_ROUTES_AVAILABLE = False
    print("??  AI task routes not available")

<<<<<<< HEAD
try:
    from .advanced_features_routes import router as advanced_router
    ADVANCED_FEATURES_AVAILABLE = True
except ImportError:
    ADVANCED_FEATURES_AVAILABLE = False
    print("??  Advanced features routes not available")

try:
    from .accounts_routes import router as accounts_router
    ACCOUNTS_ROUTES_AVAILABLE = True
except ImportError:
    ACCOUNTS_ROUTES_AVAILABLE = False
    print("??  Accounts routes not available")

try:
    from .subscription_routes import router as subscription_router
    SUBSCRIPTION_ROUTES_AVAILABLE = True
except ImportError:
    SUBSCRIPTION_ROUTES_AVAILABLE = False
    print("??  Subscription routes not available")

try:
    from .credential_vault_routes import router as credential_vault_router
    CREDENTIAL_VAULT_ROUTES_AVAILABLE = True
except ImportError:
    CREDENTIAL_VAULT_ROUTES_AVAILABLE = False
    print("??  Credential vault routes not available")

from .enhanced_websocket_manager import ws_manager
from .utils.firestore_client import get_firebase_config_status, init_firebase
from .security import verify_http_request
=======
from .enhanced_websocket_manager import ws_manager
>>>>>>> 6ea3e47c (AI task button files)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan events"""
    print("=" * 60)
    print("?? Forex Companion AI Backend Starting...")
    print("=" * 60)
    print("?? WebSocket: ws://localhost:8080/api/ws/{task_id}")
    print("?? API Docs: http://localhost:8080/docs")
    print(f"?? AI Engine: {'ACTIVE' if AI_ROUTES_AVAILABLE else 'DISABLED'}")
<<<<<<< HEAD
    print(f"?? Advanced Features: {'ACTIVE' if ADVANCED_FEATURES_AVAILABLE else 'DISABLED'}")
    print("=" * 60)

    # Firebase Admin SDK startup health check
    try:
        status = get_firebase_config_status()
        if status["credential_source"] != "none":
            init_firebase()
            status = get_firebase_config_status()
            print(f"[Firebase] Initialized via {status['credential_source']} (project_id={status['project_id']})")
        else:
            print("[Firebase] Not configured (no credentials found).")
            if os.getenv("REQUIRE_FIREBASE", "").lower() == "true":
                raise RuntimeError("Firebase configuration required but not found.")
    except Exception as exc:
        print(f"[Firebase] Startup check failed: {exc}")
        if os.getenv("REQUIRE_FIREBASE", "").lower() == "true":
            raise
    
    forex_stream_enabled = os.getenv("FOREX_STREAM_ENABLED", "true").lower() == "true"
    if forex_stream_enabled:
        await ws_manager.start_forex_stream(interval=10)

    yield

    if forex_stream_enabled:
        ws_manager.stop_forex_stream()
=======
    print("=" * 60)
    
    await ws_manager.start_forex_stream(interval=10)
    
    yield
    
    ws_manager.stop_forex_stream()
>>>>>>> 6ea3e47c (AI task button files)
    print("? Shutdown complete")


app = FastAPI(
    title="Forex Companion AI API",
    description="AI-Powered Autonomous Forex Trading System",
    version="2.0.0",
    lifespan=lifespan
)

<<<<<<< HEAD
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
    return response

# Rate limiting middleware (simple in-memory)
_rate_limit_enabled = os.getenv("RATE_LIMIT_ENABLED", "true").lower() == "true"
_rate_limit_max = int(os.getenv("RATE_LIMIT_MAX", "120"))
_rate_limit_window = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
_rate_limit_store = defaultdict(deque)
_rate_limit_exempt = {"/", "/health", "/api/health", "/docs", "/openapi.json", "/redoc"}
_max_request_body_bytes = _env_int("MAX_REQUEST_BODY_BYTES", 1_048_576)


@app.middleware("http")
async def request_size_limit_middleware(request: Request, call_next):
    if request.method in {"POST", "PUT", "PATCH"} and request.url.path.startswith("/api"):
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > _max_request_body_bytes:
                    return JSONResponse(
                        status_code=413,
                        content={"detail": "Request payload too large"},
                    )
            except ValueError:
                return JSONResponse(
                    status_code=400,
                    content={"detail": "Invalid Content-Length header"},
                )
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
            content={"detail": "Rate limit exceeded"},
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
            return JSONResponse(status_code=status_code, content={"detail": detail})

    return await call_next(request)

# CORS
def _get_cors_origins():
    if _env_bool("CORS_ALLOW_ALL"):
        return ["*"]
    raw = os.getenv("CORS_ORIGINS", "")
    if raw:
        return [origin.strip() for origin in raw.split(",") if origin.strip()]
    if not _env_bool("DEBUG", False):
        # Secure default in production: require explicit CORS origins.
        return []
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
    if explicit:
        return explicit
    # Default to allowing localhost/127.0.0.1 any port for dev tooling
    # (Flutter web, Vite, React, etc). Can be disabled via CORS_ALLOW_LOCALHOST=false.
    allow_localhost = _env_bool("CORS_ALLOW_LOCALHOST", True)
    if allow_localhost:
        return r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    return None

_cors_allow_all = _env_bool("CORS_ALLOW_ALL")
_cors_allow_credentials = _env_bool("CORS_ALLOW_CREDENTIALS") and not _cors_allow_all
_cors_origin_regex = _get_cors_origin_regex()

app.add_middleware(
    CORSMiddleware,
    allow_origins=_get_cors_origins(),
    allow_credentials=_cors_allow_credentials,
=======
# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
>>>>>>> 6ea3e47c (AI task button files)
    allow_methods=["*"],
    allow_headers=["*"],
    allow_origin_regex=_cors_origin_regex,
)

<<<<<<< HEAD
_trusted_hosts = [h.strip() for h in os.getenv("ALLOWED_HOSTS", "").split(",") if h.strip()]
if _trusted_hosts:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=_trusted_hosts)

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
=======
# Include routers
app.include_router(users_router)
app.include_router(websocket_router)
if AI_ROUTES_AVAILABLE:
    app.include_router(ai_task_router)
>>>>>>> 6ea3e47c (AI task button files)


@app.get("/")
async def root():
    return {
<<<<<<< HEAD
        "message": "Forex Companion AI - Autonomous Trading Copilot",
        "version": "3.0.0",
        "status": "online",
        "ai_enabled": AI_ROUTES_AVAILABLE,
        "advanced_features": ADVANCED_FEATURES_AVAILABLE,
=======
        "message": "Forex Companion AI - Ready to Trade",
        "version": "2.0.0",
        "status": "online",
        "ai_enabled": AI_ROUTES_AVAILABLE,
>>>>>>> 6ea3e47c (AI task button files)
        "endpoints": {
            "docs": "/docs",
            "websocket": "ws://localhost:8080/api/ws/{task_id}",
            "create_task": "/api/tasks/create" if AI_ROUTES_AVAILABLE else "Not Available",
<<<<<<< HEAD
            "advanced_features": "/api/advanced/copilot/status/{user_id}" if ADVANCED_FEATURES_AVAILABLE else "Not Available",
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
=======
>>>>>>> 6ea3e47c (AI task button files)
        }
    }


@app.get("/health")
async def health():
<<<<<<< HEAD
    firebase_status = get_firebase_config_status() if os.getenv("DEBUG", "").lower() == "true" else "hidden"
    return {
        "status": "healthy",
        "ai_engine": "active" if AI_ROUTES_AVAILABLE else "disabled",
        "connections": ws_manager.get_connection_count(),
        "firebase": firebase_status,
    }


@app.get("/api/health")
async def api_health():
    firebase_status = get_firebase_config_status() if os.getenv("DEBUG", "").lower() == "true" else "hidden"
    return {
        "status": "healthy",
        "ai_engine": "active" if AI_ROUTES_AVAILABLE else "disabled",
        "connections": ws_manager.get_connection_count(),
        "firebase": firebase_status,
=======
    return {
        "status": "healthy",
        "ai_engine": "active" if AI_ROUTES_AVAILABLE else "disabled",
        "connections": ws_manager.get_connection_count()
>>>>>>> 6ea3e47c (AI task button files)
    }
