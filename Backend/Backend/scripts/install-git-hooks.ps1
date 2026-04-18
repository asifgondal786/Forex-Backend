$ErrorActionPreference = "Stop"

Write-Host "Configuring repository git hooks path (.githooks)..." -ForegroundColor Cyan
git config core.hooksPath .githooks

$hookPath = Join-Path $PSScriptRoot "..\\.githooks\\pre-commit"
if (Test-Path $hookPath) {
    Write-Host "pre-commit hook configured at .githooks/pre-commit" -ForegroundColor Green
} else {
    Write-Host "pre-commit hook not found at .githooks/pre-commit" -ForegroundColor Yellow
}
