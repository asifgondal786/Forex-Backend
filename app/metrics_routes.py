"""
metrics_routes.py — Prometheus-compatible metrics endpoint.
Exposes application metrics for monitoring dashboards (Grafana).
"""

import time
import logging
from collections import defaultdict
from datetime import datetime, timezone

from fastapi import APIRouter
from fastapi.responses import PlainTextResponse

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Metrics"])


class MetricsCollector:
    """Simple Prometheus-compatible metrics collector."""

    def __init__(self):
        self._counters: dict[str, float] = defaultdict(float)
        self._gauges: dict[str, float] = defaultdict(float)
        self._histograms: dict[str, list[float]] = defaultdict(list)
        self._start_time = time.time()

    def increment(self, name: str, value: float = 1.0, labels: dict = None):
        key = self._make_key(name, labels)
        self._counters[key] += value

    def set_gauge(self, name: str, value: float, labels: dict = None):
        key = self._make_key(name, labels)
        self._gauges[key] = value

    def observe(self, name: str, value: float, labels: dict = None):
        key = self._make_key(name, labels)
        self._histograms[key].append(value)
        # Keep last 1000 observations
        if len(self._histograms[key]) > 1000:
            self._histograms[key] = self._histograms[key][-1000:]

    def _make_key(self, name: str, labels: dict = None) -> str:
        if not labels:
            return name
        label_str = ",".join(f'{k}="{v}"' for k, v in sorted(labels.items()))
        return f"{name}{{{label_str}}}"

    def export_prometheus(self) -> str:
        """Export all metrics in Prometheus exposition format."""
        lines = []
        lines.append(f"# Tajir Backend Metrics")
        lines.append(f"# Generated at {datetime.now(timezone.utc).isoformat()}")
        lines.append("")

        # Uptime
        uptime = time.time() - self._start_time
        lines.append("# HELP tajir_uptime_seconds Time since process start")
        lines.append("# TYPE tajir_uptime_seconds gauge")
        lines.append(f"tajir_uptime_seconds {uptime:.1f}")
        lines.append("")

        # Counters
        for key, value in sorted(self._counters.items()):
            name = key.split("{")[0] if "{" in key else key
            lines.append(f"# TYPE {name} counter")
            lines.append(f"{key} {value}")
        lines.append("")

        # Gauges
        for key, value in sorted(self._gauges.items()):
            name = key.split("{")[0] if "{" in key else key
            lines.append(f"# TYPE {name} gauge")
            lines.append(f"{key} {value}")
        lines.append("")

        # Histograms (simplified — sum and count)
        for key, values in sorted(self._histograms.items()):
            if not values:
                continue
            name = key.split("{")[0] if "{" in key else key
            lines.append(f"# TYPE {name} summary")
            lines.append(f"{key}_count {len(values)}")
            lines.append(f"{key}_sum {sum(values):.4f}")
            if values:
                lines.append(f"{key}_avg {sum(values)/len(values):.4f}")
        lines.append("")

        return "\n".join(lines)


# Global metrics instance
metrics = MetricsCollector()


@router.get("/metrics", response_class=PlainTextResponse)
async def prometheus_metrics():
    """
    Prometheus scrape endpoint.
    Configure Prometheus to scrape this at /metrics every 15s.
    """
    return metrics.export_prometheus()


# ─── Convenience functions for use across the application ────────────────────

def record_request(method: str, path: str, status_code: int, duration_ms: float):
    """Record an HTTP request metric."""
    metrics.increment("tajir_http_requests_total", labels={
        "method": method,
        "path": path,
        "status": str(status_code),
    })
    metrics.observe("tajir_http_request_duration_ms", duration_ms, labels={
        "method": method,
        "path": path,
    })


def record_ai_request(model: str, task: str, success: bool, latency_ms: float):
    """Record an AI model request."""
    metrics.increment("tajir_ai_requests_total", labels={
        "model": model,
        "task": task,
        "success": str(success).lower(),
    })
    metrics.observe("tajir_ai_latency_ms", latency_ms, labels={"model": model})


def record_trade_execution(pair: str, direction: str, status: str):
    """Record a trade execution event."""
    metrics.increment("tajir_trades_total", labels={
        "pair": pair,
        "direction": direction,
        "status": status,
    })


def record_signal_generated(pair: str, confidence: float):
    """Record a signal generation."""
    metrics.increment("tajir_signals_generated_total", labels={"pair": pair})
    metrics.observe("tajir_signal_confidence", confidence)


def set_active_connections(count: int):
    """Set the current WebSocket connection count."""
    metrics.set_gauge("tajir_websocket_connections", count)


def set_open_positions(count: int):
    """Set the current number of open positions across all users."""
    metrics.set_gauge("tajir_open_positions_total", count)
