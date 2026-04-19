"""
Macro Event Service
Provides a lightweight "Macro Event Shield" for high-impact economic events
such as FOMC, CPI, and NFP.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional
import os
import json


@dataclass
class MacroEvent:
    """Represents a single macroeconomic event."""

    id: str
    name: str
    currency: str
    category: str  # e.g. FOMC, CPI, NFP, GDP
    impact: str  # low, medium, high
    start_time: datetime
    end_time: datetime

    @property
    def is_high_impact(self) -> bool:
        return self.impact.lower() == "high"

    def to_dict(self) -> Dict:
        return {
            "id": self.id,
            "name": self.name,
            "currency": self.currency,
            "category": self.category,
            "impact": self.impact,
            "start_time": self.start_time.isoformat(),
            "end_time": self.end_time.isoformat(),
        }


class MacroEventService:
    """
    In-memory macro event provider with optional JSON overrides.

    This is intentionally simple: events are either loaded from an env JSON
    blob (MACRO_EVENTS_JSON) or from a small baked-in schedule template.
    """

    def __init__(self) -> None:
        self._events: List[MacroEvent] = self._load_events()
        # Minutes before and after a high-impact event where autonomous trading
        # should be paused by default. These can be tuned via env.
        self.pre_event_minutes = int(os.getenv("MACRO_SHIELD_PRE_MINUTES", "90"))
        self.post_event_minutes = int(os.getenv("MACRO_SHIELD_POST_MINUTES", "30"))

    def _load_events(self) -> List[MacroEvent]:
        raw = os.getenv("MACRO_EVENTS_JSON")
        if raw:
            try:
                data = json.loads(raw)
                return self._parse_events_from_json(data)
            except Exception:
                # Fall back to baked-in schedule when JSON is malformed.
                pass
        return self._default_events()

    def _parse_events_from_json(self, data: object) -> List[MacroEvent]:
        events: List[MacroEvent] = []
        if not isinstance(data, list):
            return events

        for idx, item in enumerate(data):
            if not isinstance(item, dict):
                continue
            try:
                start_raw = str(item.get("start_time") or "")
                end_raw = str(item.get("end_time") or "")
                start = datetime.fromisoformat(start_raw.replace("Z", "+00:00"))
                end = (
                    datetime.fromisoformat(end_raw.replace("Z", "+00:00"))
                    if end_raw
                    else start + timedelta(minutes=30)
                )
                events.append(
                    MacroEvent(
                        id=str(item.get("id") or f"custom_{idx}"),
                        name=str(item.get("name") or "Macro Event"),
                        currency=str(item.get("currency") or "USD"),
                        category=str(item.get("category") or "GENERIC"),
                        impact=str(item.get("impact") or "high"),
                        start_time=start.astimezone(timezone.utc),
                        end_time=end.astimezone(timezone.utc),
                    )
                )
            except Exception:
                continue
        return events

    def _default_events(self) -> List[MacroEvent]:
        """Very small rolling template; real schedules should use JSON overrides."""
        now = datetime.now(timezone.utc)
        # Anchor template around "today" in UTC; these are illustrative.
        base_date = now.replace(hour=0, minute=0, second=0, microsecond=0)

        return [
            MacroEvent(
                id="fomc_template",
                name="FOMC Rate Decision",
                currency="USD",
                category="FOMC",
                impact="high",
                start_time=base_date.replace(hour=18),  # 18:00 UTC
                end_time=base_date.replace(hour=19),
            ),
            MacroEvent(
                id="cpi_template",
                name="US CPI Release",
                currency="USD",
                category="CPI",
                impact="high",
                start_time=base_date.replace(hour=12, minute=30),
                end_time=base_date.replace(hour=13),
            ),
            MacroEvent(
                id="nfp_template",
                name="US Non-Farm Payrolls",
                currency="USD",
                category="NFP",
                impact="high",
                start_time=base_date.replace(hour=12, minute=30),
                end_time=base_date.replace(hour=13),
            ),
        ]

    def list_events(self) -> List[Dict]:
        """Return all configured macro events as dictionaries."""
        return [event.to_dict() for event in self._events]

    def get_upcoming_events(
        self,
        window_hours: int = 24,
        only_high_impact: bool = True,
    ) -> List[Dict]:
        """
        Return events occurring in the next `window_hours` window.
        """
        now = datetime.now(timezone.utc)
        window_end = now + timedelta(hours=window_hours)
        results: List[Dict] = []
        for event in self._events:
            if only_high_impact and not event.is_high_impact:
                continue
            if event.end_time < now:
                continue
            if event.start_time > window_end:
                continue
            results.append(event.to_dict())
        return results

    def compute_shield_for_user(self, user_id: str) -> Dict:
        """
        Compute whether Macro Event Shield should pause autonomy at this moment.

        The decision is global by design (same for all users) but we keep
        `user_id` in the signature for future per-user overrides.
        """
        now = datetime.now(timezone.utc)
        pre_window = timedelta(minutes=self.pre_event_minutes)
        post_window = timedelta(minutes=self.post_event_minutes)

        upcoming = self.get_upcoming_events(window_hours=48, only_high_impact=True)
        closest: Optional[MacroEvent] = None
        closest_delta: Optional[timedelta] = None
        shield_active = False

        for raw in upcoming:
            try:
                start = datetime.fromisoformat(
                    str(raw["start_time"]).replace("Z", "+00:00")
                ).astimezone(timezone.utc)
                end = datetime.fromisoformat(
                    str(raw["end_time"]).replace("Z", "+00:00")
                ).astimezone(timezone.utc)
            except Exception:
                continue

            # Determine if we are inside the shield window for this event.
            shield_start = start - pre_window
            shield_end = end + post_window
            in_window = shield_start <= now <= shield_end

            if in_window:
                shield_active = True
                event = MacroEvent(
                    id=str(raw.get("id") or "macro"),
                    name=str(raw.get("name") or "Macro Event"),
                    currency=str(raw.get("currency") or "USD"),
                    category=str(raw.get("category") or "GENERIC"),
                    impact=str(raw.get("impact") or "high"),
                    start_time=start,
                    end_time=end,
                )
                closest = event
                closest_delta = min(
                    closest_delta or timedelta.max,
                    min(abs(start - now), abs(end - now)),
                )
                break

            # Otherwise track the closest upcoming event for messaging.
            if start > now:
                delta = start - now
                if closest_delta is None or delta < closest_delta:
                    closest_delta = delta
                    closest = MacroEvent(
                        id=str(raw.get("id") or "macro"),
                        name=str(raw.get("name") or "Macro Event"),
                        currency=str(raw.get("currency") or "USD"),
                        category=str(raw.get("category") or "GENERIC"),
                        impact=str(raw.get("impact") or "high"),
                        start_time=start,
                        end_time=end,
                    )

        result: Dict = {
            "shield_active": shield_active,
            "reason": None,
            "next_event": None,
        }
        if closest is not None:
            result["next_event"] = closest.to_dict()
            minutes_until = int((closest.start_time - now).total_seconds() // 60)
            if shield_active:
                result["reason"] = (
                    f"Macro event shield: {closest.name} window active "
                    f"({closest.category})"
                )
            else:
                result["reason"] = (
                    f"Macro event shield: {closest.name} in approximately "
                    f"{max(minutes_until, 0)} minutes"
                )
        return result


macro_event_service = MacroEventService()

