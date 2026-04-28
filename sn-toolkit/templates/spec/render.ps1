# sn-toolkit -- Spec HTML -> PDF renderer
#
# Usage:
#   powershell.exe -ExecutionPolicy Bypass -File render.ps1 -InputHtml <path>
#   powershell.exe -ExecutionPolicy Bypass -File render.ps1 -InputHtml <path> -OutputPdf <path>
#
# If -OutputPdf is omitted, the PDF is written next to the HTML with the same basename.
#
# Uses headless Chrome (preferred) or Edge. No dependencies beyond the browser.
# Topic-agnostic; safe to use for any spec doc rendered via the sn-toolkit spec template.

param(
    [Parameter(Mandatory=$true)] [string]$InputHtml,
    [string]$OutputPdf
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $InputHtml)) {
    throw "Input HTML not found: $InputHtml"
}

$inputFull = (Resolve-Path -LiteralPath $InputHtml).Path
if (-not $OutputPdf) {
    $OutputPdf = [IO.Path]::ChangeExtension($inputFull, '.pdf')
}

# Prefer Chrome, fall back to Edge.
$candidates = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
)

$browser = $null
foreach ($c in $candidates) {
    if ($c -and (Test-Path -LiteralPath $c)) { $browser = $c; break }
}
if (-not $browser) {
    throw "Could not locate Chrome or Edge. Install one or edit render.ps1."
}

# file:// URI with forward slashes, as Chrome expects.
$fileUri = 'file:///' + ($inputFull -replace '\\','/')

$args = @(
    '--headless=new',
    '--disable-gpu',
    '--virtual-time-budget=10000',
    "--print-to-pdf=$OutputPdf",
    $fileUri
)

Write-Host "Rendering: $inputFull"
Write-Host "    using: $browser"
Write-Host "       to: $OutputPdf"

& $browser @args | Out-Null
if ($LASTEXITCODE -ne 0 -and -not (Test-Path -LiteralPath $OutputPdf)) {
    throw "Render failed (exit $LASTEXITCODE). No PDF produced."
}

$info = Get-Item -LiteralPath $OutputPdf
Write-Host ("Done. {0:N0} bytes." -f $info.Length)
