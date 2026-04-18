from __future__ import annotations

import argparse
import os
from dataclasses import dataclass, field
import json
from pathlib import Path
from typing import Mapping
from urllib.parse import urlparse

from dotenv import load_dotenv

from .index import AppConfig, load_config

_PLACEHOLDER_MARKERS = {
    "",
    "replace_me",
    "replace_with_brevo_api_key",
    "replace_with_firebase_web_api_key",
    "your_brevo_api_key",
    "your_firebase_web_api_key",
    "your_gemini_api_key",
    "your_base64_encoded_service_account_json",
}
_VALID_LOG_LEVELS = {"CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG", "NOTSET"}


def _is_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def _is_https_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme == "https" and bool(parsed.netloc)


def _host(value: str) -> str:
    return (urlparse(value).hostname or "").lower()


def _is_localhost(value: str) -> bool:
    return _host(value) in {"localhost", "127.0.0.1"}


def _split_csv(value: str) -> list[str]:
    return [item.strip() for item in (value or "").split(",") if item.strip()]


def _is_placeholder(value: str) -> bool:
    candidate = (value or "").strip().lower()
    if candidate in _PLACEHOLDER_MARKERS:
        return True
    return candidate.startswith("your_") or "replace_with_" in candidate


@dataclass(frozen=True)
class ValidationIssue:
    code: str
    message: str
    variable: str | None = None

    def as_dict(self) -> dict[str, str]:
        payload = {"code": self.code, "message": self.message}
        if self.variable:
            payload["variable"] = self.variable
        return payload


@dataclass
class ValidationResult:
    errors: list[ValidationIssue] = field(default_factory=list)
    warnings: list[ValidationIssue] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return len(self.errors) == 0

    def add_error(self, code: str, message: str, variable: str | None = None) -> None:
        self.errors.append(ValidationIssue(code=code, message=message, variable=variable))

    def add_warning(self, code: str, message: str, variable: str | None = None) -> None:
        self.warnings.append(ValidationIssue(code=code, message=message, variable=variable))

    def as_dict(self) -> dict[str, object]:
        return {
            "ok": self.ok,
            "error_count": len(self.errors),
            "warning_count": len(self.warnings),
            "errors": [issue.as_dict() for issue in self.errors],
            "warnings": [issue.as_dict() for issue in self.warnings],
        }


def _require_non_empty(
    result: ValidationResult,
    env: Mapping[str, str],
    key: str,
    *,
    code: str,
    message: str,
) -> None:
    if (env.get(key) or "").strip():
        return
    result.add_error(code=code, message=message, variable=key)


def validate_environment(environ: Mapping[str, str] | None = None) -> ValidationResult:
    env = dict(environ) if environ is not None else dict(os.environ)
    config: AppConfig = load_config(env)
    result = ValidationResult()

    required_common = [
        "FIREBASE_PROJECT_ID",
        "FRONTEND_APP_URL",
        "EMAIL_VERIFICATION_CONTINUE_URL",
        "PASSWORD_RESET_CONTINUE_URL",
        "EMAIL_PROVIDER",
    ]
    for key in required_common:
        _require_non_empty(
            result,
            env,
            key,
            code="missing_required_env",
            message=f"Missing required environment variable: {key}",
        )

    for key in [
        "FRONTEND_APP_URL",
        "EMAIL_VERIFICATION_CONTINUE_URL",
        "PASSWORD_RESET_CONTINUE_URL",
    ]:
        raw_value = (env.get(key) or "").strip()
        if not raw_value:
            continue
        if "forexcompanione5a28" in raw_value:
            result.add_error(
                code="frontend_domain_typo",
                message=f"{key} contains typo. Use forexcompanion-e5a28 (with hyphens).",
                variable=key,
            )
        if not _is_http_url(raw_value):
            result.add_error(
                code="invalid_url",
                message=f"{key} must be a valid http/https URL.",
                variable=key,
            )

    email_provider = config.email.provider
    if email_provider == "none":
        if config.runtime.is_production:
            result.add_error(
                code="email_provider_disabled",
                message="EMAIL_PROVIDER=none is not allowed in production.",
                variable="EMAIL_PROVIDER",
            )
        else:
            result.add_warning(
                code="email_provider_disabled",
                message="EMAIL_PROVIDER=none disables transactional email flows.",
                variable="EMAIL_PROVIDER",
            )
    elif email_provider == "brevo":
        _require_non_empty(
            result,
            env,
            "BREVO_FROM_EMAIL",
            code="missing_required_env",
            message="BREVO_FROM_EMAIL is required when EMAIL_PROVIDER=brevo.",
        )

    if config.runtime.is_production:
        if config.runtime.debug:
            result.add_error(
                code="debug_enabled_in_production",
                message="DEBUG must be false in production.",
                variable="DEBUG",
            )
        if config.security.cors_allow_all:
            result.add_error(
                code="cors_allow_all_in_production",
                message="CORS_ALLOW_ALL must be false in production.",
                variable="CORS_ALLOW_ALL",
            )
        if not config.security.auth_rate_limit_enabled:
            result.add_error(
                code="auth_rate_limit_disabled",
                message="AUTH_RATE_LIMIT_ENABLED must be true in production.",
                variable="AUTH_RATE_LIMIT_ENABLED",
            )
        if not config.security.rate_limit_enabled:
            result.add_error(
                code="rate_limit_disabled",
                message="RATE_LIMIT_ENABLED must be true in production.",
                variable="RATE_LIMIT_ENABLED",
            )
        if not config.security.enable_csp:
            result.add_warning(
                code="csp_disabled",
                message="ENABLE_CSP is disabled in production.",
                variable="ENABLE_CSP",
            )
        if not config.security.enable_hsts:
            result.add_warning(
                code="hsts_disabled",
                message="ENABLE_HSTS is disabled in production.",
                variable="ENABLE_HSTS",
            )
        for key in [
            "FIREBASE_API_KEY",
            "BREVO_API_KEY",
        ]:
            value = (env.get(key) or "").strip()
            if not value or _is_placeholder(value):
                result.add_error(
                    code="missing_required_secret",
                    message=f"{key} must be configured in production secrets.",
                    variable=key,
                )
        ai_routes_available = (env.get("AI_ROUTES_AVAILABLE") or "").strip().lower() == "true"
        gemini_value = (env.get("GEMINI_API_KEY") or "").strip()
        if ai_routes_available and (not gemini_value or _is_placeholder(gemini_value)):
            result.add_error(
                code="missing_required_secret",
                message="GEMINI_API_KEY is required when AI_ROUTES_AVAILABLE=true in production.",
                variable="GEMINI_API_KEY",
            )
        if config.firebase.require_firebase:
            has_admin_credential = any(
                (env.get(key) or "").strip()
                for key in [
                    "FIREBASE_SERVICE_ACCOUNT_JSON_B64",
                    "FIREBASE_SERVICE_ACCOUNT_JSON",
                    "FIREBASE_SERVICE_ACCOUNT_PATH",
                    "GOOGLE_APPLICATION_CREDENTIALS",
                ]
            )
            if not has_admin_credential:
                result.add_error(
                    code="missing_firebase_admin_credentials",
                    message=(
                        "REQUIRE_FIREBASE=true requires one of FIREBASE_SERVICE_ACCOUNT_JSON_B64, "
                        "FIREBASE_SERVICE_ACCOUNT_JSON, FIREBASE_SERVICE_ACCOUNT_PATH, "
                        "or GOOGLE_APPLICATION_CREDENTIALS."
                    ),
                )
        app_release = (env.get("APP_RELEASE") or "").strip()
        if not app_release:
            result.add_warning(
                code="missing_app_release",
                message="APP_RELEASE is not set; release tracking in monitoring will be limited.",
                variable="APP_RELEASE",
            )
        sentry_dsn = (env.get("SENTRY_DSN") or "").strip()
        if sentry_dsn and not _is_http_url(sentry_dsn):
            result.add_error(
                code="invalid_sentry_dsn",
                message="SENTRY_DSN must be a valid URL when configured.",
                variable="SENTRY_DSN",
            )

    origins = _split_csv(env.get("CORS_ORIGINS", ""))
    if config.frontend.app_url:
        origins.append(config.frontend.app_url)

    for origin in origins:
        if not _is_http_url(origin):
            result.add_error(
                code="invalid_cors_origin",
                message=f"Invalid CORS origin: {origin}",
                variable="CORS_ORIGINS",
            )
            continue
        if origin == "*":
            result.add_error(
                code="wildcard_cors_origin",
                message="Wildcard CORS origin is not allowed.",
                variable="CORS_ORIGINS",
            )
            continue
        if config.runtime.is_production and not _is_https_url(origin):
            if not (_is_localhost(origin) and config.security.cors_allow_localhost_in_production):
                result.add_error(
                    code="cors_origin_not_https",
                    message=f"CORS origin must use https in production: {origin}",
                    variable="CORS_ORIGINS",
                )

    log_level = (env.get("LOG_LEVEL") or "").strip().upper()
    if log_level and log_level not in _VALID_LOG_LEVELS:
        result.add_error(
            code="invalid_log_level",
            message=f"LOG_LEVEL must be one of: {', '.join(sorted(_VALID_LOG_LEVELS))}.",
            variable="LOG_LEVEL",
        )

    return result


def log_payload(result: ValidationResult) -> dict[str, object]:
    return {
        "event": "env_validation",
        **result.as_dict(),
    }


def _load_dotenv_for_cli() -> None:
    project_root = Path(__file__).resolve().parents[2]
    base_env = project_root / ".env"
    local_env = project_root / ".env.local"
    load_dotenv(dotenv_path=base_env, override=False)

    explicit_env = (
        (os.getenv("ENVIRONMENT") or "").strip().lower()
        or (os.getenv("NODE_ENV") or "").strip().lower()
    )
    if explicit_env:
        env_specific = project_root / f".env.{explicit_env}"
        env_specific_local = project_root / f".env.{explicit_env}.local"
        load_dotenv(dotenv_path=env_specific, override=True)
        load_dotenv(dotenv_path=env_specific_local, override=True)

    load_dotenv(dotenv_path=local_env, override=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate environment configuration.")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit with non-zero status when warnings are present.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print machine-readable JSON output.",
    )
    args = parser.parse_args()

    _load_dotenv_for_cli()
    result = validate_environment()
    payload = result.as_dict()
    if args.json:
        print(json.dumps(payload))
    else:
        print(f"Environment validation: ok={payload['ok']}")
        if result.errors:
            print("Errors:")
            for item in result.errors:
                print(f"  - [{item.code}] {item.message}")
        if result.warnings:
            print("Warnings:")
            for item in result.warnings:
                print(f"  - [{item.code}] {item.message}")

    if result.errors:
        return 1
    if args.strict and result.warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
