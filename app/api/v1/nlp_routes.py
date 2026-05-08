"""
NLP API routes for Tajir Forex Companion.
Endpoints for trade command parsing and AI analysis.
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field
from typing import Any, Optional

from app.services.nlp_command_service import process_nlp_command
from app.ai.ai_router import route as ai_route, health as ai_health

router = APIRouter(prefix="/api/v1/nlp", tags=["NLP"])


# ── Request Models ────────────────────────────────────────

class NlpCommandRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)
    account_balance: float = Field(default=10000.0, ge=0)
    validate_with_ai: bool = True


class DeepSeekAnalyzeRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=5000)
    task: str = Field(default="market_analysis")
    provider: Optional[str] = None
    max_tokens: int = Field(default=1024, ge=50, le=4096)


class SentimentRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=10000)
    provider: Optional[str] = None


class MarketAnalysisRequest(BaseModel):
    pair: str = Field(default="EUR/USD")
    context: str = Field(default="")
    provider: Optional[str] = None


# ── Endpoints ─────────────────────────────────────────────

@router.post("/command")
async def nlp_command(req: NlpCommandRequest) -> dict[str, Any]:
    """Parse a natural language trade command."""
    try:
        result = await process_nlp_command(
            text=req.text,
            account_balance=req.account_balance,
            validate_with_ai=req.validate_with_ai,
        )
        return {"success": True, "data": result}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/analyze")
async def deepseek_analyze(req: DeepSeekAnalyzeRequest) -> dict[str, Any]:
    """General AI analysis — routed to best provider."""
    try:
        result = await ai_route(
            req.prompt,
            task=req.task,
            force_provider=req.provider,
            max_tokens=req.max_tokens,
        )
        return {"success": True, "data": result}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/sentiment")
async def analyze_sentiment(req: SentimentRequest) -> dict[str, Any]:
    """Analyze sentiment of forex news or text."""
    system = (
        "You are a forex sentiment analysis engine. "
        "Respond ONLY with JSON: "
        '{"sentiment":"bullish|bearish|neutral|mixed",'
        '"confidence":0.0-1.0,'
        '"impact":"high|medium|low",'
        '"affected_pairs":["EUR/USD"],'
        '"explanation":"brief"}'
    )
    try:
        result = await ai_route(
            f'Analyze forex sentiment:\n\n"{req.text}"',
            task="sentiment",
            system=system,
            temperature=0.1,
            force_provider=req.provider,
        )
        return {"success": True, "data": result}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/market-analysis")
async def market_analysis(req: MarketAnalysisRequest) -> dict[str, Any]:
    """AI-powered market analysis for a currency pair."""
    system = (
        "You are Tajir, an expert forex market analyst. "
        "Provide concise, actionable analysis. "
        "Include: trend direction, key levels, risk factors, and a confidence score."
    )
    prompt = f"Analyze {req.pair} for trading."
    if req.context:
        prompt += f"\n\nAdditional context: {req.context}"

    try:
        result = await ai_route(
            prompt,
            task="market_analysis",
            system=system,
            max_tokens=1500,
            force_provider=req.provider,
        )
        return {"success": True, "data": result}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/health")
async def nlp_health() -> dict[str, Any]:
    """Health check for all AI providers."""
    providers = await ai_health()
    all_ok = all(providers.values())
    return {
        "status": "healthy" if all_ok else "degraded",
        "providers": providers,
    }

@router.post("/chat")
async def nlp_chat(req: dict, request: Request):
    """NLP chat - routes to DeepSeek AI."""
    prompt = req.get("message") or req.get("prompt", "")
    if not prompt:
        return {"status": "error", "message": "No message provided"}
    try:
        from app.ai.deepseek_client import DeepSeekClient
        ds = DeepSeekClient()
        resp = await ds.chat(prompt)
        return {"status": "ok", "response": resp}
    except Exception as e:
        return {"status": "error", "message": str(e)}