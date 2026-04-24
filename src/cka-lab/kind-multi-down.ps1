#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tears down the cka-dev and cka-prod KIND clusters created by kind-multi-up.ps1.

.DESCRIPTION
    Deletes both clusters (idempotent -- skips any that don't exist) and removes
    their entries from kubeconfig. Optionally also clears the renamed contexts
    "dev" and "prod" if you ran rename-context during practice.

.PARAMETER ClearRenamed
    Also remove "dev" and "prod" contexts (in case you ran the rename step).

.PARAMETER Force
    Don't prompt for confirmation.

.EXAMPLE
    .\kind-multi-down.ps1
    Prompts, then deletes both clusters.

.EXAMPLE
    .\kind-multi-down.ps1 -Force -ClearRenamed
    Wipes both clusters and the renamed dev/prod contexts without prompting.
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ClearRenamed,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Continue"
$ProgressPreference   = "SilentlyContinue"

. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

Initialize-LabEncoding
Initialize-LabPath

$targets = @("cka-dev", "cka-prod")

Write-Output ""
Write-Output "============================================================"
Write-Output "  KIND Multi-Cluster Teardown"
Write-Output "============================================================"
Write-Output ""

$existing = Get-KindClusters
$toDelete = $targets | Where-Object { $_ -in $existing }

if ($toDelete.Count -eq 0) {
    Write-Info "Neither cka-dev nor cka-prod exists. Nothing to do."
    exit 0
}

Write-Info "Will delete: $($toDelete -join ', ')"
if (-not $Force) {
    $ans = Read-Host "Proceed? [y/N]"
    if ($ans -notmatch '^(y|Y)$') {
        Write-Info "Aborted."
        exit 0
    }
}

foreach ($name in $toDelete) {
    Write-Step "Deleting '$name'"
    kind delete cluster --name $name 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "'$name' deleted"
    } else {
        Write-ErrorMsg "Failed to delete '$name' (continuing)"
    }
}

# kubectl config delete-context fails (non-zero) if the context isn't there,
# which is expected on second runs. Suppress the noise but keep going.
if ($ClearRenamed) {
    Write-Step "Removing renamed contexts (dev, prod) from kubeconfig"
    foreach ($ctx in @("dev", "prod")) {
        kubectl config delete-context $ctx 2>$null | Out-Null
    }
    Write-Success "Renamed contexts cleared (if they existed)"
}

Write-Output ""
Write-Info "Remaining contexts:"
kubectl config get-contexts 2>&1

Write-Output ""
Write-Output "============================================================"
Write-Output "  Teardown complete"
Write-Output "============================================================"
Write-Output ""
