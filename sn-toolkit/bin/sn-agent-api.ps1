<#
.SYNOPSIS
    Send a command to the sn-scriptsync Agent API and return the response.
.DESCRIPTION
    Writes a request JSON to the agent/requests/ folder and polls for the
    response in agent/responses/. Returns the parsed response object.
.PARAMETER InstanceDir
    Full path to the scriptsync instance directory (the folder containing
    _settings.json, e.g. .../<your-instance-dir>)
.PARAMETER Command
    The Agent API command to execute (see .NOTES for the full command
    catalog and canonical -Params shape for each).
.PARAMETER Params
    Optional hashtable of parameters for the command.
.PARAMETER TimeoutSeconds
    Max seconds to wait for a response (default: 15). Remote commands
    (create_artifact, screenshot, upload_attachment, switch_context) may
    take 1-5s -- bump to 30+ for those.
.EXAMPLE
    $r = & .agent\scripts\sn-agent-api.ps1 -InstanceDir "...\<your-instance-dir>" -Command "check_connection"
    $r.result.ready  # True if connected

    $r = & .agent\scripts\sn-agent-api.ps1 -InstanceDir "...\<your-instance-dir>" -Command "query_records" -Params @{
        table = "sys_script_include"
        query = "sys_scope.scope=x_<your_scope>"
        fields = "sys_id,name,active"
        limit = 50
    }
    $r.result.records  # Array of matching records
.NOTES
    === COMMAND CATALOG (v1.5.0) ===

    CONNECTION & STATUS (local, <100ms)
      check_connection      -- no params. Call FIRST.
      clear_last_error      -- no params.
      get_last_error        -- no params. Check after mutations.
      sync_now              -- no params. Flush pending file syncs.
      get_sync_status       -- no params. Returns { pendingCount, isPaused, pendingFiles }.
      get_instance_info     -- no params. Returns { instanceName, connected, hasSettings }.

    QUERY & DISCOVERY (remote, 1-2s)
      query_records         -- @{ table, query, fields, limit, orderBy }
      check_name_exists     -- @{ table, name }              (local _map.json only)
      check_name_exists_remote -- @{ table, name }           (SN API)
      get_parent_options    -- @{ table, scope, nameField, limit }
      get_table_metadata    -- @{ table }                    (caches to structure.json)
      list_tables           -- no params
      list_artifacts        -- @{ table }
      get_file_structure    -- no params
      validate_path         -- @{ path }

    CREATE & UPDATE (remote, 1-3s)
      create_artifact       -- @{ table, scope, fields = @{...} }
      update_record         -- @{ table, sys_id, field, content }
                               Note: "field" (singular) + "content", NOT "fields".
      update_record_batch   -- @{ table, sys_id, fields = @{...} }

    BROWSER / UI (remote, 1-3s)
      open_in_browser       -- @{ table, sys_id } or @{ table, name, scope }
                               Widgets open /$sp.do?id=sp-preview; others open form.
      refresh_preview       -- @{ table, sys_id } or @{ table, name, scope }
      activate_tab          -- @{ url, reload, waitForLoad, openIfNotFound, tabId }
      take_screenshot       -- @{ url, fileName, tabId }
                               Requires one-time extension-icon permission on target tab.
      run_slash_command     -- @{ command, url, autoRun, tabId }
                               Documented commands ONLY: /tn, /bg, /token, /sn, /xml.
      upload_attachment     -- @{ table, sys_id, filePath }  (absolute path!)
                               or @{ table, sys_id, fileName, imageData, contentType }

    CONTEXT SWITCH (remote, 1-2s)
      switch_context        -- @{ switchType, value, reloadTab, tabUrl }
                               switchType = 'updateset' | 'application' | 'domain'
                               value = sys_id of the target record
                               reloadTab default $true (needed for new context to apply)

    === COMMON GOTCHAS ===
    * update_record wants "field" + "content" (singular). Passing "fields" errors out.
    * Boolean / choice values in 'fields' must be STRINGS: "true", "-7", "100".
    * upload_attachment "filePath" is relative to INSTANCE folder, not workspace.
      Pass absolute paths to be safe.
    * take_screenshot first use per session requires user action (click extension icon).
    * run_slash_command: never invent commands. /click does not exist.
    * switch_context: reloadTab must be true for new scope/domain filters to apply.
    * Silent ACL failures: update_record can return success with zero persistence.
      Always verify via re-query on sys_updated_on / sys_updated_by.
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
        if ($val) { return "true" } else { return "false" }
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
