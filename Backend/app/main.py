"""
Forex Companion - Complete FastAPI Application
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

# Import routers
from .users import router as users_router
from .websocket_routes import router as websocket_router
from .auth_routes import router as auth_router

try:
    from .ai_task_routes import router as ai_task_router
    AI_ROUTES_AVAILABLE = True
except ImportError:
    AI_ROUTES_AVAILABLE = False
    print("??  AI task routes not available")

try:
    from .advanced_features_routes import router as advanced_router
    ADVANCED_FEATURES_AVAILABLE = True
except ImportError:
    ADVANCED_FEATURES_AVAILABLE = False
    print("??  Advanced features routes not available")

from .enhanced_websocket_manager import ws_manager


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan events"""
    print("=" * 60)
    print("?? Forex Companion AI Backend Starting...")
    print("=" * 60)
    print("?? WebSocket: ws://localhost:8080/api/ws/{task_id}")
    print("?? API Docs: http://localhost:8080/docs")
    print(f"?? AI Engine: {'ACTIVE' if AI_ROUTES_AVAILABLE else 'DISABLED'}")
    print(f"?? Advanced Features: {'ACTIVE' if ADVANCED_FEATURES_AVAILABLE else 'DISABLED'}")
    print("=" * 60)
    
    await ws_manager.start_forex_stream(interval=10)
    
    yield
    
    ws_manager.stop_forex_stream()
    print("? Shutdown complete")


app = FastAPI(
    title="Forex Companion AI API",
    description="AI-Powered Autonomous Forex Trading System",
    version="2.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(websocket_router)
if AI_ROUTES_AVAILABLE:
    app.include_router(ai_task_router)
if ADVANCED_FEATURES_AVAILABLE:
    app.include_router(advanced_router)


@app.get("/")
async def root():
    return {
        "message": "Forex Companion AI - Autonomous Trading Copilot",
        "version": "3.0.0",
        "status": "online",
        "ai_enabled": AI_ROUTES_AVAILABLE,
        "advanced_features": ADVANCED_FEATURES_AVAILABLE,
        "endpoints": {
            "docs": "/docs",
            "websocket": "ws://localhost:8080/api/ws/{task_id}",
            "create_task": "/api/tasks/create" if AI_ROUTES_AVAILABLE else "Not Available",
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
        }
    }


@app.get("/health")
async def health():
    return {
        "status": "healthy",
        "ai_engine": "active" if AI_ROUTES_AVAILABLE else "disabled",
        "connections": ws_manager.get_connection_count()
    }
