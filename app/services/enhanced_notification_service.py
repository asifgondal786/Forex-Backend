"""
Enhanced Multi-Channel Notification System
Sends smart, contextual notifications via multiple channels
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from enum import Enum
import asyncio
import json
import os
import smtplib
from email.message import EmailMessage

from ..utils.firestore_client import get_firestore_client


class NotificationChannel(Enum):
    """Notification delivery channels"""
    PUSH = "push"  # Mobile push notification
    EMAIL = "email"
    WEBHOOK = "webhook"
    IN_APP = "in_app"
    TELEGRAM = "telegram"
    WHATSAPP = "whatsapp"
    SMS = "sms"


class NotificationPriority(Enum):
    """Priority levels"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class NotificationCategory(Enum):
    """Notification categories for filtering"""
    TRADE_EXECUTION = "trade_execution"
    PRICE_ALERT = "price_alert"
    RISK_WARNING = "risk_warning"
    NEWS_ALERT = "news_alert"
    SYSTEM_UPDATE = "system_update"
    PREDICTION = "prediction"
    PERFORMANCE = "performance"
    ACCOUNT = "account"


@dataclass
class NotificationPreference:
    """User's notification preferences"""
    user_id: str
    enabled_channels: List[NotificationChannel] = field(default_factory=lambda: [NotificationChannel.PUSH, NotificationChannel.IN_APP])
    disabled_categories: List[NotificationCategory] = field(default_factory=list)
    quiet_hours_start: Optional[str] = "22:00"  # 10 PM
    quiet_hours_end: Optional[str] = "08:00"    # 8 AM
    max_notifications_per_hour: int = 10
    digest_mode: bool = False  # Send digest instead of individual notifications
    digest_frequency: str = "daily"  # "daily", "weekly", "hourly"


@dataclass
class Notification:
    """Single notification object"""
    notification_id: str
    user_id: str
    title: str
    message: str
    category: NotificationCategory
    priority: NotificationPriority
    timestamp: datetime
    
    # Content
    short_message: Optional[str] = None  # For SMS/Telegram
    rich_data: Dict = field(default_factory=dict)  # For in-app display
    action_url: Optional[str] = None  # For deep linking
    
    # Delivery
    channels_to_send: List[NotificationChannel] = field(default_factory=list)
    delivery_status: Dict[NotificationChannel, str] = field(default_factory=dict)  # "sent", "failed", "pending"
    
    # Tracking
    read: bool = False
    read_at: Optional[datetime] = None
    clicked: bool = False
    clicked_at: Optional[datetime] = None
    
    # TTL - auto-expire old notifications
    expires_at: Optional[datetime] = None


@dataclass
class NotificationTemplate:
    """Reusable notification templates"""
    template_id: str
    category: NotificationCategory
    name: str
    title_template: str
    message_template: str
    short_message_template: Optional[str] = None
    priority: NotificationPriority = NotificationPriority.MEDIUM


class EnhancedNotificationService:
    """
    Multi-channel notification system with smart delivery
    """
    
    def __init__(self):
        self.user_preferences: Dict[str, NotificationPreference] = {}
        self.notifications: List[Notification] = []
        self.notification_queue: asyncio.Queue = asyncio.Queue()
        self.templates: Dict[str, NotificationTemplate] = {}
        self._initialize_templates()
        
        # Channel integrations (placeholders)
        self.firebase_configured = False
        self.email_configured = False
        self.telegram_configured = False
        self.whatsapp_configured = False

        # SMTP config (env-driven)
        self.smtp_host = os.getenv("SMTP_HOST")
        self.smtp_port = int(os.getenv("SMTP_PORT", "587"))
        self.smtp_user = os.getenv("SMTP_USER")
        self.smtp_pass = os.getenv("SMTP_PASS")
        self.smtp_from = os.getenv("SMTP_FROM", self.smtp_user or "")
        self.smtp_tls = os.getenv("SMTP_TLS", "true").lower() != "false"
        self.email_configured = all([self.smtp_host, self.smtp_user, self.smtp_pass, self.smtp_from])

        self._firestore = None

    def _get_firestore(self):
        if self._firestore is None:
            self._firestore = get_firestore_client()
        return self._firestore

    def _initialize_templates(self):
        """Initialize standard notification templates"""
        self.templates = {
            "trade_executed": NotificationTemplate(
                template_id="trade_executed",
                category=NotificationCategory.TRADE_EXECUTION,
                name="Trade Executed",
                title_template="Trade Executed: {pair}",
                message_template="Your {action} trade on {pair} has been executed at {price}. Stop Loss: {sl}, Take Profit: {tp}",
                short_message_template="{pair} {action} @{price}",
                priority=NotificationPriority.HIGH
            ),
            "price_alert": NotificationTemplate(
                template_id="price_alert",
                category=NotificationCategory.PRICE_ALERT,
                name="Price Alert",
                title_template="Price Alert: {pair}",
                message_template="{pair} has reached {level} ({target_percent}% move). Current: {current}",
                short_message_template="{pair} @ {level}",
                priority=NotificationPriority.MEDIUM
            ),
            "risk_warning": NotificationTemplate(
                template_id="risk_warning",
                category=NotificationCategory.RISK_WARNING,
                name="Risk Warning",
                title_template="⚠️ Risk Warning",
                message_template="{warning_text}. Current account status: {account_status}",
                short_message_template="⚠️ {warning_text}",
                priority=NotificationPriority.CRITICAL
            ),
            "prediction_ready": NotificationTemplate(
                template_id="prediction_ready",
                category=NotificationCategory.PREDICTION,
                name="Prediction Ready",
                title_template="New Prediction: {pair}",
                message_template="AI analysis ready for {pair}. Recommendation: {action}. Confidence: {confidence}%",
                short_message_template="{pair}: {action} ({confidence}%)",
                priority=NotificationPriority.HIGH
            ),
            "news_alert": NotificationTemplate(
                template_id="news_alert",
                category=NotificationCategory.NEWS_ALERT,
                name="Economic News",
                title_template="Economic News: {country}",
                message_template="{news_title} scheduled in {time_to_event}. Impact: {impact_level}",
                short_message_template="{country}: {impact_level}",
                priority=NotificationPriority.MEDIUM
            ),
            "daily_performance": NotificationTemplate(
                template_id="daily_performance",
                category=NotificationCategory.PERFORMANCE,
                name="Daily Performance",
                title_template="Daily Performance Report",
                message_template="Today: {trades} trades, {win_rate}% win rate, P&L: {pnl}",
                short_message_template="P&L: {pnl} ({win_rate}%)",
                priority=NotificationPriority.LOW
            ),
        }

    async def set_notification_preferences(
        self,
        user_id: str,
        enabled_channels: Optional[List[str]] = None,
        disabled_categories: Optional[List[str]] = None,
        quiet_hours_start: Optional[str] = None,
        quiet_hours_end: Optional[str] = None,
        max_per_hour: int = 10,
        digest_mode: bool = False
    ) -> Dict:
        """Set user's notification preferences"""
        
        channels = []
        if enabled_channels:
            channels = [NotificationChannel[ch.upper()] for ch in enabled_channels]
        else:
            channels = [NotificationChannel.PUSH, NotificationChannel.IN_APP]
        
        categories = []
        if disabled_categories:
            categories = [NotificationCategory[cat.upper()] for cat in disabled_categories]
        
        preferences = NotificationPreference(
            user_id=user_id,
            enabled_channels=channels,
            disabled_categories=categories,
            quiet_hours_start=quiet_hours_start or "22:00",
            quiet_hours_end=quiet_hours_end or "08:00",
            max_notifications_per_hour=max_per_hour,
            digest_mode=digest_mode
        )
        
        self.user_preferences[user_id] = preferences
        
        return {
            "success": True,
            "message": "Notification preferences updated",
            "preferences": {
                "channels": [ch.value for ch in preferences.enabled_channels],
                "quiet_hours": f"{preferences.quiet_hours_start} - {preferences.quiet_hours_end}",
                "max_per_hour": max_per_hour,
                "digest_mode": digest_mode
            }
        }

    async def send_notification(
        self,
        user_id: str,
        template_id: str,
        category: str,
        priority: str = "medium",
        **template_vars
    ) -> Dict:
        """
        Send notification using template
        Smart delivery based on user preferences and conditions
        """
        
        template = self.templates.get(template_id)
        if not template:
            return {"error": f"Template {template_id} not found"}
        
        # Get user preferences
        prefs = self.user_preferences.get(user_id)
        if not prefs:
            # Initialize default preferences
            await self.set_notification_preferences(user_id)
            prefs = self.user_preferences[user_id]
        
        # Check if category is disabled
        cat = NotificationCategory[category.upper()]
        if cat in prefs.disabled_categories:
            return {"success": False, "reason": "Category disabled by user"}
        
        # Check quiet hours
        if self._is_quiet_hours(prefs):
            if priority not in [NotificationPriority.CRITICAL.value, NotificationPriority.HIGH.value]:
                # Queue for morning delivery
                return {"success": False, "reason": "Queued for quiet hours"}
        
        # Check rate limit
        hour_count = self._count_notifications_this_hour(user_id)
        if hour_count >= prefs.max_notifications_per_hour:
            return {"success": False, "reason": "Rate limit exceeded"}
        
        # Render notification from template
        title = self._render_template(template.title_template, template_vars)
        message = self._render_template(template.message_template, template_vars)
        short_msg = self._render_template(template.short_message_template or message, template_vars) if template.short_message_template else message
        
        notification_id = f"notif_{user_id}_{datetime.now().timestamp()}"
        
        notification = Notification(
            notification_id=notification_id,
            user_id=user_id,
            title=title,
            message=message,
            category=cat,
            priority=NotificationPriority[priority.upper()],
            timestamp=datetime.now(),
            short_message=short_msg,
            rich_data=template_vars,
            channels_to_send=prefs.enabled_channels,
            expires_at=datetime.now() + timedelta(days=7)
        )
        
        self.notifications.append(notification)
        
        # Queue for delivery
        await self.notification_queue.put(notification)
        
        # Process delivery
        await self._deliver_notification(notification)
        
        return {
            "success": True,
            "notification_id": notification_id,
            "channels": [ch.value for ch in prefs.enabled_channels],
            "timestamp": datetime.now().isoformat()
        }

    async def send_smart_alert(
        self,
        user_id: str,
        alert_type: str,
        data: Dict,
        reason: Optional[str] = None
    ) -> Dict:
        """
        Send smart, contextual alert
        Example: "Price touched 289 but conditions not met"
        """
        
        alerts = {
            "price_touched_but_conditions_not_met": {
                "template_id": "price_alert",
                "category": "PRICE_ALERT",
                "priority": "medium",
                "message_override": f"Alert: {data.get('pair')} touched {data.get('level')}, but conditions not met. Reason: {reason}"
            },
            "high_impact_news_incoming": {
                "template_id": "news_alert",
                "category": "NEWS_ALERT",
                "priority": "high",
                "message_override": f"High-impact news incoming in {data.get('time_remaining')} minutes"
            },
            "drawdown_warning": {
                "template_id": "risk_warning",
                "category": "RISK_WARNING",
                "priority": "critical",
                "message_override": f"Account drawdown: {data.get('drawdown')}% (Limit: {data.get('limit')}%)"
            }
        }
        
        alert = alerts.get(alert_type)
        if not alert:
            return {"error": f"Unknown alert type: {alert_type}"}
        
        template_vars = {**data, "warning_text": alert.get("message_override", "")}
        
        return await self.send_notification(
            user_id=user_id,
            template_id=alert["template_id"],
            category=alert["category"],
            priority=alert["priority"],
            **template_vars
        )

    async def _deliver_notification(self, notification: Notification):
        """Deliver notification across enabled channels"""
        for channel in notification.channels_to_send:
            try:
                if channel == NotificationChannel.PUSH:
                    await self._send_push(notification)
                elif channel == NotificationChannel.EMAIL:
                    await self._send_email(notification)
                elif channel == NotificationChannel.IN_APP:
                    await self._store_in_app(notification)
                elif channel == NotificationChannel.TELEGRAM:
                    await self._send_telegram(notification)
                elif channel == NotificationChannel.WHATSAPP:
                    await self._send_whatsapp(notification)
                elif channel == NotificationChannel.SMS:
                    await self._send_sms(notification)
                
                notification.delivery_status[channel] = "sent"
            except Exception as e:
                notification.delivery_status[channel] = f"failed: {str(e)}"

    async def _send_push(self, notification: Notification):
        """Send push notification (Firebase Cloud Messaging)"""
        if not self.firebase_configured:
            print(f"[PUSH] {notification.title}: {notification.message}")
            return
        
        # Production: Use FCM API
        # fcm_client.send_notification(notification.user_id, notification.title, notification.message)
        print(f"[PUSH] Sent to {notification.user_id}")

    async def _send_email(self, notification: Notification):
        """Send email notification"""
        if not self.email_configured:
            print(f"[EMAIL] To: {notification.user_id} - {notification.title}")
            return

        to_email = notification.user_id if "@" in notification.user_id else None
        if not to_email:
            print(f"[EMAIL] Skipped: user_id is not an email ({notification.user_id})")
            return

        def _send():
            msg = EmailMessage()
            msg["From"] = self.smtp_from
            msg["To"] = to_email
            msg["Subject"] = notification.title
            msg.set_content(notification.message)

            with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=10) as server:
                if self.smtp_tls:
                    server.starttls()
                server.login(self.smtp_user, self.smtp_pass)
                server.send_message(msg)

        await asyncio.to_thread(_send)
        print(f"[EMAIL] Sent to {to_email}")

    async def _send_telegram(self, notification: Notification):
        """Send Telegram message"""
        message = f"*{notification.title}*\n\n{notification.message}"
        print(f"[TELEGRAM] {message}")

    async def _send_whatsapp(self, notification: Notification):
        """Send WhatsApp message"""
        message = f"{notification.short_message}"
        print(f"[WHATSAPP] {message}")

    async def _send_sms(self, notification: Notification):
        """Send SMS"""
        print(f"[SMS] {notification.short_message}")

    async def _store_in_app(self, notification: Notification):
        """Store in-app notification"""
        # Already stored in self.notifications
        try:
            db = self._get_firestore()
            db.collection("notifications").document(notification.notification_id).set(
                {
                    "notificationId": notification.notification_id,
                    "userId": notification.user_id,
                    "title": notification.title,
                    "message": notification.message,
                    "shortMessage": notification.short_message,
                    "category": notification.category.value,
                    "priority": notification.priority.value,
                    "timestamp": notification.timestamp,
                    "read": notification.read,
                    "actionUrl": notification.action_url,
                    "createdAt": datetime.utcnow(),
                },
                merge=True,
            )
        except Exception as exc:
            print(f"[IN_APP] Firestore unavailable: {exc}")

        print(f"[IN_APP] Stored notification for {notification.user_id}")

    def _is_quiet_hours(self, prefs: NotificationPreference) -> bool:
        """Check if currently in quiet hours"""
        if not prefs.quiet_hours_start or not prefs.quiet_hours_end:
            return False
        
        now = datetime.now().time()
        start = datetime.strptime(prefs.quiet_hours_start, "%H:%M").time()
        end = datetime.strptime(prefs.quiet_hours_end, "%H:%M").time()
        
        if start < end:
            return start <= now < end
        else:
            return now >= start or now < end

    def _count_notifications_this_hour(self, user_id: str) -> int:
        """Count notifications sent this hour"""
        now = datetime.now()
        hour_ago = now - timedelta(hours=1)
        
        return len([n for n in self.notifications 
                   if n.user_id == user_id and hour_ago < n.timestamp < now])

    def _render_template(self, template: str, variables: Dict) -> str:
        """Render template with variables"""
        try:
            return template.format(**variables)
        except KeyError as e:
            return f"{template} (Missing: {e})"

    async def get_notifications(self, user_id: str, unread_only: bool = False, limit: int = 20) -> List[Dict]:
        """Get notifications for user"""
        def _coerce_dt(value: Optional[object]) -> datetime:
            if isinstance(value, datetime):
                return value
            if isinstance(value, str):
                try:
                    return datetime.fromisoformat(value)
                except ValueError:
                    return datetime.min
            return datetime.min

        def _format_ts(value: Optional[object]) -> str:
            if isinstance(value, datetime):
                return value.isoformat()
            if isinstance(value, str):
                return value
            return ""

        try:
            db = self._get_firestore()
            docs = list(db.collection("notifications").where("userId", "==", user_id).stream())
            items: List[Dict] = []
            for doc in docs:
                data = doc.to_dict() or {}
                read = data.get("read")
                if read is None:
                    read = data.get("is_read") or data.get("isRead") or False
                if unread_only and read:
                    continue

                timestamp = data.get("timestamp") or data.get("createdAt") or data.get("created_at")
                sort_dt = _coerce_dt(timestamp)
                items.append(
                    {
                        "notification_id": data.get("notificationId") or data.get("notification_id") or doc.id,
                        "title": data.get("title") or "",
                        "message": data.get("message") or "",
                        "category": data.get("category") or "",
                        "priority": data.get("priority") or "",
                        "timestamp": _format_ts(timestamp),
                        "read": bool(read),
                        "clicked": bool(data.get("clicked") or False),
                        "_sort_ts": sort_dt,
                    }
                )

            items.sort(key=lambda item: item.get("_sort_ts", datetime.min), reverse=True)
            for item in items:
                item.pop("_sort_ts", None)
            return items[:limit]
        except Exception:
            # Fallback to in-memory notifications if Firestore is unavailable
            notifications = [n for n in self.notifications if n.user_id == user_id]

            if unread_only:
                notifications = [n for n in notifications if not n.read]

            notifications = sorted(notifications, key=lambda x: x.timestamp, reverse=True)[:limit]

            return [
                {
                    "notification_id": n.notification_id,
                    "title": n.title,
                    "message": n.message,
                    "category": n.category.value,
                    "priority": n.priority.value,
                    "timestamp": n.timestamp.isoformat(),
                    "read": n.read,
                    "clicked": n.clicked,
                }
                for n in notifications
            ]

    async def mark_as_read(self, notification_id: str, user_id: Optional[str] = None) -> Dict:
        """Mark notification as read"""
        updated = False

        notif = next((n for n in self.notifications if n.notification_id == notification_id), None)
        if notif:
            if user_id and notif.user_id != user_id:
                return {"error": "Notification not found"}
            notif.read = True
            notif.read_at = datetime.now()
            updated = True

        try:
            db = self._get_firestore()
            doc_ref = db.collection("notifications").document(notification_id)
            if user_id:
                doc = doc_ref.get()
                if doc.exists:
                    data = doc.to_dict() or {}
                    if data.get("userId") and data.get("userId") != user_id:
                        return {"error": "Notification not found"}
            doc_ref.set(
                {
                    "read": True,
                    "readAt": datetime.utcnow(),
                },
                merge=True,
            )
            updated = True
        except Exception:
            pass

        if updated:
            return {"success": True}
        return {"error": "Notification not found"}

    async def get_notification_settings_panel(self, user_id: str) -> Dict:
        """Get notification settings for UI"""
        prefs = self.user_preferences.get(user_id)
        
        if not prefs:
            return {"error": "Preferences not configured"}
        
        return {
            "channels": {
                channel.value: channel in prefs.enabled_channels
                for channel in NotificationChannel
            },
            "categories": {
                cat.value: cat not in prefs.disabled_categories
                for cat in NotificationCategory
            },
            "quiet_hours": {
                "start": prefs.quiet_hours_start,
                "end": prefs.quiet_hours_end,
            },
            "rate_limit": prefs.max_notifications_per_hour,
            "digest_mode": prefs.digest_mode,
            "digest_frequency": prefs.digest_frequency,
        }

    async def generate_digest(self, user_id: str, period: str = "daily") -> Dict:
        """Generate notification digest"""
        prefs = self.user_preferences.get(user_id)
        if not prefs or not prefs.digest_mode:
            return {"error": "Digest mode not enabled"}
        
        cutoff = datetime.now() - timedelta(days=1 if period == "daily" else 7)
        
        user_notifs = [n for n in self.notifications 
                      if n.user_id == user_id and n.timestamp > cutoff]
        
        grouped = {}
        for notif in user_notifs:
            cat = notif.category.value
            if cat not in grouped:
                grouped[cat] = []
            grouped[cat].append({
                "title": notif.title,
                "message": notif.message,
                "timestamp": notif.timestamp.isoformat()
            })
        
        return {
            "period": period,
            "generated_at": datetime.now().isoformat(),
            "summary": {
                cat: len(notifs) for cat, notifs in grouped.items()
            },
            "by_category": grouped
        }
