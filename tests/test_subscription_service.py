from fastapi import HTTPException

from app.services.subscription_service import SubscriptionService


def test_feature_access_allows_free_when_paywall_disabled(monkeypatch):
    monkeypatch.setenv("SUBSCRIPTION_PAYWALL_ENABLED", "false")
    service = SubscriptionService()

    decision = service.check_feature_access(
        user_id="user_free_no_paywall",
        feature="live_broker_execution",
    )

    assert decision["allowed"] is True
    assert decision["reason"] == "paywall_disabled"


def test_feature_access_blocks_free_when_paywall_enabled(monkeypatch):
    monkeypatch.setenv("SUBSCRIPTION_PAYWALL_ENABLED", "true")
    monkeypatch.setenv("SUBSCRIPTION_ALLOW_DEV_BYPASS", "false")
    service = SubscriptionService()

    decision = service.check_feature_access(
        user_id="user_free_paywall",
        feature="live_broker_execution",
    )

    assert decision["allowed"] is False
    assert decision["reason"] == "plan_upgrade_required"


def test_feature_access_allows_premium_when_paywall_enabled(monkeypatch):
    monkeypatch.setenv("SUBSCRIPTION_PAYWALL_ENABLED", "true")
    monkeypatch.setenv("SUBSCRIPTION_ALLOW_DEV_BYPASS", "false")
    service = SubscriptionService()
    service.set_subscription(user_id="user_premium", plan="premium")

    decision = service.check_feature_access(
        user_id="user_premium",
        feature="live_broker_execution",
    )

    assert decision["allowed"] is True
    assert decision["reason"] == "plan_sufficient"


def test_ensure_feature_access_raises_payment_required(monkeypatch):
    monkeypatch.setenv("SUBSCRIPTION_PAYWALL_ENABLED", "true")
    monkeypatch.setenv("SUBSCRIPTION_ALLOW_DEV_BYPASS", "false")
    service = SubscriptionService()

    try:
        service.ensure_feature_access(
            user_id="user_denied",
            feature="full_autonomy",
        )
        assert False, "Expected HTTPException"
    except HTTPException as exc:
        assert exc.status_code == 402
