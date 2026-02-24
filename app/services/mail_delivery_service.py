"""
Centralized email delivery service.
Supports Brevo (preferred), Mailjet, and SMTP fallback.
"""
import asyncio
import json
import os
import re
import smtplib
from email.message import EmailMessage
from typing import Any, Dict, List, Optional

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


class MailDeliveryError(RuntimeError):
    def __init__(
        self,
        message: str,
        *,
        provider: str,
        category: str,
        status_code: Optional[int] = None,
        response_excerpt: str = "",
    ):
        super().__init__(message)
        self.provider = provider
        self.category = category
        self.status_code = status_code
        self.response_excerpt = (response_excerpt or "")[:400]


class MailDeliveryService:
    def __init__(self):
        # Provider preference: auto, brevo, mailjet, smtp
        self.email_provider = (os.getenv("EMAIL_PROVIDER") or "auto").strip().lower()

        # Brevo API config
        self.brevo_api_key = (
            os.getenv("BREVO_API_KEY")
            or os.getenv("SENDINBLUE_API_KEY")
            or os.getenv("SIB_API_KEY")
            or ""
        ).strip()
        self.brevo_from_email = sanitize_email(
            os.getenv("BREVO_FROM_EMAIL")
            or os.getenv("MAILJET_FROM_EMAIL")
            or os.getenv("SMTP_FROM")
            or ""
        )
        self.brevo_from_name = (
            os.getenv("BREVO_FROM_NAME")
            or os.getenv("MAILJET_FROM_NAME")
            or "Forex Companion"
        ).strip()
        self.brevo_reply_to = sanitize_email(os.getenv("BREVO_REPLY_TO") or "")
        self.brevo_configured = bool(self.brevo_api_key and self.brevo_from_email)

        # Mailjet API config
        self.mailjet_api_key = (
            os.getenv("MAILJET_API_KEY") or os.getenv("MJ_APIKEY_PUBLIC") or ""
        ).strip()
        self.mailjet_secret_key = (
            os.getenv("MAILJET_SECRET_KEY") or os.getenv("MJ_APIKEY_PRIVATE") or ""
        ).strip()
        self.mailjet_from_email = sanitize_email(
            os.getenv("MAILJET_FROM_EMAIL")
            or self.brevo_from_email
            or os.getenv("SMTP_FROM")
            or ""
        )
        self.mailjet_from_name = (os.getenv("MAILJET_FROM_NAME") or "Forex Companion").strip()
        self.mailjet_configured = bool(
            self.mailjet_api_key and self.mailjet_secret_key and self.mailjet_from_email
        )

        self.default_reply_to = sanitize_email(
            self.brevo_reply_to
            or os.getenv("MAILJET_REPLY_TO")
            or os.getenv("SMTP_REPLY_TO")
            or self.mailjet_from_email
            or self.brevo_from_email
            or os.getenv("SMTP_FROM")
            or ""
        )

        # SMTP fallback config
        self.smtp_host = (os.getenv("SMTP_HOST") or "").strip()
        self.smtp_port = int((os.getenv("SMTP_PORT") or "587").strip())
        self.smtp_user = (os.getenv("SMTP_USER") or "").strip()
        self.smtp_pass = (os.getenv("SMTP_PASS") or "").strip()
        self.smtp_from = sanitize_email(
            os.getenv("SMTP_FROM")
            or self.smtp_user
            or self.brevo_from_email
            or self.mailjet_from_email
        )
        self.smtp_tls = (os.getenv("SMTP_TLS") or "true").strip().lower() != "false"
        self.smtp_configured = bool(
            self.smtp_host and self.smtp_user and self.smtp_pass and self.smtp_from
        )

        self.email_configured = (
            self.brevo_configured or self.mailjet_configured or self.smtp_configured
        )

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

        errors: List[Exception] = []
        for provider in self._provider_order():
            try:
                if provider == "brevo" and self.brevo_configured:
                    return await self._send_via_brevo(
                        to_email=recipient,
                        subject=subject,
                        text_body=text_body,
                        html_body=html_body,
                        reply_to=reply_to_sanitized or None,
                    )
                if provider == "mailjet" and self.mailjet_configured:
                    return await self._send_via_mailjet(
                        to_email=recipient,
                        subject=subject,
                        text_body=text_body,
                        html_body=html_body,
                        reply_to=reply_to_sanitized or None,
                    )
                if provider == "smtp" and self.smtp_configured:
                    return await self._send_via_smtp(
                        to_email=recipient,
                        subject=subject,
                        text_body=text_body,
                        html_body=html_body,
                        reply_to=reply_to_sanitized or None,
                    )
            except MailDeliveryError as exc:
                errors.append(exc)
                # Invalid recipient is deterministic; don't retry other providers.
                if exc.category == "invalid_recipient":
                    raise
                continue
            except Exception as exc:
                errors.append(exc)
                continue

        if errors:
            last_error = errors[-1]
            if isinstance(last_error, MailDeliveryError):
                raise last_error
            raise RuntimeError(f"Email send failed: {last_error}")

        raise RuntimeError("Email provider is not configured.")

    def _provider_order(self) -> List[str]:
        preferred = self.email_provider
        if preferred == "brevo":
            return ["brevo", "smtp"]
        if preferred == "mailjet":
            return ["mailjet", "smtp"]
        if preferred == "smtp":
            return ["smtp"]
        # Auto mode default: Brevo first, then Mailjet, then SMTP.
        return ["brevo", "mailjet", "smtp"]

    async def _send_via_brevo(
        self,
        *,
        to_email: str,
        subject: str,
        text_body: str,
        html_body: Optional[str],
        reply_to: Optional[str],
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "sender": {
                "email": self.brevo_from_email,
                "name": self.brevo_from_name,
            },
            "to": [{"email": to_email}],
            "subject": subject,
            "textContent": text_body,
        }
        if html_body:
            payload["htmlContent"] = html_body
        if reply_to:
            payload["replyTo"] = {"email": reply_to}

        timeout = aiohttp.ClientTimeout(total=20)
        headers = {
            "accept": "application/json",
            "content-type": "application/json",
            "api-key": self.brevo_api_key,
        }
        async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
            async with session.post(
                "https://api.brevo.com/v3/smtp/email",
                json=payload,
            ) as response:
                body = await response.text()
                parsed = self._parse_json(body)
                if response.status >= 400:
                    reason = self._extract_provider_error(parsed, body)
                    category = self._classify_mail_error(reason, response.status)
                    raise MailDeliveryError(
                        f"Brevo send failed ({response.status}): {reason}",
                        provider="brevo",
                        category=category,
                        status_code=response.status,
                        response_excerpt=body,
                    )
                message_id = None
                if isinstance(parsed, dict):
                    raw_id = parsed.get("messageId") or parsed.get("messageID")
                    if raw_id is not None:
                        message_id = str(raw_id)
                return {
                    "provider": "brevo",
                    "status_code": response.status,
                    "message_id": message_id,
                    "response": body[:300],
                }

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
                parsed = self._parse_json(body)
                if response.status >= 400:
                    reason = self._extract_mailjet_response_error(parsed, body)
                    category = self._classify_mail_error(reason, response.status)
                    raise MailDeliveryError(
                        f"Mailjet send failed ({response.status}): {reason}",
                        provider="mailjet",
                        category=category,
                        status_code=response.status,
                        response_excerpt=body,
                    )

                # Mailjet can return HTTP 200 even when message status is "error".
                message_errors: List[str] = []
                message_ids: List[str] = []
                messages = parsed.get("Messages") if isinstance(parsed, dict) else None
                if isinstance(messages, list):
                    for message in messages:
                        if not isinstance(message, dict):
                            continue
                        status = str(message.get("Status") or "").strip().lower()
                        if status and status != "success":
                            message_errors.append(self._extract_mailjet_message_error(message))
                        to_recipients = message.get("To")
                        if isinstance(to_recipients, list):
                            for recipient in to_recipients:
                                if isinstance(recipient, dict):
                                    message_id = recipient.get("MessageID") or recipient.get(
                                        "MessageUUID"
                                    )
                                    if message_id is not None:
                                        message_ids.append(str(message_id))
                if message_errors:
                    reason = " | ".join(message_errors)
                    category = self._classify_mail_error(reason, response.status)
                    raise MailDeliveryError(
                        f"Mailjet rejected message: {reason}",
                        provider="mailjet",
                        category=category,
                        status_code=response.status,
                        response_excerpt=body,
                    )

                return {
                    "provider": "mailjet",
                    "status_code": response.status,
                    "message_ids": message_ids,
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

    async def check_brevo_status(self) -> Dict[str, Any]:
        if not self.brevo_configured:
            return {
                "provider": "brevo",
                "configured": False,
                "sender": self.brevo_from_email,
            }

        timeout = aiohttp.ClientTimeout(total=20)
        headers = {
            "accept": "application/json",
            "api-key": self.brevo_api_key,
        }
        async with aiohttp.ClientSession(timeout=timeout, headers=headers) as session:
            async with session.get("https://api.brevo.com/v3/senders") as response:
                body = await response.text()
                parsed = self._parse_json(body)
                sender_status = "unknown"
                sender_verified: Optional[bool] = None

                if response.status < 400:
                    senders = parsed.get("senders") if isinstance(parsed, dict) else None
                    matched_sender: Dict[str, Any] = {}
                    if isinstance(senders, list):
                        for sender in senders:
                            if not isinstance(sender, dict):
                                continue
                            email = sanitize_email(sender.get("email") or "")
                            if email == self.brevo_from_email:
                                matched_sender = sender
                                break
                    if matched_sender:
                        sender_verified = bool(matched_sender.get("active"))
                        sender_status = "active" if sender_verified else "inactive"
                    else:
                        sender_status = "not_found"
                        sender_verified = False
                else:
                    reason = self._extract_provider_error(parsed, body)
                    sender_status = f"error: {reason[:120]}"
                    sender_verified = False

                return {
                    "provider": "brevo",
                    "configured": True,
                    "sender": self.brevo_from_email,
                    "status_code": response.status,
                    "sender_status": sender_status,
                    "sender_verified": sender_verified,
                    "response": body[:300],
                }

    async def check_mailjet_sender_status(self) -> Dict[str, Any]:
        if not self.mailjet_configured:
            return {
                "provider": "mailjet",
                "configured": False,
                "sender": self.mailjet_from_email,
            }

        timeout = aiohttp.ClientTimeout(total=20)
        auth = aiohttp.BasicAuth(self.mailjet_api_key, self.mailjet_secret_key)
        async with aiohttp.ClientSession(timeout=timeout, auth=auth) as session:
            async with session.get(
                "https://api.mailjet.com/v3/REST/sender",
                params={"Email": self.mailjet_from_email},
            ) as response:
                body = await response.text()
                parsed = self._parse_json(body)
                sender_entry: Dict[str, Any] = {}
                data = parsed.get("Data") if isinstance(parsed, dict) else None
                if isinstance(data, list) and data and isinstance(data[0], dict):
                    sender_entry = data[0]

                sender_status = str(
                    sender_entry.get("Status")
                    or sender_entry.get("DNSStatus")
                    or sender_entry.get("State")
                    or "unknown"
                ).strip()
                sender_verified = sender_status.lower() in {
                    "active",
                    "verified",
                    "valid",
                } or bool(sender_entry.get("IsValid"))
                return {
                    "provider": "mailjet",
                    "configured": True,
                    "sender": self.mailjet_from_email,
                    "status_code": response.status,
                    "sender_status": sender_status,
                    "sender_verified": sender_verified,
                    "response": body[:300],
                }

    def _parse_json(self, body: str) -> Dict[str, Any]:
        if not body:
            return {}
        try:
            parsed = json.loads(body)
        except json.JSONDecodeError:
            return {}
        return parsed if isinstance(parsed, dict) else {}

    def _extract_provider_error(self, parsed: Dict[str, Any], raw_body: str) -> str:
        if parsed:
            direct_error = (
                parsed.get("ErrorMessage")
                or parsed.get("message")
                or parsed.get("Message")
                or parsed.get("error")
                or parsed.get("Error")
            )
            if direct_error:
                return str(direct_error)
            errors = parsed.get("errors")
            if isinstance(errors, list) and errors:
                return "; ".join(str(item) for item in errors[:3])
            code = parsed.get("code")
            if code:
                return str(code)
        return (raw_body or "unknown provider error")[:300]

    def _extract_mailjet_message_error(self, message_payload: Dict[str, Any]) -> str:
        status = str(message_payload.get("Status") or "").strip()
        errors = message_payload.get("Errors")
        if isinstance(errors, list) and errors:
            formatted_errors = []
            for error_item in errors:
                if isinstance(error_item, dict):
                    text = (
                        error_item.get("ErrorMessage")
                        or error_item.get("Message")
                        or error_item.get("ErrorIdentifier")
                        or str(error_item)
                    )
                else:
                    text = str(error_item)
                formatted_errors.append(str(text))
            return "; ".join(formatted_errors)
        if status and status.lower() != "success":
            return f"status={status}"
        return "unknown Mailjet delivery error"

    def _extract_mailjet_response_error(self, parsed: Dict[str, Any], raw_body: str) -> str:
        if parsed:
            direct_error = (
                parsed.get("ErrorMessage")
                or parsed.get("Message")
                or parsed.get("error")
                or parsed.get("Error")
            )
            if direct_error:
                return str(direct_error)

            messages = parsed.get("Messages")
            if isinstance(messages, list):
                for message_payload in messages:
                    if isinstance(message_payload, dict):
                        return self._extract_mailjet_message_error(message_payload)
        return (raw_body or "unknown Mailjet error")[:300]

    def _classify_mail_error(self, reason: str, status_code: Optional[int]) -> str:
        text = (reason or "").lower()
        if status_code in {401, 403}:
            return "auth_failed"
        if status_code == 429:
            return "rate_limited"
        if "too many" in text or "rate limit" in text or "quota" in text:
            return "rate_limited"
        if (
            "sender" in text
            and (
                "not validated" in text
                or "not verified" in text
                or "not allowed" in text
                or "not authenticated" in text
                or "invalid" in text
                or "inactive" in text
                or "not active" in text
            )
        ):
            return "sender_not_verified"
        if "authentication" in text or "unauthorized" in text or "forbidden" in text:
            return "auth_failed"
        if (
            ("recipient" in text or "email" in text)
            and ("invalid" in text or "malformed" in text or "bad request" in text)
        ):
            return "invalid_recipient"
        return "delivery_failed"
