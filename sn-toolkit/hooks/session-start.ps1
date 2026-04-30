# SessionStart hook -- snapshot SN connection state at session start so Claude knows
# whether scriptsync + helper tab are reachable. Output goes to
# hookSpecificOutput.additionalContext.
#
# IMPORTANT: this is a snapshot at the exact moment Claude Code spawned. The helper-tab
# websocket and agent watcher can be mid-handshake right then, so we retry once before
# declaring failure. The message tells Claude to re-verify via `check_connection` before
# deferring real work -- the snapshot is informational, not authoritative.
#
# No-ops silently in non-SN projects (no instances/ dir).

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { exit 0 }

. "$PSScriptRoot\_common.ps1"
$instanceDir = Resolve-SnInstance -ProjectDir $projectDir
if (-not $instanceDir) { exit 0 }

$api = Get-SnAgentApiPath

function Get-SnConnectionSnapshot {
    param(
        [Parameter(Mandatory)][string]$ApiPath,
        [Parameter(Mandatory)][string]$Dir,
        [int]$TimeoutSec = 5
    )
    $r = & $ApiPath -InstanceDir $Dir -Command 'check_connection' -TimeoutSeconds $TimeoutSec 2>$null
    if ($null -eq $r) { return @{ gotResponse = $false; srv = $null; brw = $null } }
    return @{
        gotResponse = $true
        srv = [bool]$r.result.serverRunning
        brw = [bool]$r.result.browserConnected
    }
}

try {
    $state = Get-SnConnectionSnapshot -ApiPath $api -Dir $instanceDir.FullName -TimeoutSec 5

    # Retry once if anything looks off -- handles transient race where the agent watcher
    # or helper-tab websocket is still wiring up. Happy path (both true) skips the retry.
    if (-not $state.gotResponse -or -not $state.srv -or -not $state.brw) {
        Start-Sleep -Seconds 2
        $state = Get-SnConnectionSnapshot -ApiPath $api -Dir $instanceDir.FullName -TimeoutSec 5
    }

    & $api -InstanceDir $instanceDir.FullName -Command 'clear_last_error' -TimeoutSeconds 5 2>$null | Out-Null

    # Wipe the instance-pivot cache so this session probes fresh on its first Edit/Write.
    # Stale cache from a prior session could mask a helper-tab pivot done while idle.
    Clear-CachedLiveInstance -ProjectDir $projectDir

    $reverify = "Before deferring SN work or telling the user the connection is down, re-verify yourself by running ``check_connection`` -- this hook is a snapshot, not the current state."

    if (-not $state.gotResponse) {
        $msg = "SN Session ($($instanceDir.Name)) startup snapshot: agent API did not respond within timeout. $reverify If still unreachable after re-verify: scriptsync may not be running (click sn-scriptsync in VS Code status bar) or helper tab not open (open SN Utils helper, type /token in ServiceNow)."
    } else {
        $statusLine = "server=$($state.srv), browser=$($state.brw)"
        $msg = "SN Session ($($instanceDir.Name)) startup snapshot: $statusLine, errors cleared."
        if (-not $state.srv -or -not $state.brw) {
            $msg += " $reverify"
            if (-not $state.srv) { $msg += " If still false after re-verify: scriptsync server not running -- ask user to click sn-scriptsync in VS Code status bar." }
            if (-not $state.brw) { $msg += " If still false after re-verify: helper tab not connected -- ask user to open SN Utils helper tab (type /token in ServiceNow)." }
        }
    }

    @{
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
            additionalContext = $msg
        }
    } | ConvertTo-Json -Depth 3
} catch {
    $errMsg = "SN Session Init hook errored ($($instanceDir.Name)): $($_.Exception.Message). Re-verify by running ``check_connection`` before reporting connection failure to the user -- the hook can fail in benign ways (agent watcher booting). If persistent: run /sn-toolkit:creds or check VPN."
    @{
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
            additionalContext = $errMsg
        }
    } | ConvertTo-Json -Depth 3
}
