---
description: Set, switch, or display the active ServiceNow instance for the current project. Writes to .claude/project.json's "instance" field, which the UserPromptSubmit hook reads to pin every prompt with "[Active SN instance: X]". Use when the user says "switch to <instance>", "what instance are we on", or starts a session in a multi-instance workspace.
model: sonnet
effort: low
allowed-tools: [Read, Bash]
---

$ARGUMENTS is optional. Forms:
- `/sn-toolkit:instance`               -- list available instances, show current, ask user
- `/sn-toolkit:instance ahadev`        -- pin to `ahadev`
- `/sn-toolkit:instance show`          -- display current pin only, no prompt

## Why this exists

Multi-instance routing (v1.18.0) lets two or more helper tabs stay connected to sn-scriptsync at once. Without an explicit pin, Claude can't tell which instance a push, edit, or create should target -- the file path alone disambiguates reads but not always writes.

This skill writes the chosen instance name to `.claude/project.json`'s `instance` field. The UserPromptSubmit hook (`hooks/inject-instance-context.ps1`) reads that field every turn and prefixes the prompt with `[Active SN instance: <name>]`. The pin survives across turns and across compaction.

## Step 1: Parse $ARGUMENTS

Three cases:
- Empty -> Case A (list + prompt)
- `show` / `current` / `?` -> Case B (display only)
- Anything else -> Case C (pin the named instance)

## Step 2: Read current state

```powershell
$projectJson = ".claude\project.json"
if (Test-Path $projectJson) {
    $cfg = Get-Content $projectJson -Raw | ConvertFrom-Json
    $current = $cfg.instance
} else {
    $current = $null
}

# List instance dirs (subfolders of instances/ that contain _settings.json)
$candidates = if (Test-Path 'instances') {
    Get-ChildItem 'instances' -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName '_settings.json')
    } | Select-Object -ExpandProperty Name
} else { @() }

$current
$candidates
```

## Step 3: Branch on case

### Case A -- no argument

If `$candidates` is empty: tell the user there are no instances under `instances/`. Suggest `/sn-toolkit:new-project` if this is a fresh project. Exit.

If `$candidates` has one entry: confirm with the user whether to pin it. If yes, write it (Step 4).

If `$candidates` has multiple: use `AskUserQuestion` to show the options. Include the current pin (if any) in the question text. After the user picks, write it (Step 4).

### Case B -- "show" / "current" / "?"

Report `$current` (or "not set"). Also list `$candidates` so the user knows what's available. Done -- no write.

### Case C -- explicit name

Validate: the argument must appear in `$candidates`. If not, list the available options and ask the user to pick a valid one. Do NOT silently fall through to a fuzzy match.

If valid, write it (Step 4).

## Step 4: Persist to project.json

Preserve every other field in `project.json`. Use PowerShell, not string substitution -- the file may have nested objects (e.g. `instances`, `devUrl`, scope config) we mustn't clobber.

```powershell
$projectJson = ".claude\project.json"
$cfg = if (Test-Path $projectJson) {
    Get-Content $projectJson -Raw | ConvertFrom-Json
} else {
    [PSCustomObject]@{}
}

# Add or update the instance property
if ($cfg.PSObject.Properties.Name -contains 'instance') {
    $cfg.instance = '<NAME>'
} else {
    $cfg | Add-Member -NotePropertyName 'instance' -NotePropertyValue '<NAME>'
}

# Ensure the parent dir exists, then write back
$dir = Split-Path $projectJson -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$cfg | ConvertTo-Json -Depth 12 | Set-Content $projectJson -Encoding utf8
```

## Step 5: Confirm

Report tersely:
- `Active SN instance set to ahadev. The UserPromptSubmit hook will pin every prompt with [Active SN instance: ahadev] until you change this.`

If the user is already actively working (mid-conversation switch), add a one-line caution: `Pin takes effect on your NEXT prompt -- this turn already happened.`

## Gotchas

- `.claude/project.json` is committed to the repo by default. If teammates work on different instances, decide as a team whether `instance` belongs in committed config or in a per-developer override (e.g. `project.local.json`). v1.18.0 ships only the committed-config path; the per-dev override is future work.
- The pin is INSTRUCTION, not enforcement. Claude reads `[Active SN instance: X]` and SHOULD target that instance, but a tool call that explicitly names a different `-InstanceDir` will still execute. For hard enforcement (block prod writes when active is dev, etc.), that's v1.19+ tool-guard work.
- If the named instance folder doesn't exist, the UserPromptSubmit hook emits a warning instead of the pin. Run `/sn-toolkit:instance` (no arg) to re-pick.

## Related

- Hook: `hooks/inject-instance-context.ps1` (UserPromptSubmit pin)
- Hook: `hooks/scriptsync-patch-check.ps1` (keeps the multi-instance WS patch alive)
- Patcher: `bin/apply-snscriptsync-patch.ps1` (the WebSocket-server patch itself)
- Field: `.claude/project.json` -> `"instance": "<name>"`
