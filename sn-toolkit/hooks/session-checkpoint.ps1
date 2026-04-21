param([Parameter(Mandatory=$true)][ValidateSet('Stop','PostCompact')][string]$Event)

# Session checkpoint -- Stop checks for async errors, PostCompact re-injects scratchpad state.
# Portable across all SN workspaces: auto-detects instance from $env:CLAUDE_PROJECT_DIR.

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { exit 0 }

. "$PSScriptRoot\_common.ps1"
$instanceDir = Resolve-SnInstance -ProjectDir $projectDir
if (-not $instanceDir) { exit 0 }

if ($Event -eq 'Stop') {
    $api = Get-SnAgentApiPath
    try {
        $r = & $api -InstanceDir $instanceDir.FullName -Command 'get_last_error'
        if ($r.result -and $r.result -ne 'null' -and $r.result -ne '' -and $null -ne $r.result) {
            $detail = $r.result | ConvertTo-Json -Compress -Depth 3
            @{ systemMessage = "WARNING: SN async error detected: $detail" } | ConvertTo-Json -Depth 3
        }
        # Silent on success
    } catch {
        # Silent on failure -- do not block stop
    }
    exit 0
}

if ($Event -eq 'PostCompact') {
    $notesFile = Join-Path $projectDir 'scratch\session-notes.md'
    if (-not (Test-Path $notesFile)) { exit 0 }

    # Freshness gate -- skip notes older than 6 hours (likely stale from prior session)
    $age = (Get-Date) - (Get-Item $notesFile).LastWriteTime
    if ($age.TotalHours -gt 6) { exit 0 }

    # Read up to 20 lines (caps the injection at roughly 1-2 KB)
    $lines = Get-Content $notesFile -TotalCount 20 -ErrorAction SilentlyContinue
    $body = ($lines -join "`n").Trim()
    if (-not $body) { exit 0 }

    $msg = "POST-COMPACT SCRATCHPAD (scratch/session-notes.md, first 20 lines):`n" + $body
    @{ systemMessage = $msg } | ConvertTo-Json -Depth 3
    exit 0
}
