"""
Backend/app/services/signal_service.py

Task 9 - Real Trade Signals
Flow: Twelve Data prices + NewsAPI headlines -> Gemini prompt -> TradeSignal JSON -> Supabase
"""

import os
import json
import logging
import httpx
from datetime import datetime, timezone
from pydantic import BaseModel
from app.services.market_data_service import get_market_prices
from app.ai.gemini_client import gemini_client

logger = logging.getLogger(__name__)

NEWS_API_KEY      = os.getenv("NEWS_API_KEY", "")
SUPABASE_URL      = os.getenv("SUPABASE_URL", "")
SUPABASE_KEY      = os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
NEWS_API_BASE     = "https://newsapi.org/v2"
GEMINI_MODEL      = "gemini-2.0-flash"


# -- Models -------------------------------------------------------------------

class TradeSignal(BaseModel):
    pair:           str
    action:         str        # BUY | SELL | HOLD
    confidence:     float      # 0.0 - 1.0
    entry_price:    float
    stop_loss:      float
    take_profit:    float
    reasoning:      str
    sentiment:      str        # bullish | bearish | neutral
    news_summary:   str
    generated_at:   str
    model:          str


class SignalResponse(BaseModel):
    signals:      list[TradeSignal]
    generated_at: str
    pairs:        list[str]


# -- Helpers ------------------------------------------------------------------

async def _fetch_news(query: str = "forex currency trading") -> list[str]:
    """Fetch top 5 forex headlines from NewsAPI."""
    if not NEWS_API_KEY:
        logger.warning("NEWS_API_KEY not set - skipping news fetch")
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
    """Persist signal to Supabase trade_signals table."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        logger.warning("Supabase not configured - skipping signal persistence")
        return
    try:
        async with httpx.AsyncClient(timeout=8.0) as client:
            resp = await client.post(
                f"{SUPABASE_URL}/rest/v1/trade_signals",
                headers={
                    "apikey":        SUPABASE_KEY,
                    "Authorization": f"Bearer {SUPABASE_KEY}",
                    "Content-Type":  "application/json",
                    "Prefer":        "return=minimal",
                },
                json=signal.model_dump(),
            )
        if resp.status_code not in (200, 201):
            logger.error("Supabase insert failed %s: %s", resp.status_code, resp.text)
    except Exception as e:
        logger.error("Supabase save failed: %s", e)


def _build_gemini_prompt(pair: str, price: float, headlines: list[str]) -> str:
    news_block = "\n".join(f"- {h}" for h in headlines) if headlines else "- No news available"
    return f"""You are an expert forex analyst. Analyze the following data and return a trade signal.

Currency Pair: {pair}
Current Price: {price}

Latest Forex News Headlines:
{news_block}

Return ONLY a valid JSON object with exactly these fields:
{{
  "action": "BUY" or "SELL" or "HOLD",
  "confidence": 0.0 to 1.0,
  "stop_loss": <price as float>,
  "take_profit": <price as float>,
  "reasoning": "<one sentence explanation>",
  "sentiment": "bullish" or "bearish" or "neutral",
  "news_summary": "<one sentence news summary>"
}}

Rules:
- stop_loss must be below entry for BUY, above entry for SELL
- take_profit must be above entry for BUY, below entry for SELL
- confidence above 0.7 means strong signal
- Return only JSON, no markdown, no explanation
"""


# -- Main service -------------------------------------------------------------

async def generate_signals(
    pairs: list[str] | None = None,
    redis_client=None,
) -> SignalResponse:
    """
    Generate AI trade signals for given pairs.
    1. Fetch live prices from Twelve Data
    2. Fetch forex news from NewsAPI
    3. For each pair, call Gemini to generate signal
    4. Save each signal to Supabase
    5. Return SignalResponse
    """
    if not pairs:
        pairs = ["EUR_USD", "GBP_USD", "USD_JPY"]

    now_iso = datetime.now(timezone.utc).isoformat()

    # Step 1: Get live prices
    price_response = await get_market_prices(pairs=pairs, redis_client=redis_client)
    price_map = {q.instrument: q.mid for q in price_response.prices}

    if not price_map:
        logger.error("No prices available for signal generation")
        return SignalResponse(signals=[], generated_at=now_iso, pairs=pairs)

    # Step 2: Get news headlines once (shared across all pairs)
    headlines = await _fetch_news("forex USD EUR GBP JPY trading")

    signals: list[TradeSignal] = []

    for pair in pairs:
        price = price_map.get(pair)
        if not price:
            logger.warning("No price for %s - skipping", pair)
            continue

        # Step 3: Generate signal via Gemini
        prompt = _build_gemini_prompt(pair, price, headlines)
        raw = gemini_client.generate_json(
            model_name=GEMINI_MODEL,
            prompt=prompt,
            fallback={
                "action":       "HOLD",
                "confidence":   0.5,
                "stop_loss":    round(price * 0.995, 5),
                "take_profit":  round(price * 1.005, 5),
                "reasoning":    "AI unavailable - default HOLD signal",
                "sentiment":    "neutral",
                "news_summary": "No news data available",
            },
        )

        signal = TradeSignal(
            pair=pair,
            action=raw.get("action", "HOLD").upper(),
            confidence=float(raw.get("confidence", 0.5)),
            entry_price=price,
            stop_loss=float(raw.get("stop_loss", round(price * 0.995, 5))),
            take_profit=float(raw.get("take_profit", round(price * 1.005, 5))),
            reasoning=raw.get("reasoning", ""),
            sentiment=raw.get("sentiment", "neutral"),
            news_summary=raw.get("news_summary", ""),
            generated_at=now_iso,
            model=GEMINI_MODEL,
        )

        # Step 4: Save to Supabase
        await _save_signal_to_supabase(signal)

        signals.append(signal)
        logger.info("Signal generated: %s %s (confidence=%.2f)", signal.action, pair, signal.confidence)

    return SignalResponse(signals=signals, generated_at=now_iso, pairs=pairs)
