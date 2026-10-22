<#
.SYNOPSIS  Offline check, no environment needed: is the repo consistent and clean enough to publish?
           1. Every tk_ name used by the canvas app, agent, flows and tests is created by setup-environment.ps1
           2. Every JSON file and PowerShell script parses
           3. No personal data, org URLs, environment IDs or other AI tool names (Constitution VI)
           Exits 1 on any failure. It can't prove the environment calls work: run setup-environment.ps1 in a test environment for that.
#>
#Requires -Version 7
$root = Split-Path $PSScriptRoot -Parent
$fail = 0
function Bad($msg) { Write-Host "  FAIL $msg" -ForegroundColor Red; $script:fail++ }
$files = git -C $root ls-files --cached --others --exclude-standard | Where-Object { $_ -notmatch '^(\.github/skills|\.specify/(scripts|templates))/' } | ForEach-Object { Join-Path $root $_ }

Write-Host '1. Dataverse names'
$setup = Get-Content (Join-Path $root 'scripts\setup-environment.ps1') -Raw
$known = @{}
foreach ($m in [regex]::Matches($setup, "'(tk_\w+)'")) { $known[$m.Groups[1].Value.ToLower()] = 1 }
foreach ($t in 'employee', 'project', 'timeentry', 'vacationbalance') { $known["tk_$($t)id"] = 1 }
foreach ($s in 'employees', 'projects', 'timeentries', 'vacationbalances') { $known["tk_$s"] = 1 }
foreach ($k in 'manager', 'employee', 'project') { $known["_tk_$($k)_value"] = 1 }
foreach ($m in [regex]::Matches($setup, '\b(tk_[a-z]+) = ''shared_')) { $known[$m.Groups[1].Value] = 1 }   # connection references
$used = @{}
foreach ($f in $files | Where-Object { $_ -match '\\(canvasapp|agents|flows|harness)\\' -and $_ -match '\.(yaml|yml|json|ts|csv)$' }) {
  foreach ($m in [regex]::Matches((Get-Content $f -Raw), '\b_?tk_[A-Za-z]+(?:_value)?\b')) { $used[$m.Value.ToLower()] += @((Split-Path $f -Leaf)) }
}
foreach ($n in $used.Keys | Sort-Object) { if (-not $known[$n]) { Bad "$n is used in $(($used[$n] | Select-Object -Unique) -join ', ') but not created by setup-environment.ps1" } }
Write-Host "  $($used.Count) names checked"

Write-Host '2. Files parse'
foreach ($f in $files | Where-Object { $_ -like '*.json' }) { try { Get-Content $f -Raw | ConvertFrom-Json -AsHashtable | Out-Null } catch { Bad "$f is not valid JSON" } }
foreach ($f in $files | Where-Object { $_ -like '*.ps1' }) {
  $e = $null; [void][Management.Automation.Language.Parser]::ParseFile($f, [ref]$null, [ref]$e)
  if ($e) { Bad "$f does not parse: $($e[0].Message)" }
}

Write-Host '3. Nothing private or tool-specific'
$pattern = '(?i)org[0-9a-f]{8}\.crm|\.onmicrosoft\.com|eyJ[A-Za-z0-9_-]{20,}'
# extra private words (your company, user names), one regex per line, in git-ignored scripts\.private-patterns
$private = Join-Path $PSScriptRoot '.private-patterns'
if (Test-Path $private) { $pattern += '|' + ((Get-Content $private | Where-Object { $_.Trim() }) -join '|') }
# designer-generated ids (flow operationMetadataId, topic node ids) are random and harmless
$guidOk = '(?i)operationMetadataId|^\s*id:\s'
foreach ($f in $files | Where-Object { $_ -notmatch '\.(png|ico)$' -and $_ -ne $PSCommandPath }) {
  $n = 0
  foreach ($line in Get-Content $f) {
    $n++
    if ($line -match $pattern) { Bad "$(Split-Path $f -Leaf):$n '$($Matches[0])'" }
    if ($line -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' -and $line -notmatch $guidOk) { Bad "$(Split-Path $f -Leaf):$n has a GUID" }
  }
}
$agent = Get-Content (Join-Path $root 'agents\Timekeeper\settings.mcs.yml') -Raw
if ($agent -notmatch '__AGENT_SCHEMA__') { Bad 'agents\Timekeeper is bound to an environment (run git checkout -- agents before publishing)' }

if ($fail) { Write-Host "`n$fail problem(s)." -ForegroundColor Red; exit 1 }
Write-Host "`nRepo check green." -ForegroundColor Green
