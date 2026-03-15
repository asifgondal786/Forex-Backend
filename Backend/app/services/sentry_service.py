"""
Sentry error monitoring service for Tajir FastAPI backend.
Initialise once at startup via init_sentry().
"""
import os
import logging

logger = logging.getLogger(__name__)


def init_sentry() -> bool:
    """
    Initialise Sentry SDK.
    Returns True if initialised, False if SENTRY_DSN is not set (safe to skip).
    """
    dsn = os.getenv("SENTRY_DSN", "").strip()
    if not dsn:
        logger.warning("SENTRY_DSN not set — Sentry monitoring disabled.")
        return False

    import sentry_sdk
    from sentry_sdk.integrations.fastapi import FastApiIntegration
    from sentry_sdk.integrations.starlette import StarletteIntegration
    from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
    from sentry_sdk.integrations.redis import RedisIntegration
    from sentry_sdk.integrations.logging import LoggingIntegration

    environment = os.getenv("ENVIRONMENT", "production")

    sentry_logging = LoggingIntegration(
        level=logging.INFO,        # Capture INFO and above as breadcrumbs
        event_level=logging.ERROR, # Send ERROR and above as Sentry events
    )

    sentry_sdk.init(
        dsn=dsn,
        environment=environment,
        # Performance tracing — 20% of requests
        traces_sample_rate=0.2,
        # Profile 10% of sampled transactions
        profiles_sample_rate=0.1,
        integrations=[
            StarletteIntegration(transaction_style="endpoint"),
            FastApiIntegration(transaction_style="endpoint"),
            SqlalchemyIntegration(),
            RedisIntegration(),
            sentry_logging,
        ],
        # Strip PII from events
        send_default_pii=False,
        # Ignore noisy non-errors
        ignore_errors=[
            KeyboardInterrupt,
        ],
        before_send=_before_send,
    )

    logger.info(f"✅ Sentry initialised — environment={environment}")
    return True


def _before_send(event, hint):
    """
    Filter / enrich events before they reach Sentry.
    - Drop 422 Unprocessable Entity (normal validation noise)
    - Drop 404 Not Found
    - Scrub Authorization headers
    """
    # Drop expected HTTP errors that aren't real bugs
    if "exc_info" in hint:
        exc_type, exc_value, _ = hint["exc_info"]
        if hasattr(exc_value, "status_code"):
            if exc_value.status_code in (404, 422):
                return None  # Don't send to Sentry

    # Scrub sensitive headers
    request = event.get("request", {})
    headers = request.get("headers", {})
    for sensitive_key in ("authorization", "cookie", "x-api-key"):
        if sensitive_key in headers:
            headers[sensitive_key] = "[Filtered]"

    return event


def capture_exception(error: Exception, context: dict = None):
    """
    Manually capture an exception with optional context.
    Safe to call even when Sentry is not initialised.
    """
    try:
        import sentry_sdk
        with sentry_sdk.push_scope() as scope:
            if context:
                for key, value in context.items():
                    scope.set_extra(key, value)
            sentry_sdk.capture_exception(error)
    except Exception:
        logger.exception("Failed to capture exception in Sentry")


def set_user_context(user_id: str, email: str = None):
    """Call after auth to tag Sentry events with the current user (no PII by default)."""
    try:
        import sentry_sdk
        sentry_sdk.set_user({"id": user_id, "email": email or "redacted"})
    except Exception:
        pass