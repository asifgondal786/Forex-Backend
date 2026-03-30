import pyotp, qrcode, io, base64, os
from app.database import supabase

def generate_totp_secret(user_id: str) -> dict:
    secret = pyotp.random_base32()
    totp   = pyotp.TOTP(secret)
    uri    = totp.provisioning_uri(name=user_id, issuer_name="Tajir")
    qr     = qrcode.QRCode(version=1, box_size=6, border=2)
    qr.add_data(uri)
    qr.make(fit=True)
    img = qr.make_image(fill="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    qr_b64 = base64.b64encode(buf.getvalue()).decode()
    supabase.table("user_2fa").upsert({
        "user_id": user_id, "totp_secret": secret, "verified": False
    }).execute()
    return {"secret": secret, "qr_code": f"data:image/png;base64,{qr_b64}", "uri": uri}

def verify_totp(user_id: str, token: str) -> bool:
    row = supabase.table("user_2fa").select("totp_secret").eq("user_id", user_id).single().execute()
    if not row.data:
        return False
    valid = pyotp.TOTP(row.data["totp_secret"]).verify(token, valid_window=1)
    if valid:
        supabase.table("user_2fa").update({"verified": True}).eq("user_id", user_id).execute()
    return valid

def is_2fa_enabled(user_id: str) -> bool:
    row = supabase.table("user_2fa").select("verified").eq("user_id", user_id).single().execute()
    return bool(row.data and row.data.get("verified"))