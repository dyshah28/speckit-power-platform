# Timekeeper — instructions for AI coding agents

This repository builds **Timekeeper** (a timesheet solution on Power Platform) with **GitHub Spec Kit**.
These instructions apply to GitHub Copilot (CLI and VS Code agent mode) working in this repo.

## Always
1. Read `.specify/memory/constitution.md` before any Spec Kit command. It overrides everything else, including these instructions.
2. Work only on the active feature in `.specify/feature.json` (`specs/NNN-*/`).
3. Respect the human gates. Print the gate line and stop:
   - after `speckit-specify` → `HUMAN GATE: spec acceptance`
   - before `speckit-tasks`, unless `plan.md` contains `**Status**: Approved` → `HUMAN GATE: plan approval`
   - after `speckit-implement` → `HUMAN GATE: final go/no-go`. Never save or publish the app or agents, and never enable environment features, yourself.
4. Tasks marked 👤 are for the human; don't attempt them.

## Spec Kit commands
`speckit-specify`, `speckit-clarify`, `speckit-plan`, `speckit-tasks`, `speckit-analyze`, `speckit-implement`
(skills in `.github/skills/`).

During `speckit-implement`, act as the **coordinator** in `.github/agents/coordinator.agent.md`. Delegate each
task to the **implementor** and check it with the **verifier** (read-only). Follow the bounded self-correct
loop in `harness/layer3-self-correct/README.md`, with at most 3 attempts per task.

## Platform facts
- Dataverse prefix **`tk_`**. Tables: Employees, Projects, Time Entries, Vacation Balances. Approval state is on Time Entries (`tk_status`, `tk_approvercomment`); there is no approval table. Confirm column names with `get_data_source_schema` and never guess.
- Identity is the signed-in **email**, matched to `Employees.tk_email` (`varMe`). Every query is scoped to `varMe` or `colDirectReports`.
- The canvas app is *Timekeeper App*, edited only through the **canvas-authoring MCP** coauthoring session with the `canvas-apps` plugin skill. Source is in `canvasapp/`. Run `sync_canvas` before edits (ask before overwriting local changes) and `compile_canvas` after.
- The UI uses the **"Soft Pastel Light"** theme in `specs/001-timekeeper-core/contracts/ui-theme.md`: light, calm, muted pastels, with colours only via the `Th*` named formulas in `App.Formulas` (no hex in screen files).
- Every interactive control has an `AccessibleLabel` from `specs/001-timekeeper-core/contracts/canvas-ui-contract.md`, because the Playwright tests depend on it.

## Environment setup
- Setup is `docs/setup.md`. The human runs every command that touches the environment. Never run `az`, `pac`, or the scripts that call them (`setup-environment`, `sync-agent`, `run-agent-evals`, `run-harness`, `harness-env`, `publish-gate`): print `HUMAN GATE: run <exact command>` and stop.
- Never ask for, accept or repeat passwords, tokens, secrets or `.env` contents.
- The environment always comes from the human's active pac profile. Never write an org URL, environment ID, tenant ID, connection ID or real email into the repo (Constitution VI).
- If `agents/Timekeeper/settings.mcs.yml` still says `__AGENT_SCHEMA__`, the agent is not bound yet: setup step 5 comes first.

## Agent sync
- Agent YAML: `agents/<Agent Name>/`, cloned with the Copilot Studio VS Code extension. After any edit there, print `HUMAN GATE: run .\scripts\sync-agent.ps1` (pull, then push). Never push without the pull. Publishing (`-Publish`) is the human's call.

## Harness (evidence for the go/no-go gate)
- You run Layer 2 with `npm test` in `harness/layer2-playwright`; the human keeps its `.env` token fresh with `.\scripts\harness-env.ps1`.
- The human runs everything else with one command, `.\scripts\run-harness.ps1`, at the end of every `speckit-implement`.
- Layer 1: `harness/layer1-agent-evals/<agent>-agent.csv`, synced to Copilot Studio and run by `scripts/run-agent-evals.ps1`
- Layer 2: `harness/layer2-playwright/` (UI suites + Dataverse API contract + theme)
- Layer 3: verifier verdicts plus `harness/reports/layer3.json`
- Then the human runs `.\scripts\publish-gate.ps1` for the go/no-go.
- How each Power Platform step is automated (pac, Web API, canvas MCP, flows, test sets): `docs/automation-playbook.md`.
- Never change a test to make it pass unless the spec changed.

## On a projector (demo)
Keep chat output short: what you're doing, which file you wrote, and the gate line.
