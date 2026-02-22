"""
Enhanced Multi-Channel Notification System
Sends smart, contextual notifications via multiple channels
"""
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
from enum import Enum
import asyncio
import json
import os
import aiohttp

from ..utils.firestore_client import get_firestore_client
from .market_intelligence_service import MarketIntelligenceService
from .mail_delivery_service import MailDeliveryService


class NotificationChannel(Enum):
    """Notification delivery channels"""
    PUSH = "push"  # Mobile push notification
    EMAIL = "email"
    WEBHOOK = "webhook"
    IN_APP = "in_app"
    TELEGRAM = "telegram"
    DISCORD = "discord"
    X = "x"
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
    autonomous_mode: bool = False
    autonomous_profile: str = "balanced"  # conservative, balanced, aggressive
    autonomous_min_confidence: float = 0.62
    autonomous_stage_alerts: bool = True
    autonomous_stage_interval_seconds: int = 45
    channel_settings: Dict[str, str] = field(default_factory=dict)


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
        self._last_stage_alert_sent: Dict[Tuple[str, str, str], datetime] = {}
        self.templates: Dict[str, NotificationTemplate] = {}
        self._initialize_templates()
        self.market_intelligence = MarketIntelligenceService()
        self.deep_study_required = os.getenv("NOTIFICATIONS_REQUIRE_DEEP_STUDY", "true").lower() != "false"
        try:
            self.deep_study_min_confidence = float(
                os.getenv("NOTIFICATIONS_DEEP_STUDY_MIN_CONFIDENCE", "0.45")
            )
        except ValueError:
            self.deep_study_min_confidence = 0.45
        try:
            self.autonomous_min_coverage = float(
                os.getenv("NOTIFICATIONS_AUTONOMOUS_MIN_COVERAGE", "0.35")
            )
        except ValueError:
            self.autonomous_min_coverage = 0.35
        self.autonomous_high_risk_pause = (
            os.getenv("NOTIFICATIONS_AUTONOMOUS_HIGH_RISK_PAUSE", "true").lower() != "false"
        )
        
        # Channel integrations (placeholders)
        self.firebase_configured = False
        self.email_configured = False
        self.telegram_configured = False
        self.discord_configured = False
        self.x_configured = False
        self.whatsapp_configured = False
        self.mail_delivery = MailDeliveryService()

        self.email_configured = self.mail_delivery.email_configured

        # Channel integration config (env-driven)
        self.telegram_bot_token = os.getenv("TELEGRAM_BOT_TOKEN", "").strip()
        self.telegram_default_chat_id = os.getenv("TELEGRAM_DEFAULT_CHAT_ID", "").strip()
        self.telegram_configured = bool(self.telegram_bot_token and self.telegram_default_chat_id)

        self.discord_webhook_url = os.getenv("DISCORD_WEBHOOK_URL", "").strip()
        self.discord_configured = bool(self.discord_webhook_url)

        # Recommended: point this to your own service that posts to X API.
        self.x_webhook_url = os.getenv("X_WEBHOOK_URL", "").strip()
        self.x_configured = bool(self.x_webhook_url)

        self.default_webhook_url = os.getenv("NOTIFICATION_WEBHOOK_URL", "").strip()

        self._firestore = None

    def _get_firestore(self):
        if self._firestore is None:
            self._firestore = get_firestore_client()
        return self._firestore

    def _normalize_channel_settings(self, raw: Optional[Dict]) -> Dict[str, str]:
        if not isinstance(raw, dict):
            return {}
        allowed_keys = {
            "email_to",
            "phone_number",
            "whatsapp_number",
            "telegram_chat_id",
            "telegram_bot_token",
            "discord_webhook_url",
            "x_webhook_url",
            "webhook_url",
            "sms_webhook_url",
            "whatsapp_webhook_url",
        }
        normalized: Dict[str, str] = {}
        for key in allowed_keys:
            value = raw.get(key)
            if value is None:
                continue
            value_str = str(value).strip()
            if value_str:
                normalized[key] = value_str
        return normalized

    def _serialize_delivery_status(self, status_map: Dict[NotificationChannel, str]) -> Dict[str, str]:
        serialized: Dict[str, str] = {}
        for key, value in status_map.items():
            channel = key.value if isinstance(key, NotificationChannel) else str(key)
            serialized[channel] = str(value)
        return serialized

    def _serialize_channels(self, channels: List[NotificationChannel]) -> List[str]:
        return [
            channel.value if isinstance(channel, NotificationChannel) else str(channel)
            for channel in channels
        ]

    def _normalize_autonomous_profile(self, raw: Optional[str]) -> str:
        value = (raw or "").strip().lower()
        if value in {"conservative", "balanced", "aggressive"}:
            return value
        return "balanced"

    def _normalize_confidence(self, raw_value: Optional[object], default: float) -> float:
        if raw_value is None:
            return default
        try:
            value = float(raw_value)
        except Exception:
            return default
        return max(0.0, min(0.99, value))

    def _autonomous_confidence_target(self, prefs: NotificationPreference) -> float:
        profile_floor = {
            "conservative": 0.72,
            "balanced": 0.62,
            "aggressive": 0.52,
        }.get(prefs.autonomous_profile, 0.62)
        return max(
            self.deep_study_min_confidence,
            profile_floor,
            prefs.autonomous_min_confidence,
        )

    def _autonomous_safety_decision(
        self,
        *,
        prefs: NotificationPreference,
        category: NotificationCategory,
        requested_priority: str,
        deep_study: Dict,
        consensus_score: float,
    ) -> Dict[str, object]:
        if not prefs.autonomous_mode:
            return {
                "enabled": False,
                "suppressed": False,
                "reason": "",
                "priority": requested_priority,
                "min_confidence": self.deep_study_min_confidence,
            }

        coverage = deep_study.get("source_coverage", {})
        coverage_ratio = float(coverage.get("coverage_ratio", 0.0) or 0.0)
        recommendation = str(deep_study.get("recommendation", "wait_for_confirmation")).lower()
        chart_analysis = deep_study.get("chart_analysis", {})
        market_risk = str(chart_analysis.get("risk_level", "unknown")).lower()
        min_confidence = self._autonomous_confidence_target(prefs)
        priority = requested_priority.lower()
        suppress_reason = ""

        trade_sensitive = category in {
            NotificationCategory.TRADE_EXECUTION,
            NotificationCategory.PREDICTION,
            NotificationCategory.PRICE_ALERT,
        }

        if coverage_ratio < self.autonomous_min_coverage and priority != "critical":
            suppress_reason = (
                "Suppressed by autonomous mode: insufficient source coverage "
                f"({coverage_ratio:.2f} < {self.autonomous_min_coverage:.2f})"
            )
        elif consensus_score < min_confidence and priority != "critical":
            suppress_reason = (
                "Suppressed by autonomous mode: confidence below threshold "
                f"({consensus_score:.2f} < {min_confidence:.2f})"
            )
        elif (
            self.autonomous_high_risk_pause
            and market_risk in {"high", "extreme"}
            and trade_sensitive
            and priority != "critical"
        ):
            suppress_reason = "Suppressed by autonomous mode: market risk elevated"
        elif recommendation == "wait_for_confirmation" and trade_sensitive and priority != "critical":
            suppress_reason = "Suppressed by autonomous mode: deep-study recommends waiting"

        if market_risk in {"high", "extreme"} and priority in {"low", "medium"}:
            priority = "high"

        return {
            "enabled": True,
            "suppressed": bool(suppress_reason),
            "reason": suppress_reason,
            "priority": priority,
            "min_confidence": min_confidence,
            "market_risk": market_risk,
            "coverage_ratio": coverage_ratio,
            "recommendation": recommendation,
        }

    def _load_preferences_from_firestore(self, user_id: str) -> Optional[NotificationPreference]:
        try:
            db = self._get_firestore()
            doc = db.collection("notification_preferences").document(user_id).get()
            if not doc.exists:
                return None
            data = doc.to_dict() or {}
            enabled_raw = data.get("enabled_channels") or [NotificationChannel.PUSH.value, NotificationChannel.IN_APP.value]
            disabled_raw = data.get("disabled_categories") or []

            enabled_channels: List[NotificationChannel] = []
            for channel in enabled_raw:
                key = str(channel).strip().upper()
                if key in NotificationChannel.__members__:
                    enabled_channels.append(NotificationChannel[key])
            if not enabled_channels:
                enabled_channels = [NotificationChannel.PUSH, NotificationChannel.IN_APP]

            disabled_categories: List[NotificationCategory] = []
            for category in disabled_raw:
                key = str(category).strip().upper()
                if key in NotificationCategory.__members__:
                    disabled_categories.append(NotificationCategory[key])

            return NotificationPreference(
                user_id=user_id,
                enabled_channels=enabled_channels,
                disabled_categories=disabled_categories,
                quiet_hours_start=str(data.get("quiet_hours_start") or "22:00"),
                quiet_hours_end=str(data.get("quiet_hours_end") or "08:00"),
                max_notifications_per_hour=int(data.get("max_notifications_per_hour") or 10),
                digest_mode=bool(data.get("digest_mode") or False),
                digest_frequency=str(data.get("digest_frequency") or "daily"),
                autonomous_mode=bool(data.get("autonomous_mode") or False),
                autonomous_profile=self._normalize_autonomous_profile(
                    data.get("autonomous_profile")
                ),
                autonomous_min_confidence=self._normalize_confidence(
                    data.get("autonomous_min_confidence"),
                    0.62,
                ),
                autonomous_stage_alerts=bool(data.get("autonomous_stage_alerts", True)),
                autonomous_stage_interval_seconds=max(
                    15,
                    int(data.get("autonomous_stage_interval_seconds") or 45),
                ),
                channel_settings=self._normalize_channel_settings(data.get("channel_settings")),
            )
        except Exception:
            return None

    def _persist_preferences(self, preferences: NotificationPreference):
        try:
            db = self._get_firestore()
            db.collection("notification_preferences").document(preferences.user_id).set(
                {
                    "user_id": preferences.user_id,
                    "enabled_channels": [ch.value for ch in preferences.enabled_channels],
                    "disabled_categories": [cat.value for cat in preferences.disabled_categories],
                    "quiet_hours_start": preferences.quiet_hours_start,
                    "quiet_hours_end": preferences.quiet_hours_end,
                    "max_notifications_per_hour": preferences.max_notifications_per_hour,
                    "digest_mode": preferences.digest_mode,
                    "digest_frequency": preferences.digest_frequency,
                    "autonomous_mode": preferences.autonomous_mode,
                    "autonomous_profile": preferences.autonomous_profile,
                    "autonomous_min_confidence": preferences.autonomous_min_confidence,
                    "autonomous_stage_alerts": preferences.autonomous_stage_alerts,
                    "autonomous_stage_interval_seconds": preferences.autonomous_stage_interval_seconds,
                    "channel_settings": preferences.channel_settings,
                    "updated_at": datetime.utcnow(),
                },
                merge=True,
            )
        except Exception as exc:
            print(f"[PREFS] Firestore unavailable: {exc}")

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
            "autonomous_stage_update": NotificationTemplate(
                template_id="autonomous_stage_update",
                category=NotificationCategory.SYSTEM_UPDATE,
                name="Autonomous Stage Update",
                title_template="Agent Stage: {stage_label} ({pair})",
                message_template=(
                    "Jarvis-style assistant update for {pair}. Stage: {stage_label}. "
                    "Confidence: {confidence}%. Signal: {recommendation}. "
                    "Sources analyzed: {source_count}. Context: {stage_context}"
                ),
                short_message_template="{pair} {stage_label}: {confidence}% | {recommendation}",
                priority=NotificationPriority.MEDIUM,
            ),
        }

    async def set_notification_preferences(
        self,
        user_id: str,
        enabled_channels: Optional[List[str]] = None,
        disabled_categories: Optional[List[str]] = None,
        quiet_hours_start: Optional[str] = None,
        quiet_hours_end: Optional[str] = None,
        max_per_hour: Optional[int] = None,
        digest_mode: Optional[bool] = None,
        autonomous_mode: Optional[bool] = None,
        autonomous_profile: Optional[str] = None,
        autonomous_min_confidence: Optional[float] = None,
        autonomous_stage_alerts: Optional[bool] = None,
        autonomous_stage_interval_seconds: Optional[int] = None,
        channel_settings: Optional[Dict[str, str]] = None,
    ) -> Dict:
        """Set user's notification preferences"""

        existing = self.user_preferences.get(user_id) or self._load_preferences_from_firestore(user_id)

        channels: List[NotificationChannel] = []
        if enabled_channels is not None:
            for channel in enabled_channels:
                key = (channel or "").strip().upper()
                if key in NotificationChannel.__members__:
                    channels.append(NotificationChannel[key])
        elif existing:
            channels = list(existing.enabled_channels)
        else:
            channels = [NotificationChannel.PUSH, NotificationChannel.IN_APP]

        if not channels:
            channels = [NotificationChannel.PUSH, NotificationChannel.IN_APP]

        categories: List[NotificationCategory] = []
        if disabled_categories is not None:
            for category in disabled_categories:
                key = (category or "").strip().upper()
                if key in NotificationCategory.__members__:
                    categories.append(NotificationCategory[key])
        elif existing:
            categories = list(existing.disabled_categories)

        merged_channel_settings = dict(existing.channel_settings) if existing else {}
        if channel_settings is not None:
            for key in {
                "email_to",
                "phone_number",
                "whatsapp_number",
                "telegram_chat_id",
                "telegram_bot_token",
                "discord_webhook_url",
                "x_webhook_url",
                "webhook_url",
                "sms_webhook_url",
                "whatsapp_webhook_url",
            }:
                if key not in channel_settings:
                    continue
                value = channel_settings.get(key)
                value_str = str(value).strip() if value is not None else ""
                if value_str:
                    merged_channel_settings[key] = value_str
                else:
                    merged_channel_settings.pop(key, None)

        preferences = NotificationPreference(
            user_id=user_id,
            enabled_channels=channels,
            disabled_categories=categories,
            quiet_hours_start=quiet_hours_start if quiet_hours_start is not None else (existing.quiet_hours_start if existing else "22:00"),
            quiet_hours_end=quiet_hours_end if quiet_hours_end is not None else (existing.quiet_hours_end if existing else "08:00"),
            max_notifications_per_hour=max_per_hour if max_per_hour is not None else (existing.max_notifications_per_hour if existing else 10),
            digest_mode=digest_mode if digest_mode is not None else (existing.digest_mode if existing else False),
            digest_frequency=existing.digest_frequency if existing else "daily",
            autonomous_mode=autonomous_mode if autonomous_mode is not None else (existing.autonomous_mode if existing else False),
            autonomous_profile=self._normalize_autonomous_profile(
                autonomous_profile
                if autonomous_profile is not None
                else (existing.autonomous_profile if existing else "balanced")
            ),
            autonomous_min_confidence=self._normalize_confidence(
                autonomous_min_confidence
                if autonomous_min_confidence is not None
                else (existing.autonomous_min_confidence if existing else 0.62),
                0.62,
            ),
            autonomous_stage_alerts=(
                autonomous_stage_alerts
                if autonomous_stage_alerts is not None
                else (existing.autonomous_stage_alerts if existing else True)
            ),
            autonomous_stage_interval_seconds=max(
                15,
                int(
                    autonomous_stage_interval_seconds
                    if autonomous_stage_interval_seconds is not None
                    else (
                        existing.autonomous_stage_interval_seconds if existing else 45
                    )
                ),
            ),
            channel_settings=merged_channel_settings,
        )
        
        self.user_preferences[user_id] = preferences
        self._persist_preferences(preferences)
        
        return {
            "success": True,
            "message": "Notification preferences updated",
            "preferences": {
                "channels": [ch.value for ch in preferences.enabled_channels],
                "quiet_hours": f"{preferences.quiet_hours_start} - {preferences.quiet_hours_end}",
                "max_per_hour": preferences.max_notifications_per_hour,
                "digest_mode": preferences.digest_mode,
                "autonomous_mode": preferences.autonomous_mode,
                "autonomous_profile": preferences.autonomous_profile,
                "autonomous_min_confidence": preferences.autonomous_min_confidence,
                "autonomous_stage_alerts": preferences.autonomous_stage_alerts,
                "autonomous_stage_interval_seconds": preferences.autonomous_stage_interval_seconds,
                "channel_settings": preferences.channel_settings,
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
        requested_priority = (priority or NotificationPriority.MEDIUM.value).strip().lower()
        if requested_priority not in {member.value for member in NotificationPriority}:
            requested_priority = NotificationPriority.MEDIUM.value
        
        # Get user preferences
        prefs = self.user_preferences.get(user_id) or self._load_preferences_from_firestore(user_id)
        if not prefs:
            # Initialize default preferences
            await self.set_notification_preferences(user_id)
            prefs = self.user_preferences[user_id]
        else:
            self.user_preferences[user_id] = prefs
        
        # Check if category is disabled
        cat = NotificationCategory[category.upper()]
        if cat in prefs.disabled_categories:
            return {"success": False, "reason": "Category disabled by user"}
        
        # Check quiet hours
        if self._is_quiet_hours(prefs):
            if requested_priority not in [NotificationPriority.CRITICAL.value, NotificationPriority.HIGH.value]:
                # Queue for morning delivery
                return {"success": False, "reason": "Queued for quiet hours"}
        
        # Check rate limit
        hour_count = self._count_notifications_this_hour(user_id)
        if hour_count >= prefs.max_notifications_per_hour:
            return {"success": False, "reason": "Rate limit exceeded"}

        # Build deep-study context so every notification is analysis-backed.
        pair = self._extract_pair(template_vars)
        deep_study = await self.market_intelligence.build_deep_study(pair=pair)
        consensus_score = float(deep_study.get("consensus_score", 0.0) or 0.0)

        if (
            self.deep_study_required
            and requested_priority in {
                NotificationPriority.LOW.value,
                NotificationPriority.MEDIUM.value,
            }
            and consensus_score < self.deep_study_min_confidence
        ):
            return {
                "success": False,
                "reason": "Suppressed by deep-study confidence threshold",
                "consensus_score": consensus_score,
                "min_confidence": self.deep_study_min_confidence,
                "study_summary": deep_study.get("evidence_summary"),
            }

        autonomous_decision = self._autonomous_safety_decision(
            prefs=prefs,
            category=cat,
            requested_priority=requested_priority,
            deep_study=deep_study,
            consensus_score=consensus_score,
        )
        if bool(autonomous_decision.get("suppressed")):
            return {
                "success": False,
                "reason": autonomous_decision.get("reason")
                or "Suppressed by autonomous safety policy",
                "consensus_score": consensus_score,
                "deep_study": {
                    "confidence_band": deep_study.get("confidence_band", "low"),
                    "recommendation": deep_study.get("recommendation", "wait_for_confirmation"),
                },
            }
        final_priority = str(autonomous_decision.get("priority") or requested_priority).lower()

        enriched_vars = dict(prefs.channel_settings)
        enriched_vars.update(template_vars)
        enriched_vars["study_pair"] = pair
        enriched_vars["study_consensus_score"] = round(consensus_score, 4)
        enriched_vars["study_confidence_band"] = deep_study.get("confidence_band", "low")
        enriched_vars["study_sources_analyzed"] = deep_study.get("source_coverage", {}).get("analyzed", 0)
        enriched_vars["deep_study"] = deep_study
        enriched_vars["autonomous_policy"] = autonomous_decision
        
        # Render notification from template
        title = self._render_template(template.title_template, enriched_vars)
        base_message = self._render_template(template.message_template, enriched_vars)
        message = self._append_deep_study_summary(base_message, deep_study)
        short_msg = (
            self._render_template(template.short_message_template or message, enriched_vars)
            if template.short_message_template
            else message
        )
        
        notification_id = f"notif_{user_id}_{datetime.now().timestamp()}"
        
        notification = Notification(
            notification_id=notification_id,
            user_id=user_id,
            title=title,
            message=message,
            category=cat,
            priority=NotificationPriority[final_priority.upper()],
            timestamp=datetime.now(),
            short_message=short_msg,
            rich_data=enriched_vars,
            channels_to_send=prefs.enabled_channels,
            expires_at=datetime.now() + timedelta(days=7)
        )
        
        self.notifications.append(notification)
        
        # Queue for delivery
        await self.notification_queue.put(notification)
        
        # Process delivery
        await self._deliver_notification(notification)
        await self._persist_delivery_metadata(notification)
        
        return {
            "success": True,
            "notification_id": notification_id,
            "channels": [ch.value for ch in prefs.enabled_channels],
            "timestamp": datetime.now().isoformat(),
            "deep_study": {
                "pair": pair,
                "consensus_score": round(consensus_score, 4),
                "confidence_band": deep_study.get("confidence_band", "low"),
                "sources_analyzed": deep_study.get("source_coverage", {}).get("analyzed", 0),
                "coverage_ratio": deep_study.get("source_coverage", {}).get("coverage_ratio", 0.0),
                "recommendation": deep_study.get("recommendation", "wait_for_confirmation"),
                "market_risk": deep_study.get("chart_analysis", {}).get("risk_level", "unknown"),
            },
            "autonomous_policy": autonomous_decision,
        }

    async def _persist_delivery_metadata(self, notification: Notification) -> None:
        try:
            db = self._get_firestore()
            db.collection("notifications").document(notification.notification_id).set(
                {
                    "channelsToSend": self._serialize_channels(notification.channels_to_send),
                    "deliveryStatus": self._serialize_delivery_status(notification.delivery_status),
                    "deliveryUpdatedAt": datetime.utcnow(),
                },
                merge=True,
            )
        except Exception:
            # Best-effort persistence only.
            pass

    async def get_deep_study(self, pair: str = "EUR/USD", max_headlines_per_source: int = 3) -> Dict:
        return await self.market_intelligence.build_deep_study(
            pair=pair,
            max_headlines_per_source=max_headlines_per_source,
        )

    async def send_autonomous_study_notification(
        self,
        user_id: str,
        pair: str = "EUR/USD",
        user_instruction: Optional[str] = None,
        priority: Optional[str] = None,
    ) -> Dict:
        normalized_pair = (pair or "EUR/USD").strip().upper()
        deep_study = await self.market_intelligence.build_deep_study(pair=normalized_pair)
        confidence_pct = round(float(deep_study.get("consensus_score", 0.0) or 0.0) * 100, 1)
        recommendation = str(
            deep_study.get("recommendation", "wait_for_confirmation")
        ).replace("_", " ")
        coverage = deep_study.get("source_coverage", {})
        analyzed = int(coverage.get("analyzed", 0) or 0)
        requested = int(coverage.get("requested", 0) or 0)

        inferred_priority = (priority or "").strip().lower()
        if inferred_priority not in {member.value for member in NotificationPriority}:
            inferred_priority = (
                NotificationPriority.HIGH.value
                if confidence_pct >= 72
                else NotificationPriority.MEDIUM.value
            )

        return await self.send_notification(
            user_id=user_id,
            template_id="prediction_ready",
            category=NotificationCategory.PREDICTION.value,
            priority=inferred_priority,
            pair=normalized_pair,
            action=recommendation,
            confidence=confidence_pct,
            source_count=f"{analyzed}/{requested}",
            user_instruction=(user_instruction or "").strip(),
            recommendation=recommendation,
        )

    def _stage_key(self, stage: str) -> str:
        normalized = (stage or "monitoring").strip().lower().replace("-", "_")
        if not normalized:
            return "monitoring"
        return normalized

    def _stage_label(self, stage: str) -> str:
        key = self._stage_key(stage)
        mapping = {
            "monitoring": "Monitoring",
            "analyzing": "Analyzing",
            "trading": "Trading",
            "risk_lock": "Risk Lock",
            "paused": "Paused",
            "briefing": "Briefing",
            "executed": "Executed",
        }
        return mapping.get(key, key.replace("_", " ").title())

    def _can_emit_stage_alert(
        self,
        *,
        user_id: str,
        pair: str,
        stage: str,
        min_interval_seconds: int,
    ) -> bool:
        key = (user_id, pair.upper(), self._stage_key(stage))
        last_sent = self._last_stage_alert_sent.get(key)
        if not last_sent:
            return True
        elapsed = (datetime.now() - last_sent).total_seconds()
        return elapsed >= max(15, min_interval_seconds)

    def _mark_stage_alert_sent(self, *, user_id: str, pair: str, stage: str) -> None:
        key = (user_id, pair.upper(), self._stage_key(stage))
        self._last_stage_alert_sent[key] = datetime.now()

    async def send_autonomous_stage_notification(
        self,
        user_id: str,
        stage: str,
        pair: str = "EUR/USD",
        user_instruction: Optional[str] = None,
        priority: Optional[str] = None,
        stage_context: Optional[str] = None,
        force: bool = False,
    ) -> Dict:
        normalized_pair = (pair or "EUR/USD").strip().upper()
        normalized_stage = self._stage_key(stage)
        stage_label = self._stage_label(stage)

        prefs = self.user_preferences.get(user_id) or self._load_preferences_from_firestore(user_id)
        if not prefs:
            await self.set_notification_preferences(user_id=user_id)
            prefs = self.user_preferences.get(user_id)
        if not prefs:
            return {"success": False, "reason": "Notification preferences unavailable"}
        self.user_preferences[user_id] = prefs

        if not force and not prefs.autonomous_stage_alerts:
            return {
                "success": False,
                "reason": "Autonomous stage alerts disabled by user preference",
            }

        if not force and not self._can_emit_stage_alert(
            user_id=user_id,
            pair=normalized_pair,
            stage=normalized_stage,
            min_interval_seconds=prefs.autonomous_stage_interval_seconds,
        ):
            return {
                "success": False,
                "reason": "Stage alert suppressed by cadence guard",
                "cadence_seconds": prefs.autonomous_stage_interval_seconds,
            }

        deep_study = await self.market_intelligence.build_deep_study(pair=normalized_pair)
        confidence_pct = round(float(deep_study.get("consensus_score", 0.0) or 0.0) * 100, 1)
        coverage = deep_study.get("source_coverage", {})
        analyzed = int(coverage.get("analyzed", 0) or 0)
        requested = int(coverage.get("requested", 0) or 0)
        recommendation = str(
            deep_study.get("recommendation", "wait_for_confirmation")
        ).replace("_", " ")
        market_risk = str(
            deep_study.get("chart_analysis", {}).get("risk_level", "unknown")
        ).lower()
        evidence_summary = str(deep_study.get("evidence_summary", "")).strip()

        inferred_priority = (priority or "").strip().lower()
        valid_priorities = {member.value for member in NotificationPriority}
        if inferred_priority not in valid_priorities:
            if normalized_stage in {"risk_lock", "paused"}:
                inferred_priority = NotificationPriority.CRITICAL.value
            elif normalized_stage in {"trading", "executed"}:
                inferred_priority = NotificationPriority.HIGH.value
            elif market_risk in {"high", "extreme"}:
                inferred_priority = NotificationPriority.HIGH.value
            else:
                inferred_priority = NotificationPriority.MEDIUM.value

        context_line = (
            stage_context.strip()
            if stage_context and stage_context.strip()
            else evidence_summary
            if evidence_summary
            else "Stage transition acknowledged."
        )

        response = await self.send_notification(
            user_id=user_id,
            template_id="autonomous_stage_update",
            category=NotificationCategory.SYSTEM_UPDATE.value,
            priority=inferred_priority,
            pair=normalized_pair,
            stage=normalized_stage,
            stage_label=stage_label,
            confidence=confidence_pct,
            source_count=f"{analyzed}/{requested}",
            recommendation=recommendation,
            stage_context=context_line,
            user_instruction=(user_instruction or "").strip(),
            market_risk=market_risk,
        )

        if response.get("success") is True:
            self._mark_stage_alert_sent(
                user_id=user_id,
                pair=normalized_pair,
                stage=normalized_stage,
            )
        return response

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
                elif channel == NotificationChannel.WEBHOOK:
                    await self._send_webhook(notification)
                elif channel == NotificationChannel.IN_APP:
                    await self._store_in_app(notification)
                    # Broadcast in-app notification via WebSocket
                    await self._broadcast_in_app_notification(notification)
                elif channel == NotificationChannel.TELEGRAM:
                    await self._send_telegram(notification)
                elif channel == NotificationChannel.DISCORD:
                    await self._send_discord(notification)
                elif channel == NotificationChannel.X:
                    await self._send_x(notification)
                elif channel == NotificationChannel.WHATSAPP:
                    await self._send_whatsapp(notification)
                elif channel == NotificationChannel.SMS:
                    await self._send_sms(notification)
                
                notification.delivery_status[channel] = "sent"
            except Exception as e:
                notification.delivery_status[channel] = f"failed: {str(e)}"
    
    async def _broadcast_in_app_notification(self, notification: Notification):
        """Broadcast in-app notification to connected clients via WebSocket"""
        try:
            from ..enhanced_websocket_manager import ws_manager
            
            # Broadcast notification to all connected clients
            await ws_manager.broadcast(
                message=notification.title,
                update_type="notification",
                data={
                    "notification_id": notification.notification_id,
                    "user_id": notification.user_id,
                    "title": notification.title,
                    "message": notification.message,
                    "short_message": notification.short_message,
                    "category": notification.category.value,
                    "priority": notification.priority.value,
                    "timestamp": notification.timestamp.isoformat(),
                    "read": notification.read,
                    "action_url": notification.action_url,
                    "rich_data": notification.rich_data,
                }
            )
            print(f"[WS] Broadcasted notification to all clients")
        except Exception as e:
            print(f"[WS] Failed to broadcast notification: {e}")

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

        to_email = str(notification.rich_data.get("email_to") or "").strip()
        if not to_email:
            to_email = notification.user_id if "@" in notification.user_id else None
        if not to_email:
            print(f"[EMAIL] Skipped: user_id is not an email ({notification.user_id})")
            return

        await self.mail_delivery.send_email(
            to_email=to_email,
            subject=notification.title,
            text_body=notification.message,
        )
        print(f"[EMAIL] Sent to {to_email}")

    async def _send_telegram(self, notification: Notification):
        """Send Telegram message"""
        chat_id = str(
            notification.rich_data.get("telegram_chat_id")
            or self.telegram_default_chat_id
        ).strip()
        bot_token = str(
            notification.rich_data.get("telegram_bot_token")
            or self.telegram_bot_token
        ).strip()
        if not chat_id or not bot_token:
            message = f"{notification.title}\n\n{notification.message}"
            print(f"[TELEGRAM] Missing config. Fallback log: {message}")
            return

        payload = {
            "chat_id": chat_id,
            "text": f"{notification.title}\n\n{notification.message}",
            "disable_web_page_preview": True,
        }
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        await self._post_json(url, payload, channel_name="TELEGRAM")

    async def _send_discord(self, notification: Notification):
        """Send Discord webhook message"""
        webhook_url = str(
            notification.rich_data.get("discord_webhook_url")
            or self.discord_webhook_url
        ).strip()
        if not webhook_url:
            print(
                f"[DISCORD] Missing webhook URL. Fallback log: "
                f"{notification.title} - {notification.short_message or notification.message}"
            )
            return

        content = f"**{notification.title}**\n{notification.message}"
        payload = {
            "content": content[:1900],
            "username": "Forex Companion",
        }
        await self._post_json(webhook_url, payload, channel_name="DISCORD")

    async def _send_x(self, notification: Notification):
        """
        Send X notification via integration webhook.
        This webhook should be implemented by your X API integration service.
        """
        webhook_url = str(
            notification.rich_data.get("x_webhook_url")
            or self.x_webhook_url
        ).strip()
        if not webhook_url:
            print(
                f"[X] Missing X_WEBHOOK_URL. Fallback log: "
                f"{notification.title} - {notification.short_message or notification.message}"
            )
            return

        payload = {
            "text": (
                notification.short_message
                or f"{notification.title}: {notification.message}"
            )[:250],
            "title": notification.title,
            "message": notification.message,
            "notification_id": notification.notification_id,
            "user_id": notification.user_id,
            "priority": notification.priority.value,
            "category": notification.category.value,
            "timestamp": notification.timestamp.isoformat(),
        }
        await self._post_json(webhook_url, payload, channel_name="X")

    async def _send_webhook(self, notification: Notification):
        """Send generic webhook notification"""
        webhook_url = str(
            notification.rich_data.get("webhook_url")
            or self.default_webhook_url
        ).strip()
        if not webhook_url:
            print(f"[WEBHOOK] Missing webhook URL. Skipped for {notification.notification_id}")
            return

        payload = {
            "notification_id": notification.notification_id,
            "user_id": notification.user_id,
            "title": notification.title,
            "message": notification.message,
            "short_message": notification.short_message,
            "category": notification.category.value,
            "priority": notification.priority.value,
            "timestamp": notification.timestamp.isoformat(),
            "action_url": notification.action_url,
            "rich_data": notification.rich_data,
        }
        await self._post_json(webhook_url, payload, channel_name="WEBHOOK")

    async def _send_whatsapp(self, notification: Notification):
        """Send WhatsApp message"""
        webhook_url = str(
            notification.rich_data.get("whatsapp_webhook_url")
            or os.getenv("WHATSAPP_WEBHOOK_URL", "")
        ).strip()
        phone_number = str(notification.rich_data.get("whatsapp_number") or "").strip()
        payload = {
            "to": phone_number,
            "message": notification.short_message or notification.message,
            "title": notification.title,
            "notification_id": notification.notification_id,
            "user_id": notification.user_id,
            "priority": notification.priority.value,
            "category": notification.category.value,
            "timestamp": notification.timestamp.isoformat(),
        }
        if webhook_url:
            await self._post_json(webhook_url, payload, channel_name="WHATSAPP")
            return
        print(f"[WHATSAPP] Missing WHATSAPP_WEBHOOK_URL. Fallback log: {payload['message']}")

    async def _send_sms(self, notification: Notification):
        """Send SMS"""
        webhook_url = str(
            notification.rich_data.get("sms_webhook_url")
            or os.getenv("SMS_WEBHOOK_URL", "")
        ).strip()
        phone_number = str(notification.rich_data.get("phone_number") or "").strip()
        payload = {
            "to": phone_number,
            "message": notification.short_message or notification.message,
            "title": notification.title,
            "notification_id": notification.notification_id,
            "user_id": notification.user_id,
            "priority": notification.priority.value,
            "category": notification.category.value,
            "timestamp": notification.timestamp.isoformat(),
        }
        if webhook_url:
            await self._post_json(webhook_url, payload, channel_name="SMS")
            return
        print(f"[SMS] Missing SMS_WEBHOOK_URL. Fallback log: {payload['message']}")

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
                    "richData": notification.rich_data,
                    "channelsToSend": self._serialize_channels(notification.channels_to_send),
                    "deliveryStatus": self._serialize_delivery_status(notification.delivery_status),
                    "createdAt": datetime.utcnow(),
                },
                merge=True,
            )
        except Exception as exc:
            print(f"[IN_APP] Firestore unavailable: {exc}")

        print(f"[IN_APP] Stored notification for {notification.user_id}")

    async def _post_json(self, url: str, payload: Dict, channel_name: str):
        timeout = aiohttp.ClientTimeout(total=12)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, json=payload) as response:
                if response.status >= 400:
                    response_text = await response.text()
                    raise RuntimeError(
                        f"{channel_name} request failed with status {response.status}: {response_text}"
                    )
        print(f"[{channel_name}] Sent")

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

    def _extract_pair(self, template_vars: Dict) -> str:
        pair_fields = ["pair", "currency_pair", "symbol"]
        for field in pair_fields:
            raw_value = template_vars.get(field)
            if isinstance(raw_value, str) and "/" in raw_value:
                return raw_value.strip().upper()

        base_currency = template_vars.get("base_currency")
        quote_currency = template_vars.get("quote_currency")
        if isinstance(base_currency, str) and isinstance(quote_currency, str):
            if base_currency and quote_currency:
                return f"{base_currency.strip().upper()}/{quote_currency.strip().upper()}"

        return "EUR/USD"

    def _append_deep_study_summary(self, message: str, deep_study: Dict) -> str:
        coverage = deep_study.get("source_coverage", {})
        analyzed = coverage.get("analyzed", 0)
        requested = coverage.get("requested", 0)
        confidence = float(deep_study.get("consensus_score", 0.0) or 0.0)
        confidence_pct = round(confidence * 100, 1)
        recommendation = deep_study.get("recommendation", "wait_for_confirmation")

        summary = (
            f"\n\nDeep Study: confidence {confidence_pct}%, "
            f"sources {analyzed}/{requested}, signal={recommendation}."
        )
        return f"{message}{summary}"

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
                        "rich_data": data.get("richData") or data.get("rich_data") or {},
                        "channels_to_send": data.get("channelsToSend") or data.get("channels_to_send") or [],
                        "delivery_status": data.get("deliveryStatus") or data.get("delivery_status") or {},
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
                    "rich_data": n.rich_data,
                    "channels_to_send": self._serialize_channels(n.channels_to_send),
                    "delivery_status": self._serialize_delivery_status(n.delivery_status),
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
        prefs = self.user_preferences.get(user_id) or self._load_preferences_from_firestore(user_id)
        if not prefs:
            await self.set_notification_preferences(user_id=user_id)
            prefs = self.user_preferences.get(user_id)
        if not prefs:
            return {"error": "Preferences not configured"}
        self.user_preferences[user_id] = prefs
        
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
            "autonomous_mode": prefs.autonomous_mode,
            "autonomous_profile": prefs.autonomous_profile,
            "autonomous_min_confidence": prefs.autonomous_min_confidence,
            "autonomous_stage_alerts": prefs.autonomous_stage_alerts,
            "autonomous_stage_interval_seconds": prefs.autonomous_stage_interval_seconds,
            "channel_settings": prefs.channel_settings,
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
