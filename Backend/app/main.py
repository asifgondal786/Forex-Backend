"""
FastAPI Application - Main Entry Point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import routes, websocket

# Create FastAPI app
app = FastAPI(
    title="ML Live Update Backend",
    description="Real-time ML training with live updates via WebSocket",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(routes.router)
app.include_router(websocket.router)


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "ML Live Update Server",
        "version": "1.0.0",
        "endpoints": {
            "docs": "/docs",
            "websocket": "/ws/{task_id}",
            "train": "/api/train",
            "predict": "/api/predict/{task_id}",
            "status": "/api/tasks/{task_id}/status",
            "health": "/api/health"
        }
    }


@app.on_event("startup")
async def startup_event():
    """Run on application startup"""
    print("🚀 ML Live Update Backend Starting...")
    print("📡 WebSocket endpoint: ws://localhost:8000/ws/{task_id}")
    print("📚 API docs: http://localhost:8000/docs")


@app.on_event("shutdown")
async def shutdown_event():
    """Run on application shutdown"""
    print("👋 ML Live Update Backend Shutting Down...")