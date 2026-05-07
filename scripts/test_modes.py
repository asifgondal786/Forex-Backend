import os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'), override=True)

from supabase import create_client
url = os.getenv('SUPABASE_URL')
sr_key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
client = create_client(url, sr_key)

# Try different mode values to find which ones work
test_modes = ['manual', 'assisted', 'semi_auto', 'fully_auto', 'full_auto', 'semi-auto', 'full-auto', 'off']

for mode in test_modes:
    try:
        result = client.table('auto_trade_config').upsert(
            {'user_id': 'constraint-test', 'trade_mode': mode},
            on_conflict='user_id'
        ).execute()
        print(f'  {mode:15} -> ALLOWED')
        # Clean up
        client.table('auto_trade_config').delete().eq('user_id', 'constraint-test').execute()
    except Exception as e:
        err = str(e)
        if 'check constraint' in err.lower():
            print(f'  {mode:15} -> BLOCKED (check constraint)')
        else:
            print(f'  {mode:15} -> ERROR: {err[:80]}')
