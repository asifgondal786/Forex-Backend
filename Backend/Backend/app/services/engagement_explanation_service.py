from datetime import datetime, timezone
from typing import List, Dict, Any, Optional
import uuid

from ..database import supabase


class EngagementExplanationService:

    def create_explanation(self, user_id: str, decision_id: str, explanation_type: str, factors: Optional[List[Dict[str, Any]]] = None, overall_reasoning: Optional[str] = None) -> Dict[str, Any]:
        now = datetime.now(timezone.utc)
        if not factors:
            factors = [{"category": "technical", "score": 0.0, "components": []}, {"category": "sentiment", "score": 0.0, "components": []}, {"category": "risk", "score": 0.0, "components": []}]
        explanation_id = str(uuid.uuid4())
        payload = {"id": explanation_id, "user_id": user_id, "decision_id": decision_id, "type": explanation_type, "factors": factors, "overall_reasoning": overall_reasoning or "Explanation not available yet.", "timestamp": now.isoformat()}
        try:
            supabase.table("ai_explanations").insert(payload).execute()
        except Exception:
            pass
        return {"id": explanation_id, "userId": user_id, "decisionId": decision_id, "type": explanation_type, "factors": factors, "overallReasoning": payload["overall_reasoning"], "timestamp": now}

    def get_explanation(self, explanation_id: str) -> Optional[Dict[str, Any]]:
        try:
            result = supabase.table("ai_explanations").select("*").eq("id", explanation_id).execute()
            if not result.data:
                return None
            data = result.data[0]
        except Exception:
            return None
        timestamp = data.get("timestamp")
        if isinstance(timestamp, str):
            try:
                timestamp = datetime.fromisoformat(timestamp)
            except ValueError:
                timestamp = datetime.now(timezone.utc)
        if timestamp is None:
            timestamp = datetime.now(timezone.utc)
        return {"id": data.get("id"), "userId": data.get("user_id"), "decisionId": data.get("decision_id"), "type": data.get("type"), "factors": data.get("factors") or [], "overallReasoning": data.get("overall_reasoning") or "", "timestamp": timestamp}
