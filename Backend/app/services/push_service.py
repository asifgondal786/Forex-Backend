"""
Phase 13 â€” Push Service
Sends Firebase Cloud Messaging push notifications using the Admin SDK.
The firebase-admin SDK is already initialized in main.py via
FIREBASE_SERVICE_ACCOUNT_JSON_B64 â€” no re-init needed here.
"""

import logging
from firebase_admin import messaging
from app.database import supabase

logger = logging.getLogger(__name__)


class PushService:

    def _get_tokens(self, user_id: str) -> list[str]:
        """Fetch all FCM tokens registered for a user."""
        rows = (
            supabase.table("device_push_tokens")
            .select("fcm_token")
            .eq("user_id", user_id)
            .execute()
        )
        return [r["fcm_token"] for r in (rows.data or [])]

    async def send(self, user_id: str, title: str, body: str, data: dict = None) -> dict:
        """
        Send a push notification to all of a user's registered devices.
        Returns a summary of successes and failures.
        """
        tokens = self._get_tokens(user_id)
        if not tokens:
            logger.info(f"[Push] No FCM tokens for user {user_id} â€” skipping")
            return {"sent": 0, "failed": 0}

        message = messaging.MulticastMessage(
            tokens  = tokens,
            notification = messaging.Notification(title=title, body=body),
            data    = {str(k): str(v) for k, v in (data or {}).items()},
            android = messaging.AndroidConfig(priority="high"),
            apns    = messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default")
                )
            )
        )

        response = messaging.send_each_for_multicast(message)
        logger.info(f"[Push] user={user_id} sent={response.success_count} failed={response.failure_count}")

        # Prune stale tokens that are no longer valid
        for idx, resp in enumerate(response.responses):
            if not resp.success:
                err_code = resp.exception.code if resp.exception else "unknown"
                if err_code in ("registration-token-not-registered", "invalid-registration-token"):
                    stale = tokens[idx]
                    supabase.table("device_push_tokens").delete().eq("fcm_token", stale).execute()
                    logger.info(f"[Push] Pruned stale token for user {user_id}")

        return {"sent": response.success_count, "failed": response.failure_count}