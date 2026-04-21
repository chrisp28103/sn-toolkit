---
description: Initialize a ServiceNow development session -- verify connection, clear errors, load project context. Use at the start of any SN work session, when the user says "start", "kick off", or begins ServiceNow development.
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

## Step 1: Verify connection

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'check_connection' | ConvertTo-Json -Depth 5"
```

- If `serverRunning` is false: Tell user to click sn-scriptsync in VS Code status bar
- If `browserConnected` is false: Tell user to open SN Utils helper tab (type /token in ServiceNow)
- If both true: Proceed

## Step 2: Clear error state

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'clear_last_error' | ConvertTo-Json -Depth 5"
```

## Step 3: Load project context

Read `docs/context/mobile-app-status.md` to understand current project state and what was done last session.

## Step 4: Report session status

Summarize concisely:
- Connection: OK or FAILED (with specific fix instructions)
- Last session summary (from context file)
- What is UP NEXT (from context file)
