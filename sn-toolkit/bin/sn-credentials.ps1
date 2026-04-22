<#
.SYNOPSIS
    Securely retrieves stored ServiceNow credentials for REST API calls.
.DESCRIPTION
    Reads DPAPI-encrypted .clixml credential files from <workspace>/.agent/credentials/
    and returns a hashtable with Headers (Basic Auth), Credential, and BaseUrl.

    Workspace root is discovered by walking up from -WorkspaceRoot (default: the
    current working directory) until a .claude/project.json is found. Instance
    URLs are read from that file:

        {
          "scope":    "x_...",
          "instance": "<dev-sync-instance-short-name>",
          "devUrl":   "https://<dev>.service-now.com",    // optional; default inferred from 'instance'
          "prodUrl":  "https://<prod>.service-now.com"    // required for -Instance prod
        }

    Passwords are NEVER displayed in plain text.
.PARAMETER Instance
    Which ServiceNow instance to load credentials for: "dev" or "prod"
.PARAMETER WorkspaceRoot
    Project workspace root. Defaults to walking up from the current working
    directory looking for .claude/project.json. Pass explicitly to override
    (e.g., when calling from outside a project directory).
.EXAMPLE
    $auth = & sn-credentials.ps1 -Instance "prod"
    Invoke-RestMethod -Uri "$($auth.BaseUrl)/api/now/table/incident" -Headers $auth.Headers
.EXAMPLE
    $auth = & sn-credentials.ps1 -Instance "dev" -WorkspaceRoot "C:\path\to\project"
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string]$Instance,

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

# Resolve workspace root
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

# Load project config
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

# Locate credential file
$credFile = Join-Path $WorkspaceRoot ".agent\credentials\sn-$Instance.clixml"
if (-not (Test-Path $credFile)) {
    Write-Error @"
No stored credentials found for '$Instance'.
Expected file: $credFile
Run the credential setup workflow to store your credentials securely.
"@
    exit 1
}

# Import the encrypted credential
try {
    $credential = Import-Clixml -Path $credFile
} catch {
    Write-Error "Failed to decrypt credential file for '$Instance'. You may need to re-store credentials. Error: $_"
    exit 1
}

# Build Basic Auth header (password is decrypted in memory only, never displayed)
$username = $credential.UserName
$password = $credential.GetNetworkCredential().Password
$base64Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))

# Clear the plain text password variable immediately
Remove-Variable password

$headers = @{
    "Authorization" = "Basic $base64Auth"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

# Return a hashtable with everything the caller needs
return @{
    Headers       = $headers
    Credential    = $credential
    BaseUrl       = $baseUrl
    Instance      = $Instance
    Username      = $username
    WorkspaceRoot = $WorkspaceRoot
}
