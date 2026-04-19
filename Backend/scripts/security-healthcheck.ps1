$ErrorActionPreference = "Stop"

Write-Host "Security Healthcheck - Forex Backend" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format o)"

Write-Host "`n1) Environment validation" -ForegroundColor Yellow
python -m app.config.validate_env --json

Write-Host "`n2) Secret signature scan (tracked files)" -ForegroundColor Yellow
$secretPattern = 'AIza[0-9A-Za-z_-]{20,}|xkeysib-[A-Za-z0-9-]{20,}|BEGIN PRIVATE KEY'
$matches = git grep -n -E $secretPattern
if ($LASTEXITCODE -eq 0) {
    Write-Host "Potential secrets found in tracked files:" -ForegroundColor Red
    Write-Output $matches
    exit 1
}
Write-Host "No secret signatures found in tracked files." -ForegroundColor Green

Write-Host "`n3) Recent history scan (last 200 commits)" -ForegroundColor Yellow
$history = git log -n 200 -p -G $secretPattern
if ($history -match '^commit ') {
    Write-Host "Potential secret signature found in recent history window." -ForegroundColor Red
    exit 1
}
Write-Host "No secret signatures found in recent history window." -ForegroundColor Green

Write-Host "`n4) Targeted security tests" -ForegroundColor Yellow
pytest -q tests/test_env_validation.py tests/test_config_audit.py tests/test_audit_middleware.py

Write-Host "`nSecurity healthcheck complete." -ForegroundColor Green
