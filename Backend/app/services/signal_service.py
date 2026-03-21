"""
app/services/signal_service.py
Phase 4 - AI Signal Fusion
Flow: Prices + News + RSI/MACD -> Gemini -> Fused confidence score + 3-level explainer
"""
import os
import json
import logging
import httpx
from datetime import datetime, timezone
from pydantic import BaseModel
from typing import Optional, List
from app.services.market_data_service import get_market_prices
from app.services.technical_analysis_service import get_technical_indicators
from app.ai.gemini_client import GeminiClient

logger = logging.getLogger(__name__)

NEWS_API_KEY  = os.getenv("NEWS_API_KEY", "")
SUPABASE_URL  = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY  = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
NEWS_API_BASE = "https://newsapi.org/v2"
GEMINI_MODEL  = "gemini-2.0-flash"


# ── Models ────────────────────────────────────────────────────────────────────

class TradeSignal(BaseModel):
    pair:             str
    action:           str          # BUY | SELL | HOLD
    confidence:       float        # 0.0 - 1.0 (fused score)
    entry_price:      float
    stop_loss:        float
    take_profit:      float
    reasoning:        str
    sentiment:        str          # bullish | bearish | neutral
    news_summary:     str
    generated_at:     str
    model:            str
    # Phase 4 additions
    technical_bias:   Optional[str] = None
    rsi:              Optional[float] = None
    macd_bias:        Optional[str] = None
    indicator_tags:   List[str] = []
    explain_simple:   Optional[str] = None   # beginner
    explain_standard: Optional[str] = None  # intermediate
    explain_advanced: Optional[str] = None  # expert


class SignalResponse(BaseModel):
    signals:      list[TradeSignal]
    generated_at: str
    pairs:        list[str]


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _fetch_news(query: str = "forex currency trading") -> list[str]:
    if not NEWS_API_KEY:
        return []
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.get(
                f"{NEWS_API_BASE}/everything",
                params={
                    "q":        query,
                    "language": "en",
                    "sortBy":   "publishedAt",
                    "pageSize": 5,
                    "apiKey":   NEWS_API_KEY,
                },
            )
        resp.raise_for_status()
        articles = resp.json().get("articles", [])
        return [a.get("title", "") for a in articles if a.get("title")]
    except Exception as e:
        logger.error("NewsAPI fetch failed: %s", e)
        return []


async def _save_signal_to_supabase(signal: TradeSignal) -> None:
    if not SUPABASE_URL or not SUPABASE_KEY:
        return
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            await client.post(
                f"{SUPABASE_URL}/rest/v1/trade_signals",
                headers={
                    "apikey":        SUPABASE_KEY,
                    "Authorization": f"Bearer {SUPABASE_KEY}",
                    "Content-Type":  "application/json",
                    "Prefer":        "return=minimal",
                },
                json=signal.model_dump(),
            )
    except Exception as e:
        logger.error("Supabase save failed: %s", e)


def _fuse_confidence(
    gemini_conf: float,
    technical_bias: str,
    gemini_sentiment: str,
    action: str,
) -> float:
    """
    Phase 4: Fuse Gemini confidence with technical indicator agreement.
    Boosts confidence when RSI/MACD agree with Gemini action.
    Reduces when they conflict.
    """
    score = gemini_conf

    action_bias = "bullish" if action == "BUY" else "bearish" if action == "SELL" else "neutral"

    if technical_bias == action_bias:
        score = min(score + 0.08, 0.95)   # indicators agree → boost
    elif technical_bias != "neutral" and technical_bias != action_bias:
        score = max(score - 0.10, 0.25)   # indicators conflict → reduce

    return round(score, 3)


def _build_gemini_prompt(
    pair: str,
    price: float,
    headlines: list[str],
    technical: dict,
) -> str:
    news_block = "\n".join(f"- {h}" for h in headlines) if headlines else "- No news available"
    tech_block = ""
    if technical.get("available"):
        rsi = technical.get("rsi")
        macd = technical.get("macd") or {}
        tech_block = f"""
Technical Indicators:
- RSI (14): {rsi:.1f} → {technical.get('technical_bias', 'neutral').upper()}
- MACD: {macd.get('bias', 'neutral').upper()} (histogram: {macd.get('histogram', 0):.6f})
"""

    return f"""You are an expert forex analyst. Analyze and return a trade signal with plain-English explanations.

Currency Pair: {pair}
Current Price: {price}
{tech_block}
Latest Forex News Headlines:
{news_block}

Return ONLY a valid JSON object with exactly these fields:
{{
  "action": "BUY" or "SELL" or "HOLD",
  "confidence": 0.0 to 1.0,
  "stop_loss": <price as float>,
  "take_profit": <price as float>,
  "reasoning": "<one sentence technical explanation>",
  "sentiment": "bullish" or "bearish" or "neutral",
  "news_summary": "<one sentence news summary>",
  "explain_simple": "<explain this trade to a complete beginner in 1-2 simple sentences, no jargon>",
  "explain_standard": "<explain this trade to an intermediate trader in 2-3 sentences with some technical context>",
  "explain_advanced": "<explain this trade to an expert with RSI, MACD, S/R levels, and risk context in 3-4 sentences>"
}}

Rules:
- stop_loss must be below entry for BUY, above entry for SELL
- take_profit must be above entry for BUY, below entry for SELL
- confidence above 0.7 means strong signal
- Consider the technical indicators when forming your view
- Return only JSON, no markdown, no explanation
"""


# ── Main service ──────────────────────────────────────────────────────────────

async def generate_signals(
    pairs: list[str] | None = None,
    redis_client=None,
) -> SignalResponse:
    if not pairs:
        pairs = ["EUR_USD", "GBP_USD", "USD_JPY"]

    now_iso = datetime.now(timezone.utc).isoformat()

    # Step 1: Live prices
    price_response = await get_market_prices(pairs=pairs, redis_client=redis_client)
    price_map = {q.instrument: q.mid for q in price_response.prices}

    if not price_map:
        return SignalResponse(signals=[], generated_at=now_iso, pairs=pairs)

    # Step 2: News headlines (shared)
    headlines = await _fetch_news("forex USD EUR GBP JPY trading")

    signals: list[TradeSignal] = []

    for pair in pairs:
        price = price_map.get(pair)
        if not price:
            continue

        # Step 3: Technical indicators (Phase 4)
        technical = await get_technical_indicators(pair)

        # Step 4: Gemini signal with technical context
        prompt = _build_gemini_prompt(pair, price, headlines, technical)
        _client = GeminiClient()
        raw = _client.generate_json(
            model_name=GEMINI_MODEL,
            prompt=prompt,
            fallback={
                "action":           "HOLD",
                "confidence":       0.5,
                "stop_loss":        round(price * 0.995, 5),
                "take_profit":      round(price * 1.005, 5),
                "reasoning":        "AI unavailable - default HOLD signal",
                "sentiment":        "neutral",
                "news_summary":     "No news data available",
                "explain_simple":   "No AI explanation available right now.",
                "explain_standard": "Signal generation requires Gemini API key.",
                "explain_advanced": "Configure GEMINI_API_KEY for full technical analysis.",
            },
        )

        action = raw.get("action", "HOLD").upper()
        gemini_conf = float(raw.get("confidence", 0.5))

        # Step 5: Fuse confidence (Phase 4)
        fused_conf = _fuse_confidence(
            gemini_conf=gemini_conf,
            technical_bias=technical.get("technical_bias", "neutral"),
            gemini_sentiment=raw.get("sentiment", "neutral"),
            action=action,
        )

        macd_data = technical.get("macd") or {}

        signal = TradeSignal(
            pair=pair,
            action=action,
            confidence=fused_conf,
            entry_price=price,
            stop_loss=float(raw.get("stop_loss", round(price * 0.995, 5))),
            take_profit=float(raw.get("take_profit", round(price * 1.005, 5))),
            reasoning=raw.get("reasoning", ""),
            sentiment=raw.get("sentiment", "neutral"),
            news_summary=raw.get("news_summary", ""),
            generated_at=now_iso,
            model=GEMINI_MODEL,
            # Phase 4 fields
            technical_bias=technical.get("technical_bias"),
            rsi=technical.get("rsi"),
            macd_bias=macd_data.get("bias"),
            indicator_tags=technical.get("indicator_tags", []),
            explain_simple=raw.get("explain_simple"),
            explain_standard=raw.get("explain_standard"),
            explain_advanced=raw.get("explain_advanced"),
        )

        await _save_signal_to_supabase(signal)
        signals.append(signal)
        logger.info(
            "Signal [Phase4] %s %s conf=%.2f→%.2f tech=%s",
            action, pair, gemini_conf, fused_conf,
            technical.get("technical_bias", "n/a"),
        )

    return SignalResponse(signals=signals, generated_at=now_iso, pairs=pairs)