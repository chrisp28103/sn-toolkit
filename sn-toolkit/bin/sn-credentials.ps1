<#
.SYNOPSIS
    Securely retrieves stored ServiceNow credentials for REST API calls.
.DESCRIPTION
    Reads DPAPI-encrypted .clixml credential files from .agent/credentials/
    and returns a hashtable with Headers (Basic Auth) and Credential (PSCredential).
    Passwords are NEVER displayed in plain text.
.PARAMETER Instance
    Which ServiceNow instance to load credentials for: "dev" or "prod"
.EXAMPLE
    $auth = & ".agent/scripts/sn-credentials.ps1" -Instance "prod"
    Invoke-RestMethod -Uri $url -Headers $auth.Headers -Method Get
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("dev", "prod")]
    [string]$Instance
)

$ErrorActionPreference = "Stop"

# Resolve paths relative to workspace root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptDir "..\.." )).Path
$credDir = Join-Path $workspaceRoot ".agent\credentials"
$credFile = Join-Path $credDir "sn-$Instance.clixml"

# Instance URL mapping
$instanceUrls = @{
    "dev"  = "https://zerovectordev.service-now.com"
    "prod" = "https://zerovector.service-now.com"
}

# Check if credential file exists
if (-not (Test-Path $credFile)) {
    Write-Error @"
No stored credentials found for '$Instance'.
Run the /sn-setup-credentials workflow first to store your credentials securely.
Expected file: $credFile
"@
    exit 1
}

# Import the encrypted credential
try {
    $credential = Import-Clixml -Path $credFile
} catch {
    Write-Error "Failed to decrypt credential file for '$Instance'. You may need to re-run /sn-setup-credentials. Error: $_"
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
    Headers    = $headers
    Credential = $credential
    BaseUrl    = $instanceUrls[$Instance]
    Instance   = $Instance
    Username   = $username
}
