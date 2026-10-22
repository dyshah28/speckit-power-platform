# Automation playbook: Power Apps, Copilot Studio, Dataverse and flows from the command line

How every step of Timekeeper is done by script or by GitHub Copilot, what still needs a human, and the traps
we hit. Verified against pac CLI 2.13.1, the canvas-authoring MCP server (`canvas-apps` plugin) and Dataverse Web API v9.2
in October 2026. Scripts referenced here live in `scripts/`.

## 0. Sign-ins (one time, human)

| Tool | Command | Used for |
|---|---|---|
| Azure CLI | `az login` | Bearer tokens for the Dataverse Web API: `az account get-access-token --resource <org url>` |
| pac CLI | `pac auth create` then `pac org select --environment <id>` | Solutions, agents, connections, evaluations. Scripts read the org URL from `pac org who`, so no environment ID is stored in source (Constitution VI) |
| GitHub Copilot CLI + `canvas-apps` plugin | `/plugin marketplace add microsoft/power-platform-skills`, `/plugin install canvas-apps@power-platform-skills`, then `/canvas-apps:configure-canvas-mcp` with the Studio URL | Live coauthoring of the canvas app through the canvas-authoring MCP server (Studio tab must stay open) |
| Copilot Studio VS Code extension | Clone the agent into `agents/<Agent Name>/` | Creates `.mcs/conn.json`, which `pac copilot pull/push` needs |
| Playwright | `npm run auth` in `harness/layer2-playwright` | Records one Microsoft sign-in (`auth/maker.json`) for the UI tests |

## 1. Dataverse (Web API with an az token)

Header: `Authorization: Bearer <token>`, `Accept: application/json`, base `<org>/api/data/v9.2`.

- **Publisher and solution**: POST `publishers` (`customizationprefix`, `customizationoptionvalueprefix`) and POST `solutions`
  (`publisherid@odata.bind`). Add header `MSCRM.SolutionUniqueName: <solution>` to every later create so it lands in the solution.
- **Create a table**: POST `EntityDefinitions` with `@odata.type: Microsoft.Dynamics.CRM.EntityMetadata`, `SchemaName`,
  `DisplayName`, `DisplayCollectionName`, `OwnershipType: UserOwned` and `Attributes` holding the primary name column
  (`StringAttributeMetadata` with `IsPrimaryName: true`). Labels are `{ LocalizedLabels: [{ Label, LanguageCode: 1033 }] }`.
- **Add a column**: POST `EntityDefinitions(LogicalName='x')/Attributes` with the typed metadata (`StringAttributeMetadata`,
  `DecimalAttributeMetadata`, `IntegerAttributeMetadata`, `DateTimeAttributeMetadata` with `Format: DateOnly`,
  `BooleanAttributeMetadata`, or `PicklistAttributeMetadata` with explicit option `Value`s).
- **Add a lookup**: POST `RelationshipDefinitions` with `OneToManyRelationshipMetadata` (`ReferencedEntity`, `ReferencingEntity`,
  `Lookup` = `LookupAttributeMetadata`). The navigation property is the lookup's schema name. Then POST `PublishAllXml`.
  All of this is in `scripts/setup-environment.ps1`, driven by one table definition per table.

- **Tables and columns**: `EntityDefinitions(LogicalName='x')/Attributes?$select=LogicalName,AttributeType&$filter=IsCustomAttribute eq true`.
  `startswith()` is not supported on metadata; filter `IsCustomEntity eq true` and match the prefix client side.
- **Choice values**: `.../Attributes(LogicalName='tk_status')/Microsoft.Dynamics.CRM.PicklistAttributeMetadata?$expand=OptionSet`.
  Time Entry status: 495690000 Draft, 495690001 Submitted, 495690002 Approved, 495690003 Rejected.
- **Yes/No labels**: `.../Microsoft.Dynamics.CRM.BooleanAttributeMetadata?$expand=OptionSet` shows `TrueOption`/`FalseOption`.
  Trap: tables made by hand once had the labels swapped (value 1 labelled "False"), so `'Active (Projects)'.True` meant inactive
  in Power Fx. The setup script sets both labels explicitly. To fix an existing table: `UpdateOptionValue` for value 1 and 0, then `PublishXml`.
  After the fix, refreshing the data source in Studio rewrote formulas to keep the old *value*, so check `.True`/`.False` again.
- **Lookup navigation names** (for `@odata.bind`): `.../ManyToOneRelationships?$select=ReferencingAttribute,ReferencingEntityNavigationPropertyName`.
  Custom lookups use the schema name (`tk_Employee`); `botcomponent` uses `ParentBotComponentId`.
- **Filter by a lookup's column**: `tk_Employee/tk_email eq 'x'` works.
- **Date-only columns** with *User local* behaviour (`tk_workdate`) are stored as UTC (Central midnight = `05:00Z`).
  Compare them with UTC timestamps and convert to the local zone for display.

## 2. Solution components

- Tables: `pac solution add-solution-component --solutionUniqueName Timekeeper --component <logical name> --componentType 1 --AddRequiredComponents`.
- Agents: pac does not know the bot type. Look up types in `solutioncomponentdefinitions` (bot = 10227, botcomponent = 10228,
  connection reference = 10165) and call the Web API action `AddSolutionComponent` with `ComponentId`, `ComponentType`,
  `SolutionUniqueName`, `AddRequiredComponents`.
- A request with header `MSCRM.SolutionUniqueName: Timekeeper` creates the record inside the solution (used for flows and
  connection references).

## 3. Cloud flows (Web API, `scripts/setup-environment.ps1`)

- **Create**: POST `workflows` with `name`, `category: 5`, `type: 1`, `primaryentity: "none"`, `clientdata` = the JSON in `flows/`.
  **Turn on**: PATCH `statecode: 1, statuscode: 2`; this also validates the definition. **Update**: turn off, PATCH `clientdata`, turn on.
- `clientdata` = `{ properties: { connectionReferences, definition }, schemaVersion }`. Connection references point at existing
  connected references by logical name (`runtimeSource: embedded` = owner's connection, `invoker` = caller's).
- **One trigger per flow**: Power Apps (`Request` / `PowerAppV2`, reply with `Response` kind `PowerApp`) or agent
  (`Request` / `Skills`, reply kind `Skills`). The app and the agent therefore need two flows (`SubmitMyWeek`,
  `SubmitMyWeekAgent`) generated from the same steps.
- Actions after the `Response` keep running: we reply to the caller first and then wait for the Teams card.
- **Teams (connector `shared_teams`, poster "Flow bot", location "Chat with Flow bot")**:
  `PostCardToConversation` (`body/recipient`, `body/messageBody`), `PostCardAndWaitForResponse` (webhook;
  `body/body/messageBody`, `body/body/updateMessage`, `body/body/recipient/to`; answer in `body(...).data`),
  `PostMessageToConversation` (`body/recipient`, `body/messageBody` HTML).
- **Dataverse actions**: `ListRecords`, `GetItem` (`recordId`, `$select`, `$expand`), `UpdateOnlyRecord` (`item/<column>`).
- Reading other flows is the quickest way to get exact parameter names: GET `workflows?$select=name,clientdata&$filter=category eq 5`.
- **Human step**: adding a flow to the canvas app (Studio, Power Automate, Add flow). There is no API for it.

## 4. Canvas app (canvas-authoring MCP)

- `connect` → `sync_canvas` → edit `.pa.yaml` → `compile_canvas` (validates **and applies** to the live session, even when it fails).
  Sync into a scratch folder first and diff before overwriting local files. `sync_canvas` refuses a folder that holds anything
  other than `.pa.yaml` files (a stray `test-results/` blocked it).
- Discover before writing: `list_controls`, `describe_control` (exact properties and enum names), `list_data_sources`,
  `get_data_source_schema`. Finish with `get_accessibility_errors` and `get_appchecker_errors`.
- **Human step**: adding data sources (tables, flows). There is no MCP or pac command; pac `canvas pack/unpack` + solution
  import fights the live coauthoring session.
- YAML: a one-line formula containing `: ` must be a block scalar (`Prop: |-` then the formula on the next line).
- Power Fx traps we hit:
  - `App.OnStart` does not run in a coauthoring session: anything screens depend on (week start) belongs in named formulas.
  - `Date + 7` inside a Dataverse filter fails at runtime ("right side of LessThan can't be NULL"): use a DateTime and `DateAdd`.
  - `Sum()` of no rows is blank: wrap in `Coalesce(..., 0)`.
  - `Navigate` in `OnVisible` is rejected by the validator.
  - `IfError(Remove(...), Notify(...))` mixes types; use `Remove(...); If(!IsEmpty(Errors(ds)), Notify(...))`.
  - Data written by flows is not seen until `Refresh(ds)`: refresh on `OnVisible` and with a hidden repeating `Timer`.
  - Behaviour UDFs work in named formulas: `SignIn(email: Text): Void = { ... }`.
- Control traps: modern buttons derive their fill from `BasePaletteColor` and darken pastels (use `Appearance.Outline`);
  classic `Label` and `Classic/Button` have no `AccessibleLabel` (tests rely on it); hidden `Timer`s still need `TabIndex >= 0`.
- The app's play URL is in Dataverse: `canvasapps?$select=appopenuri&$filter=displayname eq 'Timekeeper App'`.

## 5. Copilot Studio agent (pac copilot + YAML)

- `scripts/sync-agent.ps1`: `pac copilot pull` then `pac copilot push`, plus `pac copilot publish --bot <id>` with `-Publish`.
  Check the pull did not undo local edits before pushing.
- **Tools** (`actions/*.mcs.yml`, `kind: TaskDialog`, `InvokeConnectorTaskAction`): `ManualTaskInput` fixes a value
  (Power Fx allowed, e.g. `="tk_employees(" & Global.EmployeeId & ")"`); `AutomaticTaskInput` lets the model fill it.
  Fix every dangerous input (who, status) manually. `connectionProperties.mode: Maker` uses the maker's connection.
  The Dataverse tools Copilot Studio supports are the "...in selected environment" actions (`ListRecordsWithOrganization`,
  `CreateRecordWithOrganization`, `UpdateOnlyRecordWithOrganization`); the plain `ListRecords`/`CreateRecord` break every tool call.
  Keep the environment out of source with an environment variable: `organization` = `=Env.tk_DataverseUrl`
  (definition + value created by `scripts/setup-environment.ps1`).
  `connectionreferences.mcs.yml` lists the references; create a missing one with POST `connectionreferences`
  (`connectionreferencelogicalname`, `connectorid`, `connectionid`).
- **Topic calling a flow**: `kind: InvokeFlowAction` with `flowId` and `input.binding` / `output.binding`; declare `outputType`
  so the orchestrator can use the result. The flow must have the agent (`Skills`) trigger.
- **Context from the app**: the app prefixes each message with `[User: ...; Employee: ...; Today: ...]`; an `OnActivity`
  topic parses it into globals. Unconditional rules (no context line → fixed reply) belong in the topic with `CancelAllDialogs`,
  not in the instructions.
- **App ↔ agent bridge**: Power Apps flow `AskTimekeeper` → Microsoft Copilot Studio `ExecuteCopilotAsyncV2`
  (`Copilot` = schema name, `x-ms-conversation-id`), replying `lastResponse` and `conversationId`. Needs the agent published.

## 6. Agent evaluation (Layer 1, `scripts/run-agent-evals.ps1`)

- A test set is stored as `botcomponents` with `componenttype = 19`:
  - the set: `data` = `kind: EvaluationSet` + `graders: [- kind: CompareMeaningGrader]`;
  - one row per case: `data` = `kind: EvaluationData`, `rows: [{source: Imported, expectedOutput, input}]`,
    `ParentBotComponentId@odata.bind = /botcomponents(<set id>)`.
  - Both need `category: Testing` and a `description`, plus `parentbotid@odata.bind` and `schemaname: mspva_<guid>`.
- `GeneralQualityGrader` ignores the expected answer and fails every correct refusal ("abstention"). Use `CompareMeaningGrader`
  (score 0–100) for tests with expected answers.
- Run: `pac copilot-studio run-maker-evaluation-test-set --bot-id <id> --test-set-id <id> --mcs-connection-id <Agent Evaluation connection>`
  returns `runId`. Without the connection the run is anonymous and an agent that requires sign-in won't answer.
  In 2.13.1, `--run-on-published-bot` and `--evaluation-run-name` return HTTP 500, so runs use the pushed draft.
- Poll `get-maker-evaluation-test-run --json` until `state` is `Completed`; `testCasesResults[].metricsResults[].result.status`.
  The agent's replies are not returned and evaluation chats are not saved as transcripts: read them in Copilot Studio (Evaluate tab).
- Evaluation is single turn: a "yes" case cannot follow a proposal. Use `TODAY` in questions; the script fills in today's date
  in the organisation time zone, because the model also reasons from the real clock.

## 7. The harness (one command)

`.\scripts\run-harness.ps1` → Layer 1 for every agent in `agents/`, Layer 2 (`npx playwright test`: theme, Dataverse API
contract, UI suites that type the persona's email on the sign-in panel), Layer 3 (`harness/reports/layer3.json`). It writes
`harness/reports/harness-summary.json`, exits 1 when anything is red, and ends with the go/no-go line.
UI test lessons: canvas screens fill in piece by piece (an empty state flashes before the data), so tests wait with
`settled()` until a value reads the same twice, 3 s apart, instead of checking once. Tests that create entries mark
them `PW-TEST` and the suite deletes them through the Web API afterwards. On Windows the recorder quotes the play URL,
because its `&` splits the command under `shell: true`. A person runs it after every feature (the `speckit-implement`
coordinator runs only Layer 2, with `npm test` and the token from `scripts/harness-env.ps1`). `-SkipAgentEvals` reuses the last Layer 1 result.

## 8. What still needs a human

Each of these is a 👤 task in `specs/001-timekeeper-core/tasks.md` and a step in `docs/setup.md`:

| Step | Why there is no automation |
|---|---|
| `az login`, `pac auth create`, `npm run auth` | Interactive Microsoft sign-in |
| Creating the Dataverse, Teams and Copilot Studio connections | OAuth consent in the browser. `pac connection create` only supports service principals |
| Creating the empty agent and cloning it once | The VS Code extension writes `.mcs/conn.json`, which `pac copilot pull/push` needs |
| Creating the blank canvas app, turning on coauthoring, adding data sources and flows | No API or MCP tool, and `pac canvas pack` plus solution import fights the live coauthoring session |
| Spec acceptance, plan approval, go/no-go (`scripts/publish-gate.ps1`) | Human gates (Constitution II) |
| Saving and publishing the canvas app; publishing the agent | Go/no-go belongs to a human (Constitution II) |
