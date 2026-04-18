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

# Always anchor this workflow to the repository containing this script.
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Invoke-Step -Action { & git -C $repoRoot rev-parse --show-toplevel *> $null } -ErrorMessage "Git repository not found at script root."
Set-Location $repoRoot

# Support both array syntax and comma-separated syntax from command line.
$expandedPathSpec = @()
foreach ($entry in $PathSpec) {
    if ($null -eq $entry) { continue }
    $expandedPathSpec += ($entry -split ",")
}
$expandedPathSpec = $expandedPathSpec | ForEach-Object { $_.Trim() } | Where-Object { $_ }

if (-not $expandedPathSpec) {
    throw "No valid -PathSpec entries were provided."
}

Write-Host "Repository root: $repoRoot" -ForegroundColor Cyan
Write-Host "Staging path(s): $($expandedPathSpec -join ', ')" -ForegroundColor Cyan
$addArgs = @("add", "--") + $expandedPathSpec
Invoke-Step -Action { & git @addArgs } -ErrorMessage "Failed to stage changes."

$stagedOutput = & git diff --cached --name-only
$staged = if ($stagedOutput) { $stagedOutput.Trim() } else { "" }
if ([string]::IsNullOrWhiteSpace($staged)) {
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
