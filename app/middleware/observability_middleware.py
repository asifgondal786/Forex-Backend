"""
Observability Middleware for FastAPI
Integrates distributed tracing, metrics, and error tracking
"""

from __future__ import annotations

import time
from typing import Callable, Optional
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response, JSONResponse

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

        trace_ctx.add_tag("http.method", request.method)
        trace_ctx.add_tag("http.path", request.url.path)
        trace_ctx.add_tag("http.host", request.url.hostname)

        set_trace_context(trace_ctx)

        start_time = time.monotonic()
        response: Optional[Response] = None

        try:
            response = await call_next(request)
            return response
        except Exception as exc:
            trace_ctx.add_log(
                f"Request failed: {exc}",
                level="error",
                exception_type=type(exc).__name__
            )
            response = JSONResponse(status_code=500, content={"detail": "Internal server error"})
            return response
        finally:
            duration_ms = (time.monotonic() - start_time) * 1000
            status = getattr(response, "status_code", 500)

            trace_ctx.add_tag("http.status_code", status)
            trace_ctx.add_tag("http.duration_ms", duration_ms)

            endpoint = f"{request.method} {request.url.path}"
            metrics_collector.record_request(
                endpoint=endpoint,
                latency_ms=duration_ms,
                status=status,
            )

            anomaly = anomaly_detector.record_latency(duration_ms)
            if anomaly:
                trace_ctx.add_log(anomaly, level="warning")

            error_anomaly = anomaly_detector.record_error(1 if status >= 400 else 0)
            if error_anomaly:
                trace_ctx.add_log(error_anomaly, level="warning")

            if response is not None:
                headers = trace_ctx.to_headers()
                for key, value in headers.items():
                    try:
                        response.headers[key] = value
                    except Exception:
                        pass


class ErrorTrackingMiddleware(BaseHTTPMiddleware):
    """Track errors and collect error telemetry."""

    async def dispatch(
        self, request: Request, call_next: Callable
    ) -> Response:
        try:
            response = await call_next(request)
        except Exception:
            response = JSONResponse(status_code=500, content={"detail": "Internal server error"})

        if getattr(response, "status_code", 500) >= 400:
            trace_ctx = get_trace_context()
            status = getattr(response, "status_code", 500)
            error_info = {
                "status": status,
                "method": request.method,
                "path": request.url.path,
                "timestamp": time.time(),
            }
            trace_ctx.add_log(
                f"Error {status}: {request.method} {request.url.path}",
                level="error",
                **error_info
            )

        return response


class MetricsMiddleware(BaseHTTPMiddleware):
    """Collect detailed metrics for each request."""

    async def dispatch(
        self, request: Request, call_next: Callable
    ) -> Response:
        if request.headers.get("x-cache") == "HIT":
            metrics_collector.record_cache_hit()
        else:
            metrics_collector.record_cache_miss()

        try:
            response = await call_next(request)
        except Exception:
            response = JSONResponse(status_code=500, content={"detail": "Internal server error"})

        return response


class RequestValidationMiddleware(BaseHTTPMiddleware):
    """Validate requests and add security context."""

    async def dispatch(
        self, request: Request, call_next: Callable
    ) -> Response:
        auth_header = request.headers.get("authorization")
        if auth_header:
            trace_ctx = get_trace_context()
            trace_ctx.add_tag("auth.present", True)

        try:
            response = await call_next(request)
        except Exception:
            response = JSONResponse(status_code=500, content={"detail": "Internal server error"})

        return response


def inject_trace_context_headers(
    response_data: dict,
    trace_ctx: Optional[TraceContext] = None
) -> dict:
    if trace_ctx is None:
        trace_ctx = get_trace_context()

    response_data["_trace"] = {
        "trace_id": trace_ctx.trace_id,
        "span_id": trace_ctx.span_id,
        "duration_ms": trace_ctx.duration_ms(),
    }

    return response_data