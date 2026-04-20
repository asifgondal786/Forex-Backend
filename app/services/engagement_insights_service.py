from datetime import datetime, timezone
from typing import List, Dict, Any

from ..database import supabase


class EngagementInsightsService:

    def get_confidence_history(self, user_id: str, period: str = "24h", points: int = 7) -> Dict[str, Any]:
        try:
            result = supabase.table("ai_confidence_history").select("*").eq("user_id", user_id).order("timestamp", desc=True).limit(1).execute()
            docs = result.data or []
        except Exception:
            docs = []
        now = datetime.now(timezone.utc)
        if not docs:
            return {"current": 0.0, "trend": "flat", "change_24h": 0.0, "reason": "No confidence data available yet.", "historical": [0.0 for _ in range(points)], "timestamp": now}
        data = docs[0]
        timestamp = data.get("timestamp")
        if isinstance(timestamp, str):
            try:
                timestamp = datetime.fromisoformat(timestamp)
            except ValueError:
                timestamp = now
        if timestamp is None:
            timestamp = now
        current = float(data.get("current") or 0.0)
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
            trend = "up" if change_24h > 0.1 else "down" if change_24h < -0.1 else "flat"
        return {"current": current, "trend": trend, "change_24h": change_24h, "reason": data.get("reason") or "No explanation available yet.", "historical": [float(x) for x in historical], "timestamp": timestamp}

    def get_active_alerts(self, user_id: str, active: bool = True, limit: int = 10) -> Dict[str, Any]:
        try:
            result = supabase.table("ai_alerts").select("*").eq("user_id", user_id).eq("active", active).order("timestamp", desc=True).limit(limit).execute()
            docs = result.data or []
        except Exception:
            docs = []
        alerts: List[Dict[str, Any]] = []
        now = datetime.now(timezone.utc)
        for data in docs:
            expires_at = data.get("expires_at")
            if isinstance(expires_at, str):
                try:
                    expires_at = datetime.fromisoformat(expires_at)
                except ValueError:
                    expires_at = None
            if expires_at and expires_at < now:
                continue
            timestamp = data.get("timestamp")
            if isinstance(timestamp, str):
                try:
                    timestamp = datetime.fromisoformat(timestamp)
                except ValueError:
                    timestamp = now
            if timestamp is None:
                timestamp = now
            alerts.append({"id": str(data.get("id") or ""), "userId": data.get("user_id") or user_id, "type": data.get("type") or "info", "icon": data.get("icon") or "shield", "title": data.get("title") or "Alert", "message": data.get("message") or "", "severity": data.get("severity") or "info", "action": data.get("action"), "timestamp": timestamp, "active": data.get("active", True)})
        return {"alerts": alerts}
