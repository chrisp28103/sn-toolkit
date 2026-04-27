---
paths:
  - "**/*.js"
  - "**/*.ps1"
  - "**/*.md"
  - "**/*.html"
  - "**/*.scss"
  - "**/*.json"
---

# Global Conventions

These rules apply to ALL output -- code, documentation, ServiceNow records, and chat responses.

## Character Encoding

**ASCII only (U+0000-U+007F).** No em/en dashes, smart quotes, or ellipsis characters. Use `--`, `-`, straight quotes, and `...` respectively. Applies to all output: scripts, APIs, markdown, PowerShell, comments, chat.

## PowerShell Output Handling

Never pipe SN query results with script/long-text fields to console (truncation causes wasteful re-queries). Save to file, then read back with `Get-Content -Raw`.

## UTF-8 Without BOM

All files written to the workspace must be saved as UTF-8 without BOM. In PowerShell:
```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("<path>", $content, $utf8NoBom)
```
NEVER use `Out-File -Encoding utf8` or `Set-Content -Encoding UTF8` -- they add BOM bytes that corrupt ServiceNow scripts. The PostToolUse hook blocks both forms.

## Canonical Query-and-Save Snippet

For any Agent API `query_records` call that returns script fields, long text, or >5 records, use this exact pattern to avoid console truncation and BOM corruption:

```powershell
$outFile = "$instanceDir\agent\tmp\<purpose>_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$r = & $api -InstanceDir $instanceDir -Command "query_records" -Params @{
    table = "<TABLE>"
    query = "<encoded query>"
    fields = "<comma-separated fields>"
    limit = <N>
}
$json = $r.result.records | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($outFile, $json, (New-Object System.Text.UTF8Encoding($false)))
$records = Get-Content -Raw $outFile | ConvertFrom-Json
```

Commands (`pull`, `list`, `audit`, `export`, `review`, `view-response`, `diagnose`, `refine`, `inspect`) all follow this exact shape -- only the `table` / `query` / `fields` / `limit` vary. If you ever catch yourself writing `| Out-File -Encoding utf8` or `| ConvertTo-Json | Out-File`, stop and use the snippet above.

## Table scope vs record scope

A table being in `global` scope does NOT mean its records are global. Many OOB tables are deliberately designed to hold records belonging to scoped applications via the record's own `sys_scope` field. Update set capture follows the **record's** scope, not the table's.

Examples of OOB global-scope tables that commonly carry scoped records:
- `sys_security_acl` and `sys_security_acl_role`
- `sys_homepage_destination_rule`
- `user_criteria`
- `sys_properties`
- `sys_dictionary` (e.g. when a scoped app extends a global table)
- `sys_choice`
- `sysauto_script` (scheduled jobs)

Implication: when planning a write to one of these tables, query the **target record's** `sys_scope` first. Don't infer from the table. If you want a change to ride in a scoped app's update set, the user needs the matching scope's update set active -- a global update set won't capture writes to records whose `sys_scope` is a custom app, and vice versa.

When creating a new record on one of these tables via `create_artifact`, pass `scope = '<target_app_scope>'` explicitly. The `create_artifact` command sets `sys_scope` on the new record from that parameter.

## No silent REST fallback when Agent API fails

When a `create_artifact` / `update_record` call returns `status=success` but the change doesn't actually land (read-back shows record unchanged, or no `sys_update_xml` row appears), STOP. Do not pivot to direct `Invoke-RestMethod -Method Patch/Post/Delete` to "make it work."

Agent API silently failing is almost always a context mismatch: app scope, update set selection, missing role (e.g. `security_admin` for ACL writes, `maint` for OOB-locked records), or a stale browser session token. Direct REST bypasses these guards and can land changes in the wrong update set, in the global Default, or as ungoverned writes that defeat the migration discipline.

The right response is to surface the issue: tell the user what was attempted, what came back, what the record state actually is, and the most likely cause. Let the user resolve the context (switch update set / scope, elevate, refresh helper tab) and retry. Direct REST is appropriate only when the user has explicitly authorized it for a specific write, or when the operation is read-only diagnostic.
