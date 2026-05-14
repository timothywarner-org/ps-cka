#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reports whether the cka-dev / cka-prod multi-cluster lab is up and offers teardown.

.DESCRIPTION
    Focused status probe for the multi-cluster context-practice lab. Pairs with
    kind-multi-up.ps1 / kind-multi-down.ps1 the same way kind-status.ps1 pairs
    with the single-cluster scripts.

    Reports per-cluster state (Running / Stopped / Missing), node counts, the
    current kubeconfig context, and any "renamed" contexts (dev / prod) left
    over from rename-context drills. If either cluster is up, offers to invoke
    kind-multi-down.ps1.

    Use kind-status.ps1 if you want a single combined view across the single-
    cluster lab AND the multi-cluster lab. This script is the focused variant.

.PARAMETER Quiet
    Skip the interactive teardown prompt. Exit 0 if neither multi-cluster is
    up, exit 1 if either is up. Useful for CI / pre-record sanity checks.

.PARAMETER ClearRenamed
    Pass -ClearRenamed through to kind-multi-down.ps1 if the user accepts the
    teardown prompt. Removes the "dev" / "prod" contexts created by the
    practice runner's rename-context drill.

.EXAMPLE
    .\kind-multi-status.ps1
    Reports state. If cka-dev or cka-prod is up, offers teardown.

.EXAMPLE
    .\kind-multi-status.ps1 -Quiet
    Report-only. Exit 0 if clean, exit 1 if either multi-cluster is up.

.NOTES
    Author: Tim Warner
    Requires: PowerShell 7+, KIND, Docker Desktop (or just kind on Linux)
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ClearRenamed,

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$ProgressPreference   = "SilentlyContinue"

. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

Initialize-LabEncoding
Initialize-LabPath

# Single source of truth for the multi-cluster targets. Same names that
# kind-multi-up.ps1 / kind-multi-down.ps1 use; if a third cluster is added
# there, mirror the change here.
$targets = @("cka-dev", "cka-prod")

Write-Output ""
Write-Output "============================================================"
Write-Output "  KIND Multi-Cluster Status - cka-dev + cka-prod"
Write-Output "============================================================"
Write-Output ""

# ---------------------------------------------------------------
# Step 1: Docker daemon
# ---------------------------------------------------------------
Write-Step "Step 1: Docker daemon"

if (-not (Test-DockerReady)) {
    Write-Info "Docker daemon is not responding."
    Write-Info "Without Docker, no KIND cluster can be running. Nothing to tear down."
    Write-Output ""
    exit 0
}
Write-Success "Docker daemon is responding"

# ---------------------------------------------------------------
# Step 2: Per-target presence + node count
# ---------------------------------------------------------------
# `kind get clusters` is authoritative for "the cluster exists in kind's view".
# `docker ps --filter` is authoritative for "the node containers are running
# right now". They can disagree (e.g. cluster registered but containers stopped
# manually). Surface both so the learner sees the actual state.
Write-Step "Step 2: Multi-cluster state"

$known = Get-KindClusters

$summary = foreach ($name in $targets) {
    $registered = $name -in $known
    $nodeCount  = 0
    $cpCount    = 0
    if ($registered) {
        $nodes = docker ps --filter "label=io.x-k8s.kind.cluster=$name" --format "{{.Names}}" 2>$null
        if (-not [string]::IsNullOrWhiteSpace($nodes)) {
            $list = $nodes -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            $nodeCount = $list.Count
            $cpCount   = ($list | Where-Object { $_ -match 'control-plane' }).Count
        }
    }

    [pscustomobject]@{
        Name       = $name
        Registered = $registered
        NodeCount  = $nodeCount
        CpCount    = $cpCount
    }
}

foreach ($s in $summary) {
    if (-not $s.Registered) {
        Write-Info ("{0,-10} : MISSING (not registered with kind)" -f $s.Name)
    } elseif ($s.NodeCount -eq 0) {
        Write-Info ("{0,-10} : REGISTERED but no node containers running" -f $s.Name)
    } else {
        $workers = $s.NodeCount - $s.CpCount
        Write-Info ("{0,-10} : RUNNING -- {1} node(s), {2} CP + {3} worker" -f `
            $s.Name, $s.NodeCount, $s.CpCount, $workers)
    }
}

# ---------------------------------------------------------------
# Step 3: Current kubeconfig context + renamed-context check
# ---------------------------------------------------------------
# The practice runner teaches `kubectl config rename-context kind-cka-dev dev`,
# so detect leftover dev / prod contexts and surface them — kind-multi-down
# alone won't remove them unless -ClearRenamed is passed.
Write-Step "Step 3: Kubeconfig contexts"

$current = kubectl config current-context 2>$null
if ($LASTEXITCODE -eq 0 -and $current) {
    Write-Info "Active context: $current"
} else {
    Write-Info "No active kubectl context"
}

$ctxRaw = kubectl config get-contexts -o name 2>$null
$allContexts = if ($LASTEXITCODE -eq 0 -and $ctxRaw) {
    $ctxRaw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
} else {
    @()
}

$renamed = $allContexts | Where-Object { $_ -in @('dev', 'prod') }
if ($renamed.Count -gt 0) {
    Write-Info "Leftover renamed context(s) from practice runner: $($renamed -join ', ')"
    Write-Info "Pass -ClearRenamed to remove them during teardown."
}

# ---------------------------------------------------------------
# Step 4: Decide whether teardown is even applicable
# ---------------------------------------------------------------
Write-Step "Step 4: Teardown options"

$anyUp = $summary | Where-Object { $_.Registered -or $_.NodeCount -gt 0 }

if (-not $anyUp) {
    Write-Success "Neither cka-dev nor cka-prod is up. Multi-cluster lab is clean."
    if ($renamed.Count -gt 0) {
        Write-Info "But leftover renamed contexts exist. Remove them with:"
        Write-Output "    kubectl config delete-context dev"
        Write-Output "    kubectl config delete-context prod"
    }
    Write-Output ""
    Write-Output "  To bring it up:  .\kind-multi-up.ps1"
    Write-Output ""
    exit 0
}

# Quiet mode: report-only. Exit 1 to signal "something is up" so callers
# (CI, pre-record check) can branch without parsing output.
if ($Quiet) {
    Write-Info "-Quiet specified -- skipping teardown prompt."
    Write-Output ""
    exit 1
}

$present = ($anyUp.Name) -join ' + '
Write-Output ""
Write-Output "Choose an action:"
Write-Output "  [0] Leave clusters running"
if ($ClearRenamed -or $renamed.Count -gt 0) {
    Write-Output "  [1] Tear down ($present) AND clear renamed contexts  ->  kind-multi-down.ps1 -ClearRenamed"
} else {
    Write-Output "  [1] Tear down ($present)  ->  kind-multi-down.ps1"
}
Write-Output ""

$choice = Read-Host "Enter choice [0]"
if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "0") {
    Write-Info "Leaving clusters running."
    Write-Output ""
    exit 0
}

if ($choice -eq "1") {
    $down = Join-Path -Path $PSScriptRoot -ChildPath "kind-multi-down.ps1"
    if (-not (Test-Path -Path $down)) {
        Write-ErrorMsg "kind-multi-down.ps1 not found next to this script."
        exit 1
    }

    # If user passed -ClearRenamed OR we detected leftover renamed contexts,
    # forward the flag so teardown unwinds them in one pass. -Force suppresses
    # the multi-down confirm prompt since the user already confirmed here.
    if ($ClearRenamed -or $renamed.Count -gt 0) {
        & $down -Force -ClearRenamed
    } else {
        & $down -Force
    }
} else {
    Write-ErrorMsg "Invalid choice '$choice'. Aborted."
    exit 1
}
