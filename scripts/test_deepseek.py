import asyncio, os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'), override=True)

from openai import AsyncOpenAI

async def test_deepseek():
    key = os.getenv('DEEPSEEK_API_KEY', '')
    url = os.getenv('DEEPSEEK_BASE_URL', 'https://api.deepseek.com/v1')
    print(f'Key: {key[:10]}... (len={len(key)})')
    print(f'URL: {url}')
    
    client = AsyncOpenAI(api_key=key, base_url=url)
    try:
        r = await client.chat.completions.create(
            model='deepseek-chat',
            messages=[{'role': 'user', 'content': 'Reply with only: OK'}],
            max_tokens=10,
        )
        print(f'SUCCESS: {r.choices[0].message.content}')
    except Exception as e:
        print(f'FAILED: {e}')

asyncio.run(test_deepseek())
