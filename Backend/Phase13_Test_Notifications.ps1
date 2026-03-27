# Phase13_Test_Notifications.ps1
$BASE = "https://forex-backend-production-bc44.up.railway.app"
$TOKEN = $env:TEST_JWT_TOKEN
$headers = @{ "Authorization" = "Bearer $TOKEN"; "Content-Type" = "application/json" }

function Test-EP {
    param([string]$Label, [string]$Url, [string]$Method = "GET", [string]$Body = $null)
    try {
        if ($Body) { $r = Invoke-RestMethod -Uri $Url -Method $Method -Headers $headers -Body $Body }
        else { $r = Invoke-RestMethod -Uri $Url -Method $Method -Headers $headers }
        Write-Host "  [PASS] $Label" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $Label => $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Phase 13 Notification Tests ===" -ForegroundColor Cyan
Test-EP -Label "API Health" -Url "$BASE/health"
Test-EP -Label "Signal Generation" -Url "$BASE/api/v1/signals/generate" -Method "POST" -Body '{"pairs":["EUR_USD"]}'
Test-EP -Label "Notifications List" -Url "$BASE/api/v1/notifications"

Write-Host "`n[Check] Twilio env vars:" -ForegroundColor Cyan
@("TWILIO_ACCOUNT_SID","TWILIO_AUTH_TOKEN","TWILIO_WHATSAPP_FROM","TWILIO_SMS_FROM") | ForEach-Object {
    if ([System.Environment]::GetEnvironmentVariable($_)) { Write-Host "  [SET] $_" -ForegroundColor Green }
    else { Write-Host "  [MISSING] $_" -ForegroundColor Red }
}

Write-Host "`n[Check] Brevo env vars:" -ForegroundColor Cyan
@("BREVO_TRADE_TEMPLATE_ID","BREVO_RISK_TEMPLATE_ID","BREVO_SIGNAL_TEMPLATE_ID","BREVO_MARKET_TEMPLATE_ID") | ForEach-Object {
    if ([System.Environment]::GetEnvironmentVariable($_)) { Write-Host "  [SET] $_" -ForegroundColor Green }
    else { Write-Host "  [MISSING] $_" -ForegroundColor Red }
}
Write-Host "`n=== Done ===" -ForegroundColor Cyan
