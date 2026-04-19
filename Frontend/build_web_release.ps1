param(
  [string]$ApiBaseUrl,
  [string]$AppWebUrl,
  [string]$WsBaseUrl,
  [switch]$SkipPubGet,
  [switch]$NoWasmDryRun
)

$ErrorActionPreference = "Stop"

$defaultApiBaseUrl = "http://140.245.33.196"
$defaultAppWebUrl = "https://forexcompanion-e5a28.web.app"
$defaultWsBaseUrl = "ws://140.245.33.196:8000"

function Resolve-Value {
  param(
    [string]$Explicit,
    [string]$EnvironmentValue,
    [string]$Fallback
  )

  if ($Explicit -and $Explicit.Trim().Length -gt 0) {
    return $Explicit.Trim()
  }
  if ($EnvironmentValue -and $EnvironmentValue.Trim().Length -gt 0) {
    return $EnvironmentValue.Trim()
  }
  return $Fallback
}

$resolvedApiBaseUrl = Resolve-Value $ApiBaseUrl $env:API_BASE_URL $defaultApiBaseUrl
$resolvedAppWebUrl = Resolve-Value $AppWebUrl $env:APP_WEB_URL $defaultAppWebUrl
$resolvedWsBaseUrl = Resolve-Value $WsBaseUrl $env:WS_BASE_URL $defaultWsBaseUrl

Write-Host "Release build configuration:" -ForegroundColor Cyan
Write-Host "  API_BASE_URL = $resolvedApiBaseUrl"
Write-Host "  APP_WEB_URL  = $resolvedAppWebUrl"
Write-Host "  WS_BASE_URL  = $resolvedWsBaseUrl"

if (-not $SkipPubGet) {
  flutter pub get
}

$buildArgs = @(
  "build",
  "web",
  "--release",
  "--dart-define=API_BASE_URL=$resolvedApiBaseUrl",
  "--dart-define=APP_WEB_URL=$resolvedAppWebUrl",
  "--dart-define=WS_BASE_URL=$resolvedWsBaseUrl"
)

if ($NoWasmDryRun) {
  $buildArgs += "--no-wasm-dry-run"
}

flutter @buildArgs
