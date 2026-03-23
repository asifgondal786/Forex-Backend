from fastapi import APIRouter, Depends, HTTPException, Request
from app.services.totp_service import generate_totp_secret, verify_totp, is_2fa_enabled
from app.services.trade_token_service import generate_trade_token, consume_trade_token
from app.services.key_vault_service import store_broker_key, get_broker_key, delete_broker_key
from app.services.withdraw_service import request_withdrawal, confirm_withdrawal, cancel_withdrawal
from app.services.device_service import get_device_fingerprint, is_known_device, send_device_otp, verify_device_otp
from app.auth import get_current_user
from app.limiter import limiter

router = APIRouter(prefix="/api/v1/security", tags=["security"])

# --- 2FA ---
@router.post("/2fa/setup")
@limiter.limit("3/minute")
async def setup_2fa(request: Request, current_user=Depends(get_current_user)):
    return generate_totp_secret(str(current_user["uid"]))

@router.post("/2fa/verify-setup")
@limiter.limit("5/minute")
async def verify_2fa_setup(request: Request, body: dict, current_user=Depends(get_current_user)):
    if not verify_totp(str(current_user["uid"]), body.get("token", "")):
        raise HTTPException(400, "Invalid TOTP token")
    return {"message": "2FA enabled successfully"}

@router.post("/2fa/validate")
@limiter.limit("5/minute")
async def validate_2fa(request: Request, body: dict, current_user=Depends(get_current_user)):
    if not verify_totp(str(current_user["uid"]), body.get("token", "")):
        raise HTTPException(401, "Invalid 2FA token")
    return {"valid": True}

@router.get("/2fa/status")
async def get_2fa_status(current_user=Depends(get_current_user)):
    return {"enabled": is_2fa_enabled(str(current_user["uid"]))}

# --- Trade tokens ---
@router.post("/trade-token/generate")
@limiter.limit("30/minute")
async def gen_trade_token(request: Request, body: dict, current_user=Depends(get_current_user)):
    token = generate_trade_token(str(current_user["uid"]), body.get("trade_intent", {}))
    return {"token": token, "expires_in_seconds": 60}

@router.post("/trade-token/consume")
@limiter.limit("30/minute")
async def use_trade_token(request: Request, body: dict, current_user=Depends(get_current_user)):
    intent = consume_trade_token(str(current_user["uid"]), body.get("token", ""))
    if not intent:
        raise HTTPException(400, "Invalid, expired, or already used token")
    return {"valid": True, "trade_intent": intent}

# --- Broker key vault ---
@router.post("/vault/store")
@limiter.limit("10/minute")
async def store_key(request: Request, body: dict, current_user=Depends(get_current_user)):
    store_broker_key(str(current_user["uid"]), body["broker"], body["api_key"], body["api_secret"])
    return {"message": f"Keys for {body['broker']} stored securely"}

@router.get("/vault/{broker}")
async def get_key(broker: str, current_user=Depends(get_current_user)):
    keys = get_broker_key(str(current_user["uid"]), broker)
    if not keys:
        raise HTTPException(404, "No keys found for this broker")
    return {"broker": broker, "api_key_preview": keys["api_key"][:6] + "***"}

@router.delete("/vault/{broker}")
@limiter.limit("10/minute")
async def del_key(request: Request, broker: str, current_user=Depends(get_current_user)):
    delete_broker_key(str(current_user["uid"]), broker)
    return {"message": f"Keys for {broker} deleted"}

# --- Withdrawals ---
@router.post("/withdraw/request")
@limiter.limit("3/minute")
async def request_withdraw(request: Request, body: dict, current_user=Depends(get_current_user)):
    return request_withdrawal(str(current_user["uid"]), body["amount"], body["wallet_address"])

@router.get("/withdraw/confirm/{token}")
async def confirm_withdraw(token: str):
    try:
        return confirm_withdrawal(token)
    except ValueError as e:
        raise HTTPException(400, str(e))

@router.post("/withdraw/cancel")
@limiter.limit("5/minute")
async def cancel_withdraw(request: Request, body: dict, current_user=Depends(get_current_user)):
    return cancel_withdrawal(str(current_user["uid"]), body["request_id"])

# --- Device verification ---
@router.post("/device/check")
@limiter.limit("10/minute")
async def check_device(request: Request, current_user=Depends(get_current_user)):
    fp    = get_device_fingerprint(request)
    known = is_known_device(str(current_user["uid"]), fp)
    if not known:
        send_device_otp(str(current_user["uid"]), fp, request.headers.get("user-agent", "Unknown")[:60])
    return {"known_device": known, "fingerprint": fp,
            "message": None if known else "OTP sent to your email"}

@router.post("/device/verify-otp")
@limiter.limit("5/minute")
async def verify_device(request: Request, body: dict, current_user=Depends(get_current_user)):
    fp = get_device_fingerprint(request)
    if not verify_device_otp(str(current_user["uid"]), fp, body.get("otp", "")):
        raise HTTPException(400, "Invalid or expired OTP")
    return {"message": "Device verified and trusted"}
