---
description: Bulk export all scripts from the ServiceNow scope to local files. Use when the user asks to back up, export, or download scripts from the instance for offline reference.
model: sonnet
effort: low
allowed-tools: [Read, Write, Bash]
---

## Steps

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

1. Verify connection:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "check_connection"
```

2. For each table type (sys_script_include, sys_script, sys_script_client, sp_widget, sys_ws_operation) -- save per conventions.md "Canonical Query-and-Save Snippet":
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "sys_scope.scope=<YOUR_SCOPE>^active=true"
    fields = "sys_id,name,script"
    limit = 500
}
```

3. Report total counts per table type.
