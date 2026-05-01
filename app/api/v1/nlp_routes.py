"""
app/api/v1/nlp_routes.py
NLP + AI endpoints for Tajir.

Routes:
  POST /api/v1/nlp/command          — Main endpoint. Flutter nlp_chat_sheet calls this.
  POST /api/v1/nlp/deepseek/analyze — DeepSeek market analysis (direct).
  GET  /api/v1/nlp/health           — Health check for both AI clients.
"""
from __future__ import annotations

import logging
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.services.nlp_command_service import process_nlp_command
from app.ai.deepseek_client import deepseek_client
from app.ai.openai_client import claude_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/nlp", tags=["NLP"])


# ── Request / Response models ─────────────────────────────────────────────────

class NlpCommandRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=500, description="Raw user command")
    account_balance: float = Field(default=10_000.0, ge=0, description="User paper account balance")
    validate_trades: bool = Field(default=True, description="Run DeepSeek validation on trades")


class DeepSeekAnalyzeRequest(BaseModel):
    pair: str = Field(..., description="Forex pair e.g. EUR_USD")
    context: Optional[str] = Field(None, description="Additional context for analysis")
    timeframe: Optional[str] = Field("1h", description="Timeframe: 1h, 4h, 1d")


# ── Routes ────────────────────────────────────────────────────────────────────

@router.post("/command")
async def nlp_command(req: NlpCommandRequest) -> dict[str, Any]:
    """
    Main NLP endpoint. Called by nlp_chat_sheet.dart.
    
    Pipeline:
      OpenAI (GPT-4o-mini) → parses intent + parameters
      DeepSeek             → validates OPEN_TRADE intents
      Regex fallback       → if OpenAI unavailable
    
    Flutter reads: response, intent, requires_confirmation, pair, direction, risk_pct
    """
    try:
        result = await process_nlp_command(
            text=req.text,
            account_balance=req.account_balance,
            validate_trades=req.validate_trades,
        )
        return {"success": True, **result}
    except Exception as e:
        logger.error("NLP command failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="NLP processing failed. Try again.")


@router.post("/deepseek/analyze")
async def deepseek_analyze(req: DeepSeekAnalyzeRequest) -> dict[str, Any]:
    """
    Direct DeepSeek market analysis endpoint.
    Called when user asks for analysis/signals, or after trade confirmation.
    """
    if not deepseek_client.available:
        raise HTTPException(status_code=503, detail="DeepSeek API key not configured.")

    prompt = (
        f"Provide a brief forex market analysis for {req.pair.replace('_', '/')} "
        f"on the {req.timeframe} timeframe. "
        f"{'Context: ' + req.context if req.context else ''}"
        f"Return JSON: {{\"bias\": BUY/SELL/NEUTRAL, \"confidence\": 0-1, "
        f"\"key_levels\": [float], \"summary\": \"one sentence\", "
        f"\"risk_note\": \"one sentence\"}}"
    )

    try:
        result = await deepseek_client.chat_completion_json(
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2,
            max_tokens=300,
            fallback={"bias": "NEUTRAL", "confidence": 0.5,
                      "summary": "Analysis unavailable", "key_levels": [], "risk_note": ""},
        )
        return {"success": True, "pair": req.pair, "timeframe": req.timeframe, **result}
    except Exception as e:
        logger.error("DeepSeek analyze failed: %s", e, exc_info=True)
        raise HTTPException(status_code=500, detail="Market analysis failed.")


@router.get("/health")
async def nlp_health() -> dict[str, Any]:
    """
    Health check for both AI clients.
    Call this on app startup to verify keys are working.
    """
    openai_health  = await claude_client.health_check()
    deepseek_health = await deepseek_client.health_check()

    both_ok = (
        openai_health.get("status") == "ok"
        and deepseek_health.get("status") == "ok"
    )

    return {
        "status": "ok" if both_ok else "degraded",
        "openai": openai_health,
        "deepseek": deepseek_health,
    }
