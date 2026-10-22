<#
.SYNOPSIS  Layer 1, fully automated: syncs the agent test set in Copilot Studio from the CSV, runs it on the
           published agent, waits for the result and records it in harness\reports\layer1.json.
.PARAMETER Agent     Short name used in layer1.json (default timekeeper).
.PARAMETER Schema    Agent schema name (default: schemaName in agents\<Agent>\settings.mcs.yml, bound by setup-environment.ps1).
.PARAMETER TimeZone  Organisation time zone used for TODAY in questions (must match the flows).
.PARAMETER Csv       Test set CSV (Question, Expected response).
.NOTES     How test sets are stored: see docs/automation-playbook.md ("Agent evaluation").
#>
#Requires -Version 7
param(
  [string]$Agent = 'timekeeper',
  [string]$Schema,
  [string]$TimeZone = 'Central Standard Time',
  [string]$Csv,
  [int]$TimeoutMinutes = 20
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $Csv) { $Csv = Join-Path $root "harness\layer1-agent-evals\$Agent-agent.csv" }
if (-not $Schema) { $Schema = ((Select-String -Path (Join-Path $root "agents\$Agent\settings.mcs.yml") -Pattern '^schemaName:\s*(\S+)').Matches[0].Groups[1].Value) }
if ($Schema -like '__*') { throw 'agents\Timekeeper is not bound to an environment yet. Run .\scripts\setup-environment.ps1 first.' }
$setName = "$Agent - harness"

$org = ((pac org who | Select-String 'Org URL:').Line -replace '.*Org URL:\s*', '').Trim().TrimEnd('/')
if (-not $org) { throw 'No active pac environment. Run: pac org select' }
$token = az account get-access-token --resource $org --query accessToken -o tsv
$h = @{ Authorization = "Bearer $token"; Accept = 'application/json'; 'Content-Type' = 'application/json; charset=utf-8' }
$api = "$org/api/data/v9.2"
$botId = (Invoke-RestMethod -Headers $h "$api/bots?`$select=botid&`$filter=schemaname eq '$Schema'").value[0].botid
if (-not $botId) { throw "Agent $Schema not found." }

function YamlQuote([string]$s) { '"' + ($s -replace '\\', '\\' -replace '"', '\"') + '"' }
function New-Component([string]$name, [string]$data, [string]$parentSetId) {
  # category 'Testing' and a description are required, or the run fails with HTTP 500
  $short = $name.Substring(0, [Math]::Min(400, $name.Length))
  $body = @{ name = $short; description = $short; category = 'Testing'; componenttype = 19
             schemaname = "mspva_$([guid]::NewGuid())"; data = $data
             'parentbotid@odata.bind' = "/bots($botId)" }
  if ($parentSetId) { $body['ParentBotComponentId@odata.bind'] = "/botcomponents($parentSetId)" }
  $r = Invoke-WebRequest -Method Post -Headers $h "$api/botcomponents" -Body ([Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json)))
  $r.Headers['OData-EntityId'] -replace '.*\(|\).*', ''
}

# 1. Sync the test set: one EvaluationSet component, one EvaluationData component per CSV row
$cases = Import-Csv $Csv
# TODAY in a question becomes the real date in the organisation time zone, the way the app writes it
$today = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTime]::UtcNow, $TimeZone).ToString('yyyy-MM-dd (dddd)', [Globalization.CultureInfo]::InvariantCulture)
# EMPLOYEE_ID becomes the Employee row id of the email in the same context line (ids differ per environment)
$ids = @{}
foreach ($c in $cases) {
  $c.Question = $c.Question.Replace('TODAY', $today)
  if ($c.Question -match '\[User: ([^;]+); Employee: EMPLOYEE_ID') {
    $email = $Matches[1]
    if (-not $ids[$email]) { $ids[$email] = (Invoke-RestMethod -Headers $h "$api/tk_employees?`$select=tk_employeeid&`$filter=tk_email eq '$email'").value[0].tk_employeeid }
    if (-not $ids[$email]) { throw "No Employee row for $email (seed data missing?)" }
    $c.Question = $c.Question.Replace('EMPLOYEE_ID', $ids[$email])
  }
}
$set = (Invoke-RestMethod -Headers $h "$api/botcomponents?`$select=botcomponentid&`$filter=_parentbotid_value eq $botId and componenttype eq 19 and name eq '$setName'").value
if ($set) {
  $setId = $set[0].botcomponentid
  $old = (Invoke-RestMethod -Headers $h "$api/botcomponents?`$select=botcomponentid&`$filter=_parentbotcomponentid_value eq $setId").value
  foreach ($c in $old) { Invoke-RestMethod -Method Delete -Headers $h "$api/botcomponents($($c.botcomponentid))" | Out-Null }
} else {
  $setId = New-Component $setName "kind: EvaluationSet`ngraders:`n  - kind: CompareMeaningGrader`n" $null
}
$i = 0
foreach ($c in $cases) {
  $i++
  $data = "kind: EvaluationData`nrows:`n  - source: Imported`n    expectedOutput: $(YamlQuote $c.'Expected response')`n    input: $(YamlQuote $c.Question)`n`nextensionData:`n  displayOrder: `"$i`"`n"
  New-Component $c.Question $data $setId | Out-Null
}
Write-Host "Test set '$setName' ($setId): $($cases.Count) cases synced from $(Split-Path $Csv -Leaf)"

# 2. Run it and wait. The draft agent is used: in pac 2.13 the --run-on-published-bot, --mcs-connection-id and
#    --evaluation-run-name options return HTTP 500. sync-agent.ps1 publishes what it pushes, so draft = published.
# The 'Agent Evaluation' (Microsoft Copilot Studio) connection signs the run in, so agents that require sign-in answer
$evalConn = ((pac connection list | Select-String 'Agent Evaluation' | Select-Object -First 1).Line -split '\s+')[0]
$connArgs = if ($evalConn) { @('--mcs-connection-id', $evalConn) } else { @() }
$runOut = (pac copilot-studio run-maker-evaluation-test-set --bot-id $botId --test-set-id $setId @connArgs 2>&1 | Out-String)
$runId = ([regex]::Match($runOut, '"runId":\s*"([0-9a-f-]{36})"')).Groups[1].Value
if (-not $runId) { throw "Could not start the evaluation run:`n$runOut" }
Write-Host "Evaluation run $runId started; waiting..."
$deadline = (Get-Date).AddMinutes($TimeoutMinutes)
do {
  Start-Sleep -Seconds 20
  $run = pac copilot-studio get-maker-evaluation-test-run --bot-id $botId --test-run-id $runId --json 2>$null | Out-String | ConvertFrom-Json
} while ($run.state -notmatch 'Completed|Failed|Aborted|Cancel' -and (Get-Date) -lt $deadline)
if ($run.state -notmatch 'Completed') { throw "Evaluation run $runId ended as '$($run.state)'." }

# 3. Record: a case passes when every grader result on it passed
$results = @($run.testCasesResults)
$passed = @($results | Where-Object { @($_.metricsResults | Where-Object { $_.result.status -ne 'Pass' }).Count -eq 0 }).Count
$results | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $root "harness\reports\layer1-$Agent-run.json") -Encoding utf8
& (Join-Path $PSScriptRoot 'record-layer1.ps1') -Agent $Agent -Passed $passed -Total $results.Count
