path = 'app/routers/charting.py'
content = open(path, encoding='utf-8', errors='replace').read()

# Remove old sync _get_candles (OANDA-based)
old = '''def _get_candles(pair: str, granularity: str, count: int) -> list[dict]:
    """
    Smart data source selector:
    - Uses OANDA if OANDA_API_KEY is set (Phase 15)
    - Falls back to mock generator (Phase 16)
    """
    if os.getenv("OANDA_API_KEY"):
        try:
            import asyncio
            from app.services.oanda_service import fetch_candles
            loop = asyncio.new_event_loop()
            candles = loop.run_until_complete(fetch_candles(pair, granularity, count))
            loop.close()
            if candles:
                return candles
        except Exception as e:
            logger.warning("OANDA candles failed, using mock: %s", e)

    return generate_mock_candles(pair, granularity, count)'''

new = '# _get_candles defined above as async Yahoo Finance implementation'

if 'def _get_candles' in content and 'OANDA_API_KEY' in content:
    content = content.replace(old, new)
    open(path, 'w', encoding='utf-8').write(content)
    print('STEP 2 OK - old OANDA _get_candles removed')
else:
    print('NOT FOUND - checking:')
    idx = content.find('def _get_candles')
    print(repr(content[idx:idx+400]))
