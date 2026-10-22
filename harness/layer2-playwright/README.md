# Layer 2 — Playwright UI tests + Dataverse API contract

**Triggers on:** any canvas app, table or column change.

| Suite | Persona (typed on the sign-in panel) | Covers |
|---|---|---|
| `tests/theme-contrast.spec.ts` | none | Palette contrast (WCAG AA), pastel softness, no hard-coded colours in screen files |
| `tests/api-contract.spec.ts` | API token | Every table and column in `contract.config.json` exists, and the seed data is there |
| `tests/us1-log-time.spec.ts` | Priya (employee) | US1 |
| `tests/us2-approvals.spec.ts` | Jordan (manager) | US2 |
| `tests/unregistered.spec.ts` | an email that isn't in Employees | US1 AC5 |

The tests find controls **only** by the accessible labels in
`specs/001-timekeeper-core/contracts/canvas-ui-contract.md`. If a label is missing in the app, the test
fails with "element not found". That tells the agent to fix the app, not the test.

## One-time setup
```powershell
npm install
npx playwright install chromium
$env:TK_APP_URL = '<the app''s Web link: Power Apps, Timekeeper App, Details>'
npm run auth      # sign in with your Microsoft account; close the window when the Timekeeper sign-in panel shows
```
One recorded sign-in (`auth/maker.json`, git-ignored) covers every persona, because the persona is the email typed in the app.

## Run
```powershell
..\..\scripts\run-harness.ps1   # you run this: fills TK_APP_URL, TK_ORG_URL and the API token from pac and az, then runs everything
..\..\scripts\harness-env.ps1   # you run this: writes those values to .env (token valid about an hour)
npm test                        # just this layer; the only test command a coding agent runs
npm run test:headed             # watch it click through the app
npm run report                  # open the HTML report
```

Tests that change shared data (submitting a week, approving) only run with `TK_ALLOW_MUTATIONS=1`.
Entries created by tests are marked `PW-TEST`, and the suite deletes them through the Web API afterwards.

Canvas screens fill in piece by piece, so tests wait with `settled()` until a value reads the same twice.
Microsoft's open-source toolkit (github.com/microsoft/power-platform-playwright-samples, `CanvasAppPage`) is a
drop-in alternative for `helpers/app.ts`.
