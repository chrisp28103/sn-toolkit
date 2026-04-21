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

## Check 2: Recent syslog errors (last 5 minutes)

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'query_records' -Params @{ table = 'syslog'; query = 'level<=1^sys_created_on>=javascript:gs.minutesAgoStart(5)^source!=system^ORDERBYDESCsys_created_on'; fields = 'level,message,source,sys_created_on'; limit = 5 } | ConvertTo-Json -Depth 5"
```

If records found, report them briefly (source + first 150 chars of message).

## Check 3: Connection health

```bash
powershell.exe -Command "& '$API' -InstanceDir '$INSTANCE_DIR' -Command 'check_connection' | ConvertTo-Json -Depth 5"
```

If server or browser disconnected, report WARNING.

## Output rules

- Report ONLY problems. If all checks pass, say: "SN health: OK"
- Keep output to 2-3 lines max when healthy
- On errors, include enough detail to act on
