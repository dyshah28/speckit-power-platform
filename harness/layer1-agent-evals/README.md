# Layer 1 — Agent evals (Copilot Studio agent evaluation)

**Triggers on:** any change to an agent's instructions, tools or topics.

| File | Agent | Cases | Identity |
|---|---|---|---|
| `timekeeper-agent.yaml` / `.csv` | Timekeeper | 13 (5 refusals) | each question carries Priya's context line |

The YAML is the source of truth: each case cites the acceptance scenario or constitution rule it proves.
The CSV (`Question`, `Expected response`) is what gets synced.

## Run it (automated)
```powershell
.\scripts\run-agent-evals.ps1          # or the whole harness: .\scripts\run-harness.ps1
```
The script writes the CSV into a Copilot Studio test set (compare-meaning grader), runs it with
`pac copilot-studio run-maker-evaluation-test-set`, waits for the result and records it in
`harness/reports/layer1.json`. In each question it replaces `TODAY` with today's date in the organisation time zone,
and `EMPLOYEE_ID` with the Employee row ID of the email in the same context line. How it works is in
`docs/automation-playbook.md`, section 6.

**Green = 100% pass, including every refusal case** (Constitution IV and VII). Anything less is red.
Read the agent's actual replies in Copilot Studio (the agent's **Evaluate** tab): pac returns only the verdicts.

## Run it by hand
Import the CSV in the agent's **Evaluate** tab (replace the two placeholders first), choose **Compare meaning**, run it,
then record the result: `.\scripts\record-layer1.ps1 -Agent timekeeper -Passed 13 -Total 13`.

## Why these cases
Refusals and "confirm before saving" are the behaviours that matter most for trust. A wrong answer is
annoying; a leaked colleague's timesheet, or an entry saved without consent, breaks the constitution.
