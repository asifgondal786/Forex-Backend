from fastapi import APIRouter, Depends, HTTPException, Request, Body
from app.services.social_service import (
    get_profile, upsert_profile, get_leaderboard,
    follow_trader, unfollow_trader, get_following,
    get_followers, refresh_profile_stats)
from app.services.copy_trade_service import (
    get_copy_history, get_copy_performance)
from app.services.autonomous_service import (
    get_auto_config, upsert_auto_config,
    enable_autonomous, disable_autonomous,
    get_auto_log, evaluate_and_execute)
from app.auth import get_current_user
from app.limiter import limiter

router = APIRouter(prefix="/api/v1/social", tags=["social"])

# --- Strategy profiles ---
@router.get("/profile/me")
async def my_profile(current_user=Depends(get_current_user)):
    profile = get_profile(str(current_user["uid"]))
    return profile or {"message": "No profile yet. Create one with POST /profile"}

@router.post("/profile")
@limiter.limit("10/minute")
async def create_or_update_profile(request: Request, body: dict = Body(...), current_user=Depends(get_current_user)):
    allowed = {"display_name","bio","is_public","trading_style","pairs_traded"}
    data = {k: v for k, v in body.items() if k in allowed}
    return upsert_profile(str(current_user["uid"]), data)

@router.get("/profile/{user_id}")
async def get_public_profile(user_id: str):
    profile = get_profile(user_id)
    if not profile or not profile.get("is_public"):
        raise HTTPException(404, "Profile not found or not public")
    return profile

@router.post("/profile/refresh-stats")
async def refresh_stats(current_user=Depends(get_current_user)):
    return refresh_profile_stats(str(current_user["uid"]))

# --- Leaderboard ---
@router.get("/leaderboard")
async def leaderboard(limit: int = 20):
    return {"leaderboard": get_leaderboard(min(limit, 100))}

# --- Follows ---
@router.post("/follow/{user_id}")
@limiter.limit("20/minute")
async def follow(request: Request, user_id: str, body: dict = Body(default={}), current_user=Depends(get_current_user)):
    if str(current_user["uid"]) == user_id:
        raise HTTPException(400, "Cannot follow yourself")
    return follow_trader(
        follower_id=str(current_user["uid"]),
        following_id=user_id,
        copy_enabled=body.get("copy_enabled", False),
        copy_risk_pct=float(body.get("copy_risk_pct", 1.0)),
        max_drawdown_pct=float(body.get("max_drawdown_pct", 10.0)),
    )

@router.delete("/follow/{user_id}")
async def unfollow(user_id: str, current_user=Depends(get_current_user)):
    return unfollow_trader(str(current_user["uid"]), user_id)

@router.get("/following")
async def my_following(current_user=Depends(get_current_user)):
    return {"following": get_following(str(current_user["uid"]))}

@router.get("/followers")
async def my_followers(current_user=Depends(get_current_user)):
    return {"followers": get_followers(str(current_user["uid"]))}

# --- Copy trading ---
@router.get("/copy/history")
async def copy_history(limit: int = 50, current_user=Depends(get_current_user)):
    return {"trades": get_copy_history(str(current_user["uid"]), limit)}

@router.get("/copy/performance")
async def copy_performance(current_user=Depends(get_current_user)):
    return get_copy_performance(str(current_user["uid"]))

# --- Autonomous mode ---
@router.get("/auto/config")
async def get_config(current_user=Depends(get_current_user)):
    config = get_auto_config(str(current_user["uid"]))
    return config or {"enabled": False, "message": "No config yet. POST /auto/config to set up"}

@router.post("/auto/config")
async def set_config(body: dict = Body(...), current_user=Depends(get_current_user)):
    allowed = {"max_daily_trades","max_risk_per_trade","max_daily_drawdown",
               "min_confidence","allowed_pairs","pause_on_news",
               "news_pause_minutes","trade_mode"}
    data = {k: v for k, v in body.items() if k in allowed}
    return upsert_auto_config(str(current_user["uid"]), data)

@router.post("/auto/enable")
async def enable_auto(current_user=Depends(get_current_user)):
    config = get_auto_config(str(current_user["uid"]))
    if not config:
        raise HTTPException(400, "Set up auto config first with POST /auto/config")
    return enable_autonomous(str(current_user["uid"]))

@router.post("/auto/disable")
async def disable_auto(current_user=Depends(get_current_user)):
    return disable_autonomous(str(current_user["uid"]))

@router.get("/auto/log")
async def auto_log(limit: int = 50, current_user=Depends(get_current_user)):
    return {"log": get_auto_log(str(current_user["uid"]), limit)}

@router.post("/auto/evaluate")
@limiter.limit("30/minute")
async def evaluate_signal(request: Request, body: dict = Body(...), current_user=Depends(get_current_user)):
    """Manually trigger autonomous evaluation against a signal."""
    return await evaluate_and_execute(str(current_user["uid"]), body)
