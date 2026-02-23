param(
    [string]$RepoRoot = ""
)

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

$rootVercelConfig = Join-Path $RepoRoot "vercel.json"
$frontendVercelConfig = Join-Path $RepoRoot "Frontend/vercel.json"

Write-Host "Checking Vercel config policy in: $RepoRoot"

if (-not (Test-Path $rootVercelConfig)) {
    Write-Error "Missing required root vercel.json at '$rootVercelConfig'."
    exit 1
}

if (Test-Path $frontendVercelConfig) {
    Write-Error "Disallowed duplicate config found: '$frontendVercelConfig'. Keep only root vercel.json."
    exit 1
}

try {
    $raw = Get-Content -Path $rootVercelConfig -Raw -ErrorAction Stop
    $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "Invalid JSON in root vercel.json: $($_.Exception.Message)"
    exit 1
}

if (-not $parsed.outputDirectory) {
    Write-Error "root vercel.json must define 'outputDirectory'."
    exit 1
}

if ([string]$parsed.outputDirectory -ne "Frontend/build/web") {
    Write-Error "root vercel.json outputDirectory must be 'Frontend/build/web'. Current: '$($parsed.outputDirectory)'."
    exit 1
}

if (-not $parsed.rewrites) {
    Write-Error "root vercel.json must define SPA rewrites."
    exit 1
}

Write-Host "Vercel config guard passed."
