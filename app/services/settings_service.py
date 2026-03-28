from datetime import datetime
from typing import Any, Dict, Optional

from ..database import supabase


class SettingsService:
    def _format_ts(self, value: Optional[object]) -> Optional[str]:
        if isinstance(value, datetime):
            return value.isoformat()
        if isinstance(value, str):
            return value
        return None

    def get_settings(self, user_id: str) -> Dict[str, Any]:
        result = supabase.table("user_settings").select("*").eq("user_id", user_id).execute()
        data = result.data[0] if result.data else {}
        settings = data.get("settings") or {}

        return {
            "user_id": user_id,
            "settings": settings,
            "created_at": self._format_ts(data.get("created_at")),
            "updated_at": self._format_ts(data.get("updated_at")),
        }

    def update_settings(self, user_id: str, updates: Dict[str, Any], replace: bool = False) -> Dict[str, Any]:
        now = datetime.utcnow().isoformat()

        result = supabase.table("user_settings").select("*").eq("user_id", user_id).execute()
        data = result.data[0] if result.data else {}
        current_settings = data.get("settings") or {}

        if replace:
            merged_settings = updates or {}
        else:
            merged_settings = {**current_settings, **(updates or {})}

        payload: Dict[str, Any] = {
            "user_id": user_id,
            "settings": merged_settings,
            "updated_at": now,
        }

        if not data:
            payload["created_at"] = now

        supabase.table("user_settings").upsert(payload).execute()

        return {
            "user_id": user_id,
            "settings": merged_settings,
            "created_at": self._format_ts(payload.get("created_at") or data.get("created_at")),
            "updated_at": now,
        }
