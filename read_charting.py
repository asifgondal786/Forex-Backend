path = 'app/routers/charting.py'
lines = open(path, encoding='utf-8', errors='replace').readlines()
for i, line in enumerate(lines[73:], start=74):
    print(f'{i}: {line}', end='')
