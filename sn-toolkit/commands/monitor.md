---
description: Health monitor for active SN dev sessions -- use with /loop 5m /sn-toolkit:monitor
model: sonnet
effort: low
allowed-tools: [Read, Glob, Grep, Bash]
---

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

This skill is designed for recurring use with `/loop`. Example: `/loop 5m /sn-toolkit:monitor`

## Check 1: Async errors

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'get_last_error' | ConvertTo-Json -Depth 5"
```

If result is non-null/non-empty, report "ASYNC ERROR DETECTED" with details.

## Check 2: Scriptsync sync queue depth

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'get_sync_status' | ConvertTo-Json -Depth 5"
```

Healthy: `pendingCount: 0` or small (1-3) with recent activity.

Report WARNING if:
- `pendingCount >= 10` -- queue is backing up, sync is not keeping pace
- `isPaused: true` -- user paused sync manually; flag it so they don't forget
- Same file has been pending across two consecutive monitor runs -- likely stuck

## Check 3: Recent syslog errors (last 5 minutes)

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'query_records' -Params @{ table = 'syslog'; query = 'level<=1^sys_created_on>=javascript:gs.minutesAgoStart(5)^source!=system^ORDERBYDESCsys_created_on'; fields = 'level,message,source,sys_created_on'; limit = 5 } | ConvertTo-Json -Depth 5"
```

If records found, report them briefly (source + first 150 chars of message).

## Check 4: Connection health

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'check_connection' | ConvertTo-Json -Depth 5"
```

If server or browser disconnected, report WARNING.

## Output rules

- Report ONLY problems. If all checks pass, say: "SN health: OK (sync queue: 0)"
- Keep output to 2-3 lines max when healthy
- On errors, include enough detail to act on
- If queue is backing up, suggest `& $api -InstanceDir $instanceDir -Command "sync_now"` to flush
