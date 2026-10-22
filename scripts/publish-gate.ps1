<#
.SYNOPSIS  Constitution IV + II: refuse to publish unless every required layer is green, then ask the human.
#>
#Requires -Version 7
$root = Split-Path $PSScriptRoot -Parent
$file = Join-Path $root 'harness\reports\harness-summary.json'
if (-not (Test-Path $file)) { Write-Host 'Run .\scripts\run-harness.ps1 first.' -ForegroundColor Yellow; exit 1 }
$summary = Get-Content $file -Raw | ConvertFrom-Json
$red = $summary.PSObject.Properties | Where-Object { $_.Value -like 'red*' }
if ($red) {
  Write-Host 'Publish blocked (Constitution IV):' -ForegroundColor Red
  $red | ForEach-Object { Write-Host "  $($_.Name): $($_.Value)" -ForegroundColor Red }
  exit 1
}
Write-Host 'All required harness layers are green.' -ForegroundColor Green
$answer = Read-Host 'HUMAN GATE: final go/no-go. Type "ship" to proceed'
if ($answer -ne 'ship') { Write-Host 'No-go recorded. Nothing published.'; exit 0 }
Write-Host 'GO. Now Save and Publish the app in Power Apps Studio (and publish agents in Copilot Studio).' -ForegroundColor Green
Add-Content (Join-Path $root 'harness\reports\go-decisions.log') "$(Get-Date -Format s)  GO by $env:USERNAME"
