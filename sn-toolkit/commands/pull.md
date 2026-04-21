---
description: Pull a ServiceNow record's script/config, review it, and optionally modify it. Use when the user says "pull [record name]", "show me the script for X", or wants to inspect an existing SN record.
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

3. Check update set (MANDATORY before any writes):
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "sys_user_preference"
    query = "user=javascript:gs.getUserID()^name=sys_update_set"
    fields = "value"
    limit = 1
}
$currentUsId = if ($r.result.records.Count -gt 0) { $r.result.records[0].value } else { "" }
if ($currentUsId) {
    $us = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
        table = "sys_update_set"; query = "sys_id=$currentUsId"; fields = "name,is_default"; limit = 1
    }
    if ($us.result.records.Count -gt 0) {
        $usName = $us.result.records[0].name; $isDef = $us.result.records[0].is_default
        if ($isDef -eq "true") { Write-Host "WARNING: Current update set is DEFAULT ($usName) -- do NOT make changes!" }
        else { Write-Host "OK: Current update set: $usName" }
    }
}
```
If DEFAULT detected: STOP and warn user.

4. Query the record and save to temp file (NEVER pipe script fields to console):
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

5. Read back full content with `Get-Content -Raw` and display to user.

6. If modifications are requested, update via Agent API:
   - Single field: `update_record` with `table`, `sys_id`, `field`, `content`
   - Multiple fields (widgets): `update_record_batch` with `table`, `sys_id`, `fields` hashtable

7. Verify: `& $api -InstanceDir $instanceDir -Command "get_last_error"`
