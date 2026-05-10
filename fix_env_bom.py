path = 'D:/Tajir/Backend/.env'
data = open(path, 'rb').read()
if data.startswith(b'\xef\xbb\xbf'):
    data = data[3:]
    open(path, 'wb').write(data)
    print('BOM stripped - .env fixed')
else:
    print('No BOM found - already clean')
