---
description: Review all scripts in a ServiceNow table type for best practices, security, and performance. Use when the user asks to code-review or audit scripts against standards for an entire table type (all Script Includes, all Business Rules, etc.).
model: sonnet
effort: medium
allowed-tools: [Read, Glob, Grep, Bash]
---

$ARGUMENTS should specify the table type to review (e.g., "sys_script_include" or "sp_widget").

## Steps

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

1. Query all records of the specified type in scope:
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "sys_scope.scope=<YOUR_SCOPE>^active=true"
    fields = "sys_id,name,script"
    limit = 100
}
$outFile = "$instanceDir\agent\tmp\review_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$json = $r.result.records | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outFile, $json, (New-Object System.Text.UTF8Encoding($false)))
```

2. Read each script and check against .claude/rules/sn-scripting.md standards:
   - `var` instead of `let`/`const`
   - Direct property access (`gr.name`) instead of `getValue()`
   - `gs.nowDateTime()` or other forbidden scoped-app APIs
   - Generic variable names (`gr` instead of `grUser`)
   - Missing error handling
   - `getRowCount()` for existence checks
   - GlideRecord queries inside loops
   - String concatenation instead of template literals

3. Report findings grouped by severity (Critical / Warning / Style).
