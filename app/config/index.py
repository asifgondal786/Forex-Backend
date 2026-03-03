from __future__ import annotations

from dataclasses import dataclass
from functools import lru_cache
import os
from typing import Mapping
from urllib.parse import urlparse

_TRUE_VALUES = {"1", "true", "yes", "on"}


def _get(env: Mapping[str, str], key: str, default: str = "") -> str:
    value = env.get(key)
    return value.strip() if value is not None else default


def _env_bool(env: Mapping[str, str], key: str, default: bool = False) -> bool:
    value = env.get(key)
    if value is None:
        return default
    return value.strip().lower() in _TRUE_VALUES


def _env_int(env: Mapping[str, str], key: str, default: int, minimum: int = 1) -> int:
    value = env.get(key)
    if value is None:
        return default
    try:
        parsed = int(value.strip())
    except Exception:
        return default
    return parsed if parsed >= minimum else default


def _normalize_url(value: str) -> str:
    candidate = (value or "").strip()
    if not candidate:
        return ""
    if not candidate.startswith("http://") and not candidate.startswith("https://"):
        candidate = f"https://{candidate}"
    return candidate.rstrip("/")


def _split_csv(value: str) -> list[str]:
    return [item.strip() for item in (value or "").split(",") if item.strip()]


@dataclass(frozen=True)
class RuntimeConfig:
    environment: str
    node_env: str
    debug: bool
    validation_fail_fast: bool

    @property
    def is_production(self) -> bool:
        return self.environment in {"prod", "production"}

    @property
    def is_development(self) -> bool:
        return self.environment in {"dev", "development", "local", "test", "testing"}


@dataclass(frozen=True)
class FrontendConfig:
    app_url: str
    email_verification_continue_url: str
    password_reset_continue_url: str


@dataclass(frozen=True)
class FirebaseConfig:
    project_id: str
    api_key: str
    require_firebase: bool
    auth_domain_check_enabled: bool
    auth_domain_check_fail_fast: bool
    service_account_json_b64: str
    service_account_path: str
    google_application_credentials: str


@dataclass(frozen=True)
class EmailConfig:
    provider: str
    brevo_api_key: str
    brevo_from_email: str
    brevo_from_name: str
    brevo_reply_to: str


@dataclass(frozen=True)
class SecurityConfig:
    enable_csp: bool
    enable_hsts: bool
    cors_allow_all: bool
    cors_allow_localhost: bool
    cors_allow_localhost_in_production: bool
    cors_origins: tuple[str, ...]
    auth_rate_limit_enabled: bool
    auth_rate_limit_max: int
    auth_rate_limit_window_seconds: int
    rate_limit_enabled: bool
    rate_limit_max: int
    rate_limit_window_seconds: int


@dataclass(frozen=True)
class FeatureConfig:
    forex_stream_enabled: bool
    task_queue_enabled: bool
    task_queue_backend: str
    redis_enabled: bool
    ai_routes_available: bool


@dataclass(frozen=True)
class MonitoringConfig:
    sentry_dsn: str
    sentry_traces_sample_rate: float
    app_release: str
    log_level: str
    log_json: bool
    enable_file_logging: bool
    log_dir: str


@dataclass(frozen=True)
class AppConfig:
    runtime: RuntimeConfig
    frontend: FrontendConfig
    firebase: FirebaseConfig
    email: EmailConfig
    security: SecurityConfig
    features: FeatureConfig
    monitoring: MonitoringConfig


def load_config(environ: Mapping[str, str] | None = None) -> AppConfig:
    env = environ or os.environ
    debug = _env_bool(env, "DEBUG", False)
    explicit_env = _get(env, "ENVIRONMENT", "").lower()
    node_env = _get(env, "NODE_ENV", "").lower()
    environment = explicit_env or node_env or ("development" if debug else "production")
    explicit_runtime_mode = bool(explicit_env or node_env)

    runtime = RuntimeConfig(
        environment=environment,
        node_env=node_env or environment,
        debug=debug,
        validation_fail_fast=_env_bool(
            env,
            "CONFIG_VALIDATION_FAIL_FAST",
            environment in {"prod", "production"} and explicit_runtime_mode,
        ),
    )
    frontend = FrontendConfig(
        app_url=_normalize_url(_get(env, "FRONTEND_APP_URL", "")),
        email_verification_continue_url=_normalize_url(
            _get(env, "EMAIL_VERIFICATION_CONTINUE_URL", "")
        ),
        password_reset_continue_url=_normalize_url(
            _get(env, "PASSWORD_RESET_CONTINUE_URL", "")
        ),
    )
    firebase = FirebaseConfig(
        project_id=_get(env, "FIREBASE_PROJECT_ID", ""),
        api_key=_get(env, "FIREBASE_API_KEY", ""),
        require_firebase=_env_bool(env, "REQUIRE_FIREBASE", False),
        auth_domain_check_enabled=_env_bool(env, "FIREBASE_AUTH_DOMAIN_CHECK_ENABLED", True),
        auth_domain_check_fail_fast=_env_bool(
            env,
            "FIREBASE_AUTH_DOMAIN_CHECK_FAIL_FAST",
            not debug,
        ),
        service_account_json_b64=_get(env, "FIREBASE_SERVICE_ACCOUNT_JSON_B64", ""),
        service_account_path=_get(env, "FIREBASE_SERVICE_ACCOUNT_PATH", ""),
        google_application_credentials=_get(env, "GOOGLE_APPLICATION_CREDENTIALS", ""),
    )
    email = EmailConfig(
        provider=_get(env, "EMAIL_PROVIDER", "auto").lower(),
        brevo_api_key=_get(env, "BREVO_API_KEY", ""),
        brevo_from_email=_get(env, "BREVO_FROM_EMAIL", ""),
        brevo_from_name=_get(env, "BREVO_FROM_NAME", ""),
        brevo_reply_to=_get(env, "BREVO_REPLY_TO", ""),
    )
    security = SecurityConfig(
        enable_csp=_env_bool(env, "ENABLE_CSP", True),
        enable_hsts=_env_bool(env, "ENABLE_HSTS", not debug),
        cors_allow_all=_env_bool(env, "CORS_ALLOW_ALL", False),
        cors_allow_localhost=_env_bool(env, "CORS_ALLOW_LOCALHOST", debug),
        cors_allow_localhost_in_production=_env_bool(
            env, "CORS_ALLOW_LOCALHOST_IN_PRODUCTION", False
        ),
        cors_origins=tuple(_split_csv(_get(env, "CORS_ORIGINS", ""))),
        auth_rate_limit_enabled=_env_bool(env, "AUTH_RATE_LIMIT_ENABLED", True),
        auth_rate_limit_max=_env_int(env, "AUTH_RATE_LIMIT_MAX", 10),
        auth_rate_limit_window_seconds=_env_int(env, "AUTH_RATE_LIMIT_WINDOW_SECONDS", 300),
        rate_limit_enabled=_env_bool(env, "RATE_LIMIT_ENABLED", True),
        rate_limit_max=_env_int(env, "RATE_LIMIT_MAX", 120),
        rate_limit_window_seconds=_env_int(env, "RATE_LIMIT_WINDOW_SECONDS", 60),
    )
    features = FeatureConfig(
        forex_stream_enabled=_env_bool(env, "FOREX_STREAM_ENABLED", False),
        task_queue_enabled=_env_bool(env, "TASK_QUEUE_ENABLED", False),
        task_queue_backend=_get(env, "TASK_QUEUE_BACKEND", "memory").lower(),
        redis_enabled=_env_bool(env, "REDIS_ENABLED", False),
        ai_routes_available=_env_bool(env, "AI_ROUTES_AVAILABLE", False),
    )
    traces_sample_rate_raw = _get(env, "SENTRY_TRACES_SAMPLE_RATE", "0.1")
    try:
        traces_sample_rate = float(traces_sample_rate_raw)
    except Exception:
        traces_sample_rate = 0.1
    if traces_sample_rate < 0:
        traces_sample_rate = 0.0
    if traces_sample_rate > 1:
        traces_sample_rate = 1.0
    monitoring = MonitoringConfig(
        sentry_dsn=_get(env, "SENTRY_DSN", ""),
        sentry_traces_sample_rate=traces_sample_rate,
        app_release=_get(env, "APP_RELEASE", ""),
        log_level=_get(env, "LOG_LEVEL", "INFO").upper(),
        log_json=_env_bool(env, "LOG_JSON", True),
        enable_file_logging=_env_bool(env, "ENABLE_FILE_LOGGING", True),
        log_dir=_get(env, "LOG_DIR", "logs"),
    )
    return AppConfig(
        runtime=runtime,
        frontend=frontend,
        firebase=firebase,
        email=email,
        security=security,
        features=features,
        monitoring=monitoring,
    )


@lru_cache(maxsize=1)
def get_config() -> AppConfig:
    return load_config()


def _redact(value: str, keep: int = 4) -> str:
    raw = (value or "").strip()
    if not raw:
        return ""
    if len(raw) <= keep:
        return "*" * len(raw)
    return f"{raw[:keep]}***"


def startup_snapshot(config: AppConfig) -> dict[str, object]:
    return {
        "environment": config.runtime.environment,
        "debug": config.runtime.debug,
        "validation_fail_fast": config.runtime.validation_fail_fast,
        "email_provider": config.email.provider,
        "frontend_app_url": config.frontend.app_url,
        "password_reset_continue_url": config.frontend.password_reset_continue_url,
        "email_verification_continue_url": config.frontend.email_verification_continue_url,
        "csp_enabled": config.security.enable_csp,
        "hsts_enabled": config.security.enable_hsts,
        "has_brevo_api_key": bool(config.email.brevo_api_key),
        "has_firebase_api_key": bool(config.firebase.api_key),
        "firebase_project_id": config.firebase.project_id,
        "firebase_auth_domain_check_enabled": config.firebase.auth_domain_check_enabled,
        "firebase_auth_domain_check_fail_fast": config.firebase.auth_domain_check_fail_fast,
        "has_service_account_json_b64": bool(config.firebase.service_account_json_b64),
        "redacted_service_account_path": _redact(config.firebase.service_account_path, keep=8),
        "redacted_google_application_credentials": _redact(
            config.firebase.google_application_credentials,
            keep=8,
        ),
        "auth_rate_limit_enabled": config.security.auth_rate_limit_enabled,
        "rate_limit_enabled": config.security.rate_limit_enabled,
        "task_queue_enabled": config.features.task_queue_enabled,
        "task_queue_backend": config.features.task_queue_backend,
        "redis_enabled": config.features.redis_enabled,
        "sentry_configured": bool(config.monitoring.sentry_dsn),
        "app_release": config.monitoring.app_release,
        "log_level": config.monitoring.log_level,
        "log_json": config.monitoring.log_json,
        "enable_file_logging": config.monitoring.enable_file_logging,
    }
