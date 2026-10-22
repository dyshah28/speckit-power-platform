<#
.SYNOPSIS  The whole Timekeeper harness in one command. Prints a traffic-light summary and writes
           harness\reports\harness-summary.json, which publish-gate.ps1 reads.
           Layer 1: syncs and runs every agent's Copilot Studio test set (run-agent-evals.ps1)
           Layer 2: Playwright UI suites + Dataverse API contract + theme
           Layer 3: reads harness\reports\layer3.json written by the verifier during speckit-implement
           App URL, org URL and the API token come from pac/az, so harness\layer2-playwright\.env is optional.
.PARAMETER App           Canvas app display name (default Timekeeper App).
.PARAMETER SkipAgentEvals  Use the last recorded Layer 1 result instead of running the evaluations (they take a few minutes).
.NOTES     One-time: az login, pac auth, and "npm run auth" in harness\layer2-playwright (records your Microsoft sign-in).
#>
#Requires -Version 7
param([string]$App = 'Timekeeper App', [switch]$SkipAgentEvals)
$root = Split-Path $PSScriptRoot -Parent
$reports = Join-Path $root 'harness\reports'
New-Item -ItemType Directory -Force -Path $reports | Out-Null
$summary = [ordered]@{}

# ---- Environment (Constitution VI: nothing environment-specific in source)
$org = ((pac org who | Select-String 'Org URL:').Line -replace '.*Org URL:\s*', '').Trim().TrimEnd('/')
if (-not $org) { throw 'No active pac environment. Run: pac auth create / pac org select' }
$token = az account get-access-token --resource $org --query accessToken -o tsv
if (-not $token) { throw 'az login first.' }
$env:TK_ORG_URL = $org
$env:TK_DATAVERSE_TOKEN = $token
if (-not $env:TK_APP_URL) {
  $h = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
  $env:TK_APP_URL = (Invoke-RestMethod -Headers $h "$org/api/data/v9.2/canvasapps?`$select=appopenuri&`$filter=displayname eq '$App'").value[0].appopenuri
}

# ---- Layer 1: every cloned agent needs a test set at harness\layer1-agent-evals\<agent>-agent.csv
$agents = Get-ChildItem (Join-Path $root 'agents') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'settings.mcs.yml') }
$l1 = @()
foreach ($a in $agents) {
  $name = $a.Name.ToLower()
  $schema = ((Select-String -Path (Join-Path $a.FullName 'settings.mcs.yml') -Pattern '^schemaName:\s*(\S+)').Matches[0].Groups[1].Value)
  if (-not (Test-Path (Join-Path $root "harness\layer1-agent-evals\$name-agent.csv"))) { $l1 += "red ($name has no test set)"; continue }
  if (-not $SkipAgentEvals) {
    try { & (Join-Path $PSScriptRoot 'run-agent-evals.ps1') -Agent $name -Schema $schema }
    catch { $l1 += "red ($name evaluation failed: $($_.Exception.Message))"; continue }
  }
  $rec = (Get-Content (Join-Path $reports 'layer1.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json).$name
  $l1 += $(if (-not $rec) { "red ($name not recorded)" } elseif ($rec.status -ne 'green') { "red ($name $($rec.passed)/$($rec.total))" } else { "$name $($rec.passed)/$($rec.total)" })
}
$summary['Layer 1 · agent evals'] = $(if (-not $l1) { 'n/a (no agents)' } elseif ($l1 -match '^red') { 'red  ' + ($l1 -join '; ') } else { 'green  ' + ($l1 -join '; ') })

# ---- Layer 2
Push-Location (Join-Path $root 'harness\layer2-playwright')
try {
  if (-not (Test-Path 'auth\maker.json')) { Write-Host 'No recorded sign-in: UI suites will skip. Run "npm run auth" here once.' -ForegroundColor Yellow }
  npx playwright test
  $s = (Get-Content (Join-Path $reports 'layer2-results.json') -Raw | ConvertFrom-Json).stats
  $state = if ($s.unexpected -gt 0) { 'red' } elseif (-not (Test-Path 'auth\maker.json')) { 'red (UI suites skipped - run "npm run auth" once)' } else { 'green' }
  $summary['Layer 2 · Playwright + API'] = "$state  [passed $($s.expected), failed $($s.unexpected), flaky $($s.flaky), skipped $($s.skipped)]"
} catch { $summary['Layer 2 · Playwright + API'] = "red ($($_.Exception.Message))" }
finally { Pop-Location }

# ---- Layer 3
$l3File = Join-Path $reports 'layer3.json'
if (Test-Path (Join-Path $root 'harness-report.md')) { $summary['Layer 3 · self-correct'] = 'red (budget exhausted - see harness-report.md)' }
elseif (Test-Path $l3File) { $summary['Layer 3 · self-correct'] = (Get-Content $l3File -Raw | ConvertFrom-Json).status }
else { $summary['Layer 3 · self-correct'] = 'n/a (no implement run yet)' }

Write-Host "`n==== Timekeeper harness ===="
foreach ($k in $summary.Keys) {
  $v = $summary[$k]
  $color = if ($v -like 'green*') { 'Green' } elseif ($v -like 'red*') { 'Red' } else { 'Yellow' }
  Write-Host ("{0,-28} {1}" -f $k, $v) -ForegroundColor $color
}
$summary | ConvertTo-Json | Set-Content (Join-Path $reports 'harness-summary.json') -Encoding utf8
if (@($summary.Values) -match '^red') { Write-Host "`nHarness is red: fix before the go/no-go." -ForegroundColor Red; exit 1 }
Write-Host "`nAll layers green. HUMAN GATE: final go/no-go (.\scripts\publish-gate.ps1)" -ForegroundColor Green
