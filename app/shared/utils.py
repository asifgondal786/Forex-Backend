"""
Shared utility functions used across multiple route and service modules.
Single source of truth — all routes should import from here instead of
defining their own private copies.

Migration: Replace local definitions with:
    from app.shared import require_supabase, safe_float, normalize_pair, ...
"""
from __future__ import annotations

import os
from datetime import datetime, timezone
from typing import Any

from fastapi import HTTPException


# ═══════════════════════ Supabase ═══════════════════════

_supabase_client = None


def require_supabase():
    """Return the Supabase client or raise 503 if unavailable."""
    global _supabase_client
    if _supabase_client is not None:
        return _supabase_client
    try:
        from supabase import create_client
        url = os.getenv("SUPABASE_URL", "")
        key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY", "")
        if not url or not key:
            raise RuntimeError("SUPABASE_URL or SUPABASE_KEY not configured")
        _supabase_client = create_client(url, key)
        return _supabase_client
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Database unavailable: {exc}")


# ═══════════════════════ Type Helpers ═══════════════════════

def safe_float(value: Any, default: float = 0.0) -> float:
    """Safely convert any value to float."""
    if value is None:
        return default
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def safe_bool(value: Any) -> bool:
    """Safely convert any value to bool."""
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.lower() in ("true", "1", "yes")
    return bool(value)


def env_bool(name: str, default: bool = False) -> bool:
    """Read a boolean from environment."""
    raw = os.getenv(name, "")
    if not raw:
        return default
    return raw.lower() in ("true", "1", "yes")


# ═══════════════════════ Date/Time ═══════════════════════

def utcnow() -> datetime:
    """Current UTC datetime."""
    return datetime.now(timezone.utc)


def utcnow_iso() -> str:
    """Current UTC as ISO 8601 string."""
    return datetime.now(timezone.utc).isoformat()


def today_str() -> str:
    """Today's date as YYYY-MM-DD."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


# ═══════════════════════ Forex Pairs ═══════════════════════

_JPY_PAIRS = frozenset({
    "USD/JPY", "EUR/JPY", "GBP/JPY", "AUD/JPY",
    "NZD/JPY", "CAD/JPY", "CHF/JPY",
})


def normalize_pair(pair: str) -> str:
    """Normalize pair format: 'eurusd' -> 'EUR/USD'."""
    cleaned = pair.strip().upper().replace(" ", "")
    if "/" not in cleaned and len(cleaned) == 6:
        cleaned = cleaned[:3] + "/" + cleaned[3:]
    return cleaned


def pair_key(pair: str) -> str:
    """Convert pair to standard lookup key."""
    return normalize_pair(pair)


def price_digits(pair: str) -> int:
    """Number of decimal places for a pair."""
    return 3 if normalize_pair(pair) in _JPY_PAIRS else 5


def round_price(pair: str, value: float) -> float:
    """Round a price to appropriate digits for the pair."""
    return round(value, price_digits(pair))
