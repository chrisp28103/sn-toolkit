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
