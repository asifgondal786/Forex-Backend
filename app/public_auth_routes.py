import asyncio
import os
from typing import Optional, Dict, Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from firebase_admin import auth as firebase_auth

from .services.mail_delivery_service import MailDeliveryService, sanitize_email, is_valid_email
from .utils.firestore_client import init_firebase


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


def _public_reset_message() -> str:
    return "If an account exists for this email, password reset instructions have been sent."


def _debug_enabled() -> bool:
    return (os.getenv("DEBUG") or "").strip().lower() in {"1", "true", "yes", "on"}


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


def _resolve_reset_continue_url() -> str:
    explicit = _normalize_base_url(os.getenv("PASSWORD_RESET_CONTINUE_URL") or "")
    if explicit:
        return explicit
    frontend_url = _normalize_base_url(os.getenv("FRONTEND_APP_URL") or "")
    if frontend_url:
        return frontend_url
    firebase_auth_domain = _normalize_base_url(os.getenv("FIREBASE_AUTH_DOMAIN") or "")
    if firebase_auth_domain:
        return firebase_auth_domain
    return ""


def _resolve_verification_continue_url() -> str:
    explicit = _normalize_base_url(os.getenv("EMAIL_VERIFICATION_CONTINUE_URL") or "")
    if explicit:
        return explicit
    frontend_url = _normalize_base_url(os.getenv("FRONTEND_APP_URL") or "")
    if frontend_url:
        return frontend_url
    firebase_auth_domain = _normalize_base_url(os.getenv("FIREBASE_AUTH_DOMAIN") or "")
    if firebase_auth_domain:
        return firebase_auth_domain
    return ""


def _should_retry_without_continue_url(exc: Exception) -> bool:
    reason = f"{getattr(exc, 'code', '')} {str(exc)}".lower()
    markers = [
        "invalid-continue-uri",
        "unauthorized-continue-uri",
        "missing-continue-uri",
        "continue uri",
        "continue_url",
        "dynamic link domain",
        "invalid dynamic link domain",
    ]
    return any(marker in reason for marker in markers)


def _generate_reset_link(email: str) -> str:
    init_firebase()
    continue_url = _resolve_reset_continue_url()
    if continue_url:
        settings = firebase_auth.ActionCodeSettings(
            url=continue_url,
            handle_code_in_app=False,
        )
        try:
            return firebase_auth.generate_password_reset_link(email, settings)
        except Exception as exc:
            if not _should_retry_without_continue_url(exc):
                raise
            print(
                f"[AUTH] Reset link generation with continue_url failed, retrying without continue_url: {exc}"
            )
    return firebase_auth.generate_password_reset_link(email)


def _generate_verification_link(email: str) -> str:
    init_firebase()
    continue_url = _resolve_verification_continue_url()
    if continue_url:
        settings = firebase_auth.ActionCodeSettings(
            url=continue_url,
            handle_code_in_app=False,
        )
        try:
            return firebase_auth.generate_email_verification_link(email, settings)
        except Exception as exc:
            if not _should_retry_without_continue_url(exc):
                raise
            print(
                f"[AUTH] Verification link generation with continue_url failed, retrying without continue_url: {exc}"
            )
    return firebase_auth.generate_email_verification_link(email)


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

    # Avoid user enumeration by returning a generic response for unknown users.
    try:
        reset_link = await asyncio.to_thread(_generate_reset_link, email)
    except firebase_auth.UserNotFoundError:
        print(f"[AUTH] Password reset requested for unknown email: {email}")
        debug_payload = {"result": "user_not_found"} if _debug_enabled() else None
        return PasswordResetResponse(
            success=True,
            message=_public_reset_message(),
            debug=debug_payload,
        )
    except Exception as exc:
        print(f"[AUTH] Password reset link generation failed for {email}: {exc}")
        raise HTTPException(
            status_code=500,
            detail="Unable to generate password reset link right now.",
        )

    subject, text_body, html_body = _build_reset_email_content(reset_link)
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
        raise HTTPException(
            status_code=500,
            detail="Unable to send password reset email right now.",
        )

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

    try:
        verification_link = await asyncio.to_thread(_generate_verification_link, email)
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
        raise HTTPException(
            status_code=500,
            detail="Unable to generate verification link right now.",
        )

    subject, text_body, html_body = _build_verification_email_content(verification_link)
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
        raise HTTPException(
            status_code=500,
            detail="Unable to send verification email right now.",
        )

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
