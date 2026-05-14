# scriptsync-patch-check.ps1
#
# SessionStart hook (second group, runs after session-start.ps1). Keeps the
# sn-scriptsync multi-instance patch alive across extension auto-updates:
# silent when the live extension.js has the full patch, auto-reapplies when
# the extension was updated/replaced and the markers are wiped, warns when
# the patch is partial (upstream refactor touched some anchors but not all).
#
# Output goes to hookSpecificOutput.additionalContext so the user sees a
# one-line notice in the session-start banner -- only when there's something
# to say. Silent path is the happy path.

$ErrorActionPreference = 'Stop'

function Emit-Context($msg) {
    @{
        hookSpecificOutput = @{
            hookEventName = 'SessionStart'
            additionalContext = $msg
        }
    } | ConvertTo-Json -Depth 3
}

try {
    # Resolve the patcher script (plugin-relative). Hook PowerShell sessions
    # don't inherit the plugin bin/ on PATH, so go through $env:CLAUDE_PLUGIN_ROOT.
    $pluginRoot = $env:CLAUDE_PLUGIN_ROOT
    if (-not $pluginRoot) { $pluginRoot = Split-Path $PSScriptRoot -Parent }
    $patcher = Join-Path $pluginRoot 'bin\apply-snscriptsync-patch.ps1'
    if (-not (Test-Path $patcher)) { exit 0 }  # plugin install incomplete -- stay silent

    # Dot-source to get Get-ExpectedMarkerCount. The patcher returns early on
    # dot-source (via $MyInvocation.InvocationName -eq '.') so this is cheap.
    . $patcher
    $expected = Get-ExpectedMarkerCount

    # Find the live extension.js. Same three-root search as the patcher.
    $searchRoots = @(
        "$env:USERPROFILE\.antigravity\extensions",
        "$env:USERPROFILE\.vscode\extensions",
        "$env:USERPROFILE\.vscode-insiders\extensions"
    )
    $extDir = $searchRoots | Where-Object { Test-Path $_ } | ForEach-Object {
        Get-ChildItem $_ -Directory -Filter "arnoudkooicom.sn-scriptsync-*" -ErrorAction SilentlyContinue
    } | Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $extDir) { exit 0 }  # sn-scriptsync not installed -- not our problem
    $live = Join-Path $extDir.FullName 'out\extension.js'
    if (-not (Test-Path $live)) { exit 0 }

    $markers = (Select-String -Path $live -Pattern 'sn-scriptsync-multi-instance patch' -SimpleMatch -ErrorAction SilentlyContinue | Measure-Object).Count

    if ($markers -eq $expected) {
        # Fully patched -- happy path, stay silent.
        exit 0
    }

    if ($markers -eq 0) {
        # Extension was updated/replaced; markers wiped. Auto-reapply.
        # Use *> to suppress ALL streams (Write-Host writes to stream 6 in PS 5.1,
        # which 2>&1 | Out-Null does NOT catch).
        & $patcher -Path $live *> $null
        $reapplied = (Select-String -Path $live -Pattern 'sn-scriptsync-multi-instance patch' -SimpleMatch -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($reapplied -eq $expected) {
            Emit-Context "sn-scriptsync multi-instance patch was missing (extension likely auto-updated to $($extDir.Name)) -- reapplied automatically. Reload sn-scriptsync (status-bar toggle or Reload Window) to activate the patched code."
        } else {
            Emit-Context "sn-scriptsync multi-instance patch missing in $($extDir.Name) and auto-reapply did not complete cleanly (markers: $reapplied / $expected). Run apply-snscriptsync-patch.ps1 -DryRun manually to inspect; anchors may have shifted upstream."
        }
        exit 0
    }

    # Partial patch -- some anchors matched, some didn't. Don't auto-fix.
    Emit-Context "sn-scriptsync multi-instance patch is in a PARTIAL state ($markers / $expected markers) in $($extDir.Name). Upstream likely refactored one or more anchor blocks. Diff extension.js against extension.js.bak and update the anchor strings in bin/apply-snscriptsync-patch.ps1 before reapplying. Multi-instance routing may be broken until resolved."

} catch {
    # Never fail loud at session start -- the user can still work without the patch.
    Emit-Context "sn-scriptsync patch keepalive hook errored: $($_.Exception.Message). Multi-instance routing may not be active. Run apply-snscriptsync-patch.ps1 -DryRun to check state."
}
