import os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'), override=True)

from supabase import create_client

url = os.getenv('SUPABASE_URL')
sr_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
anon_key = os.getenv('SUPABASE_ANON_KEY')

print(f'URL: {url}')
print(f'Service Role Key starts: {sr_key[:20]}...')
print(f'Anon Key starts: {anon_key[:20]}...')

# Test with SERVICE ROLE key (should bypass RLS)
print('\n--- Testing with SERVICE_ROLE_KEY ---')
client = create_client(url, sr_key)
try:
    result = client.table('auto_trade_config').upsert(
        {'user_id': 'test-user-001', 'trade_mode': 'semi_auto', 'enabled': True},
        on_conflict='user_id'
    ).execute()
    print(f'SUCCESS: {result.data}')
except Exception as e:
    print(f'FAILED: {e}')

# Verify it was written
print('\n--- Reading back ---')
try:
    result = client.table('auto_trade_config').select('*').eq('user_id', 'test-user-001').execute()
    print(f'Data: {result.data}')
except Exception as e:
    print(f'Read FAILED: {e}')
