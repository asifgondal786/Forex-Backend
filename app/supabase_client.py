"""
supabase_client.py — High-level Supabase utilities and health checks.
The actual client instance lives in app.database (already initialized).
This module provides health checks, table constants, and the base repository pattern.
"""

import logging
from typing import Optional
from app.database import supabase

logger = logging.getLogger(__name__)


async def supabase_health() -> dict:
    """Health check — verify Supabase connectivity."""
    if not supabase:
        return {"status": "unhealthy", "connected": False, "error": "Client not initialized"}
    try:
        # Simple query to verify connection
        result = supabase.table("users").select("id").limit(1).execute()
        return {"status": "healthy", "connected": True}
    except Exception as e:
        return {"status": "unhealthy", "connected": False, "error": str(e)}


class Tables:
    """Table name constants — prevents typos and enables IDE autocomplete."""
    USERS = "users"
    TRADES = "trades"
    ORDERS = "orders"
    SIGNALS = "signals"
    POSITIONS = "positions"
    PORTFOLIO = "portfolio"
    RISK_SETTINGS = "risk_settings"
    NOTIFICATIONS = "notifications"
    SUBSCRIPTIONS = "subscriptions"
    AUDIT_LOG = "audit_log"
    AI_REQUESTS = "ai_requests"
    MACRO_EVENTS = "macro_events"
    USER_SETTINGS = "user_settings"
    BROKER_ACCOUNTS = "broker_accounts"
    EQUITY_SNAPSHOTS = "equity_snapshots"


class SupabaseRepository:
    """
    Base repository with common CRUD operations.
    All domain repositories extend this.
    """

    def __init__(self, table_name: str):
        self.table_name = table_name
        if not supabase:
            raise RuntimeError(f"Supabase not initialized — cannot access table '{table_name}'")
        self._client = supabase

    @property
    def table(self):
        return self._client.table(self.table_name)

    def get_by_id(self, record_id: str) -> Optional[dict]:
        try:
            result = self.table.select("*").eq("id", record_id).single().execute()
            return result.data if result.data else None
        except Exception:
            return None

    def get_by_user(self, user_id: str, limit: int = 100) -> list[dict]:
        result = (
            self.table
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .limit(limit)
            .execute()
        )
        return result.data or []

    def create(self, data: dict) -> dict:
        result = self.table.insert(data).execute()
        return result.data[0] if result.data else {}

    def update(self, record_id: str, data: dict) -> dict:
        result = self.table.update(data).eq("id", record_id).execute()
        return result.data[0] if result.data else {}

    def delete(self, record_id: str) -> bool:
        self.table.delete().eq("id", record_id).execute()
        return True

    def upsert(self, data: dict) -> dict:
        result = self.table.upsert(data).execute()
        return result.data[0] if result.data else {}
