"""
Production Monitoring & Observability Layer
Distributed tracing, metrics collection, and health checks
"""

from __future__ import annotations

import time
import uuid
from typing import Callable, Optional, Dict, Any
from datetime import datetime, timezone
from functools import wraps
import json


class TraceContext:
    """Distributed trace context for request correlation."""
    
    def __init__(self, trace_id: Optional[str] = None, span_id: Optional[str] = None):
        self.trace_id = trace_id or str(uuid.uuid4())
        self.span_id = span_id or str(uuid.uuid4())
        self.parent_span_id: Optional[str] = None
        self.start_time = time.monotonic()
        self.tags: Dict[str, Any] = {}
        self.logs: list[Dict[str, Any]] = []
    
    def duration_ms(self) -> float:
        """Get duration in milliseconds since trace start."""
        return (time.monotonic() - self.start_time) * 1000
    
    def add_tag(self, key: str, value: Any) -> None:
        """Add a tag to this trace."""
        self.tags[key] = value
    
    def add_log(self, message: str, level: str = "info", **kwargs) -> None:
        """Add a log entry to this trace."""
        self.logs.append({
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": level,
            "message": message,
            **kwargs
        })
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert trace to dictionary."""
        return {
            "trace_id": self.trace_id,
            "span_id": self.span_id,
            "parent_span_id": self.parent_span_id,
            "duration_ms": self.duration_ms(),
            "tags": self.tags,
            "logs": self.logs,
        }
    
    def to_headers(self) -> Dict[str, str]:
        """Convert trace to HTTP headers for propagation."""
        return {
            "X-Trace-ID": self.trace_id,
            "X-Span-ID": self.span_id,
            "X-Parent-Span-ID": self.parent_span_id or "",
        }


class MetricsCollector:
    """Collect request metrics for observability."""
    
    def __init__(self):
        self.metrics: Dict[str, list[float]] = {
            "request_latency_ms": [],
            "error_count": 0,
            "success_count": 0,
            "cache_hits": 0,
            "cache_misses": 0,
            "db_queries": 0,
            "db_query_time_ms": [],
            "websocket_connections": 0,
            "task_queue_size": 0,
        }
        self.endpoint_stats: Dict[str, Dict[str, Any]] = {}
    
    def record_request(self, endpoint: str, latency_ms: float, status: int) -> None:
        """Record a request metric."""
        self.metrics["request_latency_ms"].append(latency_ms)
        
        if status < 400:
            self.metrics["success_count"] += 1
        else:
            self.metrics["error_count"] += 1
        
        if endpoint not in self.endpoint_stats:
            self.endpoint_stats[endpoint] = {
                "total_requests": 0,
                "total_latency_ms": 0.0,
                "error_count": 0,
                "last_called": None,
                "p95_latency_ms": 0.0,
            }
        
        stats = self.endpoint_stats[endpoint]
        stats["total_requests"] += 1
        stats["total_latency_ms"] += latency_ms
        if status >= 400:
            stats["error_count"] += 1
        stats["last_called"] = datetime.now(timezone.utc).isoformat()
        
        # Calculate p95
        if len(self.metrics["request_latency_ms"]) >= 20:
            sorted_latencies = sorted(self.metrics["request_latency_ms"])
            p95_index = int(len(sorted_latencies) * 0.95)
            stats["p95_latency_ms"] = sorted_latencies[p95_index]
    
    def record_cache_hit(self) -> None:
        """Record a cache hit."""
        self.metrics["cache_hits"] += 1
    
    def record_cache_miss(self) -> None:
        """Record a cache miss."""
        self.metrics["cache_misses"] += 1
    
    def record_db_query(self, duration_ms: float) -> None:
        """Record a database query."""
        self.metrics["db_queries"] += 1
        self.metrics["db_query_time_ms"].append(duration_ms)
    
    def get_summary(self) -> Dict[str, Any]:
        """Get metrics summary."""
        latencies = self.metrics["request_latency_ms"]
        db_times = self.metrics["db_query_time_ms"]
        
        return {
            "total_requests": len(latencies),
            "success_count": self.metrics["success_count"],
            "error_count": self.metrics["error_count"],
            "error_rate": (
                self.metrics["error_count"] / len(latencies) 
                if latencies else 0
            ),
            "request_latency_ms": {
                "min": min(latencies) if latencies else 0,
                "max": max(latencies) if latencies else 0,
                "avg": sum(latencies) / len(latencies) if latencies else 0,
                "p50": sorted(latencies)[len(latencies)//2] if latencies else 0,
                "p95": sorted(latencies)[int(len(latencies)*0.95)] if latencies else 0,
                "p99": sorted(latencies)[int(len(latencies)*0.99)] if latencies else 0,
            },
            "cache": {
                "hits": self.metrics["cache_hits"],
                "misses": self.metrics["cache_misses"],
                "hit_rate": (
                    self.metrics["cache_hits"] / 
                    (self.metrics["cache_hits"] + self.metrics["cache_misses"])
                    if (self.metrics["cache_hits"] + self.metrics["cache_misses"]) > 0 
                    else 0
                ),
            },
            "database": {
                "total_queries": self.metrics["db_queries"],
                "avg_query_time_ms": (
                    sum(db_times) / len(db_times) if db_times else 0
                ),
                "slow_query_threshold_ms": 100,
            },
            "endpoints": self.endpoint_stats,
        }


class HealthChecker:
    """Check health of application dependencies."""
    
    def __init__(self):
        self.checks: Dict[str, Callable[[], bool]] = {}
        self.last_check: Dict[str, Dict[str, Any]] = {}
    
    def register_check(self, name: str, check_fn: Callable[[], bool]) -> None:
        """Register a health check."""
        self.checks[name] = check_fn
    
    async def run_all_checks(self) -> Dict[str, Dict[str, Any]]:
        """Run all health checks."""
        results = {}
        
        for name, check_fn in self.checks.items():
            start = time.monotonic()
            try:
                healthy = await check_fn() if hasattr(check_fn, '__await__') else check_fn()
                duration_ms = (time.monotonic() - start) * 1000
                
                results[name] = {
                    "healthy": healthy,
                    "duration_ms": duration_ms,
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
                self.last_check[name] = results[name]
            except Exception as exc:
                results[name] = {
                    "healthy": False,
                    "error": str(exc),
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
                self.last_check[name] = results[name]
        
        return results
    
    def is_ready(self) -> bool:
        """Check if all critical services are ready."""
        critical = {"firebase", "firestore"}
        
        for service in critical:
            if service in self.last_check:
                if not self.last_check[service].get("healthy"):
                    return False
        
        return True


class AnomalyDetector:
    """Detect anomalies in metric patterns."""
    
    def __init__(self, window_size: int = 100):
        self.window_size = window_size
        self.latency_history: list[float] = []
        self.error_history: list[int] = []
    
    def record_latency(self, latency_ms: float) -> Optional[str]:
        """Record latency and detect anomaly."""
        self.latency_history.append(latency_ms)
        if len(self.latency_history) > self.window_size:
            self.latency_history.pop(0)
        
        if len(self.latency_history) < 10:
            return None  # Not enough data
        
        avg = sum(self.latency_history) / len(self.latency_history)
        
        # If current latency is 3x the average, it's anomalous
        if latency_ms > avg * 3:
            return f"HIGH_LATENCY: {latency_ms}ms vs avg {avg:.1f}ms"
        
        return None
    
    def record_error(self, is_error: int) -> Optional[str]:
        """Record error and detect error spike."""
        self.error_history.append(is_error)
        if len(self.error_history) > self.window_size:
            self.error_history.pop(0)
        
        if len(self.error_history) < 10:
            return None
        
        error_rate = sum(self.error_history) / len(self.error_history)
        
        # If error rate exceeds 5%, flag it
        if error_rate > 0.05:
            return f"ERROR_SPIKE: {error_rate*100:.1f}% error rate"
        
        return None


# Global instances
trace_context: Optional[TraceContext] = None
metrics_collector = MetricsCollector()
health_checker = HealthChecker()
anomaly_detector = AnomalyDetector()


def get_trace_context() -> TraceContext:
    """Get current trace context."""
    global trace_context
    if trace_context is None:
        trace_context = TraceContext()
    return trace_context


def set_trace_context(ctx: TraceContext) -> None:
    """Set trace context."""
    global trace_context
    trace_context = ctx
