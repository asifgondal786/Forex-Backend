"""
app/services/signal_service.py
Phase 4 - AI Signal Fusion
Flow: gather() context -> DeepSeek -> Fused confidence score + 3-level explainer
"""
import os
import logging
from datetime import datetime, timezone
from pydantic import BaseModel
from typing import Optional, List
from app.services.technical_analysis_service import get_technical_indicators
from app.ai.deepseek_client import DeepSeekClient

logger   = logging.getLogger(__name__)
AI_MODEL = "deepseek-v4-flash"


class TradeSignal(BaseModel):
    pair:             str
    action:           str
    confidence:       float
    entry_price:      float
    stop_loss:        float
    take_profit:      float
    reasoning:        str
    sentiment:        str
    news_summary:     str
    generated_at:     str
    model:            str
    technical_bias:   Optional[str] = None
    rsi:              Optional[float] = None
    macd_bias:        Optional[str] = None
    indicator_tags:      List[str] = []
    av_rsi:               Optional[float] = None
    av_ema20:             Optional[float] = None
    av_ema50:             Optional[float] = None
    av_available:         Optional[bool] = None
    consensus_score:      Optional[float] = None
    consensus_reason:     Optional[str] = None
    consensus_downgraded: Optional[bool] = None
    explain_simple:   Optional[str] = None
    explain_standard: Optional[str] = None
    explain_advanced: Optional[str] = None


class SignalResponse(BaseModel):
    signals:      list[TradeSignal]
    generated_at: str
    pairs:        list[str]


async def _save_signal_to_supabase(signal: TradeSignal, safe_mode: bool = False) -> None:
    try:
        from app.database import supabase
        if not supabase:
            return
        data = signal.model_dump()
        if safe_mode:
            # Only insert columns guaranteed to exist in trade_signals table
            core_fields = {
                "pair", "action", "confidence", "entry_price",
                "stop_loss", "take_profit", "reasoning", "sentiment",
                "news_summary", "generated_at", "model",
            }
            data = {k: v for k, v in data.items() if k in core_fields}
        supabase.table("trade_signals").insert(data).execute()
        logger.info("Signal saved to Supabase: %s %s", signal.pair, signal.action)
    except Exception as e:
        logger.error("Supabase save failed: %s", e)


def _fuse_confidence(ai_conf: float, technical_bias: str, ai_sentiment: str, action: str) -> float:
    score       = ai_conf
    action_bias = "bullish" if action == "BUY" else "bearish" if action == "SELL" else "neutral"
    if technical_bias == action_bias:
        score = min(score + 0.08, 0.95)
    elif technical_bias != "neutral" and technical_bias != action_bias:
        score = max(score - 0.10, 0.25)
    return round(score, 3)


def _build_signal_prompt(pair: str, ctx_block: str, price: float, technical: dict) -> str:
    tech_block = ""
    if technical.get("available"):
        rsi  = technical.get("rsi")
        macd = technical.get("macd") or {}
        tech_block = (
            f"\nTechnical Indicators:\n"
            f"- RSI(14): {rsi:.1f} -> {technical.get('technical_bias','neutral').upper()}\n"
            f"- MACD: {macd.get('bias','neutral').upper()} (histogram: {macd.get('histogram',0):.6f})\n"
        )

    return f"""You are an expert forex analyst with access to live market data.

{ctx_block}

Currency Pair: {pair}
Current Price: {price}
{tech_block}
Return ONLY a valid JSON object with exactly these fields:
{{
  "action": "BUY" or "SELL" or "HOLD",
  "confidence": 0.0 to 1.0,
  "stop_loss": <price as float>,
  "take_profit": <price as float>,
  "reasoning": "<one sentence technical explanation>",
  "sentiment": "bullish" or "bearish" or "neutral",
  "news_summary": "<one sentence news summary>",
  "explain_simple": "<explain to a complete beginner in 1-2 simple sentences>",
  "explain_standard": "<explain to an intermediate trader in 2-3 sentences>",
  "explain_advanced": "<explain to an expert with RSI, MACD, S/R levels in 3-4 sentences>"
}}

Rules:
- stop_loss must be below entry for BUY, above entry for SELL
- take_profit must be above entry for BUY, below entry for SELL
- confidence above 0.7 means strong signal
- Return only JSON, no markdown, no explanation
"""


async def generate_signals(
    pairs: list[str] | None = None,
    redis_client=None,
) -> SignalResponse:
    if not pairs:
        pairs = ["EUR_USD", "GBP_USD", "USD_JPY"]

    now_iso    = datetime.now(timezone.utc).isoformat()
    signals: list[TradeSignal] = []
    _ai_client = DeepSeekClient()

    for pair in pairs:
        pair_slash = pair.replace("_", "/")

        # -- Full live context via gather() ----------------------------------
        try:
            from app.services.context_aggregator import gather, build_ai_prompt_context
            ctx      = await gather(pair_slash)
            ctx_block = build_ai_prompt_context(ctx)
            price    = None
            # Extract price from context (Yahoo or Pepperstone)
            if ctx.get("price"):
                import re
                m = re.search(r"[\d.]{5,}", ctx["price"])
                price = float(m.group()) if m else None
        except Exception as e:
            logger.warning("gather() failed for %s: %s", pair_slash, e)
            ctx_block = ""
            price     = None

        # -- Fallback price from market_data_service -------------------------
        if not price:
            try:
                from app.services.market_data_service import get_market_prices
                pr = await get_market_prices(pairs=[pair], redis_client=redis_client)
                price = pr.prices[0].mid if pr.prices else None
            except Exception:
                pass

        if not price:
            logger.warning("No price for %s — skipping signal", pair)
            continue

        technical = await get_technical_indicators(pair_slash)
        prompt    = _build_signal_prompt(pair_slash, ctx_block, price, technical)

        _FALLBACK = {
            "action": "HOLD", "confidence": 0.5,
            "stop_loss": round(price * 0.995, 5),
            "take_profit": round(price * 1.005, 5),
            "reasoning": "AI unavailable � default HOLD signal",
            "sentiment": "neutral",
            "news_summary": "No news data available",
            "explain_simple":   "No AI explanation available right now.",
            "explain_standard": "Signal generation requires DeepSeek API key.",
            "explain_advanced": "Configure DEEPSEEK_API_KEY for full technical analysis.",
        }
        try:
            raw = await _ai_client.generate_json(
                prompt=prompt,
                model_name=AI_MODEL,
                system_prompt=(
                    "You are an expert forex analyst. "
                    "Return ONLY valid JSON, no markdown, no explanation."
                ),
            )
            if not isinstance(raw, dict) or "action" not in raw:
                raw = _FALLBACK
        except Exception as _ge:
            logger.warning("DeepSeek generate_json failed: %s", _ge)
            raw = _FALLBACK

        action     = raw.get("action", "HOLD").upper()
        ai_conf    = float(raw.get("confidence", 0.5))
        fused_conf = _fuse_confidence(
            ai_conf=ai_conf,
            technical_bias=technical.get("technical_bias", "neutral"),
            ai_sentiment=raw.get("sentiment", "neutral"),
            action=action,
        )
        # -- Phase 2B: Consensus engine ----------------------------------
        try:
            from app.services.signal_engine import consensus_check
            consensus = await consensus_check(
                pair=pair_slash,
                action=action,
                base_confidence=fused_conf,
                internal_ta=technical,
            )
            final_confidence = consensus["consensus_score"]
            final_action     = consensus["action"]
        except Exception as _ce:
            logger.warning("Consensus check failed � using fused_conf: %s", _ce)
            consensus        = {}
            final_confidence = fused_conf
            final_action     = action

        macd_data = technical.get("macd") or {}

        signal = TradeSignal(
            pair=pair,
            action=final_action,
            confidence=final_confidence,
            entry_price=price,
            stop_loss=float(raw.get("stop_loss", round(price * 0.995, 5))),
            take_profit=float(raw.get("take_profit", round(price * 1.005, 5))),
            reasoning=raw.get("reasoning", ""),
            sentiment=raw.get("sentiment", "neutral"),
            news_summary=raw.get("news_summary", ""),
            generated_at=now_iso,
            model=AI_MODEL,
            technical_bias=technical.get("technical_bias"),
            rsi=technical.get("rsi"),
            macd_bias=macd_data.get("bias"),
            indicator_tags=technical.get("indicator_tags", []),
            explain_simple=raw.get("explain_simple"),
            explain_standard=raw.get("explain_standard"),
            explain_advanced=raw.get("explain_advanced"),
            av_rsi=consensus.get("av_rsi"),
            av_ema20=consensus.get("av_ema20"),
            av_ema50=consensus.get("av_ema50"),
            av_available=consensus.get("av_available", False),
            consensus_score=consensus.get("consensus_score"),
            consensus_reason=consensus.get("reason"),
            consensus_downgraded=consensus.get("downgraded", False),
        )

        await _save_signal_to_supabase(signal)
        signals.append(signal)

        try:
            import asyncio as _asyncio
            from app.services.notification_service import notify_new_signal
            _asyncio.create_task(notify_new_signal(
                user_id="broadcast", signal_data=signal.model_dump()))
        except Exception as _ne:
            logger.warning("Signal notification failed: %s", _ne)

        logger.info("Signal %s %s conf=%.2f->%.2f tech=%s",
                    action, pair, ai_conf, fused_conf,
                    technical.get("technical_bias", "n/a"))

    return SignalResponse(signals=signals, generated_at=now_iso, pairs=pairs)








