from enum import Enum
import asyncio

class NotificationType(Enum):
    """
    Enum for different types of notifications.
    """
    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    SUCCESS = "success"

class NotificationService:
    """
    Service to handle sending notifications to users.
    This is a placeholder and can be extended to send emails, push notifications, etc.
    """
    def __init__(self):
        # In a real application, this would be initialized with connection
        # details for services like Firebase Cloud Messaging, SendGrid, etc.
        print("Initializing Notification Service...")

    async def send_notification(self, user_id: str, message: str, notification_type: NotificationType):
        """
        Sends a notification to a specific user.
        
        For now, it just prints to the console. This should be replaced with
        a real notification system.
        """
        # --- Placeholder for actual notification logic ---
        # This could involve:
        # - Looking up user's device token from a database.
        # - Sending a push notification via Firebase Cloud Messaging.
        # - Sending an email via SendGrid or a similar service.
        # - Pushing a message to a user-specific WebSocket channel.

        log_message = f"[{notification_type.name.upper()}] Notification for User '{user_id}': {message}"

        print(log_message)

        # Simulate an async operation
        await asyncio.sleep(0.01)

        # Returning true for now to indicate mock success
        return True

async def main():
    """ Test function for NotificationService. """
    service = NotificationService()

    print("\n--- Testing Notifications ---")

    # Test sending different types of notifications
    await service.send_notification(
        "user_001",
        "Your trade for EUR/USD has been successfully executed.",
        NotificationType.SUCCESS
    )

    await service.send_notification(
        "user_002",
        "Market volatility is high for GBP/JPY. Consider reviewing your positions.",
        NotificationType.WARNING
    )

    await service.send_notification(
        "user_001",
        "Failed to execute trade: Insufficient funds.",
        NotificationType.ERROR
    )

    await service.send_notification(
        "user_003",
        "A new AI analysis report for AUD/USD is available.",
        NotificationType.INFO
    )

if __name__ == "__main__":
    asyncio.run(main())

# Phase 13: Bridge to EnhancedNotificationService
import logging as _logging
_notif_logger = _logging.getLogger(__name__)

async def notify_trade_executed(user_id: str, trade_data: dict) -> None:
    try:
        from app.services.enhanced_notification_service import EnhancedNotificationService
        svc = EnhancedNotificationService()
        await svc.send_trade_notification(user_id=user_id, trade_data=trade_data)
    except Exception as _e:
        _notif_logger.warning("notify_trade_executed failed: %s", _e)

async def notify_risk_alert(user_id: str, risk_data: dict) -> None:
    try:
        from app.services.enhanced_notification_service import EnhancedNotificationService
        svc = EnhancedNotificationService()
        await svc.send_risk_alert(user_id=user_id, risk_data=risk_data)
    except Exception as _e:
        _notif_logger.warning("notify_risk_alert failed: %s", _e)

async def notify_new_signal(user_id: str, signal_data: dict) -> None:
    try:
        from app.services.enhanced_notification_service import EnhancedNotificationService
        svc = EnhancedNotificationService()
        await svc.send_signal_notification(user_id=user_id, signal_data=signal_data)
    except Exception as _e:
        _notif_logger.warning("notify_new_signal failed: %s", _e)
