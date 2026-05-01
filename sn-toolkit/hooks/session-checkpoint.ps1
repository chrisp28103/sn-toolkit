param([Parameter(Mandatory=$true)][ValidateSet('Stop','PostCompact')][string]$Event)

# Session checkpoint -- Stop checks for async errors, PostCompact re-injects scratchpad state.
# Portable across all SN workspaces: auto-detects instance from $env:CLAUDE_PROJECT_DIR.

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { exit 0 }

. "$PSScriptRoot\_common.ps1"
$instanceDir = Resolve-SnInstance -ProjectDir $projectDir
if (-not $instanceDir) { exit 0 }

if ($Event -eq 'Stop') {
    # Stop loop guard: read stdin to check stop_hook_active. If true, the hook
    # already blocked once on this turn; allow exit so the user can actually leave.
    # If stdin is unavailable or unparseable, fall through to normal logic.
    try {
        $stdin = [Console]::In.ReadToEnd()
        if ($stdin) {
            $hookData = $stdin | ConvertFrom-Json -ErrorAction Stop
            if ($hookData.stop_hook_active -eq $true) { exit 0 }
        }
    } catch { }

    # Gate: only run checks if SN activity happened this turn. The agent/responses
    # directory mtime reflects the last API round-trip; if it's stale, Claude did non-SN
    # work (docs, code reads, conversation) and there is no pending state to verify.
    $responsesDir = Join-Path $instanceDir.FullName 'agent\responses'
    if (-not (Test-Path $responsesDir)) { exit 0 }

    $newest = Get-ChildItem $responsesDir -File -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending |
              Select-Object -First 1
    if (-not $newest -or ((Get-Date) - $newest.LastWriteTime).TotalMinutes -gt 5) {
        exit 0
    }

    $api = Get-SnAgentApiPath
    $blockReasons = @()

    # Check 1: pending sync queue. get_sync_status returns the scriptsync queue
    # state; non-zero pending means file edits have not landed on the instance yet.
    try {
        $r = & $api -InstanceDir $instanceDir.FullName -Command 'get_sync_status' 2>$null
        if ($r -and $r.result) {
            $pending = $null
            if ($null -ne $r.result.pending) { $pending = [int]$r.result.pending }
            elseif ($null -ne $r.result.queue_length) { $pending = [int]$r.result.queue_length }
            elseif ($null -ne $r.result.queue) { $pending = [int]$r.result.queue }
            if ($pending -and $pending -gt 0) {
                $blockReasons += "scriptsync queue has $pending pending file write(s) -- run sync_now to flush"
            }
        }
    } catch { }

    # Check 2: unread async error from last operation (existing behavior, now elevated to block).
    try {
        $r = & $api -InstanceDir $instanceDir.FullName -Command 'get_last_error' 2>$null
        if ($r.result -and $r.result -ne 'null' -and $r.result -ne '' -and $null -ne $r.result) {
            $detail = $r.result | ConvertTo-Json -Compress -Depth 3
            $blockReasons += "unread SN async error: $detail"
        }
    } catch { }

    if ($blockReasons.Count -gt 0) {
        $reason = "Cannot end session cleanly. Resolve before stopping:`n - " +
                  ($blockReasons -join "`n - ") +
                  "`n`nTypical fix: get_sync_status -> sync_now -> get_last_error -> clear_last_error"
        $sysMsg = "sn-toolkit: $($blockReasons.Count) sync issue(s) pending; Stop blocked"
        @{
            decision      = 'block'
            reason        = $reason
            systemMessage = $sysMsg
        } | ConvertTo-Json -Depth 3
    }
    # Silent on success: existing behavior preserved.
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
