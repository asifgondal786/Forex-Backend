import secrets, hashlib
from datetime import datetime, timedelta
from app.database import supabase

def generate_trade_token(user_id: str, trade_intent: dict) -> str:
    token      = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    expires    = (datetime.utcnow() + timedelta(seconds=60)).isoformat()
    supabase.table("trade_tokens").insert({
        "user_id": user_id, "token_hash": token_hash,
        "trade_intent": trade_intent, "used": False, "expires_at": expires
    }).execute()
    return token

def consume_trade_token(user_id: str, token: str) -> dict | None:
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    now        = datetime.utcnow().isoformat()
    rows = supabase.table("trade_tokens")\
        .select("*").eq("user_id", user_id).eq("token_hash", token_hash)\
        .eq("used", False).gt("expires_at", now).limit(1).execute()
    if not rows.data:
        return None
    row = rows.data[0]
    supabase.table("trade_tokens").update({"used": True, "used_at": now})\
        .eq("id", row["id"]).execute()
    return row["trade_intent"]
