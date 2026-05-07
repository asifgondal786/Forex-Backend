import os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'), override=True)

from supabase import create_client
url = os.getenv('SUPABASE_URL')
sr_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
client = create_client(url, sr_key)

# Query the check constraint definition from information_schema
try:
    result = client.rpc('get_check_constraints', {}).execute()
    print(f'RPC result: {result.data}')
except:
    pass

# Try raw SQL via RPC or just query the pg_catalog
# Alternative: query with a valid looking value
# Let's try common patterns
test_modes = [
    'Manual', 'Assisted', 'Semi-Auto', 'Full-Auto',
    'MANUAL', 'ASSISTED', 'SEMI_AUTO', 'FULL_AUTO',
    'semi', 'full', 'auto', 'paper', 'live', 'demo',
    'conservative', 'moderate', 'aggressive',
    'autonomous', 'supervised', 'hybrid',
]

print('Testing mode values:')
for mode in test_modes:
    try:
        result = client.table('auto_trade_config').upsert(
            {'user_id': 'constraint-test-2', 'trade_mode': mode},
            on_conflict='user_id'
        ).execute()
        print(f'  {mode:20} -> ALLOWED !!!')
        client.table('auto_trade_config').delete().eq('user_id', 'constraint-test-2').execute()
    except Exception as e:
        if 'check constraint' in str(e).lower():
            pass  # silently skip blocked ones
        else:
            print(f'  {mode:20} -> OTHER ERROR: {str(e)[:60]}')

# Also try to read existing rows to see what values are already in there
print('\nExisting rows in auto_trade_config:')
try:
    result = client.table('auto_trade_config').select('user_id, trade_mode, enabled').limit(10).execute()
    for row in (result.data or []):
        print(f'  user={row.get("user_id","")[:20]} mode={row.get("trade_mode","")} enabled={row.get("enabled","")}')
    if not result.data:
        print('  (empty table)')
except Exception as e:
    print(f'  Error reading: {e}')
