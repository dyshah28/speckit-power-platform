<#
.SYNOPSIS  You run this, not the coding agent. Writes TK_ORG_URL, TK_APP_URL and a Dataverse-only access token into
           harness\layer2-playwright\.env (git-ignored), so the agent can run the Layer 2 tests with npm test
           without any az or pac access. The token works only against this environment's Dataverse and expires
           in about an hour; when the tests start failing with 401, run this again.
.PARAMETER App  Canvas app display name (default Timekeeper App; "Timekeeper App V2" for a -Suffix V2 build).
#>
#Requires -Version 7
param([string]$App = 'Timekeeper App')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$org = ((pac org who | Select-String 'Org URL:').Line -replace '.*Org URL:\s*', '').Trim().TrimEnd('/')
if (-not $org) { throw 'No active pac environment. Run: pac auth create --environment <your environment URL>' }
$token = az account get-access-token --resource $org --query accessToken -o tsv
if (-not $token) { throw 'Run az login --allow-no-subscriptions first.' }
$h = @{ Authorization = "Bearer $token"; Accept = 'application/json' }
$appUrl = (Invoke-RestMethod -Headers $h "$org/api/data/v9.2/canvasapps?`$select=appopenuri&`$filter=displayname eq '$App'").value[0].appopenuri
if (-not $appUrl) { throw "No canvas app named '$App' in $org. Pass -App with its display name." }

# keep every other setting in .env (manager email, mutations), replace only these three
$dir = Join-Path $root 'harness\layer2-playwright'
$file = Join-Path $dir '.env'
$lines = Get-Content $(if (Test-Path $file) { $file } else { Join-Path $dir '.env.example' })
$lines = @($lines | Where-Object { $_ -notmatch '^(TK_ORG_URL|TK_APP_URL|TK_DATAVERSE_TOKEN)=' }) + "TK_ORG_URL=$org", "TK_APP_URL=$appUrl", "TK_DATAVERSE_TOKEN=$token"
Set-Content $file $lines -Encoding utf8
Write-Host "Wrote harness\layer2-playwright\.env for $org (token valid about an hour). Don't paste it anywhere." -ForegroundColor Green
