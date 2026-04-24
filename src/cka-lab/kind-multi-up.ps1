#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Stands up two KIND clusters (cka-dev + cka-prod) for kubectl context practice.

.DESCRIPTION
    Creates two independent KIND clusters side-by-side so you can practice the
    full context workflow: viewing, switching, renaming, namespacing, and
    one-shot --context overrides. Cluster topologies differ on purpose so
    `kubectl get nodes` looks visibly different on each.

        cka-dev   1 control-plane + 1 worker   ports 30100 / 30180
        cka-prod  1 control-plane + 2 workers  ports 30200 / 30280

    Cross-platform: PowerShell 7 on Windows Terminal or pwsh inside Ubuntu WSL2.

.PARAMETER SkipDdStart
    Skip Docker Desktop startup. Use when Docker is already running, or always
    on WSL2/Linux (where Docker Desktop runs on the Windows host).

.PARAMETER Force
    Bypass the NodePort host-port conflict prompt.

.PARAMETER Practice
    After both clusters are up, launch the interactive context practice runner
    (Start-ContextPractice.ps1).

.EXAMPLE
    .\kind-multi-up.ps1
    Creates cka-dev and cka-prod, prints a context cheat sheet.

.EXAMPLE
    .\kind-multi-up.ps1 -SkipDdStart -Practice
    Skips DD startup, then drops into the context practice runner.

.NOTES
    Author: Tim Warner
    Requires: Docker Desktop, KIND, kubectl, PowerShell 7+
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$DdTimeoutSeconds = 120,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDdStart,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$Practice
)

$ErrorActionPreference = "Continue"
$ProgressPreference   = "SilentlyContinue"

. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

Initialize-LabEncoding
Initialize-LabPath

# Cluster definitions kept in one table so adding a third cluster later is a
# one-line change. Ports are per-cluster so both can bind the host without
# colliding (kind allocates ALL extraPortMappings at create time).
$clusters = @(
    [pscustomobject]@{ Name = "cka-dev";  Config = "cka-dev.yaml";  Ports = @(30100, 30180); Description = "1 CP + 1 worker" },
    [pscustomobject]@{ Name = "cka-prod"; Config = "cka-prod.yaml"; Ports = @(30200, 30280); Description = "1 CP + 2 workers" }
)

Write-Output ""
Write-Output "============================================================"
Write-Output "  KIND Multi-Cluster Lab - Context Management Practice"
Write-Output "============================================================"
Write-Output ""
Write-Output "  This lab spins up TWO clusters so you can practice the"
Write-Output "  kubectl context workflow against real, distinct clusters:"
Write-Output ""
foreach ($c in $clusters) {
    $portStr = ($c.Ports -join ", ")
    Write-Output ("    {0,-9} {1,-20} ports {2}" -f $c.Name, $c.Description, $portStr)
}
Write-Output ""

# ---------------------------------------------------------------
# Step 1: Prerequisites
# ---------------------------------------------------------------
Write-Step "Step 1: Validating prerequisites"

$missing = Test-Prerequisites
if ($missing.Count -gt 0) {
    Write-ErrorMsg "Missing prerequisites:"
    foreach ($t in $missing) { Write-Output "  - $t" }
    exit 1
}

$configDir = Join-Path -Path $PSScriptRoot -ChildPath "configs"
foreach ($c in $clusters) {
    $path = Join-Path -Path $configDir -ChildPath $c.Config
    if (-not (Test-Path -Path $path)) {
        Write-ErrorMsg "Missing config: $path"
        exit 1
    }
}

Write-Success "All prerequisites verified"
Write-Info "KIND version: $(kind version)"

# ---------------------------------------------------------------
# Step 2: Docker Desktop
# ---------------------------------------------------------------
Write-Step "Step 2: Checking Docker daemon"

if (-not $SkipDdStart) { Start-DockerDesktop }
$effectiveTimeout = if ($SkipDdStart) { 15 } else { $DdTimeoutSeconds }
Wait-DockerReady -TimeoutSeconds $effectiveTimeout

# ---------------------------------------------------------------
# Step 3: NodePort preflight (across BOTH clusters)
# ---------------------------------------------------------------
# Two clusters means twice as many host ports. A single conflict on either set
# silently breaks the second `kind create` mid-flight, so check them all up
# front. Cross-platform probe via TcpListener bind (works on Windows + Linux).
Write-Step "Step 3: Checking host ports"

$allPorts = $clusters | ForEach-Object { $_.Ports } | Sort-Object -Unique
$busy = @()
foreach ($port in $allPorts) {
    $listener = $null
    $inUse = $false
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
        $listener.Start()
    } catch [System.Net.Sockets.SocketException] {
        $inUse = $true
    } finally {
        if ($listener) { try { $listener.Stop() } catch { } }
    }
    if ($inUse) { $busy += $port }
}

if ($busy.Count -gt 0) {
    Write-Warning "These host ports are already in use: $($busy -join ', ')"
    Write-Warning "kind create cluster will fail partway through if it can't bind them."
    if (-not $Force) {
        $ans = Read-Host "Continue anyway? [y/N]"
        if ($ans -notmatch '^(y|Y)$') {
            Write-Info "Aborted. Free the ports above (or pass -Force) and retry."
            exit 1
        }
    } else {
        Write-Info "-Force specified - proceeding despite port conflicts."
    }
} else {
    Write-Success "All host ports are free"
}

# ---------------------------------------------------------------
# Step 4: Create both clusters (idempotent, fail-fast on first error)
# ---------------------------------------------------------------
Write-Step "Step 4: Creating clusters"

foreach ($c in $clusters) {
    if (Test-ClusterExists -ClusterName $c.Name) {
        Write-Info "Cluster '$($c.Name)' already exists - skipping creation"
        continue
    }

    $cfgPath = Join-Path -Path $configDir -ChildPath $c.Config
    Write-Info "Creating '$($c.Name)' from $($c.Config)..."

    kind create cluster --name $c.Name --config $cfgPath --wait 120s 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "Failed to create cluster '$($c.Name)'. Aborting before second cluster."
        exit 1
    }
    Write-Success "Cluster '$($c.Name)' is up"
}

# ---------------------------------------------------------------
# Step 5: Verify and show context state
# ---------------------------------------------------------------
Write-Step "Step 5: Cluster + context summary"

foreach ($c in $clusters) {
    Write-Output ""
    Write-Info "Nodes for '$($c.Name)' (context: kind-$($c.Name)):"
    kubectl --context "kind-$($c.Name)" get nodes -o wide 2>&1
}

Write-Output ""
Write-Info "All kubeconfig contexts on this host:"
kubectl config get-contexts

Write-Output ""
Write-Info "Current context:"
$current = kubectl config current-context 2>&1
Write-Output "  $current"

# ---------------------------------------------------------------
# Cheat sheet
# ---------------------------------------------------------------
Write-Step "Context cheat sheet - try these against your two clusters"

$cheatSheet = @"

  VIEW
    kubectl config get-contexts
    kubectl config current-context
    kubectl config view --minify
    kubectl config view -o jsonpath='{.contexts[*].name}'

  SWITCH
    kubectl config use-context kind-cka-dev
    kubectl config use-context kind-cka-prod
    kubectl get nodes                         # whichever you're on now

  ONE-SHOT OVERRIDE  (no permanent switch)
    kubectl --context kind-cka-dev  get nodes
    kubectl --context kind-cka-prod get nodes

  RENAME  (kind- prefix is verbose; rename for ergonomics)
    kubectl config rename-context kind-cka-dev  dev
    kubectl config rename-context kind-cka-prod prod
    kubectl config use-context dev

  PER-CONTEXT DEFAULT NAMESPACE
    kubectl config set-context --current --namespace=kube-system
    kubectl get pods                          # uses kube-system now
    kubectl config set-context --current --namespace=default

  CLEAN UP
    .\kind-multi-down.ps1                     # destroys both clusters

"@

Write-Output $cheatSheet

Write-HostMemory

Write-Output ""
Write-Output "============================================================"
Write-Output "  Multi-cluster lab ready. Two contexts available:"
Write-Output "    kind-cka-dev   (1 CP + 1 worker)"
Write-Output "    kind-cka-prod  (1 CP + 2 workers)"
Write-Output "============================================================"
Write-Output ""

# ---------------------------------------------------------------
# Optional: drop into the practice runner
# ---------------------------------------------------------------
if ($Practice) {
    $practiceScript = Join-Path -Path $PSScriptRoot -ChildPath "Start-ContextPractice.ps1"
    if (Test-Path -Path $practiceScript) {
        & $practiceScript
    } else {
        Write-Info "Start-ContextPractice.ps1 not found - skipping interactive practice."
    }
}
