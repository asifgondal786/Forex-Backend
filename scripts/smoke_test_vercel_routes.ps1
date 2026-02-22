param(
  [Parameter(Mandatory = $false)]
  [string]$BaseUrl = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  $BaseUrl = $env:APP_WEB_URL
}

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
  throw "BaseUrl is required. Pass -BaseUrl or set APP_WEB_URL."
}

if (-not $BaseUrl.StartsWith("http://") -and -not $BaseUrl.StartsWith("https://")) {
  $BaseUrl = "https://$BaseUrl"
}

$BaseUrl = $BaseUrl.TrimEnd("/")
$targets = @("/verify", "/reset")

foreach ($path in $targets) {
  $url = "$BaseUrl$path"
  Write-Host "Checking $url"
  $response = Invoke-WebRequest -Uri $url -Method GET -UseBasicParsing
  if ($response.StatusCode -ne 200) {
    throw "Route $path returned status $($response.StatusCode)"
  }
  if (-not ($response.Content -match "<html" -or $response.Content -match "<!DOCTYPE html>")) {
    throw "Route $path did not return HTML content."
  }
}

Write-Host "Deep-link smoke test passed for $BaseUrl"
