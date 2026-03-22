import secrets
from datetime import datetime, timedelta
from app.database import supabase

def request_withdrawal(user_id: str, amount: float, wallet_address: str) -> dict:
    token      = secrets.token_urlsafe(48)
    execute_at = (datetime.utcnow() + timedelta(hours=24)).isoformat()
    record = supabase.table("withdrawal_requests").insert({
        "user_id": user_id, "amount": amount,
        "wallet_address": wallet_address, "confirm_token": token,
        "status": "pending_email_confirmation", "execute_at": execute_at,
    }).execute()
    # TODO: wire your email provider here — send token to user's email
    return {"message": "Withdrawal requested. Check email to confirm.",
            "execute_at": execute_at, "request_id": record.data[0]["id"]}

def confirm_withdrawal(token: str) -> dict:
    row = supabase.table("withdrawal_requests").select("*")\
        .eq("confirm_token", token).eq("status", "pending_email_confirmation")\
        .single().execute()
    if not row.data:
        raise ValueError("Invalid or expired confirmation token")
    supabase.table("withdrawal_requests")\
        .update({"status": "confirmed_pending_execution"})\
        .eq("id", row.data["id"]).execute()
    return {"message": "Confirmed. Executes after 24h cooling period."}

def cancel_withdrawal(user_id: str, request_id: str) -> dict:
    supabase.table("withdrawal_requests").update({"status": "cancelled"})\
        .eq("id", request_id).eq("user_id", user_id)\
        .in_("status", ["pending_email_confirmation", "confirmed_pending_execution"])\
        .execute()
    return {"message": "Withdrawal cancelled successfully."}