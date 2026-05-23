<#
.SYNOPSIS
    Strip all output cells from every .ipynb in this folder.
.DESCRIPTION
    Run this before every recording take. Stale outputs from rehearsals are a leading
    cause of "wait, where did that output come from?" moments on camera. Also run before
    every commit to keep diffs reviewable.
.EXAMPLE
    PS> .\clear-outputs.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

# Keep the venv OUT of Dropbox (see launch.ps1 for the why).
$env:UV_PROJECT_ENVIRONMENT = Join-Path $HOME '.venvs\cka-c02'

$notebooks = Get-ChildItem -Path . -Filter 'c02-m*.ipynb' -File
if (-not $notebooks) {
    Write-Host "No notebooks found in $PSScriptRoot. Nothing to clear." -ForegroundColor Yellow
    exit 0
}

Write-Host "Clearing outputs in $($notebooks.Count) notebook(s)..." -ForegroundColor Cyan
foreach ($nb in $notebooks) {
    Write-Host "  - $($nb.Name)"
    & uv run jupyter nbconvert --clear-output --inplace $nb.FullName 2>&1 |
        Where-Object { $_ -notmatch '^\[NbConvertApp\]' } |
        Out-String -Stream | ForEach-Object { if ($_) { Write-Host "      $_" -ForegroundColor DarkGray } }
}
Write-Host "Done. Notebooks ready for recording." -ForegroundColor Green
