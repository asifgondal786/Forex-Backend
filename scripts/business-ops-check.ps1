$ErrorActionPreference = "Stop"

Write-Host "Business Ops Check - Forex Backend" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date -Format o)"

$requiredFiles = @(
    "docs/PHASE_9_STRATEGIC_GROWTH.md",
    "docs/PHASE_10_REVENUE_SCALING.md",
    "docs/BUSINESS_IMPACT.md",
    "docs/REVENUE_MODEL.md",
    "docs/WEEKLY_BUSINESS_REVIEW_TEMPLATE.md",
    "docs/BUSINESS_SCORECARD_TEMPLATE.md",
    "docs/MONTHLY_BUSINESS_METRICS.csv"
)

Write-Host "`n1) Required artifact check" -ForegroundColor Yellow
$missing = @()
foreach ($path in $requiredFiles) {
    if (-not (Test-Path $path)) {
        $missing += $path
    }
}

if ($missing.Count -gt 0) {
    Write-Host "Missing required business files:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}
Write-Host "All required business artifacts are present." -ForegroundColor Green

Write-Host "`n2) Monthly metrics freshness check" -ForegroundColor Yellow
$period = Get-Date -Format "yyyy-MM"
$metricsFile = "docs/MONTHLY_BUSINESS_METRICS.csv"
$hasCurrentPeriod = Select-String -Path $metricsFile -Pattern "^$period," -Quiet

if (-not $hasCurrentPeriod) {
    Write-Warning "No metrics row found for $period in $metricsFile. Add current-month metrics."
} else {
    Write-Host "Found metrics row for current period: $period" -ForegroundColor Green
}

Write-Host "`nBusiness ops check complete." -ForegroundColor Green
