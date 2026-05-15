"""
NLP API routes for Tajir Forex Companion.
Endpoints for trade command parsing and AI analysis.
"""
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field, model_validator, model_validator
from typing import Any, Optional

from app.services.nlp_command_service import process_nlp_command
from app.ai.ai_router import route as ai_route, health as ai_health

router = APIRouter(prefix="/api/v1/nlp", tags=["NLP"])


# â”€â”€ Request Models â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class NlpCommandRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=2000)
    account_balance: float = Field(default=10000.0, ge=0)
    validate_with_ai: bool = True


class DeepSeekAnalyzeRequest(BaseModel):
    """
    Accepts both 'prompt' and 'message' field names.
    Frontend sends {message: "..."}, Pydantic model expects 'prompt'.
    model_validator normalises before validation so either works.
    """
    prompt: str = Field(default="", min_length=0, max_length=5000)
    message: Optional[str] = Field(default=None)        # frontend alias
    task: str = Field(default="market_analysis")
    provider: Optional[str] = None
    max_tokens: int = Field(default=1024, ge=50, le=4096)

    @model_validator(mode="after")
    def normalise_prompt(self) -> "DeepSeekAnalyzeRequest":
        # If frontend sent 'message' but not 'prompt', copy it over
        if not self.prompt and self.message:
            self.prompt = self.message
        if not self.prompt:
            raise ValueError("Either 'prompt' or 'message' must be provided")
        return self


class SentimentRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=10000)
    provider: Optional[str] = None


class MarketAnalysisRequest(BaseModel):
    pair: str = Field(default="EUR/USD")
    context: str = Field(default="")
    provider: Optional[str] = None


# â”€â”€ Endpoints â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    """
    General AI analysis â€” routed to best provider.
    Accepts both {prompt: "..."} and {message: "..."} from frontend.
    """
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
async def nlp_chat(req: dict):
    """
    AI chat endpoint â€” primary conversational interface.
    Accepts {message: "..."} or {prompt: "..."} from frontend.
    Routes through AI router (Claude for conversation, DeepSeek fallback).
    Injects live market context before sending to AI.
    """
    prompt = req.get("message") or req.get("prompt", "")
    if not prompt:
        raise HTTPException(status_code=400, detail="No message provided")

    # â”€â”€ Inject live context â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    context_block = ""
    try:
        from app.services.context_aggregator import gather, build_ai_prompt_context, _extract_pair_from_message
        pair = _extract_pair_from_message(prompt)
        ctx  = await gather(pair)

        # Inject active trades
        try:
            from app.services.trade_service import get_active_trades
            trades = await get_active_trades()
            if trades:
                ctx["active_trades"] = f"{len(trades)} open trades: " + ", ".join(
                    f"{t.get('pair')} {t.get('direction')} lot={t.get('lot_size')}"
                    for t in trades[:3]
                )
        except Exception:
            pass

        # Inject pending signals
        try:
            from app.services.signal_service import get_pending_signals
            sigs = await get_pending_signals()
            if sigs:
                ctx["pending_signals"] = f"{len(sigs)} pending: " + ", ".join(
                    f"{s.get('pair')} {s.get('action')} conf={s.get('confidence')}"
                    for s in sigs[:3]
                )
        except Exception:
            pass

        context_block = build_ai_prompt_context(ctx)
    except Exception as e:
        logger.warning("context injection failed: %s", e)

    system = (
        "You are Tajir, an expert AI forex trading assistant. "
        "You help traders analyze markets, understand signals, manage risk, "
        "and make informed trading decisions. Be concise, professional, "
        "and always include relevant price levels when discussing trades. "
        "Format responses for mobile readability."
    )
    if context_block:
        system += f"\n\n{context_block}"

    try:
        result = await ai_route(
            prompt,
            task="conversation",
            system=system,
            max_tokens=1500,
            temperature=0.5,
        )
        return {
            "status": "ok",
            "response": result.get("content", ""),
            "provider": result.get("provider", "unknown"),
            "model": result.get("model", ""),
            "context_injected": bool(context_block),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


import logging
logger = logging.getLogger(__name__)
