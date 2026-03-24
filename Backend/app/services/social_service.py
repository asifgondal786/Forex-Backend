from __future__ import annotations
from datetime import datetime
from app.database import supabase

def get_profile(user_id: str) -> dict | None:
    row = supabase.table("strategy_profiles").select("*") \
        .eq("user_id", user_id).single().execute()
    return row.data

def upsert_profile(user_id: str, data: dict) -> dict:
    data["user_id"] = user_id
    data["updated_at"] = datetime.utcnow().isoformat()
    result = supabase.table("strategy_profiles").upsert(data).execute()
    return result.data[0]

def get_leaderboard(limit: int = 20) -> list:
    result = supabase.table("strategy_profiles") \
        .select("user_id,display_name,win_rate,total_trades,total_pnl_usd,avg_rr_ratio,followers,verified") \
        .eq("is_public", True) \
        .order("win_rate", desc=True) \
        .limit(limit).execute()
    return result.data or []

def follow_trader(follower_id: str, following_id: str,
                  copy_enabled: bool = False,
                  copy_risk_pct: float = 1.0,
                  max_drawdown_pct: float = 10.0) -> dict:
    try:
        result = supabase.table("follows").upsert({
            "follower_id": follower_id,
            "following_id": following_id,
            "copy_enabled": copy_enabled,
            "copy_risk_pct": copy_risk_pct,
            "max_drawdown_pct": max_drawdown_pct,
        }).execute()
        _update_follower_count(following_id)
        return result.data[0] if result.data else {"follower_id": follower_id, "following_id": following_id}
    except Exception as e:
        import traceback
        raise RuntimeError(f"follow_trader failed: {e} | {traceback.format_exc()}")

def unfollow_trader(follower_id: str, following_id: str) -> dict:
    supabase.table("follows").delete() \
        .eq("follower_id", follower_id) \
        .eq("following_id", following_id).execute()
    _update_follower_count(following_id)
    return {"message": "Unfollowed successfully"}

def get_following(user_id: str) -> list:
    result = supabase.table("follows") \
        .select("*,strategy_profiles(display_name,win_rate,verified)") \
        .eq("follower_id", user_id).execute()
    return result.data or []

def get_followers(user_id: str) -> list:
    result = supabase.table("follows") \
        .select("follower_id,created_at") \
        .eq("following_id", user_id).execute()
    return result.data or []

def get_copy_subscribers(provider_id: str) -> list:
    result = supabase.table("follows") \
        .select("follower_id,copy_risk_pct,max_drawdown_pct") \
        .eq("following_id", provider_id) \
        .eq("copy_enabled", True).execute()
    return result.data or []

def _update_follower_count(user_id: str) -> None:
    count_result = supabase.table("follows") \
        .select("id", count="exact") \
        .eq("following_id", user_id).execute()
    count = count_result.count or 0
    supabase.table("strategy_profiles").upsert({"user_id": user_id, "followers": count}).execute()

def refresh_profile_stats(user_id: str) -> dict:
    """Recalculate win_rate/total_trades/pnl from paper_trades table."""
    trades = supabase.table("paper_trades") \
        .select("realized_pnl,status") \
        .eq("user_id", user_id) \
        .eq("status", "closed").execute()
    rows = trades.data or []
    total = len(rows)
    wins  = sum(1 for r in rows if (r.get("realized_pnl") or 0) > 0)
    pnl   = sum((r.get("realized_pnl") or 0) for r in rows)
    win_rate = round((wins / total * 100), 2) if total else 0
    update = {"win_rate": win_rate, "total_trades": total,
              "total_pnl_usd": round(pnl, 2),
              "updated_at": datetime.utcnow().isoformat()}
    supabase.table("strategy_profiles") \
        .update(update).eq("user_id", user_id).execute()
    return update


