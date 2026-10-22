# Data Model: Timekeeper Core (Dataverse, prefix `tk_`)

> `scripts/setup-environment.ps1` creates these tables, columns and the seed data from this file. Agents MUST still
> confirm the names against the live schema (canvas-authoring `get_data_source_schema`) before writing formulas.
> Lookups are referenced in Power Fx and `@odata.bind` by their schema name (`tk_Manager`, `tk_Employee`, `tk_Project`);
> their Web API filter names are `_tk_manager_value` etc.

## Employees (`tk_employee`)
| Display name | Logical name (expected) | Type | Rules |
|---|---|---|---|
| Full Name | `tk_fullname` (primary name) | Text | Required |
| Email | `tk_email` | Email | Required, unique; **identity key** (case-insensitive match to sign-in email) |
| Manager | `tk_Manager` | Lookup → Employees | Blank for top-level managers |
| Weekly Capacity Hours | `tk_weeklycapacityhours` | Decimal | Default 40 |
| Active | `tk_active` | Yes/No (value 1 = True) | Default True |

## Projects (`tk_project`)
| Display name | Logical name (expected) | Type | Rules |
|---|---|---|---|
| Project Name | `tk_projectname` (primary name) | Text | Required |
| Project Code | `tk_projectcode` | Text | Required, e.g. CON-001 |
| Client Name | `tk_clientname` | Text | |
| Budget Hours | `tk_budgethours` | Decimal | Used for burn (US7) |
| Active | `tk_active` | Yes/No, seen in the app as `'Active (Projects)'` (value 1 = True = active) | Only active projects are selectable |

## Time Entries (`tk_timeentry`)
| Display name | Logical name (expected) | Type | Rules |
|---|---|---|---|
| Title | `tk_title` (primary name) | Text | "{Employee} – {Project} – {yyyy-mm-dd}" |
| Employee | `tk_Employee` | Lookup → Employees | Required |
| Project | `tk_Project` | Lookup → Projects | Required, must be active at creation |
| Work Date | `tk_workdate` | Date only (Power Fx type DateTime) | Required |
| Hours | `tk_hours` | Decimal | 0.25–12, multiple of 0.25; per-day total ≤ 24 |
| Notes | `tk_notes` | Text (2000) | Optional |
| Status | `tk_status` | Choice `'Status (Time Entries)'`: Draft 495690000, Submitted 495690001, Approved 495690002, Rejected 495690003 | Default Draft |
| Approver Comment | `tk_approvercomment` | Text (2000) | Required when Status = Rejected |

### Status transitions
```text
Draft ──submit──▶ Submitted ──approve──▶ Approved   (final)
                      └──reject (comment)──▶ Rejected ──edit──▶ Draft ──submit──▶ Submitted
```
Only the owner employee moves Draft → Submitted. Only the owner's manager moves Submitted → Approved or Rejected.

## Vacation Balances (`tk_vacationbalance`)
| Display name | Logical name (expected) | Type | Rules |
|---|---|---|---|
| Title | `tk_title` (primary name) | Text | "{Employee} – {Year}" |
| Employee | `tk_Employee` | Lookup → Employees | Required |
| Year | `tk_year` | Whole number | Required |
| Accrued Hours | `tk_accruedhours` | Decimal | |
| Used Hours | `tk_usedhours` | Decimal | |
| Remaining Hours | `tk_remaininghours` | Decimal (seeded as Accrued − Used) | |

Stored only in feature 001. Feature 002 displays it.

## Demo seed data
| Employee | Email | Manager | Capacity | Current-year vacation (accrued/used/remaining) |
|---|---|---|---|---|
| Jordan Lee | `-ManagerEmail` (use your own, for the Teams card) | — | 40 | *no row* (tests the "not available" path in feature 002) |
| Priya Patel | priya@example.com | Jordan Lee | 40 | 80 / 24 / **56** |
| Alex Kim | alex@example.com | Jordan Lee | 40 | 80 / 40 / **40** |

Projects: Contoso Migration (CON-001, 400 h), Fabrikam Portal (FAB-002, 250 h), Internal Training (INT-003, 100 h).
