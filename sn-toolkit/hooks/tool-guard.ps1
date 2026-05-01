param([Parameter(Mandatory=$true)][ValidateSet('PreToolUse','PostToolUse')][string]$Event)

# Tool guard -- PreToolUse blocks unsafe ops, PostToolUse validates encoding.
# Portable across all SN workspaces: auto-detects the sync dir from instances/<name>/.
# Exit 2 = blocking error (prevents tool execution / forces Claude to fix).

$projectDir = $env:CLAUDE_PROJECT_DIR
if (-not $projectDir) { exit 0 }

. "$PSScriptRoot\_common.ps1"
$instanceDir = Resolve-SnInstance -ProjectDir $projectDir
if (-not $instanceDir) { exit 0 }

# Sync-dir root: always <projectDir>/<instance-name>/ (sibling of instances/).
$syncRoot = Join-Path $projectDir $instanceDir.Name
$syncRootForward = ($syncRoot -replace '\\', '/').TrimEnd('/')

$hookData = [Console]::In.ReadToEnd() | ConvertFrom-Json

function Test-PathInSyncRoot {
    param([string]$FilePath)
    if (-not $FilePath) { return $false }
    $normalized = ($FilePath -replace '\\', '/')
    return $normalized -like "$syncRootForward/*"
}

if ($Event -eq 'PreToolUse') {
    $toolName = $hookData.tool_name

    # Guard 0 (runs FIRST for Edit/Write): scriptsync target-pivot detection.
    # When the user flips sn-scriptsync's helper tab to a different instance mid-session,
    # editing a local file under <pathInstance>/ can cross-write to <liveInstance>.
    # This block probes the live instance and BLOCKS on mismatch. Cached for 30s to avoid
    # probing every keystroke edit. SessionStart wipes the cache so each session probes fresh.
    if ($toolName -eq 'Edit' -or $toolName -eq 'Write') {
        $filePath = $hookData.tool_input.file_path
        $pathInstance = Get-PathImpliedInstance -FilePath $filePath -ProjectDir $projectDir
        if ($pathInstance) {
            $live = Get-CachedLiveInstance -ProjectDir $projectDir -TtlSeconds 30
            if (-not $live) {
                $probeDir = Join-Path (Join-Path $projectDir 'instances') $pathInstance
                $probe = Invoke-LiveInstanceProbe -InstanceDir $probeDir -TimeoutSec 4
                if (-not $probe.ok) {
                    $msg = "BLOCKED: cannot verify scriptsync helper-tab instance (probe failed).`n" +
                           "About to edit a file under '$pathInstance/' but cannot confirm the helper tab is on '$pathInstance'.`n" +
                           "Risk: silent cross-instance write if scriptsync's helper tab has been flipped to a different target.`n" +
                           "Fix:`n" +
                           "  (a) run check_connection to diagnose helper-tab connectivity, then retry`n" +
                           "  (b) use Agent API directly with explicit -InstanceDir for the correct target"
                    [Console]::Error.WriteLine($msg)
                    exit 2
                }
                $live = $probe.live
                if ($live -eq $pathInstance) {
                    Set-CachedLiveInstance -ProjectDir $projectDir -LiveInstance $live
                }
            }
            if ($live -ne $pathInstance) {
                $msg = "BLOCKED: scriptsync helper tab is on '$live', but the edit target is '$pathInstance'.`n" +
                       "Risk of cross-instance write -- editing a file under '$pathInstance/' while scriptsync syncs to '$live'.`n" +
                       "Fix:`n" +
                       "  (a) flip scriptsync's helper tab back to '$pathInstance' (open SN Utils helper on $pathInstance.service-now.com), then retry`n" +
                       "  (b) use Agent API directly with -InstanceDir for the intended target`n" +
                       "  (c) if intentional cross-instance work, edit the file under instances/$live/ instead of $pathInstance/"
                [Console]::Error.WriteLine($msg)
                exit 2
            }
        }
        # Edit has no further PreToolUse guards; Write falls through to Guard 1.
        if ($toolName -eq 'Edit') { exit 0 }
    }

    # Guard 1: Write tool -- protect the sync directory
    if ($toolName -eq 'Write') {
        $filePath = $hookData.tool_input.file_path
        if (Test-PathInSyncRoot $filePath) {
            $fileName = [System.IO.Path]::GetFileName($filePath)
            $ext = [System.IO.Path]::GetExtension($filePath)

            $allowedExt = @('.js','.html','.scss','.css','.xml')
            if ($ext -notin $allowedExt) {
                $msg = "BLOCKED: '$fileName' (extension '$ext') is not a valid sn-scriptsync file type.`n" +
                       "Only .js, .html, .scss, .css, .xml belong in $($instanceDir.Name)/.`n" +
                       "Use instances/$($instanceDir.Name)/ for local working files, scratch/ for debug artifacts."
                [Console]::Error.WriteLine($msg)
                exit 2
            }

            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $configFields = @('collection','when','active','order','action_insert',
                'action_update','action_delete','action_query','priority','http_method','table')
            $parts = $baseName -split '\.'
            if ($parts.Count -ge 2 -and $parts[-1] -in $configFields) {
                $field = $parts[-1]
                $msg = "BLOCKED: '$fileName' looks like a config field file ('$field').`n" +
                       "Config fields (collection, when, active, order, etc.) must be set via Agent API update_record, NOT as files."
                [Console]::Error.WriteLine($msg)
                exit 2
            }
        }
        exit 0
    }

    # Guard 2: Bash tool -- block BOM-producing commands.
    # Strip heredocs and quoted strings before matching, so describing the bad
    # pattern inside a commit message or echo does not false-positive.
    if ($toolName -eq 'Bash') {
        $cmd = $hookData.tool_input.command
        $stripped = $cmd
        # PowerShell literal here-string: @'...'@
        $stripped = [regex]::Replace($stripped, "(?s)@'.*?'@", '')
        # PowerShell expandable here-string: @"..."@
        $stripped = [regex]::Replace($stripped, '(?s)@".*?"@', '')
        # Bash quoted heredoc: <<'EOF' ... EOF
        $stripped = [regex]::Replace($stripped, "(?s)<<'(\w+)'.*?\r?\n\1\b", '')
        # Bash unquoted heredoc: <<EOF ... EOF
        $stripped = [regex]::Replace($stripped, "(?s)<<(\w+)\b.*?\r?\n\1\b", '')
        # Single-quoted strings
        $stripped = [regex]::Replace($stripped, "'[^']*'", '')
        # Double-quoted strings
        $stripped = [regex]::Replace($stripped, '"[^"]*"', '')

        if ($stripped -match 'Out-File\s.*-Encoding\s+utf8' -or
            $stripped -match 'Set-Content\s.*-Encoding\s+(UTF8|utf8)') {
            $msg = "BLOCKED: Out-File/Set-Content with -Encoding utf8 adds BOM bytes that corrupt SN files.`n" +
                   "Use instead: [System.IO.File]::WriteAllText(`$path, `$content, (New-Object System.Text.UTF8Encoding(`$false)))"
            [Console]::Error.WriteLine($msg)
            exit 2
        }
        exit 0
    }

    exit 0
}

if ($Event -eq 'PostToolUse') {
    $filePath = $null
    if ($hookData.tool_input.file_path) {
        $filePath = $hookData.tool_input.file_path
    } else {
        exit 0
    }

    if (-not (Test-PathInSyncRoot $filePath)) { exit 0 }

    $ext = [System.IO.Path]::GetExtension($filePath)
    if ($ext -notin '.js','.html','.scss','.css','.xml') { exit 0 }

    if (-not (Test-Path $filePath)) { exit 0 }

    $errors = @()

    # BOM detection (first 3 bytes)
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $errors += "BOM DETECTED -- UTF-8 BOM bytes corrupt SN scripts. Rewrite without BOM."
    }

    # Non-ASCII scan
    $content = [System.IO.File]::ReadAllText($filePath)
    $lineNum = 0
    foreach ($line in $content -split "`n") {
        $lineNum++
        $chars = [char[]]$line | Where-Object { [int]$_ -gt 127 }
        if ($chars) {
            $hex = ($chars | ForEach-Object { 'U+{0:X4}' -f [int]$_ }) -join ', '
            $sample = ($chars | ForEach-Object { $_ }) -join ''
            $errors += "Line ${lineNum}: non-ASCII chars ($hex) -- '$sample'"
        }
    }

    if ($errors.Count -gt 0) {
        $fileName = [System.IO.Path]::GetFileName($filePath)
        $msg = "BLOCKED: $fileName has encoding violations:`n" + ($errors -join "`n") +
               "`nFix: replace smart quotes with straight quotes, em/en dashes with --, ellipsis with ..."
        [Console]::Error.WriteLine($msg)
        exit 2
    }

    # SN security pattern scan -- non-blocking warnings via PostToolUse exit 2.
    # PostToolUse exit 2 does NOT reverse the edit; it surfaces stderr to Claude as
    # feedback on the next turn so it can fix the introduced issue.
    # Patterns are conservative; false positives go through to Claude as advisories,
    # not hard fails.
    $warnings = @()

    if ($ext -eq '.js') {
        if ($content -match '\bgs\.evaluate\s*\(') {
            $warnings += "gs.evaluate() runs arbitrary scripts -- prefer explicit logic or GlideScopedEvaluator"
        }
        if ($content -match '(?<![A-Za-z0-9_.])eval\s*\(') {
            $warnings += "eval() runs arbitrary code -- forbidden in scoped apps"
        }
        if ($content -match '\bqueryNoDomain\s*\(') {
            $warnings += "queryNoDomain() bypasses domain ACLs -- confirm intentional and document why"
        }
        if ($content -match '\bgs\.include\s*\([^)"'']+\+') {
            $warnings += "gs.include() with concatenated argument -- dynamic includes are a maintenance/security risk"
        }
        if ($content -match '\bsetRedirectURL\s*\(\s*[a-zA-Z_$][a-zA-Z0-9_$.]*\s*\)') {
            $warnings += "setRedirectURL() with a variable -- validate the URL to avoid open-redirect"
        }
    }

    if ($ext -eq '.html') {
        if ($content -match 'ng-bind-html\b' -and $content -notmatch '\$sce\.trustAsHtml') {
            $warnings += "ng-bind-html without `$sce.trustAsHtml in scope -- raw HTML binding can enable XSS"
        }
    }

    if ($warnings.Count -gt 0) {
        $fileName = [System.IO.Path]::GetFileName($filePath)
        $msg = "SN-SECURITY: $fileName has potential security patterns (review and confirm intent):`n" +
               ($warnings -join "`n") +
               "`nThe edit was applied; this is advisory feedback to verify before continuing."
        [Console]::Error.WriteLine($msg)
        exit 2
    }
    exit 0
}
