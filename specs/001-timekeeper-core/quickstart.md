# Quickstart: Timekeeper Core

## Use the app
1. Open *Timekeeper App* (play link) and type `priya@example.com` on the sign-in panel.
2. Log 8 h to Contoso Migration for Monday and confirm the week total shows 8. Submit the week.
3. In Teams, as the manager (the `-ManagerEmail` you seeded), use **Approve week** or **Reject week** (comment required) on the Flow bot card,
   or sign in as the manager in the app and use Approvals.
4. Back as Priya, a rejected entry shows the comment and is editable.

## Run the harness (one command)
```powershell
# one time: az login; pac auth create; then record your Microsoft sign-in for the UI tests
cd harness\layer2-playwright; npm install; npx playwright install chromium; npm run auth; cd ..\..

# every time (the speckit-implement coordinator also runs it after each feature)
.\scripts\run-harness.ps1         # Layer 1 agent evals (synced from CSV and run), Layer 2 Playwright + API, Layer 3
.\scripts\publish-gate.ps1        # refuses unless all layers are green, then asks for your go/no-go
```
How each step is automated: `docs/automation-playbook.md`.
