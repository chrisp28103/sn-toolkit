---
description: View the full, untruncated response from a ServiceNow query. Use when SN query output looks truncated, sys_ids appear cut off, or the user needs the untruncated JSON response.
model: sonnet
effort: low
allowed-tools: [Read, Bash]
---

$ARGUMENTS should describe what to query or the path to an existing temp file.

## Pattern: Query and Save (prevents PowerShell truncation)

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

```powershell
$outFile = "$instanceDir\agent\tmp\full_response_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"

$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "<QUERY>"
    fields = "<FIELDS including script or long fields>"
    limit = 1
}
$json = $r.result.records | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outFile, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Saved to: $outFile"
```

Then read the file with `Get-Content -Raw "$outFile"` to get untruncated content.

## Why This Is Necessary
PowerShell truncates long strings in console output. ServiceNow sys_ids (32 chars) and script fields get silently clipped. If you use a truncated sys_id in an `update_record` call, it will silently fail or target the wrong record.

NEVER copy sys_ids or long field values from console output. Always save to file first.
