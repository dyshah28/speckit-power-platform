# Contract: Dataverse schema

The canvas app, agents, flows and the Layer 2 API contract test (`harness/layer2-playwright/tests/api-contract.spec.ts`)
depend on these entity sets and columns existing with these types. A change here is a breaking change and
needs a spec update first (Constitution I).

| Entity set (Web API) | Required columns |
|---|---|
| `tk_employees` | `tk_fullname`, `tk_email`, `_tk_manager_value`, `tk_weeklycapacityhours` |
| `tk_projects` | `tk_projectname`, `tk_projectcode`, `tk_budgethours` |
| `tk_timeentries` | `_tk_employee_value`, `_tk_project_value`, `tk_workdate`, `tk_hours`, `tk_status`, `tk_approvercomment` |
| `tk_vacationbalances` | `_tk_employee_value`, `tk_year`, `tk_remaininghours` |

The exact names are confirmed once against the live environment, and `harness/layer2-playwright/contract.config.json`
is the single place the tests read them from.
