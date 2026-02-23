import asyncio
import os
from typing import Optional, Dict, Any
import json
from urllib.parse import urlparse, parse_qs, unquote, urlencode

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from firebase_admin import auth as firebase_auth
import aiohttp

from .services.mail_delivery_service import (
    MailDeliveryService,
    MailDeliveryError,
    sanitize_email,
    is_valid_email,
)
from .utils.firestore_client import init_firebase, get_firebase_config_status


router = APIRouter(prefix="/auth", tags=["Public Auth"])
mailer = MailDeliveryService()


class PasswordResetRequest(BaseModel):
    email: EmailStr


class PasswordResetResponse(BaseModel):
    success: bool
    message: str
    debug: Optional[Dict[str, Any]] = None


class EmailVerificationRequest(BaseModel):
    email: EmailStr


class EmailVerificationResponse(BaseModel):
    success: bool
    message: str
    debug: Optional[Dict[str, Any]] = None


class EmailProviderStatusResponse(BaseModel):
    configured: bool
    provider: str
    sender: Optional[str] = None
    sender_verified: Optional[bool] = None
    sender_status: Optional[str] = None
    debug: Optional[Dict[str, Any]] = None


def _public_reset_message() -> str:
    return "If an account exists for this email, password reset instructions have been sent."


def _debug_enabled() -> bool:
    return (os.getenv("DEBUG") or "").strip().lower() in {"1", "true", "yes", "on"}


def _firebase_admin_credentials_available() -> bool:
    source = (get_firebase_config_status().get("credential_source") or "").strip().lower()
    return source in {"json_b64", "json", "path", "adc"}


def _build_reset_email_content(reset_link: str) -> tuple[str, str, str]:
    subject = "Reset your Forex Companion password"
    text = (
        "We received a request to reset your Forex Companion password.\n\n"
        f"Reset your password here:\n{reset_link}\n\n"
        "If you did not request this, you can safely ignore this email."
    )
    html = (
        "<p>We received a request to reset your <strong>Forex Companion</strong> password.</p>"
        f"<p><a href=\"{reset_link}\">Click here to reset your password</a></p>"
        "<p>If you did not request this, you can safely ignore this email.</p>"
    )
    return subject, text, html


def _build_verification_email_content(verification_link: str) -> tuple[str, str, str]:
    subject = "Verify your Forex Companion email"
    text = (
        "Welcome to Forex Companion.\n\n"
        "Please verify your email address using the link below:\n"
        f"{verification_link}\n\n"
        "If you did not create this account, you can ignore this email."
    )
    html = (
        "<p>Welcome to <strong>Forex Companion</strong>.</p>"
        "<p>Please verify your email address by using the link below:</p>"
        f"<p><a href=\"{verification_link}\">Verify Email Address</a></p>"
        "<p>If you did not create this account, you can ignore this email.</p>"
    )
    return subject, text, html


def _normalize_base_url(value: str) -> str:
    candidate = (value or "").strip()
    if not candidate:
        return ""
    if not candidate.startswith("http://") and not candidate.startswith("https://"):
        candidate = f"https://{candidate}"
    return candidate.rstrip("/")


def _is_debug_mode() -> bool:
    return _debug_enabled()


def _allow_http_redirects() -> bool:
    # In production redirects must be HTTPS.
    return _is_debug_mode()


def _frontend_use_hash_routes() -> bool:
    value = (os.getenv("FRONTEND_USE_HASH_ROUTES") or "true").strip().lower()
    return value in {"1", "true", "yes", "on"}


def _allowed_redirect_hosts() -> set[str]:
    hosts: set[str] = set()
    for key in ("FRONTEND_APP_URL",):
        value = _normalize_base_url(os.getenv(key) or "")
        if value:
            parsed = urlparse(value)
            if parsed.hostname:
                hosts.add(parsed.hostname.lower())
    extra = (os.getenv("REDIRECT_ALLOWLIST") or "").strip()
    if extra:
        for item in extra.split(","):
            parsed = urlparse(_normalize_base_url(item))
            if parsed.hostname:
                hosts.add(parsed.hostname.lower())
    if _is_debug_mode():
        hosts.update({"localhost", "127.0.0.1"})
    return hosts


def _assert_allowed_redirect_url(value: str, *, flow: str, expected_path: str) -> str:
    candidate = _normalize_base_url(value)
    if not candidate:
        raise RuntimeError(f"{flow} continue URL is missing.")

    parsed = urlparse(candidate)
    scheme = (parsed.scheme or "").lower()
    host = (parsed.hostname or "").lower()
    path = parsed.path or "/"

    if scheme not in {"http", "https"}:
        raise RuntimeError(f"{flow} continue URL has invalid scheme: {scheme}")
    if scheme != "https" and not _allow_http_redirects():
        raise RuntimeError(f"{flow} continue URL must use HTTPS in production.")
    if host not in _allowed_redirect_hosts():
        raise RuntimeError(f"{flow} continue URL host is not allowlisted: {host}")

    normalized_expected_path = expected_path if expected_path.startswith("/") else f"/{expected_path}"
    if normalized_expected_path != "/" and path.rstrip("/") != normalized_expected_path.rstrip("/"):
        raise RuntimeError(
            f"{flow} continue URL must use path '{normalized_expected_path}', got '{path}'."
        )
    return candidate


def _extract_continue_url_from_action_link(action_link: str) -> str:
    parsed = urlparse(action_link or "")
    params = parse_qs(parsed.query or "")
    value = params.get("continueUrl", [])
    if not value:
        return ""
    return unquote(value[0] or "").strip()


def _log_redirect_event(*, event: str, flow: str, continue_url: str, action_link: str = "") -> None:
    payload = {
        "event": event,
        "flow": flow,
        "continue_host": urlparse(continue_url).hostname,
        "continue_path": urlparse(continue_url).path or "/",
    }
    if action_link:
        parsed = urlparse(action_link)
        payload["action_link_host"] = parsed.hostname
        payload["action_link_path"] = parsed.path or "/"
        payload["action_link_fragment"] = parsed.fragment or ""
    print(json.dumps(payload))


def _assert_action_link_redirect(action_link: str, *, flow: str, expected_path: str) -> None:
    continue_url = _extract_continue_url_from_action_link(action_link)
    if not continue_url:
        raise RuntimeError(f"{flow} action link missing continueUrl.")
    validated = _assert_allowed_redirect_url(
        continue_url,
        flow=flow,
        expected_path=expected_path,
    )
    _log_redirect_event(
        event="action_link_generated",
        flow=flow,
        continue_url=validated,
        action_link=action_link,
    )


def _build_frontend_action_url(
    *,
    action_link: str,
    flow: str,
    expected_path: str,
    expected_mode: str,
) -> str:
    parsed = urlparse(action_link or "")
    query = parse_qs(parsed.query or "")

    oob_code = (query.get("oobCode", [""])[0] or "").strip()
    mode = (query.get("mode", [expected_mode])[0] or expected_mode).strip()
    api_key = (query.get("apiKey", [""])[0] or "").strip()
    lang = (query.get("lang", [""])[0] or "").strip()

    if not oob_code:
        raise RuntimeError(f"{flow} action link missing oobCode.")
    if mode != expected_mode:
        raise RuntimeError(f"{flow} action link mode mismatch: expected {expected_mode}, got {mode}")

    if flow == "password_reset":
        continue_url = _resolve_reset_continue_url()
    else:
        continue_url = _resolve_verification_continue_url()

    base = _assert_allowed_redirect_url(
        continue_url,
        flow=flow,
        expected_path=expected_path,
    )
    base_parsed = urlparse(base)
    passthrough: Dict[str, str] = {
        "mode": mode,
        "oobCode": oob_code,
    }
    if api_key:
        passthrough["apiKey"] = api_key
    if lang:
        passthrough["lang"] = lang

    if _frontend_use_hash_routes():
        frontend_base = _normalize_base_url(os.getenv("FRONTEND_APP_URL") or "")
        if not frontend_base:
            raise RuntimeError("FRONTEND_APP_URL must be configured for hash-route action links.")

        validated = _assert_allowed_redirect_url(
            f"{frontend_base}{expected_path}",
            flow=flow,
            expected_path=expected_path,
        )
        frontend_parsed = urlparse(frontend_base)
        fragment_query = urlencode(passthrough, doseq=True)
        fragment_value = expected_path
        if fragment_query:
            fragment_value = f"{expected_path}?{fragment_query}"
        app_link = frontend_parsed._replace(
            path=frontend_parsed.path or "/",
            query="",
            fragment=fragment_value,
        ).geturl()
        _log_redirect_event(
            event="frontend_action_link_built",
            flow=flow,
            continue_url=validated,
            action_link=app_link,
        )
        return app_link

    merged_query = parse_qs(base_parsed.query or "")
    for key, value in passthrough.items():
        merged_query[key] = [value]
    final_query = urlencode(merged_query, doseq=True)
    app_link = base_parsed._replace(query=final_query).geturl()
    _log_redirect_event(
        event="frontend_action_link_built",
        flow=flow,
        continue_url=base,
        action_link=app_link,
    )
    return app_link


def _resolve_reset_continue_url() -> str:
    explicit = os.getenv("PASSWORD_RESET_CONTINUE_URL") or ""
    if explicit.strip():
        return _assert_allowed_redirect_url(explicit, flow="password_reset", expected_path="/reset")

    frontend_url = _normalize_base_url(os.getenv("FRONTEND_APP_URL") or "")
    if frontend_url:
        return _assert_allowed_redirect_url(
            f"{frontend_url}/reset",
            flow="password_reset",
            expected_path="/reset",
        )
    raise RuntimeError("PASSWORD_RESET_CONTINUE_URL or FRONTEND_APP_URL must be configured.")


def _resolve_verification_continue_url() -> str:
    explicit = os.getenv("EMAIL_VERIFICATION_CONTINUE_URL") or ""
    if explicit.strip():
        return _assert_allowed_redirect_url(
            explicit,
            flow="email_verification",
            expected_path="/verify",
        )

    frontend_url = _normalize_base_url(os.getenv("FRONTEND_APP_URL") or "")
    if frontend_url:
        return _assert_allowed_redirect_url(
            f"{frontend_url}/verify",
            flow="email_verification",
            expected_path="/verify",
        )
    raise RuntimeError("EMAIL_VERIFICATION_CONTINUE_URL or FRONTEND_APP_URL must be configured.")


def _is_too_many_attempts_error(exc: Exception) -> bool:
    reason = f"{getattr(exc, 'code', '')} {str(exc)}".lower()
    markers = [
        "too_many_attempts_try_later",
        "too-many-requests",
        "too many attempts",
        "quota exceeded",
    ]
    return any(marker in reason for marker in markers)


def _is_unauthorized_domain_error(exc: Exception) -> bool:
    reason = f"{getattr(exc, 'code', '')} {str(exc)}".lower()
    markers = [
        "unauthorized_domain",
        "unauthorized domain",
        "domain not allowlisted by project",
        "unauthorized-continue-uri",
    ]
    return any(marker in reason for marker in markers)


def _is_insufficient_permission_error(exc: Exception) -> bool:
    reason = f"{getattr(exc, 'code', '')} {str(exc)}".lower()
    markers = [
        "insufficient_permission",
        "permission_denied",
        "insufficient permission",
        "caller does not have permission",
    ]
    return any(marker in reason for marker in markers)


def _build_unauthorized_domain_error(
    *,
    flow: str,
    continue_url: str,
    exc: Exception,
) -> HTTPException:
    host = (urlparse(continue_url or "").hostname or "").strip().lower() or "unknown"
    detail = (
        f"Unable to generate {flow} link right now. Firebase Auth rejected continue URL domain "
        f"'{host}'. Add this domain under Firebase Console > Authentication > Settings > "
        "Authorized domains and retry."
    )
    if _debug_enabled():
        detail = f"{detail} ({exc})"
    return HTTPException(status_code=503, detail=detail)


def _build_insufficient_permission_error(*, flow: str, exc: Exception) -> HTTPException:
    detail = (
        f"Unable to generate {flow} link right now due to insufficient Firebase permissions. "
        "Verify Firebase Auth is enabled, API key restrictions allow Identity Toolkit, and "
        "service account has Firebase Admin access."
    )
    if _debug_enabled():
        detail = f"{detail} ({exc})"
    return HTTPException(status_code=503, detail=detail)


def _firebase_api_key() -> str:
    return (os.getenv("FIREBASE_API_KEY") or os.getenv("FIREBASE_WEB_API_KEY") or "").strip()


def _firebase_api_key_valid(value: str) -> bool:
    candidate = (value or "").strip()
    if not candidate:
        return False
    if candidate.lower().startswith("replace_with_"):
        return False
    # Firebase web API keys are expected to look like AIza...
    return candidate.startswith("AIza") and len(candidate) >= 30


def _auth_link_timeout_seconds() -> float:
    raw = (os.getenv("AUTH_LINK_TIMEOUT_SECONDS") or "").strip()
    if not raw:
        return 15.0
    try:
        parsed = float(raw)
    except Exception:
        return 15.0
    if parsed <= 0:
        return 15.0
    return parsed


def _has_password_reset_link_generator() -> bool:
    return _firebase_admin_credentials_available() or _firebase_api_key_valid(_firebase_api_key())


def _mail_delivery_http_error(exc: Exception, *, flow: str) -> HTTPException:
    if isinstance(exc, MailDeliveryError):
        provider_name = (exc.provider or "Email provider").strip().capitalize()
        if exc.category == "sender_not_verified":
            detail = (
                f"{provider_name} sender identity is not verified. "
                "Validate your sender/domain in the provider dashboard and retry."
            )
            if _debug_enabled():
                detail = f"{detail} ({exc})"
            return HTTPException(status_code=503, detail=detail)
        if exc.category == "rate_limited":
            return HTTPException(
                status_code=429,
                detail="Email provider is rate-limiting requests. Please wait a few minutes and retry.",
            )
        if exc.category == "auth_failed":
            detail = f"{provider_name} credentials are invalid or expired."
            if _debug_enabled():
                detail = f"{detail} ({exc})"
            return HTTPException(status_code=503, detail=detail)
        if exc.category == "invalid_recipient":
            return HTTPException(status_code=400, detail="Invalid recipient email.")
        detail = f"Unable to send {flow} email right now."
        if _debug_enabled():
            detail = f"{detail} ({exc})"
        return HTTPException(status_code=502, detail=detail)

    detail = f"Unable to send {flow} email right now."
    if _debug_enabled():
        detail = f"{detail} ({exc})"
    return HTTPException(status_code=500, detail=detail)


async def _generate_reset_link_via_rest(email: str) -> str:
    api_key = _firebase_api_key()
    if not _firebase_api_key_valid(api_key):
        raise RuntimeError("FIREBASE_API_KEY missing or invalid for REST fallback.")

    payload: Dict[str, Any] = {
        "requestType": "PASSWORD_RESET",
        "email": email,
        "returnOobLink": True,
    }
    continue_url = _resolve_reset_continue_url()
    if continue_url:
        payload["continueUrl"] = continue_url
        payload["canHandleCodeInApp"] = False

    url = f"https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key={api_key}"
    timeout = aiohttp.ClientTimeout(total=20)
    async with aiohttp.ClientSession(timeout=timeout) as session:
        async with session.post(url, json=payload) as response:
            body = await response.text()
            if response.status >= 400:
                try:
                    parsed = json.loads(body)
                    message = (
                        parsed.get("error", {}).get("message")
                        or parsed.get("error", {}).get("status")
                        or body
                    )
                except Exception:
                    message = body
                raise RuntimeError(f"REST sendOobCode failed ({response.status}): {message}")
            try:
                parsed = json.loads(body)
            except Exception as exc:
                raise RuntimeError(f"REST sendOobCode invalid JSON response: {body}") from exc
            link = str(parsed.get("oobLink") or "").strip()
            if not link:
                raise RuntimeError(f"REST sendOobCode missing oobLink in response: {body}")
            _assert_action_link_redirect(link, flow="password_reset", expected_path="/reset")
            return link


def _generate_reset_link(email: str) -> str:
    init_firebase()
    continue_url = _resolve_reset_continue_url()
    settings = firebase_auth.ActionCodeSettings(
        url=continue_url,
        handle_code_in_app=False,
    )
    link = firebase_auth.generate_password_reset_link(email, settings)
    _assert_action_link_redirect(link, flow="password_reset", expected_path="/reset")
    return link


def _generate_verification_link(email: str) -> str:
    init_firebase()
    continue_url = _resolve_verification_continue_url()
    settings = firebase_auth.ActionCodeSettings(
        url=continue_url,
        handle_code_in_app=False,
    )
    link = firebase_auth.generate_email_verification_link(email, settings)
    _assert_action_link_redirect(link, flow="email_verification", expected_path="/verify")
    return link


@router.get("/email-provider-status", response_model=EmailProviderStatusResponse)
async def email_provider_status():
    if not _debug_enabled():
        raise HTTPException(status_code=404, detail="Not found.")

    if not mailer.email_configured:
        return EmailProviderStatusResponse(
            configured=False,
            provider="none",
            sender=None,
            debug={"hint": "Configure Brevo, Mailjet, or SMTP environment variables."},
        )

    if mailer.brevo_configured:
        try:
            status = await mailer.check_brevo_status()
        except Exception as exc:
            status = {
                "provider": "brevo",
                "configured": True,
                "sender": mailer.brevo_from_email,
                "sender_status": "unknown",
                "sender_verified": False,
                "error": str(exc),
            }
        return EmailProviderStatusResponse(
            configured=True,
            provider="brevo",
            sender=mailer.brevo_from_email,
            sender_verified=status.get("sender_verified"),
            sender_status=status.get("sender_status"),
            debug=status if _debug_enabled() else None,
        )

    if mailer.mailjet_configured:
        try:
            status = await mailer.check_mailjet_sender_status()
        except Exception as exc:
            status = {
                "provider": "mailjet",
                "configured": True,
                "sender": mailer.mailjet_from_email,
                "sender_status": "unknown",
                "sender_verified": False,
                "error": str(exc),
            }
        return EmailProviderStatusResponse(
            configured=True,
            provider="mailjet",
            sender=mailer.mailjet_from_email,
            sender_verified=status.get("sender_verified"),
            sender_status=status.get("sender_status"),
            debug=status if _debug_enabled() else None,
        )

    return EmailProviderStatusResponse(
        configured=True,
        provider="smtp",
        sender=mailer.smtp_from,
        debug={"smtp_host": bool(mailer.smtp_host)} if _debug_enabled() else None,
    )


@router.post("/password-reset", response_model=PasswordResetResponse)
async def request_password_reset(payload: PasswordResetRequest):
    if not mailer.email_configured:
        raise HTTPException(
            status_code=503,
            detail="Password reset email provider is not configured.",
        )

    email = sanitize_email(payload.email)
    if not is_valid_email(email):
        raise HTTPException(status_code=400, detail="Invalid email.")

    if not _has_password_reset_link_generator():
        detail = (
            "Password reset link service is not configured. Set Firebase Admin credentials "
            "or a valid FIREBASE_API_KEY."
        )
        if not _debug_enabled():
            detail = "Password reset service is not configured."
        raise HTTPException(status_code=503, detail=detail)

    # Avoid user enumeration by returning a generic response for unknown users.
    try:
        reset_link = await asyncio.wait_for(
            asyncio.to_thread(_generate_reset_link, email),
            timeout=_auth_link_timeout_seconds(),
        )
    except firebase_auth.UserNotFoundError:
        print(f"[AUTH] Password reset requested for unknown email: {email}")
        debug_payload = {"result": "user_not_found"} if _debug_enabled() else None
        return PasswordResetResponse(
            success=True,
            message=_public_reset_message(),
            debug=debug_payload,
        )
    except Exception as exc:
        print(f"[AUTH] Password reset link generation failed for {email}: {exc!r}")
        if isinstance(exc, asyncio.TimeoutError):
            # Firebase Admin can be intermittently slow; try REST fallback before failing.
            print("[AUTH] Password reset admin link timed out; attempting REST fallback.")
        elif _is_unauthorized_domain_error(exc):
            continue_url = _resolve_reset_continue_url()
            raise _build_unauthorized_domain_error(
                flow="password reset",
                continue_url=continue_url,
                exc=exc,
            )
        elif _is_insufficient_permission_error(exc):
            raise _build_insufficient_permission_error(flow="password reset", exc=exc)
        try:
            reset_link = await _generate_reset_link_via_rest(email)
            print("[AUTH] Password reset link generated via REST fallback.")
        except Exception as rest_exc:
            reason = str(rest_exc).lower()
            if _is_unauthorized_domain_error(rest_exc):
                continue_url = _resolve_reset_continue_url()
                raise _build_unauthorized_domain_error(
                    flow="password reset",
                    continue_url=continue_url,
                    exc=rest_exc,
                )
            if _is_insufficient_permission_error(rest_exc):
                raise _build_insufficient_permission_error(
                    flow="password reset",
                    exc=rest_exc,
                )
            if (
                "api key not valid" in reason
                or "api_key_invalid" in reason
                or "missing or invalid for rest fallback" in reason
            ):
                detail = (
                    "FIREBASE_API_KEY is missing/invalid for password reset REST fallback."
                )
                if not _debug_enabled():
                    detail = "Password reset service is not configured."
                raise HTTPException(status_code=503, detail=detail)
            if _is_too_many_attempts_error(rest_exc):
                raise HTTPException(
                    status_code=429,
                    detail="Too many password reset attempts. Please wait a few minutes and try again.",
                )
            if "email_not_found" in reason or "user-not-found" in reason:
                debug_payload = {"result": "user_not_found"} if _debug_enabled() else None
                return PasswordResetResponse(
                    success=True,
                    message=_public_reset_message(),
                    debug=debug_payload,
                )
            debug_suffix = f" ({rest_exc})" if _debug_enabled() else ""
            raise HTTPException(
                status_code=500,
                detail=f"Unable to generate password reset link right now.{debug_suffix}",
            )

    frontend_reset_link = _build_frontend_action_url(
        action_link=reset_link,
        flow="password_reset",
        expected_path="/reset",
        expected_mode="resetPassword",
    )
    subject, text_body, html_body = _build_reset_email_content(frontend_reset_link)
    try:
        send_result = await mailer.send_email(
            to_email=email,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
        )
        print(
            f"[AUTH] Password reset email sent to {email} via "
            f"{send_result.get('provider', 'unknown')}"
        )
    except Exception as exc:
        print(f"[AUTH] Password reset email send failed for {email}: {exc}")
        raise _mail_delivery_http_error(exc, flow="password reset")

    debug_payload = None
    if _debug_enabled():
        debug_payload = {
            "result": "sent",
            "provider": send_result.get("provider", "unknown"),
            "status_code": send_result.get("status_code"),
        }
    return PasswordResetResponse(
        success=True,
        message=_public_reset_message(),
        debug=debug_payload,
    )


@router.post("/email-verification", response_model=EmailVerificationResponse)
async def request_email_verification(payload: EmailVerificationRequest):
    if not mailer.email_configured:
        raise HTTPException(
            status_code=503,
            detail="Email provider is not configured.",
        )

    email = sanitize_email(payload.email)
    if not is_valid_email(email):
        raise HTTPException(status_code=400, detail="Invalid email.")

    if not _firebase_admin_credentials_available():
        detail = (
            "Firebase Admin credentials are missing on backend. Configure "
            "FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON_B64."
        )
        if not _debug_enabled():
            detail = "Verification link service is not configured."
        raise HTTPException(status_code=503, detail=detail)

    try:
        verification_link = await asyncio.wait_for(
            asyncio.to_thread(_generate_verification_link, email),
            timeout=8,
        )
    except firebase_auth.UserNotFoundError:
        print(f"[AUTH] Verification requested for unknown email: {email}")
        debug_payload = {"result": "user_not_found"} if _debug_enabled() else None
        return EmailVerificationResponse(
            success=True,
            message="If an account exists for this email, verification instructions have been sent.",
            debug=debug_payload,
        )
    except Exception as exc:
        print(f"[AUTH] Verification link generation failed for {email}: {exc}")
        if isinstance(exc, asyncio.TimeoutError):
            raise HTTPException(
                status_code=504,
                detail="Verification link generation timed out on backend.",
            )
        if _is_unauthorized_domain_error(exc):
            continue_url = _resolve_verification_continue_url()
            raise _build_unauthorized_domain_error(
                flow="email verification",
                continue_url=continue_url,
                exc=exc,
            )
        if _is_insufficient_permission_error(exc):
            raise _build_insufficient_permission_error(flow="email verification", exc=exc)
        if _is_too_many_attempts_error(exc):
            # Keep UX smooth and avoid leaking operational details: if Firebase reports
            # too-many-attempts, treat it as a successful "already recently sent" outcome.
            debug_payload = {"result": "rate_limited"} if _debug_enabled() else None
            return EmailVerificationResponse(
                success=True,
                message=(
                    "A verification email was recently sent. "
                    "Please check inbox/spam and wait a few minutes before retrying."
                ),
                debug=debug_payload,
            )
        raise HTTPException(
            status_code=500,
            detail="Unable to generate verification link right now.",
        )

    frontend_verify_link = _build_frontend_action_url(
        action_link=verification_link,
        flow="email_verification",
        expected_path="/verify",
        expected_mode="verifyEmail",
    )
    subject, text_body, html_body = _build_verification_email_content(frontend_verify_link)
    try:
        send_result = await mailer.send_email(
            to_email=email,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
        )
        print(
            f"[AUTH] Verification email sent to {email} via "
            f"{send_result.get('provider', 'unknown')}"
        )
    except Exception as exc:
        print(f"[AUTH] Verification email send failed for {email}: {exc}")
        raise _mail_delivery_http_error(exc, flow="verification")

    debug_payload = None
    if _debug_enabled():
        debug_payload = {
            "result": "sent",
            "provider": send_result.get("provider", "unknown"),
            "status_code": send_result.get("status_code"),
        }
    return EmailVerificationResponse(
        success=True,
        message="Verification email sent. Please check inbox and spam folders.",
        debug=debug_payload,
    )
