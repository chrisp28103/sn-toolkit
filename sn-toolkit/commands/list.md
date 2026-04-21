---
description: List and review all records of a specific type in the project's scoped application. Use when the user asks "list all X", "show me all script includes", or wants an inventory of records in a table.
model: sonnet
effort: low
allowed-tools: [Read, Glob, Grep, Bash]
---

$ARGUMENTS should specify the table type (e.g., "sys_script_include", "sp_widget", "sys_script").

## Steps

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

1. Query all records:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "sys_scope.scope=<YOUR_SCOPE>"
    fields = "sys_id,name,active,sys_updated_on,sys_updated_by"
    limit = 200
}
$outFile = "$instanceDir\agent\tmp\list_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$json = $r.result.records | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($outFile, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Found $($r.result.records.Count) records"
```

2. Read the file and present as a formatted table to the user.

3. If user wants details on a specific record, use /sn-toolkit:pull to fetch it.
