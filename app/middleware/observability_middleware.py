"""
Observability Middleware for FastAPI
Integrates distributed tracing, metrics, and error tracking
"""

from __future__ import annotations

import time
import json
from typing import Callable, Optional
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response
from starlette.types import ASGIApp

from app.services.observability import (
    TraceContext,
    set_trace_context,
    get_trace_context,
    metrics_collector,
    anomaly_detector,
)


class DistributedTracingMiddleware(BaseHTTPMiddleware):
    """Add distributed tracing headers and context to all requests."""
    
    async def dispatch(
        self, request: Request, call_next: Callable
    ) -> Response:
        # Extract trace context from headers or create new
        trace_id = request.headers.get(
            "x-trace-id",
            request.headers.get("X-Trace-ID")
        )
        parent_span_id = request.headers.get(
            "x-parent-span-id",
            request.headers.get("X-Parent-Span-ID")
        )
        
        trace_ctx = TraceContext(trace_id=trace_id)
        if parent_span_id:
            trace_ctx.parent_span_id = parent_span_id
        
        # Add request tags
        trace_ctx.add_tag("http.method", request.method)
        trace_ctx.add_tag("http.path", request.url.path)
        trace_ctx.add_tag("http.host", request.url.hostname)
        
        # Set in context
        set_trace_context(trace_ctx)
        
        # Process request
        start_time = time.monotonic()
        try:
            response = await call_next(request)
        except Exception as exc:
            # Log exception
            trace_ctx.add_log(
                f"Request failed: {exc}",
                level="error",
                exception_type=type(exc).__name__
            )
            raise
        finally:
            # Calculate latency
            duration_ms = (time.monotonic() - start_time) * 1000
            trace_ctx.add_tag("http.status_code", response.status_code)
            trace_ctx.add_tag("http.duration_ms", duration_ms)
            
            # Record metrics
            endpoint = f"{request.method} {request.url.path}"
            metrics_collector.record_request(
                endpoint=endpoint,
                latency_ms=duration_ms,
                status=response.status_code
            )
            
            # Check for anomalies
            anomaly = anomaly_detector.record_latency(duration_ms)
            if anomaly:
                trace_ctx.add_log(anomaly, level="warning")
            
            error_anomaly = anomaly_detector.record_error(
                1 if response.status_code >= 400 else 0
            )
            if error_anomaly:
                trace_ctx.add_log(error_anomaly, level="warning")
        
        # Add trace headers to response
        headers = trace_ctx.to_headers()
        for key, value in headers.items():
            response.headers[key] = value
        
        return response


class ErrorTrackingMiddleware(BaseHTTPMiddleware):
    """Track errors and collect error telemetry."""
    
    async def dispatch(
        self, request: Request, call_next: Callable
    ) -> Response:
        response = await call_next(request)
        
        # Track 4xx and 5xx errors
        if response.status_code >= 400:
            trace_ctx = get_trace_context()
            
            error_info = {
                "status": response.status_code,
                "method": request.method,
                "path": request.url.path,
                "timestamp": time.time(),
            }
            
            trace_ctx.add_log(
                f"Error {response.status_code}: {request.method} {request.url.path}",
                level="error",
                **error_info
            )
        
        return response


class MetricsMiddleware(BaseHTTPMiddleware):
    """Collect detailed metrics for each request."""
    
    async def dispatch(
        self, request: Request, call_next: Callable
    ) -> Response:
        # Record cache metrics if headers present
        if request.headers.get("x-cache") == "HIT":
            metrics_collector.record_cache_hit()
        else:
            metrics_collector.record_cache_miss()
        
        response = await call_next(request)
        
        return response


class RequestValidationMiddleware(BaseHTTPMiddleware):
    """Validate requests and add security context."""
    
    async def dispatch(
        self, request: Request, call_next: Callable
    ) -> Response:
        # Extract user info if authenticated
        auth_header = request.headers.get("authorization")
        if auth_header:
            trace_ctx = get_trace_context()
            trace_ctx.add_tag("auth.present", True)
        
        response = await call_next(request)
        
        return response


def inject_trace_context_headers(
    response_data: dict,
    trace_ctx: Optional[TraceContext] = None
) -> dict:
    """Inject trace context into response body for debugging."""
    if trace_ctx is None:
        trace_ctx = get_trace_context()
    
    # Add trace info to response in debug mode
    response_data["_trace"] = {
        "trace_id": trace_ctx.trace_id,
        "span_id": trace_ctx.span_id,
        "duration_ms": trace_ctx.duration_ms(),
    }
    
    return response_data
