# Shared helpers for sn-toolkit hooks.
# Dot-source via:  . "$PSScriptRoot\_common.ps1"

function Resolve-SnInstance {
    # Returns a DirectoryInfo for the active SN instance dir, or $null.
    # Order of precedence:
    #   1. <projectDir>/.claude/project.json -> "instance" field names a subdir of instances/
    #   2. first subdir of instances/ (legacy auto-detect, only safe when there is exactly one)
    param([Parameter(Mandatory=$true)][string]$ProjectDir)

    $instancesRoot = Join-Path $ProjectDir 'instances'
    if (-not (Test-Path $instancesRoot)) { return $null }

    $projectJson = Join-Path $ProjectDir '.claude\project.json'
    if (Test-Path $projectJson) {
        try {
            $cfg = Get-Content $projectJson -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($cfg.instance) {
                $explicit = Join-Path $instancesRoot $cfg.instance
                if (Test-Path $explicit) { return Get-Item $explicit }
            }
        } catch { }
    }

    return (Get-ChildItem $instancesRoot -Directory -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Get-SnAgentApiPath {
    # Resolves to <plugin-root>/bin/sn-agent-api.ps1.
    # Hook PowerShell sessions do NOT inherit the plugin bin/ on PATH (only the Bash tool does),
    # so hook scripts must reference the agent API by full path.
    $root = $env:CLAUDE_PLUGIN_ROOT
    if (-not $root) {
        # Fallback: _common.ps1 lives in <plugin-root>/hooks/, so parent is plugin root.
        $root = Split-Path $PSScriptRoot -Parent
    }
    return (Join-Path $root 'bin\sn-agent-api.ps1')
}

function Get-PathImpliedInstance {
    # For a file path inside a sn-scriptsync sync workspace, return the instance
    # name implied by the path (the first path segment after $ProjectDir).
    # Returns $null if the path is not under $ProjectDir or that first segment
    # has no matching instances/<name>/ directory (i.e. not a real workspace).
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ProjectDir
    )
    if (-not $FilePath) { return $null }
    $normalizedFile = ($FilePath -replace '\\', '/').TrimEnd('/')
    $normalizedProject = ($ProjectDir -replace '\\', '/').TrimEnd('/')
    if (-not $normalizedFile.StartsWith($normalizedProject + '/')) { return $null }
    $relative = $normalizedFile.Substring($normalizedProject.Length + 1)
    $firstSegment = ($relative -split '/')[0]
    if (-not $firstSegment) { return $null }
    if ($firstSegment -eq 'instances') { return $null }
    $instancesRoot = Join-Path $ProjectDir 'instances'
    if (-not (Test-Path (Join-Path $instancesRoot $firstSegment))) { return $null }
    return $firstSegment
}

function Get-SnInstanceLockPath {
    param([Parameter(Mandatory=$true)][string]$ProjectDir)
    return (Join-Path $ProjectDir '.claude\.sn-instance-lock.json')
}

function Get-CachedLiveInstance {
    # Returns the cached live instance_name if cache file exists and is within TTL.
    # Returns $null on miss / stale / read error.
    param(
        [Parameter(Mandatory=$true)][string]$ProjectDir,
        [int]$TtlSeconds = 30
    )
    $cacheFile = Get-SnInstanceLockPath -ProjectDir $ProjectDir
    if (-not (Test-Path $cacheFile)) { return $null }
    try {
        $cache = Get-Content $cacheFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $cache.live_instance -or -not $cache.verified_at) { return $null }
        $now = [int][double]::Parse((Get-Date -UFormat %s))
        $age = $now - [int]$cache.verified_at
        if ($age -gt $TtlSeconds) { return $null }
        return [string]$cache.live_instance
    } catch { return $null }
}

function Set-CachedLiveInstance {
    param(
        [Parameter(Mandatory=$true)][string]$ProjectDir,
        [Parameter(Mandatory=$true)][string]$LiveInstance
    )
    $cacheDir = Join-Path $ProjectDir '.claude'
    if (-not (Test-Path $cacheDir)) {
        try { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null } catch { return }
    }
    $cacheFile = Get-SnInstanceLockPath -ProjectDir $ProjectDir
    $now = [int][double]::Parse((Get-Date -UFormat %s))
    $payload = "{`"live_instance`":`"$LiveInstance`",`"verified_at`":$now}"
    try {
        [System.IO.File]::WriteAllText($cacheFile, $payload, (New-Object System.Text.UTF8Encoding($false)))
    } catch { }
}

function Clear-CachedLiveInstance {
    param([Parameter(Mandatory=$true)][string]$ProjectDir)
    $cacheFile = Get-SnInstanceLockPath -ProjectDir $ProjectDir
    if (Test-Path $cacheFile) {
        try { Remove-Item $cacheFile -Force -ErrorAction SilentlyContinue } catch { }
    }
}

function Invoke-LiveInstanceProbe {
    # Probes the helper-tab-connected SN instance for sys_properties.instance_name.
    # Returns @{ ok = $true; live = '<name>' } on success.
    # Returns @{ ok = $false; reason = 'unreachable' } on probe failure / timeout.
    param(
        [Parameter(Mandatory=$true)][string]$InstanceDir,
        [int]$TimeoutSec = 5
    )
    $api = Get-SnAgentApiPath
    if (-not (Test-Path $api)) { return @{ ok = $false; reason = 'unreachable' } }
    try {
        $r = & $api -InstanceDir $InstanceDir -Command 'query_records' -Params @{
            table  = 'sys_properties'
            query  = 'name=instance_name'
            fields = 'name,value'
            limit  = 1
        } -TimeoutSeconds $TimeoutSec 2>$null
        if ($null -eq $r -or $null -eq $r.result -or $null -eq $r.result.records) {
            return @{ ok = $false; reason = 'unreachable' }
        }
        $rec = $r.result.records | Select-Object -First 1
        if (-not $rec -or -not $rec.value) {
            return @{ ok = $false; reason = 'unreachable' }
        }
        return @{ ok = $true; live = [string]$rec.value }
    } catch {
        return @{ ok = $false; reason = 'unreachable' }
    }
}
