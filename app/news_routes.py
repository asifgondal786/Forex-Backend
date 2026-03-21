"""
Backend/app/news_routes.py

Task 10 - Real News Feed + Economic Calendar + Macro Shield
Exposes existing market_intelligence_service and macro_event_service via API.

Endpoints:
  GET /api/v1/news/feed          - live articles with sentiment from 20+ sources
  GET /api/v1/news/events        - economic calendar events (FOMC/CPI/NFP)
  GET /api/v1/news/macro-shield  - current macro shield status
  GET /api/v1/news/health        - service health check
"""

import logging
from typing import Optional
from fastapi import APIRouter, Query, Request
from app.services.market_intelligence_service import MarketIntelligenceService
from app.services.macro_event_service import macro_event_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/news", tags=["News & Events"])

_intelligence = MarketIntelligenceService()


@router.get("/feed", summary="Live forex news feed with sentiment")
async def get_news_feed(
    pair: Optional[str] = Query(default="EUR/USD", description="Currency pair e.g. EUR/USD"),
    limit: Optional[int] = Query(default=3, description="Max headlines per source"),
) -> dict:
    try:
        report = await _intelligence.build_deep_study(
            pair=pair or "EUR/USD",
            max_headlines_per_source=min(limit or 3, 5),
        )
        return {
            "status": "ok",
            "pair": report.get("pair"),
            "sentiment_score": report.get("sentiment_score"),
            "consensus_score": report.get("consensus_score"),
            "confidence_band": report.get("confidence_band"),
            "recommendation": report.get("recommendation"),
            "top_headlines": report.get("top_headlines", []),
            "source_coverage": report.get("source_coverage"),
            "generated_at": report.get("generated_at"),
            "cached": report.get("cached", False),
        }
    except Exception as e:
        logger.exception("Error fetching news feed")
        return {"status": "error", "error": str(e), "top_headlines": []}


@router.get("/events", summary="Economic calendar events")
async def get_economic_events(
    hours: Optional[int] = Query(default=24, description="Look-ahead window in hours"),
    high_impact_only: Optional[bool] = Query(default=True, description="Filter to high impact only"),
) -> dict:
    try:
        events = macro_event_service.get_upcoming_events(
            window_hours=hours or 24,
            only_high_impact=high_impact_only if high_impact_only is not None else True,
        )
        return {
            "status": "ok",
            "events": events,
            "count": len(events),
            "window_hours": hours,
            "high_impact_only": high_impact_only,
        }
    except Exception as e:
        logger.exception("Error fetching economic events")
        return {"status": "error", "error": str(e), "events": []}


@router.get("/macro-shield", summary="Macro Event Shield status")
async def get_macro_shield(
    user_id: Optional[str] = Query(default="anonymous"),
) -> dict:
    try:
        shield = macro_event_service.compute_shield_for_user(user_id or "anonymous")
        return {
            "status": "ok",
            "shield_active": shield.get("shield_active", False),
            "reason": shield.get("reason"),
            "next_event": shield.get("next_event"),
            "pre_event_minutes": macro_event_service.pre_event_minutes,
            "post_event_minutes": macro_event_service.post_event_minutes,
        }
    except Exception as e:
        logger.exception("Error computing macro shield")
        return {"status": "error", "error": str(e), "shield_active": False}


@router.get("/health", summary="News service health check")
async def news_health() -> dict:
    import os
    return {
        "status": "ok",
        "news_api_key_set": bool(os.getenv("NEWS_API_KEY")),
        "macro_events_loaded": len(macro_event_service._events),
        "intelligence_service": "active",
    }
