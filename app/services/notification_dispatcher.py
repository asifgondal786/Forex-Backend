"""
Phase 13 — Notification Dispatcher
Central fan-out for all notification channels.
Services call dispatcher.dispatch() — it handles channel selection,
user preferences, severity routing, and logging.

Usage:
    dispatcher = NotificationDispatcher()
    await dispatcher.dispatch(user_id, "trade", {"pair": "EUR/USD", ...})
"""

import os
import logging
from datetime import datetime, timezone
from typing import Optional

import sib_api_v3_sdk                                  # Brevo — already installed
from sib_api_v3_sdk.rest import ApiException
from app.services.push_service import PushService
from app.services.twilio_service import TwilioService
from app.database import supabase

logger = logging.getLogger(__name__)

# ── Brevo template IDs (set in Railway Variables) ──────────────────────────
TEMPLATE_IDS = {
    "trade":  int(os.environ.get("BREVO_TRADE_TEMPLATE_ID",  "0")),
    "risk":   int(os.environ.get("BREVO_RISK_TEMPLATE_ID",   "0")),
    "signal": int(os.environ.get("BREVO_SIGNAL_TEMPLATE_ID", "0")),
    "market": int(os.environ.get("BREVO_MARKET_TEMPLATE_ID", "0")),
}

# ── Severity: which channels fire per event ────────────────────────────────
# "high"   → email + push + whatsapp/sms
# "medium" → email + push
# "low"    → email only
SEVERITY = {
    "trade":  "medium",
    "risk":   "high",
    "signal": "low",
    "market": "low",
}

# ── Human-readable push titles ─────────────────────────────────────────────
PUSH_TITLES = {
    "trade":  "Trade Executed",
    "risk":   "Risk Warning",
    "signal": "New AI Signal",
    "market": "Market Alert",
}

PUSH_BODIES = {
    "trade":  lambda p: f"{p.get('direction','?')} {p.get('pair','?')} @ {p.get('price','?')}",
    "risk":   lambda p: f"{p.get('pair','?')} drawdown {p.get('drawdown','?')} — review now",
    "signal": lambda p: f"{p.get('pair','?')}: {p.get('signal','?')} — {p.get('confidence','?')} confidence",
    "market": lambda p: f"{p.get('pair','?')}: {p.get('event','?')} at {p.get('time','?')}",
}


class NotificationDispatcher:

    def __init__(self):
        self.push   = PushService()
        self.twilio = TwilioService()
        brevo_cfg   = sib_api_v3_sdk.Configuration()
        brevo_cfg.api_key["api-key"] = os.environ.get("BREVO_API_KEY", "")
        self.brevo  = sib_api_v3_sdk.TransactionalEmailsApi(sib_api_v3_sdk.ApiClient(brevo_cfg))

    # ── Internal helpers ───────────────────────────────────────────────────

    def _get_user(self, user_id: str) -> dict:
        """Fetch user email + notification prefs from Supabase."""
        row = (
            supabase.table("users")
            .select("email, email_enabled, push_enabled, whatsapp_enabled")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        return row.data or {}

    def _log(self, user_id: str, channel: str, event_type: str, payload: dict, status: str):
        """Write one row to notification_log."""
        try:
            supabase.table("notification_log").insert({
                "user_id":    user_id,
                "channel":    channel,
                "event_type": event_type,
                "payload":    payload,
                "status":     status,
                "sent_at":    datetime.now(timezone.utc).isoformat(),
            }).execute()
        except Exception as e:
            logger.error(f"[Dispatcher] Log write failed: {e}")

    async def _send_email(self, user: dict, event_type: str, payload: dict):
        template_id = TEMPLATE_IDS.get(event_type, 0)
        if not template_id:
            logger.warning(f"[Dispatcher] No Brevo template ID for event: {event_type}")
            return
        try:
            send_email = sib_api_v3_sdk.SendSmtpEmail(
                to=[{"email": user["email"]}],
                template_id=template_id,
                params=payload,
            )
            self.brevo.send_transac_email(send_email)
            logger.info(f"[Dispatcher] Email sent: {event_type} → {user['email']}")
            return "sent"
        except ApiException as e:
            logger.error(f"[Dispatcher] Brevo error: {e}")
            return "failed"

    async def _send_push(self, user_id: str, event_type: str, payload: dict):
        title = PUSH_TITLES.get(event_type, "Tajir Alert")
        body  = PUSH_BODIES.get(event_type, lambda p: str(p))(payload)
        result = await self.push.send(user_id, title, body, {"event_type": event_type})
        return "sent" if result["sent"] > 0 else "no_devices"

    # ── Public interface ───────────────────────────────────────────────────

    async def dispatch(
        self,
        user_id:    str,
        event_type: str,
        payload:    dict,
        channels:   Optional[list] = None   # override for test endpoints
    ):
        """
        Fan-out notification to all appropriate channels.
        channels param pins which channels fire (used by test endpoints).
        """
        user     = self._get_user(user_id)
        severity = SEVERITY.get(event_type, "low")
        if channels is None:
            channels = self._resolve_channels(user, severity)

        for ch in channels:
            status = "skipped"
            try:
                if ch == "email" and user.get("email_enabled", True):
                    status = await self._send_email(user, event_type, payload) or "sent"
                elif ch == "push" and user.get("push_enabled", True):
                    status = await self._send_push(user_id, event_type, payload)
                elif ch == "whatsapp" and user.get("whatsapp_enabled", False):
                    ok = await self.twilio.send_whatsapp(user_id, event_type, payload)
                    status = "sent" if ok else "failed"
                elif ch == "sms" and user.get("whatsapp_enabled", False):
                    ok = await self.twilio.send_sms(user_id, event_type, payload)
                    status = "sent" if ok else "failed"
            except Exception as e:
                logger.error(f"[Dispatcher] Channel {ch} failed for {user_id}: {e}")
                status = "error"
            finally:
                self._log(user_id, ch, event_type, payload, status)

    def _resolve_channels(self, user: dict, severity: str) -> list:
        if severity == "high":
            return ["email", "push", "whatsapp", "sms"]
        elif severity == "medium":
            return ["email", "push"]
        else:
            return ["email"]