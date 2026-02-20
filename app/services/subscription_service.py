"""
Subscription and feature-gating service.

Supports a free-first rollout with optional paid gating for selected features.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Dict, Optional
import os

from fastapi import HTTPException

from ..utils.firestore_client import get_firestore_client


def _env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


class SubscriptionService:
    _PLAN_ORDER: Dict[str, int] = {
        "free": 0,
        "premium": 1,
        "enterprise": 2,
    }

    # Feature-level minimum plans when paywall is enabled.
    _FEATURE_MIN_PLAN: Dict[str, str] = {
        "live_broker_execution": "premium",
        "full_autonomy": "premium",
        "api_key_management": "premium",
    }

    def __init__(self) -> None:
        self._subscriptions_by_user: Dict[str, Dict[str, Any]] = {}
        self._firestore = None
        self._firestore_disabled = False

        self.paywall_enabled = _env_bool("SUBSCRIPTION_PAYWALL_ENABLED", False)
        self.allow_dev_bypass = _env_bool("SUBSCRIPTION_ALLOW_DEV_BYPASS", True)
        self.allow_self_service_management = _env_bool(
            "SUBSCRIPTION_ALLOW_SELF_SERVICE_MANAGEMENT",
            _env_bool("DEBUG", False),
        )
        try:
            self.premium_price_usd = float(os.getenv("SUBSCRIPTION_PREMIUM_PRICE_USD", "10"))
        except ValueError:
            self.premium_price_usd = 10.0

    def _normalize_plan(self, plan: Optional[str]) -> str:
        value = (plan or "").strip().lower()
        if value in self._PLAN_ORDER:
            return value
        return "free"

    def _normalize_status(self, status: Optional[str]) -> str:
        value = (status or "").strip().lower()
        if value in {"active", "trialing", "past_due", "cancelled"}:
            return value
        return "active"

    def _get_firestore(self):
        if self._firestore_disabled:
            return None
        if self._firestore is not None:
            return self._firestore
        try:
            self._firestore = get_firestore_client()
            return self._firestore
        except Exception:
            self._firestore_disabled = True
            return None

    def _default_subscription(self, user_id: str) -> Dict[str, Any]:
        now = _now_iso()
        return {
            "user_id": user_id,
            "plan": "free",
            "status": "active",
            "source": "default",
            "subscribed_at": now,
            "updated_at": now,
            "renews_on": None,
            "expires_on": None,
            "paywall_enabled": self.paywall_enabled,
            "premium_price_usd": self.premium_price_usd,
        }

    def _load_from_firestore(self, user_id: str) -> Optional[Dict[str, Any]]:
        db = self._get_firestore()
        if db is None:
            return None
        doc = db.collection("user_subscriptions").document(user_id).get()
        if not doc.exists:
            return None
        data = doc.to_dict() or {}
        now = _now_iso()
        return {
            "user_id": user_id,
            "plan": self._normalize_plan(data.get("plan")),
            "status": self._normalize_status(data.get("status")),
            "source": str(data.get("source") or "firestore"),
            "subscribed_at": str(data.get("subscribed_at") or now),
            "updated_at": str(data.get("updated_at") or now),
            "renews_on": data.get("renews_on"),
            "expires_on": data.get("expires_on"),
            "paywall_enabled": self.paywall_enabled,
            "premium_price_usd": self.premium_price_usd,
        }

    def _persist(self, subscription: Dict[str, Any]) -> None:
        db = self._get_firestore()
        if db is None:
            return
        db.collection("user_subscriptions").document(subscription["user_id"]).set(
            {
                "user_id": subscription["user_id"],
                "plan": subscription["plan"],
                "status": subscription["status"],
                "source": subscription["source"],
                "subscribed_at": subscription["subscribed_at"],
                "updated_at": subscription["updated_at"],
                "renews_on": subscription["renews_on"],
                "expires_on": subscription["expires_on"],
            },
            merge=True,
        )

    def get_subscription(self, user_id: str) -> Dict[str, Any]:
        cached = self._subscriptions_by_user.get(user_id)
        if cached:
            cached["paywall_enabled"] = self.paywall_enabled
            cached["premium_price_usd"] = self.premium_price_usd
            return dict(cached)

        loaded = self._load_from_firestore(user_id)
        if loaded is None:
            loaded = self._default_subscription(user_id)

        self._subscriptions_by_user[user_id] = dict(loaded)
        return dict(loaded)

    def set_subscription(
        self,
        user_id: str,
        plan: str,
        status: str = "active",
        source: str = "manual",
        renews_on: Optional[str] = None,
        expires_on: Optional[str] = None,
    ) -> Dict[str, Any]:
        current = self.get_subscription(user_id)
        updated = {
            **current,
            "plan": self._normalize_plan(plan),
            "status": self._normalize_status(status),
            "source": (source or "manual").strip() or "manual",
            "updated_at": _now_iso(),
            "renews_on": renews_on,
            "expires_on": expires_on,
            "paywall_enabled": self.paywall_enabled,
            "premium_price_usd": self.premium_price_usd,
        }
        self._subscriptions_by_user[user_id] = dict(updated)
        self._persist(updated)
        return dict(updated)

    def _compare_plan_rank(self, current_plan: str, required_plan: str) -> bool:
        current_rank = self._PLAN_ORDER.get(self._normalize_plan(current_plan), 0)
        required_rank = self._PLAN_ORDER.get(self._normalize_plan(required_plan), 0)
        return current_rank >= required_rank

    def check_feature_access(self, user_id: str, feature: str) -> Dict[str, Any]:
        feature_key = (feature or "").strip().lower()
        subscription = self.get_subscription(user_id)
        plan = self._normalize_plan(subscription.get("plan"))
        status = self._normalize_status(subscription.get("status"))
        required_plan = self._FEATURE_MIN_PLAN.get(feature_key)

        if not self.paywall_enabled:
            return {
                "allowed": True,
                "reason": "paywall_disabled",
                "feature": feature_key,
                "required_plan": required_plan,
                "plan": plan,
                "status": status,
                "paywall_enabled": self.paywall_enabled,
                "premium_price_usd": self.premium_price_usd,
            }

        if self.allow_dev_bypass and user_id.startswith("dev_"):
            return {
                "allowed": True,
                "reason": "dev_bypass",
                "feature": feature_key,
                "required_plan": required_plan,
                "plan": plan,
                "status": status,
                "paywall_enabled": self.paywall_enabled,
                "premium_price_usd": self.premium_price_usd,
            }

        if required_plan is None:
            return {
                "allowed": True,
                "reason": "unrestricted_feature",
                "feature": feature_key,
                "required_plan": None,
                "plan": plan,
                "status": status,
                "paywall_enabled": self.paywall_enabled,
                "premium_price_usd": self.premium_price_usd,
            }

        if status not in {"active", "trialing"}:
            return {
                "allowed": False,
                "reason": "inactive_subscription",
                "feature": feature_key,
                "required_plan": required_plan,
                "plan": plan,
                "status": status,
                "paywall_enabled": self.paywall_enabled,
                "premium_price_usd": self.premium_price_usd,
            }

        allowed = self._compare_plan_rank(plan, required_plan)
        return {
            "allowed": allowed,
            "reason": "plan_sufficient" if allowed else "plan_upgrade_required",
            "feature": feature_key,
            "required_plan": required_plan,
            "plan": plan,
            "status": status,
            "paywall_enabled": self.paywall_enabled,
            "premium_price_usd": self.premium_price_usd,
        }

    def ensure_feature_access(self, user_id: str, feature: str) -> Dict[str, Any]:
        decision = self.check_feature_access(user_id=user_id, feature=feature)
        if decision.get("allowed"):
            return decision
        raise HTTPException(
            status_code=402,
            detail={
                "message": (
                    f"Feature '{decision.get('feature')}' requires "
                    f"{decision.get('required_plan', 'a paid')} plan."
                ),
                "code": "SUBSCRIPTION_REQUIRED",
                **decision,
            },
        )

    def get_feature_matrix(self, user_id: str) -> Dict[str, Any]:
        features = sorted(set(self._FEATURE_MIN_PLAN.keys()))
        access_map: Dict[str, Dict[str, Any]] = {}
        for feature in features:
            access_map[feature] = self.check_feature_access(user_id=user_id, feature=feature)
        return {
            "user_id": user_id,
            "subscription": self.get_subscription(user_id),
            "features": access_map,
        }


subscription_service = SubscriptionService()
