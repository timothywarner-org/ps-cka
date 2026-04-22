<#
.SYNOPSIS
    Starts Docker Desktop, waits for readiness, and creates a KIND cluster for CKA training.

.DESCRIPTION
    Full lifecycle startup script for Tim's CKA certification lab environment.
    Presents an interactive menu to choose cluster topology:
    - Simple:    1 control-plane + 1 worker  (quick practice)
    - Standard:  1 control-plane + 2 workers (CKA exam topology)
    - HA:        3 control-plane + 2 workers (etcd quorum, HA exercises)
    - Workloads: 1 control-plane + 3 workers (scheduling, affinity, taints)

    Handles all prerequisites automatically:
    - Launches Docker Desktop if not already running
    - Polls the Docker daemon until it responds (DD can take 30-60 seconds)
    - Creates the KIND cluster with the chosen topology
    - Verifies all nodes reach Ready status
    - Displays resource usage summary

    The cluster config includes CKA-relevant settings:
    - PodSecurity and NodeRestriction admission plugins
    - NodePort mappings on 30000, 30080, 30443
    - containerd runtime (matches CKA exam environment)

.PARAMETER ClusterName
    Name for the KIND cluster. Default: cka-lab

.PARAMETER ConfigPath
    Path to the KIND cluster config YAML. When specified, skips the topology menu.
    Default: presents interactive menu to choose topology.

.PARAMETER DdTimeoutSeconds
    Max seconds to wait for Docker Desktop to become ready. Default: 120

.PARAMETER SkipDdStart
    Skip Docker Desktop startup (use if DD is already running). Default: false

.PARAMETER ShowKubeadm
    Show detailed output from KIND including kubeadm/kubectl commands running
    under the hood. Useful for teaching what KIND does internally.

.PARAMETER Tutorial
    After cluster creation, run an interactive guided walkthrough of all
    Kubernetes components. Pauses between sections so learners can follow along.

.EXAMPLE
    .\kind-up.ps1
    Presents topology menu, starts Docker Desktop, creates cluster, verifies nodes.

.EXAMPLE
    .\kind-up.ps1 -SkipDdStart
    Skips DD startup (already running), presents menu, creates cluster.

.EXAMPLE
    .\kind-up.ps1 -ConfigPath .\configs\cka-3node.yaml
    Skips menu, uses specified config directly.

.EXAMPLE
    .\kind-up.ps1 -ShowKubeadm
    Shows kubeadm/kubectl commands KIND runs under the hood (great for teaching).

.EXAMPLE
    .\kind-up.ps1 -Tutorial
    Creates cluster then walks through a guided tour of all K8s components.

.NOTES
    Author: Tim Warner
    Version: 2.0
    Requires: Docker Desktop, KIND, kubectl
    Tested: PowerShell 7.x, Windows 11
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "cka-lab",

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "",

    [Parameter(Mandatory = $false)]
    [int]$DdTimeoutSeconds = 120,

    [Parameter(Mandatory = $false)]
    [switch]$SkipDdStart,

    [Parameter(Mandatory = $false)]
    [switch]$ShowKubeadm,

    [Parameter(Mandatory = $false)]
    [switch]$Tutorial,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Source shared library (provides helpers, Docker mgmt, tutorials, etc.)
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

# Must run before any external command so kind/kubectl/docker UTF-8 output
# (bullets, checkmarks, emoji) renders correctly on the Windows console.
Initialize-LabEncoding

Initialize-LabPath

# Banner
Write-Output ""
Write-Output "============================================================"
Write-Output "  KIND Cluster Startup - CKA Lab Environment"
Write-Output "============================================================"
Write-Output ""

# ---------------------------------------------------------------
# Topology menu (skip if -ConfigPath was explicitly passed)
# ---------------------------------------------------------------
$configDir = Join-Path -Path $PSScriptRoot -ChildPath "configs"
$ConfigPathExplicit = $PSBoundParameters.ContainsKey('ConfigPath') -and $ConfigPath -ne ""

if (-not $ConfigPathExplicit) {
    Write-Output "Select cluster topology:"
    Write-Output "  [1] Simple    - 1 control-plane + 1 worker  (quick practice)"
    Write-Output "  [2] Standard  - 1 control-plane + 2 workers (CKA exam topology)"
    Write-Output "  [3] HA        - 3 control-plane + 2 workers (HA / etcd quorum)"
    Write-Output "  [4] Workloads - 1 control-plane + 3 workers (scheduling, affinity, taints)"
    Write-Output ""
    $choice = Read-Host "Enter choice [1]"
    switch ($choice) {
        { $_ -eq "" -or $_ -eq "1" } {
            $ConfigPath = Join-Path -Path $configDir -ChildPath "cka-simple.yaml"
            $nodeDescription = "1 control-plane + 1 worker"
            $nodeCount = 2
        }
        "2" {
            $ConfigPath = Join-Path -Path $configDir -ChildPath "cka-3node.yaml"
            $nodeDescription = "1 control-plane + 2 workers"
            $nodeCount = 3
        }
        "3" {
            $ConfigPath = Join-Path -Path $configDir -ChildPath "cka-ha.yaml"
            $nodeDescription = "3 control-plane + 2 workers (HA)"
            $nodeCount = 5
        }
        "4" {
            $ConfigPath = Join-Path -Path $configDir -ChildPath "cka-workloads.yaml"
            $nodeDescription = "1 control-plane + 3 workers (workloads)"
            $nodeCount = 4
        }
        default {
            Write-ErrorMsg "Invalid choice '$choice'. Please enter 1, 2, 3, or 4."
            exit 1
        }
    }
    Write-Output ""
    Write-Output "  >> $nodeDescription selected"
    Write-Output ""
} else {
    # Backward compat: if the path doesn't exist, try configs/ subdirectory
    if (-not (Test-Path -Path $ConfigPath)) {
        $fileName = Split-Path -Leaf $ConfigPath
        $fallback = Join-Path -Path $configDir -ChildPath $fileName
        if (Test-Path -Path $fallback) {
            Write-Info "Config moved to configs/ — resolving: $fallback"
            $ConfigPath = $fallback
        }
    }

    # Infer node count from config file
    if (Test-Path -Path $ConfigPath) {
        $yamlContent = Get-Content -Path $ConfigPath -Raw
        $nodeCount = ([regex]::Matches($yamlContent, '^\s*- role:\s+(control-plane|worker)', 'Multiline')).Count
        $nodeDescription = "$nodeCount nodes (custom config)"
    } else {
        $nodeDescription = "custom config"
        $nodeCount = 0
    }
}

# ---------------------------------------------------------------
# Verbose mode prompt (skip if -ShowKubeadm was explicitly passed)
# ---------------------------------------------------------------
$doShowKubeadm = [bool]$ShowKubeadm
if (-not $PSBoundParameters.ContainsKey('ShowKubeadm')) {
    $verboseChoice = Read-Host "Show kubeadm/kubectl commands KIND runs under the hood? [y/N]"
    switch ($verboseChoice) {
        { $_ -eq "y" -or $_ -eq "Y" } {
            $doShowKubeadm = $true
            Write-Output "  >> Verbose mode enabled — will show kubeadm internals"
        }
        default {
            $doShowKubeadm = $false
        }
    }
    Write-Output ""
}

# ---------------------------------------------------------------
# Tutorial mode prompt (skip if -Tutorial was explicitly passed)
# ---------------------------------------------------------------
$tutorialSelection = ""
if ($PSBoundParameters.ContainsKey('Tutorial') -and $Tutorial) {
    $tutorialSelection = "components"
} else {
    Write-Output "Run a guided tutorial after cluster creation?"
    Write-Output "  [0] No tutorial              (skip)"
    Write-Output "  [1] Component Walkthrough    (verify all K8s components)"
    Write-Output "  [2] Course 1, Module 1       (architecture & lab setup)"
    Write-Output "  [3] Course 1, Module 2       (kubectl workflows)"
    Write-Output "  [4] Course 1, Module 3       (core resources & diagnostics)"
    Write-Output ""
    $tutChoice = Read-Host "Enter choice [0]"
    switch ($tutChoice) {
        { $_ -eq "" -or $_ -eq "0" } {
            $tutorialSelection = ""
        }
        "1" {
            $tutorialSelection = "components"
            Write-Output "  >> Component walkthrough selected"
        }
        "2" {
            $tutorialSelection = "m01"
            Write-Output "  >> Course 1, Module 1 tutorial selected"
        }
        "3" {
            $tutorialSelection = "m02"
            Write-Output "  >> Course 1, Module 2 tutorial selected"
        }
        "4" {
            $tutorialSelection = "m03"
            Write-Output "  >> Course 1, Module 3 tutorial selected"
        }
        default {
            Write-ErrorMsg "Invalid choice '$tutChoice'. Please enter 0, 1, 2, 3, or 4."
            exit 1
        }
    }
    Write-Output ""
}

# ---------------------------------------------------------------
# Step 1: Validate prerequisites
# ---------------------------------------------------------------
Write-Step "Step 1: Validating prerequisites"

$missingTools = Test-Prerequisites
if ($missingTools.Count -gt 0) {
    Write-ErrorMsg "Missing prerequisites:"
    foreach ($tool in $missingTools) {
        Write-Output "  - $tool"
    }
    exit 1
}

if (-not (Test-Path -Path $ConfigPath)) {
    Write-ErrorMsg "KIND cluster config not found: $ConfigPath"
    exit 1
}

Write-Success "All prerequisites verified"
Write-Info "KIND version: $(kind version)"
Write-Info "Config: $ConfigPath"

# ---------------------------------------------------------------
# Step 2: Start Docker Desktop and wait for daemon readiness
# ---------------------------------------------------------------
Write-Step "Step 2: Starting Docker Desktop"

if (-not $SkipDdStart) {
    Start-DockerDesktop
}

$effectiveTimeout = if ($SkipDdStart) { 15 } else { $DdTimeoutSeconds }
Wait-DockerReady -TimeoutSeconds $effectiveTimeout

# ---------------------------------------------------------------
# Step 3: Create the KIND cluster (idempotent)
# ---------------------------------------------------------------
Write-Step "Step 3: Creating KIND cluster"

if (Test-ClusterExists -ClusterName $ClusterName) {
    Write-Info "Cluster '$ClusterName' already exists - skipping creation"
    Write-Info "To rebuild, run kind-down.ps1 first, then kind-up.ps1"
} else {
    Write-Info "Creating ${nodeCount}-node cluster '$ClusterName'..."
    Write-Info "This pulls node images and runs kubeadm - expect 2-4 minutes on first run."
    Write-Output ""

    # NodePort host-port preflight. All configs bind 30000/30080/30443 on the host.
    # If another dev tool (a running webapp, reverse proxy, etc.) already owns
    # one of these ports, kind fails partway through with a confusing containerd
    # error. Warn early so Tim isn't blocked on camera. Non-fatal by default;
    # -Force (or user confirmation) suppresses the prompt.
    # Cross-platform: Get-NetTCPConnection is Windows-only, so on Linux/macOS
    # (PS7 on WSL2) we probe by trying to bind a TcpListener on 0.0.0.0:<port>.
    # Bind success -> port free; SocketException -> port busy. Process name is
    # a best-effort lookup via Get-Process on Windows, `ss` on Linux, `lsof` on
    # macOS -- if we can't resolve it we fall back to '<unknown>'.
    $portsToCheck = @(30000, 30080, 30443)
    $portsInUse = @()
    foreach ($port in $portsToCheck) {
        $inUse = $false
        $owner = '<unknown>'
        if ($IsWindows) {
            $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Listen' } | Select-Object -First 1
            if ($conn) {
                $inUse = $true
                $owner = try {
                    (Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue).ProcessName
                } catch { '<unknown>' }
            }
        } else {
            $listener = $null
            try {
                $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
                $listener.Start()
            } catch [System.Net.Sockets.SocketException] {
                $inUse = $true
            } finally {
                if ($listener) { try { $listener.Stop() } catch { } }
            }
            if ($inUse) {
                # Try `ss -ltnp` (Linux) then `lsof` (macOS) for the process name.
                # Both are best-effort; process name often requires matching-user
                # privileges, so a blank result just means we keep '<unknown>'.
                try {
                    $ssOut = & ss -ltnp "sport = :$port" 2>$null | Out-String
                    if ($ssOut -match 'users:\(\("([^"]+)"') { $owner = $Matches[1] }
                } catch { }
                if ($owner -eq '<unknown>') {
                    try {
                        $lsofOut = & lsof -nP -iTCP:$port -sTCP:LISTEN 2>$null | Out-String
                        if ($lsofOut -match '(?m)^(\S+)\s+\d+') { $owner = $Matches[1] }
                    } catch { }
                }
            }
        }
        if ($inUse) {
            $portsInUse += [pscustomobject]@{ Port = $port; Process = $owner }
        }
    }
    if ($portsInUse.Count -gt 0) {
        Write-Warning "The following NodePort host-ports are already in use:"
        foreach ($p in $portsInUse) {
            Write-Warning "  - Port $($p.Port) (held by: $($p.Process))"
        }
        Write-Warning "kind create cluster may fail partway through with a containerd error."
        Write-Warning "Close the conflicting app, or re-run with -Force to proceed anyway."
        if (-not $Force) {
            $continueChoice = Read-Host "Continue anyway? [y/N]"
            if ($continueChoice -notmatch '^(y|Y)$') {
                Write-Info "Aborted. Free the port(s) above and try again."
                exit 1
            }
        } else {
            Write-Info "-Force specified - proceeding despite port conflicts."
        }
        Write-Output ""
    }

    # Topology-aware --wait timeout. Defaults chosen to tolerate cold image cache:
    #   cka-ha.yaml        -> 300s (5 nodes, 3 CP with etcd quorum negotiation)
    #   cka-workloads.yaml -> 180s (4 nodes, label/taint follow-up)
    #   others (simple/3node or custom) -> 120s (2-3 nodes, fast path)
    $configLeaf = Split-Path -Leaf $ConfigPath
    $waitTimeout = switch ($configLeaf) {
        "cka-ha.yaml"        { "300s" }
        "cka-workloads.yaml" { "180s" }
        default              { "120s" }
    }
    Write-Info "Using --wait $waitTimeout for topology '$configLeaf'"

    if ($doShowKubeadm) {
        Write-Output ""
        Write-Output "  ┌──────────────────────────────────────────────────────────────┐"
        Write-Output "  │  VERBOSE MODE: Showing what KIND does under the hood         │"
        Write-Output "  │                                                              │"
        Write-Output "  │  KIND automates these steps that you'd do manually:          │"
        Write-Output "  │    1. Pulls a node image (kindest/node) with K8s built in    │"
        Write-Output "  │    2. Creates Docker containers to act as 'nodes'            │"
        Write-Output "  │    3. Runs kubeadm init on the control-plane node            │"
        Write-Output "  │    4. Installs a CNI (kindnet) for pod networking            │"
        Write-Output "  │    5. Runs kubeadm join on each worker node                  │"
        Write-Output "  │    6. Writes a kubeconfig to your host                       │"
        Write-Output "  └──────────────────────────────────────────────────────────────┘"
        Write-Output ""

        kind create cluster --name $ClusterName --config $ConfigPath --wait $waitTimeout -v 6 2>&1
    } else {
        kind create cluster --name $ClusterName --config $ConfigPath --wait $waitTimeout 2>&1
    }

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "KIND cluster creation failed. Check Docker Desktop logs and available disk space."
        exit 1
    }

    Write-Success "Cluster '$ClusterName' created successfully"

    # Apply node labels and taints for the workloads topology
    $configName = Split-Path -Leaf $ConfigPath
    if ($configName -eq "cka-workloads.yaml") {
        Write-Output ""
        Write-Info "Applying node labels and taints for scheduling exercises..."

        # kubectl calls can race 'kind create' completion: nodes are Ready but the
        # API server may briefly 404 on node names. Retry with backoff so a transient
        # failure doesn't leave the cluster half-configured for scheduling demos.
        function Invoke-KubectlWithRetry {
            param(
                [Parameter(Mandatory = $true)][string[]]$KubectlArgs,
                [int]$MaxAttempts = 3,
                [int]$DelaySeconds = 2
            )
            for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
                & kubectl @KubectlArgs 2>&1
                if ($LASTEXITCODE -eq 0) { return $true }
                if ($attempt -lt $MaxAttempts) {
                    Write-Info "kubectl $($KubectlArgs -join ' ') failed (attempt $attempt/$MaxAttempts), retrying in ${DelaySeconds}s..."
                    Start-Sleep -Seconds $DelaySeconds
                }
            }
            return $false
        }

        $labelTaintOk = $true
        $labelTaintOk = (Invoke-KubectlWithRetry -KubectlArgs @('label','node',"${ClusterName}-worker",'zone=east','tier=frontend','--overwrite')) -and $labelTaintOk
        $labelTaintOk = (Invoke-KubectlWithRetry -KubectlArgs @('label','node',"${ClusterName}-worker2",'zone=west','tier=backend','--overwrite')) -and $labelTaintOk
        $labelTaintOk = (Invoke-KubectlWithRetry -KubectlArgs @('label','node',"${ClusterName}-worker3",'zone=east','tier=backend','--overwrite')) -and $labelTaintOk
        $labelTaintOk = (Invoke-KubectlWithRetry -KubectlArgs @('taint','node',"${ClusterName}-worker3",'dedicated=special:NoSchedule','--overwrite')) -and $labelTaintOk

        if ($labelTaintOk) {
            Write-Success "Node labels and taints applied"
        } else {
            Write-Warning "One or more label/taint commands failed after retries. The cluster is usable, but scheduling demos that rely on zone/tier/dedicated may not work. Inspect with: kubectl get nodes --show-labels"
        }
        Write-Output ""
        Write-Info "Try these CKA exercises:"
        Write-Output "  kubectl get nodes --show-labels"
        Write-Output "  kubectl describe node ${ClusterName}-worker3 | Select-String Taint"
        Write-Output "  kubectl create deployment nginx --image=nginx --replicas=6"
        Write-Output "  kubectl get pods -o wide   # observe pod spread across workers"
    }
}

# ---------------------------------------------------------------
# Step 4: Verify cluster health
# ---------------------------------------------------------------
Write-Step "Step 4: Verifying cluster health"

$currentContext = kubectl config current-context 2>&1
Write-Info "Kubeconfig context: $currentContext"

Write-Info "Waiting for all nodes to reach Ready status..."
$maxNodeWait = 60
$nodeElapsed = 0

while ($nodeElapsed -lt $maxNodeWait) {
    $notReady = kubectl get nodes --no-headers 2>&1 | Select-String "NotReady"
    if (-not $notReady) {
        break
    }
    Start-Sleep -Seconds 5
    $nodeElapsed += 5
}

if ($nodeElapsed -ge $maxNodeWait) {
    Write-ErrorMsg "Some nodes did not reach Ready status within ${maxNodeWait}s"
    Write-Info "Check node conditions: kubectl describe nodes"
    exit 1
}

Write-Output ""
kubectl get nodes -o wide
Write-Output ""

Write-Info "System pods:"
kubectl get pods -n kube-system --no-headers 2>&1 | ForEach-Object {
    Write-Output "  $_"
}

# ---------------------------------------------------------------
# Step 5: Resource usage summary
# ---------------------------------------------------------------
Write-Step "Step 5: Resource usage summary"

# Filter to KIND cluster containers only. On HA (5 nodes) unfiltered
# docker stats buries the useful rows in unrelated Docker containers.
$kindNodes = docker ps --filter "label=io.x-k8s.kind.cluster=$ClusterName" --format "{{.Names}}" 2>$null
if ([string]::IsNullOrWhiteSpace($kindNodes)) {
    Write-Info "No KIND containers found for label io.x-k8s.kind.cluster=$ClusterName - skipping stats"
} else {
    $kindNodeList = $kindNodes -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" @kindNodeList 2>&1
}

Write-Output ""
Write-HostMemory

# Final banner
Write-Output ""
Write-Output "============================================================"
Write-Output "  CKA Lab Ready"
Write-Output "  Cluster: $ClusterName | Nodes: $nodeCount | Context: $currentContext"
Write-Output ""
Write-Output "  Quick reference:"
Write-Output "    kubectl get nodes              - Check node status"
Write-Output "    kubectl get pods -A             - All pods across namespaces"
Write-Output "    kubectl run test --image=nginx  - Quick smoke test"
Write-Output "    .\kind-down.ps1                - Tear it all down"
Write-Output "============================================================"
Write-Output ""

# ---------------------------------------------------------------
# Step 6: Tutorial walkthrough (optional)
# ---------------------------------------------------------------
if ($tutorialSelection -ne "") {
    Write-Step "Step 6: Tutorial"
    switch ($tutorialSelection) {
        "components" { Start-ComponentWalkthrough -ClusterName $ClusterName }
        "m01"        { Start-TutorialM01 -ClusterName $ClusterName }
        "m02"        { Start-TutorialM02 -ClusterName $ClusterName }
        "m03"        { Start-TutorialM03 -ClusterName $ClusterName }
    }
}
