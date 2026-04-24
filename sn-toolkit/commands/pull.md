---
description: Pull a ServiceNow record's script/config, review it, and optionally modify it. Use when the user says "pull [record name]", "show me the script for X", or wants to inspect an existing SN record.
model: sonnet
effort: low
allowed-tools: [Read, Bash]
---

See `docs/reference/agent-api-cheatsheet.md` for command quick-reference.

$ARGUMENTS should contain the table name and record name (e.g., "sys_script_include TpMobileUtils").

## Steps

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

1. Parse table and record name from $ARGUMENTS

2. Verify connection:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "check_connection"
$r.result | ConvertTo-Json
```

3. Query the record, save, read back -- see conventions.md "Canonical Query-and-Save Snippet" for the full save+read pattern:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "name=<NAME>^sys_scope.scope=<YOUR_SCOPE>"
    fields = "sys_id,name,script,active,sys_updated_on,sys_updated_by"
    limit = 1
}
```

4. Display the full content to the user.

5. If modifications are requested, update via Agent API:
   - Single field: `update_record` with `table`, `sys_id`, `field`, `content`
   - Multiple fields (widgets): `update_record_batch` with `table`, `sys_id`, `fields` hashtable

6. Verify: `& $api -InstanceDir $instanceDir -Command "get_last_error"`
