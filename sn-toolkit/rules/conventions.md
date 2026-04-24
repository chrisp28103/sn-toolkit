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
