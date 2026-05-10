path = 'app/services/pepperstone_fix_client.py'
content = open(path, encoding='utf-8', errors='replace').read()

old = '    async def _heartbeat_loop(self) -> None:'

new = '''    async def _price_refresh_loop(self) -> None:
        import asyncio as _asyncio
        await _asyncio.sleep(5)
        while self._logged_on:
            try:
                await self.subscribe_market_data(['EURUSD', 'GBPUSD', 'USDJPY', 'XAUUSD'])
            except Exception as e:
                import logging; logging.getLogger(__name__).warning('Price refresh error: %s', e)
            await _asyncio.sleep(30)

    async def _heartbeat_loop(self) -> None:'''

if '    async def _heartbeat_loop(self) -> None:' in content:
    content = content.replace(old, new)
    open(path, 'w', encoding='utf-8').write(content)
    print('STEP B OK - _price_refresh_loop inserted')
else:
    print('NOT FOUND')
