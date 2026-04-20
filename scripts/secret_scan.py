import sys, re, subprocess

PATTERNS = [
    r'sk-[a-zA-Z0-9]{32,}',
    r'AIza[0-9A-Za-z\-_]{35}',
    r'(?i)password\s*=\s*["\'][^"\']+["\']',
    r'(?i)secret\s*=\s*["\'][^"\']+["\']',
    r'(?i)api_key\s*=\s*["\'][^"\']+["\']',
]

result = subprocess.run(
    ['git', 'diff', '--cached', '--name-only'],
    capture_output=True, text=True
)
files = result.stdout.strip().split('\n')

found = False
for filepath in files:
    if not filepath or not filepath.endswith(('.py', '.env', '.yaml', '.yml', '.json')):
        continue
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f, 1):
                for pattern in PATTERNS:
                    if re.search(pattern, line):
                        print(f"[secret-scan] WARNING: Possible secret in {filepath}:{i}")
                        found = True
    except FileNotFoundError:
        pass

if found:
    print("[secret-scan] BLOCKED: Remove secrets before committing.")
    sys.exit(1)

print("[secret-scan] OK: no known secret patterns found.")
sys.exit(0)
