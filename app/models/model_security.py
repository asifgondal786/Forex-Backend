"""
Phase 14 — Security Models
Pydantic models for all security-related API request/response payloads.
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ─────────────────────────────────────────────
# 2FA Models
# ─────────────────────────────────────────────

class TwoFASetupResponse(BaseModel):
    """Returned when user initiates 2FA setup."""
    secret: str
    qr_code_base64: str          # PNG QR code, base64 encoded — display in Flutter Image.memory()
    provisioning_uri: str        # For manual entry in authenticator apps
    message: str = "Scan QR code with Google Authenticator, then verify with a code."


class TwoFAVerifyRequest(BaseModel):
    """User submits TOTP code to confirm 2FA setup or verify at login."""
    code: str = Field(..., min_length=6, max_length=6, description="6-digit TOTP code")


class TwoFAVerifyResponse(BaseModel):
    success: bool
    message: str


class TwoFAStatusResponse(BaseModel):
    is_enabled: bool
    message: str


class TwoFADisableRequest(BaseModel):
    code: str = Field(..., min_length=6, max_length=6, description="6-digit TOTP code to confirm disable")


# ─────────────────────────────────────────────
# Device Verification Models
# ─────────────────────────────────────────────

class DeviceInfo(BaseModel):
    """Device metadata sent from Flutter."""
    platform: str               # "android" | "ios"
    model: str                  # e.g. "Samsung Galaxy S23"
    os_version: str             # e.g. "Android 14"
    app_version: str            # e.g. "1.0.0"


class RegisterDeviceRequest(BaseModel):
    device_info: DeviceInfo
    trust_days: int = Field(default=30, ge=1, le=90)


class RegisterDeviceResponse(BaseModel):
    device_token: str           # Store this securely in Flutter (flutter_secure_storage)
    expires_in_days: int
    message: str


class CheckDeviceRequest(BaseModel):
    device_token: str
    device_info: DeviceInfo


class CheckDeviceResponse(BaseModel):
    is_trusted: bool
    message: str


class TrustedDeviceItem(BaseModel):
    id: str
    device_name: str
    platform: str
    trusted_at: str
    expires_at: str


class ListDevicesResponse(BaseModel):
    devices: list[TrustedDeviceItem]
    count: int


class RevokeDeviceRequest(BaseModel):
    device_token: str


class RevokeDeviceResponse(BaseModel):
    success: bool
    message: str


# ─────────────────────────────────────────────
# Trade Confirmation Token Models
# ─────────────────────────────────────────────

class TradePayload(BaseModel):
    """The trade details that require confirmation before execution."""
    pair: str                       # e.g. "EURUSD"
    direction: str                  # "BUY" | "SELL"
    lot_size: float
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    strategy: Optional[str] = None


class GenerateTradeTokenRequest(BaseModel):
    trade_payload: TradePayload


class GenerateTradeTokenResponse(BaseModel):
    token: str                      # Show this to user in confirmation screen
    expires_in_minutes: int = 5
    message: str = "Confirm this token in the trade confirmation screen within 5 minutes."


class ConfirmTradeRequest(BaseModel):
    token: str
    trade_payload: TradePayload     # Must match exactly what token was generated for


class ConfirmTradeResponse(BaseModel):
    confirmed: bool
    message: str