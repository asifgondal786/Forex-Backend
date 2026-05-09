"""
Backend/app/api/v1/market_routes.py

FastAPI router for live market data endpoints.
Register under /api/v1/market via main.py include_router call.

Endpoints:
  GET /api/v1/market/prices          — prices for default pairs
  GET /api/v1/market/prices?pairs=.. — prices for specific pairs
  GET /api/v1/market/supported       — list all supported instruments
  GET /api/v1/market/health          — connectivity check
  GET /api/v1/market/ohlc            — OHLC candlestick data
  GET /api/v1/market/sentiment       — market sentiment analysis

NOTE: If /api/v1/market/sentiment returns 404, check that main.py includes:
  app.include_router(market_router)
  where market_router is imported from this file.
"""

import logging
import traceback as _tb
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import JSONResponse

from app.services.market_data_service import (
    get_ohlc_data,
    MarketPricesResponse,
    SUPPORTED_PAIRS,
    DEFAULT_PAIRS,
    get_market_prices,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/market", tags=["Market Data"])


async def get_redis(request: Request):
    return getattr(request.app.state, "redis", None)


@router.get(
    "/prices",
    response_model=MarketPricesResponse,
    summary="Get live forex prices",
)
async def get_prices(
    pairs: Optional[str] = Query(
        default=None,
        description="Comma-separated instruments e.g. EUR_USD,GBP_USD,USD_JPY",
        example="EUR_USD,GBP_USD,USD_JPY",
    ),
    redis=Depends(get_redis),
) -> MarketPricesResponse:
    requested = (
        [p.strip().upper() for p in pairs.split(",") if p.strip()]
        if pairs else DEFAULT_PAIRS
    )

    try:
        result = await get_market_prices(pairs=requested, redis_client=redis)
    except Exception as e:
        logger.exception("Error in /market/prices")
        raise HTTPException(status_code=500, detail=str(e))

    if not result.prices and result.source == "error_fallback":
        raise HTTPException(
            status_code=503,
            detail="Market data unavailable. Check TWELVE_DATA_API_KEY environment variable.",
        )

    return result


@router.get("/supported", summary="List supported instruments")
async def get_supported_instruments() -> dict:
    return {
        "instruments": SUPPORTED_PAIRS,
        "default": DEFAULT_PAIRS,
        "count": len(SUPPORTED_PAIRS),
        "source": "Twelve Data (twelvedata.com)",
    }


@router.get("/health", summary="Market data health check")
async def market_health(request: Request, redis=Depends(get_redis)) -> dict:
    import os
    try:
        result = await get_market_prices(pairs=["EUR_USD"], redis_client=redis)
        ok = bool(result.prices) and result.source != "error_fallback"
        return {
            "status": "ok" if ok else "degraded",
            "source": result.source,
            "cached": result.cached,
            "price_count": len(result.prices),
            "key_set": bool(os.getenv("TWELVE_DATA_API_KEY")),
        }
    except Exception as e:
        logger.error("MARKET_HEALTH_ERROR: %s\n%s", str(e), _tb.format_exc())
        return {
            "status": "error",
            "error": str(e),
            "traceback": _tb.format_exc(),
        }


@router.get("/ohlc", summary="OHLC candlestick data for charting")
async def get_ohlc(
    pair: str = "EUR/USD",
    interval: str = "1h",
    outputsize: int = 100,
) -> dict:
    return await get_ohlc_data(pair=pair, interval=interval, outputsize=outputsize)


# ═══════════════════════════════════════════════════════════════════════
# Market Sentiment — called by Flutter dashboard + signal provider
# GET /api/v1/market/sentiment?pair=EUR/USD
# ═══════════════════════════════════════════════════════════════════════

@router.get("/sentiment", summary="Market sentiment analysis")
async def market_sentiment(pair: Optional[str] = Query(default=None)) -> dict:
    """
    Returns market sentiment data for the dashboard and signal screens.
    Pulls from GDELT, news analysis, and AI sentiment scoring.

    Query param: pair (optional) — e.g. EUR/USD
    If omitted, returns general forex sentiment.
    """
    from app.services.forex_data_service import get_sentiment

    # Normalise: None → "general", strip whitespace
    pair_normalised = (pair or "general").strip()

    try:
        sentiment_data = await get_sentiment(
            pair_normalised if pair_normalised != "general" else None
        )

        return {
            "status": "success",
            "sentiment": sentiment_data.get("sentiment", "neutral"),
            "score": sentiment_data.get("score", 0.0),
            "source": sentiment_data.get("source", "unavailable"),
            "pair": pair_normalised,
            "article_count": sentiment_data.get("article_count", 0),
            "details": sentiment_data,
        }
    except Exception as e:
        logger.warning("Sentiment endpoint error for pair=%s: %s", pair_normalised, e)
        # Return neutral on error — don't crash the dashboard
        return {
            "status": "degraded",
            "sentiment": "neutral",
            "score": 0.0,
            "source": "unavailable",
            "pair": pair_normalised,
            "error": str(e)[:200],
        }