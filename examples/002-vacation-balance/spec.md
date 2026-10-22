# Feature Specification: Vacation Balance Widget

**Feature Branch**: `002-vacation-balance`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "Add a vacation-balance widget to Timekeeper. Employees should see their remaining vacation hours for the current year on the Log Time screen of the app. Managers can see the balance of their direct reports on the Approvals screen. Nobody can see anyone else's balance."

> Reference output: what Spec Kit produced for `prompts/002-live-requirement.md`. Compare it with your own run.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See my remaining vacation (Priority: P1)
An employee sees their remaining vacation hours for the current year on the Log Time screen.

**Why this priority**: Removes the most common question employees send to HR.

**Independent Test**: Sign in as Priya and see "56.0 h".

**Acceptance Scenarios**:
1. **Given** Priya with 56 remaining hours in the current year, **When** she opens Log Time, **Then** the widget shows "56.0 h".
2. **Given** a user with no balance row for the current year, **When** they open Log Time, **Then** the widget shows "Not available — contact HR".

### User Story 2 - See my reports' vacation when approving (Priority: P2)
A manager sees the remaining vacation of the direct report whose entries they are reviewing.

**Independent Test**: Sign in as Jordan, open Approvals and select one of Priya's entries: "56.0 h" is shown.

**Acceptance Scenarios**:
1. **Given** a manager reviewing a direct report's entry, **When** they select it, **Then** that report's remaining hours are shown.
2. **Given** any user, **When** they use the app, **Then** they never see the balance of anyone other than themselves or their direct reports.

### Edge Cases
- A balance row for a previous year only → treated as "Not available".
- Remaining hours with decimals → shown with one decimal.

## Requirements *(mandatory)*
- **FR-001**: The system MUST show the signed-in employee's remaining vacation hours for the current calendar year, with one decimal.
- **FR-002**: The system MUST show "Not available — contact HR" when no current-year balance exists.
- **FR-003**: Managers MUST see remaining hours only for their direct reports.
- **FR-004**: The feature MUST NOT change any balance (read-only).

### Key Entities
- **Vacation Balance** (existing): employee, year, remaining hours.

## Success Criteria *(mandatory)*
- **SC-001**: Employees see their balance within 3 seconds of opening the app.
- **SC-002**: Zero cases in testing where a user sees a non-permitted person's balance.

## Assumptions
- Balances are maintained by HR outside this feature. Out of scope: requesting vacation, accrual rules, editing balances, skip-level visibility.
