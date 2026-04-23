###################################################################
# bootstrap-project.ps1 (plugin edition -- lean)
# Creates a new ServiceNow project workspace. The plugin provides
# all shared infrastructure (agents, commands, hooks, rules, bin/
# scripts, autocomplete). This script only creates project-specific
# scaffold -- dirs, CLAUDE.md, .gitignore, .claude/project.json.
#
# Usage:
#   bootstrap-project.ps1 -Name aha -Scope x_icir_aha -Instance ahadev
###################################################################
param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Scope,
    [Parameter(Mandatory)][string]$Instance,
    [string]$InstanceUrl = "",
    [string]$OutputDir = (Join-Path $env:USERPROFILE "Documents\ServiceNow")
)

$ErrorActionPreference = "Stop"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# Plugin root (this script lives in <plugin-root>/bin/)
$pluginRoot = Split-Path $PSScriptRoot -Parent
$projectDir = Join-Path $OutputDir $Name
if (Test-Path $projectDir) {
    Write-Error "Project directory already exists: $projectDir"
    exit 1
}
if (-not $InstanceUrl) { $InstanceUrl = "https://$Instance.service-now.com" }

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Creating ServiceNow project: $Name" -ForegroundColor Cyan
Write-Host " Scope:    $Scope" -ForegroundColor Cyan
Write-Host " Instance: $Instance" -ForegroundColor Cyan
Write-Host " Output:   $projectDir" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# 1. Project dir skeleton
$dirs = @(
    "instances\$Instance\agent\requests"
    "instances\$Instance\agent\responses"
    "instances\$Instance\agent\tmp"
    "scratch"
    "credentials"
    "docs\architecture"
    "docs\context"
    "docs\reference"
    "docs\requirements"
    ".claude"
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $projectDir $d) -Force | Out-Null
}
Write-Host "[1/5] Created directory skeleton"

# 2. sn-scriptsync instance config (consumed by scriptsync, not Claude)
$settingsJson = '{"instance":"' + $Instance + '.service-now.com"}'
[System.IO.File]::WriteAllText(
    (Join-Path $projectDir "instances\$Instance\_settings.json"),
    $settingsJson, $utf8NoBom)
$scopesJson = '{"' + $Scope + '":"' + $Scope + '"}'
[System.IO.File]::WriteAllText(
    (Join-Path $projectDir "instances\$Instance\scopes.json"),
    $scopesJson, $utf8NoBom)
Write-Host "[2/5] Wrote sn-scriptsync instance config"

# 3. .claude/project.json (consumed by plugin hooks for instance resolution)
#    and empty settings.local.json placeholder
$projectJson = '{"scope":"' + $Scope + '","instance":"' + $Instance + '"}'
[System.IO.File]::WriteAllText(
    (Join-Path $projectDir ".claude\project.json"),
    $projectJson, $utf8NoBom)
[System.IO.File]::WriteAllText(
    (Join-Path $projectDir ".claude\settings.local.json"),
    '{}', $utf8NoBom)
Write-Host "[3/5] Wrote .claude/project.json + settings.local.json"

# 4. CLAUDE.md from plugin template
$templatePath = Join-Path $pluginRoot "CLAUDE.md.template"
if (-not (Test-Path $templatePath)) {
    Write-Error "Plugin CLAUDE.md.template not found at: $templatePath"
    exit 1
}
$template = Get-Content $templatePath -Raw
$template = $template -replace '__PROJECT_NAME__', $Name
$template = $template -replace '__SCOPE__', $Scope
$template = $template -replace '__INSTANCE__', $Instance
$template = $template -replace '__PROJECT_DIR__', ($projectDir -replace '\\','/')
$template = $template -replace '__PROJECT_DIR_WIN__', $projectDir
[System.IO.File]::WriteAllText((Join-Path $projectDir "CLAUDE.md"), $template, $utf8NoBom)
Write-Host "[4/5] Wrote CLAUDE.md"

# 5. .gitignore from plugin template
$gitignoreSrc = Join-Path $pluginRoot ".gitignore.template"
if (Test-Path $gitignoreSrc) {
    Copy-Item $gitignoreSrc (Join-Path $projectDir ".gitignore") -Force
}
Write-Host "[5/5] Wrote .gitignore"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " PROJECT CREATED" -ForegroundColor Green
Write-Host " Open '$projectDir' as your IDE workspace" -ForegroundColor Green
Write-Host " Then run /sn-toolkit:creds to configure credentials" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
