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

Never pipe SN query results with script/long-text fields to console (truncation causes wasteful re-queries). Save to file, then read back with `Get-Content -Raw`. See `docs/reference/sn-scriptsync-reference.md` for the full anti-truncation pattern.

## UTF-8 Without BOM

All files written to the workspace must be saved as UTF-8 without BOM. In PowerShell:
```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText("<path>", $content, $utf8NoBom)
```
NEVER use `Out-File -Encoding utf8` or `Set-Content -Encoding UTF8` -- they add BOM bytes that corrupt ServiceNow scripts.
