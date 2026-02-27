"""
Phase 6: Production Monitoring Endpoints
Exposes metrics, health checks, and observability data
"""

from fastapi import APIRouter, Depends
from typing import Any, Dict, Optional
from datetime import datetime, timezone

from app.services.observability import (
    metrics_collector,
    health_checker,
    get_trace_context,
)
from app.security import get_current_user_id

router = APIRouter(prefix="/api/monitoring", tags=["Monitoring"])


@router.get("/metrics")
async def get_metrics(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    """
    Get comprehensive system metrics.
    
    Includes:
    - Request latency percentiles (p50, p95, p99)
    - Error rates
    - Cache performance
    - Database metrics
    - Per-endpoint statistics
    """
    return {
        "status": "success",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "metrics": metrics_collector.get_summary(),
    }


@router.get("/health")
async def health_check() -> Dict[str, Any]:
    """
    Detailed health check of all dependencies.
    
    Returns:
    - Health status of each service
    - Response time for each check
    - Overall readiness status
    """
    results = await health_checker.run_all_checks()
    
    return {
        "status": "success",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "ready": health_checker.is_ready(),
        "checks": results,
    }


@router.get("/health/ready")
async def readiness_probe() -> Dict[str, bool]:
    """
    Kubernetes-style readiness probe.
    
    Returns 200 if system is ready to accept traffic.
    """
    is_ready = health_checker.is_ready()
    return {
        "ready": is_ready,
    }


@router.get("/health/live")
async def liveness_probe() -> Dict[str, bool]:
    """
    Kubernetes-style liveness probe.
    
    Returns 200 if application is alive.
    """
    return {
        "alive": True,
    }


@router.get("/trace")
async def get_current_trace(
    user_id: str = Depends(get_current_user_id)
) -> Dict[str, Any]:
    """
    Get current request trace information.
    
    Useful for debugging request issues.
    """
    trace_ctx = get_trace_context()
    
    return {
        "status": "success",
        "trace": trace_ctx.to_dict(),
    }


@router.get("/endpoints")
async def get_endpoint_stats(
    user_id: str = Depends(get_current_user_id)
) -> Dict[str, Any]:
    """
    Get per-endpoint statistics.
    
    Returns:
    - Request count per endpoint
    - Average latency
    - Error rate
    - Last called timestamp
    """
    summary = metrics_collector.get_summary()
    
    return {
        "status": "success",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "endpoints": summary.get("endpoints", {}),
    }


@router.get("/performance")
async def get_performance_report(
    user_id: str = Depends(get_current_user_id)
) -> Dict[str, Any]:
    """
    Get comprehensive performance report.
    
    Includes:
    - Request latency breakdown
    - Cache efficiency
    - Database performance
    - Error analysis
    """
    summary = metrics_collector.get_summary()
    
    return {
        "status": "success",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "performance": {
            "request_latency_ms": summary.get("request_latency_ms", {}),
            "cache": summary.get("cache", {}),
            "database": summary.get("database", {}),
            "error_rate": summary.get("error_rate", 0),
        },
    }


@router.get("/diagnostics")
async def get_diagnostics(
    user_id: str = Depends(get_current_user_id)
) -> Dict[str, Any]:
    """
    Get full diagnostic information for troubleshooting.
    
    Combines:
    - Current metrics
    - Health checks
    - Performance statistics
    - Error information
    """
    summary = metrics_collector.get_summary()
    health = await health_checker.run_all_checks()
    trace_ctx = get_trace_context()
    
    return {
        "status": "success",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "system": {
            "total_requests": summary.get("total_requests", 0),
            "success_count": summary.get("success_count", 0),
            "error_count": summary.get("error_count", 0),
            "error_rate": summary.get("error_rate", 0),
        },
        "performance": {
            "request_latency_ms": summary.get("request_latency_ms", {}),
            "cache_hit_rate": summary.get("cache", {}).get("hit_rate", 0),
        },
        "dependencies": health,
        "ready": health_checker.is_ready(),
        "current_trace_id": trace_ctx.trace_id,
    }
