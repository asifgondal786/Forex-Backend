"""
Phase 14 â€” Security Router
All security-related API endpoints:
  /security/2fa/setup
  /security/2fa/verify
  /security/2fa/confirm-login
  /security/2fa/disable
  /security/2fa/status
  /security/devices/register
  /security/devices/check
  /security/devices/list
  /security/devices/revoke
  /security/devices/revoke-all
  /security/trade/generate-token
  /security/trade/confirm
"""

from fastapi import APIRouter, Depends, HTTPException, status
from app.auth import get_current_user   # your existing Firebase auth dependency
from app.models.model_security import (
    TwoFASetupResponse, TwoFAVerifyRequest, TwoFAVerifyResponse,
    TwoFAStatusResponse, TwoFADisableRequest,
    RegisterDeviceRequest, RegisterDeviceResponse,
    CheckDeviceRequest, CheckDeviceResponse,
    ListDevicesResponse, TrustedDeviceItem,
    RevokeDeviceRequest, RevokeDeviceResponse,
    GenerateTradeTokenRequest, GenerateTradeTokenResponse,
    ConfirmTradeRequest, ConfirmTradeResponse,
)
from app.services import security_service

router = APIRouter(prefix="/security", tags=["Security"])


# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# 2FA ENDPOINTS
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@router.post("/2fa/setup", response_model=TwoFASetupResponse)
async def setup_2fa(current_user: dict = Depends(get_current_user)):
    """
    Initiate 2FA setup for the authenticated user.
    Returns a QR code (base64 PNG) to scan with Google Authenticator.
    The user must then call /2fa/verify to activate 2FA.
    """
    user_id = current_user["uid"]
    data = security_service.generate_totp_secret(user_id)
    return TwoFASetupResponse(**data)


@router.post("/2fa/verify", response_model=TwoFAVerifyResponse)
async def verify_2fa_setup(
    body: TwoFAVerifyRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Confirm 2FA setup by submitting first TOTP code.
    This ENABLES 2FA on the account.
    """
    user_id = current_user["uid"]
    success = security_service.verify_and_enable_2fa(user_id, body.code)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid code. Please check your authenticator app and try again."
        )
    return TwoFAVerifyResponse(success=True, message="2FA enabled successfully.")


@router.post("/2fa/confirm-login", response_model=TwoFAVerifyResponse)
async def confirm_2fa_login(
    body: TwoFAVerifyRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Verify TOTP code at login time (after Firebase auth succeeds).
    Call this after Firebase sign-in if is_2fa_enabled returns True.
    """
    user_id = current_user["uid"]
    success = security_service.verify_totp_code(user_id, body.code)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid 2FA code."
        )
    return TwoFAVerifyResponse(success=True, message="2FA verified. Login approved.")


@router.get("/2fa/status", response_model=TwoFAStatusResponse)
async def get_2fa_status(current_user: dict = Depends(get_current_user)):
    """Check whether 2FA is enabled for the current user."""
    user_id = current_user["uid"]
    enabled = security_service.is_2fa_enabled(user_id)
    return TwoFAStatusResponse(
        is_enabled=enabled,
        message="2FA is enabled." if enabled else "2FA is not enabled."
    )


@router.post("/2fa/disable", response_model=TwoFAVerifyResponse)
async def disable_2fa(
    body: TwoFADisableRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Disable 2FA. Requires a valid TOTP code to confirm intent.
    """
    user_id = current_user["uid"]
    success = security_service.disable_2fa(user_id, body.code)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid code. 2FA was not disabled."
        )
    return TwoFAVerifyResponse(success=True, message="2FA disabled successfully.")


# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# DEVICE VERIFICATION ENDPOINTS
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@router.post("/devices/register", response_model=RegisterDeviceResponse)
async def register_device(
    body: RegisterDeviceRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Register a trusted device. Returns a device_token to store in
    flutter_secure_storage on the device. Send this token with future
    requests to skip 2FA on trusted devices.
    """
    user_id = current_user["uid"]
    token = security_service.register_trusted_device(
        user_id, body.device_info.dict(), body.trust_days
    )
    return RegisterDeviceResponse(
        device_token=token,
        expires_in_days=body.trust_days,
        message=f"Device trusted for {body.trust_days} days."
    )


@router.post("/devices/check", response_model=CheckDeviceResponse)
async def check_device(
    body: CheckDeviceRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Check if a device token is still valid and trusted.
    Flutter calls this on app launch to decide whether to prompt for 2FA.
    """
    user_id = current_user["uid"]
    trusted = security_service.is_device_trusted(
        user_id, body.device_token, body.device_info.dict()
    )
    return CheckDeviceResponse(
        is_trusted=trusted,
        message="Device is trusted." if trusted else "Device is not trusted. 2FA required."
    )


@router.get("/devices/list", response_model=ListDevicesResponse)
async def list_devices(current_user: dict = Depends(get_current_user)):
    """List all active trusted devices for the current user."""
    user_id = current_user["uid"]
    devices = security_service.list_trusted_devices(user_id)
    return ListDevicesResponse(
        devices=[TrustedDeviceItem(**d) for d in devices],
        count=len(devices)
    )


@router.post("/devices/revoke", response_model=RevokeDeviceResponse)
async def revoke_device(
    body: RevokeDeviceRequest,
    current_user: dict = Depends(get_current_user),
):
    """Revoke a specific trusted device by its token."""
    user_id = current_user["uid"]
    success = security_service.revoke_device(user_id, body.device_token)
    return RevokeDeviceResponse(
        success=success,
        message="Device revoked." if success else "Device not found."
    )


@router.post("/devices/revoke-all", response_model=RevokeDeviceResponse)
async def revoke_all_devices(current_user: dict = Depends(get_current_user)):
    """Revoke ALL trusted devices â€” useful if account is compromised."""
    user_id = current_user["uid"]
    count = security_service.revoke_all_devices(user_id)
    return RevokeDeviceResponse(
        success=True,
        message=f"Revoked {count} device(s). All sessions require 2FA now."
    )


# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# TRADE CONFIRMATION TOKEN ENDPOINTS
# â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

@router.post("/trade/generate-token", response_model=GenerateTradeTokenResponse)
async def generate_trade_token(
    body: GenerateTradeTokenRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Generate a one-time trade confirmation token.
    Call this BEFORE executing any trade.
    Flutter shows the token + trade details on a confirmation screen.
    Token expires in 5 minutes and is single-use.
    """
    user_id = current_user["uid"]
    token = security_service.generate_trade_confirmation_token(
        user_id, body.trade_payload.dict()
    )
    return GenerateTradeTokenResponse(token=token)


@router.post("/trade/confirm", response_model=ConfirmTradeResponse)
async def confirm_trade(
    body: ConfirmTradeRequest,
    current_user: dict = Depends(get_current_user),
):
    """
    Confirm a trade using the one-time token.
    The trade payload must exactly match what the token was generated for.
    On success, the actual trade execution endpoint should be called.
    """
    user_id = current_user["uid"]
    confirmed = security_service.confirm_trade_token(
        user_id, body.token, body.trade_payload.dict()
    )
    if not confirmed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid, expired, or already-used confirmation token."
        )
    return ConfirmTradeResponse(
        confirmed=True,
        message="Trade confirmed. Proceed with execution."
    )
