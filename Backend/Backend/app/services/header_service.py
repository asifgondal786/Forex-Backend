from datetime import datetime
from typing import Dict, Any, Optional

from ..database import supabase
from ..enhanced_websocket_manager import ws_manager


class HeaderService:
    def _default_name(self, claims: Dict[str, Any]) -> str:
        email = claims.get("email") or ""
        return claims.get("name") or (email.split("@")[0] if email else "User")

    def _default_avatar(self, claims: Dict[str, Any]) -> str | None:
        return claims.get("picture") or claims.get("avatar_url") or None

    def _count_unread_notifications(self, user_id: str) -> Optional[int]:
        try:
            result = (
                supabase.table("notifications")
                .select("id", count="exact")
                .eq("user_id", user_id)
                .eq("is_read", False)
                .execute()
            )
            return result.count or 0
        except Exception:
            return None

    def get_header(self, user_id: str, claims: Dict[str, Any]) -> Dict[str, Any]:
        result = supabase.table("user_headers").select("*").eq("user_id", user_id).execute()
        data = result.data[0] if result.data else {}

        name = data.get("display_name") or data.get("name") or self._default_name(claims)
        status = data.get("status") or "Available Online"
        avatar_url = data.get("avatar_url") or self._default_avatar(claims)
        risk_level = data.get("risk_level") or "Moderate"
        balance_amount = data.get("balance_amount")
        balance_currency = data.get("balance_currency")

        unread = self._count_unread_notifications(user_id)
        if unread is None:
            unread = int(data.get("notifications_unread") or 0)

        return {
            "user": {
                "id": user_id,
                "name": name,
                "status": status,
                "avatar_url": avatar_url,
                "risk_level": risk_level,
            },
            "balance": {
                "amount": float(balance_amount) if balance_amount is not None else 0.0,
                "currency": balance_currency or "USD",
            },
            "notifications": {
                "unread": unread,
            },
            "stream": {
                "enabled": ws_manager.is_forex_stream_running(),
                "interval": ws_manager.get_forex_stream_interval(),
            },
        }

    def update_header(self, user_id: str, updates: Dict[str, Any], claims: Dict[str, Any]) -> Dict[str, Any]:
        now = datetime.utcnow().isoformat()
        payload: Dict[str, Any] = {"user_id": user_id, "updated_at": now}

        if "name" in updates:
            payload["display_name"] = updates["name"]
        if "status" in updates:
            payload["status"] = updates["status"]
        if "avatar_url" in updates:
            payload["avatar_url"] = updates["avatar_url"]
        if "risk_level" in updates:
            payload["risk_level"] = updates["risk_level"]
        if "balance_amount" in updates:
            payload["balance_amount"] = updates["balance_amount"]
        if "balance_currency" in updates:
            payload["balance_currency"] = updates["balance_currency"]
        if "notifications_unread" in updates:
            payload["notifications_unread"] = updates["notifications_unread"]

        supabase.table("user_headers").upsert(payload).execute()
        return self.get_header(user_id, claims)
