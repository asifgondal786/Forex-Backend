$ErrorActionPreference = "Stop"

Write-Host "Starting Forex Companion backend (dev)..." -ForegroundColor Cyan

$env:DEBUG = "true"
$env:CORS_ALLOW_LOCALHOST = "true"
$env:ALLOW_DEV_USER_ID = "true"
$env:DEV_USER_LOCALHOST_ONLY = "true"

$python = if (Test-Path ".\.venv\Scripts\python.exe") { ".\.venv\Scripts\python.exe" } else { "python" }

Write-Host "Using Python: $python" -ForegroundColor DarkCyan
Write-Host "Dev flags: DEBUG=true, CORS_ALLOW_LOCALHOST=true, ALLOW_DEV_USER_ID=true, DEV_USER_LOCALHOST_ONLY=true" -ForegroundColor DarkCyan

& $python -c "import google.generativeai" *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "Missing backend dependencies detected. Installing requirements..." -ForegroundColor Yellow
  & $python -m pip install -r requirements.txt
}

& $python -m uvicorn app.main:app --host 127.0.0.1 --port 8080 --reload
