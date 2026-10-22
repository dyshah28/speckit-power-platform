# Layer 3 — Bounded self-correct loop

**Runs during** `/speckit-implement`.

```text
approved spec + tasks
        │
   Coordinator ──delegates one task──▶ Implementor ──change──▶ canvas compile_canvas (validator)
        ▲                                                         │
        │                                                         ▼
        └──── routes the fix ◀── FAIL ── Verifier (read-only) ── checks each acceptance scenario + runs Layer 1/2
                                   │
                                  PASS ──▶ next task … all done ──▶ HUMAN GATE: go / no-go
```

## Rules (from the constitution)
- The **implementor** optimizes for completing the task. The **verifier** optimizes for finding failures and cannot edit files. Opposing goals give a cleaner signal.
- Each failure is labeled with a root cause and routed:
  - `code` → back to the implementor with the evidence.
  - `plan` → the coordinator proposes a plan.md change → **HUMAN GATE: plan change**.
  - `spec` → stop → **HUMAN GATE: spec change**, with the exact question.
- **Budget:** at most 3 attempts per task. When the budget runs out, write `harness-report.md` and stop at `HUMAN GATE: budget exhausted`.
- The loop never edits a test to make it pass. A test changes only if the spec changed.

## Verifier output (exact format)
```text
TASK: T017
VERDICT: PASS | FAIL
US1-AC1: PASS — Playwright us1-log-time "US1-AC1 …" passed
US1-AC5: FAIL — label "Not registered message" not found (canvasapp/Screen1.pa.yaml)
COMPILE: clean | <n> blocking errors
ROOT CAUSE: code | plan | spec
```

## Real example from building this app
The first build of the Log Time screen used a `ModernLink` control for navigation. `compile_canvas` rejected
it because `ModernLink` has no `OnSelect`. The implementor read the error, switched to a `ModernButton`
with a transparent appearance, recompiled, and passed. No human touched it. That's this loop.
