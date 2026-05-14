# inject-instance-context.ps1
#
# UserPromptSubmit hook. Runs on every prompt the user sends. Reads
# .claude/project.json's "instance" field and prefixes the prompt with
# [Active SN instance: <name>] so multi-turn work can't drift to the
# wrong instance.
#
# Stdout becomes additionalContext for Claude. Keep terse -- this runs on
# every message.
#
# Behavior:
#   - No project.json, or no "instance" field        -> silent (no nag)
#   - "instance" set + instances/<name>/_settings.json exists -> emit pin
#   - "instance" set + folder missing                -> emit warning so user knows to fix

$ErrorActionPreference = 'SilentlyContinue'

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { exit 0 }

$projectJson = Join-Path $projectDir '.claude\project.json'
if (-not (Test-Path $projectJson)) { exit 0 }

try {
    $cfg = Get-Content $projectJson -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch { exit 0 }

$instance = [string]$cfg.instance
if (-not $instance) { exit 0 }

$settingsPath = Join-Path $projectDir "instances\$instance\_settings.json"
if (-not (Test-Path $settingsPath)) {
    Write-Output "[sn-instance] .claude/project.json names instance '$instance' but instances\$instance\_settings.json is missing. Run /sn-toolkit:instance to re-pick a valid instance before pushing."
    exit 0
}

Write-Output "[Active SN instance: $instance] -- pushes/edits/creates should target this instance unless the user explicitly says otherwise."
