<#
.SYNOPSIS
    Send a command to the sn-scriptsync Agent API and return the response.
.DESCRIPTION
    Writes a request JSON to the agent/requests/ folder and polls for the
    response in agent/responses/. Returns the parsed response object.
.PARAMETER InstanceDir
    Full path to the scriptsync instance directory (the folder containing
    _settings.json, e.g. .../zerovectordev)
.PARAMETER Command
    The Agent API command to execute (e.g. check_connection, query_records)
.PARAMETER Params
    Optional hashtable of parameters for the command.
.PARAMETER TimeoutSeconds
    Max seconds to wait for a response (default: 15)
.EXAMPLE
    $r = & .agent\scripts\sn-agent-api.ps1 -InstanceDir "...\zerovectordev" -Command "check_connection"
    $r.result.ready  # True if connected

    $r = & .agent\scripts\sn-agent-api.ps1 -InstanceDir "...\zerovectordev" -Command "query_records" -Params @{
        table = "sys_script_include"
        query = "sys_scope.scope=x_icir_zero_vector"
        fields = "sys_id,name,active"
        limit = 50
    }
    $r.result.records  # Array of matching records
#>
param(
    [Parameter(Mandatory)][string]$InstanceDir,
    [Parameter(Mandatory)][string]$Command,
    [hashtable]$Params = @{},
    [int]$TimeoutSeconds = 15
)

$agentDir = Join-Path $InstanceDir "agent"
$reqDir = Join-Path $agentDir "requests"
$resDir = Join-Path $agentDir "responses"

# Ensure directories exist
if (-not (Test-Path $reqDir)) { New-Item -ItemType Directory -Path $reqDir  -Force | Out-Null }
if (-not (Test-Path $resDir)) { New-Item -ItemType Directory -Path $resDir  -Force | Out-Null }

# Generate unique request ID
$reqId = "req_$(Get-Date -Format 'yyyyMMddHHmmssfff')_$([guid]::NewGuid().ToString('N').Substring(0,6))"

# Build request JSON using .NET serialization to avoid ConvertTo-Json hangs
# on large multi-line strings (e.g., full script content in update_record calls).
# ConvertTo-Json can freeze indefinitely when params contain multi-line code
# with special characters. JavaScriptStringEncode handles this correctly.
Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue

$reqFile = Join-Path $reqDir "$reqId.json"
$resFile = Join-Path $resDir "res_$reqId.json"

function ConvertTo-JsonValue($val) {
    if ($val -is [hashtable]) {
        $entries = @()
        foreach ($k in $val.Keys) {
            $entries += "`"$k`":$(ConvertTo-JsonValue $val[$k])"
        }
        return "{$($entries -join ',')}"
    }
    elseif ($val -is [array]) {
        $items = @()
        foreach ($item in $val) { $items += ConvertTo-JsonValue $item }
        return "[$($items -join ',')]"
    }
    elseif ($val -is [bool]) {
        return if ($val) { "true" } else { "false" }
    }
    elseif ($val -is [int] -or $val -is [long] -or $val -is [double]) {
        return "$val"
    }
    else {
        $escaped = [System.Web.HttpUtility]::JavaScriptStringEncode([string]$val)
        return "`"$escaped`""
    }
}

$requestObj = @{ id = $reqId; command = $Command }
if ($Params.Count -gt 0) { $requestObj.params = $Params }

$jsonContent = ConvertTo-JsonValue $requestObj
[System.IO.File]::WriteAllText($reqFile, $jsonContent, [System.Text.Encoding]::UTF8)

# Poll for response
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while (-not (Test-Path $resFile)) {
    if ((Get-Date) -gt $deadline) {
        # Clean up request file on timeout
        if (Test-Path $reqFile) { Remove-Item $reqFile -Force }
        Write-Error "Agent API timeout after ${TimeoutSeconds}s waiting for response to '$Command'. Is scriptsync running with the helper tab open?"
        return $null
    }
    Start-Sleep -Milliseconds 100
}

# Read and parse response
$response = Get-Content $resFile -Raw | ConvertFrom-Json

# Clean up request and response files
Remove-Item $reqFile -Force -ErrorAction SilentlyContinue
Remove-Item $resFile -Force -ErrorAction SilentlyContinue

return $response
