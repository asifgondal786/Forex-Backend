from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
import uuid

from ..database import supabase


class EngagementActivityService:

    def log_activity(
        self,
        user_id: str,
        activity_type: str,
        message: str,
        emoji: Optional[str] = None,
        color: Optional[str] = None,
    ) -> Dict[str, Any]:
        now = datetime.now(timezone.utc)
        activity_id = str(uuid.uuid4())
        payload = {
            "id": activity_id,
            "user_id": user_id,
            "type": activity_type,
            "message": message,
            "timestamp": now.isoformat(),
            "emoji": emoji,
            "color": color,
        }
        try:
            supabase.table("ai_activity").insert(payload).execute()
        except Exception:
            pass

        return {
            "id": activity_id,
            "userId": user_id,
            "type": activity_type,
            "message": message,
            "timestamp": now,
            "emoji": emoji,
            "color": color,
        }

    def get_activity_feed(
        self,
        user_id: str,
        limit: int = 10,
        cursor: Optional[str] = None,
    ) -> Dict[str, Any]:
        try:
            query = (
                supabase.table("ai_activity")
                .select("*")
                .eq("user_id", user_id)
                .order("timestamp", desc=True)
                .limit(limit)
            )
            if cursor:
                query = query.lt("id", cursor)

            result = query.execute()
            docs = result.data or []
        except Exception:
            docs = []

        activities = [self._normalize_activity(row) for row in docs]
        next_cursor = docs[-1]["id"] if len(docs) == limit else None
        return {"activities": activities, "next_cursor": next_cursor}

    def _normalize_activity(self, data: Dict[str, Any]) -> Dict[str, Any]:
        timestamp = data.get("timestamp")
        if isinstance(timestamp, str):
            try:
                timestamp = datetime.fromisoformat(timestamp)
            except ValueError:
                timestamp = datetime.now(timezone.utc)
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)

        return {
            "id": data.get("id") or "",
            "userId": data.get("user_id") or "",
            "type": data.get("type") or "monitor",
            "message": data.get("message") or "",
            "timestamp": timestamp,
            "emoji": data.get("emoji"),
            "color": data.get("color"),
        }
