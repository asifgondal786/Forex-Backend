path = 'app/services/pepperstone_fix_client.py'
content = open(path, encoding='utf-8', errors='replace').read()

old = '        self._hb_task = None'
new = '        self._hb_task = None\n        self._refresh_task = None'

if old in content:
    content = content.replace(old, new)
    open(path, 'w', encoding='utf-8').write(content)
    print('STEP C OK - _refresh_task attribute added to __init__')
else:
    print('NOT FOUND')
