from fastapi import APIRouter, Depends, Body, HTTPException
from app.auth import get_current_user
from app.limiter import limiter
from app.database import supabase
from fastapi import Request
from datetime import datetime, timezone, date
import math

router = APIRouter(prefix="/api/v1/beginner", tags=["beginner"])


# ─── Beginner mode settings ───────────────────────────────────────────────────

@router.get("/settings")
async def get_settings(current_user=Depends(get_current_user)):
    """
    Get beginner mode settings from server.
    Maps to BeginnerModeProvider.load() — persists across devices.

    Response shape:
      is_enabled, daily_loss_cap, max_leverage, daily_loss_used, last_reset_date
    """
    uid = str(current_user["uid"])
    row = supabase.table("user_settings") \
        .select("beginner_mode_enabled, daily_loss_cap, max_leverage, daily_loss_used, last_reset_date") \
        .eq("user_id", uid).limit(1).execute()

    if not row.data:
        return {
            "is_enabled":      False,
            "daily_loss_cap":  100.0,
            "max_leverage":    10.0,
            "daily_loss_used": 0.0,
            "last_reset_date": date.today().isoformat(),
        }

    r = row.data[0]
    last_reset = r.get("last_reset_date", "")
    today = date.today().isoformat()

    # Auto-reset daily loss if it's a new day
    daily_loss_used = float(r.get("daily_loss_used") or 0)
    if last_reset and last_reset[:10] != today:
        daily_loss_used = 0.0
        supabase.table("user_settings").update({
            "daily_loss_used":  0.0,
            "last_reset_date":  today,
        }).eq("user_id", uid).execute()

    return {
        "is_enabled":      bool(r.get("beginner_mode_enabled", False)),
        "daily_loss_cap":  float(r.get("daily_loss_cap") or 100.0),
        "max_leverage":    float(r.get("max_leverage") or 10.0),
        "daily_loss_used": daily_loss_used,
        "last_reset_date": today,
    }


@router.patch("/settings")
@limiter.limit("20/minute")
async def update_settings(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Update beginner mode settings.
    Maps to BeginnerModeProvider.setEnabled / setDailyLossCap / setMaxLeverage.

    Body: {
      "is_enabled":     bool,
      "daily_loss_cap": 100.0,
      "max_leverage":   10.0
    }
    """
    uid = str(current_user["uid"])
    update = {"user_id": uid}

    if "is_enabled" in body:
        update["beginner_mode_enabled"] = bool(body["is_enabled"])
    if "daily_loss_cap" in body:
        update["daily_loss_cap"] = max(10.0, min(10000.0, float(body["daily_loss_cap"])))
    if "max_leverage" in body:
        update["max_leverage"] = max(1.0, min(100.0, float(body["max_leverage"])))

    supabase.table("user_settings").upsert(update, on_conflict="user_id").execute()
    return {"message": "Settings updated", **update}


@router.post("/record-loss")
@limiter.limit("60/minute")
async def record_loss(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Record a realized loss against the daily cap.
    Maps to BeginnerModeProvider.recordLoss(loss).
    Body: { "loss_usd": 25.50 }
    """
    uid = str(current_user["uid"])
    loss = abs(float(body.get("loss_usd", 0)))
    if loss <= 0:
        return {"message": "No loss to record"}

    today = date.today().isoformat()

    # Get current row
    row = supabase.table("user_settings") \
        .select("daily_loss_used, last_reset_date, daily_loss_cap, beginner_mode_enabled") \
        .eq("user_id", uid).limit(1).execute()

    if not row.data or not row.data[0].get("beginner_mode_enabled"):
        return {"message": "Beginner mode not enabled"}

    r = row.data[0]
    last_reset = r.get("last_reset_date", "")
    current_used = float(r.get("daily_loss_used") or 0)

    # Reset if new day
    if last_reset[:10] != today:
        current_used = 0.0

    new_used = current_used + loss
    daily_cap = float(r.get("daily_loss_cap") or 100.0)
    cap_reached = new_used >= daily_cap

    supabase.table("user_settings").update({
        "daily_loss_used": round(new_used, 2),
        "last_reset_date": today,
    }).eq("user_id", uid).execute()

    return {
        "daily_loss_used": round(new_used, 2),
        "daily_loss_cap":  daily_cap,
        "cap_reached":     cap_reached,
        "remaining":       max(0, round(daily_cap - new_used, 2)),
    }


@router.post("/check-trade")
@limiter.limit("60/minute")
async def check_trade_guard(
    request: Request,
    body: dict = Body(...),
    current_user=Depends(get_current_user)
):
    """
    Server-side trade guard check (mirrors BeginnerModeProvider.checkTrade).
    Body: { "leverage": 10.0, "estimated_loss_usd": 25.0 }
    Returns: { "result": "allowed" | "warn_high_leverage" | "blocked_daily_cap" }
    """
    uid = str(current_user["uid"])
    leverage = float(body.get("leverage", 1.0))
    loss = float(body.get("estimated_loss_usd", 0))

    row = supabase.table("user_settings") \
        .select("beginner_mode_enabled, daily_loss_cap, max_leverage, daily_loss_used, last_reset_date") \
        .eq("user_id", uid).limit(1).execute()

    if not row.data or not row.data[0].get("beginner_mode_enabled"):
        return {"result": "allowed", "reason": None}

    r = row.data[0]
    today = date.today().isoformat()
    last_reset = r.get("last_reset_date", "")
    used = float(r.get("daily_loss_used") or 0) if last_reset[:10] == today else 0.0
    cap = float(r.get("daily_loss_cap") or 100.0)
    max_lev = float(r.get("max_leverage") or 10.0)

    if used + loss > cap:
        return {
            "result": "blocked_daily_cap",
            "reason": f"Daily loss cap of ${cap:.0f} reached (used: ${used:.0f})",
        }
    if leverage > max_lev:
        return {
            "result": "warn_high_leverage",
            "reason": f"Leverage {leverage:.0f}x exceeds recommended max of {max_lev:.0f}x",
        }

    return {"result": "allowed", "reason": None}


# ─── Risk simulator (Kelly + Drawdown + Stress) ───────────────────────────────

@router.post("/risk/kelly")
async def compute_kelly(body: dict = Body(...)):
    """
    Kelly Criterion calculator.
    Maps to RiskSimulatorScreen._KellyTab calculations.
    Body: { "win_rate_pct": 60.0, "win_loss_ratio": 2.0 }
    """
    win_rate = float(body.get("win_rate_pct", 60)) / 100
    ratio    = float(body.get("win_loss_ratio", 2.0))

    kelly = (win_rate - (1 - win_rate) / ratio) * 100
    safe_kelly = kelly / 2

    if kelly < 0:
        interpretation = "Negative expected value — do not trade this setup."
    elif kelly < 5:
        interpretation = f"Risk only {safe_kelly:.1f}% per trade. Conservative setup."
    else:
        interpretation = f"Risk {safe_kelly:.1f}% per trade (half-Kelly) for optimal growth."

    return {
        "kelly_criterion": round(kelly, 2),
        "safe_kelly":      round(safe_kelly, 2),
        "interpretation":  interpretation,
        "negative":        kelly < 0,
    }


@router.post("/risk/drawdown")
async def compute_drawdown(body: dict = Body(...)):
    """
    Drawdown calculator.
    Maps to RiskSimulatorScreen._DrawdownTab.
    Body: { "risk_per_trade_pct": 2.0, "max_drawdown_target_pct": 20.0 }
    """
    risk   = float(body.get("risk_per_trade_pct", 2.0))
    target = float(body.get("max_drawdown_target_pct", 20.0))

    max_losses = target / risk if risk > 0 else 0

    return {
        "max_consecutive_losses": round(max_losses, 1),
        "risk_per_trade_pct":     risk,
        "max_drawdown_target_pct": target,
        "description": (
            f"At {risk:.1f}% risk/trade, you can absorb "
            f"{max_losses:.0f} consecutive losses before hitting "
            f"your {target:.0f}% drawdown limit."
        ),
    }


@router.post("/risk/stress")
async def compute_stress(body: dict = Body(...)):
    """
    Stress test calculator.
    Maps to RiskSimulatorScreen._StressTestTab.
    Body: {
      "consecutive_losses": 5,
      "risk_per_trade_pct": 2.0,
      "account_size":       10000.0
    }
    """
    n_losses = int(body.get("consecutive_losses", 5))
    risk_pct = float(body.get("risk_per_trade_pct", 2.0))
    account  = float(body.get("account_size", 10000.0))

    balance = account
    for _ in range(n_losses):
        balance *= (1 - risk_pct / 100)

    loss = account - balance
    loss_pct = (loss / account) * 100

    if loss_pct > 30:
        severity = "critical"
    elif loss_pct > 15:
        severity = "warning"
    else:
        severity = "safe"

    return {
        "total_loss_usd":     round(loss, 2),
        "remaining_balance":  round(balance, 2),
        "loss_pct":           round(loss_pct, 2),
        "severity":           severity,
        "description": (
            f"After {n_losses} consecutive losses at {risk_pct:.1f}% risk, "
            f"your ${account:.0f} account would be down ${loss:.2f}."
        ),
    }
