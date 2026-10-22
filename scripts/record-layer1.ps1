<#
.SYNOPSIS  Record a Layer 1 (Copilot Studio agent evaluation) result for the publish gate.
.EXAMPLE   .\scripts\record-layer1.ps1 -Agent timekeeper -Passed 13 -Total 13
#>
#Requires -Version 7
param(
  [Parameter(Mandatory)][ValidateSet('timekeeper')][string]$Agent,
  [Parameter(Mandatory)][int]$Passed,
  [Parameter(Mandatory)][int]$Total
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$file = Join-Path $root 'harness\reports\layer1.json'
$data = @{}
if (Test-Path $file) { (Get-Content $file -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $data[$_.Name] = $_.Value } }
$data[$Agent] = @{ passed = $Passed; total = $Total; status = $(if ($Passed -eq $Total -and $Total -gt 0) { 'green' } else { 'red' }); recordedAt = (Get-Date).ToString('s') }
$data | ConvertTo-Json -Depth 4 | Set-Content $file -Encoding utf8
Write-Host "Layer 1 / $Agent agent: $Passed of $Total -> $($data[$Agent].status)"
