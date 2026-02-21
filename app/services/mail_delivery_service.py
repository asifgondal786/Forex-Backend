"""
Centralized email delivery service.
Supports Mailjet (preferred) and SMTP (fallback).
"""
import asyncio
import os
import re
import smtplib
from email.message import EmailMessage
from typing import Optional, Dict, Any

import aiohttp


_INVISIBLE_EMAIL_CHARS = re.compile(
    r"[\u0000-\u001F\u007F\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F-\u206F\u3000\uFEFF]"
)
_EMAIL_PATTERN = re.compile(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$")


def normalize_email(raw_email: str) -> str:
    return (
        str(raw_email or "")
        .replace("\n", "")
        .replace("\r", "")
        .replace("\t", "")
        .replace(" ", "")
        .strip()
        .lower()
    )


def sanitize_email(raw_email: str) -> str:
    normalized = normalize_email(raw_email)
    normalized = _INVISIBLE_EMAIL_CHARS.sub("", normalized)
    return normalized


def is_valid_email(email: str) -> bool:
    return bool(_EMAIL_PATTERN.match(email or ""))


class MailDeliveryService:
    def __init__(self):
        # Mailjet API config
        self.mailjet_api_key = (os.getenv("MAILJET_API_KEY") or "").strip()
        self.mailjet_secret_key = (os.getenv("MAILJET_SECRET_KEY") or "").strip()
        self.mailjet_from_email = sanitize_email(
            os.getenv("MAILJET_FROM_EMAIL") or os.getenv("SMTP_FROM") or ""
        )
        self.mailjet_from_name = (os.getenv("MAILJET_FROM_NAME") or "Forex Companion").strip()
        self.default_reply_to = sanitize_email(
            os.getenv("MAILJET_REPLY_TO")
            or os.getenv("SMTP_REPLY_TO")
            or self.mailjet_from_email
            or os.getenv("SMTP_FROM")
            or ""
        )
        self.mailjet_configured = bool(
            self.mailjet_api_key and self.mailjet_secret_key and self.mailjet_from_email
        )

        # SMTP fallback config
        self.smtp_host = (os.getenv("SMTP_HOST") or "").strip()
        self.smtp_port = int((os.getenv("SMTP_PORT") or "587").strip())
        self.smtp_user = (os.getenv("SMTP_USER") or "").strip()
        self.smtp_pass = (os.getenv("SMTP_PASS") or "").strip()
        self.smtp_from = sanitize_email(
            os.getenv("SMTP_FROM") or self.smtp_user or self.mailjet_from_email
        )
        self.smtp_tls = (os.getenv("SMTP_TLS") or "true").strip().lower() != "false"
        self.smtp_configured = bool(
            self.smtp_host and self.smtp_user and self.smtp_pass and self.smtp_from
        )

        self.email_configured = self.mailjet_configured or self.smtp_configured

    async def send_email(
        self,
        *,
        to_email: str,
        subject: str,
        text_body: str,
        html_body: Optional[str] = None,
        reply_to: Optional[str] = None,
    ) -> Dict[str, Any]:
        recipient = sanitize_email(to_email)
        if not is_valid_email(recipient):
            raise ValueError("Invalid recipient email.")
        if not self.email_configured:
            raise RuntimeError("Email provider is not configured.")

        subject = str(subject or "").strip()[:255]
        text_body = str(text_body or "").strip()
        html_body = (html_body or "").strip() or None
        reply_to_sanitized = sanitize_email(reply_to or self.default_reply_to or "")
        if reply_to_sanitized and not is_valid_email(reply_to_sanitized):
            reply_to_sanitized = ""

        if self.mailjet_configured:
            return await self._send_via_mailjet(
                to_email=recipient,
                subject=subject,
                text_body=text_body,
                html_body=html_body,
                reply_to=reply_to_sanitized or None,
            )

        return await self._send_via_smtp(
            to_email=recipient,
            subject=subject,
            text_body=text_body,
            html_body=html_body,
            reply_to=reply_to_sanitized or None,
        )

    async def _send_via_mailjet(
        self,
        *,
        to_email: str,
        subject: str,
        text_body: str,
        html_body: Optional[str],
        reply_to: Optional[str],
    ) -> Dict[str, Any]:
        payload = {
            "Messages": [
                {
                    "From": {
                        "Email": self.mailjet_from_email,
                        "Name": self.mailjet_from_name,
                    },
                    "To": [{"Email": to_email}],
                    "Subject": subject,
                    "TextPart": text_body,
                }
            ]
        }
        if html_body:
            payload["Messages"][0]["HTMLPart"] = html_body
        if reply_to:
            payload["Messages"][0]["ReplyTo"] = {"Email": reply_to}

        timeout = aiohttp.ClientTimeout(total=20)
        auth = aiohttp.BasicAuth(self.mailjet_api_key, self.mailjet_secret_key)
        async with aiohttp.ClientSession(timeout=timeout, auth=auth) as session:
            async with session.post(
                "https://api.mailjet.com/v3.1/send",
                json=payload,
                headers={"Content-Type": "application/json"},
            ) as response:
                body = await response.text()
                if response.status >= 400:
                    raise RuntimeError(
                        f"Mailjet send failed ({response.status}): {body[:300]}"
                    )
                return {
                    "provider": "mailjet",
                    "status_code": response.status,
                    "response": body[:300],
                }

    async def _send_via_smtp(
        self,
        *,
        to_email: str,
        subject: str,
        text_body: str,
        html_body: Optional[str],
        reply_to: Optional[str],
    ) -> Dict[str, Any]:
        def _send() -> None:
            msg = EmailMessage()
            msg["From"] = self.smtp_from
            msg["To"] = to_email
            msg["Subject"] = subject
            if reply_to:
                msg["Reply-To"] = reply_to
            msg.set_content(text_body)
            if html_body:
                msg.add_alternative(html_body, subtype="html")

            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=15) as server:
                if self.smtp_tls:
                    server.starttls()
                server.login(self.smtp_user, self.smtp_pass)
                server.send_message(msg)

        await asyncio.to_thread(_send)
        return {
            "provider": "smtp",
            "status_code": 200,
        }
