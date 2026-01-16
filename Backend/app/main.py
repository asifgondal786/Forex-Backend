"""
Forex Companion - FastAPI Application Main Entry Point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# --- Import Your API Routers ---
from .live_updates_routes import router as updates_router
from .example_usage import router as example_tasks_router # Renamed for clarity
from .users import router as users_router # The new user router

# Create FastAPI app
app = FastAPI(
    title="Forex Companion API",
    description="Backend services for the Forex Companion application.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        # Add the specific port your Flutter web app runs on if it's consistent
        # e.g., "http://localhost:53398"
        "*" # Broad for local dev, but be specific in production
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# --- Include Your API Routers ---
# This is where you register the endpoints from your other files.
app.include_router(users_router)
app.include_router(updates_router)
# Note: The tasks router from example_usage.py is for demonstration.
# You will need to build a full task router for all frontend features.
app.include_router(example_tasks_router)


@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Welcome to the Forex Companion API!",
        "version": "1.0.0",
        "docs": "/docs",
        "description": "This API provides services for user management, task processing, and live updates."
    }


@app.on_event("startup")
async def startup_event():
    """Run on application startup"""
    print("🚀 Forex Companion Backend Starting...")
    print("---")
    print("See Uvicorn logs for the running host and port.")
    print("API docs will be available at '/docs' on that address.")
    print("---")


@app.on_event("shutdown")
async def shutdown_event():
    """Run on application shutdown"""
    print("👋 Forex Companion Backend Shutting Down...")