import boto3, os
from pathlib import Path
from dotenv import load_dotenv
load_dotenv(dotenv_path=Path('D:/Tajir/Backend/.env'), override=True)

client = boto3.client(
    'bedrock',
    aws_access_key_id=os.getenv('AWS_ACCESS_KEY_ID'),
    aws_secret_access_key=os.getenv('AWS_SECRET_ACCESS_KEY'),
    region_name=os.getenv('AWS_REGION', 'us-east-1'),
)

try:
    response = client.list_foundation_models(byProvider='Anthropic')
    models = response.get('modelSummaries', [])
    print(f'Found {len(models)} Anthropic models in {os.getenv("AWS_REGION")}:')
    for m in models:
        mid = m.get('modelId', '')
        name = m.get('modelName', '')
        status = m.get('modelLifecycle', {}).get('status', '')
        print(f'  {mid} | {name} | {status}')
except Exception as e:
    print(f'Error: {e}')
