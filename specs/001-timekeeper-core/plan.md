# Implementation Plan: Timekeeper Core

**Branch**: `001-timekeeper-core` | **Date**: 2026-10-16 (revised 2026-10-20 for Constitution 2.0.0) | **Spec**: [spec.md](./spec.md)

**Status**: Approved

**Input**: Feature specification from `/specs/001-timekeeper-core/spec.md`

## Summary

Build Timekeeper on Power Platform. Dataverse holds four tables, which already exist. A canvas app covers
logging, approvals and an assistant chat, on three screens plus a sign-in panel (US1, US2, US3). One Copilot
Studio agent, *Timekeeper*, backs the assistant; the app reaches it through the `AskTimekeeper` flow. Power
Automate later handles the Friday reminder and the Teams approval card (US5, US6). A Power BI report serves
leadership (US7). Identity is the email typed on the sign-in panel, matched to `Employees.tk_email`
(Constitution V). US4 is removed (Constitution VII). Quality is enforced by a three-layer harness: agent evals, Playwright UI tests with
Dataverse API contract checks, and a bounded self-correct loop with an independent verifier.

## Technical Context

**Language/Version**: Power Fx (canvas app, `.pa.yaml` source); Copilot Studio YAML (agents); TypeScript 5 for tests

**Primary Dependencies**: Dataverse; Power Apps canvas (modern controls); Copilot Studio (generative orchestration, Dataverse connector tools); Power Automate (`AskTimekeeper` instant flow with the Microsoft Copilot Studio connector; later Teams flows); Power BI; canvas-authoring MCP server and the `canvas-apps` plugin (microsoft/power-platform-skills)

**Storage**: Dataverse tables Employees, Projects, Time Entries, Vacation Balances (prefix `tk_`). See [data-model.md](./data-model.md)

**Testing**: Layer 1 Copilot Studio Agent Evaluation test sets (`harness/layer1-agent-evals/`); Layer 2 Playwright (`harness/layer2-playwright/`) for the canvas UI plus Dataverse Web API contract checks; Layer 3 coordinator → implementor → verifier loop (`harness/layer3-self-correct/`)

**Target Platform**: Power Apps web player and Microsoft Teams (desktop and web)

**Project Type**: Low-code business solution (canvas app + agents + flows) with source in git

**Performance Goals**: Screens load in under 3 s with demo data; agent replies in under 5 s

**Constraints**: Demo identity model (email match, no security roles); delegation warnings acceptable only at demo scale and documented below

**Scale/Scope**: Demo scale: 8 employees, 8 projects, under 100 time entries; 3 screens, 1 agent, 1 flow now (2 more later), 1 report

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How this plan complies |
|---|---|---|
| I Spec-First | ✅ | Every task in tasks.md cites a user story; no component is outside spec scope |
| II Human-Gated | ✅ | This plan carries `Status: Approved` from a human; the human saves and publishes the app and agents |
| III Solution-Contained | ✅ | App, agents, flows and tables live in the *Timekeeper* solution |
| IV Validated Before Publish | ✅ | Canvas compile clean + Playwright US1/US2 suites green + agent test sets green + verifier PASS on every acceptance scenario |
| V Identity-Scoped Data | ✅ (demo model) | `varMe` resolves from the typed email (never `User().Email`); every Items/Filter is scoped to `varMe` or `colDirectReports`; the app sends `[User: email; …]` with each chat message and the agent's tools filter by that email |
| VI No Secrets | ✅ | Connection references; test credentials only in a local `.env` (git-ignored) |
| VII Responsible AI | ✅ | One agent with exactly three tools' worth of actions (list, add entry, submit = set Status Submitted only); confirmation and refusals in instructions; no delete tool exists; covered by Layer 1 refusal cases |
| VIII Source-Controlled | ✅ | `canvasapp/`, `agents/`, `specs/`, `harness/` in git |
| FR-015–019 Look & feel | ✅ | Theme tokens in App.Formulas only; contrast + no-hex enforced by `theme-contrast.spec.ts` |
| IX Incremental | ✅ | Delivered by priority: P1 (US1–US2) → P2 (US3–US4) → P3 (US5–US6) → P4 (US7) |

## Project Structure

### Documentation (this feature)

```text
specs/001-timekeeper-core/
├── plan.md              # This file
├── research.md          # Decisions and alternatives
├── data-model.md        # Dataverse tables and columns
├── quickstart.md        # How to run and verify the feature
├── contracts/
│   ├── dataverse-schema.md     # Columns the app, agents, flows and tests depend on
│   ├── canvas-ui-contract.md   # Screens + accessible labels (Playwright depends on these)
│   ├── ui-theme.md             # "Soft Pastel Light" theme tokens, typography, composition
│   └── agent-contracts.md      # Agent tools, confirmation and refusal behaviour
├── checklists/requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
canvasapp/                    # Canvas app source synced via canvas-authoring MCP
├── App.pa.yaml
├── Screen1.pa.yaml           # Log Time screen + sign-in panel (key kept as Screen1)
├── Approvals.pa.yaml
└── Assistant.pa.yaml         # Chat with the Timekeeper agent
agents/                       # Cloned with the Copilot Studio VS Code extension
└── Timekeeper/               # actions/ (Dataverse tools), topics/, agent.mcs.yml
flows/                        # Flow definitions: AskTimekeeper (US3); US5/US6 later
harness/
├── layer1-agent-evals/       # Test sets per agent (YAML source + CSV for import)
├── layer2-playwright/        # Playwright project: UI suites + Dataverse API contract checks
├── layer3-self-correct/      # Loop rules + verifier report format
└── reports/                  # Generated; git-ignored
scripts/                      # PowerShell: setup-environment, sync-agent, run-harness, run-agent-evals, publish-gate
```

**Structure Decision**: This is a low-code solution with source-controlled artifacts per component type.
Business logic lives in Power Fx and agent instructions. TypeScript exists only for tests.

## Design Decisions (summary; details in research.md)

1. **Identity**: the app opens on a sign-in panel (on `Screen1`). Continue sets `varMeEmail` from the typed email and `varMe = LookUp(Employees, tk_email = varMeEmail)` (seed emails are lower case; the typed email is lower-cased). Blank `varMe` shows the "not registered" panel. The app bar shows "Signed in as" with Sign out. The agent gets the email from the app's context line (Decision 10), not from Microsoft sign-in.
2. **Direct reports**: `ClearCollect(colDirectReports, Filter(Employees, tk_manager.tk_employeeid = varMe.tk_employeeid))`, then filter Time Entries by that collection (documented delegation warning; fine at demo scale).
3. **Validation**: Power Fx guards before `Patch`: hours range and step, the 24-hour daily cap, and active projects only.
4. **Week**: named formulas, not OnStart variables (OnStart does not run during coauthoring): `WeekStart = Today() - Weekday(Today(), StartOfWeek.Monday) + 1` and `WeekStartTime` (the same as a DateTime). `MyWeek` filters `tk_workdate >= WeekStartTime && < DateAdd(WeekStartTime, 7, Days)`, because `Date + 7` does not translate into a Dataverse filter. `WeekTotal = Coalesce(Sum(MyWeek, tk_hours), 0)`.
5. **Approvals**: `Patch` status to Approved or Rejected. Rejection requires a non-blank comment.
6. **Testability**: every interactive control sets `AccessibleLabel` exactly as listed in `contracts/canvas-ui-contract.md`. Playwright locates controls by those labels.
7. **Agent**: one agent, generative orchestration, Dataverse connector tools reusing the existing Dataverse connection: *My entries* (List rows, Time Entries filtered by the context email's employee), *Active projects* (List rows, `tk_active eq true`), *Add my entry* (Add a new row; Employee bound from the context email, Status forced to Draft), *Submit my week* (topic calling flow `SubmitMyWeekAgent` with `Global.EmployeeId`; no model input). There is no delete tool, no write tool that takes a row id, and no tool that can write Approved/Rejected. Instructions enforce confirmation, scoping and refusals.
8. **Theme ("Soft Pastel Light")**: define every token from `contracts/ui-theme.md` once in `App.Formulas` as named formulas, e.g.
   ```text
   ThBg = ColorValue("#F7F8FC"); ThSurface = ColorValue("#FFFFFF"); ThSurfaceAlt = ColorValue("#F1F2F9");
   ThBorder = ColorValue("#DADDEA"); ThAppBar = ColorValue("#E9E8F8"); ThPrimary = ColorValue("#5F66B8");
   ThOnPrimary = ColorValue("#FFFFFF"); ThPrimarySoft = ColorValue("#E6E8F7"); ThFocus = ColorValue("#7A80D0");
   ThInk = ColorValue("#2E3142"); ThInkMuted = ColorValue("#5B6075"); ThError = ColorValue("#A3364A");
   ThChipSky = ColorValue("#DDEBF7"); ThChipSkyInk = ColorValue("#2F5A80"); …(peach, mint, rose, butter)
   ThStatusFill(s) / ThStatusInk(s) = Switch(s, "Draft", ThChipSky, "Submitted", ThChipPeach, "Approved", ThChipMint, ThChipRose)
   ```
   Screens reference only these names (Fill, Color, BorderColor, and the modern controls' base palette/appearance
   properties; confirm exact property names with `describe_control`). Screen files contain **no hex values**;
   the Layer 2 `theme-contrast` suite enforces this and the palette's contrast.
9. **Friendly UI**: greeting from `Hour(Now())` and the first word of `varMe.'Full Name'`; week progress =
   week total ÷ `varMe.'Weekly Capacity Hours'` (capped at 100%); pastel status chips; project colour dots;
   empty-state messages per `contracts/ui-theme.md`.
10. **App ↔ agent bridge**: instant flow `AskTimekeeper(message, conversationId)` → Microsoft Copilot Studio *Execute Agent and wait* (the agent's schema name, filled in by `scripts/setup-environment.ps1`) → returns `reply`, `conversationid`. The Assistant screen prefixes each message with `[User: <email>; Employee: <id>; Today: yyyy-mm-dd (dddd)]`; topic *Read user context* stores `Global.UserEmail` and `Global.EmployeeId`, which the tools use, and answers "Please open me from the Timekeeper app." when there is no context line. Works only after the agent is published (human gate).
11. **Edit/delete (US1 AC6–AC7)**: selecting a Draft/Rejected row loads it into the form (`locEdit`); Save patches that row (Rejected → Draft) after re-reading its status; Delete is offered for Draft rows only and also re-reads the status first.
12. **Submit + manager card (FR-012, US6)**: flows `SubmitMyWeek` (Power Apps trigger, used by Submit week) and `SubmitMyWeekAgent` (agent trigger) have identical steps: get the employee and manager, list this week's Draft entries (week = Monday 00:00 Central), set each to Submitted, return `submitted`, `hours`, `manager` to the caller, then post an Adaptive Card from Flow bot to the manager's email in Teams and wait: *Approve week* / *Reject week* plus a comment box. The decision is applied to the entries submitted in that run that are still Submitted (stale check per entry); Reject without a comment changes nothing and Flow bot tells the manager to use the Approvals screen. Two flows because a flow has one trigger.
13. **Fresh data after flows**: changes made by the flows (Teams decisions, assistant writes) are not seen until the app re-reads. Log Time refreshes Time Entries on `OnVisible`; Log Time and Approvals each have a hidden repeating 30-second `Timer` that calls `Refresh('Time Entries')` while signed in.
14. **Harness, one command** (`scripts/run-harness.ps1`, run by the human after every implement; the coordinator runs only Layer 2 with `npm test`): Layer 1 syncs `harness/layer1-agent-evals/<agent>-agent.csv` into a Copilot Studio test set (compare-meaning grader) and runs it with pac; Layer 2 runs Playwright (theme, Dataverse API contract, UI suites that type each persona's email); Layer 3 reads the verifier result. Mechanics in `docs/automation-playbook.md`.

## Known Delegation Warnings (accepted at demo scale)

- `Filter('Time Entries', tk_employee.tk_employeeid in colDirectReports.tk_employeeid, …)`: non-delegable `in`. Acceptable for under 500 rows.
- `LookUp(Employees, Lower(tk_email) = …)`: `Lower()` is non-delegable. Acceptable for under 500 employees.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Data scoping in app/agent instead of Dataverse security roles (Principle V demo model) | Demo must run with simple email sign-in and no admin role setup | Security roles need admin configuration per test user; recorded as a production requirement |
| Extra flow `AskTimekeeper` between app and agent | The canvas Chatbot control can't pass the typed email to the agent | Chatbot control would use the Microsoft account, which breaks Principle V's typed-email identity |
| Two submit flows with the same steps (`SubmitMyWeek`, `SubmitMyWeekAgent`) | A flow has exactly one trigger: Power Apps for the app, agent for Copilot Studio | A child flow shared by both needs extra connection setup for run-only users; the two JSON files differ only in trigger and response kind |
| Agent identity comes from the context line (**accepted by the user, 2026-10-20**) | Typed-email demo identity (Principle V) has no token to pass | The agent is not published to Teams or any other channel; it is reached only through `AskTimekeeper`. Same trust level as the app's sign-in |
