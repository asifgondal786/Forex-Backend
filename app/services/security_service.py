"""
Phase 14 — Security Service
Handles: TOTP 2FA, trusted device registry, trade confirmation tokens
"""

import pyotp
import qrcode
import io
import base64
import hashlib
import secrets
import uuid
from datetime import datetime, timedelta
from typing import Optional

from app.core.supabase_client import supabase
from app.core.config import settings


# ─────────────────────────────────────────────
# 2FA — TOTP (Google Authenticator compatible)
# ─────────────────────────────────────────────

def generate_totp_secret(user_id: str) -> dict:
    """
    Generate a new TOTP secret for a user.
    Stores it in Supabase user_2fa table (unverified until user confirms first code).
    Returns secret + QR code as base64 PNG.
    """
    secret = pyotp.random_base32()
    totp = pyotp.TOTP(secret)

    # Build otpauth URI for QR code
    provisioning_uri = totp.provisioning_uri(
        name=user_id,
        issuer_name=settings.APP_NAME  # e.g. "Tajir"
    )

    # Generate QR code image as base64
    qr = qrcode.make(provisioning_uri)
    buffer = io.BytesIO()
    qr.save(buffer, format="PNG")
    qr_base64 = base64.b64encode(buffer.getvalue()).decode("utf-8")

    # Upsert into Supabase — mark as NOT verified yet
    supabase.table("user_2fa").upsert({
        "user_id": user_id,
        "totp_secret": secret,
        "is_enabled": False,
        "created_at": datetime.utcnow().isoformat(),
    }).execute()

    return {
        "secret": secret,
        "qr_code_base64": qr_base64,
        "provisioning_uri": provisioning_uri,
    }


def verify_and_enable_2fa(user_id: str, code: str) -> bool:
    """
    Verify the TOTP code entered by user during setup.
    If valid, mark 2FA as enabled in Supabase.
    """
    result = supabase.table("user_2fa") \
        .select("totp_secret") \
        .eq("user_id", user_id) \
        .single() \
        .execute()

    if not result.data:
        return False

    secret = result.data["totp_secret"]
    totp = pyotp.TOTP(secret)

    if totp.verify(code, valid_window=1):  # ±30s window
        supabase.table("user_2fa").update({
            "is_enabled": True,
            "enabled_at": datetime.utcnow().isoformat(),
        }).eq("user_id", user_id).execute()
        return True

    return False


def verify_totp_code(user_id: str, code: str) -> bool:
    """
    Verify TOTP code at login time.
    Returns True if valid and 2FA is enabled for this user.
    """
    result = supabase.table("user_2fa") \
        .select("totp_secret, is_enabled") \
        .eq("user_id", user_id) \
        .single() \
        .execute()

    if not result.data or not result.data["is_enabled"]:
        return False

    secret = result.data["totp_secret"]
    totp = pyotp.TOTP(secret)
    return totp.verify(code, valid_window=1)


def is_2fa_enabled(user_id: str) -> bool:
    """Check if 2FA is enabled for a user."""
    result = supabase.table("user_2fa") \
        .select("is_enabled") \
        .eq("user_id", user_id) \
        .single() \
        .execute()

    return bool(result.data and result.data.get("is_enabled"))


def disable_2fa(user_id: str, code: str) -> bool:
    """Disable 2FA — requires valid TOTP code to confirm."""
    if not verify_totp_code(user_id, code):
        return False

    supabase.table("user_2fa").update({
        "is_enabled": False,
        "disabled_at": datetime.utcnow().isoformat(),
    }).eq("user_id", user_id).execute()
    return True


# ─────────────────────────────────────────────
# DEVICE VERIFICATION — Trusted Device Registry
# ─────────────────────────────────────────────

def _fingerprint_device(device_info: dict) -> str:
    """
    Create a stable fingerprint from device info dict.
    Uses: platform, model, os_version, app_version
    """
    raw = f"{device_info.get('platform', '')}" \
          f"{device_info.get('model', '')}" \
          f"{device_info.get('os_version', '')}" \
          f"{device_info.get('app_version', '')}"
    return hashlib.sha256(raw.encode()).hexdigest()


def register_trusted_device(user_id: str, device_info: dict, trust_days: int = 30) -> str:
    """
    Register a device as trusted for a user.
    Returns device_token to be stored on the device.
    """
    device_token = secrets.token_urlsafe(32)
    fingerprint = _fingerprint_device(device_info)
    expires_at = datetime.utcnow() + timedelta(days=trust_days)

    supabase.table("trusted_devices").insert({
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "device_token": device_token,
        "device_fingerprint": fingerprint,
        "device_name": device_info.get("model", "Unknown Device"),
        "platform": device_info.get("platform", "unknown"),
        "trusted_at": datetime.utcnow().isoformat(),
        "expires_at": expires_at.isoformat(),
        "is_active": True,
    }).execute()

    return device_token


def is_device_trusted(user_id: str, device_token: str, device_info: dict) -> bool:
    """
    Check if a device token is valid, not expired, and fingerprint matches.
    """
    result = supabase.table("trusted_devices") \
        .select("*") \
        .eq("user_id", user_id) \
        .eq("device_token", device_token) \
        .eq("is_active", True) \
        .single() \
        .execute()

    if not result.data:
        return False

    record = result.data

    # Check expiry
    expires_at = datetime.fromisoformat(record["expires_at"])
    if datetime.utcnow() > expires_at:
        return False

    # Check fingerprint matches
    expected_fingerprint = _fingerprint_device(device_info)
    if record["device_fingerprint"] != expected_fingerprint:
        return False

    return True


def revoke_device(user_id: str, device_token: str) -> bool:
    """Revoke a specific trusted device."""
    result = supabase.table("trusted_devices").update({
        "is_active": False,
        "revoked_at": datetime.utcnow().isoformat(),
    }).eq("user_id", user_id).eq("device_token", device_token).execute()

    return bool(result.data)


def revoke_all_devices(user_id: str) -> int:
    """Revoke all trusted devices for a user. Returns count revoked."""
    result = supabase.table("trusted_devices").update({
        "is_active": False,
        "revoked_at": datetime.utcnow().isoformat(),
    }).eq("user_id", user_id).eq("is_active", True).execute()

    return len(result.data) if result.data else 0


def list_trusted_devices(user_id: str) -> list:
    """List all active trusted devices for a user."""
    result = supabase.table("trusted_devices") \
        .select("id, device_name, platform, trusted_at, expires_at") \
        .eq("user_id", user_id) \
        .eq("is_active", True) \
        .execute()

    return result.data or []


# ─────────────────────────────────────────────
# TRADE CONFIRMATION TOKENS
# ─────────────────────────────────────────────

TRADE_TOKEN_TTL_MINUTES = 5  # Token expires in 5 minutes


def generate_trade_confirmation_token(user_id: str, trade_payload: dict) -> str:
    """
    Generate a one-time token for trade confirmation.
    Stores token + trade payload hash in Supabase.
    Returns the token to be sent to Flutter for display.
    """
    token = secrets.token_urlsafe(16)  # Short enough to display/type
    payload_hash = hashlib.sha256(str(trade_payload).encode()).hexdigest()
    expires_at = datetime.utcnow() + timedelta(minutes=TRADE_TOKEN_TTL_MINUTES)

    supabase.table("trade_confirmation_tokens").insert({
        "id": str(uuid.uuid4()),
        "user_id": user_id,
        "token": token,
        "trade_payload_hash": payload_hash,
        "expires_at": expires_at.isoformat(),
        "is_used": False,
        "created_at": datetime.utcnow().isoformat(),
    }).execute()

    return token


def confirm_trade_token(user_id: str, token: str, trade_payload: dict) -> bool:
    """
    Validate a trade confirmation token.
    - Must belong to user
    - Must not be used
    - Must not be expired
    - Trade payload hash must match (prevents token reuse on different trade)
    Marks token as used on success.
    """
    result = supabase.table("trade_confirmation_tokens") \
        .select("*") \
        .eq("user_id", user_id) \
        .eq("token", token) \
        .eq("is_used", False) \
        .single() \
        .execute()

    if not result.data:
        return False

    record = result.data

    # Check expiry
    expires_at = datetime.fromisoformat(record["expires_at"])
    if datetime.utcnow() > expires_at:
        return False

    # Check payload hash matches — prevents replay on a different trade
    expected_hash = hashlib.sha256(str(trade_payload).encode()).hexdigest()
    if record["trade_payload_hash"] != expected_hash:
        return False

    # Mark as used (one-time use)
    supabase.table("trade_confirmation_tokens").update({
        "is_used": True,
        "used_at": datetime.utcnow().isoformat(),
    }).eq("id", record["id"]).execute()

    return True


def cleanup_expired_tokens() -> int:
    """
    Delete expired trade tokens. Call this periodically via a scheduled task.
    Returns number of tokens deleted.
    """
    result = supabase.table("trade_confirmation_tokens") \
        .delete() \
        .lt("expires_at", datetime.utcnow().isoformat()) \
        .execute()

    return len(result.data) if result.data else 0