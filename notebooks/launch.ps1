<#
.SYNOPSIS
    Launch JupyterLab in Simple Mode with the recording-friendly CSS overlay.
.DESCRIPTION
    Starts JupyterLab in the background, captures stdout, regexes the http://127.0.0.1:NNNN/lab?token=...
    URL out of the startup banner, and opens it in the default browser. Custom CSS at
    assets/recording.css hides the left sidebar/toolbar and highlights destructive cells.
.EXAMPLE
    PS> .\launch.ps1
#>
[CmdletBinding()]
param(
    [int]$Port = 8888
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Keep the venv OUT of Dropbox. Without this, uv puts .venv beside pyproject.toml,
# which means Dropbox sees ~5000 changing files every time we resolve deps.
$env:UV_PROJECT_ENVIRONMENT = Join-Path $HOME '.venvs\cka-c02'

$cssPath = Join-Path $PSScriptRoot 'assets\recording.css'
if (-not (Test-Path $cssPath)) {
    throw "Missing $cssPath. Restore from git or re-create from the plan."
}

Write-Host 'Starting JupyterLab...' -ForegroundColor Cyan
Write-Host "  cwd:       $PSScriptRoot"
Write-Host "  port:      $Port"
Write-Host "  custom css: $cssPath"

# Start in background so we can capture and parse the token URL.
$logFile = Join-Path $env:TEMP "jupyterlab-cka-c02-$PID.log"
$args = @(
    'run', 'jupyter', 'lab',
    '--no-browser',
    '--ip=127.0.0.1',
    "--port=$Port",
    '--ServerApp.token='   # disable token gate — Simple Mode + localhost is safe enough for our recording use
)
$proc = Start-Process -FilePath 'uv' -ArgumentList $args `
    -RedirectStandardOutput $logFile -RedirectStandardError "$logFile.err" `
    -NoNewWindow -PassThru

# Wait for JupyterLab to print its URL (typically <5 sec).
$url = $null
$deadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $deadline -and -not $url) {
    Start-Sleep -Milliseconds 500
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        if ($logContent -match 'http://127\.0\.0\.1:\d+/lab[^\s]*') {
            $url = $Matches[0]
        }
    }
}

if (-not $url) {
    # No token-bearing URL emitted (because we disabled the token). Fall back to the bare URL.
    $url = "http://127.0.0.1:$Port/lab"
}

Write-Host "`nJupyterLab is up: $url" -ForegroundColor Green
Write-Host "PID: $($proc.Id)  |  log: $logFile"
Write-Host "Stop with: Stop-Process -Id $($proc.Id)" -ForegroundColor DarkGray
Write-Host "`nNext step: View -> Simple Interface (or press Ctrl+Shift+D)" -ForegroundColor Yellow

Start-Process $url
