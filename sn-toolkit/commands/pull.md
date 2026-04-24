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

3. Query the record and save to temp file (NEVER pipe script fields to console):
```powershell
$outFile = "$instanceDir\agent\tmp\sn_query_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "name=<NAME>^sys_scope.scope=<YOUR_SCOPE>"
    fields = "sys_id,name,script,active,sys_updated_on,sys_updated_by"
    limit = 1
}
$json = $r.result.records | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outFile, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Saved to: $outFile"
```

4. Read back full content with `Get-Content -Raw` and display to user.

5. If modifications are requested, update via Agent API:
   - Single field: `update_record` with `table`, `sys_id`, `field`, `content`
   - Multiple fields (widgets): `update_record_batch` with `table`, `sys_id`, `fields` hashtable

6. Verify: `& $api -InstanceDir $instanceDir -Command "get_last_error"`
