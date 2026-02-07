from datetime import datetime, timezone
from typing import Dict, Any, List

from firebase_admin import firestore

from ..utils.firestore_client import get_firestore_client


class EngagementProgressService:
    def __init__(self):
        self.db = get_firestore_client()

    def get_progress(self, user_id: str, period: str = "week") -> Dict[str, Any]:
        query = (
            self.db.collection("user_progress")
            .where("userId", "==", user_id)
            .where("period", "==", period)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .limit(1)
        )
        docs = list(query.stream())

        if not docs:
            now = datetime.now(timezone.utc)
            return {
                "period": period,
                "metrics": {},
                "achievements": [],
                "timestamp": now,
            }

        data = docs[0].to_dict() or {}
        timestamp = data.get("timestamp")
        if hasattr(timestamp, "to_datetime"):
            timestamp = timestamp.to_datetime()
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)

        achievements = self.get_achievements(user_id).get("achievements", [])

        return {
            "period": data.get("period", period),
            "metrics": data.get("metrics", {}),
            "achievements": achievements,
            "timestamp": timestamp,
        }

    def get_achievements(self, user_id: str) -> Dict[str, Any]:
        query = (
            self.db.collection("user_achievements")
            .where("userId", "==", user_id)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
        )
        docs = list(query.stream())
        achievements: List[Dict[str, Any]] = []

        for doc in docs:
            data = doc.to_dict() or {}
            timestamp = data.get("timestamp")
            if hasattr(timestamp, "to_datetime"):
                timestamp = timestamp.to_datetime()
            if timestamp is None:
                timestamp = datetime.now(timezone.utc)

            achievements.append(
                {
                    "id": doc.id,
                    "userId": data.get("userId", user_id),
                    "title": data.get("title", ""),
                    "description": data.get("description", ""),
                    "seen": data.get("seen", False),
                    "timestamp": timestamp,
                }
            )

        return {"achievements": achievements}

    def mark_achievement_seen(self, user_id: str, achievement_id: str) -> Dict[str, Any]:
        doc_ref = self.db.collection("user_achievements").document(achievement_id)
        doc = doc_ref.get()
        if not doc.exists:
            return {"status": "not_found", "achievement_id": achievement_id}

        doc_ref.update(
            {
                "seen": True,
                "seenAt": firestore.SERVER_TIMESTAMP,
                "seenBy": user_id,
            }
        )

        return {"status": "ok", "achievement_id": achievement_id}
