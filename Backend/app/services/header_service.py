from datetime import datetime
from typing import Dict, Any, Optional

from ..utils.firestore_client import get_firestore_client
from ..enhanced_websocket_manager import ws_manager


class HeaderService:
    def __init__(self) -> None:
        self.db = get_firestore_client()
        self.collection = self.db.collection("user_headers")

    def _default_name(self, claims: Dict[str, Any]) -> str:
        email = claims.get("email") or ""
        return claims.get("name") or (email.split("@")[0] if email else "User")

    def _default_avatar(self, claims: Dict[str, Any]) -> str | None:
        return claims.get("picture") or claims.get("avatar_url") or None

    def _count_unread_notifications(self, user_id: str) -> Optional[int]:
        try:
            query = self.db.collection("notifications").where("userId", "==", user_id)
            count = 0
            for doc in query.stream():
                data = doc.to_dict() or {}
                read = data.get("read")
                if read is None:
                    read = data.get("is_read") or data.get("isRead") or False
                if not read:
                    count += 1
            return count
        except Exception:
            return None

    def get_header(self, user_id: str, claims: Dict[str, Any]) -> Dict[str, Any]:
        doc = self.collection.document(user_id).get()
        data = doc.to_dict() or {}

        name = data.get("display_name") or data.get("name") or self._default_name(claims)
        status = data.get("status") or "Available Online"
        avatar_url = data.get("avatar_url") or data.get("avatarUrl") or self._default_avatar(claims)
        risk_level = data.get("risk_level") or data.get("riskLevel") or "Moderate"

        balance_amount = data.get("balance_amount")
        balance_currency = data.get("balance_currency")
        if balance_amount is None and isinstance(data.get("balance"), dict):
            balance_amount = data.get("balance", {}).get("amount")
        if balance_currency is None and isinstance(data.get("balance"), dict):
            balance_currency = data.get("balance", {}).get("currency")

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
        payload: Dict[str, Any] = {"updated_at": now}

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

        doc_ref = self.collection.document(user_id)
        doc = doc_ref.get()
        if not doc.exists:
            payload["created_at"] = now

        doc_ref.set(payload, merge=True)
        return self.get_header(user_id, claims)
