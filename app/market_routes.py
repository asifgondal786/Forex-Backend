"""
Backend/app/market_routes.py

FastAPI router for live market data endpoints.
Register under /api/v1/market via main.py — no changes needed here
regardless of whether the data source is OANDA or Twelve Data.

Endpoints:
  GET /api/v1/market/prices          — prices for default pairs (EUR_USD, GBP_USD, USD_JPY)
  GET /api/v1/market/prices?pairs=.. — prices for specific pairs
  GET /api/v1/market/supported       — list all supported instruments
  GET /api/v1/market/health          — connectivity check
"""

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import JSONResponse

from app.services.market_data_service import (
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
async def market_health(redis=Depends(get_redis)) -> dict:
    result = await get_market_prices(pairs=["EUR_USD"], redis_client=redis)
    ok = bool(result.prices) and result.source != "error_fallback"
    return {
        "status": "ok" if ok else "degraded",
        "source": result.source,
        "cached": result.cached,
        "price_count": len(result.prices),
    }
@router.get("/debug")
async def market_debug() -> dict:
    import os, httpx
    key = os.getenv("TWELVE_DATA_API_KEY", "")
    result = {"key_set": bool(key), "key_prefix": key[:6] if key else "none"}
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                "https://api.twelvedata.com/price",
                params={"symbol": "EUR/USD", "apikey": key, "dp": 5},
            )
        result["status_code"] = resp.status_code
        result["response"] = resp.json()
    except Exception as e:
        result["error"] = str(e)
    return result

