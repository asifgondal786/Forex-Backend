import hashlib, secrets
from datetime import datetime, timedelta
from app.database import supabase

def get_device_fingerprint(request) -> str:
    ua  = request.headers.get("user-agent", "")
    ip  = request.client.host
    return hashlib.sha256(f"{ip}:{ua}".encode()).hexdigest()[:32]

def is_known_device(user_id: str, fingerprint: str) -> bool:
    row = supabase.table("trusted_devices").select("id")\
        .eq("user_id", user_id).eq("fingerprint", fingerprint)\
        .eq("revoked", False).execute()
    return bool(row.data)

def send_device_otp(user_id: str, fingerprint: str, device_name: str) -> str:
    otp      = str(secrets.randbelow(900000) + 100000)
    otp_hash = hashlib.sha256(otp.encode()).hexdigest()
    expires  = (datetime.utcnow() + timedelta(minutes=10)).isoformat()
    supabase.table("device_otps").upsert({
        "user_id": user_id, "fingerprint": fingerprint,
        "device_name": device_name, "otp_hash": otp_hash,
        "expires_at": expires, "verified": False
    }).execute()
    return otp

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
        "user_id": user_id, "fingerprint": fingerprint,
        "device_name": row["device_name"], "revoked": False,
    }).execute()
    return True
