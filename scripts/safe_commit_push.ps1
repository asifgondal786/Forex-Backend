param(
    [Parameter(Mandatory = $true)]
    [string]$Message,
    [string[]]$PathSpec = @("."),
    [string]$Remote = "origin",
    [string]$Branch = "main",
    [switch]$NoPush
)

$ErrorActionPreference = "Stop"

function Invoke-Step {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )

    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw $ErrorMessage
    }
}

$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

Write-Host "Staging path(s): $($PathSpec -join ', ')" -ForegroundColor Cyan
$addArgs = @("add", "--") + $PathSpec
Invoke-Step -Action { & git @addArgs } -ErrorMessage "Failed to stage changes."

$staged = (git diff --cached --name-only).Trim()
if (-not $staged) {
    throw "Nothing is staged. Update files first or adjust -PathSpec."
}

Write-Host "Running staged secret scan..." -ForegroundColor Cyan
Invoke-Step -Action { & python scripts/secret_scan.py } -ErrorMessage "Secret scan failed on staged files."

Write-Host "Creating commit..." -ForegroundColor Cyan
# Hook execution is skipped because this script already performs explicit staged/range scans.
Invoke-Step -Action { & git commit --no-verify -m $Message } -ErrorMessage "git commit failed."

if ($NoPush) {
    Write-Host "Commit created. Push skipped because -NoPush was used." -ForegroundColor Yellow
    exit 0
}

$upstream = $null
& git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" *> $null
if ($LASTEXITCODE -eq 0) {
    $upstream = (git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}").Trim()
}

if ($upstream) {
    $range = "$upstream..HEAD"
} else {
    $range = "HEAD"
}

Write-Host "Running commit-range secret scan: $range" -ForegroundColor Cyan
Invoke-Step -Action { & python scripts/secret_scan.py --range $range } -ErrorMessage "Secret scan failed on commits to push."

Write-Host "Pushing to $Remote $Branch..." -ForegroundColor Cyan
Invoke-Step -Action { & git push --no-verify $Remote "HEAD:$Branch" } -ErrorMessage "git push failed."

Write-Host "Done: commit and push completed safely." -ForegroundColor Green
