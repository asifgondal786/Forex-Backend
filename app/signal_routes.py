"""
app/signal_routes.py
Phase 4 - Signal Fusion Endpoints
"""
import logging
import os
from typing import Optional
from fastapi import APIRouter, HTTPException, Query, Request
from app.services.signal_service import SignalResponse, generate_signals

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/signals", tags=["Trade Signals"])


@router.post("/generate", response_model=SignalResponse, summary="Generate fused AI trade signals")
async def generate_trade_signals(
    request: Request,
    pairs: Optional[str] = Query(default=None, description="Comma-separated pairs"),
) -> SignalResponse:
    requested = (
        [p.strip().upper() for p in pairs.split(",") if p.strip()]
        if pairs else None
    )
    redis = getattr(request.app.state, "redis", None)
    try:
        result = await generate_signals(pairs=requested, redis_client=redis)
    except Exception as e:
        logger.exception("Error generating signals")
        raise HTTPException(status_code=500, detail=str(e))
    if not result.signals:
        raise HTTPException(status_code=503, detail="Signal generation failed - check API keys")
    return result


@router.get("/indicators/{pair}", summary="Get RSI + MACD for a pair")
async def get_indicators(pair: str) -> dict:
    from app.services.technical_analysis_service import get_technical_indicators
    try:
        pair_clean = pair.upper().replace("-", "_").replace("/", "_")
        result = await get_technical_indicators(pair_clean)
        return {"pair": pair_clean, **result}
    except Exception as e:
        logger.exception("Indicator fetch error")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/health", summary="Signal service health check")
async def signals_health() -> dict:
    return {
        "status":           "ok",
        "phase":            4,
        "fusion_enabled":   True,
        "gemini_key_set":   bool(os.getenv("GEMINI_API_KEY")),
        "news_api_key_set": bool(os.getenv("NEWS_API_KEY")),
        "supabase_url_set": bool(os.getenv("SUPABASE_URL")),
        "supabase_key_set": bool(os.getenv("SUPABASE_SERVICE_ROLE_KEY")),
        "twelve_data_set":  bool(os.getenv("TWELVE_DATA_API_KEY")),
    }