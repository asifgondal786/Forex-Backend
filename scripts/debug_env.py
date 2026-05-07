import os, sys
from pathlib import Path
from dotenv import load_dotenv

# Load exactly like the app does
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'), override=True)

# Check DeepSeek key
ds_key = os.getenv('DEEPSEEK_API_KEY', '')
print(f'DEEPSEEK_API_KEY length: {len(ds_key)}')
print(f'DEEPSEEK_API_KEY starts with: {ds_key[:10]}...' if len(ds_key) > 10 else f'KEY: {ds_key}')
print(f'DEEPSEEK_BASE_URL: {os.getenv("DEEPSEEK_BASE_URL", "NOT SET")}')

# Check Supabase key
sr_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY', '')
anon_key = os.getenv('SUPABASE_ANON_KEY', '')
print(f'\nSUPABASE_SERVICE_ROLE_KEY length: {len(sr_key)}')
print(f'SUPABASE_ANON_KEY length: {len(anon_key)}')
print(f'Service role starts with: {sr_key[:15]}...' if len(sr_key) > 15 else 'EMPTY!')

# Check if duplicate keys exist in .env
print('\n--- Checking for duplicate DEEPSEEK_API_KEY entries ---')
env_path = Path('D:/Tajir/Backend/.env')
lines = env_path.read_text().splitlines()
ds_lines = [l for l in lines if l.startswith('DEEPSEEK_API_KEY')]
print(f'Found {len(ds_lines)} DEEPSEEK_API_KEY entries:')
for l in ds_lines:
    val = l.split('=', 1)[1] if '=' in l else ''
    print(f'  {l[:25]}... (length: {len(val)})')

aws_lines = [l for l in lines if l.startswith('AWS_ACCESS_KEY_ID') or l.startswith('AWS_SECRET_ACCESS_KEY') or l.startswith('AWS_REGION')]
print(f'\nFound {len(aws_lines)} AWS entries:')
for l in aws_lines:
    key = l.split('=', 1)[0]
    val = l.split('=', 1)[1] if '=' in l else ''
    print(f'  {key} = {val[:8]}... (length: {len(val)})')
