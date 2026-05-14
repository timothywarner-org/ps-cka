#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reports whether any CKA KIND clusters are running and offers to tear them down.

.DESCRIPTION
    Read-only status probe for the CKA lab environment. Detects three categories
    of state and, if anything is up, offers to invoke the matching teardown:

        Single-cluster lab  -> cka-lab            -> kind-down.ps1
        Multi-cluster lab   -> cka-dev / cka-prod -> kind-multi-down.ps1
        Other KIND clusters -> reported only (never touched -- could be another
                               project's cluster on the same Docker daemon)

    Always safe to run. Reports Docker daemon status, lists every KIND cluster
    visible to `kind get clusters`, shows node counts, and surfaces the current
    kubeconfig context. With -Quiet, exits without prompting (useful for CI or
    pre-record sanity checks).

.PARAMETER Quiet
    Skip the interactive teardown prompt. Just report and exit. Exit code 0 if
    no CKA clusters are up, 1 if any CKA cluster is up.

.PARAMETER ClusterName
    Single-cluster lab name to look for. Default: cka-lab (matches kind-up.ps1).

.EXAMPLE
    .\kind-status.ps1
    Reports state. If a cka-lab / cka-dev / cka-prod is up, offers teardown.

.EXAMPLE
    .\kind-status.ps1 -Quiet
    Report-only. Exit 0 if clean, exit 1 if any CKA cluster is up.

.NOTES
    Author: Tim Warner
    Requires: PowerShell 7+, KIND, Docker Desktop (or just kind on Linux)
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "cka-lab",

    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$ProgressPreference   = "SilentlyContinue"

. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

Initialize-LabEncoding
Initialize-LabPath

# Multi-cluster targets are fixed (matches kind-multi-up.ps1's $clusters table).
# Keep this in sync if a third multi-cluster lab gets added there.
$multiTargets = @("cka-dev", "cka-prod")

Write-Output ""
Write-Output "============================================================"
Write-Output "  KIND Cluster Status - CKA Lab Environment"
Write-Output "============================================================"
Write-Output ""

# ---------------------------------------------------------------
# Step 1: Docker daemon
# ---------------------------------------------------------------
Write-Step "Step 1: Docker daemon"

$dockerUp = Test-DockerReady
if ($dockerUp) {
    Write-Success "Docker daemon is responding"
} else {
    Write-Info "Docker daemon is not responding."
    Write-Info "Without Docker, no KIND cluster can be running. Nothing to tear down."
    Write-Output ""
    exit 0
}

# ---------------------------------------------------------------
# Step 2: Enumerate KIND clusters and bucket them
# ---------------------------------------------------------------
Write-Step "Step 2: KIND clusters on this host"

$all = Get-KindClusters

if ($all.Count -eq 0) {
    Write-Success "No KIND clusters are running. Lab is clean."
    Write-Output ""
    Write-Output "  To bring something up:"
    Write-Output "    .\kind-up.ps1            single-cluster lab"
    Write-Output "    .\kind-multi-up.ps1      two-cluster context lab (cka-dev + cka-prod)"
    Write-Output ""
    exit 0
}

# Bucket: single, multi (split into present/missing for clarity), other.
$singleUp = ($ClusterName -in $all)
$multiUp  = $all | Where-Object { $_ -in $multiTargets }
$other    = $all | Where-Object { $_ -ne $ClusterName -and $_ -notin $multiTargets }

Write-Info "Found $($all.Count) KIND cluster(s):"
foreach ($c in $all) {
    $tag = if ($c -eq $ClusterName) {
        "[single-cluster lab]"
    } elseif ($c -in $multiTargets) {
        "[multi-cluster lab]"
    } else {
        "[other / unknown]"
    }
    Write-Output ("    {0,-20} {1}" -f $c, $tag)
}

# ---------------------------------------------------------------
# Step 3: Per-cluster node summary
# ---------------------------------------------------------------
# `docker ps --filter label=io.x-k8s.kind.cluster=<name>` is cheaper and more
# reliable than `kubectl --context kind-<name> get nodes` -- it doesn't depend
# on the kubeconfig still pointing at a valid context, and it works even if
# the API server is briefly unreachable (e.g. mid-restart).
Write-Step "Step 3: Node counts"

foreach ($c in $all) {
    $nodes = docker ps --filter "label=io.x-k8s.kind.cluster=$c" --format "{{.Names}}" 2>$null
    if ([string]::IsNullOrWhiteSpace($nodes)) {
        Write-Info "${c}: no running node containers (cluster may be stopped)"
        continue
    }
    $nodeList = $nodes -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $cpCount     = ($nodeList | Where-Object { $_ -match 'control-plane' }).Count
    $workerCount = $nodeList.Count - $cpCount
    Write-Info "${c}: $($nodeList.Count) node(s) -- $cpCount control-plane + $workerCount worker"
}

# ---------------------------------------------------------------
# Step 4: Current kubeconfig context
# ---------------------------------------------------------------
Write-Step "Step 4: Current kubeconfig context"

$current = kubectl config current-context 2>$null
if ($LASTEXITCODE -eq 0 -and $current) {
    Write-Info "Active context: $current"
} else {
    Write-Info "No active kubectl context (or kubectl not configured)"
}

# ---------------------------------------------------------------
# Step 5: Offer teardown(s)
# ---------------------------------------------------------------
Write-Step "Step 5: Teardown options"

# Build a list of available teardown actions so we can prompt with one menu
# rather than chaining yes/no prompts. Each entry is { label, action-scriptblock }.
$actions = [System.Collections.Generic.List[object]]::new()

if ($singleUp) {
    $actions.Add([pscustomobject]@{
        Key    = ($actions.Count + 1).ToString()
        Label  = "Tear down single-cluster lab ($ClusterName)  ->  kind-down.ps1"
        Script = {
            $down = Join-Path -Path $PSScriptRoot -ChildPath "kind-down.ps1"
            if (Test-Path -Path $down) {
                & $down -ClusterName $ClusterName
            } else {
                Write-ErrorMsg "kind-down.ps1 not found next to this script."
            }
        }
    })
}

if ($multiUp.Count -gt 0) {
    $present = ($multiUp -join ' + ')
    $actions.Add([pscustomobject]@{
        Key    = ($actions.Count + 1).ToString()
        Label  = "Tear down multi-cluster lab ($present)  ->  kind-multi-down.ps1"
        Script = {
            $down = Join-Path -Path $PSScriptRoot -ChildPath "kind-multi-down.ps1"
            if (Test-Path -Path $down) {
                & $down
            } else {
                Write-ErrorMsg "kind-multi-down.ps1 not found next to this script."
            }
        }
    })
}

if ($singleUp -and $multiUp.Count -gt 0) {
    $actions.Add([pscustomobject]@{
        Key    = ($actions.Count + 1).ToString()
        Label  = "Tear down BOTH labs (single + multi)"
        Script = {
            $kindDown = Join-Path -Path $PSScriptRoot -ChildPath "kind-down.ps1"
            $multiDown = Join-Path -Path $PSScriptRoot -ChildPath "kind-multi-down.ps1"
            if (Test-Path -Path $kindDown)  { & $kindDown -ClusterName $ClusterName }
            if (Test-Path -Path $multiDown) { & $multiDown -Force }
        }
    })
}

if ($other.Count -gt 0) {
    Write-Info "Other KIND clusters detected (not touched by this script):"
    foreach ($o in $other) {
        Write-Output "    $o"
    }
    Write-Info "Tear them down manually with: kind delete cluster --name <name>"
}

if ($actions.Count -eq 0) {
    Write-Success "No CKA-owned clusters are up. Nothing to tear down."
    Write-Output ""
    exit 0
}

# Quiet mode: report-only. Exit 1 to signal "something is up" so callers
# (CI, pre-record check) can branch on it without parsing output.
if ($Quiet) {
    Write-Info "-Quiet specified -- skipping teardown prompt."
    Write-Output ""
    exit 1
}

Write-Output ""
Write-Output "Choose a teardown action:"
Write-Output "  [0] Leave everything running"
foreach ($a in $actions) {
    Write-Output "  [$($a.Key)] $($a.Label)"
}
Write-Output ""

$choice = Read-Host "Enter choice [0]"
if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq "0") {
    Write-Info "Leaving clusters running."
    Write-Output ""
    exit 0
}

$selected = $actions | Where-Object { $_.Key -eq $choice } | Select-Object -First 1
if (-not $selected) {
    Write-ErrorMsg "Invalid choice '$choice'. Aborted."
    exit 1
}

Write-Output ""
Write-Info "Running: $($selected.Label)"
Write-Output ""
& $selected.Script
