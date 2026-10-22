<#
.SYNOPSIS  Builds the Timekeeper environment from source. Safe to re-run: anything that already exists is skipped.
           1. Publisher (prefix tk, choice values 49569xxxx) and the Timekeeper solution
           2. The four Dataverse tables, their columns and lookups (specs/001-timekeeper-core/data-model.md)
           3. Seed data: 3 employees, 3 projects, 2 vacation balances (only when Employees is empty)
           4. Environment variable tk_DataverseUrl and connection references tk_dataverse, tk_teams, tk_copilotstudio
           5. The three cloud flows in flows/ (created, or updated in place)
           6. Adds the agent to the solution and binds agents/Timekeeper to it (agent schema name, flow id)
           When a step needs a human, the script stops with a 👤 message. Fix it and re-run. See docs/setup.md.
           A person runs this script, never the coding agent: it acts with your az and pac sign-in.
.PARAMETER ManagerEmail  Email of the seeded manager (Jordan Lee). Use your own work email so the Teams approval card reaches you.
.PARAMETER AgentClone    Folder of a fresh Copilot Studio VS Code extension clone of the empty Timekeeper agent.
                         Its .mcs\ folder (connection files, git-ignored) is copied into agents\Timekeeper.
.PARAMETER Suffix        Only when the environment already has another Timekeeper build: added to the solution, flow and
                         agent names (TimekeeperV2, AskTimekeeperV2, "Timekeeper V2"). The app source is renamed to match.
.EXAMPLE   .\scripts\setup-environment.ps1 -ManagerEmail me@contoso.com -AgentClone "$env:TEMP\tk-clone\Timekeeper"
#>
#Requires -Version 7
param(
  [string]$ManagerEmail = 'jordan@example.com',
  [string]$EmployeeEmail = 'priya@example.com',
  [string]$Employee2Email = 'alex@example.com',
  [string]$AgentClone,
  [ValidatePattern('^[A-Za-z0-9]*$')][string]$Suffix = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$solution = "Timekeeper$Suffix"
$agentName = "Timekeeper $Suffix".Trim()

# the environment comes from the active pac profile, never from source (Constitution VI)
$who = pac org who | Out-String
$org = (($who -split "`n" | Select-String 'Org URL:').Line -replace '.*Org URL:\s*', '').Trim().TrimEnd('/')
if (-not $org) { throw '👤 No active pac environment. Run: pac auth create --environment <your environment URL>' }
$token = az account get-access-token --resource $org --query accessToken -o tsv
if (-not $token) { throw '👤 Run az login --allow-no-subscriptions first.' }
# az and pac signed in as different people gives confusing 401/403 errors later
$pacUser = (($who -split "`n" | Select-String 'User Email:').Line -replace '.*User Email:\s*', '').Trim()
$azUser = az account show --query user.name -o tsv
if ($pacUser -and $azUser -ne $pacUser) { throw "👤 az is signed in as $azUser but pac as $pacUser. Sign both in as the same account." }
$api = "$org/api/data/v9.2"
$h = @{ Authorization = "Bearer $token"; Accept = 'application/json'; 'Content-Type' = 'application/json; charset=utf-8' }
Write-Host "Environment: $org"

function Get-Rows($path) { (Invoke-RestMethod -Headers $h "$api/$path").value }
function Post($path, $body) {
  $r = Invoke-WebRequest -Method Post -Headers $h "$api/$path" -Body ([Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Depth 12)))
  $r.Headers['OData-EntityId'] -replace '.*\(|\).*', ''
}
function L([string]$text) { @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'; LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $text; LanguageCode = 1033 }) } }
function Req([bool]$required) { @{ Value = $(if ($required) { 'ApplicationRequired' } else { 'None' }) } }

# ---- 1. Publisher and solution
Write-Host '1. Publisher and solution'
$pub = Get-Rows "publishers?`$select=publisherid&`$filter=customizationprefix eq 'tk'"
$other = Get-Rows "solutions?`$select=solutionid&`$expand=publisherid(`$select=customizationprefix)&`$filter=uniquename eq '$solution'"
if ($other -and $other[0].publisherid.customizationprefix -ne 'tk') {
  throw "👤 This environment already has a '$solution' solution from another publisher. Re-run with -Suffix V2 (or another suffix)."
}
$pubId = if ($pub) { $pub[0].publisherid } else {
  Post 'publishers' @{ uniquename = 'timekeeper'; friendlyname = 'Timekeeper'; customizationprefix = 'tk'; customizationoptionvalueprefix = 49569 }
}
if (-not (Get-Rows "solutions?`$select=solutionid&`$filter=uniquename eq '$solution'")) {
  Post 'solutions' @{ uniquename = $solution; friendlyname = $solution; version = '1.0.0.0'; 'publisherid@odata.bind' = "/publishers($pubId)" } | Out-Null
}
# from here on, everything created lands in the solution (Constitution III)
$h['MSCRM.SolutionUniqueName'] = $solution

# ---- 2. Tables. Names must match data-model.md: the canvas app, agent, flows and tests use them.
Write-Host '2. Tables and columns'
function Text($schema, $label, [int]$max = 100, [bool]$req = $false, $format = 'Text') {
  @{ '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'; SchemaName = $schema; DisplayName = (L $label); RequiredLevel = (Req $req); MaxLength = $max; FormatName = @{ Value = $format } }
}
function Num($schema, $label, [bool]$req = $false) {
  @{ '@odata.type' = 'Microsoft.Dynamics.CRM.DecimalAttributeMetadata'; SchemaName = $schema; DisplayName = (L $label); RequiredLevel = (Req $req); Precision = 2; MinValue = 0; MaxValue = 100000 }
}
function YesNo($schema, $label) {
  # labels set explicitly, value 1 = True: tables made by hand once had them swapped, which inverts 'Active (Projects)'.True in Power Fx
  @{ '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanAttributeMetadata'; SchemaName = $schema; DisplayName = (L $label); RequiredLevel = (Req $false); DefaultValue = $true
     OptionSet = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.BooleanOptionSetMetadata'; OptionSetType = 'Boolean'; TrueOption = @{ Value = 1; Label = (L 'True') }; FalseOption = @{ Value = 0; Label = (L 'False') } } }
}
$tables = [ordered]@{
  tk_employee = @{ schema = 'tk_Employee'; label = 'Employee'; plural = 'Employees'; primary = (Text 'tk_FullName' 'Full Name' 850)
    columns = @((Text 'tk_Email' 'Email' 100 $true 'Email'), (Num 'tk_WeeklyCapacityHours' 'Weekly Capacity Hours'), (YesNo 'tk_Active' 'Active'))
    lookups = @(@{ schema = 'tk_Manager'; label = 'Manager'; target = 'tk_employee'; req = $false }) }
  tk_project = @{ schema = 'tk_Project'; label = 'Project'; plural = 'Projects'; primary = (Text 'tk_ProjectName' 'Project Name' 850)
    columns = @((Text 'tk_ProjectCode' 'Project Code' 100 $true), (Text 'tk_ClientName' 'Client Name'), (Num 'tk_BudgetHours' 'Budget Hours'), (YesNo 'tk_Active' 'Active'))
    lookups = @() }
  tk_timeentry = @{ schema = 'tk_TimeEntry'; label = 'Time Entry'; plural = 'Time Entries'; primary = (Text 'tk_Title' 'Title' 850)
    columns = @(
      @{ '@odata.type' = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'; SchemaName = 'tk_WorkDate'; DisplayName = (L 'Work Date'); RequiredLevel = (Req $true); Format = 'DateOnly'; DateTimeBehavior = @{ Value = 'UserLocal' } },
      (Num 'tk_Hours' 'Hours' $true), (Text 'tk_Notes' 'Notes' 2000), (Text 'tk_ApproverComment' 'Approver Comment' 2000),
      @{ '@odata.type' = 'Microsoft.Dynamics.CRM.PicklistAttributeMetadata'; SchemaName = 'tk_Status'; DisplayName = (L 'Status'); RequiredLevel = (Req $false); DefaultFormValue = 495690000
         OptionSet = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.OptionSetMetadata'; IsGlobal = $false; OptionSetType = 'Picklist'
           Options = @(@{ Value = 495690000; Label = (L 'Draft') }, @{ Value = 495690001; Label = (L 'Submitted') }, @{ Value = 495690002; Label = (L 'Approved') }, @{ Value = 495690003; Label = (L 'Rejected') }) } })
    lookups = @(@{ schema = 'tk_Employee'; label = 'Employee'; target = 'tk_employee'; req = $true }, @{ schema = 'tk_Project'; label = 'Project'; target = 'tk_project'; req = $true }) }
  tk_vacationbalance = @{ schema = 'tk_VacationBalance'; label = 'Vacation Balance'; plural = 'Vacation Balances'; primary = (Text 'tk_Title' 'Title' 850)
    columns = @(
      @{ '@odata.type' = 'Microsoft.Dynamics.CRM.IntegerAttributeMetadata'; SchemaName = 'tk_Year'; DisplayName = (L 'Year'); RequiredLevel = (Req $true); MinValue = 2000; MaxValue = 2100; Format = 'None' },
      (Num 'tk_AccruedHours' 'Accrued Hours'), (Num 'tk_UsedHours' 'Used Hours'), (Num 'tk_RemainingHours' 'Remaining Hours'))
    lookups = @(@{ schema = 'tk_Employee'; label = 'Employee'; target = 'tk_employee'; req = $true }) }
}
$existingTables = @(Get-Rows "EntityDefinitions?`$select=LogicalName&`$filter=IsCustomEntity eq true" | ForEach-Object LogicalName)
foreach ($t in $tables.Keys) {
  if ($t -in $existingTables) { continue }
  $d = $tables[$t]
  $d.primary.IsPrimaryName = $true
  Post 'EntityDefinitions' @{ '@odata.type' = 'Microsoft.Dynamics.CRM.EntityMetadata'; SchemaName = $d.schema; DisplayName = (L $d.label); DisplayCollectionName = (L $d.plural)
    OwnershipType = 'UserOwned'; IsActivity = $false; HasActivities = $false; HasNotes = $false; Attributes = @($d.primary) } | Out-Null
  Write-Host "  table $t"
}
# columns after all tables exist, so lookups can point at any of them
foreach ($t in $tables.Keys) {
  $d = $tables[$t]
  $have = @(Get-Rows "EntityDefinitions(LogicalName='$t')/Attributes?`$select=LogicalName" | ForEach-Object LogicalName)
  foreach ($c in $d.columns) {
    if ($c.SchemaName.ToLower() -in $have) { continue }
    Post "EntityDefinitions(LogicalName='$t')/Attributes" $c | Out-Null
    Write-Host "  $t.$($c.SchemaName.ToLower())"
  }
  foreach ($k in $d.lookups) {
    if ($k.schema.ToLower() -in $have) { continue }
    # the navigation property defaults to the lookup's schema name (tk_Employee), which the app and flows use in @odata.bind
    Post 'RelationshipDefinitions' @{ '@odata.type' = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'; SchemaName = "$($d.schema)_$($k.schema)"
      ReferencedEntity = $k.target; ReferencingEntity = $t
      CascadeConfiguration = @{ Assign = 'NoCascade'; Delete = 'RemoveLink'; Merge = 'NoCascade'; Reparent = 'NoCascade'; Share = 'NoCascade'; Unshare = 'NoCascade' }
      Lookup = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'; SchemaName = $k.schema; DisplayName = (L $k.label); RequiredLevel = (Req $k.req) } } | Out-Null
    Write-Host "  $t.$($k.schema.ToLower()) -> $($k.target)"
  }
}
Invoke-RestMethod -Method Post -Headers $h "$api/PublishAllXml" -Body '{}' | Out-Null

# ---- 3. Seed data (data-model.md, "Demo seed data")
Write-Host '3. Seed data'
if (Get-Rows 'tk_employees?$select=tk_employeeid&$top=1') { Write-Host '  Employees already has rows: skipped' } else {
  foreach ($x in @(@('Contoso Migration', 'CON-001', 'Contoso', 400), @('Fabrikam Portal', 'FAB-002', 'Fabrikam', 250), @('Internal Training', 'INT-003', 'Internal', 100))) {
    Post 'tk_projects' @{ tk_projectname = $x[0]; tk_projectcode = $x[1]; tk_clientname = $x[2]; tk_budgethours = $x[3]; tk_active = $true } | Out-Null
  }
  $mgr = Post 'tk_employees' @{ tk_fullname = 'Jordan Lee'; tk_email = $ManagerEmail.ToLower(); tk_weeklycapacityhours = 40; tk_active = $true }
  $year = (Get-Date).Year
  foreach ($x in @(@('Priya Patel', $EmployeeEmail, 24), @('Alex Kim', $Employee2Email, 40))) {
    $e = Post 'tk_employees' @{ tk_fullname = $x[0]; tk_email = $x[1].ToLower(); tk_weeklycapacityhours = 40; tk_active = $true; 'tk_Manager@odata.bind' = "/tk_employees($mgr)" }
    Post 'tk_vacationbalances' @{ tk_title = "$($x[0]) $year"; tk_year = $year; tk_accruedhours = 80; tk_usedhours = $x[2]; tk_remaininghours = 80 - $x[2]; 'tk_Employee@odata.bind' = "/tk_employees($e)" } | Out-Null
  }
  Write-Host "  3 projects, 3 employees (manager: $ManagerEmail), 2 vacation balances for $year"
}

# ---- 4. Environment variable (the agent's Dataverse tools read the org URL from it) and connection references
Write-Host '4. Environment variable and connection references'
if (-not (Get-Rows "environmentvariabledefinitions?`$select=environmentvariabledefinitionid&`$filter=schemaname eq 'tk_DataverseUrl'")) {
  $def = Post 'environmentvariabledefinitions' @{ schemaname = 'tk_DataverseUrl'; displayname = 'Dataverse URL'; type = 100000000 }
  Post 'environmentvariablevalues' @{ schemaname = 'tk_DataverseUrl_value'; value = $org; 'EnvironmentVariableDefinitionId@odata.bind' = "/environmentvariabledefinitions($def)" } | Out-Null
}
# a connection needs an interactive sign-in, so a human makes it once; the references point at it
$connections = @{}
foreach ($line in (pac connection list)) {
  if ($line -match '^(\S+)\s+.*/providers/Microsoft\.PowerApps/apis/(shared_\w+)\s+Connected' -and -not $connections[$Matches[2]]) { $connections[$Matches[2]] = $Matches[1] }
}
$refs = [ordered]@{ tk_dataverse = 'shared_commondataserviceforapps'; tk_teams = 'shared_teams'; tk_copilotstudio = 'shared_microsoftcopilotstudio' }
$missing = @($refs.Values | Where-Object { -not $connections[$_] })
if ($missing) { throw "👤 Create these connections in Power Automate (Connections > New connection), then re-run: $($missing -join ', ')" }
foreach ($name in $refs.Keys) {
  if (Get-Rows "connectionreferences?`$select=connectionreferenceid&`$filter=connectionreferencelogicalname eq '$name'") { continue }
  Post 'connectionreferences' @{ connectionreferencelogicalname = $name; connectionreferencedisplayname = $name
    connectorid = "/providers/Microsoft.PowerApps/apis/$($refs[$name])"; connectionid = $connections[$refs[$name]] } | Out-Null
  Write-Host "  $name"
}

# ---- 5. Flows. The agent must exist first: AskTimekeeper calls it by schema name.
$bot = Get-Rows "bots?`$select=botid,schemaname&`$filter=name eq '$agentName'"
if (-not $bot) { throw "👤 Create an empty agent named `"$agentName`" in Copilot Studio, then re-run." }
$botId = $bot[0].botid; $schema = $bot[0].schemaname
Write-Host '5. Flows'
$flowIds = @{}
foreach ($file in 'AskTimekeeper', 'SubmitMyWeek', 'SubmitMyWeekAgent') {
  $name = "$file$Suffix"
  $clientdata = (Get-Content (Join-Path $root "flows\$file.json") -Raw).Replace('__AGENT_SCHEMA__', $schema)
  $existing = Get-Rows "workflows?`$select=workflowid&`$filter=name eq '$name' and category eq 5"
  if ($existing) {
    # update in place: turn off, replace the definition, turn on again
    $id = $existing[0].workflowid
    Invoke-RestMethod -Method Patch -Headers $h "$api/workflows($id)" -Body '{"statecode":0,"statuscode":1}' | Out-Null
    Invoke-RestMethod -Method Patch -Headers $h "$api/workflows($id)" -Body ([Text.Encoding]::UTF8.GetBytes((@{ clientdata = $clientdata } | ConvertTo-Json))) | Out-Null
  } else {
    $id = Post 'workflows' @{ name = $name; category = 5; type = 1; primaryentity = 'none'; clientdata = $clientdata }
  }
  # turning a flow on also validates its definition and connection references
  Invoke-RestMethod -Method Patch -Headers $h "$api/workflows($id)" -Body '{"statecode":1,"statuscode":2}' | Out-Null
  $flowIds[$file] = $id
  Write-Host "  $name on"
}

# ---- 6. Agent: add to the solution (pac doesn't know the bot component type 10227), then bind the local source
Write-Host '6. Agent'
$add = @{ ComponentId = $botId; ComponentType = 10227; SolutionUniqueName = $solution; AddRequiredComponents = $true } | ConvertTo-Json
Invoke-RestMethod -Method Post -Headers $h "$api/AddSolutionComponent" -Body $add | Out-Null
$agentDir = Join-Path $root 'agents\Timekeeper'
if ($AgentClone) { Copy-Item (Join-Path $AgentClone '.mcs') $agentDir -Recurse -Force }
if (-not (Test-Path (Join-Path $agentDir '.mcs\conn.json'))) {
  throw '👤 Clone the agent with the Copilot Studio VS Code extension into a folder OUTSIDE this repo, then re-run with -AgentClone <that folder>.'
}
Get-ChildItem $agentDir -Recurse -Filter '*.mcs.yml' | ForEach-Object {
  $text = Get-Content $_.FullName -Raw
  $bound = $text.Replace('__AGENT_SCHEMA__', $schema).Replace('__SUBMIT_FLOW_ID__', $flowIds['SubmitMyWeekAgent']) -replace '(?m)^displayName: Timekeeper\b[^\r\n]*', "displayName: $agentName"
  if ($bound -ne $text) { Set-Content $_.FullName $bound -NoNewline -Encoding utf8 }
}
# the app calls the flows by name, so a suffixed build renames those calls
if ($Suffix) {
  Get-ChildItem (Join-Path $root 'canvasapp') -Filter '*.pa.yaml' | ForEach-Object {
    $text = Get-Content $_.FullName -Raw
    $bound = $text -replace '\b(AskTimekeeper|SubmitMyWeek)\.Run\(', ('${1}' + $Suffix + '.Run(')
    if ($bound -ne $text) { Set-Content $_.FullName $bound -NoNewline -Encoding utf8 }
  }
}
Write-Host '  agents\Timekeeper now holds this environment''s agent schema and flow id. Keep that out of public forks.' -ForegroundColor Yellow
Write-Host "`nDone. Next: docs/setup.md step 6 (push the agent with .\scripts\sync-agent.ps1, then build the app)." -ForegroundColor Green
