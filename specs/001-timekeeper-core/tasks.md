---
description: "Task list for Timekeeper Core"
---

# Tasks: Timekeeper Core

**Input**: Design documents from `/specs/001-timekeeper-core/`

**Prerequisites**: plan.md (Approved), spec.md, research.md, data-model.md, contracts/

**Tests**: Requested. Each user story has harness tasks (Layer 1 agent evals and/or Layer 2 Playwright), and every story closes with a Layer 3 verifier pass.

**Organization**: Tasks are grouped by user story. 👤 = a human does it; the coordinator prints `HUMAN GATE` and stops there. Phase 1 is the environment setup from `docs/setup.md`; do it once per environment.

## Format: `[ID] [P?] [Story] Description`

---

## Phase 1: Setup (docs/setup.md)

- [ ] T001 👤 Tools installed and signed in, az and pac as the same account, in a dedicated Developer environment: `az login --allow-no-subscriptions`, `pac auth create`, canvas-apps plugin in Copilot CLI (setup steps 2–3)
- [ ] T002 👤 Connections created in Power Automate: Microsoft Dataverse, Microsoft Teams, Microsoft Copilot Studio (setup step 4)
- [ ] T003 👤 Run `scripts/setup-environment.ps1`: publisher `tk`, solution *Timekeeper*, tables, seed data, environment variable, connection references (setup step 5)
- [ ] T004 👤 Create the empty *Timekeeper* agent in Copilot Studio and clone it with the Copilot Studio VS Code extension outside the repo (setup step 5)
- [ ] T005 👤 Re-run `scripts/setup-environment.ps1 -AgentClone <folder>`: flows, agent in the solution, agent YAML bound; then `scripts/sync-agent.ps1` (setup steps 5–6)
- [ ] T006 👤 Create the blank canvas app *Timekeeper App* in the solution (tablet, modern controls, coauthoring), add the four tables and the `AskTimekeeper` and `SubmitMyWeek` flows, save, and connect the canvas-authoring MCP session (setup steps 7–8)
- [ ] T007 [P] Install the Layer 2 test project (`npm install`, `npx playwright install chromium`) record one Microsoft sign-in with `npm run auth`, and write the short-lived `.env` token with `scripts/harness-env.ps1` (👤 sign-in and script, setup step 9)

---

## Phase 2: Foundational (blocks all stories)

- [ ] T008 Tables Employees, Projects, Time Entries, Vacation Balances and seed data per data-model.md (created by T003)
- [ ] T009 Confirm the logical names with `get_data_source_schema` and correct data-model.md and `contract.config.json` if any differ
- [ ] T010 [P] Layer 2: `theme-contrast` suite green (palette contrast, pastel softness) and API contract check green
- [ ] T011 Theme: define all "Soft Pastel Light" tokens as named formulas in `App.Formulas` per contracts/ui-theme.md and plan.md Design Decision 8 (canvasapp/App.pa.yaml)
- [ ] T012 App.OnStart / sign-in: identity from the typed email (`varMeEmail` → `varMe`), week range, active projects, direct reports (canvasapp/App.pa.yaml, Screen1 sign-in panel)

**Checkpoint**: Data, identity and theme ready. Every screen built after this uses theme tokens only.

---

## Phase 3: User Story 1 - Log my time in the app (P1) 🎯 MVP

### Tests (Layer 2)
- [ ] T013 [P] [US1] Playwright `tests/us1-log-time.spec.ts`: AC1–AC4, AC6–AC8 plus greeting and week progress visible
- [ ] T014 [P] [US1] Playwright `tests/unregistered.spec.ts`: AC5 (typed unregistered email)

### Implementation
- [ ] T015 [US1] Sign-in panel + Log Time screen shell: app bar with greeting, "Signed in as", Sign out, nav; week summary card; "This week" list; entry form (canvasapp/Screen1.pa.yaml)
- [ ] T016 [US1] "This week" cards: project dot, project, date, hours, status chip, rejection comment; empty state
- [ ] T017 [US1] Entry form validation (0.25–12 step 0.25; day cap 24; active projects only)
- [ ] T017a [US1] Edit Draft/Rejected entries (Rejected → Draft), delete Draft entries (AC6–AC7)
- [ ] T018 [US1] Submit week: Draft → Submitted; Submitted/Approved read-only
- [ ] T019 [US1] Not-registered panel when `varMe` is blank (AC5)
- [ ] T020 [US1] AccessibleLabels per contracts/canvas-ui-contract.md
- [ ] T021 [US1] Compile clean → verifier PASS on AC1–AC8 → **HUMAN GATE**: save and publish

## Phase 4: User Story 2 - Approve my team's time in the app (P1)

- [ ] T022 [P] [US2] Playwright `tests/us2-approvals.spec.ts`: AC1–AC3
- [ ] T023 [US2] Approvals screen with pending cards and empty state (canvasapp/Approvals.pa.yaml)
- [ ] T024 [US2] Approve / Reject with required comment; stale-status check before writing
- [ ] T025 [US2] Rejection comment shown on Log Time; Rejected editable (AC4)
- [ ] T026 [US2] Hide "Go to Approvals" without direct reports (AC5)
- [ ] T027 [US2] AccessibleLabels per contract
- [ ] T028 [US2] Compile clean → verifier PASS on AC1–AC5 → **HUMAN GATE**: save and publish

## Phase 5: User Story 3 - Ask the Timekeeper assistant (P2)

- [ ] T029 [P] [US3] Layer 1 test set `harness/layer1-agent-evals/timekeeper-agent.csv` (replaces employee/manager sets)
- [ ] T030 [US3] Agent instructions + topic *Read user context* + Dataverse tools per contracts/agent-contracts.md (agents/Timekeeper/)
- [ ] T031 [US3] Flow definition `flows/AskTimekeeper.json`
- [ ] T031a [US1][US3] Flows `SubmitMyWeek` (app) and `SubmitMyWeekAgent` (agent): submit this week's drafts + Teams card to the manager (FR-012); agent topic *Submit my week* replaces the row-id Submit tool
- [ ] T031b 👤 Add the `SubmitMyWeek` flow to the app in Studio (Power Automate → Add flow)
- [ ] T032 [US3] Assistant screen (canvasapp/Assistant.pa.yaml)
- [ ] T033 👤 [US3] `scripts/sync-agent.ps1` (pull, then push); review in Copilot Studio; run the test set → **HUMAN GATE**: publish the agent

## Phase 6: User Story 4 - Approve by chatting (Removed by Constitution 2.0.0)

---

## Phase 7: User Story 5 - Friday reminder (P3)

- [ ] T040 [US5] Scheduled cloud flow *Friday Reminder* (Fri 3 PM): per active employee, sum the week's hours and post a Teams message if below capacity
- [ ] T041 [US5] Manual test with seeded data (Priya 17/40 gets a message, Alex 40/40 doesn't)

## Phase 8: User Story 6 - Approval card in Teams (P3)

- [ ] T042 [US6] (built inside the SubmitMyWeek flows: card + wait for response, per-entry stale check) Automated flow on Time Entry status → Submitted (batched per employee and week): post an adaptive card with Approve/Reject (comment required) to the manager
- [ ] T043 [US6] Manual test of approve and reject paths

## Phase 9: User Story 7 - Leadership dashboard (P4)

- [ ] T044 [US7] Power BI report on Dataverse: utilization (approved ÷ capacity) and burn (approved ÷ budget), hourly refresh

---

## Phase 10: Polish & Cross-Cutting

- [ ] T044a Fresh data after flows: refresh on Log Time open + 30 s timers on Log Time and Approvals (plan Decision 13)
- [ ] T044b One-command harness with automated agent evaluation; coordinator runs it after every implement (plan Decision 14)

- [ ] T045 Application Insights connected to the agent
- [ ] T046 👤 `scripts/run-harness.ps1` green on all layers → `scripts/publish-gate.ps1`
- [ ] T047 Try feature 002 yourself: `prompts/002-live-requirement.md` (a reference result is in `examples/002-vacation-balance/`)

## Dependencies

- Phase 2 blocks everything. US1 and US2 share App.OnStart (T015) but are otherwise independent.
- US3 depends on Phase 2 data and the published agent. US5 and US6 depend on US1 statuses. US7 depends on US2 approvals.
