# Setup: from an empty environment to a working Timekeeper

About 45 minutes. Most of it is scripted; the steps marked 👤 need a person, because they involve a browser sign-in
or a Power Platform screen that has no API. The same 👤 steps are tasks in `specs/001-timekeeper-core/tasks.md`
(Phase 1), so when GitHub Copilot runs `/speckit-implement` it stops at each one and prints `HUMAN GATE`.

Commands are PowerShell 7 on Windows, run from the repo root unless stated otherwise.

---

## Safety: you hold the keys, Copilot doesn't

`az` and `pac` act as **you**, with everything your account can do in every environment and Azure resource it can
reach. So in this repo:

- **You run every command that touches the environment**: `az`, `pac`, and the scripts that call them
  (`setup-environment`, `sync-agent`, `run-agent-evals`, `run-harness`, `harness-env`, `publish-gate`). When
  Copilot needs one, it prints `HUMAN GATE: run <command>` and stops. Read the command, run it, paste back the output.
- **Copilot only edits files**, drives the canvas-authoring session you connect in step 8, and runs the Layer 2 tests
  with `npm test`. For the API checks it uses a token you write with `.\scripts\harness-env.ps1`: it works only against
  this environment's Dataverse and expires in about an hour.
- **Never paste a password, token, client secret or `.env` contents into a chat.** If one ends up there, revoke or
  rotate it.
- **Use a dedicated Developer environment**, ideally in a test tenant with nothing else in it. Your sign-in is the
  real limit on what anything running on your PC can do, so keep that account's reach small.
- **Clean up when you're done**: `az logout`, `pac auth clear`, and delete `harness\layer2-playwright\auth\` (a recorded
  browser sign-in) and `harness\layer2-playwright\.env`.

Tool rules add a guardrail against accidents. They are not a security boundary: a script can still call `az`
internally. To make Copilot CLI refuse the commands directly:

```powershell
copilot --deny-tool 'shell(az)' --deny-tool 'shell(pac)'
```

In VS Code agent mode, keep terminal commands on manual approval (don't add `az`, `pac` or `scripts\*` to
`chat.tools.terminal.autoApprove`).

## 0. 👤 Get the repo

```powershell
winget install Git.Git --accept-source-agreements --accept-package-agreements
# open a new terminal so git is on PATH
git clone <this repo's URL>
cd <repo folder>
```

Clone it rather than downloading a ZIP. Windows blocks scripts from a downloaded ZIP; if you did, run
`Get-ChildItem -Recurse *.ps1 | Unblock-File`.

## 1. 👤 What you need

| Need | Notes |
|---|---|
| A **work or school** Microsoft account | Personal accounts (Outlook.com, Gmail) can't use the Developer Plan or Copilot Studio. |
| A Power Platform environment **with Dataverse** | A free [Developer environment](https://learn.microsoft.com/power-platform/developer/create-developer-environment) works. Use one you can change freely, and nothing else important lives in. |
| Your role there | **System Administrator** (creates tables, flows, agents) |
| Licences | Power Apps and Power Automate (included in the Developer Plan), Copilot Studio (start the trial once in the portal), and Microsoft Teams for the approval card. The Developer Plan does **not** include Teams: you need a Microsoft 365 licence with Teams in the same tenant. |
| GitHub Copilot | Any plan that includes Copilot CLI or Copilot in VS Code agent mode |

## 2. 👤 Install the tools (once per machine)

```powershell
winget install Microsoft.PowerShell Microsoft.VisualStudioCode Microsoft.AzureCLI Microsoft.DotNet.SDK.10 OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
```

Close the terminal and open **PowerShell 7** (`pwsh`), not Windows PowerShell 5.1. The scripts refuse to run on 5.1.

```powershell
dotnet tool install --global Microsoft.PowerApps.CLI.Tool        # pac CLI
npm install -g @github/copilot                                   # GitHub Copilot CLI
```

Open a new terminal again so `pac` is on PATH.

In VS Code, install these extensions: **GitHub Copilot**, **Power Platform Tools** and **Copilot Studio**. Sign in to
GitHub Copilot with your GitHub account, and to the Copilot Studio extension with your work account.

Sign in to Copilot CLI, then install the canvas app plugin. It gives Copilot the canvas-authoring MCP server and the
`canvas-app` skill:

```text
copilot
/login
/plugin marketplace add microsoft/power-platform-skills
/plugin install canvas-apps@power-platform-skills
```

You only need the Spec Kit CLI (`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`) to
upgrade Spec Kit or start a new repo. This repo already contains the generated commands in `.github/skills/`.

## 3. 👤 Sign in (once per machine)

Find your environment URL in the [Power Platform admin center](https://admin.powerplatform.microsoft.com):
**Environments**, your environment, **Environment URL**.

```powershell
az login --allow-no-subscriptions                      # add --tenant <tenant id> if your account is in several tenants
pac auth create --environment https://<your-org>.crm.dynamics.com
pac org who                                            # check it shows your environment
az account show --query user.name -o tsv               # must be the same account as pac's "User Email"
```

`--allow-no-subscriptions` matters: a Power Platform tenant usually has no Azure subscription, and without it
`az login` stops with "No subscriptions found".

Nothing in the repo stores your environment. Every script reads it from the active pac profile (`pac org who`).

## 4. 👤 Create three connections

Go to Power Automate, choose your environment, open **Connections**, select **New connection**, and add each of these signed in as yourself:

- **Microsoft Dataverse**
- **Microsoft Teams**
- **Microsoft Copilot Studio**

The setup script points the solution's connection references at them.

## 5. 👤 Run the setup script (it stops at each 👤 step)

```powershell
.\scripts\setup-environment.ps1 -ManagerEmail <your work email>
```

`-ManagerEmail` becomes the seeded manager, Jordan Lee, so the Teams approval card reaches you. The employees are
`priya@example.com` and `alex@example.com`. You sign in as them by typing their email in the app, so they don't
need real accounts.

The script creates the **tk** publisher, the **Timekeeper** solution, the four tables, the seed data, the
`tk_DataverseUrl` environment variable and the connection references. Then it stops and asks for the agent:

1. 👤 In **Copilot Studio**, choose your environment, select **Create**, then **New agent**, then **Skip to configure**.
   Name it exactly `Timekeeper` and create it. Leave everything else empty: the repo holds its instructions, tools and topics.
2. 👤 In **VS Code**, open the Copilot Studio extension, choose **Clone agent**, pick the environment and *Timekeeper*,
   and clone it into a folder **outside this repo**, for example `$env:TEMP\tk-clone`.
3. Run the script again, pointing it at the cloned folder (keep the quotes):
   ```powershell
   .\scripts\setup-environment.ps1 -ManagerEmail <your work email> -AgentClone "$env:TEMP\tk-clone\Timekeeper"
   ```
   It creates and turns on the three flows, adds the agent to the solution, copies the clone's `.mcs\` connection
   files into `agents\Timekeeper\`, and fills in the agent's schema name and the flow ID in the agent YAML.

> The filled-in files under `agents\Timekeeper\` now hold IDs from your environment. `.mcs\` is git-ignored.
> Don't push the other filled-in values to a public fork.

**Environment already has a Timekeeper build?** The script stops with a message if a *Timekeeper* solution from another
publisher exists. Add `-Suffix V2` to every run: the solution, flows and agent become *TimekeeperV2*,
*AskTimekeeperV2* (and so on) and *Timekeeper V2*, and the script renames the flow calls in `canvasapp/` to match.
Use those names in steps 5 to 10, and name the app `Timekeeper App V2`.

## 6. 👤 Push and publish the agent

```powershell
.\scripts\sync-agent.ps1 -Publish     # pac copilot pull, then push, then publish
```

The Assistant screen reaches the agent through the `AskTimekeeper` flow, which only talks to a **published** agent.

## 7. 👤 Create the canvas app shell (5 minutes)

There is no API for these steps:

1. In Power Apps, go to **Solutions**, open **Timekeeper**, and select **New**, then **App**, then **Canvas app**.
   Name it `Timekeeper App`, choose **Tablet** and select **Create**.
2. Open **Settings**, then **Updates**. Turn on **Modern controls and themes** and **Coauthoring**, and reload if asked.
3. Open **Data**, select **Add data**, choose **Dataverse**, and add **Employees**, **Projects**, **Time Entries** and **Vacation Balances**.
4. Open **Power Automate**, select **Add flow**, and add **AskTimekeeper** and **SubmitMyWeek**.
5. **Save** the app. Keep this tab open, and copy the full Studio URL from the address bar.

## 8. Let Copilot build the app

In VS Code's terminal, from the repo root, run `copilot`, then:

```text
/canvas-apps:configure-canvas-mcp
```

Paste the Studio URL and approve the `connect` step. Then choose one of these:

**A. Deploy the reference build** (fast). Paste this:
```text
Apply the canvasapp/ source to the coauthoring session with compile_canvas until it compiles clean.
Do NOT run sync_canvas first: the session is a blank app and would overwrite the source.
```

**B. Rebuild it from the spec with Spec Kit** (the real demo, about 1.5 hours). See
[Rebuild from the spec](#rebuild-the-app-from-the-spec) below.

Then 👤 **Save** and **Publish** in Studio. Only a person publishes (Constitution II).

## 9. 👤 Wire up the harness and run it

```powershell
cd harness\layer2-playwright
npm install
npx playwright install chromium
cd ..\..
.\scripts\harness-env.ps1      # writes the app URL, org URL and a 1-hour Dataverse-only token to .env (add -App for another name)
cd harness\layer2-playwright
npm run auth                   # sign in with your Microsoft account; close the window when the Timekeeper sign-in panel shows
cd ..\..
.\scripts\run-harness.ps1      # Layer 1 agent evals, Layer 2 Playwright and API contract, Layer 3
.\scripts\publish-gate.ps1     # your go/no-go
```

While Copilot works, it runs only the Layer 2 tests (`npm test`). When they fail with 401, the token has expired:
run `.\scripts\harness-env.ps1` again.

If you seeded a different manager email, also set `TK_MANAGER_EMAIL` in `harness\layer2-playwright\.env`.

Layer 1 runs the agent's test set with pac. If the run can't sign in, open the agent's **Evaluate** tab in
Copilot Studio and run any test once. That creates the *Agent Evaluation* connection the script uses.

## 10. 👤 Let other people use it (optional)

Under the demo identity model the app scopes the data, but Dataverse still needs each user to have permission on the tables:

1. In the Power Platform admin center, open your environment, then **Settings**, **Users + permissions** and **Security roles**.
   Create a role named `Timekeeper User` with Organization-level Create, Read, Write, Append and Append To on the four tables.
2. Assign it, plus **Basic User**, to each tester. Share *Timekeeper App* with them.

---

## Rebuild the app from the spec

This is the Spec Kit loop at work: Copilot builds the app from `specs/001-timekeeper-core/` through the
canvas-authoring MCP server, and the harness checks it.

1. Do step 7 above, then connect Copilot to the session as in step 8 (`/canvas-apps:configure-canvas-mcp` with the Studio URL).
2. Delete `canvasapp\Approvals.pa.yaml` and `canvasapp\Assistant.pa.yaml`, then sync the blank session:
   *"Sync the canvas session into canvasapp/. It's a new, empty app, so overwriting is fine."*
3. Every task in `specs/001-timekeeper-core/tasks.md` starts unticked. Tick Phase 1 (T001 to T008) as you finish
   steps 1 to 7. The rounds below build the app; the test, agent and flow tasks they skip are already in the repo.
4. Build it in three rounds. Each round ends at a human gate, so you can look at the app before going on.

**Round 1: foundation**
```text
/speckit-implement Feature 001, only tasks T009, T011 and T012. Confirm the real column names first (T009), then define the Soft Pastel Light theme tokens in App.Formulas exactly as in contracts/ui-theme.md (T011), then sign-in and identity (T012). Compile, then stop.
```

**Round 2: Log Time screen (US1)**
```text
/speckit-implement Feature 001, Phase 3 (US1): tasks T015 to T021. Build the Log Time screen as contracts/ui-theme.md describes. Use only Th* tokens for colour and the accessible labels from canvas-ui-contract.md. Compile, run the verifier, then stop at the human gate.
```
Press **F5** in Studio to try it. You can ask for changes in plain English, for example *"Make the progress bar thinner; keep it within the theme."*

**Round 3: Approvals and Assistant (US2, US3)**
```text
/speckit-implement Feature 001, Phases 4 and 5: tasks T023 to T028, then T032. Theme tokens and contract labels only. Compile, run the verifier, then stop at the human gate.
```

Then do steps 9 and 10.

## Then add a feature yourself

`prompts/002-live-requirement.md` has a ready-to-paste requirement (a vacation-balance widget) for
`/speckit-specify`. Go through spec, clarify, plan, your plan approval, tasks and implement. Compare your run with
`examples/002-vacation-balance/`.

## If something goes wrong

| Symptom | Fix |
|---|---|
| A script says `👤 ...` | Do that step, then run the same script again. Every script is safe to re-run. |
| Copilot prints `HUMAN GATE: run ...` | Read the command, run it yourself, and paste the output back. |
| "No subscriptions found" from `az login` | Use `az login --allow-no-subscriptions`. |
| 401 or 403 from a script | az and pac are signed in as different accounts, or the account isn't System Administrator. Check step 3. |
| "cannot be loaded ... not digitally signed" | The repo came from a ZIP. Run `Get-ChildItem -Recurse *.ps1 \| Unblock-File`. |
| Flow won't turn on | A connection from step 4 is missing or signed out. Fix it in Power Automate, then re-run step 5. |
| "Request Too Long" when Studio opens | Open Studio in a private browser window. |
| Canvas session dropped | Run `/canvas-apps:configure-canvas-mcp` again with the URL. Your work is in `canvasapp/` and `tasks.md`. |
| `'Active (Projects)'.True` shows inactive projects | The Yes/No labels are swapped. Tables made by the script are correct; see the playbook, section 1. |
| Copilot ran out of quota mid-build | Start it again and say *"Resume /speckit-implement from the first unchecked task."* |

How each step is automated, and the traps we hit along the way: [`automation-playbook.md`](automation-playbook.md).
