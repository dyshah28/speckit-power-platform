# agents/

The Copilot Studio agent's source, one folder per agent (`agents/<Agent Name>/`), kept in git like code (Constitution VIII).
The agent lives in the **Timekeeper** solution (Constitution III).

- `Timekeeper/agent.mcs.yml`: instructions. `actions/`: Dataverse tools (employee and status are fixed in the tool, not
  chosen by the model). `topics/`: *Read user context* (parses the app's context line) and *Submit my week* (calls a flow).
- `__AGENT_SCHEMA__` and `__SUBMIT_FLOW_ID__` are placeholders. `scripts/setup-environment.ps1` fills them in for your
  environment and copies the clone's `.mcs/` folder here (docs/setup.md, step 5).
- After any edit, you run `.\scripts\sync-agent.ps1` (pull, then push); a coding agent only prints it as a HUMAN GATE.
  Never push without the pull.
- Publish (`-Publish`) only when the human asks; publishing is a human gate (Constitution II).
- `.mcs/` (environment and change-token files) and `workflows/` (flow copies pulled by pac) are git-ignored.
