from fastapi import APIRouter, Depends, Body
from app.auth import get_current_user
from app.limiter import limiter
from fastapi import Request
from app.database import supabase
from datetime import datetime, timezone, date
from typing import Optional

router = APIRouter(prefix="/api/v1/automation", tags=["automation"])


# ─── Mode ─────────────────────────────────────────────────────────────────────

@router.get("/mode")
async def get_mode(current_user=Depends(get_current_user)):
    """Get current automation mode for the user."""
    uid = str(current_user["uid"])
    row = supabase.table("auto_trade_config").select("trade_mode") \
        .eq("user_id", uid).limit(1).execute()
    mode = row.data[0]["trade_mode"] if row.data else "manual"
    return {"mode": mode}


@router.patch("/mode")
@limiter.limit("20/minute")
async def set_mode(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Set automation mode. Maps to AutomationProvider.setMode().
    Body: { "mode": "manual" | "assisted" | "semi_auto" | "fully_auto" }
    Flutter enum → DB value mapping:
      AutoMode.manual    → "manual"
      AutoMode.assisted  → "assisted"
      AutoMode.semiAuto  → "semi_auto"
      AutoMode.fullyAuto → "fully_auto"
    """
    uid = str(current_user["uid"])
    mode = body.get("mode", "manual")

    valid_modes = {"manual", "assisted", "semi_auto", "fully_auto"}
    if mode not in valid_modes:
        from fastapi import HTTPException
        raise HTTPException(400, f"Invalid mode. Must be one of: {valid_modes}")

    supabase.table("auto_trade_config").upsert({
        "user_id": uid,
        "trade_mode": mode,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    }, on_conflict="user_id").execute()

    return {"mode": mode, "message": f"Mode set to {mode}"}


# ─── Guardrails ───────────────────────────────────────────────────────────────

@router.get("/guardrails")
async def get_guardrails(current_user=Depends(get_current_user)):
    """
    Get risk guardrail settings.
    Maps to AutomationProvider: maxDrawdown, dailyLossCap, maxOpenTrades.
    """
    uid = str(current_user["uid"])
    row = supabase.table("auto_trade_config") \
        .select("max_drawdown_pct, daily_loss_cap_usd, max_open_trades") \
        .eq("user_id", uid).limit(1).execute()

    if not row.data:
        return {"max_drawdown_pct": 20.0, "daily_loss_cap_usd": 200.0, "max_open_trades": 5}

    return row.data[0]


@router.patch("/guardrails")
@limiter.limit("30/minute")
async def set_guardrails(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Update risk guardrails.
    Body: { "max_drawdown_pct": 20.0, "daily_loss_cap_usd": 200.0, "max_open_trades": 5 }
    Maps to AutomationProvider.setMaxDrawdown / setDailyLossCap / setMaxOpenTrades.
    """
    uid = str(current_user["uid"])

    update = {"user_id": uid, "updated_at": datetime.now(timezone.utc).isoformat()}

    if "max_drawdown_pct" in body:
        pct = float(body["max_drawdown_pct"])
        update["max_drawdown_pct"] = max(1.0, min(50.0, pct))

    if "daily_loss_cap_usd" in body:
        cap = float(body["daily_loss_cap_usd"])
        update["daily_loss_cap_usd"] = max(10.0, min(10000.0, cap))

    if "max_open_trades" in body:
        trades = int(body["max_open_trades"])
        update["max_open_trades"] = max(1, min(20, trades))

    supabase.table("auto_trade_config").upsert(update, on_conflict="user_id").execute()
    return {"message": "Guardrails updated", **update}


# ─── Auto-follow settings ─────────────────────────────────────────────────────

@router.patch("/settings")
@limiter.limit("20/minute")
async def update_settings(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Update auto-follow and AI reasoning settings.
    Body: { "auto_follow_enabled": bool, "show_ai_reasoning": bool }
    Maps to AutomationProvider.setAutoFollow / setShowAiReasoning.
    """
    uid = str(current_user["uid"])
    update = {"user_id": uid, "updated_at": datetime.now(timezone.utc).isoformat()}

    if "auto_follow_enabled" in body:
        update["auto_follow_enabled"] = bool(body["auto_follow_enabled"])
    if "show_ai_reasoning" in body:
        update["show_ai_reasoning"] = bool(body["show_ai_reasoning"])

    supabase.table("auto_trade_config").upsert(update, on_conflict="user_id").execute()
    return {"message": "Settings updated"}


# ─── Execution log ────────────────────────────────────────────────────────────

@router.get("/log")
async def get_execution_log(
    current_user=Depends(get_current_user),
    limit: int = 50,
    offset: int = 0
):
    """
    Fetch automation execution log.
    Maps to AutomationProvider.loadLog() — returns List<LogEntry>.

    Response shape matches LogEntry model:
      id, pair, action, result, triggered_by, timestamp
    """
    uid = str(current_user["uid"])
    rows = supabase.table("auto_trade_log") \
        .select("id, pair, action_taken, result, triggered_by, created_at") \
        .eq("user_id", uid) \
        .order("created_at", desc=True) \
        .range(offset, offset + limit - 1) \
        .execute()

    entries = []
    for r in (rows.data or []):
        entries.append({
            "id":           r["id"],
            "pair":         r["pair"],
            "action":       r["action_taken"],
            "result":       r.get("result", ""),
            "triggered_by": r.get("triggered_by", "manual"),
            "timestamp":    r["created_at"],
        })

    return {"log": entries, "count": len(entries)}


# ─── Guardrail evaluation (called server-side before any auto-trade) ──────────

@router.post("/evaluate")
@limiter.limit("60/minute")
async def evaluate_auto_trade(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Server-side guardrail check before executing an auto-trade.
    Maps to AutomationProvider.evaluateAutoTrade().

    Body: {
      "estimated_loss_usd": 50.0,
      "current_drawdown_pct": 5.0
    }

    Returns: { "allowed": bool, "reason": str | null }
    """
    uid = str(current_user["uid"])

    # Fetch guardrails
    cfg_row = supabase.table("auto_trade_config") \
        .select("trade_mode, max_drawdown_pct, daily_loss_cap_usd, max_open_trades") \
        .eq("user_id", uid).limit(1).execute()

    cfg = cfg_row.data[0] if cfg_row.data else {
        "trade_mode": "manual", "max_drawdown_pct": 20.0,
        "daily_loss_cap_usd": 200.0, "max_open_trades": 5
    }

    mode = cfg["trade_mode"]
    if mode not in ("semi_auto", "fully_auto"):
        return {"allowed": False, "reason": "Automation is not active"}

    # Count open trades
    open_count = supabase.table("paper_trades") \
        .select("id", count="exact") \
        .eq("user_id", uid).eq("status", "open").execute()
    current_open = open_count.count or 0

    max_open = int(cfg.get("max_open_trades", 5))
    if current_open >= max_open:
        return {"allowed": False, "reason": f"Max open trades limit reached ({max_open})"}

    # Check daily loss cap
    estimated_loss = float(body.get("estimated_loss_usd", 0))
    daily_cap = float(cfg.get("daily_loss_cap_usd", 200.0))

    today_str = date.today().isoformat()
    daily_loss_row = supabase.table("paper_trades") \
        .select("realized_pnl") \
        .eq("user_id", uid).eq("status", "closed") \
        .gte("closed_at", today_str).execute()

    daily_loss_used = abs(sum(
        r["realized_pnl"] for r in (daily_loss_row.data or [])
        if (r.get("realized_pnl") or 0) < 0
    ))

    if daily_loss_used + estimated_loss > daily_cap:
        return {"allowed": False, "reason": f"Exceeds daily loss cap (${daily_cap:.0f})"}

    # Check drawdown
    current_drawdown = float(body.get("current_drawdown_pct", 0))
    max_drawdown = float(cfg.get("max_drawdown_pct", 20.0))
    if current_drawdown > max_drawdown:
        return {"allowed": False, "reason": f"Drawdown limit exceeded ({max_drawdown}%)"}

    return {"allowed": True, "reason": None}
