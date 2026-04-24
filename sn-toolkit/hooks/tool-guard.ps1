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
    exit 0
}
