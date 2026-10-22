# Research: Timekeeper Core

## Decision 1: Identity by email match
- **Decision** (revised 2026-10-20, Constitution 2.0.0): the user types their email on a sign-in panel; the app matches it (lower-cased) to `Employees.tk_email` and sends it to the agent in a context line with every message.
- **Rationale**: One Microsoft account can demo every persona (employee, manager, unregistered) by switching user; no extra accounts needed.
- **Risk**: anyone can type any registered email. Demo only; production uses Microsoft sign-in plus security roles.
- **Alternatives rejected**: An Entra object ID column (more robust, but needs an extra column and seeding); Dataverse security roles (correct for production, but too much setup for a demo; recorded in Complexity Tracking).

## Decision 2: Approval state on Time Entries (no approval table)
- **Decision**: `tk_status` (Draft / Submitted / Approved / Rejected) and `tk_approvercomment` live on each Time Entry.
- **Rationale**: Matches the tables already created; simpler queries; every decision is visible on the entry.
- **Alternatives rejected**: A separate approval table per week. It gives a better audit trail but doubles the queries for the demo.

## Decision 3: Canvas app authored by an AI agent through the canvas-authoring MCP server
- **Decision**: Use the `canvas-apps` plugin (microsoft/power-platform-skills) with Studio coauthoring; source kept in `canvasapp/`.
- **Rationale**: Lets the same Spec Kit flow drive canvas changes live in Studio; works with any agent that has the canvas-apps plugin (for example GitHub Copilot CLI).
- **Risks**: The preview server needs the Studio tab open, and sessions can drop. Mitigation: `sync_canvas` again after reconnecting; everything done so far is in `canvasapp/` and `tasks.md`.

## Decision 4: Agents use generative orchestration with Dataverse connector tools
- **Decision** (revised 2026-10-20): one agent, *Timekeeper*, uses Dataverse connector actions as tools whose dangerous inputs (employee, status) are fixed in the tool rather than chosen by the model; instruction-level guardrails for confirmation and refusals; the app reaches it through the `AskTimekeeper` flow (Microsoft Copilot Studio connector).
- **Alternatives rejected**: the canvas Chatbot control (can't pass the typed email); two agents (Constitution VII now allows one).
- **Rationale**: Fastest to build in Copilot Studio; behaviour is testable with Agent Evaluation test sets.
- **Alternatives rejected**: Fully authored topics for every intent (more work, less natural); Power Automate flows as tools (extra components with no demo value).

## Decision 5: Harness layers
- **Layer 1, agent evals**: Copilot Studio Agent Evaluation (generally available) test sets imported from `harness/layer1-agent-evals/*.csv`; results exported to `harness/reports/layer1-*.csv`.
- **Layer 2, Playwright + Web API**: Playwright drives the published app in the Power Apps web player (canvas iframe) using accessible labels; Dataverse Web API checks verify the schema contract the app relies on. Microsoft's open-source Power Platform Playwright toolkit can replace the hand-written iframe helpers. Power Apps Test Engine is deprecated (April 2026) and not used.
- **Layer 3, self-correct**: coordinator → implementor → verifier, at most 3 attempts per task (Constitution IV), with the verifier read-only.
- **Note on security tests**: Under the demo identity model, the Web API does NOT enforce per-user scoping (no security roles). Layer 2 therefore tests scoping through the UI, not the API. An API scoping test is added when security roles are introduced.

## Decision 6: Flows and dashboard are later priorities
- US5 and US6 (flows) and US7 (Power BI) are planned as P3 and P4; the core demo does not need them.
