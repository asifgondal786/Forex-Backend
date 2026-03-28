from datetime import datetime, timezone
from typing import Dict, Any, List

from ..database import supabase


class EngagementProgressService:

    def get_progress(self, user_id: str, period: str = "week") -> Dict[str, Any]:
        try:
            result = (
                supabase.table("user_progress")
                .select("*")
                .eq("user_id", user_id)
                .eq("period", period)
                .order("timestamp", desc=True)
                .limit(1)
                .execute()
            )
            docs = result.data or []
        except Exception:
            docs = []

        now = datetime.now(timezone.utc)
        if not docs:
            return {"period": period, "metrics": {}, "achievements": [], "timestamp": now}

        data = docs[0]
        timestamp = data.get("timestamp")
        if isinstance(timestamp, str):
            try:
                timestamp = datetime.fromisoformat(timestamp)
            except ValueError:
                timestamp = now
        if timestamp is None:
            timestamp = now

        achievements = self.get_achievements(user_id).get("achievements", [])
        return {
            "period": data.get("period") or period,
            "metrics": data.get("metrics") or {},
            "achievements": achievements,
            "timestamp": timestamp,
        }

    def get_achievements(self, user_id: str) -> Dict[str, Any]:
        try:
            result = (
                supabase.table("user_achievements")
                .select("*")
                .eq("user_id", user_id)
                .order("timestamp", desc=True)
                .execute()
            )
            docs = result.data or []
        except Exception:
            docs = []

        achievements: List[Dict[str, Any]] = []
        now = datetime.now(timezone.utc)

        for data in docs:
            timestamp = data.get("timestamp")
            if isinstance(timestamp, str):
                try:
                    timestamp = datetime.fromisoformat(timestamp)
                except ValueError:
                    timestamp = now
            if timestamp is None:
                timestamp = now

            achievements.append({
                "id": str(data.get("id") or ""),
                "userId": data.get("user_id") or user_id,
                "title": data.get("title") or "",
                "description": data.get("description") or "",
                "seen": bool(data.get("seen") or False),
                "timestamp": timestamp,
            })

        return {"achievements": achievements}

    def mark_achievement_seen(self, user_id: str, achievement_id: str) -> Dict[str, Any]:
        try:
            result = supabase.table("user_achievements").select("id").eq("id", achievement_id).execute()
            if not result.data:
                return {"status": "not_found", "achievement_id": achievement_id}
            supabase.table("user_achievements").update({
                "seen": True,
                "seen_at": datetime.now(timezone.utc).isoformat(),
                "seen_by": user_id,
            }).eq("id", achievement_id).execute()
        except Exception:
            return {"status": "error", "achievement_id": achievement_id}

        return {"status": "ok", "achievement_id": achievement_id}
