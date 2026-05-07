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
    response = client.list_inference_profiles()
    profiles = response.get('inferenceProfileSummaries', [])
    print(f'Found {len(profiles)} inference profiles:')
    for p in profiles:
        pid = p.get('inferenceProfileId', '')
        name = p.get('inferenceProfileName', '')
        status = p.get('status', '')
        if 'claude' in pid.lower() or 'claude' in name.lower() or 'anthropic' in pid.lower():
            print(f'  ID: {pid}')
            print(f'  Name: {name}')
            print(f'  Status: {status}')
            print(f'  ---')
except Exception as e:
    print(f'Error: {e}')
    print('Trying with paginator...')
    try:
        paginator = client.get_paginator('list_inference_profiles')
        for page in paginator.paginate():
            for p in page.get('inferenceProfileSummaries', []):
                pid = p.get('inferenceProfileId', '')
                if 'claude' in pid.lower() or 'anthropic' in pid.lower():
                    print(f'  {pid} | {p.get("inferenceProfileName","")} | {p.get("status","")}')
    except Exception as e2:
        print(f'Paginator also failed: {e2}')
