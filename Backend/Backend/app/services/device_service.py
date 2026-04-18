import asyncio
import hashlib
import secrets
from datetime import datetime, timedelta
from app.database import supabase
from app.services.mail_delivery_service import MailDeliveryService

_mail = MailDeliveryService()

def get_device_fingerprint(request) -> str:
    ua  = request.headers.get("user-agent", "")
    ip  = request.client.host
    return hashlib.sha256(f"{ip}:{ua}".encode()).hexdigest()[:32]

def is_known_device(user_id: str, fingerprint: str) -> bool:
    row = supabase.table("trusted_devices").select("id")\
        .eq("user_id", user_id).eq("fingerprint", fingerprint)\
        .eq("revoked", False).execute()
    return bool(row.data)

def send_device_otp(user_id: str, fingerprint: str, device_name: str, user_email: str) -> None:
    otp      = str(secrets.randbelow(900000) + 100000)
    otp_hash = hashlib.sha256(otp.encode()).hexdigest()
    expires  = (datetime.utcnow() + timedelta(minutes=10)).isoformat()
    supabase.table("device_otps").upsert({
        "user_id":     user_id,
        "fingerprint": fingerprint,
        "device_name": device_name,
        "otp_hash":    otp_hash,
        "expires_at":  expires,
        "verified":    False
    }).execute()

    subject   = "Your Forex Companion Device Verification Code"
    text_body = f"Your one-time verification code is: {otp}\n\nThis code expires in 10 minutes.\nIf you did not request this, please ignore this email."
    html_body = f"""
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:32px;background:#f9f9f9;border-radius:8px;">
      <h2 style="color:#1a1a2e;margin-bottom:8px;">Device Verification</h2>
      <p style="color:#444;font-size:15px;">Use the code below to verify your new device on <strong>Forex Companion</strong>.</p>
      <div style="background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:24px;text-align:center;margin:24px 0;">
        <span style="font-size:36px;font-weight:bold;letter-spacing:8px;color:#2563eb;">{otp}</span>
      </div>
      <p style="color:#888;font-size:13px;">This code expires in <strong>10 minutes</strong>.<br>If you did not request this, you can safely ignore this email.</p>
    </div>
    """

    try:
        asyncio.get_event_loop().run_until_complete(
            _mail.send_email(
                to_email=user_email,
                subject=subject,
                text_body=text_body,
                html_body=html_body,
            )
        )
    except RuntimeError:
        # Already inside a running event loop (FastAPI) — use create_task
        import asyncio as _asyncio
        loop = _asyncio.get_event_loop()
        loop.create_task(
            _mail.send_email(
                to_email=user_email,
                subject=subject,
                text_body=text_body,
                html_body=html_body,
            )
        )

def verify_device_otp(user_id: str, fingerprint: str, otp: str) -> bool:
    otp_hash = hashlib.sha256(otp.encode()).hexdigest()
    now      = datetime.utcnow().isoformat()
    rows = supabase.table("device_otps").select("*")\
        .eq("user_id", user_id).eq("fingerprint", fingerprint)\
        .eq("otp_hash", otp_hash).eq("verified", False)\
        .gt("expires_at", now).limit(1).execute()
    if not rows.data:
        return False
    row = rows.data[0]
    supabase.table("device_otps").update({"verified": True}).eq("id", row["id"]).execute()
    supabase.table("trusted_devices").insert({
        "user_id":     user_id,
        "fingerprint": fingerprint,
        "device_name": row["device_name"],
        "revoked":     False,
    }).execute()
    return True
