"""
trial_expiry_service.py
Scans the 'user_subscriptions' table in Supabase for users whose trial has expired
and updates their status accordingly. Sends notification via event bus.
"""

import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException

from app.database import supabase
from app.auth import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trial", tags=["Trial Management"])


async def check_and_expire_trials(dry_run: bool = False) -> dict:
    """
    Scans subscriptions for expired trials and updates their status.
    
    Returns:
        dict with counts of expired, already_expired, errors
    """
    if not supabase:
        logger.warning("check_and_expire_trials: Supabase not available, skipping")
        return {"status": "skipped", "reason": "supabase_not_configured"}

    now = datetime.now(timezone.utc).isoformat()
    
    try:
        # Find all trialing subscriptions where trial has ended
        result = (
            supabase.table("user_subscriptions")
            .select("id, user_id, trial_ends_at, plan")
            .eq("status", "trialing")
            .lt("trial_ends_at", now)
            .execute()
        )

        expired_subs = result.data or []
        
        if not expired_subs:
            return {"status": "ok", "expired_count": 0, "message": "No expired trials found"}

        expired_count = 0
        errors = []

        for sub in expired_subs:
            try:
                if not dry_run:
                    # Update subscription status
                    supabase.table("user_subscriptions").update({
                        "status": "expired",
                        "plan": "free",
                    }).eq("id", sub["id"]).execute()

                    # Update user's subscription tier
                    supabase.table("users").update({
                        "subscription_tier": "free",
                    }).eq("id", sub["user_id"]).execute()

                    # Publish event for notification
                    try:
                        from app.services.event_bus import publish_event, EventType
                        await publish_event(
                            EventType.USER_SUBSCRIPTION_CHANGED,
                            payload={
                                "previous_plan": sub.get("plan", "basic"),
                                "new_plan": "free",
                                "reason": "trial_expired",
                            },
                            user_id=sub["user_id"],
                        )
                    except Exception as notify_err:
                        logger.warning("Failed to publish trial expiry event: %s", notify_err)

                expired_count += 1
                logger.info(
                    "Trial expired | user=%s | plan=%s | trial_ended=%s",
                    sub["user_id"], sub.get("plan"), sub.get("trial_ends_at"),
                )

            except Exception as e:
                errors.append({"user_id": sub["user_id"], "error": str(e)})
                logger.error("Failed to expire trial for user %s: %s", sub["user_id"], e)

        return {
            "status": "ok",
            "expired_count": expired_count,
            "dry_run": dry_run,
            "errors": errors if errors else None,
        }

    except Exception as e:
        logger.error("check_and_expire_trials failed: %s", e, exc_info=True)
        return {"status": "error", "error": str(e)}


# ─── API Endpoints ───────────────────────────────────────────────────────────

@router.post("/check-expired")
async def run_trial_check(
    dry_run: bool = False,
    user=Depends(get_current_user),
):
    """
    Manually trigger trial expiry check.
    Protected — requires a valid Firebase auth token.
    In production, this is called by a cron job / scheduled task.
    """
    result = await check_and_expire_trials(dry_run=dry_run)
    return result


@router.get("/status")
async def get_trial_status(user=Depends(get_current_user)):
    """Get current user's trial/subscription status."""
    if not supabase:
        raise HTTPException(status_code=503, detail="Database not configured")

    uid = user.get("uid") or user.get("user_id")
    
    result = (
        supabase.table("user_subscriptions")
        .select("*")
        .eq("user_id", uid)
        .order("created_at", desc=True)
        .limit(1)
        .execute()
    )

    if not result.data:
        return {"status": "no_subscription", "plan": "free"}

    sub = result.data[0]
    return {
        "plan": sub.get("plan", "free"),
        "status": sub.get("status", "active"),
        "trial_ends_at": sub.get("trial_ends_at"),
        "current_period_end": sub.get("current_period_end"),
    }


# ─── Scheduler (called by main.py on startup) ────────────────────────────────

import asyncio
from contextlib import asynccontextmanager

_scheduler_task = None


async def _trial_check_loop(interval_hours: int = 6):
    """Background task that periodically checks for expired trials."""
    while True:
        try:
            result = await check_and_expire_trials()
            logger.info("Trial expiry check completed: %s", result)
        except Exception as e:
            logger.error("Trial expiry scheduler error: %s", e)
        await asyncio.sleep(interval_hours * 3600)


def start_trial_expiry_scheduler():
    """
    Start the background trial expiry checker.
    Called by main.py during app startup.
    """
    global _scheduler_task
    try:
        loop = asyncio.get_event_loop()
        _scheduler_task = loop.create_task(_trial_check_loop())
        logger.info("Trial expiry scheduler started (checks every 6 hours)")
    except Exception as e:
        logger.warning("Could not start trial expiry scheduler: %s", e)


def stop_trial_expiry_scheduler():
    """Stop the background scheduler."""
    global _scheduler_task
    if _scheduler_task:
        _scheduler_task.cancel()
        _scheduler_task = None
        logger.info("Trial expiry scheduler stopped")

