<#
.SYNOPSIS
    Compare ServiceNow records across two instances per a JSON spec.

.DESCRIPTION
    Reads a comparison spec (JSON) listing one or more (table, fields, match_key, query)
    entries. For each spec entry, queries both instances via REST, builds a three-way
    set diff (A-only / B-only / both-with-field-diffs), and emits a markdown report.

    Spec format:
      {
        "instance_a": "dev",
        "instance_b": "prod",
        "output": "docs/context/<file>.md",
        "specs": [
          {
            "label": "human label",
            "table": "sys_user_group",
            "fields": ["name","description","manager","..."],
            "match_key": "name",          // string OR array (composite)
            "query": "active=true"        // sysparm_query (URL-encoded internally)
          }
        ]
      }

    Reference-field comparisons use display_value (logical name) so cross-instance sys_id
    divergence does not produce false diffs.

.PARAMETER SpecPath
    Path to the JSON spec.

.PARAMETER OutPath
    Optional output path. Overrides spec.output. Resolved relative to workspace root if relative.

.EXAMPLE
    sn-compare.ps1 -SpecPath docs/context/access-go-live-compare-spec.json
#>
param(
    [Parameter(Mandatory = $true)][string]$SpecPath,
    [string]$OutPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web

$specFull = (Resolve-Path $SpecPath).Path
$spec = Get-Content $specFull -Raw | ConvertFrom-Json

if (-not $spec.specs)      { throw "spec.specs is required" }
if (-not $spec.instance_a) { throw "spec.instance_a is required (dev|prod)" }
if (-not $spec.instance_b) { throw "spec.instance_b is required (dev|prod)" }

$auth_a = & sn-credentials.ps1 -Instance $spec.instance_a
$auth_b = & sn-credentials.ps1 -Instance $spec.instance_b
$repoRoot = $auth_a.WorkspaceRoot

if (-not $OutPath) {
    if (-not $spec.output) { throw "spec.output or -OutPath required" }
    $OutPath = if ([IO.Path]::IsPathRooted($spec.output)) { $spec.output } else { Join-Path $repoRoot $spec.output }
}

function Get-FieldProp {
    param($row, [string]$field)
    $prop = $row.PSObject.Properties[$field]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-DisplayValue {
    param($row, [string]$field)
    $v = Get-FieldProp -row $row -field $field
    if ($null -eq $v) { return '' }
    if ($v -is [string]) { return $v }
    if ($v.PSObject.Properties['display_value']) { return [string]$v.display_value }
    return [string]$v
}

function Get-RawValue {
    param($row, [string]$field)
    $v = Get-FieldProp -row $row -field $field
    if ($null -eq $v) { return '' }
    if ($v -is [string]) { return $v }
    if ($v.PSObject.Properties['value']) { return [string]$v.value }
    return [string]$v
}

function Get-MatchKey {
    param($row, $matchKey)
    if ($matchKey -is [array] -or $matchKey -is [System.Collections.IList]) {
        return (($matchKey | ForEach-Object { Get-DisplayValue -row $row -field $_ }) -join '||')
    }
    return Get-DisplayValue -row $row -field ([string]$matchKey)
}

function Get-Rows {
    param([string]$BaseUrl, [hashtable]$Headers, [string]$Table, [string]$Query, [string[]]$Fields)
    $allFields = New-Object System.Collections.Generic.List[string]
    if (-not ($Fields -contains 'sys_id')) { [void]$allFields.Add('sys_id') }
    foreach ($f in $Fields) { [void]$allFields.Add($f) }
    $fieldsCsv = ($allFields -join ',')
    $encQuery  = [System.Web.HttpUtility]::UrlEncode($Query)
    $uri = "$BaseUrl/api/now/table/$Table" + "?sysparm_query=$encQuery&sysparm_fields=$fieldsCsv&sysparm_display_value=all&sysparm_exclude_reference_link=true&sysparm_limit=10000"
    $resp = Invoke-RestMethod -Uri $uri -Headers $Headers -Method Get
    return @($resp.result)
}

function Escape-Cell {
    param([string]$s)
    if (-not $s) { return '' }
    $r = $s -replace '\|', '\|'
    $r = $r -replace "`r?`n", ' '
    if ($r.Length -gt 200) { $r = $r.Substring(0, 200) + '...' }
    return $r
}

$report  = New-Object System.Text.StringBuilder
$summary = New-Object System.Text.StringBuilder
$body    = New-Object System.Text.StringBuilder

[void]$report.AppendLine("# Cross-Instance Compare Report")
[void]$report.AppendLine("")
[void]$report.AppendLine("- Spec: ``$specFull``")
[void]$report.AppendLine("- Instance A: ``$($spec.instance_a)`` -- $($auth_a.BaseUrl)")
[void]$report.AppendLine("- Instance B: ``$($spec.instance_b)`` -- $($auth_b.BaseUrl)")
[void]$report.AppendLine("- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$report.AppendLine("")

[void]$summary.AppendLine("## Summary")
[void]$summary.AppendLine("")
[void]$summary.AppendLine("| Spec | Total A | Total B | A-only | B-only | Differing |")
[void]$summary.AppendLine("| --- | ---: | ---: | ---: | ---: | ---: |")

foreach ($s in $spec.specs) {
    $label    = [string]$s.label
    $table    = [string]$s.table
    $fields   = @($s.fields)
    $matchKey = $s.match_key
    $query    = if ($s.query) { [string]$s.query } else { '' }

    Write-Host "[compare] $label  ($table)" -ForegroundColor Cyan

    $rowsA = @(Get-Rows -BaseUrl $auth_a.BaseUrl -Headers $auth_a.Headers -Table $table -Query $query -Fields $fields)
    $rowsB = @(Get-Rows -BaseUrl $auth_b.BaseUrl -Headers $auth_b.Headers -Table $table -Query $query -Fields $fields)

    $countA = $rowsA.Count
    $countB = $rowsB.Count
    $truncWarn = ''
    if ($countA -ge 10000 -or $countB -ge 10000) { $truncWarn = ' **WARNING: hit 10000-row limit -- results truncated**' }

    $mapA = @{}
    foreach ($r in $rowsA) {
        $k = Get-MatchKey -row $r -matchKey $matchKey
        if ([string]::IsNullOrEmpty($k)) { continue }
        if (-not $mapA.ContainsKey($k)) { $mapA[$k] = $r }
    }
    $mapB = @{}
    foreach ($r in $rowsB) {
        $k = Get-MatchKey -row $r -matchKey $matchKey
        if ([string]::IsNullOrEmpty($k)) { continue }
        if (-not $mapB.ContainsKey($k)) { $mapB[$k] = $r }
    }

    $aOnly = New-Object System.Collections.Generic.List[string]
    $bOnly = New-Object System.Collections.Generic.List[string]
    $diffs = New-Object System.Collections.Generic.List[object]

    foreach ($k in $mapA.Keys) {
        if (-not $mapB.ContainsKey($k)) { [void]$aOnly.Add($k); continue }
        $rA = $mapA[$k]
        $rB = $mapB[$k]
        $fieldDiffs = New-Object System.Collections.Generic.List[object]
        foreach ($f in $fields) {
            $dvA = Get-DisplayValue -row $rA -field $f
            $dvB = Get-DisplayValue -row $rB -field $f
            if ($dvA -ne $dvB) {
                [void]$fieldDiffs.Add([pscustomobject]@{ field = $f; a = $dvA; b = $dvB })
            }
        }
        if ($fieldDiffs.Count -gt 0) {
            [void]$diffs.Add([pscustomobject]@{
                key      = $k
                sysId_a  = (Get-RawValue -row $rA -field 'sys_id')
                sysId_b  = (Get-RawValue -row $rB -field 'sys_id')
                fields   = $fieldDiffs
            })
        }
    }
    foreach ($k in $mapB.Keys) {
        if (-not $mapA.ContainsKey($k)) { [void]$bOnly.Add($k) }
    }

    [void]$summary.AppendLine(("| {0} | {1} | {2} | {3} | {4} | {5} |" -f $label, $countA, $countB, $aOnly.Count, $bOnly.Count, $diffs.Count))

    $matchKeyDisplay = if ($matchKey -is [array] -or $matchKey -is [System.Collections.IList]) { ($matchKey -join '+') } else { [string]$matchKey }

    [void]$body.AppendLine("---")
    [void]$body.AppendLine("")
    [void]$body.AppendLine("## $label")
    [void]$body.AppendLine("")
    [void]$body.AppendLine("- Table: ``$table`` | Match key: ``$matchKeyDisplay`` | Query: ``$query``$truncWarn")
    [void]$body.AppendLine("- Instance A ($($spec.instance_a)) rows: **$countA** | Instance B ($($spec.instance_b)) rows: **$countB**")
    [void]$body.AppendLine("")

    [void]$body.AppendLine("### In A only ($($spec.instance_a) -> needs adding to $($spec.instance_b)) -- $($aOnly.Count)")
    [void]$body.AppendLine("")
    if ($aOnly.Count -eq 0) {
        [void]$body.AppendLine("_(none)_")
    } else {
        $aOnly | Sort-Object | ForEach-Object {
            [void]$body.AppendLine("- ``$_``")
        }
    }
    [void]$body.AppendLine("")

    [void]$body.AppendLine("### In B only ($($spec.instance_b) -> drift / extra in $($spec.instance_b)) -- $($bOnly.Count)")
    [void]$body.AppendLine("")
    if ($bOnly.Count -eq 0) {
        [void]$body.AppendLine("_(none)_")
    } else {
        $bOnly | Sort-Object | ForEach-Object {
            [void]$body.AppendLine("- ``$_``")
        }
    }
    [void]$body.AppendLine("")

    [void]$body.AppendLine("### In both, fields differ -- $($diffs.Count)")
    [void]$body.AppendLine("")
    if ($diffs.Count -eq 0) {
        [void]$body.AppendLine("_(none)_")
    } else {
        foreach ($d in ($diffs | Sort-Object -Property key)) {
            [void]$body.AppendLine("**$($d.key)**  ")
            [void]$body.AppendLine(("(sys_id A: ``{0}`` | sys_id B: ``{1}``)" -f $d.sysId_a, $d.sysId_b))
            [void]$body.AppendLine("")
            [void]$body.AppendLine("| Field | A | B |")
            [void]$body.AppendLine("| --- | --- | --- |")
            foreach ($fd in $d.fields) {
                [void]$body.AppendLine(("| {0} | {1} | {2} |" -f $fd.field, (Escape-Cell $fd.a), (Escape-Cell $fd.b)))
            }
            [void]$body.AppendLine("")
        }
    }
}

[void]$report.AppendLine($summary.ToString())
[void]$report.AppendLine("")
[void]$report.AppendLine($body.ToString())

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
[System.IO.File]::WriteAllText($OutPath, $report.ToString(), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host ("Report written: " + $OutPath) -ForegroundColor Green
