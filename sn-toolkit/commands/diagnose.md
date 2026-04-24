---
description: Diagnose ServiceNow errors -- widgets not loading, script failures, BR issues, integration failures
model: sonnet
effort: medium
allowed-tools: [Read, Grep, Bash]
---

$ARGUMENTS should describe the error or symptom.

Use `$api` and `$instanceDir` from CLAUDE.md "Agent API Setup".

## Step 1: Check syslog for errors
```powershell
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "syslog"
    query = "level<=1^sys_created_on>=javascript:gs.minutesAgoStart(10)^ORDERBYDESCsys_created_on"
    fields = "level,message,source,sys_created_on"
    limit = 20
}
$outFile = "$instanceDir\agent\tmp\syslog_diag.json"
$json = $r.result.records | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($outFile, $json, (New-Object System.Text.UTF8Encoding($false)))
```
Read the file and analyze errors.

## Step 2: If widget-related, check widget script for syntax errors
Query the widget's script fields and look for common issues:
- Missing function declarations
- Stale local files that overwrote API changes (Gotcha #8)
- IIFE pattern instead of Angular DI in client scripts
- `gs.nowDateTime()` or other forbidden scoped app APIs

## Step 3: If integration-related
- Check integration profile resolution for the correct domain
- Verify credential record is active
- Check Twilio trial account limitations (verified caller IDs only)

## Step 4: Check scriptsync connection
```powershell
$r = & $api -InstanceDir $instanceDir -Command "check_connection"
$r.result | ConvertTo-Json
```
- `serverRunning: false` -- click sn-scriptsync in VS Code status bar
- `browserConnected: false` -- open SN Utils helper tab (type /token in ServiceNow)

## Step 5: Report findings with specific error messages and recommended fixes.
