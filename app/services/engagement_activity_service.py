from datetime import datetime, timezone
from typing import Optional, List, Dict, Any

from firebase_admin import firestore

from ..utils.firestore_client import get_firestore_client


class EngagementActivityService:
    def __init__(self):
        self.db = get_firestore_client()

    def log_activity(
        self,
        user_id: str,
        activity_type: str,
        message: str,
        emoji: Optional[str] = None,
        color: Optional[str] = None,
    ) -> Dict[str, Any]:
        now = datetime.now(timezone.utc)
        payload = {
            "userId": user_id,
            "type": activity_type,
            "message": message,
            "timestamp": firestore.SERVER_TIMESTAMP,
            "emoji": emoji,
            "color": color,
        }

        doc_ref = self.db.collection("ai_activity").document()
        doc_ref.set(payload)

        response = {
            "id": doc_ref.id,
            "userId": user_id,
            "type": activity_type,
            "message": message,
            "timestamp": now,
            "emoji": emoji,
            "color": color,
        }
        return response

    def get_activity_feed(
        self,
        user_id: str,
        limit: int = 10,
        cursor: Optional[str] = None,
    ) -> Dict[str, Any]:
        query = (
            self.db.collection("ai_activity")
            .where("userId", "==", user_id)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )

        if cursor:
            cursor_doc = self.db.collection("ai_activity").document(cursor).get()
            if cursor_doc.exists:
                query = query.start_after(cursor_doc)

        docs = list(query.stream())
        activities: List[Dict[str, Any]] = []

        for doc in docs:
            data = doc.to_dict() or {}
            activities.append(self._normalize_activity(doc.id, data, user_id))

        next_cursor = docs[-1].id if len(docs) == limit else None
        return {"activities": activities, "next_cursor": next_cursor}

    def _normalize_activity(self, doc_id: str, data: Dict[str, Any], user_id: str) -> Dict[str, Any]:
        timestamp = data.get("timestamp")
        if hasattr(timestamp, "to_datetime"):
            timestamp = timestamp.to_datetime()
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)

        return {
            "id": doc_id,
            "userId": data.get("userId", user_id),
            "type": data.get("type", "monitor"),
            "message": data.get("message", ""),
            "timestamp": timestamp,
            "emoji": data.get("emoji"),
            "color": data.get("color"),
        }
