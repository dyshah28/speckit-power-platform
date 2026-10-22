<!--
Sync Impact Report
- Version change: 2.0.0 → 2.1.0 (MINOR): Principle X Tenant Hands-Off added. Coding agents make no tenant
  changes; they only use the canvas-authoring MCP session and hand every az/pac/script command to the human.
  Governance check now covers I–X. Templates requiring updates: none. `.github/copilot-instructions.md` and
  `coordinator.agent.md` already state the rule. Deferred: plan 001 Constitution Check should list X.
- Version change: 1.0.1 → 2.0.0 (MAJOR): Principles V and VII redefined.
  - V Identity-Scoped Data: identity is now the email typed on the app's sign-in page (demo model, no
    password, "Signed in as" switcher), not the Microsoft account email.
  - VII Responsible AI: one agent replaces Employee Agent + Manager Agent; it may only add a time entry
    for the signed-in user, submit that user's entries and summarise that user's history.
  - Platform & Tooling: Copilot Studio line now names one agent; how the email reaches the agent is a plan decision.
  - VIII Source-Controlled: agents/ wording names `agents/<Agent Name>/` and `scripts/sync-agent.ps1`.
- Templates requiring updates: none. Dependent docs to follow (deferred): spec 001,
  `docs/copilot-studio-agents.md`, Layer 1 test sets, `.github/copilot-instructions.md`, `agents/README.md`.
- Version change: 1.0.0 → 1.0.1 (PATCH): the agent-tool wording no longer names a specific coding assistant; roles are defined in `.github/agents/`. No rule changed.
- Version change: template → 1.0.0 (initial ratification)
- Principles added: I Spec-First · II Human-Gated · III Solution-Contained · IV Validated Before Publish ·
  V Identity-Scoped Data · VI No Secrets in Source · VII Responsible AI · VIII Source-Controlled · IX Incremental
- Sections added: Platform & Tooling Constraints · Agent Workflow & Quality Gates · Governance
- Templates requiring updates: none (plan-template "Constitution Check" reads gates from this file)
-->

# Timekeeper Constitution

Timekeeper is a timesheet solution on Microsoft Power Platform (Dataverse, a Power Apps canvas app,
a Copilot Studio agent, Power Automate and Microsoft Teams). It is built and changed by AI coding agents
(for example GitHub Copilot) using GitHub Spec Kit. This constitution binds every agent and every human
contributor. When an artifact conflicts with a principle, the principle wins, and the agent MUST stop and
report the conflict instead of working around it.

## Core Principles

### I. Spec-First
No table, column, screen, flow, agent topic or tool is created or changed without an accepted `spec.md`
under `specs/NNN-*/`. Specs describe **what** and **why** in business language and MUST NOT name
technologies, controls or formulas. Technology first appears in `plan.md`. A defect fix that changes
behaviour MUST update the spec first, because a gap fixed only in code comes back the next time the code is
regenerated.

### II. Human-Gated (NON-NEGOTIABLE)
Three decisions belong to a human and are never self-approved by an agent:
1. **Spec acceptance**: a human reads `spec.md` and accepts it before planning.
2. **Plan approval**: `/speckit-tasks` MUST NOT run until `plan.md` contains the line `**Status**: Approved`,
   written by a human.
3. **Go / no-go**: only a human saves and publishes the canvas app, publishes an agent, or imports a solution.

When an agent reaches a gate it MUST print `HUMAN GATE: <gate name>` and stop.

### III. Solution-Contained
Every component (tables, canvas app, flows, agents, connection references, environment variables) lives
in the **Timekeeper** solution. The demo environment uses an unmanaged solution. Promotion to any other
environment MUST use a managed export of that solution, never manual re-creation.

### IV. Validated Before Publish
A change is "done" only when all of these hold, and the evidence is shown to the human at the go / no-go gate:
- **Canvas changes** compile cleanly through the canvas-authoring validator, with no blocking errors.
  Delegation warnings are allowed only if they are documented in `plan.md`.
- **Every acceptance scenario** in the spec has a PASS/FAIL verdict from an independent verifier
  (a separate agent or subagent that did not write the change and cannot edit files).
- **Agent changes** pass their Copilot Studio test set (agent evaluation), including every refusal case.

The self-correct loop is bounded: at most **3** fix attempts per task. When attempts run out, the agent
writes `harness-report.md` and stops at `HUMAN GATE: budget exhausted`.

### V. Identity-Scoped Data (demo identity model)
Identity is the **email address typed on the app's sign-in page**, matched to `Employees.tk_email`.
There is no password: this is a demo identity model. The app shows "Signed in as <email>" with a way to
switch user. Identity MUST NOT be taken from `User().Email`.
- An employee sees and changes only their own time entries.
- A manager sees only the entries of their **direct reports** (Employees whose Manager is that manager).
- No screen, query, agent answer or tool call may return another person's data outside these two rules.
- If the typed email matches no Employee row, the solution shows a clear "not registered" message
  and allows no data access.

*Demo scope*: scoping is enforced in the app formulas and agent instructions/tools, not by Dataverse
security roles, and a typed email is not authentication. Production deployments MUST replace it with
Microsoft sign-in and add Dataverse security roles and hierarchy security; that work is out of scope for this demo and MUST be listed under Assumptions in any spec that relies on it.

### VI. No Secrets in Source
No passwords, client secrets, tokens, tenant or environment IDs, connection strings or personal data
(other than seeded demo data) are committed. Use connection references, environment variables and the
signed-in user's identity.

### VII. Responsible AI
Timekeeper has **one** Copilot Studio agent. It acts only for the signed-in user and can do exactly
three things:
1. add a time entry for the signed-in user;
2. submit the signed-in user's entries;
3. summarise the signed-in user's timesheet history.

The agent MUST:
- show what it is about to write (project, date, hours, or which entries it will submit) and get an
  explicit "yes" before every write;
- never approve, reject, edit or delete any entry, for anyone;
- refuse any request about another person's data, or outside the three actions, politely and without
  confirming whether the other person exists;
- not invent projects, dates or numbers. When unsure, it asks.

### VIII. Source-Controlled
Specs, plans, tasks, the canvas app source (`canvasapp/*.pa.yaml`) and agent definitions
(`agents/<Agent Name>/`, cloned with the Copilot Studio VS Code extension) live in git. Agent changes are
synced with `scripts/sync-agent.ps1`, which always pulls before it pushes.
Agents MUST NOT edit `_EditorState.pa.yaml` except for screen ordering, and MUST NOT
edit generated Spec Kit files under `.specify/scripts` or `.specify/templates`.

### IX. Incremental
One feature per spec, one spec per folder, numbered sequentially. A change touches the smallest set of
components that satisfies its spec. There are no opportunistic refactors, and no features beyond the spec's
In Scope list.

### X. Tenant Hands-Off (NON-NEGOTIABLE)
A coding agent MUST NOT create, change, delete, import or publish anything in the tenant or environment.
It MUST NOT run `az`, `pac`, or any script that calls them (`setup-environment`, `sync-agent`,
`run-agent-evals`, `run-harness`, `harness-env`, `publish-gate`). It is allowed exactly these:
- edit files in the repo and run offline checks (`scripts/test-repo.ps1`, `npm test` in the Layer 2 project);
- work in the canvas-authoring MCP coauthoring session: read data sources and schema, `sync_canvas`, edit,
  `compile_canvas`. Saving and publishing the app stay with the human (Principle II).

For setup, agent sync, evals, the harness and the publish gate, the agent prints
`HUMAN GATE: run <exact existing script and arguments>`, stops, and continues from the output the human
pastes. It never asks for or handles passwords, tokens or other secrets.

## Platform & Tooling Constraints

- **Dataverse**: the publisher prefix is `tk_`. Tables: **Employees**, **Projects**, **Time Entries**,
  **Vacation Balances**. Approval state lives on Time Entries (`tk_status`, `tk_approvercomment`);
  there is no separate approval table. Agents MUST confirm real column names from the live schema
  (canvas-authoring `get_data_source_schema` or Dataverse metadata) before writing formulas or filters.
- **Canvas app**: *Timekeeper App*, edited only through the canvas-authoring MCP coauthoring session using
  the `canvas-apps` plugin skill. Run `sync_canvas` before edits and `compile_canvas` after edits. Before
  any sync that would overwrite local `canvasapp/` changes, the agent asks the human first.
- **Copilot Studio**: one agent in the Timekeeper solution, limited by Principle VII. It identifies the
  user by the same email as Principle V; how that email reaches the agent is decided in `plan.md`.
  Agent source is cloned to `agents/<Agent Name>/` with the Copilot Studio VS Code extension.
- **Model tiering**: use the strongest available model for specify, clarify and plan; a mid-tier model to
  implement; a fast model to verify.

## Agent Workflow & Quality Gates

`/speckit-specify` → (optional `/speckit-clarify`) → **HUMAN GATE: spec acceptance** → `/speckit-plan` →
**HUMAN GATE: plan approval** → `/speckit-tasks` → (optional `/speckit-analyze`) → `/speckit-implement`
(coordinator → implementor → verifier, bounded by Principle IV) → **HUMAN GATE: go / no-go** → the human
saves and publishes.

Agent roles are defined in `.github/agents/*.agent.md`. Any other agent tool that mirrors them follows the same
roles; if a copy diverges, this constitution decides.

## Governance

This constitution supersedes all other guidance in the repository. Amendments are made through a pull
request that updates this file, bumps the version (MAJOR: a principle removed or redefined; MINOR: a
principle or section added; PATCH: wording), and updates the Sync Impact Report. Every `plan.md`
MUST contain a Constitution Check against Principles I–X, and any violation MUST be justified in its
Complexity Tracking table or the plan is not approvable.

**Version**: 2.1.0 | **Ratified**: 2026-10-16 | **Last Amended**: 2026-10-22
