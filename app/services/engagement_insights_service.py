from datetime import datetime, timezone
from typing import Optional, List, Dict, Any

from firebase_admin import firestore

from ..utils.firestore_client import get_firestore_client


class EngagementInsightsService:
    def __init__(self):
        self.db = get_firestore_client()

    def get_confidence_history(
        self,
        user_id: str,
        period: str = "24h",
        points: int = 7,
    ) -> Dict[str, Any]:
        query = (
            self.db.collection("ai_confidence_history")
            .where("userId", "==", user_id)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .limit(1)
        )
        docs = list(query.stream())

        if not docs:
            now = datetime.now(timezone.utc)
            return {
                "current": 0.0,
                "trend": "flat",
                "change_24h": 0.0,
                "reason": "No confidence data available yet.",
                "historical": [0.0 for _ in range(points)],
                "timestamp": now,
            }

        data = docs[0].to_dict() or {}
        timestamp = data.get("timestamp")
        if hasattr(timestamp, "to_datetime"):
            timestamp = timestamp.to_datetime()
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)

        current = float(data.get("current", 0.0))
        historical = data.get("historical") or [current]

        if not historical:
            historical = [current]

        if len(historical) == 1 and points > 1:
            historical = [historical[0] for _ in range(points)]

        change_24h = data.get("change_24h")
        if change_24h is None and len(historical) >= 2:
            change_24h = float(historical[-1]) - float(historical[0])
        change_24h = float(change_24h or 0.0)

        trend = data.get("trend")
        if trend not in {"up", "down", "flat"}:
            if change_24h > 0.1:
                trend = "up"
            elif change_24h < -0.1:
                trend = "down"
            else:
                trend = "flat"

        reason = data.get("reason") or "No explanation available yet."

        return {
            "current": current,
            "trend": trend,
            "change_24h": change_24h,
            "reason": reason,
            "historical": [float(x) for x in historical],
            "timestamp": timestamp,
        }

    def get_active_alerts(
        self,
        user_id: str,
        active: bool = True,
        limit: int = 10,
    ) -> Dict[str, Any]:
        query = (
            self.db.collection("ai_alerts")
            .where("userId", "==", user_id)
            .where("active", "==", active)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .limit(limit)
        )

        docs = list(query.stream())
        alerts: List[Dict[str, Any]] = []
        now = datetime.now(timezone.utc)

        for doc in docs:
            data = doc.to_dict() or {}
            expires_at = data.get("expiresAt")
            if hasattr(expires_at, "to_datetime"):
                expires_at = expires_at.to_datetime()
            if expires_at and expires_at < now:
                continue

            timestamp = data.get("timestamp")
            if hasattr(timestamp, "to_datetime"):
                timestamp = timestamp.to_datetime()
            if timestamp is None:
                timestamp = now

            alerts.append(
                {
                    "id": doc.id,
                    "userId": data.get("userId", user_id),
                    "type": data.get("type", "info"),
                    "icon": data.get("icon", "shield"),
                    "title": data.get("title", "Alert"),
                    "message": data.get("message", ""),
                    "severity": data.get("severity", "info"),
                    "action": data.get("action"),
                    "timestamp": timestamp,
                    "active": data.get("active", True),
                }
            )

        return {"alerts": alerts}
