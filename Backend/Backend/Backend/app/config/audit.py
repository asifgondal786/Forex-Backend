from __future__ import annotations

import hashlib
import json
import logging
from typing import Any

from .index import AppConfig, get_config, startup_snapshot

_AUDIT_LOGGER = logging.getLogger("config_audit")


def hash_config(config: AppConfig) -> str:
    """Hash a stable subset of config to detect unexpected runtime changes."""
    subset = {
        "environment": config.runtime.environment,
        "debug": config.runtime.debug,
        "validation_fail_fast": config.runtime.validation_fail_fast,
        "cors_allow_all": config.security.cors_allow_all,
        "auth_rate_limit_enabled": config.security.auth_rate_limit_enabled,
        "rate_limit_enabled": config.security.rate_limit_enabled,
        "enable_hsts": config.security.enable_hsts,
        "enable_csp": config.security.enable_csp,
        "email_provider": config.email.provider,
        "task_queue_enabled": config.features.task_queue_enabled,
        "task_queue_backend": config.features.task_queue_backend,
        "redis_enabled": config.features.redis_enabled,
    }
    raw = json.dumps(subset, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def build_config_snapshot(config: AppConfig | None = None) -> dict[str, Any]:
    active = config or get_config()
    payload = {
        "event": "config_snapshot",
        "config_hash": hash_config(active),
        "snapshot": startup_snapshot(active),
    }
    return payload


def log_config_snapshot(config: AppConfig | None = None) -> dict[str, Any]:
    payload = build_config_snapshot(config)
    _AUDIT_LOGGER.info(json.dumps(payload, ensure_ascii=True, sort_keys=True))
    return payload
