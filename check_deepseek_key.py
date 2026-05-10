from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'))
import os
key = os.getenv('DEEPSEEK_API_KEY', '')
print('Key length:', len(key))
print('Key prefix:', key[:8] if key else 'EMPTY')
