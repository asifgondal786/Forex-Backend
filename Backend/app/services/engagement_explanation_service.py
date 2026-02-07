from datetime import datetime, timezone
from typing import List, Dict, Any, Optional

from firebase_admin import firestore

from ..utils.firestore_client import get_firestore_client


class EngagementExplanationService:
    def __init__(self):
        self.db = get_firestore_client()

    def create_explanation(
        self,
        user_id: str,
        decision_id: str,
        explanation_type: str,
        factors: Optional[List[Dict[str, Any]]] = None,
        overall_reasoning: Optional[str] = None,
    ) -> Dict[str, Any]:
        now = datetime.now(timezone.utc)

        if not factors:
            factors = [
                {"category": "technical", "score": 0.0, "components": []},
                {"category": "sentiment", "score": 0.0, "components": []},
                {"category": "risk", "score": 0.0, "components": []},
            ]

        payload = {
            "userId": user_id,
            "decisionId": decision_id,
            "type": explanation_type,
            "factors": factors,
            "overallReasoning": overall_reasoning or "Explanation not available yet.",
            "timestamp": firestore.SERVER_TIMESTAMP,
        }

        doc_ref = self.db.collection("ai_explanations").document()
        doc_ref.set(payload)

        return {
            "id": doc_ref.id,
            "userId": user_id,
            "decisionId": decision_id,
            "type": explanation_type,
            "factors": factors,
            "overallReasoning": payload["overallReasoning"],
            "timestamp": now,
        }

    def get_explanation(self, explanation_id: str) -> Optional[Dict[str, Any]]:
        doc = self.db.collection("ai_explanations").document(explanation_id).get()
        if not doc.exists:
            return None

        data = doc.to_dict() or {}
        timestamp = data.get("timestamp")
        if hasattr(timestamp, "to_datetime"):
            timestamp = timestamp.to_datetime()
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)

        return {
            "id": doc.id,
            "userId": data.get("userId"),
            "decisionId": data.get("decisionId"),
            "type": data.get("type"),
            "factors": data.get("factors", []),
            "overallReasoning": data.get("overallReasoning", ""),
            "timestamp": timestamp,
        }
