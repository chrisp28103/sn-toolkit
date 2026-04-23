---
description: Refresh the project's reference architecture -- re-extract schema and scripts from the instance. Use when the user asks to refresh docs, re-extract schema, or update the architecture reference.
---

## Steps

This command runs the project-specific architecture refresh script. Convention: each SN project provides a `scripts\refresh-architecture.ps1` that extracts schema and scripts from its instance into `docs/architecture/`.

1. Locate and run the project's refresh script (resolve `<PROJECT_DIR>` from the current workspace -- typically `(Get-Location).Path`):
```powershell
$script = Join-Path "<PROJECT_DIR>" "scripts\refresh-architecture.ps1"
if (Test-Path $script) {
    & $script
} else {
    Write-Host "No scripts\refresh-architecture.ps1 found in this project."
    Write-Host "This command requires a project-specific refresh script. See docs/reference/ for an example."
}
```

2. The script typically extracts:
   - Table/field schema for all tables in the project scope
   - All Script Includes, Business Rules, Client Scripts, Widgets
   - Choice lists, relationship definitions

3. Results are saved to `docs/architecture/`

4. After extraction, update `docs/architecture/overview.md` with any new tables or significant changes.

## Note
If your project does not yet have `scripts\refresh-architecture.ps1`, the plugin does not prescribe its exact contents -- each project's scope and refresh needs differ. See any existing project's `scripts\refresh-architecture.ps1` for a working example, or write your own tailored to your scope's tables.
