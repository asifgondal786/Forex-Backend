path = 'app/services/pepperstone_fix_client.py'
content = open(path, encoding='utf-8').read()
before = content.count('buf.strip()')
content = content.replace('buf.strip().endswith(b"\\x01")', 'buf.endswith(b"\\x01")')
after = content.count('buf.strip()')
open(path, 'w', encoding='utf-8').write(content)
print(f'Replacements made: {before - after} | buf.strip() remaining: {after}')
