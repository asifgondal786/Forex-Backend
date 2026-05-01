"""
app/services/trial_expiry_service.py

Scheduled job that runs every hour and checks all users whose
10-day trial has expired. Sets trialExpired = True and isSubscribed = False
in Firestore so the Flutter real-time listener picks it up immediately.

Integration:
    In Backend/app/main.py add these lines in the startup section:

        from .services.trial_expiry_service import start_trial_expiry_scheduler
        start_trial_expiry_scheduler()

    That's it. The scheduler runs in the background automatically.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone, timedelta

logger = logging.getLogger(__name__)

# ── Firestore client ──────────────────────────────────────────────────────────
# Uses your existing firestore_client utility
try:
    from app.utils.firestore_client import get_firestore_client
    _FIRESTORE_AVAILABLE = True
except ImportError:
    _FIRESTORE_AVAILABLE = False
    logger.warning("trial_expiry_service: firestore_client not available")

# ── Constants ─────────────────────────────────────────────────────────────────
TRIAL_DAYS           = 10
CHECK_INTERVAL_SECS  = 3600   # run every 1 hour
USERS_COLLECTION     = "users"


# ── Core expiry check ─────────────────────────────────────────────────────────
async def check_and_expire_trials() -> dict:
    """
    Scans the Firestore 'users' collection for users whose trial has expired
    but whose trialExpired flag is not yet set to True.

    Returns a dict with counts for logging/monitoring.
    """
    if not _FIRESTORE_AVAILABLE:
        logger.warning("check_and_expire_trials: Firestore not available, skipping")
        return {"checked": 0, "expired": 0, "errors": 0}

    db = get_firestore_client()
    now = datetime.now(timezone.utc)
    trial_cutoff = now - timedelta(days=TRIAL_DAYS)

    expired_count = 0
    error_count   = 0
    checked_count = 0

    try:
        # Query users who:
        # 1. Have a trialStartDate set (signed up)
        # 2. Are NOT already marked as trialExpired
        # 3. Are NOT subscribed (no need to touch paying users)
        users_ref = db.collection(USERS_COLLECTION)

        # Firestore doesn't support complex multi-condition queries easily,
        # so we filter in Python after fetching candidates
        # Only fetch users where trialExpired != True to keep query small
        candidates = users_ref.where("trialExpired", "!=", True).stream()

        batch = db.batch()
        batch_count = 0

        for user_doc in candidates:
            checked_count += 1
            try:
                data = user_doc.to_dict()
                if not data:
                    continue

                # Skip already subscribed users
                if data.get("isSubscribed", False):
                    continue

                # Get trial start date
                trial_start_raw = data.get("trialStartDate")
                if trial_start_raw is None:
                    continue

                # Normalise to datetime
                if hasattr(trial_start_raw, "datetime"):
                    # Firestore Timestamp object
                    trial_start = trial_start_raw.datetime.replace(tzinfo=timezone.utc)
                elif isinstance(trial_start_raw, str):
                    trial_start = datetime.fromisoformat(
                        trial_start_raw.replace("Z", "+00:00")
                    )
                else:
                    continue

                # Check if trial has expired
                if trial_start <= trial_cutoff:
                    # Mark as expired in Firestore
                    user_ref = users_ref.document(user_doc.id)
                    batch.update(user_ref, {
                        "trialExpired": True,
                        "trialExpiredAt": now.isoformat(),
                    })
                    batch_count += 1
                    expired_count += 1

                    logger.info(
                        f"Trial expired: user={user_doc.id} "
                        f"started={trial_start.date()} "
                        f"expired={now.date()}"
                    )

                    # Commit in batches of 500 (Firestore limit)
                    if batch_count >= 499:
                        batch.commit()
                        batch = db.batch()
                        batch_count = 0

            except Exception as user_err:
                error_count += 1
                logger.error(
                    f"trial_expiry_service: error processing user "
                    f"{user_doc.id}: {user_err}"
                )

        # Commit remaining batch
        if batch_count > 0:
            batch.commit()

    except Exception as e:
        logger.error(f"trial_expiry_service: scan failed: {e}")
        error_count += 1

    result = {
        "checked": checked_count,
        "expired": expired_count,
        "errors":  error_count,
        "ran_at":  now.isoformat(),
    }
    logger.info(f"trial_expiry_service: run complete {result}")
    return result


# ── Scheduler ─────────────────────────────────────────────────────────────────
async def _scheduler_loop() -> None:
    """Runs check_and_expire_trials every CHECK_INTERVAL_SECS seconds."""
    logger.info(
        f"trial_expiry_service: scheduler started "
        f"(interval={CHECK_INTERVAL_SECS}s)"
    )
    while True:
        try:
            await check_and_expire_trials()
        except Exception as e:
            logger.error(f"trial_expiry_service: scheduler loop error: {e}")
        await asyncio.sleep(CHECK_INTERVAL_SECS)


def start_trial_expiry_scheduler() -> None:
    """
    Call this once during FastAPI startup.
    Creates a background asyncio task for the scheduler loop.
    """
    try:
        loop = asyncio.get_event_loop()
        loop.create_task(_scheduler_loop())
        logger.info("trial_expiry_service: background scheduler registered")
    except RuntimeError as e:
        logger.error(f"trial_expiry_service: could not start scheduler: {e}")


# ── FastAPI route (optional admin endpoint) ───────────────────────────────────
# Add this router to main.py if you want to manually trigger the check
# from your admin panel or Postman during testing.
#
# Usage in main.py:
#   from .services.trial_expiry_service import trial_admin_router
#   app.include_router(trial_admin_router)

from fastapi import APIRouter, Depends
from app.security import get_current_user_id   # reuse existing auth

trial_admin_router = APIRouter(
    prefix="/api/v1/admin/trial",
    tags=["admin"],
)

@trial_admin_router.post("/run-expiry-check")
async def manual_expiry_check(user_id: str = Depends(get_current_user_id)):
    """
    Manually trigger the trial expiry check.
    Useful for testing without waiting for the hourly scheduler.
    Protected — requires a valid Firebase auth token.
    """
    result = await check_and_expire_trials()
    return {"status": "ok", "result": result}
