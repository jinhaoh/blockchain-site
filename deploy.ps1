#requires -Version 5.1
<#
.SYNOPSIS
  GitHub Pages auto-deploy script.

.DESCRIPTION
  Commits and pushes changes in the blockchain-site repository
  so that GitHub Pages automatically rebuilds the site.

.PARAMETER Message
  Commit message. If omitted, current timestamp is used.

.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 "Update x402 section"
#>

param(
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8

# Move to the script's directory
$repoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoDir

Write-Host ""
Write-Host "===== GitHub Pages Deploy =====" -ForegroundColor Cyan
Write-Host "Repository: $repoDir" -ForegroundColor Gray
Write-Host ""

# Check git availability
try { git --version | Out-Null } catch {
    Write-Host "[ERROR] git is not installed or not in PATH." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Check for changes
$status = git status --porcelain
if (-not $status) {
    Write-Host "[INFO] No changes detected. Skipping deploy." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

Write-Host "Changed files:" -ForegroundColor Green
git status --short
Write-Host ""

# Determine commit message
if (-not $Message) {
    $Message = "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}
Write-Host "Commit message: $Message" -ForegroundColor Green
Write-Host ""

$confirm = Read-Host "Proceed with deploy? (Y/n)"
if ($confirm -match '^[nN]') {
    Write-Host "Cancelled." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 0
}

# Workaround for corporate security software (e.g., BOK environment):
# disable git features that create rapid file access patterns
git config --local core.fscache false 2>$null
git config --local core.preloadindex false 2>$null
git config --local gc.auto 0 2>$null

Write-Host ""
Write-Host "[1/3] git add ..." -ForegroundColor Cyan
git add -A
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] git add" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# git commit: retry up to 3 times in case security SW transiently locks .git/objects
Write-Host "[2/3] git commit ..." -ForegroundColor Cyan
$commitOk = $false
for ($i = 1; $i -le 3; $i++) {
    git commit -m $Message
    if ($LASTEXITCODE -eq 0) { $commitOk = $true; break }
    if ($i -lt 3) {
        Write-Host "  -> Transient failure (likely security SW). Retrying in $($i*2)s ($i/3)..." -ForegroundColor Yellow
        Start-Sleep -Seconds ($i * 2)
    }
}
if (-not $commitOk) {
    Write-Host "[FAIL] git commit (after 3 retries)" -ForegroundColor Red
    Write-Host "  -> Try committing via GitHub Desktop, or request IT to whitelist this .git folder." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "[3/3] git push ..." -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "[FAIL] git push" -ForegroundColor Red
    Write-Host "If this is an auth error, sign in once via GitHub Desktop and retry." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Resolve site URL
$remoteUrl = git config --get remote.origin.url
$siteUrl = ""
if ($remoteUrl -match "github.com[:/]([^/]+)/([^/.]+)") {
    $user = $matches[1]
    $repo = $matches[2]
    $siteUrl = "https://$user.github.io/$repo/"
}

Write-Host ""
Write-Host "===== Deploy Complete =====" -ForegroundColor Green
if ($siteUrl) {
    Write-Host "Site URL: $siteUrl" -ForegroundColor Cyan
    Write-Host "(GitHub Pages build usually takes 30s - 2min)" -ForegroundColor Gray
    Write-Host ""
    $open = Read-Host "Open in browser? (Y/n)"
    if ($open -notmatch '^[nN]') {
        Start-Process $siteUrl
    }
}
Write-Host ""
Read-Host "Press Enter to exit"
