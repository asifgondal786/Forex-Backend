from datetime import datetime
from typing import Any, Dict, Optional

from ..utils.firestore_client import get_firestore_client


class SettingsService:
    def __init__(self) -> None:
        self.db = get_firestore_client()
        self.collection = self.db.collection("user_settings")

    def _format_ts(self, value: Optional[object]) -> Optional[str]:
        if isinstance(value, datetime):
            return value.isoformat()
        if isinstance(value, str):
            return value
        return None

    def get_settings(self, user_id: str) -> Dict[str, Any]:
        doc = self.collection.document(user_id).get()
        data = doc.to_dict() or {}
        settings = data.get("settings") or {}

        return {
            "user_id": user_id,
            "settings": settings,
            "created_at": self._format_ts(data.get("created_at")),
            "updated_at": self._format_ts(data.get("updated_at")),
        }

    def update_settings(self, user_id: str, updates: Dict[str, Any], replace: bool = False) -> Dict[str, Any]:
        now = datetime.utcnow().isoformat()
        doc_ref = self.collection.document(user_id)
        doc = doc_ref.get()
        data = doc.to_dict() or {}
        current_settings = data.get("settings") or {}

        if replace:
            merged_settings = updates or {}
        else:
            merged_settings = {**current_settings, **(updates or {})}

        payload: Dict[str, Any] = {
            "settings": merged_settings,
            "updated_at": now,
        }

        if not doc.exists:
            payload["created_at"] = now

        doc_ref.set(payload, merge=True)

        return {
            "user_id": user_id,
            "settings": merged_settings,
            "created_at": self._format_ts(payload.get("created_at") or data.get("created_at")),
            "updated_at": now,
        }
