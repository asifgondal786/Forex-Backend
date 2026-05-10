path = 'app/services/pepperstone_fix_client.py'
content = open(path, encoding='utf-8').read()

old = 'if b"10=" in buf and buf.strip().endswith(b"\\x01"):'
new = 'if b"10=" in buf and buf.endswith(b"\\x01"):'

if old in content:
    content = content.replace(old, new)
    open(path, 'w', encoding='utf-8').write(content)
    print('FIXED - buf.strip() removed')
else:
    print('NOT FOUND - checking:')
    idx = content.find('buf.strip()')
    print(repr(content[idx-50:idx+80]) if idx != -1 else 'buf.strip not found either')
