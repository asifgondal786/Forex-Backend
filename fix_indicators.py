path = 'app/services/forex_data_service.py'
content = open(path, encoding='utf-8').read()

old = 'async def get_indicators(pair: str, indicator: str = "rsi", interval: str = "1h", period: int = 14) -> dict[str, Any]:\n    data = await fetch_indicator(pair, indicator=indicator, interval=interval, period=period)\n    if not data:\n        return {"error": "Indicator unavailable", "source": "error"}\n\n'

new = 'async def get_indicators(pair: str, indicator: str = "rsi", interval: str = "1h", period: int = 14) -> dict[str, Any]:\n    try:\n        from app.services.technical_analysis_service import get_technical_indicators\n        result = await get_technical_indicators(pair, interval=interval)\n        return {**result, "source": "yahoo_computed"}\n    except Exception as e:\n        import logging; logging.getLogger(__name__).error("get_indicators failed: %s", e)\n        return {"error": str(e), "source": "yahoo_computed"}\n\n'

if old in content:
    content = content.replace(old, new)
    open(path, 'w', encoding='utf-8').write(content)
    print('FIXED')
else:
    print('NOT FOUND - dumping around fetch_indicator:')
    idx = content.find('fetch_indicator')
    print(repr(content[idx-300:idx+150]))
