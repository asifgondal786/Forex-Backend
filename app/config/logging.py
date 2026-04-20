from __future__ import annotations

import json
import logging
from logging.config import dictConfig
import os
from pathlib import Path
from typing import Any

_TRUE_VALUES = {"1", "true", "yes", "on"}


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in _TRUE_VALUES


def _env_int(name: str, default: int, minimum: int = 1) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        parsed = int(value.strip())
    except Exception:
        return default
    return parsed if parsed >= minimum else default


class JsonLogFormatter(logging.Formatter):
    """Structured JSON log formatter."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        for key in ("event", "request_id", "path", "status_code", "duration_ms"):
            if hasattr(record, key):
                payload[key] = getattr(record, key)
        return json.dumps(payload, ensure_ascii=True)


def setup_logging(force: bool = False) -> None:
    """Configure application logging once per process."""
    root = logging.getLogger()
    if root.handlers and not force:
        return

    log_level = (os.getenv("LOG_LEVEL") or "INFO").strip().upper()
    log_json = _env_bool("LOG_JSON", True)
    enable_file_logging = _env_bool("ENABLE_FILE_LOGGING", True)
    log_max_bytes = _env_int("LOG_MAX_BYTES", 5 * 1024 * 1024, minimum=1024)
    log_backup_count = _env_int("LOG_BACKUP_COUNT", 5, minimum=1)
    log_dir = Path((os.getenv("LOG_DIR") or "logs").strip() or "logs")
    app_log_file = (os.getenv("APP_LOG_FILE") or "app.log").strip() or "app.log"
    audit_log_file = (os.getenv("AUDIT_LOG_FILE") or "audit.log").strip() or "audit.log"

    if enable_file_logging:
        log_dir.mkdir(parents=True, exist_ok=True)

    formatter_name = "json" if log_json else "standard"
    config: dict[str, Any] = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "standard": {
                "format": "%(asctime)s %(levelname)s [%(name)s] %(message)s",
            },
            "json": {
                "()": "app.config.logging.JsonLogFormatter",
            },
        },
        "handlers": {
            "console": {
                "class": "logging.StreamHandler",
                "formatter": formatter_name,
                "level": log_level,
            },
        },
        "loggers": {
            "": {
                "handlers": ["console"],
                "level": log_level,
            },
            "audit": {
                "handlers": ["console"],
                "level": log_level,
                "propagate": False,
            },
            "rate_limit": {
                "handlers": ["console"],
                "level": log_level,
                "propagate": False,
            },
            "config_audit": {
                "handlers": ["console"],
                "level": log_level,
                "propagate": False,
            },
        },
    }
    if enable_file_logging:
        config["handlers"]["app_file"] = {
            "class": "logging.handlers.RotatingFileHandler",
            "formatter": formatter_name,
            "level": log_level,
            "filename": str(log_dir / app_log_file),
            "maxBytes": log_max_bytes,
            "backupCount": log_backup_count,
            "encoding": "utf-8",
        }
        config["handlers"]["audit_file"] = {
            "class": "logging.handlers.RotatingFileHandler",
            "formatter": formatter_name,
            "level": log_level,
            "filename": str(log_dir / audit_log_file),
            "maxBytes": log_max_bytes,
            "backupCount": log_backup_count,
            "encoding": "utf-8",
        }
        config["loggers"][""]["handlers"].append("app_file")
        config["loggers"]["audit"]["handlers"].append("audit_file")
        config["loggers"]["config_audit"]["handlers"].append("audit_file")

    dictConfig(config)
