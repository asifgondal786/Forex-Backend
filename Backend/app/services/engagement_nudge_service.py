from datetime import datetime, timezone
from typing import Dict, Any, List

from ..database import supabase


class EngagementNudgeService:

    def get_nudges(self, user_id: str, context: str = "active", limit: int = 5) -> Dict[str, Any]:
        try:
            result = (supabase.table("ai_nudges").select("*").eq("user_id", user_id).eq("active", True).order("timestamp", desc=True).limit(limit).execute())
            docs = result.data or []
        except Exception:
            docs = []
        nudges: List[Dict[str, Any]] = []
        now = datetime.now(timezone.utc)
        for data in docs:
            display_until = data.get("display_until")
            if isinstance(display_until, str):
                try:
                    display_until = datetime.fromisoformat(display_until)
                except ValueError:
                    display_until = None
            if display_until and display_until < now:
                continue
            if data.get("context") and data.get("context") != context:
                continue
            timestamp = data.get("timestamp")
            if isinstance(timestamp, str):
                try:
                    timestamp = datetime.fromisoformat(timestamp)
                except ValueError:
                    timestamp = now
            if timestamp is None:
                timestamp = now
            nudges.append({"id": str(data.get("id") or ""), "userId": data.get("user_id") or user_id, "type": data.get("type") or "suggestion", "emoji": data.get("emoji") or "idea", "title": data.get("title") or "Nudge", "message": data.get("message") or "", "action": data.get("action"), "priority": data.get("priority") or "low", "displayUntil": display_until, "timestamp": timestamp, "active": data.get("active", True)})
        return {"nudges": nudges}

    def record_response(self, user_id: str, nudge_id: str, response: str) -> Dict[str, Any]:
        try:
            result = supabase.table("ai_nudges").select("id").eq("id", nudge_id).execute()
            if not result.data:
                return {"status": "not_found", "nudge_id": nudge_id}
            supabase.table("ai_nudges").update({"last_response": response, "responded_at": datetime.now(timezone.utc).isoformat(), "active": False, "responded_by": user_id}).eq("id", nudge_id).execute()
        except Exception:
            return {"status": "error", "nudge_id": nudge_id}
        return {"status": "ok", "nudge_id": nudge_id, "response": response}
