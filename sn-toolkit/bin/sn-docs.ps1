<#
.SYNOPSIS
    Search and read the official ServiceNow product docs (servicenow/servicenowdocs).
.DESCRIPTION
    Lazy-loaded mirror of github.com/servicenow/servicenowdocs. Subcommands surface
    paths and snippets, never bulk content, so Claude can answer ServiceNow platform
    questions from authoritative sources without bloating context.

    Cache lives at $env:LOCALAPPDATA\sn-toolkit\servicenow-docs\ -- outside the
    plugin dir (survives plugin upgrades) and outside OneDrive (no sync conflicts).
    Cache is opt-in: a fresh install does NOT auto-clone. Users opt in via
    /sn-toolkit:docs-setup. Without the cache, peek/read fall through to a single
    HTTP fetch from raw.githubusercontent.com.
.PARAMETER Command
    sync | status | list | search | peek | read | webfetch | help
.PARAMETER Arg1
    First positional arg. Meaning depends on Command:
      list <area>           -- product area name
      search <query>        -- search text
      peek  <path>          -- repo-relative file path (e.g. markdown/now-platform/acl.md)
      read  <path>          -- repo-relative file path
      webfetch <path>       -- repo-relative file path
.PARAMETER Area
    For 'search': restrict to a single product area folder.
.PARAMETER Max
    For 'search': cap on total hits (default 30).
.PARAMETER Lines
    For 'peek': head line count (default 30).
.NOTES
    Output is path/snippet shaped. Token discipline:
      - search: caps at -Max hits, 1 line of context per hit
      - peek:   head -Lines + section H2 outline, never full body
      - read:   only used after peek confirms relevance
    All output is ASCII-clean per sn-toolkit rule #1.
#>
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('sync','status','list','search','peek','read','webfetch','help')]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$Arg1,

    [string]$Area,
    [int]$Max = 30,
    [int]$Lines = 30
)

$ErrorActionPreference = 'Stop'

# --- Constants ----------------------------------------------------------------
$REPO_URL   = 'https://github.com/servicenow/servicenowdocs.git'
$REPO_BRANCH = 'australia'   # NOTE: upstream default branch is 'australia', not 'main'
$RAW_BASE   = "https://raw.githubusercontent.com/servicenow/servicenowdocs/$REPO_BRANCH"
$BLOB_BASE  = "https://github.com/servicenow/servicenowdocs/blob/$REPO_BRANCH"
$API_BASE   = 'https://api.github.com/repos/servicenow/servicenowdocs/contents'
$CACHE_ROOT = Join-Path $env:LOCALAPPDATA 'sn-toolkit'
$CACHE_DIR  = Join-Path $CACHE_ROOT 'servicenow-docs'
$STAMP_FILE = Join-Path $CACHE_DIR '.last-sync'

# --- Helpers ------------------------------------------------------------------
function Test-CachePresent {
    return (Test-Path (Join-Path $CACHE_DIR '.git')) -and (Test-Path (Join-Path $CACHE_DIR 'markdown'))
}

function Get-CacheAgeDays {
    if (-not (Test-Path $STAMP_FILE)) { return $null }
    $stamp = [datetime]::Parse((Get-Content $STAMP_FILE -Raw).Trim())
    return [int]([datetime]::UtcNow - $stamp).TotalDays
}

function Write-Stamp {
    [System.IO.File]::WriteAllText($STAMP_FILE, [datetime]::UtcNow.ToString('o'), [System.Text.Encoding]::UTF8)
}

function Invoke-Webfetch([string]$RelPath) {
    $url = "$RAW_BASE/$($RelPath -replace '\\','/')"
    try {
        return (Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop).Content
    } catch {
        Write-Error "Failed to fetch $url -- $($_.Exception.Message)"
        return $null
    }
}

function Get-RepoTopAreas {
    # GitHub contents API -- works with no cache; used by 'list' fallback.
    try {
        $resp = Invoke-WebRequest -Uri "$API_BASE/markdown" -UseBasicParsing -ErrorAction Stop
        $items = $resp.Content | ConvertFrom-Json
        return $items | Where-Object { $_.type -eq 'dir' } | ForEach-Object { $_.name }
    } catch {
        Write-Error "Failed to list product areas via GitHub API -- $($_.Exception.Message)"
        return @()
    }
}

# --- Commands -----------------------------------------------------------------

function Invoke-SubStatus {
    Write-Output "cache_path: $CACHE_DIR"
    if (-not (Test-CachePresent)) {
        Write-Output "cache_present: no"
        Write-Output "hint: run /sn-toolkit:docs-setup once to enable fast offline lookup"
        exit 2
    }
    Write-Output "cache_present: yes"
    $age = Get-CacheAgeDays
    if ($null -ne $age) { Write-Output "last_sync_days_ago: $age" }
    Push-Location $CACHE_DIR
    try {
        $sha = (& git rev-parse --short HEAD 2>$null)
        if ($LASTEXITCODE -eq 0) { Write-Output "head_sha: $sha" }
    } finally { Pop-Location }
    if ($null -ne $age -and $age -gt 30) {
        Write-Output "stale: yes (run /sn-toolkit:docs-sync to refresh; not auto-pulled)"
    }
    exit 0
}

function Invoke-SubSync {
    if (-not (Test-Path $CACHE_ROOT)) { New-Item -ItemType Directory -Path $CACHE_ROOT -Force | Out-Null }
    # Native git emits progress to stderr; PS 5.1 wraps that as NativeCommandError under
    # $ErrorActionPreference='Stop'. Temporarily relax for the git call only.
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    # -c core.longpaths=true:  Windows MAX_PATH workaround -- some doc paths exceed 260 chars.
    # -c core.ignorecase=true: tolerate case-insensitive filesystem collisions in the upstream tree.
    $gitOpts = @('-c','core.longpaths=true','-c','core.ignorecase=true')
    try {
        if (Test-CachePresent) {
            Write-Output "Refreshing existing cache at $CACHE_DIR ..."
            Push-Location $CACHE_DIR
            try { & git @gitOpts pull --ff-only } finally { Pop-Location }
            if ($LASTEXITCODE -ne 0) { Write-Output "ERROR: git pull failed (exit $LASTEXITCODE)"; exit 1 }
        } else {
            # If a partial clone left a .git/ behind, remove it so git clone can run.
            if (Test-Path $CACHE_DIR) { Remove-Item $CACHE_DIR -Recurse -Force -ErrorAction SilentlyContinue }
            Write-Output "Cloning servicenow/servicenowdocs (shallow + blobless) to $CACHE_DIR ..."
            Write-Output "This is a one-time ~150 MB download. Subsequent /sn-toolkit:docs-sync calls are incremental."
            & git @gitOpts clone --depth 1 --filter=blob:none $REPO_URL $CACHE_DIR
            $cloneExit = $LASTEXITCODE
            # Soft-tolerate checkout failures on Windows: clone-succeeded-checkout-failed (exit 128)
            # is common on Windows due to long paths or case-insensitive filename collisions in the
            # upstream tree. As long as 'markdown/' exists with most areas, the cache is usable.
            $mdDir = Join-Path $CACHE_DIR 'markdown'
            $areaCount = if (Test-Path $mdDir) { (Get-ChildItem $mdDir -Directory).Count } else { 0 }
            if ($cloneExit -ne 0 -and $areaCount -lt 40) {
                Write-Output "ERROR: git clone failed (exit $cloneExit) and only $areaCount product areas present"
                exit 1
            }
            if ($cloneExit -ne 0) {
                Write-Output ""
                Write-Output "NOTE: clone exited $cloneExit (Windows long-path or case-collision warnings)"
                Write-Output "      $areaCount product areas checked out -- cache is usable."
            }
        }
    } finally { $ErrorActionPreference = $prev }
    Write-Stamp
    $sizeMb = [math]::Round(((Get-ChildItem $CACHE_DIR -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
    Write-Output "Done. cache_size_mb: $sizeMb"
    Invoke-SubStatus
}

function Invoke-SubList {
    if ([string]::IsNullOrWhiteSpace($Arg1)) {
        # No area arg -- list product areas.
        if (Test-CachePresent) {
            Get-ChildItem (Join-Path $CACHE_DIR 'markdown') -Directory -ErrorAction SilentlyContinue |
                Sort-Object Name | ForEach-Object { Write-Output $_.Name }
        } else {
            Get-RepoTopAreas | Sort-Object | ForEach-Object { Write-Output $_ }
        }
        return
    }
    # Area arg -- list .md files under markdown/<area>/.
    $area = $Arg1.Trim()
    if (Test-CachePresent) {
        $areaDir = Join-Path $CACHE_DIR "markdown/$area"
        if (-not (Test-Path $areaDir)) { Write-Error "Unknown area '$area'. Run 'sn-docs list' to see valid areas."; exit 1 }
        Get-ChildItem $areaDir -Recurse -Filter '*.md' -File |
            ForEach-Object { ($_.FullName.Substring($CACHE_DIR.Length + 1)) -replace '\\','/' } |
            Sort-Object | Select-Object -First $Max
    } else {
        # GitHub API recursive listing is heavy; fall through to top-level only.
        try {
            $resp = Invoke-WebRequest -Uri "$API_BASE/markdown/$area" -UseBasicParsing -ErrorAction Stop
            ($resp.Content | ConvertFrom-Json) |
                ForEach-Object {
                    if ($_.type -eq 'file' -and $_.name -like '*.md') { "markdown/$area/$($_.name)" }
                    elseif ($_.type -eq 'dir') { "markdown/$area/$($_.name)/   (subdir -- list with cache for full tree)" }
                } | Sort-Object
        } catch { Write-Error "Failed to list area '$area' via GitHub API -- $($_.Exception.Message)"; exit 1 }
    }
}

function Invoke-SubSearch {
    if ([string]::IsNullOrWhiteSpace($Arg1)) { Write-Error "search requires a query string"; exit 1 }
    if (-not (Test-CachePresent)) {
        Write-Output "no_cache: search requires the local cache. Run /sn-toolkit:docs-setup once to enable."
        Write-Output "fallback: use 'sn-docs list <area>' + 'sn-docs peek <path>' for one-off discovery via GitHub API."
        exit 2
    }
    $searchRoot = Join-Path $CACHE_DIR 'markdown'
    if ($Area) { $searchRoot = Join-Path $searchRoot $Area }
    if (-not (Test-Path $searchRoot)) { Write-Error "Search root not found: $searchRoot"; exit 1 }
    # Prefer ripgrep if on PATH (much faster); fall back to PowerShell Select-String otherwise.
    $rg = Get-Command rg -ErrorAction SilentlyContinue
    $cacheDirNorm = $CACHE_DIR + [System.IO.Path]::DirectorySeparatorChar
    if ($rg) {
        Push-Location $CACHE_DIR
        try {
            # --path-separator / forces forward-slash paths so we can prefix-strip without
            # touching backslashes inside snippet content (markdown often has \(, \), \_).
            & rg -i -n --max-count 3 -t md --path-separator '/' $Arg1 (Resolve-Path $searchRoot).Path 2>$null |
                Select-Object -First $Max |
                ForEach-Object {
                    $cacheFwd = ($cacheDirNorm -replace '\\','/')
                    $_ -replace [regex]::Escape($cacheFwd), ''
                }
        } finally { Pop-Location }
    } else {
        # Select-String fallback. -SimpleMatch avoids regex surprises with user queries that
        # contain regex metachars (parens, brackets, etc.). Group by file, cap 3 hits per file.
        $hits = Get-ChildItem $searchRoot -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
            Select-String -Pattern $Arg1 -SimpleMatch -CaseSensitive:$false -ErrorAction SilentlyContinue
        $byFile = $hits | Group-Object Path
        $emitted = 0
        foreach ($g in $byFile) {
            foreach ($h in ($g.Group | Select-Object -First 3)) {
                if ($emitted -ge $Max) { break }
                $rel = ($h.Path -replace [regex]::Escape($cacheDirNorm), '') -replace '\\','/'
                $line = ($h.Line -replace '\s+',' ').Trim()
                if ($line.Length -gt 160) { $line = $line.Substring(0, 157) + '...' }
                Write-Output "${rel}:$($h.LineNumber):$line"
                $emitted++
            }
            if ($emitted -ge $Max) { break }
        }
    }
}

function Invoke-SubPeek {
    if ([string]::IsNullOrWhiteSpace($Arg1)) { Write-Error "peek requires a relative path"; exit 1 }
    $rel = $Arg1.Trim() -replace '\\','/'
    $content = $null
    if (Test-CachePresent) {
        $full = Join-Path $CACHE_DIR ($rel -replace '/','\')
        if (Test-Path $full) { $content = Get-Content $full -Raw }
    }
    if (-not $content) {
        $content = Invoke-Webfetch $rel
        if (-not $content) { exit 1 }
    }
    $allLines = $content -split "`n"
    Write-Output "--- head ($Lines lines of $($allLines.Count)) ---"
    $allLines | Select-Object -First $Lines | ForEach-Object { Write-Output $_ }
    Write-Output ""
    Write-Output "--- H2 outline ---"
    $allLines | Where-Object { $_ -match '^##\s+\S' } | ForEach-Object { Write-Output $_ }
    Write-Output ""
    Write-Output "source: $BLOB_BASE/$rel"
}

function Invoke-SubRead {
    if ([string]::IsNullOrWhiteSpace($Arg1)) { Write-Error "read requires a relative path"; exit 1 }
    $rel = $Arg1.Trim() -replace '\\','/'
    if (Test-CachePresent) {
        $full = Join-Path $CACHE_DIR ($rel -replace '/','\')
        if (Test-Path $full) { Get-Content $full -Raw; return }
    }
    $content = Invoke-Webfetch $rel
    if (-not $content) { exit 1 }
    Write-Output $content
}

function Invoke-SubWebfetch {
    if ([string]::IsNullOrWhiteSpace($Arg1)) { Write-Error "webfetch requires a relative path"; exit 1 }
    $rel = $Arg1.Trim() -replace '\\','/'
    $content = Invoke-Webfetch $rel
    if (-not $content) { exit 1 }
    Write-Output $content
}

function Invoke-SubHelp {
@'
sn-docs <command> [args]

Commands:
  sync                       Clone (shallow+blobless) or refresh the local docs mirror
  status                     Show cache state, age, head sha. Exit 2 if cache absent.
  list                       List 50 product-area folders
  list <area>                List .md files under markdown/<area>/
  search <query> [-Area X]   Ripgrep markdown for query (cache required)
  peek <path> [-Lines N]     First N lines + H2 outline (works with or without cache)
  read <path>                Full markdown (works with or without cache)
  webfetch <path>            Force HTTP fetch from raw.githubusercontent.com
  help                       This message

Examples:
  sn-docs status
  sn-docs list now-platform
  sn-docs search "ACL evaluation order" -Area now-platform
  sn-docs peek markdown/now-platform/acl.md
'@ | Write-Output
}

# --- Dispatch -----------------------------------------------------------------
switch ($Command) {
    'sync'     { Invoke-SubSync }
    'status'   { Invoke-SubStatus }
    'list'     { Invoke-SubList }
    'search'   { Invoke-SubSearch }
    'peek'     { Invoke-SubPeek }
    'read'     { Invoke-SubRead }
    'webfetch' { Invoke-SubWebfetch }
    'help'     { Invoke-SubHelp }
}
