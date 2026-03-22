import os
from cryptography.fernet import Fernet
from app.database import supabase

VAULT_KEY = os.environ.get("VAULT_ENCRYPTION_KEY", "")
fernet    = Fernet(VAULT_KEY.encode()) if VAULT_KEY else None

def _f():
    if not fernet:
        raise RuntimeError("VAULT_ENCRYPTION_KEY not set in environment")
    return fernet

def store_broker_key(user_id: str, broker: str, api_key: str, api_secret: str) -> None:
    f = _f()
    supabase.table("broker_keys").upsert({
        "user_id": user_id, "broker": broker,
        "encrypted_api_key":    f.encrypt(api_key.encode()).decode(),
        "encrypted_api_secret": f.encrypt(api_secret.encode()).decode(),
    }).execute()

def get_broker_key(user_id: str, broker: str) -> dict | None:
    f   = _f()
    row = supabase.table("broker_keys").select("encrypted_api_key,encrypted_api_secret")\
        .eq("user_id", user_id).eq("broker", broker).single().execute()
    if not row.data:
        return None
    return {
        "api_key":    f.decrypt(row.data["encrypted_api_key"].encode()).decode(),
        "api_secret": f.decrypt(row.data["encrypted_api_secret"].encode()).decode(),
    }

def delete_broker_key(user_id: str, broker: str) -> None:
    supabase.table("broker_keys").delete()\
        .eq("user_id", user_id).eq("broker", broker).execute()