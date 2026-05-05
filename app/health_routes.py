"""
health_routes.py — Production health, readiness, and liveness endpoints.
Used by Docker, load balancers, and monitoring systems.
"""

import time
import logging
from datetime import datetime, timezone

from fastapi import APIRouter
from app.services.redis_store import redis_ping
from app.ai.ai_router import health as ai_health

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Health"])

_START_TIME = time.time()


@router.get("/health")
async def health_check():
    """
    Basic health check — returns 200 if the process is alive.
    Used by Docker HEALTHCHECK and load balancer liveness probes.
    """
    return {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime_seconds": round(time.time() - _START_TIME, 1),
    }


@router.get("/health/ready")
async def readiness_check():
    """
    Readiness probe — checks all critical dependencies.
    Returns 503 if any dependency is unavailable.
    Used by Kubernetes/load balancer to decide if this instance should receive traffic.
    """
    checks = {}
    all_healthy = True

    # Redis
    try:
        redis_ok = await redis_ping()
        checks["redis"] = {"status": "up" if redis_ok else "down"}
        if not redis_ok:
            all_healthy = False
    except Exception as e:
        checks["redis"] = {"status": "down", "error": str(e)}
        all_healthy = False

    # AI providers
    try:
        ai_status = await ai_health()
        checks["ai_providers"] = ai_status
        if not ai_status.get("claude", {}).get("healthy", False):
            # Claude down is degraded, not fatal
            checks["ai_providers"]["claude_note"] = "degraded — using DeepSeek fallback"
    except Exception as e:
        checks["ai_providers"] = {"status": "error", "error": str(e)}

    status_code = 200 if all_healthy else 503
    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=status_code,
        content={
            "status": "ready" if all_healthy else "not_ready",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checks": checks,
        },
    )


@router.get("/health/live")
async def liveness_check():
    """
    Liveness probe — is the process responsive?
    If this fails, the orchestrator should restart the container.
    """
    return {"status": "alive", "pid": __import__("os").getpid()}
