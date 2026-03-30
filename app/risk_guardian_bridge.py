"""
Tajir Phase 18 — Risk Guardian Bridge
Patch for risk_middleware.py → get_market_snapshot()

Replace the stub body of get_market_snapshot() in risk_middleware.py
with the function below. This connects Phase 17 and Phase 18.

BEFORE (Phase 17 stub):
────────────────────────────────────────────────────────────────────
async def get_market_snapshot(symbol: str) -> MarketSnapshot:
    return MarketSnapshot(
        symbol=symbol,
        current_spread_pips=1.5,
        atr_14=8.0,
        is_news_window=False,      # ← was always False
        session="london",
        volatility_index=35.0,
    )

AFTER (Phase 18 live):
────────────────────────────────────────────────────────────────────
Copy the function below into risk_middleware.py, replacing the stub.
"""

from macro_shield import is_news_window as macro_is_news_window

# ── Replace get_market_snapshot in risk_middleware.py with this ───────────────

async def get_market_snapshot(symbol: str) -> "MarketSnapshot":
    """
    Live market snapshot for Risk Guardian.
    Now includes real is_news_window from Macro Event Shield.

    TODO — replace remaining stubs with your broker API:
        current_spread_pips:  from broker tick data
        atr_14:               from broker OHLC (14-period ATR)
        session:              derive from current UTC hour
        volatility_index:     from broker volatility feed or computed from ATR/price
    """
    from risk_models import MarketSnapshot

    news_blocked = await macro_is_news_window(symbol)
    session      = _derive_session()

    return MarketSnapshot(
        symbol=symbol,
        current_spread_pips=1.5,      # TODO: replace with live broker spread
        atr_14=8.0,                   # TODO: replace with live ATR
        is_news_window=news_blocked,  # ✅ now live from Macro Event Shield
        session=session,
        volatility_index=35.0,        # TODO: replace with live volatility
    )


def _derive_session() -> str:
    """
    Derive the current forex session from UTC hour.
    Approximate boundaries (overlaps are labelled as the dominant session).
    """
    from datetime import datetime, timezone
    hour = datetime.now(tz=timezone.utc).hour

    if 22 <= hour or hour < 1:
        return "sydney"
    elif 1 <= hour < 7:
        return "tokyo"
    elif 7 <= hour < 9:
        return "overlap"    # Tokyo/London overlap
    elif 9 <= hour < 12:
        return "london"
    elif 12 <= hour < 14:
        return "overlap"    # London/New York overlap
    elif 14 <= hour < 21:
        return "new_york"
    else:
        return "dead"