<#
.SYNOPSIS
    Store or load ServiceNow credentials (DPAPI-encrypted, Windows-only).

.DESCRIPTION
    Action "load" (default) retrieves stored credentials and returns a hashtable
    with Headers (Basic Auth), BaseUrl (from project.json), Credential, etc.

    Action "store" encrypts a username + password into .agent/credentials/sn-<instance>.clixml
    using Windows DPAPI. The file can ONLY be decrypted by the same user on the
    same machine.

    Workspace root is discovered by walking up from $PWD (or -WorkspaceRoot).
    The .claude/project.json in that workspace must define the base URL for the
    requested instance (devUrl / prodUrl), or an 'instance' field for dev
    auto-inference.

.PARAMETER Action
    "load" (default) or "store".

.PARAMETER Instance
    "dev" or "prod". Picks the credential file (sn-<instance>.clixml) and, for
    load, the base URL from project.json.

.PARAMETER Username
    Required for -Action store.

.PARAMETER Password
    Password for -Action store. Accepts a plain string OR a SecureString.
    If omitted, prompts interactively (Read-Host -AsSecureString).

.PARAMETER WorkspaceRoot
    Project workspace root. Defaults to walking up from CWD until a
    .claude/project.json is found.

.EXAMPLE
    $auth = & sn-credentials.ps1 -Instance prod
    Invoke-RestMethod -Uri "$($auth.BaseUrl)/api/now/table/incident" -Headers $auth.Headers

.EXAMPLE
    & sn-credentials.ps1 -Action store -Instance prod -Username "me@x.com"
    # prompts for password securely

.EXAMPLE
    & sn-credentials.ps1 -Action store -Instance prod -Username "me@x.com" -Password "secret"
#>
param(
    [ValidateSet("load", "store")]
    [string]$Action = "load",

    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string]$Instance,

    [string]$Username,
    [object]$Password,
    [string]$WorkspaceRoot
)

$ErrorActionPreference = "Stop"

function Find-WorkspaceRoot {
    param([string]$StartDir)
    $dir = (Resolve-Path $StartDir).Path
    while ($dir) {
        if (Test-Path (Join-Path $dir ".claude\project.json")) {
            return $dir
        }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

if (-not $WorkspaceRoot) {
    $WorkspaceRoot = Find-WorkspaceRoot -StartDir $PWD.Path
    if (-not $WorkspaceRoot) {
        Write-Error @"
Could not locate project workspace root.
Searched upward from '$($PWD.Path)' for '.claude\project.json'.
Pass -WorkspaceRoot explicitly, or run from within a project directory.
"@
        exit 1
    }
}

$projectFile = Join-Path $WorkspaceRoot ".claude\project.json"
if (-not (Test-Path $projectFile)) {
    Write-Error "Project config not found at '$projectFile'."
    exit 1
}
try {
    $project = Get-Content $projectFile -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse '$projectFile': $_"
    exit 1
}

$credDir  = Join-Path $WorkspaceRoot ".agent\credentials"
$credFile = Join-Path $credDir "sn-$Instance.clixml"

# ---------- STORE ----------
if ($Action -eq "store") {
    if (-not $Username) {
        Write-Error "-Username is required for -Action store."
        exit 1
    }

    if (-not (Test-Path $credDir)) {
        New-Item -ItemType Directory -Path $credDir -Force | Out-Null
    }

    # Resolve the password into a SecureString
    if ($null -eq $Password) {
        $securePass = Read-Host -Prompt "Password for $Username on $Instance" -AsSecureString
    } elseif ($Password -is [System.Security.SecureString]) {
        $securePass = $Password
    } else {
        $securePass = ConvertTo-SecureString -String ([string]$Password) -AsPlainText -Force
    }

    $credential = New-Object System.Management.Automation.PSCredential($Username, $securePass)
    $credential | Export-Clixml -Path $credFile

    return @{
        Action   = "store"
        Instance = $Instance
        Username = $Username
        File     = $credFile
    }
}

# ---------- LOAD (default) ----------

# Determine base URL
$baseUrl = $null
if ($Instance -eq "dev") {
    if ($project.devUrl) {
        $baseUrl = $project.devUrl
    } elseif ($project.instance) {
        $baseUrl = "https://$($project.instance).service-now.com"
    }
} elseif ($Instance -eq "prod") {
    if ($project.prodUrl) { $baseUrl = $project.prodUrl }
}

if (-not $baseUrl) {
    $hint = if ($Instance -eq "prod") {
        'Add a "prodUrl" field (e.g., "https://<yourprod>.service-now.com") to project.json.'
    } else {
        'Add a "devUrl" field or an "instance" field to project.json.'
    }
    Write-Error @"
No base URL configured for '-Instance $Instance' in '$projectFile'.
$hint
"@
    exit 1
}

if (-not (Test-Path $credFile)) {
    Write-Error @"
No stored credentials found for '$Instance'.
Expected file: $credFile
Run: sn-credentials.ps1 -Action store -Instance $Instance -Username "..."
"@
    exit 1
}

try {
    $credential = Import-Clixml -Path $credFile
} catch {
    Write-Error "Failed to decrypt credential file for '$Instance'. You may need to re-store credentials. Error: $_"
    exit 1
}

$username = $credential.UserName
$password = $credential.GetNetworkCredential().Password
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))
Remove-Variable password

$headers = @{
    "Authorization" = "Basic $base64Auth"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

return @{
    Headers       = $headers
    Credential    = $credential
    BaseUrl       = $baseUrl
    Instance      = $Instance
    Username      = $username
    WorkspaceRoot = $WorkspaceRoot
}
