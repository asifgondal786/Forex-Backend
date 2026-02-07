from datetime import datetime, timezone
from typing import Optional, Dict, Any, List

from firebase_admin import firestore

from ..utils.firestore_client import get_firestore_client


class EngagementNudgeService:
    def __init__(self):
        self.db = get_firestore_client()

    def get_nudges(
        self,
        user_id: str,
        context: str = "active",
        limit: int = 5,
    ) -> Dict[str, Any]:
        query = (
            self.db.collection("ai_nudges")
            .where("userId", "==", user_id)
            .where("active", "==", True)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )

        docs = list(query.stream())
        nudges: List[Dict[str, Any]] = []
        now = datetime.now(timezone.utc)

        for doc in docs:
            data = doc.to_dict() or {}
            display_until = data.get("displayUntil")
            if hasattr(display_until, "to_datetime"):
                display_until = display_until.to_datetime()
            if display_until and display_until < now:
                continue

            if data.get("context") and data.get("context") != context:
                continue

            timestamp = data.get("timestamp")
            if hasattr(timestamp, "to_datetime"):
                timestamp = timestamp.to_datetime()
            if timestamp is None:
                timestamp = now

            nudges.append(
                {
                    "id": doc.id,
                    "userId": data.get("userId", user_id),
                    "type": data.get("type", "suggestion"),
                    "emoji": data.get("emoji", "idea"),
                    "title": data.get("title", "Nudge"),
                    "message": data.get("message", ""),
                    "action": data.get("action"),
                    "priority": data.get("priority", "low"),
                    "displayUntil": display_until,
                    "timestamp": timestamp,
                    "active": data.get("active", True),
                }
            )

        return {"nudges": nudges}

    def record_response(
        self,
        user_id: str,
        nudge_id: str,
        response: str,
    ) -> Dict[str, Any]:
        doc_ref = self.db.collection("ai_nudges").document(nudge_id)
        doc = doc_ref.get()
        if not doc.exists:
            return {"status": "not_found", "nudge_id": nudge_id}

        doc_ref.update(
            {
                "lastResponse": response,
                "respondedAt": firestore.SERVER_TIMESTAMP,
                "active": False,
                "respondedBy": user_id,
            }
        )

        return {"status": "ok", "nudge_id": nudge_id, "response": response}
