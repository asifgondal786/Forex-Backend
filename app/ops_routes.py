"""Operational status and readiness endpoints."""

from __future__ import annotations

import os
from collections import Counter
from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, Depends, Response
import httpx

from .enhanced_websocket_manager import ws_manager
from .forex_data_service import forex_service
from .security import get_current_user_id
from .services.task_queue_service import task_queue_service
from .utils.firestore_client import get_firebase_config_status

router = APIRouter(prefix="/api/ops", tags=["Ops"])
_alert_latch: dict[str, dict[str, Any]] = {}


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int, minimum: int = 0) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        parsed = int(value.strip())
    except Exception:
        return default
    return parsed if parsed >= minimum else default


def _env_float(name: str, default: float, minimum: float = 0.0) -> float:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        parsed = float(value.strip())
    except Exception:
        return default
    return parsed if parsed >= minimum else default


def _parse_iso(value: str) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value)
    except Exception:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _count_stale_connections(
    registry: dict[str, dict[str, Any]],
    stale_after_seconds: int,
) -> int:
    now = datetime.now(timezone.utc)
    stale = 0
    for item in registry.values():
        last_seen = _parse_iso(str(item.get("last_seen") or ""))
        if last_seen is None:
            continue
        age = (now - last_seen).total_seconds()
        if age >= stale_after_seconds:
            stale += 1
    return stale


async def _collect_ops_snapshot() -> dict[str, Any]:
    queue = task_queue_service.get_stats()
    registry = await ws_manager.get_task_registry_snapshot_async()
    stale_after_seconds = _env_int("OPS_ALERT_WS_STALE_SECONDS", 120, minimum=10)
    stale_connections = _count_stale_connections(
        registry,
        stale_after_seconds=stale_after_seconds,
    )
    websocket = {
        "total_connections": ws_manager.get_connection_count(),
        "tasks": list(ws_manager.active_connections.keys()),
        "registry_size": len(registry),
        "registry": registry,
        "stale_after_seconds": stale_after_seconds,
        "stale_connections": stale_connections,
        "forex_stream_running": ws_manager.is_forex_stream_running(),
        "forex_stream_interval_seconds": ws_manager.get_forex_stream_interval(),
    }
    forex = forex_service.get_runtime_stats()
    return {"queue": queue, "websocket": websocket, "forex": forex}


def _build_alerts(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    queue = snapshot["queue"]
    websocket = snapshot["websocket"]
    forex = snapshot["forex"]

    alerts: list[dict[str, Any]] = []

    queue_warn = _env_int("OPS_ALERT_QUEUE_DEPTH_WARN", 80, minimum=1)
    queue_crit = _env_int("OPS_ALERT_QUEUE_DEPTH_CRIT", 150, minimum=1)
    queue_failed_warn = _env_int("OPS_ALERT_QUEUE_FAILED_WARN", 1, minimum=1)
    ws_stale_warn = _env_int("OPS_ALERT_WS_STALE_COUNT_WARN", 1, minimum=1)
    forex_failure_warn = _env_int("OPS_ALERT_FOREX_FAILURE_STREAK_WARN", 3, minimum=1)
    forex_retry_warn = _env_int("OPS_ALERT_FOREX_RETRY_WARN_SECONDS", 20, minimum=1)

    queue_size = int(queue.get("queue_size") or 0)
    if queue_size >= queue_crit:
        alerts.append(
            {
                "id": "queue_depth_critical",
                "severity": "critical",
                "message": "Task queue depth is critical",
                "value": queue_size,
                "threshold": queue_crit,
            }
        )
    elif queue_size >= queue_warn:
        alerts.append(
            {
                "id": "queue_depth_warning",
                "severity": "warning",
                "message": "Task queue depth is high",
                "value": queue_size,
                "threshold": queue_warn,
            }
        )

    failed_count = int(queue.get("failed") or 0)
    if failed_count >= queue_failed_warn:
        alerts.append(
            {
                "id": "queue_failed_tasks",
                "severity": "warning",
                "message": "Queue has failed tasks",
                "value": failed_count,
                "threshold": queue_failed_warn,
            }
        )

    stale_connections = int(websocket.get("stale_connections") or 0)
    if stale_connections >= ws_stale_warn:
        alerts.append(
            {
                "id": "websocket_stale_connections",
                "severity": "warning",
                "message": "Stale websocket connections detected",
                "value": stale_connections,
                "threshold": ws_stale_warn,
            }
        )

    failure_streak = int(forex.get("rate_failure_streak") or 0)
    if failure_streak >= forex_failure_warn:
        alerts.append(
            {
                "id": "forex_rate_failure_streak",
                "severity": "warning",
                "message": "Forex rate source failure streak elevated",
                "value": failure_streak,
                "threshold": forex_failure_warn,
            }
        )

    retry_in = float(forex.get("next_rates_retry_in_seconds") or 0.0)
    if retry_in >= forex_retry_warn:
        alerts.append(
            {
                "id": "forex_retry_backoff_high",
                "severity": "warning",
                "message": "Forex retry backoff is high",
                "value": round(retry_in, 3),
                "threshold": forex_retry_warn,
            }
        )

    return alerts


def _severity_rank(severity: str) -> int:
    mapping = {"info": 1, "warning": 2, "critical": 3}
    return mapping.get((severity or "info").lower(), 1)


def _should_emit_webhook(alert: dict[str, Any]) -> bool:
    min_severity = os.getenv("OPS_ALERT_WEBHOOK_MIN_SEVERITY", "warning").strip().lower() or "warning"
    return _severity_rank(str(alert.get("severity") or "info")) >= _severity_rank(min_severity)


def _resolve_webhook_provider(url: str) -> str:
    explicit = os.getenv("OPS_ALERT_WEBHOOK_PROVIDER", "auto").strip().lower()
    if explicit and explicit != "auto":
        return explicit
    lowered = (url or "").lower()
    if "discord.com/api/webhooks" in lowered or "discordapp.com/api/webhooks" in lowered:
        return "discord"
    if "hooks.slack.com" in lowered:
        return "slack"
    return "generic"


def _build_webhook_payload(event_type: str, alert: dict[str, Any]) -> dict[str, Any]:
    title = str(alert.get("message") or alert.get("id") or "ops-alert")
    severity = str(alert.get("severity") or "info").upper()
    alert_id = str(alert.get("id") or "unknown")
    value = alert.get("value")
    threshold = alert.get("threshold")
    return {
        "event": "ops_alert",
        "event_type": event_type,
        "id": alert_id,
        "severity": str(alert.get("severity") or "info").lower(),
        "message": title,
        "value": value,
        "threshold": threshold,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "text": (
            f"[OPS_ALERT_{event_type.upper()}] "
            f"{severity} {alert_id}: {title} (value={value}, threshold={threshold})"
        ),
    }


async def _send_alert_webhook(event_type: str, alert: dict[str, Any]) -> None:
    url = (os.getenv("OPS_ALERT_WEBHOOK_URL") or "").strip()
    if not url or not _should_emit_webhook(alert):
        return

    provider = _resolve_webhook_provider(url)
    payload = _build_webhook_payload(event_type, alert)
    timeout = _env_float("OPS_ALERT_WEBHOOK_TIMEOUT_SECONDS", 5.0, minimum=0.1)
    headers = {}
    auth_header = (os.getenv("OPS_ALERT_WEBHOOK_AUTH_HEADER") or "").strip()
    auth_value = (os.getenv("OPS_ALERT_WEBHOOK_AUTH_VALUE") or "").strip()
    if auth_header and auth_value:
        headers[auth_header] = auth_value

    if provider == "discord":
        body: dict[str, Any] = {"content": payload["text"]}
    elif provider == "slack":
        body = {"text": payload["text"]}
    else:
        body = payload

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.post(url, json=body, headers=headers or None)
        if response.status_code >= 400:
            print(
                f"[OPS_ALERT_WEBHOOK] failed status={response.status_code} "
                f"provider={provider} id={alert.get('id')}"
            )
    except Exception as exc:
        print(
            f"[OPS_ALERT_WEBHOOK] failed provider={provider} id={alert.get('id')} error={exc}"
        )


async def _emit_alert_hooks(alerts: list[dict[str, Any]]) -> None:
    if not _env_bool("OPS_ALERT_HOOKS_ENABLED", True):
        return

    active_ids = {item["id"] for item in alerts}

    # New or still-active alerts
    for alert in alerts:
        alert_id = alert["id"]
        if alert_id not in _alert_latch:
            print(
                f"[OPS_ALERT] id={alert_id} severity={alert['severity']} "
                f"value={alert.get('value')} threshold={alert.get('threshold')} "
                f"message={alert.get('message')}"
            )
            await _send_alert_webhook("triggered", alert)
        _alert_latch[alert_id] = {
            "id": alert_id,
            "severity": alert.get("severity"),
            "message": alert.get("message"),
            "value": alert.get("value"),
            "threshold": alert.get("threshold"),
        }

    # Resolved alerts
    resolved = [alert_id for alert_id in _alert_latch.keys() if alert_id not in active_ids]
    for alert_id in resolved:
        print(f"[OPS_ALERT_RESOLVED] id={alert_id}")
        previous = _alert_latch.get(alert_id) or {"id": alert_id, "severity": "info"}
        await _send_alert_webhook("resolved", previous)
        _alert_latch.pop(alert_id, None)


def _to_prometheus(snapshot: dict[str, Any], alerts: list[dict[str, Any]]) -> str:
    queue = snapshot["queue"]
    websocket = snapshot["websocket"]
    forex = snapshot["forex"]

    lines = [
        "# HELP forex_backend_queue_started Queue service started (1=true,0=false)",
        "# TYPE forex_backend_queue_started gauge",
        f"forex_backend_queue_started {1 if queue.get('started') else 0}",
        "# HELP forex_backend_queue_size Current task queue size",
        "# TYPE forex_backend_queue_size gauge",
        f"forex_backend_queue_size {int(queue.get('queue_size') or 0)}",
        "# HELP forex_backend_queue_enqueued_total Total enqueued tasks",
        "# TYPE forex_backend_queue_enqueued_total counter",
        f"forex_backend_queue_enqueued_total {int(queue.get('enqueued') or 0)}",
        "# HELP forex_backend_queue_completed_total Total completed queued tasks",
        "# TYPE forex_backend_queue_completed_total counter",
        f"forex_backend_queue_completed_total {int(queue.get('completed') or 0)}",
        "# HELP forex_backend_queue_failed_total Total failed queued tasks",
        "# TYPE forex_backend_queue_failed_total counter",
        f"forex_backend_queue_failed_total {int(queue.get('failed') or 0)}",
        "# HELP forex_backend_websocket_connections_total Total active websocket connections",
        "# TYPE forex_backend_websocket_connections_total gauge",
        f"forex_backend_websocket_connections_total {int(websocket.get('total_connections') or 0)}",
        "# HELP forex_backend_websocket_registry_size Total tracked websocket connections in registry",
        "# TYPE forex_backend_websocket_registry_size gauge",
        f"forex_backend_websocket_registry_size {int(websocket.get('registry_size') or 0)}",
        "# HELP forex_backend_websocket_stale_connections Total stale websocket connections",
        "# TYPE forex_backend_websocket_stale_connections gauge",
        f"forex_backend_websocket_stale_connections {int(websocket.get('stale_connections') or 0)}",
        "# HELP forex_backend_forex_rate_failure_streak Consecutive forex rate source failures",
        "# TYPE forex_backend_forex_rate_failure_streak gauge",
        f"forex_backend_forex_rate_failure_streak {int(forex.get('rate_failure_streak') or 0)}",
        "# HELP forex_backend_forex_retry_backoff_seconds Current forex retry backoff seconds",
        "# TYPE forex_backend_forex_retry_backoff_seconds gauge",
        f"forex_backend_forex_retry_backoff_seconds {float(forex.get('next_rates_retry_in_seconds') or 0.0)}",
        "# HELP forex_backend_alerts_total Active ops alerts grouped by severity",
        "# TYPE forex_backend_alerts_total gauge",
    ]

    severity_counts = Counter(item.get("severity", "info") for item in alerts)
    for severity in ("critical", "warning", "info"):
        lines.append(
            f'forex_backend_alerts_total{{severity="{severity}"}} {severity_counts.get(severity, 0)}'
        )
    return "\n".join(lines) + "\n"


@router.get("/status")
async def ops_status(_user_id: str = Depends(get_current_user_id)):
    """Return live operational diagnostics for backend subsystems."""
    snapshot = await _collect_ops_snapshot()
    alerts = _build_alerts(snapshot)
    await _emit_alert_hooks(alerts)
    summary = Counter(item.get("severity", "info") for item in alerts)

    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "queue": snapshot["queue"],
        "websocket": snapshot["websocket"],
        "forex": snapshot["forex"],
        "alerts": alerts,
        "alert_summary": {
            "total": len(alerts),
            "critical": summary.get("critical", 0),
            "warning": summary.get("warning", 0),
            "info": summary.get("info", 0),
        },
    }


@router.get("/alerts")
async def ops_alerts(_user_id: str = Depends(get_current_user_id)):
    """Return active operational alerts based on runtime thresholds."""
    snapshot = await _collect_ops_snapshot()
    alerts = _build_alerts(snapshot)
    await _emit_alert_hooks(alerts)
    return {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "alerts": alerts,
        "total": len(alerts),
    }


@router.get("/readiness")
async def ops_readiness(_user_id: str = Depends(get_current_user_id)):
    """Return readiness status for critical runtime dependencies."""
    queue_required = _env_bool("TASK_QUEUE_ENABLED", True)
    require_firebase = _env_bool("REQUIRE_FIREBASE", False)
    firebase_status = get_firebase_config_status()
    firebase_configured = firebase_status.get("credential_source") != "none"

    checks = {
        "queue": {
            "required": queue_required,
            "ok": (task_queue_service.get_stats().get("started") is True) if queue_required else True,
        },
        "firebase": {
            "required": require_firebase,
            "ok": firebase_configured if require_firebase else True,
            "credential_source": firebase_status.get("credential_source"),
            "project_id": firebase_status.get("project_id"),
        },
        "websocket_manager": {
            "required": True,
            "ok": True,
            "forex_stream_running": ws_manager.is_forex_stream_running(),
        },
    }

    ready = all(bool(item.get("ok")) for item in checks.values())
    return {
        "ready": ready,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "checks": checks,
    }


@router.get("/metrics")
async def ops_metrics(_user_id: str = Depends(get_current_user_id)):
    """Return Prometheus-compatible metrics text."""
    snapshot = await _collect_ops_snapshot()
    alerts = _build_alerts(snapshot)
    await _emit_alert_hooks(alerts)
    body = _to_prometheus(snapshot, alerts)
    return Response(
        content=body,
        media_type="text/plain; version=0.0.4; charset=utf-8",
    )
