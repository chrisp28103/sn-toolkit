---
description: Initialize a ServiceNow development session -- verify connection, clear errors, surface current session context (update set / scope / domain), load project context. Use at the start of any SN work session, when the user says "start", "kick off", or begins ServiceNow development.
model: sonnet
effort: low
allowed-tools: [Read, Bash]
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

## Step 3: Surface current session context

ServiceNow has THREE concurrent context layers -- surfacing them at session start prevents "why is my query returning 0 rows?" confusion later.

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'get_instance_info' | ConvertTo-Json -Depth 5"
```

Also query the currently-active update set via the session's preference (if the `get_instance_info` result doesn't include it):

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'query_records' -Params @{ table='sys_user_preference'; query='user=javascript:gs.getUserID()^name=sys_update_set'; fields='value'; limit=1 } | ConvertTo-Json -Depth 5"
```

If an update set sys_id is returned, look it up:
```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'query_records' -Params @{ table='sys_update_set'; query='sys_id=<SYS_ID>'; fields='name,state,sys_scope.scope'; limit=1 } | ConvertTo-Json -Depth 5"
```

## Step 4: Load project context

Read `docs/context/mobile-app-status.md` (or the project's primary context file from the user's CLAUDE.md) to understand current project state and what was done last session.

## Step 5: Report session status

Summarize concisely (under 10 lines):
- Connection: OK or FAILED (with specific fix instructions)
- Active instance / scope / domain (from step 3)
- Active update set (name + state) -- flag WARNING if it's "Default" for global-scope work
- Last session summary (from context file)
- What is UP NEXT (from context file)

If the update set is "Default" and the user's work will likely touch global scope, suggest `/sn-toolkit:switch updateset <name>` to move to a named update set before editing. Don't auto-switch (user manages update sets).

## Gotchas

- Session context is per-BROWSER-session, not per-terminal. If the user has multiple browser windows, the Agent API targets whichever has the SN Utils helper tab active.
- Domain visibility is the #1 cause of "query returned 0 results" surprises -- call out the active domain explicitly in the report if the instance is domain-separated.
