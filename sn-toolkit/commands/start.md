---
description: Initialize a ServiceNow development session -- verify connection, clear errors, surface current session context (update set / scope / domain), load project context. Use at the start of any SN work session, when the user says "start", "kick off", or begins ServiceNow development.
model: sonnet
effort: low
allowed-tools: [Read, Bash]
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

> **Multi-instance note (v1.18.0+):** if `instances/` contains more than one subdir with a `_settings.json`, you can run Steps 1-4 in parallel against each instance dir. The sn-scriptsync multi-instance patch lets both helper tabs stay connected at once. Confirm the active pin first via `/sn-toolkit:instance`; that's where pushes/edits will target unless the user explicitly says otherwise.

## Step 1: Verify connection

**Skip Steps 1 and 3 if the SessionStart snapshot in your context already shows `server=True, browser=True, errors cleared`** -- the hook ran `check_connection` and `clear_last_error` for you. Jump to Step 2. Only run the commands below if the snapshot is missing, stale (e.g. after compaction), or shows either flag false.

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'check_connection' | ConvertTo-Json -Depth 5"
```

- If `serverRunning` is false: Tell user to click sn-scriptsync in VS Code status bar
- If `browserConnected` is false: Tell user to open SN Utils helper tab (type /token in ServiceNow)
- If both true: Proceed

## Step 2: Verify instance identity (CRITICAL)

`get_instance_info` returns the cached `instanceName` from `_settings.json` -- it does NOT reflect what scriptsync's browser tab is actually connected to. If the helper tab is on a different instance than the configured InstanceDir, every subsequent query silently goes to the wrong place. Catch this BEFORE any other work.

Query the live instance for its identity:

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'query_records' -Params @{ table='sys_properties'; query='nameINinstance_name,instance_id'; fields='name,value'; limit=5 } | ConvertTo-Json -Depth 5"
```

Read the InstanceDir's expected identity:

```bash
powershell.exe -Command "Get-Content '$INSTANCE_DIR/_settings.json' | ConvertFrom-Json | Select-Object name, url, instance_id | ConvertTo-Json"
```

**Compare:**

1. **Live `instance_name` vs. `_settings.json.name`** -- must match exactly. If different, STOP. Tell the user:
   > scriptsync is connected to **`<live_name>`** but your InstanceDir is configured for **`<expected_name>`**. Either repoint scriptsync's helper tab to the expected instance, or pass a different `-InstanceDir` (check the project root for `.claude/project.json` -- it may list `devUrl`/`prodUrl` and a sibling `instances/<name>/` folder).
2. **Live `instance_id` vs. `_settings.json.instance_id`** (defeats clone-name collisions) -- if `_settings.json` has no `instance_id` yet, treat this as a first-time verification and **append** the live `instance_id` to `_settings.json` so future starts can compare GUID-to-GUID. If the field exists and doesn't match: STOP, same warning as above (clone or accidental rename).
3. Only proceed to Step 3 if both match.

> **Why both checks:** ServiceNow clones occasionally inherit the source's `instance_name` until renamed. The `instance_id` GUID is unique per provisioning so it can't be spoofed. Name match catches the common case fast; ID match catches the edge case.

## Step 3: Clear error state

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'clear_last_error' | ConvertTo-Json -Depth 5"
```

## Step 4: Surface current session context

ServiceNow has THREE concurrent context layers -- surfacing them at session start prevents "why is my query returning 0 rows?" confusion later. Step 2 already pulled the instance identity (name, scope, instance_id) from `_settings.json` and `sys_properties`, so the only missing piece is the active update set.

Query the currently-active update set via the session's preference:

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'query_records' -Params @{ table='sys_user_preference'; query='user=javascript:gs.getUserID()^name=sys_update_set'; fields='value'; limit=1 } | ConvertTo-Json -Depth 5"
```

If an update set sys_id is returned, look it up:
```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'query_records' -Params @{ table='sys_update_set'; query='sys_id=<SYS_ID>'; fields='name,state,sys_scope.scope'; limit=1 } | ConvertTo-Json -Depth 5"
```

## Step 5: Load project context

Read `docs/context/mobile-app-status.md` (or the project's primary context file from the user's CLAUDE.md) to understand current project state and what was done last session.

## Step 6: Report session status

Summarize concisely (under 10 lines):
- Connection: OK or FAILED (with specific fix instructions)
- Active instance / scope / domain (from step 4)
- Active update set (name + state) -- flag WARNING if it's "Default" for global-scope work
- Last session summary (from context file)
- What is UP NEXT (from context file)

If the update set is "Default" and the user's work will likely touch global scope, suggest `/sn-toolkit:switch updateset <name>` to move to a named update set before editing. Don't auto-switch (user manages update sets).

## Gotchas

- Session context is per-BROWSER-session, not per-terminal. If the user has multiple browser windows, the Agent API targets whichever has the SN Utils helper tab active.
- Domain visibility is the #1 cause of "query returned 0 results" surprises -- call out the active domain explicitly in the report if the instance is domain-separated.
