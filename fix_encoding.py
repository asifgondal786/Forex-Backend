files = [
    'app/services/context_aggregator.py',
    'app/services/forex_data_service.py',
]
for path in files:
    content = open(path, encoding='utf-8', errors='replace').read()
    content = content.replace('\ufffd', '-')
    content = content.replace('\x97', '-').replace('\x96', '-')
    content = content.replace('\x93', '"').replace('\x94', '"')
    open(path, 'w', encoding='utf-8').write(content)
    print('Encoding fixed:', path)
