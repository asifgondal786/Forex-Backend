import asyncio, os, sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, 'D:/Tajir/Backend')

from dotenv import load_dotenv
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'), override=True)

from app.ai.claude_client import ask_claude, _CLAUDE_MODEL

async def test():
    print(f'Model ID: {_CLAUDE_MODEL}')
    try:
        r = await ask_claude('Reply with only: Hello from Claude', max_tokens=20)
        print(f'SUCCESS: {r["content"]}')
    except Exception as e:
        print(f'FAILED: {e}')

asyncio.run(test())
