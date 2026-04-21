# SessionStart hook -- auto-connect to ServiceNow and inject session state into Claude's context.
# Output goes to hookSpecificOutput.additionalContext so Claude sees the connection state
# at the start of every session. The VS Code extension does not render this as a user-facing
# banner -- it is consumed by Claude, who surfaces warnings in the first response if relevant.
#
# No-ops silently in non-SN projects (no instances/ dir).

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { exit 0 }

. "$PSScriptRoot\_common.ps1"
$instanceDir = Resolve-SnInstance -ProjectDir $projectDir
if (-not $instanceDir) { exit 0 }

$api = Get-SnAgentApiPath

try {
    $r = & $api -InstanceDir $instanceDir.FullName -Command 'check_connection'
    $srv = $r.result.serverRunning
    $brw = $r.result.browserConnected

    & $api -InstanceDir $instanceDir.FullName -Command 'clear_last_error' | Out-Null

    $msg = "SN Session ($($instanceDir.Name)): server=$srv, browser=$brw, errors cleared."
    if (-not $srv) { $msg += ' WARNING: scriptsync server not running -- click sn-scriptsync in VS Code status bar.' }
    if (-not $brw) { $msg += ' WARNING: browser not connected -- open SN Utils helper tab.' }

    @{
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
            additionalContext = $msg
        }
    } | ConvertTo-Json -Depth 3
} catch {
    $errMsg = "SN Session Init FAILED ($($instanceDir.Name)): $($_.Exception.Message). Run /sn-toolkit:creds or check VPN."
    @{
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
            additionalContext = $errMsg
        }
    } | ConvertTo-Json -Depth 3
}
