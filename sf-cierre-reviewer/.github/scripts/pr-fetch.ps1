<#
.SYNOPSIS
  Descarga datos del PR desde GitHub y los guarda en .github/pr-cache/ para que el agente los lea sin necesitar terminal.

.USAGE
  pwsh .github/scripts/pr-fetch.ps1 42
  pwsh .github/scripts/pr-fetch.ps1 42 jira   # incluye contexto Jira si hay .env configurado
#>
param(
  [Parameter(Mandatory)][int]$PrNumber,
  [string]$Mode = ""
)

$env:PATH += ";C:\Program Files\GitHub CLI"
$repo = "ueno-tecnologia-org/ueno_core"
$cacheDir = "$PSScriptRoot\..\pr-cache"

if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir | Out-Null }

Write-Host "=== PR-FETCH PR#$PrNumber ===" -ForegroundColor Cyan

# --- 1. gh auth check ---
Write-Host "[1/4] gh auth status..." -NoNewline
$authResult = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host " FALLO" -ForegroundColor Red
  Write-Host $authResult
  Write-Host "`nEjecuta: gh auth login`n"
  exit 1
}
Write-Host " OK" -ForegroundColor Green

# --- 2. PR metadata ---
Write-Host "[2/4] gh pr view..." -NoNewline
$prJson = gh pr view $PrNumber `
  --repo $repo `
  --json "number,title,headRefName,headRefOid,baseRefName,baseRefOid,files,body,labels" 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host " FALLO" -ForegroundColor Red
  Write-Host $prJson
  exit 1
}
$prJson | Out-File -Encoding UTF8 "$cacheDir\pr-$PrNumber.json"
Write-Host " OK" -ForegroundColor Green

# extraer ticket del headRefName
$prData = $prJson | ConvertFrom-Json
$ticketMatch = $prData.headRefName -match '([A-Z]+-\d+)'
$ticket = if ($ticketMatch) { $Matches[1] } else { "UNKNOWN" }
Write-Host "    Ticket: $ticket | Branch: $($prData.headRefName)"

# --- 3. PR diff ---
Write-Host "[3/4] gh pr diff..." -NoNewline
$diff = gh pr diff $PrNumber --repo $repo 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Host " FALLO" -ForegroundColor Red
  Write-Host $diff
  exit 1
}
$diff | Out-File -Encoding UTF8 "$cacheDir\pr-$PrNumber.diff"
Write-Host " OK" -ForegroundColor Green

# --- 4. Jira (opcional) ---
$jiraStatus = "SKIPPED"
if ($Mode -eq "jira") {
  Write-Host "[4/4] Jira $ticket..." -NoNewline
  $envFile = "$PSScriptRoot\..\..\.github\..\.github\..\tools\mcp-jira\.env"
  $envFile = Resolve-Path "$PSScriptRoot\..\..\tools\mcp-jira\.env" -ErrorAction SilentlyContinue
  if ($envFile -and (Test-Path $envFile)) {
    Get-Content $envFile | ForEach-Object {
      if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
      $parts = $_ -split '=', 2
      $k = $parts[0].Trim(); $v = $parts[1].Trim()
      if ($k) { [Environment]::SetEnvironmentVariable($k, $v) }
    }
  }
  try {
    $pair = "$($env:JIRA_EMAIL):$($env:JIRA_API_TOKEN)"
    $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
    $resp = Invoke-RestMethod -Method Get `
      -Uri "$($env:JIRA_BASE_URL)/rest/api/3/issue/$ticket" `
      -Headers @{ Authorization = "Basic $auth"; Accept = "application/json" }
    $resp | ConvertTo-Json -Depth 10 | Out-File -Encoding UTF8 "$cacheDir\pr-$PrNumber-jira.json"
    Write-Host " OK" -ForegroundColor Green
    $jiraStatus = "OK"
  } catch {
    Write-Host " FALLO ($_)" -ForegroundColor Yellow
    $jiraStatus = "FAILED"
    '{"error":"Jira no disponible"}' | Out-File -Encoding UTF8 "$cacheDir\pr-$PrNumber-jira.json"
  }
} else {
  Write-Host "[4/4] Jira: omitido (pasar 'jira' como segundo argumento para incluir)"
}

# --- Resumen ---
$files = ($prData.files | Where-Object { $_.path -match '\.(spc|bdy|prc|fnc)$' }).Count
Write-Host ""
Write-Host "Cache generado en: .github/pr-cache/" -ForegroundColor Green
Write-Host "  pr-$PrNumber.json        (metadata + lista de archivos)"
Write-Host "  pr-$PrNumber.diff        (diff completo del PR)"
if ($jiraStatus -ne "SKIPPED") { Write-Host "  pr-$PrNumber-jira.json   (contexto Jira: $jiraStatus)" }
Write-Host ""
Write-Host "Archivos PL/SQL en el PR: $files"
Write-Host "Ticket: $ticket"
Write-Host ""
Write-Host "Ahora podes invocar el revisor en VS Code:" -ForegroundColor Cyan
Write-Host "  @CB PL/SQL Reviewer PR#$PrNumber | .github/reports/pr-$PrNumber-cb-review.md"
