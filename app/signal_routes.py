"""
Backend/app/signal_routes.py

Task 9 - Trade Signal Endpoints
POST /api/v1/signals/generate  - generate AI trade signals
GET  /api/v1/signals/health    - check signal service health
"""

import logging
from typing import Optional
from fastapi import APIRouter, HTTPException, Query, Request
from app.services.signal_service import SignalResponse, generate_signals

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/signals", tags=["Trade Signals"])


async def get_redis(request: Request):
    return getattr(request.app.state, "redis", None)


@router.post(
    "/generate",
    response_model=SignalResponse,
    summary="Generate AI trade signals",
)
async def generate_trade_signals(
    request: Request,
    pairs: Optional[str] = Query(
        default=None,
        description="Comma-separated pairs e.g. EUR_USD,GBP_USD",
        example="EUR_USD,GBP_USD,USD_JPY",
    ),
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


@router.get("/debug-gemini")
async def debug_gemini() -> dict:
    import os
    from google import genai
    key = os.getenv("GEMINI_API_KEY", "")
    error = ""
    result = ""
    try:
        client = genai.Client(api_key=key)
        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents="Say hello",
        )
        result = str(response.text)
    except Exception as e:
        error = str(e)
    return {
        "key_length": len(key),
        "result": result,
        "error": error,
        "success": bool(result),
    }

@router.get("/health", summary="Signal service health check")
async def signals_health() -> dict:
    import os
    return {
        "status": "ok",
        "gemini_key_set":   bool(os.getenv("GEMINI_API_KEY")),
        "news_api_key_set": bool(os.getenv("NEWS_API_KEY")),
        "supabase_url_set": bool(os.getenv("SUPABASE_URL")),
        "supabase_key_set": bool(os.getenv("SUPABASE_SERVICE_ROLE_KEY")),
    }



