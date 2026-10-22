# Try it: add feature 002 with Spec Kit

Paste one of these into GitHub Copilot. A reference result is in `examples/002-vacation-balance/`.

## App-only version
```
/speckit-specify Add a vacation-balance widget to Timekeeper. Employees should see their remaining vacation hours for the current year on the Log Time screen of the app. Managers can see the balance of their direct reports on the Approvals screen. Nobody can see anyone else's balance. Balances already exist in the Vacation Balances table.
```

## Full version (app + Timekeeper agent)
```
/speckit-specify Add a vacation-balance widget to Timekeeper. Employees should see their remaining vacation hours for the current year on the Log Time screen of the app, and be able to ask the Timekeeper assistant "how much vacation do I have left?". Managers can see the balance of their direct reports on the Approvals screen. Nobody can see anyone else's balance. Balances already exist in the Vacation Balances table.
```

## Answers for /speckit-clarify
1. Hours or days? → **Hours, one decimal.**
2. No balance row for the current year? → **Show "Not available — contact HR".**
3. Skip-level managers? → **No, direct reports only.**

## Expected result with the demo data
Priya **56.0 h** · Alex **40.0 h** · Jordan (no row) **Not available — contact HR**
