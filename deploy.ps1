#requires -Version 5.1
<#
.SYNOPSIS
  GitHub Pages 자동 배포 스크립트

.DESCRIPTION
  blockchain-site 저장소의 변경사항을 GitHub에 커밋·푸시하여
  GitHub Pages를 자동 재배포합니다.

.PARAMETER Message
  커밋 메시지. 생략하면 현재 시각으로 자동 생성.

.EXAMPLE
  .\deploy.ps1
  .\deploy.ps1 "x402 섹션 보강"
#>

param(
    [string]$Message = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = [System.Text.Encoding]::UTF8

# 스크립트가 있는 디렉토리로 이동
$repoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoDir

Write-Host ""
Write-Host "===== GitHub Pages 배포 =====" -ForegroundColor Cyan
Write-Host "저장소: $repoDir" -ForegroundColor Gray
Write-Host ""

# Git 사용 가능 여부
try { git --version | Out-Null } catch {
    Write-Host "[오류] git이 설치되어 있지 않습니다." -ForegroundColor Red
    Read-Host "Enter 키로 종료"
    exit 1
}

# 변경사항 확인
$status = git status --porcelain
if (-not $status) {
    Write-Host "[정보] 변경사항이 없습니다. 배포 생략." -ForegroundColor Yellow
    Read-Host "Enter 키로 종료"
    exit 0
}

Write-Host "변경된 파일:" -ForegroundColor Green
git status --short
Write-Host ""

# 커밋 메시지 결정
if (-not $Message) {
    $Message = "Update: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
}
Write-Host "커밋 메시지: $Message" -ForegroundColor Green
Write-Host ""

$confirm = Read-Host "배포하시겠습니까? (Y/n)"
if ($confirm -match '^[nN]') {
    Write-Host "취소되었습니다." -ForegroundColor Yellow
    Read-Host "Enter 키로 종료"
    exit 0
}

Write-Host ""
Write-Host "[1/3] git add ..." -ForegroundColor Cyan
git add -A
if ($LASTEXITCODE -ne 0) { Write-Host "[실패] git add" -ForegroundColor Red; Read-Host; exit 1 }

Write-Host "[2/3] git commit ..." -ForegroundColor Cyan
git commit -m $Message
if ($LASTEXITCODE -ne 0) { Write-Host "[실패] git commit" -ForegroundColor Red; Read-Host; exit 1 }

Write-Host "[3/3] git push ..." -ForegroundColor Cyan
git push
if ($LASTEXITCODE -ne 0) {
    Write-Host "[실패] git push" -ForegroundColor Red
    Write-Host "인증 오류라면 GitHub Desktop에서 한 번 로그인 후 다시 시도하세요." -ForegroundColor Yellow
    Read-Host "Enter 키로 종료"
    exit 1
}

# 사이트 URL 계산
$remoteUrl = git config --get remote.origin.url
$siteUrl = ""
if ($remoteUrl -match "github.com[:/]([^/]+)/([^/.]+)") {
    $user = $matches[1]
    $repo = $matches[2]
    $siteUrl = "https://$user.github.io/$repo/"
}

Write-Host ""
Write-Host "===== 배포 완료 =====" -ForegroundColor Green
if ($siteUrl) {
    Write-Host "사이트 URL: $siteUrl" -ForegroundColor Cyan
    Write-Host "(GitHub Pages 빌드에 보통 30초~2분 소요)" -ForegroundColor Gray
    Write-Host ""
    $open = Read-Host "브라우저에서 열어볼까요? (Y/n)"
    if ($open -notmatch '^[nN]') {
        Start-Process $siteUrl
    }
}
Write-Host ""
Read-Host "Enter 키로 종료"
