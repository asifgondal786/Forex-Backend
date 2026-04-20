"""
Phase 17 beginner-mode routes.

These endpoints mirror the Flutter BeginnerModeProvider while remaining
compatible with both the direct-column and nested-settings variants of the
current user_settings storage.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from pydantic import BaseModel, Field

from app.database import supabase
from app.limiter import limiter
from app.security import get_current_user_id

router = APIRouter(prefix="/api/v1/beginner", tags=["beginner"])


class BeginnerSettingsRequest(BaseModel):
    is_enabled: Optional[bool] = None
    daily_loss_cap: Optional[float] = Field(default=None, ge=10, le=10000)
    max_leverage: Optional[float] = Field(default=None, ge=1, le=100)


class RecordLossRequest(BaseModel):
    loss_usd: float = Field(..., ge=0.0)


class CheckTradeRequest(BaseModel):
    leverage: float = Field(default=1.0, ge=1.0)
    estimated_loss_usd: float = Field(default=0.0, ge=0.0)


class KellyRequest(BaseModel):
    win_rate_pct: float = Field(default=60.0, ge=0.0, le=100.0)
    win_loss_ratio: float = Field(default=2.0, gt=0.0)


class DrawdownRequest(BaseModel):
    risk_per_trade_pct: float = Field(default=2.0, gt=0.0)
    max_drawdown_target_pct: float = Field(default=20.0, gt=0.0)


class StressRequest(BaseModel):
    consecutive_losses: int = Field(default=5, ge=0, le=100)
    risk_per_trade_pct: float = Field(default=2.0, ge=0.0, le=100.0)
    account_size: float = Field(default=10000.0, gt=0.0)


def _require_supabase() -> Any:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase is not configured")
    return supabase


def _today() -> str:
    return date.today().isoformat()


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _default_settings() -> Dict[str, Any]:
    return {
        "is_enabled": False,
        "daily_loss_cap": 100.0,
        "max_leverage": 10.0,
        "daily_loss_used": 0.0,
        "last_reset_date": _today(),
    }


def _row_to_settings(row: Optional[Dict[str, Any]]) -> Dict[str, Any]:
    settings = dict(_default_settings())
    if not row:
        return settings

    nested = row.get("settings") or {}

    settings["is_enabled"] = bool(
        row.get("beginner_mode_enabled", nested.get("beginner_mode_enabled", settings["is_enabled"]))
    )
    settings["daily_loss_cap"] = _safe_float(
        row.get("daily_loss_cap", nested.get("daily_loss_cap", settings["daily_loss_cap"])),
        settings["daily_loss_cap"],
    )
    settings["max_leverage"] = _safe_float(
        row.get("max_leverage", nested.get("max_leverage", settings["max_leverage"])),
        settings["max_leverage"],
    )
    settings["daily_loss_used"] = _safe_float(
        row.get("daily_loss_used", nested.get("daily_loss_used", settings["daily_loss_used"])),
        settings["daily_loss_used"],
    )
    settings["last_reset_date"] = str(
        row.get("last_reset_date", nested.get("last_reset_date", settings["last_reset_date"]))
    )
    return settings


def _load_settings(user_id: str) -> Dict[str, Any]:
    if supabase is None:
        return dict(_default_settings())

    try:
        result = (
            supabase.table("user_settings")
            .select("*")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        row = (result.data or [None])[0]
        return _row_to_settings(row)
    except Exception:
        return dict(_default_settings())


def _persist_settings(user_id: str, updates: Dict[str, Any]) -> None:
    client = _require_supabase()
    try:
        current_result = (
            client.table("user_settings")
            .select("*")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        current_row = (current_result.data or [None])[0]
    except Exception:
        current_row = None

    current_settings = _row_to_settings(current_row)
    merged = {**current_settings, **updates}
    nested_settings = dict((current_row or {}).get("settings") or {})
    nested_settings.update(
        {
            "beginner_mode_enabled": bool(merged["is_enabled"]),
            "daily_loss_cap": float(merged["daily_loss_cap"]),
            "max_leverage": float(merged["max_leverage"]),
            "daily_loss_used": float(merged["daily_loss_used"]),
            "last_reset_date": str(merged["last_reset_date"]),
        }
    )

    payload = {
        "user_id": user_id,
        "beginner_mode_enabled": bool(merged["is_enabled"]),
        "daily_loss_cap": float(merged["daily_loss_cap"]),
        "max_leverage": float(merged["max_leverage"]),
        "daily_loss_used": float(merged["daily_loss_used"]),
        "last_reset_date": str(merged["last_reset_date"]),
        "settings": nested_settings,
        "updated_at": _utcnow_iso(),
    }
    if not current_row:
        payload["created_at"] = _utcnow_iso()

    client.table("user_settings").upsert(payload, on_conflict="user_id").execute()


@router.get("/settings")
async def get_settings(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    settings = _load_settings(user_id)
    today = _today()
    if settings["last_reset_date"][:10] != today:
        settings["daily_loss_used"] = 0.0
        settings["last_reset_date"] = today
        if supabase is not None:
            try:
                _persist_settings(user_id, settings)
            except Exception:
                pass

    return settings


@router.patch("/settings")
@limiter.limit("20/minute")
async def update_settings(
    request: Request,
    payload: BeginnerSettingsRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    current = _load_settings(user_id)
    updates = dict(current)

    if payload.is_enabled is not None:
        updates["is_enabled"] = bool(payload.is_enabled)
    if payload.daily_loss_cap is not None:
        updates["daily_loss_cap"] = float(payload.daily_loss_cap)
    if payload.max_leverage is not None:
        updates["max_leverage"] = float(payload.max_leverage)

    try:
        _persist_settings(user_id, updates)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not update beginner settings: {exc}") from exc

    fresh = _load_settings(user_id)
    fresh["message"] = "Settings updated"
    return fresh


@router.post("/record-loss")
@limiter.limit("60/minute")
async def record_loss(
    request: Request,
    payload: RecordLossRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    settings = _load_settings(user_id)
    loss = abs(float(payload.loss_usd))
    if not settings["is_enabled"]:
        return {"message": "Beginner mode not enabled"}
    if loss <= 0:
        return {"message": "No loss to record"}

    today = _today()
    if settings["last_reset_date"][:10] != today:
        settings["daily_loss_used"] = 0.0
    settings["daily_loss_used"] = round(settings["daily_loss_used"] + loss, 2)
    settings["last_reset_date"] = today

    try:
        _persist_settings(user_id, settings)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not record loss: {exc}") from exc

    remaining = max(0.0, round(settings["daily_loss_cap"] - settings["daily_loss_used"], 2))
    return {
        "daily_loss_used": round(settings["daily_loss_used"], 2),
        "daily_loss_cap": round(settings["daily_loss_cap"], 2),
        "cap_reached": settings["daily_loss_used"] >= settings["daily_loss_cap"],
        "remaining": remaining,
    }


@router.post("/check-trade")
@limiter.limit("60/minute")
async def check_trade_guard(
    request: Request,
    payload: CheckTradeRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    settings = _load_settings(user_id)
    today = _today()
    daily_loss_used = settings["daily_loss_used"] if settings["last_reset_date"][:10] == today else 0.0

    if not settings["is_enabled"]:
        return {"result": "allowed", "reason": None}

    if daily_loss_used + float(payload.estimated_loss_usd) > settings["daily_loss_cap"]:
        return {
            "result": "blocked_daily_cap",
            "reason": (
                f"Daily loss cap of ${settings['daily_loss_cap']:.0f} reached "
                f"(used: ${daily_loss_used:.0f})"
            ),
        }

    if float(payload.leverage) > settings["max_leverage"]:
        return {
            "result": "warn_high_leverage",
            "reason": (
                f"Leverage {float(payload.leverage):.0f}x exceeds recommended max "
                f"of {settings['max_leverage']:.0f}x"
            ),
        }

    return {"result": "allowed", "reason": None}


@router.post("/risk/kelly")
async def compute_kelly(payload: KellyRequest = Body(...)) -> Dict[str, Any]:
    win_rate = float(payload.win_rate_pct) / 100.0
    ratio = float(payload.win_loss_ratio)
    kelly_pct = (win_rate - (1.0 - win_rate) / ratio) * 100.0
    safe_kelly = kelly_pct / 2.0

    if kelly_pct < 0:
        interpretation = "Negative expectancy. Avoid this setup until the edge improves."
    elif kelly_pct < 5:
        interpretation = f"Small edge. Around {safe_kelly:.1f}% risk per trade keeps sizing conservative."
    else:
        interpretation = f"Half-Kelly suggests about {safe_kelly:.1f}% risk per trade."

    return {
        "kelly_criterion": round(kelly_pct, 2),
        "safe_kelly": round(safe_kelly, 2),
        "interpretation": interpretation,
        "negative": kelly_pct < 0,
    }


@router.post("/risk/drawdown")
async def compute_drawdown(payload: DrawdownRequest = Body(...)) -> Dict[str, Any]:
    risk = float(payload.risk_per_trade_pct)
    target = float(payload.max_drawdown_target_pct)
    max_losses = (target / risk) if risk > 0 else 0.0
    return {
        "max_consecutive_losses": round(max_losses, 1),
        "risk_per_trade_pct": risk,
        "max_drawdown_target_pct": target,
        "description": (
            f"At {risk:.1f}% risk per trade, about {max_losses:.0f} consecutive losses "
            f"would push you to a {target:.0f}% drawdown."
        ),
    }


@router.post("/risk/stress")
async def compute_stress(payload: StressRequest = Body(...)) -> Dict[str, Any]:
    balance = float(payload.account_size)
    start_balance = balance
    for _ in range(int(payload.consecutive_losses)):
        balance *= 1.0 - (float(payload.risk_per_trade_pct) / 100.0)

    total_loss = start_balance - balance
    loss_pct = (total_loss / start_balance) * 100.0 if start_balance else 0.0

    if loss_pct > 30:
        severity = "critical"
    elif loss_pct > 15:
        severity = "warning"
    else:
        severity = "safe"

    return {
        "total_loss_usd": round(total_loss, 2),
        "remaining_balance": round(balance, 2),
        "loss_pct": round(loss_pct, 2),
        "severity": severity,
        "description": (
            f"After {payload.consecutive_losses} consecutive losses at "
            f"{payload.risk_per_trade_pct:.1f}% risk, a ${start_balance:.0f} account "
            f"would be down ${total_loss:.2f}."
        ),
    }
