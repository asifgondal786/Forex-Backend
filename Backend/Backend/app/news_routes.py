"""
app/news_routes.py
News feed, economic calendar, and macro shield endpoints.
Phase 3: /news/events and /news/macro-shield now use live ForexFactory data.
"""
import logging
from typing import Optional
from fastapi import APIRouter, Query
from app.services.market_intelligence_service import MarketIntelligenceService
market_intelligence_service = MarketIntelligenceService()
from app.services.macro_event_service import macro_event_service
from app.services.forex_factory_service import forex_factory_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/news", tags=["News & Events"])


@router.get("/feed", summary="Live forex news feed with sentiment")
async def get_news_feed(
    pair: Optional[str] = Query(default="EUR/USD"),
) -> dict:
    try:
        result = await market_intelligence_service.get_market_intelligence(
            pair=pair or "EUR/USD"
        )
        return result
    except Exception as e:
        logger.exception("News feed error")
        return {"error": str(e), "top_headlines": [], "status": "error"}


@router.get("/events", summary="Live economic calendar from ForexFactory")
async def get_economic_events(
    hours: int = Query(default=48, ge=1, le=168),
    high_impact_only: bool = Query(default=False),
) -> dict:
    try:
        # Phase 3: live ForexFactory feed with static fallback
        events = await forex_factory_service.get_events(
            hours=hours,
            high_impact_only=high_impact_only,
        )
        return {
            "events": events,
            "count": len(events),
            "hours_window": hours,
            "source": "forexfactory_live",
        }
    except Exception as e:
        logger.exception("Economic events error")
        # Hard fallback to static service
        events = macro_event_service.get_upcoming_events(
            window_hours=hours,
            only_high_impact=high_impact_only,
        )
        return {
            "events": events,
            "count": len(events),
            "hours_window": hours,
            "source": "static_fallback",
        }


@router.get("/macro-shield", summary="Macro Event Shield status")
async def get_macro_shield(
    pre_minutes: int = Query(default=30, ge=5, le=120),
) -> dict:
    try:
        # Phase 3: live shield using ForexFactory
        shield = await forex_factory_service.is_shield_active(
            pre_minutes=pre_minutes
        )
        # Enrich with next 3 high-impact events for Flutter countdown
        upcoming = await forex_factory_service.get_events(
            hours=72, high_impact_only=True
        )
        shield["upcoming_high_impact"] = upcoming[:3]
        shield["pre_minutes"] = pre_minutes
        return shield
    except Exception as e:
        logger.exception("Macro shield error")
        return {
            "shield_active": False,
            "reason": f"Shield check error: {e}",
            "next_event": None,
            "minutes_until": None,
            "upcoming_high_impact": [],
        }


@router.get("/health", summary="News service health")
async def news_health() -> dict:
    try:
        next_event = await forex_factory_service.get_next_high_impact()
        cached_count = len(forex_factory_service._cache)
        return {
            "status": "ok",
            "source": "forexfactory_live",
            "cached_events": cached_count,
            "next_high_impact": next_event.get("title") if next_event else None,
            "macro_events_loaded": cached_count,
        }
    except Exception as e:
        return {"status": "error", "error": str(e)}