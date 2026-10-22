# Feature Specification: Timekeeper Core

**Feature Branch**: `001-timekeeper-core`

**Created**: 2026-10-16

**Status**: Accepted (human gate 1; re-accepted by the user on 2026-10-20 for Constitution 2.0.0) · US1–US3 being built · US4 removed · US5–US7 planned

**Input**: User description: "Timesheets for employees and managers. Employees log hours against projects
from an app or by chatting with an agent, and submit their week. Managers approve or reject in the app,
in chat, or from a Teams card. Everyone gets a Friday reminder if their week is incomplete. Leadership sees
utilization and project burn. Sign-in is simply the person's work email."

**Amended 2026-10-20 (Constitution 2.0.0)**: the person types their email on a sign-in page (no password, demo
only). There is one assistant, inside the app, which can only add time, submit time and summarise history for
the signed-in person. Chat approvals (US4) are removed.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log my time in the app (Priority: P1)

An employee opens Timekeeper, types their work email, picks a project, a date in the current week and a
number of hours, and saves the entry. They see their entries for this week and the week total, can change or
delete an entry that is still Draft or Rejected, and can submit the week for approval.

**Why this priority**: Without recorded hours nothing else in the product has value. This is the MVP.

**Independent Test**: Sign in as a test employee, log three entries across two projects, check the weekly
total, and submit the week. The entries appear with status Submitted and can no longer be edited.

**Acceptance Scenarios**:

1. **Given** an employee with no entries this week, **When** they log 8 hours to "Contoso Migration" for Monday, **Then** the entry appears in "This week" with status Draft and the week total shows 8.
2. **Given** an employee, **When** they try to log 13 hours in one entry, or 0 hours, **Then** saving is blocked with a message that an entry must be between 0.25 and 12 hours in 0.25-hour steps.
3. **Given** an employee who already has 20 hours on Tuesday, **When** they add another 6 hours on Tuesday, **Then** saving is blocked because a day cannot exceed 24 hours.
4. **Given** an employee with Draft entries, **When** they submit the week, **Then** all of that week's Draft entries become Submitted and are read-only.
5. **Given** a typed email that matches no employee, **When** the person continues, **Then** the app shows "You're not registered in Timekeeper. Contact your manager." and shows no data.
6. **Given** a Draft or Rejected entry, **When** the employee changes its hours and saves, **Then** the entry shows the new hours, the same validation as AC2–AC3 applies, and a Rejected entry goes back to Draft.
7. **Given** a Draft entry, **When** the employee deletes it, **Then** it disappears from "This week" and the week total drops. Submitted and Approved entries offer no change or delete.
8. **Given** a signed-in person, **When** they choose "Sign out" or switch user, **Then** the sign-in page shows again and no previous person's data stays on screen.

---

### User Story 2 - Approve my team's time in the app (Priority: P1)

A manager opens the Approvals screen, sees submitted entries from their direct reports only, and approves
or rejects each one. A rejection needs a comment. A rejected entry becomes editable again for the employee.

**Why this priority**: Logged time is only useful once a manager has approved it. Together with US1 this
forms a complete minimum product.

**Independent Test**: Sign in as the manager. Approve one of Priya's submitted entries, and try to reject
another without a comment (blocked), then with a comment (allowed). Then sign in as Priya and confirm the
rejected entry is editable and shows the comment.

**Acceptance Scenarios**:

1. **Given** a manager with two direct reports who have submitted entries, **When** they open Approvals, **Then** they see only those reports' Submitted entries and nobody else's.
2. **Given** a submitted entry, **When** the manager approves it, **Then** its status becomes Approved and it leaves the pending list.
3. **Given** a submitted entry, **When** the manager rejects it without a comment, **Then** rejection is blocked until a comment is entered.
4. **Given** a rejected entry, **When** the employee views their week, **Then** the entry shows Rejected with the manager's comment and can be edited and resubmitted.
5. **Given** a user with no direct reports, **When** they use the app, **Then** the Approvals screen is not offered.

---

### User Story 3 - Ask the Timekeeper assistant (Priority: P2)

On the Assistant screen of the app, the signed-in employee chats with the Timekeeper assistant. It can do
exactly three things for that person: add a time entry ("log 3 hours to Contoso migration yesterday"), submit
their entries ("submit my week"), and summarise their timesheet history ("what did I log last week?"). It shows
what it is about to write and saves only after the employee says yes. It never approves, rejects, changes or
deletes an entry.

**Why this priority**: Removes friction for quick entries, and is the headline agentic experience, but the
app alone already delivers the core value.

**Independent Test**: Signed in as Priya, ask the assistant to log time, confirm, and check that the entry
appears on Log Time. Ask it to submit the week, confirm, and check the statuses. Then ask about Alex's hours,
and ask it to approve or delete an entry: it refuses both.

**Acceptance Scenarios**:

1. **Given** an employee chatting with the assistant, **When** they say "log 3 hours to Contoso migration yesterday", **Then** the assistant replies with project, date and hours and asks for confirmation before saving.
2. **Given** the confirmation prompt, **When** the employee says "no" or changes a value, **Then** nothing is saved until a corrected version is confirmed.
3. **Given** an ambiguous project name matching two projects, **When** the employee asks to log time, **Then** the assistant asks which project they mean.
4. **Given** any employee, **When** they ask "how many hours did Priya log last week?", **Then** the assistant politely refuses and does not reveal whether Priya exists.
5. **Given** an employee, **When** they ask "what have I logged this week?", **Then** the assistant lists only their own entries with a total.
6. **Given** an employee with Draft entries this week, **When** they say "submit my week", **Then** the assistant lists the entries it will submit and the total, and only after a yes they become Submitted.
7. **Given** any employee, **When** they ask the assistant to approve, reject, change or delete an entry, **Then** it refuses and points to the app screens.
8. **Given** the assistant, **When** a request uses the same validation rules as the app (hours range, 24-hour day, active projects), **Then** the assistant applies them before asking for confirmation.

---

### User Story 4 - Approve by chatting (Removed)

Removed on 2026-10-20 by Constitution 2.0.0 (Principle VII): the assistant never approves or rejects.
Approvals happen only on the Approvals screen (US2).

---

### User Story 5 - Friday reminder (Priority: P3)

Every Friday at 3 PM, each employee whose logged hours for the week are below their weekly capacity receives
a Teams message with their total and a link to Timekeeper.

**Why this priority**: Improves completeness but depends on US1 and is not needed for a first demo.

**Independent Test**: Run the reminder manually for a week where Priya has 17 hours and Alex has 40, and
confirm only Priya receives a message showing "17 of 40 hours".

**Acceptance Scenarios**:

1. **Given** Friday 3 PM and an employee below capacity, **When** the reminder runs, **Then** they receive one Teams message with their total, their capacity and a link to the app.
2. **Given** an employee at or above capacity, **When** the reminder runs, **Then** they receive nothing.

---

### User Story 6 - Approval request in Teams (Priority: P3, built 2026-10-20)

When an employee submits their week (in the app or through the assistant), their manager receives a Teams card
listing the submitted entries and the total, with a comment box and *Approve week* / *Reject week*. The decision
applies to every entry of that submission that is still Submitted. A rejection needs a comment.

**Why this priority**: Convenient, but US2 already covers approvals in the app.

**Independent Test**: Submit Priya's week, act on the card as the manager, and confirm all of that week's
entries change status.

**Acceptance Scenarios**:

1. **Given** an employee submits a week, **When** submission completes, **Then** their manager receives one card for that week listing each submitted entry and the total hours.
2. **Given** the card, **When** the manager rejects without a comment, **Then** nothing changes and the manager is told in Teams that a rejection needs a comment and to use the Approvals screen.
3. **Given** the card, **When** the manager approves, **Then** every entry of that submission becomes Approved and the card confirms the decision was recorded.
4. **Given** the card, **When** the manager rejects with a comment, **Then** every entry of that submission becomes Rejected with that comment, and the employee sees it on Log Time.
5. **Given** an entry of that submission was already decided in the app, **When** the manager answers the card, **Then** that entry keeps its existing decision.
6. **Given** a decision made in Teams, **When** the employee or manager has the app open, **Then** the new status shows within 30 seconds, or at once when the screen is opened.

---

### User Story 7 - Leadership dashboard (Priority: P4)

Leadership sees utilization (approved hours ÷ capacity) per employee and per week, and burn (approved hours
÷ budget) per project.

**Why this priority**: Valuable reporting, but it only needs data that US1 and US2 already produce.

**Independent Test**: With seeded approved entries, the dashboard shows Contoso Migration burn as approved
hours ÷ 400 and Priya's utilization for the week.

**Acceptance Scenarios**:

1. **Given** approved entries, **When** leadership opens the dashboard, **Then** utilization and burn reflect approved hours only.
2. **Given** a new approval, **When** the dashboard next refreshes (at most hourly), **Then** the numbers include it.

---

### Edge Cases

- A signed-in email with different capitalization from the stored email still matches (case-insensitive).
- An employee who is also a manager sees both their own week and their team's approvals.
- A manager whose direct report has no entries this week sees that report in "who hasn't submitted" but not in the pending list.
- Inactive projects cannot receive new entries but still show on existing entries.
- A week spans Monday to Sunday in the organization's time zone. Entries dated outside the current week are not editable from the "This week" view.
- The same entry is decided twice at once (two app sessions), or the assistant submits an entry the app is editing: the second action sees that the entry is no longer Submitted and reports that, instead of overwriting.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST identify the user by the work email they type on the sign-in page (no password, demo only), matched case-insensitively to a registered employee, and MUST deny all data access to unregistered users. The current person is always visible ("Signed in as") and can sign out or switch.
- **FR-002**: Employees MUST be able to create time entries with project, date, hours (0.25–12, in 0.25 steps) and optional notes.
- **FR-003**: The system MUST prevent total hours on a single day from exceeding 24 for one employee.
- **FR-004**: Only active projects MUST be selectable for new entries.
- **FR-005**: Employees MUST be able to submit all Draft entries of the current week. Submitted and Approved entries MUST be read-only to the employee. Draft and Rejected entries MAY be changed; Draft entries MAY be deleted.
- **FR-006**: Managers MUST see and decide only on Submitted entries of their direct reports.
- **FR-007**: Rejections MUST include a comment. Approvals MUST NOT require one.
- **FR-008**: Rejected entries MUST become editable again and display the rejection comment.
- **FR-009**: Users MUST NOT be able to view or change another person's entries, except a manager acting on direct reports' submitted entries.
- **FR-010**: The assistant MUST only add an entry, submit entries, or summarise history for the signed-in person; MUST confirm every write before saving; MUST refuse requests about other people's data; and MUST never approve, reject, change or delete an entry.
- **FR-011**: The system MUST remind under-capacity employees every Friday at 3 PM local time.
- **FR-012**: On week submission (app or assistant), the employee's manager MUST be notified in Teams with a summary of the submitted entries. Making the card actionable is US6.
- **FR-013**: Leadership reporting MUST use approved hours only.
- **FR-014**: Each employee MAY have a vacation balance per year. This feature stores but does not display it (reserved for a later feature).

### Look & Feel Requirements

- **FR-015**: The app MUST use a calm, modern, light visual style with soft pastel accents: never dark, never neon or saturated, never pure black text.
- **FR-016**: Every status MUST be recognisable at a glance by a consistent soft colour and a text label (colour is never the only signal).
- **FR-017**: All text MUST remain comfortably readable on every background (at least WCAG 2.1 AA contrast).
- **FR-018**: The app MUST feel friendly and personal: greet the user by first name, show progress toward their weekly hours, and use encouraging empty-state messages instead of blank areas.
- **FR-019**: The same visual language (colours, shapes, spacing, type sizes) MUST apply across all screens and future features.

### Key Entities

- **Employee**: a person who logs time; has name, work email (identity), manager (another Employee), weekly capacity in hours and an active flag.
- **Project**: work that time is logged against; has name, code, client, budget hours and an active flag.
- **Time Entry**: hours one employee worked on one project on one date; has hours, notes, status (Draft, Submitted, Approved, Rejected) and an approver comment.
- **Vacation Balance**: an employee's vacation hours for one year (accrued, used, remaining). Stored only in this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An employee can log a day's time (3 entries) in under 2 minutes in the app, or under 30 seconds per entry in chat.
- **SC-002**: A manager can clear 10 pending entries in under 3 minutes.
- **SC-003**: Zero cases in testing where a user sees or changes another person's data outside FR-006 and FR-009.
- **SC-004**: 100% of rejection attempts without a comment are blocked.
- **SC-005**: 100% of agent write actions are preceded by an explicit user confirmation in test transcripts.
- **SC-006**: 100% of text/background colour pairs meet WCAG 2.1 AA, and no screen hard-codes a colour outside the shared theme.
- **SC-007**: In a 5-person hallway test, at least 4 describe the app as "clean", "calm" or "modern" without prompting.

## Assumptions

- Users type their work email on the sign-in page; there is no password, so anyone can act as any registered email. This is the demo identity model (Constitution V); production needs real sign-in.
- Data scoping is enforced by the app and agents. Dataverse security roles and hierarchy security are out of scope for this demo and required for production.
- The week runs Monday–Sunday in a single organization time zone.
- Weekly capacity defaults to 40 hours when not set.
- Demo data: Jordan Lee (manager, no vacation row), Priya Patel and Alex Kim (reports of Jordan); projects Contoso Migration (CON-001, 400 h), Fabrikam Portal (FAB-002, 250 h), Internal Training (INT-003, 100 h); current-year vacation balances Priya 80/24 (56 remaining), Alex 80/40 (40 remaining).
- Out of scope: payroll, invoicing, overtime rules, contractor timesheets, offline mobile use, vacation requests.
