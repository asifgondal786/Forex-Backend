"""
app/services/context_aggregator.py
Single source of truth for live market context.
Sources: Pepperstone FIX, OHLC/Yahoo, RSI/MACD, News RSS, ForexFactory, Sentiment, Supabase
"""
import os, asyncio, logging, re, httpx, feedparser
from datetime import datetime, timezone
from typing import Optional
from dotenv import load_dotenv
load_dotenv()

logger = logging.getLogger(__name__)
FINNHUB_KEY = os.getenv("FINNHUB_API_KEY", "")

_ctx_cache: dict = {}
_ctx_time: dict  = {}
CTX_TTL = 30

_RSS_SOURCES = [
    {"name": "Bloomberg Markets", "url": "https://feeds.bloomberg.com/markets/news.rss"},
    {"name": "Reuters Business",  "url": "https://feeds.reuters.com/reuters/businessNews"},
    {"name": "ForexLive",         "url": "https://www.forexlive.com/feed/news"},
    {"name": "FXStreet",          "url": "https://www.fxstreet.com/rss/news"},
]

_FOREX_KEYWORDS = {
    "usd","eur","gbp","jpy","aud","cad","nzd","chf","forex","currency","currencies",
    "dollar","euro","pound","yen","fed ","ecb","boe","boj","rba","central bank",
    "interest rate","inflation","gdp","nfp","fomc","monetary policy","trade balance",
    "cpi","ppi","treasury","treasuries","bond yield","rate hike","rate cut",
    "employment","payroll","unemployment","market rally","market falls",
    "tariff","sanctions","oil price","crude","gold price",
}

_NOISE_PATTERNS = {
    "podcast","masters in business","ceo on "," ceo ","interview","what's next",
    "partnership","launches","ipo ","biotech","pharma","neuroscience","medtronic",
    "apple ","google ","microsoft","amazon","tesla","nvidia","semiconductor",
}


def _unwrap_candles(data) -> list:
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        if "values" in data and isinstance(data["values"], list):
            return data["values"]
        if "data" in data and isinstance(data["data"], list):
            return data["data"]
    return []


def _pair_to_slash(pair: str) -> str:
    if "/" in pair:
        return pair
    if len(pair) == 6:
        return pair[:3] + "/" + pair[3:]
    return pair


def _is_relevant(title: str, pair: str) -> bool:
    text = title.lower()
    if any(n in text for n in _NOISE_PATTERNS):
        return False
    parts = pair.replace("/", " ").lower().split()
    if any(p in text for p in parts):
        return True
    return any(kw in text for kw in _FOREX_KEYWORDS)


async def _fetch_rss(source: dict, pair: str) -> list:
    try:
        async with httpx.AsyncClient(timeout=8.0, follow_redirects=True) as client:
            r = await client.get(source["url"],
                                 headers={"User-Agent": "Mozilla/5.0 (compatible; TajirBot/1.0)"})
            if r.status_code != 200:
                return []
        feed = await asyncio.to_thread(feedparser.parse, r.text)
        headlines = []
        for entry in feed.entries[:20]:
            title = entry.get("title", "").strip()
            if title and _is_relevant(title, pair):
                headlines.append(title)
            if len(headlines) >= 5:
                break
        logger.info("RSS %s: %d relevant", source["name"], len(headlines))
        return headlines
    except Exception as e:
        logger.debug("RSS %s failed: %s", source["name"], e)
        return []


async def _get_pepperstone_price(pair: str) -> Optional[str]:
    # 1. Pepperstone FIX
    try:
        from app.services.pepperstone_fix_client import pepperstone
        symbol = pair.replace("/", "")
        if pepperstone and hasattr(pepperstone, "get_price"):
            p = pepperstone.get_price(symbol)
            if p:
                spread = round((float(p.get("ask", 0)) - float(p.get("bid", 0))) * 10000, 1)
                return f"Bid:{p.get('bid','?')} Ask:{p.get('ask','?')} Spread:{spread}pip"
    except Exception as e:
        logger.debug("Pepperstone price failed: %s", e)
    # 2. Pepperstone _last_prices direct access (already subscribed on startup)
    try:
        from app.services.pepperstone_fix_client import pepperstone
        if pepperstone and hasattr(pepperstone, "_last_prices"):
            sym = pair.replace("/", "")
            p   = pepperstone._last_prices.get(sym)
            if p and p.get("bid") and p.get("ask"):
                bid    = float(p["bid"])
                ask    = float(p["ask"])
                spread = round((ask - bid) * 10000, 1)
                return f"Bid:{bid:.5f} Ask:{ask:.5f} Spread:{spread}pip [Pepperstone FIX]"
    except Exception as e:
        logger.debug("Pepperstone direct price failed: %s", e)
    # 3. Yahoo Finance spot (get_rates source=unavailable, skip it)
    try:
        symbol_yahoo = pair.replace("/", "") + "=X"
        async with httpx.AsyncClient(timeout=6.0) as c:
            r = await c.get(
                f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol_yahoo}",
                params={"interval": "1m", "range": "1d"},
                headers={"User-Agent": "Mozilla/5.0"},
            )
            r.raise_for_status()
            body = r.json()
        result = body.get("chart", {}).get("result", [])
        if result:
            meta  = result[0].get("meta", {})
            price = meta.get("regularMarketPrice") or meta.get("previousClose")
            if price:
                return f"Price:{price:.5f} (Yahoo)"
    except Exception as e:
        logger.debug("Yahoo spot price failed: %s", e)
    return None


async def _get_ohlc_trend(pair: str) -> Optional[str]:
    symbol_raw   = pair.replace("/", "")
    symbol_yahoo = symbol_raw + "=X"
    # 1. Yahoo Finance (primary - twelve_cache removed)
    try:
        async with httpx.AsyncClient(timeout=8.0) as c:
            r = await c.get(
                f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol_yahoo}",
                params={"interval": "1h", "range": "2d"},
                headers={"User-Agent": "Mozilla/5.0"},
            )
            r.raise_for_status()
            body = r.json()
        result = body.get("chart", {}).get("result", [])
        if result:
            closes_raw = result[0].get("indicators", {}).get("quote", [{}])[0].get("close", [])
            closes     = [float(x) for x in closes_raw if x is not None][-10:]
            if len(closes) >= 4:
                trend      = "bullish" if closes[-1] > closes[0] else "bearish" if closes[-1] < closes[0] else "sideways"
                change_pct = round((closes[-1] - closes[0]) / closes[0] * 100, 3)
                return f"Trend:{trend} Change:{change_pct}% over 10h Last:{closes[-1]} (Yahoo)"
    except Exception as e:
        logger.debug("OHLC Yahoo failed: %s", e)
    return None


async def _get_technical(pair: str) -> Optional[str]:
    try:
        from app.services.technical_analysis_service import get_technical_indicators
        pair_slash = _pair_to_slash(pair.replace("/", "")) if "/" not in pair else pair
        tech = await get_technical_indicators(pair_slash)
        if not tech or not tech.get("available"):
            return None
        rsi     = tech.get("rsi")
        macd    = (tech.get("macd") or {}).get("bias", "neutral")
        bias    = tech.get("technical_bias", "neutral")
        tags    = ", ".join(tech.get("indicator_tags", []))
        rsi_str = f"{rsi:.1f}" if rsi is not None else "N/A"
        return f"RSI:{rsi_str} MACD:{macd.upper()} Bias:{bias.upper()} Tags:[{tags}]"
    except Exception as e:
        logger.debug("Technical failed: %s", e)
    return None


async def _get_news_headlines(pair: str) -> list:
    if FINNHUB_KEY:
        try:
            async with httpx.AsyncClient(timeout=8.0) as client:
                r = await client.get("https://finnhub.io/api/v1/news",
                                     params={"category": "forex", "token": FINNHUB_KEY})
                r.raise_for_status()
                articles = r.json()[:10]
                headlines = [a.get("headline", "") for a in articles if a.get("headline")]
                relevant  = [h for h in headlines if _is_relevant(h, pair)]
                if len(relevant) >= 3:
                    return relevant[:5]
        except Exception as e:
            logger.debug("Finnhub news failed: %s", e)

    for source in _RSS_SOURCES:
        headlines = await _fetch_rss(source, pair)
        if len(headlines) >= 3:
            return headlines[:5]

    for source in _RSS_SOURCES:
        headlines = await _fetch_rss(source, pair)
        if headlines:
            return headlines[:5]

    return []


async def _get_forex_factory_events(pair: str) -> Optional[str]:
    try:
        from app.services.forex_factory_service import get_upcoming_events, format_for_ai_context
        events    = await get_upcoming_events(hours_ahead=8)
        currencies = set(pair.replace("/", " ").upper().split())
        relevant  = [e for e in events if e.get("Currency","").upper() in currencies or e.get("Impact","") == "High"]
        return format_for_ai_context(relevant or events, max_events=5)
    except Exception as e:
        logger.debug("FF events failed: %s", e)
    return None


async def _get_sentiment(pair: str) -> Optional[str]:
    try:
        from app.services.forex_data_service import get_sentiment
        s = await get_sentiment(pair)
        if s and s.get("source") not in (None, "unavailable"):
            return f"{s.get('sentiment','neutral').upper()} score:{s.get('score',0):.2f} source:{s.get('source','N/A')}"
    except Exception as e:
        logger.debug("Sentiment failed: %s", e)
    return None


async def _get_last_signal(pair: str) -> Optional[str]:
    try:
        from app.database import supabase
        if not supabase:
            return None
        symbol = pair.replace("/", "")
        r = await asyncio.to_thread(
            lambda: supabase.table("trade_signals")
            .select("pair,action,confidence,entry_price,stop_loss,take_profit")
            .eq("pair", symbol).order("created_at", desc=True).limit(1).execute())
        if r.data:
            s = r.data[0]
            return (f"{s.get('pair')} {s.get('action','').upper()} @ {s.get('entry_price','?')} "
                    f"SL:{s.get('stop_loss','?')} TP:{s.get('take_profit','?')} "
                    f"Conf:{float(s.get('confidence',0)):.0%}")
    except Exception as e:
        logger.debug("Last signal failed: %s", e)
    return None


async def gather(pair: str = "EUR/USD") -> dict:
    cache_key = pair.upper()
    now = datetime.now(timezone.utc)
    if cache_key in _ctx_time:
        if (now - _ctx_time[cache_key]).total_seconds() < CTX_TTL:
            return _ctx_cache[cache_key]

    results = await asyncio.gather(
        asyncio.wait_for(_get_pepperstone_price(pair),    timeout=8),
        asyncio.wait_for(_get_ohlc_trend(pair),           timeout=10),
        asyncio.wait_for(_get_technical(pair),            timeout=15),
        asyncio.wait_for(_get_news_headlines(pair),       timeout=12),
        asyncio.wait_for(_get_forex_factory_events(pair), timeout=8),
        asyncio.wait_for(_get_sentiment(pair),            timeout=6),
        asyncio.wait_for(_get_last_signal(pair),          timeout=5),
        return_exceptions=True,
    )

    price, ohlc, technical, news, ff_events, sentiment, last_signal = [
        None if isinstance(r, Exception) else r for r in results
    ]

    ctx = {
        "pair": pair, "price": price, "ohlc": ohlc, "technical": technical,
        "news": news or [], "ff_events": ff_events, "sentiment": sentiment,
        "last_signal": last_signal, "gathered_at": now.isoformat(),
    }
    _ctx_cache[cache_key] = ctx
    _ctx_time[cache_key]  = now
    return ctx


def build_ai_prompt_context(ctx: dict) -> str:
    pair  = ctx.get("pair", "N/A")
    lines = [f"--- LIVE MARKET CONTEXT: {pair} ---"]
    if ctx.get("price"):      lines.append(f"?? LIVE PRICE:     {ctx['price']}")
    if ctx.get("ohlc"):       lines.append(f"?? CHART TREND:    {ctx['ohlc']}")
    if ctx.get("technical"):  lines.append(f"?? TECHNICALS:     {ctx['technical']}")
    if ctx.get("sentiment"):  lines.append(f"??  SENTIMENT:      {ctx['sentiment']}")
    if ctx.get("news"):
        lines.append("?? LATEST NEWS:")
        for h in ctx["news"][:5]:
            lines.append(f"   - {h}")
    if ctx.get("ff_events"):  lines.append(f"?? CALENDAR EVENTS:\n{ctx['ff_events']}")
    if ctx.get("last_signal"): lines.append(f"?? LAST AI SIGNAL: {ctx['last_signal']}")
    if ctx.get("active_trades"):
        lines.append(f"?? ACTIVE TRADES:  {ctx['active_trades']}")
    if ctx.get("pending_signals"):
        lines.append(f"?? PENDING SIGNALS: {ctx['pending_signals']}")
    lines.append("-----------------------------------")
    return "\n".join(lines)


def _extract_pair_from_message(text: str) -> str:
    text_upper = text.upper()
    if any(w in text_upper for w in ["GOLD", "XAU", "XAUUSD"]):
        return "XAU/USD"
    if any(w in text_upper for w in ["SILVER", "XAG", "XAGUSD"]):
        return "XAG/USD"
    if any(w in text_upper for w in ["POUND", "CABLE", "GBP"]):
        return "GBP/USD"
    if any(w in text_upper for w in ["YEN", "JPY", "USDJPY"]):
        return "USD/JPY"
    for p in ["EUR/USD","GBP/USD","USD/JPY","AUD/USD","USD/CAD","NZD/USD","USD/CHF","EUR/GBP","EUR/JPY","GBP/JPY","XAU/USD","XAG/USD"]:
        if p.replace("/","") in text_upper or p in text_upper:
            return p
    m = re.search(r"\b([A-Z]{3})/?([A-Z]{3})\b", text_upper)
    if m:
        return f"{m.group(1)}/{m.group(2)}"
    return "EUR/USD"



