<#
.SYNOPSIS  Syncs the agent YAML under agents/ with Copilot Studio: pull (merge remote edits), then push.
           Does NOT publish unless -Publish is given: publishing is the human's step.
.PARAMETER Agent     Folder name under agents/ (default: the only cloned agent there).
.PARAMETER PullOnly  Only pull, do not push.
#>
#Requires -Version 7
param([string]$Agent, [switch]$PullOnly, [switch]$Publish)
$ErrorActionPreference = 'Stop'
$agents = Join-Path (Split-Path $PSScriptRoot -Parent) 'agents'
$clones = @(Get-ChildItem $agents -Directory | Where-Object { Test-Path (Join-Path $_.FullName '.mcs\conn.json') })
if ($Agent) { $clones = @($clones | Where-Object Name -eq $Agent) }
if ($clones.Count -ne 1) { throw "Expected one cloned agent under agents/ (found $($clones.Count)). Clone it with the Copilot Studio VS Code extension, or pass -Agent <folder>." }
$dir = $clones[0].FullName
$conn = Get-Content (Join-Path $dir '.mcs\conn.json') -Raw | ConvertFrom-Json

# the active pac profile must point at the agent's environment, or we would push to the wrong place
$active = (pac org who 2>&1 | Out-String)
if ($active -notmatch [regex]::Escape($conn.EnvironmentId)) {
  throw "Active pac environment is not $($conn.EnvironmentId) ($($conn.EnvironmentDisplayName)). Run: pac org select --environment $($conn.EnvironmentId)"
}

pac copilot pull --project-dir $dir
if ($LASTEXITCODE) { throw 'pac copilot pull failed - fix conflicts before pushing.' }
if ($PullOnly) { return }

pac copilot push --project-dir $dir
if ($LASTEXITCODE) { throw 'pac copilot push failed.' }
if ($Publish) {
  # pac exits 0 even when publishing fails, so read its text
  $out = pac copilot publish --bot $conn.AgentId 2>&1 | Out-String
  Write-Host $out
  if ($LASTEXITCODE -or $out -match 'Failed') { throw 'pac copilot publish failed.' }
  Write-Host 'Pushed and published.' -ForegroundColor Green
} else { Write-Host 'Pushed (not published). Re-run with -Publish to go live.' -ForegroundColor Green }
