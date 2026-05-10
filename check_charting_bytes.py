path = 'app/routers/charting.py'
data = open(path, 'rb').read()
print('Total bytes:', len(data))
print('Content after byte 2000:')
print(repr(data[2000:2200]))
