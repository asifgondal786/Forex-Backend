"""
Phase 13 — Twilio Service
Sends WhatsApp messages and SMS for high-priority events.
Requires: pip install twilio
"""

import os
import logging
from twilio.rest import Client
from app.database import supabase

logger = logging.getLogger(__name__)

ACCOUNT_SID      = os.environ.get("TWILIO_ACCOUNT_SID")
AUTH_TOKEN       = os.environ.get("TWILIO_AUTH_TOKEN")
WHATSAPP_FROM    = os.environ.get("TWILIO_WHATSAPP_FROM", "whatsapp:+14155238886")  # Twilio sandbox default
SMS_FROM         = os.environ.get("TWILIO_SMS_FROM")

# Event → message templates
TEMPLATES = {
    "trade": {
        "whatsapp": "Tajir Trade Alert\nPair: {pair}\nDirection: {direction}\nPrice: {price}\nSize: {size}",
        "sms":      "Tajir: {direction} {pair} @ {price} executed.",
    },
    "risk": {
        "whatsapp": "Tajir Risk Warning\nPair: {pair}\nDrawdown: {drawdown} (threshold: {threshold})\nReview your positions.",
        "sms":      "Tajir Risk: {pair} drawdown {drawdown} exceeded {threshold} limit.",
    },
}


class TwilioService:

    def __init__(self):
        if ACCOUNT_SID and AUTH_TOKEN:
            self.client = Client(ACCOUNT_SID, AUTH_TOKEN)
        else:
            self.client = None
            logger.warning("[Twilio] Credentials not set — service disabled")

    def _get_phone(self, user_id: str) -> str | None:
        """Fetch user phone number from Supabase users table."""
        row = (
            supabase.table("users")
            .select("phone_number, whatsapp_enabled")
            .eq("id", user_id)
            .maybe_single()
            .execute()
        )
        if row.data and row.data.get("whatsapp_enabled"):
            return row.data.get("phone_number")
        return None

    async def send_whatsapp(self, user_id: str, event_type: str, payload: dict) -> bool:
        """Send a WhatsApp message. Returns True on success."""
        if not self.client:
            return False
        phone = self._get_phone(user_id)
        if not phone:
            return False

        template = TEMPLATES.get(event_type, {}).get("whatsapp")
        if not template:
            logger.info(f"[Twilio] No WhatsApp template for event: {event_type}")
            return False

        try:
            body = template.format(**payload)
            self.client.messages.create(
                from_=WHATSAPP_FROM,
                to=f"whatsapp:{phone}",
                body=body
            )
            logger.info(f"[Twilio] WhatsApp sent to user {user_id}")
            return True
        except Exception as e:
            logger.error(f"[Twilio] WhatsApp failed for user {user_id}: {e}")
            return False

    async def send_sms(self, user_id: str, event_type: str, payload: dict) -> bool:
        """Send an SMS. Returns True on success."""
        if not self.client or not SMS_FROM:
            return False
        phone = self._get_phone(user_id)
        if not phone:
            return False

        template = TEMPLATES.get(event_type, {}).get("sms")
        if not template:
            return False

        try:
            body = template.format(**payload)
            self.client.messages.create(from_=SMS_FROM, to=phone, body=body)
            logger.info(f"[Twilio] SMS sent to user {user_id}")
            return True
        except Exception as e:
            logger.error(f"[Twilio] SMS failed for user {user_id}: {e}")
            return False