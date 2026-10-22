# Implementation Plan: Vacation Balance Widget

**Branch**: `002-vacation-balance` | **Date**: 2026-10-16 | **Spec**: [spec.md](./spec.md)

**Status**: Awaiting approval

## Summary
A read-only widget on Log Time (own balance) and on Approvals (selected direct report's balance), read from Vacation Balances for `Year(Today())`.

## Technical Context
**Language/Version**: Power Fx (canvas `.pa.yaml`) · **Storage**: Dataverse Vacation Balances (`tk_`) · **Testing**: Playwright (Layer 2) · **Scale**: demo

## Constitution Check
| Principle | Status | Note |
|---|---|---|
| I Spec-First | ✅ | Traces to US1/US2 |
| II Human-Gated | ⏳ | Awaiting `**Status**: Approved` |
| IV Validated | ✅ | Compile clean + new Playwright tests US1-AC1/AC2, US2-AC1 |
| V Identity-Scoped | ✅ | Own: `LookUp('Vacation Balances', tk_employee.tk_employeeid = varMe.tk_employeeid && tk_year = Year(Today()))`; manager: same lookup for the selected row's employee, which is already restricted to `colDirectReports` |
| IX Incremental | ✅ | One read-only label/card per screen; no schema change |

## Design
- Styling: a soft butter highlight card (`ThChipButter` fill, `ThChipButterInk` text, radius 12) with a 🌴 icon and the label "Vacation left this year", consistent with contracts/ui-theme.md. No new colours.
- Log Time: a card next to the week summary card, `AccessibleLabel` = `Vacation balance`, text `Text(rec.tk_remaininghours, "0.0") & " h"` or `"Not available — contact HR"`.
- Approvals: the same card bound to the selected pending row's employee, `AccessibleLabel` = `Report vacation balance`.
- Add both labels to `specs/001-timekeeper-core/contracts/canvas-ui-contract.md`.
