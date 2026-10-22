# flows/

Cloud flow definitions (the `clientdata` JSON of each flow). `scripts/setup-environment.ps1` creates them in the
Timekeeper solution, or updates them in place, and turns them on. Connections go through the connection references
`tk_dataverse`, `tk_teams` and `tk_copilotstudio`. `__AGENT_SCHEMA__` is filled in when the flow is created.

| Flow | Trigger | Used by | Does |
|---|---|---|---|
| `AskTimekeeper` | Power Apps | Assistant screen | Sends a message to the Timekeeper agent and returns its reply |
| `SubmitMyWeek` | Power Apps | Submit week button | Submits the employee's Draft entries of this week, replies, then posts an Approve/Reject card to the manager in Teams and applies the decision (US6) |
| `SubmitMyWeekAgent` | Agent | Topic *Submit my week* | Same steps as `SubmitMyWeek` (keep the two in sync) |

"This week" is calculated in *Central Standard Time*. Search for it in the JSON to change the time zone.
US5 (Friday reminder) is P3 and not built yet.
