"""
Phase 17 automation routes.

These endpoints back the Flutter AutomationProvider and piggyback on the
existing auto_trade_config / auto_trade_log tables where possible.
"""

from __future__ import annotations

from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field

from app.database import supabase
from app.limiter import limiter
from app.security import get_current_user_id

router = APIRouter(prefix="/api/v1/automation", tags=["automation"])

VALID_MODES = {"manual", "assisted", "semi_auto", "fully_auto"}


class ModeRequest(BaseModel):
    mode: str = Field(..., min_length=3, max_length=16)


class GuardrailsRequest(BaseModel):
    max_drawdown_pct: Optional[float] = Field(default=None, ge=1, le=50)
    daily_loss_cap_usd: Optional[float] = Field(default=None, ge=10, le=10000)
    max_open_trades: Optional[int] = Field(default=None, ge=1, le=20)


class AutomationSettingsRequest(BaseModel):
    auto_follow_enabled: Optional[bool] = None
    show_ai_reasoning: Optional[bool] = None


class EvaluateAutoTradeRequest(BaseModel):
    estimated_loss_usd: float = Field(default=0.0, ge=0.0)
    current_drawdown_pct: float = Field(default=0.0, ge=0.0)


def _require_supabase() -> Any:
    if supabase is None:
        raise HTTPException(status_code=503, detail="Supabase is not configured")
    return supabase


def _utcnow_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _default_config() -> Dict[str, Any]:
    return {
        "trade_mode": "manual",
        "max_drawdown_pct": 20.0,
        "daily_loss_cap_usd": 200.0,
        "max_open_trades": 5,
        "auto_follow_enabled": False,
        "show_ai_reasoning": True,
    }


def _load_config(user_id: str) -> Dict[str, Any]:
    if supabase is None:
        return dict(_default_config())

    try:
        result = (
            supabase.table("auto_trade_config")
            .select("*")
            .eq("user_id", user_id)
            .limit(1)
            .execute()
        )
        row = (result.data or [None])[0]
        if not row:
            return dict(_default_config())
        config = dict(_default_config())
        config.update(row)
        return config
    except Exception:
        return dict(_default_config())


def _mode_or_default(raw_mode: Any) -> str:
    mode = str(raw_mode or "manual").strip().lower()
    return mode if mode in VALID_MODES else "manual"


@router.get("/mode")
async def get_mode(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    config = _load_config(user_id)
    return {"mode": _mode_or_default(config.get("trade_mode"))}


@router.patch("/mode")
@limiter.limit("20/minute")
async def set_mode(
    request: Request,
    payload: ModeRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    mode = _mode_or_default(payload.mode)
    if mode != payload.mode.strip().lower():
        raise HTTPException(
            status_code=400,
            detail=f"Invalid mode. Must be one of: {sorted(VALID_MODES)}",
        )

    client = _require_supabase()
    body = {
        "user_id": user_id,
        "trade_mode": mode,
        "updated_at": _utcnow_iso(),
    }
    try:
        client.table("auto_trade_config").upsert(body, on_conflict="user_id").execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not update automation mode: {exc}") from exc

    return {"mode": mode, "message": f"Mode set to {mode}"}


@router.get("/guardrails")
async def get_guardrails(user_id: str = Depends(get_current_user_id)) -> Dict[str, Any]:
    config = _load_config(user_id)
    return {
        "max_drawdown_pct": _safe_float(config.get("max_drawdown_pct"), 20.0),
        "daily_loss_cap_usd": _safe_float(config.get("daily_loss_cap_usd"), 200.0),
        "max_open_trades": int(config.get("max_open_trades") or 5),
    }


@router.patch("/guardrails")
@limiter.limit("30/minute")
async def set_guardrails(
    request: Request,
    payload: GuardrailsRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    body: Dict[str, Any] = {
        "user_id": user_id,
        "updated_at": _utcnow_iso(),
    }

    if payload.max_drawdown_pct is not None:
        body["max_drawdown_pct"] = float(payload.max_drawdown_pct)
    if payload.daily_loss_cap_usd is not None:
        body["daily_loss_cap_usd"] = float(payload.daily_loss_cap_usd)
    if payload.max_open_trades is not None:
        body["max_open_trades"] = int(payload.max_open_trades)

    if len(body) == 2:
        raise HTTPException(status_code=400, detail="No guardrails provided")

    try:
        client.table("auto_trade_config").upsert(body, on_conflict="user_id").execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not update guardrails: {exc}") from exc

    config = _load_config(user_id)
    return {
        "message": "Guardrails updated",
        "max_drawdown_pct": _safe_float(config.get("max_drawdown_pct"), 20.0),
        "daily_loss_cap_usd": _safe_float(config.get("daily_loss_cap_usd"), 200.0),
        "max_open_trades": int(config.get("max_open_trades") or 5),
    }


@router.patch("/settings")
@limiter.limit("20/minute")
async def update_settings(
    request: Request,
    payload: AutomationSettingsRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    client = _require_supabase()
    body: Dict[str, Any] = {
        "user_id": user_id,
        "updated_at": _utcnow_iso(),
    }

    if payload.auto_follow_enabled is not None:
        body["auto_follow_enabled"] = bool(payload.auto_follow_enabled)
    if payload.show_ai_reasoning is not None:
        body["show_ai_reasoning"] = bool(payload.show_ai_reasoning)

    if len(body) == 2:
        raise HTTPException(status_code=400, detail="No settings provided")

    try:
        client.table("auto_trade_config").upsert(body, on_conflict="user_id").execute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not update automation settings: {exc}") from exc

    config = _load_config(user_id)
    return {
        "message": "Settings updated",
        "auto_follow_enabled": bool(config.get("auto_follow_enabled", False)),
        "show_ai_reasoning": bool(config.get("show_ai_reasoning", True)),
    }


@router.get("/log")
async def get_execution_log(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    if supabase is None:
        return {"log": [], "count": 0}

    try:
        result = (
            supabase.table("auto_trade_log")
            .select("*")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .range(offset, offset + limit - 1)
            .execute()
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Could not load automation log: {exc}") from exc

    entries: List[Dict[str, Any]] = []
    for row in (result.data or []):
        triggered_by = _mode_or_default(row.get("triggered_by") or "manual")
        entries.append(
            {
                "id": str(row.get("id") or ""),
                "pair": row.get("pair") or "",
                "action": row.get("action_taken") or row.get("action") or "",
                "result": row.get("result") or row.get("reason") or "",
                "triggered_by": triggered_by,
                "timestamp": row.get("created_at") or row.get("timestamp"),
            }
        )

    return {"log": entries, "count": len(entries)}


@router.post("/evaluate")
@limiter.limit("60/minute")
async def evaluate_auto_trade(
    request: Request,
    payload: EvaluateAutoTradeRequest = Body(...),
    user_id: str = Depends(get_current_user_id),
) -> Dict[str, Any]:
    config = _load_config(user_id)
    mode = _mode_or_default(config.get("trade_mode"))
    if mode not in {"semi_auto", "fully_auto"}:
        return {"allowed": False, "reason": "Automation is not active"}

    client = _require_supabase()

    max_open_trades = int(config.get("max_open_trades") or 5)
    try:
        open_count_result = (
            client.table("paper_trades")
            .select("id", count="exact")
            .eq("user_id", user_id)
            .eq("status", "open")
            .execute()
        )
        current_open = int(open_count_result.count or 0)
    except Exception:
        current_open = 0

    if current_open >= max_open_trades:
        return {
            "allowed": False,
            "reason": f"Max open trades limit reached ({max_open_trades})",
        }

    today = date.today().isoformat()
    daily_cap = _safe_float(config.get("daily_loss_cap_usd"), 200.0)
    try:
        daily_rows = (
            client.table("paper_trades")
            .select("realized_pnl, closed_at")
            .eq("user_id", user_id)
            .eq("status", "closed")
            .gte("closed_at", today)
            .execute()
        )
        loss_used = sum(
            abs(_safe_float(row.get("realized_pnl")))
            for row in (daily_rows.data or [])
            if _safe_float(row.get("realized_pnl")) < 0
        )
    except Exception:
        loss_used = 0.0

    if loss_used + float(payload.estimated_loss_usd) > daily_cap:
        return {
            "allowed": False,
            "reason": f"Exceeds daily loss cap (${daily_cap:.0f})",
        }

    max_drawdown = _safe_float(config.get("max_drawdown_pct"), 20.0)
    if float(payload.current_drawdown_pct) > max_drawdown:
        return {
            "allowed": False,
            "reason": f"Drawdown limit exceeded ({max_drawdown:.0f}%)",
        }

    return {"allowed": True, "reason": None}
