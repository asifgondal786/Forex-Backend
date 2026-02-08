$ErrorActionPreference = "Stop"

Write-Host "Starting Forex Companion backend (dev)..." -ForegroundColor Cyan

$env:DEBUG = "true"
$env:CORS_ALLOW_LOCALHOST = "true"

uvicorn app.main:app --host 127.0.0.1 --port 8080 --reload
