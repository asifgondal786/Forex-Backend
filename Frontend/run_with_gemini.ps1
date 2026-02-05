param(
  [string]$ApiKey
)

$ErrorActionPreference = "Stop"

$key = if ($ApiKey -and $ApiKey.Trim().Length -gt 0) {
  $ApiKey.Trim()
} else {
  $env:GEMINI_API_KEY
}

if (-not $key -or $key.Trim().Length -eq 0) {
  Write-Host "GEMINI_API_KEY is not set. Provide it or set the env var." -ForegroundColor Red
  Write-Host "Examples:" -ForegroundColor Yellow
  Write-Host "  .\\run_with_gemini.ps1 -ApiKey 'YOUR_KEY'" -ForegroundColor Yellow
  Write-Host "  `$env:GEMINI_API_KEY = 'YOUR_KEY'" -ForegroundColor Yellow
  exit 1
}

Write-Host "Launching Flutter with Gemini API key..." -ForegroundColor Green
flutter run --dart-define=GEMINI_API_KEY=$key
