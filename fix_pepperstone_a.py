path = 'app/services/pepperstone_fix_client.py'
content = open(path, encoding='utf-8', errors='replace').read()

old = '                self._hb_task = asyncio.create_task(self._heartbeat_loop())'

new = '''                self._hb_task = asyncio.create_task(self._heartbeat_loop())
                if self.label == "PRICE":
                    self._refresh_task = asyncio.create_task(self._price_refresh_loop())'''

if old in content:
    content = content.replace(old, new)
    open(path, 'w', encoding='utf-8').write(content)
    print('STEP A OK - refresh task wired')
else:
    print('NOT FOUND')
    print(repr(content[content.find('_hb_task'):content.find('_hb_task')+120]))
