path = 'app/services/forex_data_service.py'
content = open(path, encoding='utf-8').read()
marker = 'async def get_indicators('
idx = content.find(marker)
if idx == -1:
    print('MARKER NOT FOUND')
else:
    end = content.find('\nasync def ', idx + 1)
    old_block = content[idx:end]
    print('OLD BLOCK:')
    print(repr(old_block[:300]))
