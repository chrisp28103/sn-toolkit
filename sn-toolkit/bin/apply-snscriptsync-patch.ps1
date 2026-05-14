# apply-snscriptsync-patch.ps1
#
# Patches the installed sn-scriptsync extension to support MULTIPLE simultaneous
# helper-tab connections, each routed to its own ServiceNow instance.
#
# Original multi-instance routing patch by Matthew, ported into sn-toolkit
# v1.18.0 (2026-05-14). Logic preserved verbatim; the only additions are
# $ExpectedMarkers + Get-ExpectedMarkerCount so the SessionStart keepalive
# hook can verify patch state without hardcoding the count itself.
#
# Idempotent: detects existing patch markers and exits cleanly. Anchored by
# unique string literals (not line numbers) so it survives most upstream updates.
#
# Usage:
#   .\apply-snscriptsync-patch.ps1                # apply (creates .bak first)
#   .\apply-snscriptsync-patch.ps1 -DryRun        # show diff, don't write
#   .\apply-snscriptsync-patch.ps1 -Revert        # restore from .bak
#   .\apply-snscriptsync-patch.ps1 -Path <file>   # target a specific extension.js
#
# What it changes in out/extension.js:
#   1. Removes  `if (wss.clients.size > 1) { ws.close(0, 'Max connection'); }`
#   2. Stamps   `ws.instanceName` / `ws.instanceUrl` from the helper-tab's first
#               identifying message, so the server can route by instance.
#   3. Rewrites `broadcastToHelperTab` to route to the matching client when the
#               outbound message carries `instance.url`, falling back to legacy
#               broadcast for messages without instance info (e.g., CSS live-reload).
#   4. Passes   `ws.instanceUrl` into `relayErrorToAgent` and filters the loop so
#               `_last_error.json` only lands in the source instance's folder.

[CmdletBinding()]
param(
    [string]$Path,           # Optional. Auto-detected if omitted.
    [switch]$DryRun,
    [switch]$Revert
)

$ErrorActionPreference = 'Stop'
$Marker = '[sn-scriptsync-multi-instance patch]'
# Bump when adding/removing a patch block below. Single source of truth --
# the SessionStart keepalive hook and the /sn-toolkit:instance skill both
# dot-source this script and call Get-ExpectedMarkerCount instead of
# hardcoding the count themselves.
$ExpectedMarkers = 5

function Get-ExpectedMarkerCount { return $ExpectedMarkers }

function Read-AllText($p) { [System.IO.File]::ReadAllText($p) }
function Write-AllText($p, $t) { [System.IO.File]::WriteAllText($p, $t, [System.Text.UTF8Encoding]::new($false)) }

# When dot-sourced (e.g. by the SessionStart keepalive hook just to grab
# Get-ExpectedMarkerCount), return immediately so we don't print or do work.
# Anything below this line runs only when the script is invoked normally.
if ($MyInvocation.InvocationName -eq '.') { return }

# Auto-detect the live extension.js if -Path not provided. Searches both
# Antigravity and vanilla VS Code extension dirs, picks the newest sn-scriptsync.
if (-not $Path) {
    $searchRoots = @(
        "$env:USERPROFILE\.antigravity\extensions",
        "$env:USERPROFILE\.vscode\extensions",
        "$env:USERPROFILE\.vscode-insiders\extensions"
    )
    $extDir = $searchRoots | Where-Object { Test-Path $_ } | ForEach-Object {
        Get-ChildItem $_ -Directory -Filter "arnoudkooicom.sn-scriptsync-*" -ErrorAction SilentlyContinue
    } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($extDir) {
        $Path = Join-Path $extDir.FullName "out\extension.js"
        Write-Host "Auto-detected: $Path" -ForegroundColor DarkGray
    }
}

if (-not $Path -or -not (Test-Path $Path)) {
    Write-Host "sn-scriptsync extension not found." -ForegroundColor Red
    Write-Host "Searched: ~/.antigravity/extensions, ~/.vscode/extensions, ~/.vscode-insiders/extensions" -ForegroundColor Yellow
    Write-Host "Pass an explicit path with -Path '<full-path-to-extension.js>' if the install lives elsewhere." -ForegroundColor Yellow
    exit 1
}

$bakPath = "$Path.bak"

# ---------------------- REVERT MODE ----------------------
if ($Revert) {
    if (-not (Test-Path $bakPath)) {
        Write-Host "No backup found at $bakPath -- nothing to revert." -ForegroundColor Yellow
        exit 1
    }
    Copy-Item $bakPath $Path -Force
    Write-Host "Reverted $Path from $bakPath" -ForegroundColor Green
    exit 0
}

$src = Read-AllText $Path

# ---------------------- IDEMPOTENCY CHECK ----------------------
if ($src -match [regex]::Escape($Marker)) {
    Write-Host "Patch already applied (marker found). Nothing to do." -ForegroundColor Green
    exit 0
}

Write-Host "Patching: $Path" -ForegroundColor Cyan
$original = $src
$changes = @()

# ---------------------- PATCH 1: remove singleton guard ----------------------
$p1_old = @"
        if (wss.clients.size > 1) {
            ws.close(0, 'Max connection');
        }
"@
$p1_new = @"
        // $Marker singleton guard removed -- multiple helper tabs allowed
"@
if ($src.Contains($p1_old)) {
    $src = $src.Replace($p1_old, $p1_new)
    $changes += 'P1: removed wss.clients.size>1 guard'
} else {
    Write-Host "P1 anchor not found. Has the WS connection block changed upstream?" -ForegroundColor Red
    Write-Host "Looked for the literal 'Max connection' close-frame block." -ForegroundColor Red
    exit 2
}

# ---------------------- PATCH 2: stamp ws.instanceName / ws.instanceUrl ----------------------
$p2_old = @"
                if (messageJson?.instance)
                    eu.writeInstanceSettings(messageJson.instance);
"@
$p2_new = @"
                if (messageJson?.instance) {
                    eu.writeInstanceSettings(messageJson.instance);
                    // $Marker bind this ws connection to its source instance
                    ws.instanceName = messageJson.instance.name;
                    ws.instanceUrl = messageJson.instance.url;
                }
"@
if ($src.Contains($p2_old)) {
    $src = $src.Replace($p2_old, $p2_new)
    $changes += 'P2: stamped ws.instanceName/instanceUrl on identifying message'
} else {
    Write-Host "P2 anchor not found. Has the message handler changed upstream?" -ForegroundColor Red
    exit 2
}

# ---------------------- PATCH 3: route broadcastToHelperTab by instance.url ----------------------
$p3_old = @"
function broadcastToHelperTab(messageObj) {
    if (typeof messageObj === 'object') {
        messageObj.appName = vscode.env.appName || 'VS Code';
    }
    const message = JSON.stringify(messageObj);
    if (wss) {
        wss.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
                client.send(message);
            }
        });
    }
}
"@
$p3_new = @"
function broadcastToHelperTab(messageObj) {
    // $Marker route by instance.url when present; fall back to broadcast for legacy messages
    if (typeof messageObj === 'object') {
        messageObj.appName = vscode.env.appName || 'VS Code';
    }
    const message = JSON.stringify(messageObj);
    if (!wss) return;
    const targetUrl = messageObj && messageObj.instance && messageObj.instance.url;
    if (targetUrl) {
        let routed = 0;
        wss.clients.forEach(client => {
            if (client.readyState === WebSocket.OPEN && client.instanceUrl === targetUrl) {
                client.send(message);
                routed++;
            }
        });
        if (routed > 0) return;
        // No matching client (helper tab may be multiplexing multiple instances) -- fall through to broadcast.
        // Helper tab will route to the right ServiceNow tab using messageObj.instance.url itself.
        console.log('[sn-scriptsync] No ws stamped for ' + targetUrl + ' -- broadcasting (helper tab will route)');
    }
    // No instance info, OR routed-broadcast fallback -- send to all open clients
    wss.clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(message);
        }
    });
}
"@
if ($src.Contains($p3_old)) {
    $src = $src.Replace($p3_old, $p3_new)
    $changes += 'P3: broadcastToHelperTab routes by instance.url'
} else {
    Write-Host "P3 anchor not found. Has broadcastToHelperTab been refactored upstream?" -ForegroundColor Red
    exit 2
}

# ---------------------- PATCH 4a: pass ws.instanceUrl into relayErrorToAgent ----------------------
$p4a_old = @"
                    // Relay error to Agent API - write to _last_error.json in all instance folders
                    relayErrorToAgent(errorDetail, messageJson);
"@
$p4a_new = @"
                    // $Marker pass source instance so error only lands in the right folder
                    relayErrorToAgent(errorDetail, messageJson, ws.instanceUrl);
"@
if ($src.Contains($p4a_old)) {
    $src = $src.Replace($p4a_old, $p4a_new)
    $changes += 'P4a: relayErrorToAgent call site forwards ws.instanceUrl'
} else {
    Write-Host "P4a anchor not found. Has the error relay call site changed?" -ForegroundColor Red
    exit 2
}

# ---------------------- PATCH 4b: filter relayErrorToAgent body ----------------------
$p4b_old = @"
function relayErrorToAgent(errorMessage, rawError) {
    try {
        // Find instance folders in workspace and write error to each
        const workspaceRoot = vscode.workspace.rootPath || '';
        const folders = fs.readdirSync(workspaceRoot, { withFileTypes: true })
            .filter(d => d.isDirectory() && !d.name.startsWith('.'));
        for (const folder of folders) {
            const settingsPath = path.join(workspaceRoot, folder.name, '_settings.json');
            const oldSettingsPath = path.join(workspaceRoot, folder.name, 'settings.json');
            // Only write to instance folders (those with settings files)
            if (fs.existsSync(settingsPath) || fs.existsSync(oldSettingsPath)) {
"@
$p4b_new = @"
function relayErrorToAgent(errorMessage, rawError, sourceInstanceUrl) {
    try {
        // Find instance folders in workspace and write error to each
        const workspaceRoot = vscode.workspace.rootPath || '';
        const folders = fs.readdirSync(workspaceRoot, { withFileTypes: true })
            .filter(d => d.isDirectory() && !d.name.startsWith('.'));
        for (const folder of folders) {
            const settingsPath = path.join(workspaceRoot, folder.name, '_settings.json');
            const oldSettingsPath = path.join(workspaceRoot, folder.name, 'settings.json');
            // Only write to instance folders (those with settings files)
            if (fs.existsSync(settingsPath) || fs.existsSync(oldSettingsPath)) {
                // $Marker if we know which instance errored, skip all others
                if (sourceInstanceUrl) {
                    try {
                        const _sp = fs.existsSync(settingsPath) ? settingsPath : oldSettingsPath;
                        const _settings = JSON.parse(fs.readFileSync(_sp, 'utf8'));
                        if (_settings && _settings.url && _settings.url !== sourceInstanceUrl) continue;
                    } catch (_e) { /* fall through and write anyway */ }
                }
"@
if ($src.Contains($p4b_old)) {
    $src = $src.Replace($p4b_old, $p4b_new)
    $changes += 'P4b: relayErrorToAgent filters by sourceInstanceUrl'
} else {
    Write-Host "P4b anchor not found. Has relayErrorToAgent been refactored?" -ForegroundColor Red
    exit 2
}

# ---------------------- WRITE OR DRY-RUN ----------------------
if ($src -eq $original) {
    Write-Host "No changes produced -- bailing." -ForegroundColor Yellow
    exit 3
}

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN -- no file written. Changes that would be applied:" -ForegroundColor Yellow
    foreach ($c in $changes) { Write-Host "  + $c" -ForegroundColor Green }
    Write-Host ""
    Write-Host ("Original size: {0} chars" -f $original.Length)
    Write-Host ("Patched size:  {0} chars" -f $src.Length)
    exit 0
}

# Back up original on first apply (don't overwrite an existing .bak)
if (-not (Test-Path $bakPath)) {
    Copy-Item $Path $bakPath
    Write-Host "Backed up original to: $bakPath" -ForegroundColor Cyan
}

Write-AllText $Path $src
Write-Host ""
Write-Host "Patch applied successfully:" -ForegroundColor Green
foreach ($c in $changes) { Write-Host "  + $c" -ForegroundColor Green }
Write-Host ""
Write-Host "Restart sn-scriptsync (toggle the status-bar item, or reload VS Code) to pick up the changes." -ForegroundColor Cyan
