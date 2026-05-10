path = 'app/routers/charting.py'
content = open(path, encoding='utf-8', errors='replace').read()

old = '''def generate_mock_candles(pair: str, timeframe: str, count: int = 100) -> list[dict]:
    """Stub -- returns empty list. Real candle data comes from Yahoo Finance."""
    return []'''

new = '''def generate_mock_candles(pair: str, timeframe: str, count: int = 100) -> list[dict]:
    """Stub -- returns empty list. Real candle data comes from Yahoo Finance."""
    return []


async def _get_candles(pair: str, granularity: str, count: int) -> list[dict]:
    """Fetch OHLCV candles from Yahoo Finance via market_data_service."""
    try:
        from app.services.market_data_service import get_ohlc_data
        pair_fmt = pair.replace("-", "/").replace("_", "/")
        interval_map = {"1m": "1m", "5m": "5m", "15m": "15m", "30m": "30m",
                        "1h": "1h", "4h": "4h", "1d": "1d"}
        interval = interval_map.get(granularity.lower(), "1h")
        result = await get_ohlc_data(pair_fmt, interval=interval, outputsize=count)
        return result.get("values", [])
    except Exception as e:
        import logging
        logging.getLogger(__name__).error("_get_candles failed: %s", e)
        return []'''

if 'def generate_mock_candles' in content:
    content = content.replace(old, new)
    open(path, 'w', encoding='utf-8').write(content)
    print('STEP 1 OK - _get_candles added')
else:
    print('NOT FOUND')
