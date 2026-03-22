from __future__ import annotations
from datetime import datetime
from app.database import supabase
from app.services.social_service import get_copy_subscribers

def mirror_trade(provider_id: str, trade: dict) -> list[dict]:
    """
    Called when a provider opens a trade.
    Mirrors it to all copy-enabled followers, scaled to their risk %.
    Returns list of copy trade records created.
    """
    subscribers = get_copy_subscribers(provider_id)
    results = []
    for sub in subscribers:
        follower_id  = sub["follower_id"]
        risk_pct     = float(sub.get("copy_risk_pct") or 1.0)
        max_dd       = float(sub.get("max_drawdown_pct") or 10.0)

        # Check follower drawdown — skip if breached
        if _is_drawdown_breached(follower_id, max_dd):
            _log_copy_trade(follower_id, provider_id, trade,
                           status="skipped",
                           skip_reason="max_drawdown_breached")
            continue

        # Scale lot size to follower risk %
        provider_risk = float(trade.get("risk_pct") or 1.0)
        scale_factor  = risk_pct / provider_risk if provider_risk else 1.0
        scaled_lots   = round(float(trade.get("lot_size") or 0.1) * scale_factor, 4)
        scaled_lots   = max(0.01, min(scaled_lots, 10.0))  # clamp 0.01–10 lots

        record = {
            "follower_id":     follower_id,
            "provider_id":     provider_id,
            "source_trade_id": str(trade.get("id") or ""),
            "pair":            trade.get("pair", ""),
            "direction":       trade.get("direction", "BUY"),
            "lot_size":        scaled_lots,
            "entry_price":     trade.get("entry_price"),
            "stop_loss":       trade.get("stop_loss"),
            "take_profit":     trade.get("take_profit"),
            "status":          "open",
        }
        result = supabase.table("copy_trades").insert(record).execute()
        results.append(result.data[0])
    return results

def close_mirror_trade(provider_trade_id: str, exit_price: float) -> list[dict]:
    """Close all copy trades linked to a provider trade."""
    rows = supabase.table("copy_trades") \
        .select("*").eq("source_trade_id", str(provider_trade_id)) \
        .eq("status", "open").execute()
    updated = []
    for row in (rows.data or []):
        direction = row.get("direction", "BUY")
        lot_size  = float(row.get("lot_size") or 0.1)
        entry     = float(row.get("entry_price") or exit_price)
        pip_value = 10.0 * lot_size
        pnl = (exit_price - entry) * pip_value * (1 if direction == "BUY" else -1)
        supabase.table("copy_trades").update({
            "status": "closed", "exit_price": exit_price,
            "pnl_usd": round(pnl, 2),
            "closed_at": datetime.utcnow().isoformat()
        }).eq("id", row["id"]).execute()
        updated.append(row["id"])
    return updated

def get_copy_history(follower_id: str, limit: int = 50) -> list:
    result = supabase.table("copy_trades") \
        .select("*").eq("follower_id", follower_id) \
        .order("opened_at", desc=True).limit(limit).execute()
    return result.data or []

def get_copy_performance(follower_id: str) -> dict:
    rows = supabase.table("copy_trades") \
        .select("pnl_usd,status").eq("follower_id", follower_id) \
        .eq("status", "closed").execute()
    data  = rows.data or []
    total = len(data)
    wins  = sum(1 for r in data if (r.get("pnl_usd") or 0) > 0)
    pnl   = sum((r.get("pnl_usd") or 0) for r in data)
    return {
        "total_copy_trades": total,
        "win_rate": round(wins / total * 100, 2) if total else 0,
        "total_pnl_usd": round(pnl, 2),
        "wins": wins, "losses": total - wins,
    }

def _is_drawdown_breached(follower_id: str, max_dd_pct: float) -> bool:
    rows = supabase.table("copy_trades") \
        .select("pnl_usd").eq("follower_id", follower_id) \
        .eq("status", "closed").execute()
    total_loss = sum(
        (r.get("pnl_usd") or 0) for r in (rows.data or [])
        if (r.get("pnl_usd") or 0) < 0
    )
    return abs(total_loss) >= max_dd_pct * 100

def _log_copy_trade(follower_id, provider_id, trade,
                    status="skipped", skip_reason=None):
    supabase.table("copy_trades").insert({
        "follower_id": follower_id, "provider_id": provider_id,
        "source_trade_id": str(trade.get("id") or ""),
        "pair": trade.get("pair", ""), "direction": trade.get("direction", "BUY"),
        "lot_size": 0, "status": status, "skip_reason": skip_reason,
    }).execute()
