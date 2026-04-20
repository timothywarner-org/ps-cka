<#
.SYNOPSIS
    Destroys the CKA KIND cluster and optionally stops Docker Desktop.

.DESCRIPTION
    Full lifecycle shutdown script for Tim's CKA certification lab environment.

    By default, destroys the cluster but leaves Docker Desktop running so you
    can immediately re-run kind-up.ps1. Use -StopDockerDesktop to also shut
    down Docker Desktop and release WSL2 memory.

    Performs a clean teardown in order:
    1. Deletes the KIND cluster (removes containers and network)
    2. Optionally prunes unused Docker images to reclaim disk space
    3. Optionally stops Docker Desktop and shuts down WSL2

    Idempotent - safe to run even if the cluster is already gone or DD is already stopped.

.PARAMETER ClusterName
    Name of the KIND cluster to destroy. Default: cka-lab

.PARAMETER Prune
    Remove unused Docker images after cluster deletion to reclaim disk space.

.PARAMETER StopDockerDesktop
    Also stop Docker Desktop and shut down WSL2 after destroying the cluster.

.EXAMPLE
    .\kind-down.ps1
    Destroys cka-lab cluster, leaves Docker Desktop running for quick restart.

.EXAMPLE
    .\kind-down.ps1 -StopDockerDesktop
    Destroys cluster, stops Docker Desktop, shuts down WSL2 to reclaim memory.

.EXAMPLE
    .\kind-down.ps1 -Prune
    Destroys cluster and prunes unused Docker images. DD keeps running.

.EXAMPLE
    .\kind-down.ps1 -Prune -StopDockerDesktop
    Full cleanup: destroy cluster, prune images, stop DD, shut down WSL2.

.NOTES
    Author: Tim Warner
    Version: 2.0
    Requires: Docker Desktop, KIND
    Tested: PowerShell 7.x, Windows 11
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "cka-lab",

    [Parameter(Mandatory = $false)]
    [switch]$Prune,

    [Parameter(Mandatory = $false)]
    [switch]$StopDockerDesktop
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Source shared library
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

# UTF-8 console so kind/kubectl/docker bullets and checkmarks render correctly.
Initialize-LabEncoding

Initialize-LabPath

# Banner
Write-Output ""
Write-Output "============================================================"
Write-Output "  KIND Cluster Shutdown - CKA Lab Environment"
Write-Output "  Cluster: $ClusterName"
Write-Output "============================================================"
Write-Output ""

# ---------------------------------------------------------------
# Shutdown mode menu (skip if -StopDockerDesktop was explicitly passed)
# ---------------------------------------------------------------
$stopDD = [bool]$StopDockerDesktop
if (-not $PSBoundParameters.ContainsKey('StopDockerDesktop')) {
    Write-Output "Select shutdown mode:"
    Write-Output "  [1] Destroy cluster only      (Docker Desktop stays running)"
    Write-Output "  [2] Full shutdown              (stop Docker Desktop + WSL2)"
    Write-Output ""
    $choice = Read-Host "Enter choice [1]"
    switch ($choice) {
        { $_ -eq "" -or $_ -eq "1" } {
            $stopDD = $false
            Write-Output ""
            Write-Output "  >> Cluster-only teardown (Docker Desktop stays running)"
        }
        "2" {
            $stopDD = $true
            Write-Output ""
            Write-Output "  >> Full shutdown selected"
        }
        default {
            Write-ErrorMsg "Invalid choice '$choice'. Please enter 1 or 2."
            exit 1
        }
    }
    Write-Output ""
} else {
    if ($stopDD) {
        Write-Output "  Mode: Destroy cluster + stop Docker Desktop + shut down WSL2"
    } else {
        Write-Output "  Mode: Destroy cluster (Docker Desktop stays running)"
    }
    Write-Output ""
}

# Prune prompt (skip if -Prune was explicitly passed)
$doPrune = [bool]$Prune
if (-not $PSBoundParameters.ContainsKey('Prune')) {
    $pruneChoice = Read-Host "Prune unused Docker images to reclaim disk space? [y/N]"
    switch ($pruneChoice) {
        { $_ -eq "y" -or $_ -eq "Y" } {
            $doPrune = $true
            Write-Output "  >> Will prune after cluster deletion"
        }
        default {
            $doPrune = $false
        }
    }
    Write-Output ""
}

# ---------------------------------------------------------------
# Step 1: Delete the KIND cluster
# ---------------------------------------------------------------
Write-Step "Step 1: Deleting KIND cluster"

$dockerRunning = Test-DockerReady

if (-not $dockerRunning) {
    Write-Info "Docker is not running - cluster containers are already gone"
} else {
    if (Test-ClusterExists -ClusterName $ClusterName) {
        Write-Info "Deleting cluster '$ClusterName'..."
        kind delete cluster --name $ClusterName

        if ($LASTEXITCODE -eq 0) {
            Write-Success "Cluster '$ClusterName' deleted"
        } else {
            Write-ErrorMsg "KIND delete returned exit code $LASTEXITCODE"
            Write-Info "Attempting to force-remove Docker containers..."
            $containers = docker ps -aq --filter "label=io.x-k8s.kind.cluster=$ClusterName" 2>$null
            if ($containers) {
                docker rm -f $containers 2>$null | Out-Null
                Write-Info "Force-removed cluster containers"
            }
        }
    } else {
        Write-Info "Cluster '$ClusterName' does not exist - nothing to delete"
    }
}

# ---------------------------------------------------------------
# Step 2: Prune Docker resources (optional)
# ---------------------------------------------------------------
if ($doPrune) {
    Write-Step "Step 2: Pruning unused Docker resources"

    if ($dockerRunning) {
        Write-Info "Removing unused images, networks, and build cache..."
        docker system prune -af --volumes 2>&1 | ForEach-Object {
            if ($_ -match "(?i)Total reclaimed space") {
                Write-Output $_
            }
        }
    } else {
        Write-Info "Docker is not running - skipping prune"
    }
} else {
    Write-Step "Step 2: Skipping Docker prune"
}

# ---------------------------------------------------------------
# Step 3: Stop Docker Desktop (only if selected)
# ---------------------------------------------------------------
if ($stopDD) {
    Write-Step "Step 3: Stopping Docker Desktop"

    Stop-DockerDesktop
    Write-Success "Docker Desktop stopped"
} else {
    Write-Step "Step 3: Skipping Docker Desktop shutdown"
    Write-Info "Docker Desktop remains running — ready for kind-up.ps1"
}

# ---------------------------------------------------------------
# Step 4: WSL2 shutdown (deferred to end)
# ---------------------------------------------------------------
$WslShutdownPending = $false
if ($stopDD) {
    Write-Step "Step 4: Shutting down WSL2"
    Write-Info "Sending WSL shutdown signal..."
    Write-Info "WSL shutdown will terminate any active WSL sessions."
    Write-Info "Run manually if needed: wsl --shutdown"
    $WslShutdownPending = $true
} else {
    Write-Step "Step 4: Skipping WSL2 shutdown (Docker Desktop left running)"
}

# ---------------------------------------------------------------
# Step 5: Final verification
# ---------------------------------------------------------------
Write-Step "Step 5: Verification"

$dockerStillUp = Test-DockerReady

if ($stopDD) {
    if ($dockerStillUp) {
        Write-Info "Docker daemon is still responding (may take a moment to stop)"
    } else {
        Write-Success "Docker daemon is not responding (stopped)"
    }
} else {
    if ($dockerStillUp) {
        Write-Success "Docker Desktop is running — ready for kind-up.ps1"
    } else {
        Write-Info "Docker daemon is not responding (may need to start Docker Desktop)"
    }
}

Write-Output ""
Write-HostMemory

# Final banner
Write-Output ""
Write-Output "============================================================"
if ($stopDD) {
    Write-Output "  CKA Lab Shut Down"
    Write-Output "  Cluster '$ClusterName' deleted | Docker Desktop stopped"
    Write-Output ""
    Write-Output "  To restart:   .\kind-up.ps1"
} else {
    Write-Output "  CKA Lab Torn Down"
    Write-Output "  Cluster '$ClusterName' deleted | Docker Desktop running"
    Write-Output ""
    Write-Output "  To recreate:  .\kind-up.ps1"
}
Write-Output "============================================================"
Write-Output ""

# Execute WSL shutdown as the very last action (if pending)
if ($WslShutdownPending) {
    Write-Info "Executing WSL shutdown in 3 seconds..."
    Start-Sleep -Seconds 3

    # Prefer whatever wsl the current PATH resolves to. On ARM64 Windows,
    # %SystemRoot%\System32 gets Sysnative-redirected when a 32-bit host runs,
    # so hardcoding that path can point at the wrong wsl.exe (or nothing).
    # Fallback order: Get-Command -> 'wsl.exe' on PATH -> skip with a friendly note.
    $wslExe = Get-Command wsl -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    if (-not $wslExe) {
        $wslExe = Get-Command wsl.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    }

    if ($wslExe -and (Test-Path -Path $wslExe)) {
        & $wslExe --shutdown 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL shutdown complete"
        } else {
            Write-ErrorMsg "WSL shutdown failed (exit code $LASTEXITCODE)"
        }
    } else {
        Write-Info "wsl.exe not found on PATH - skipping WSL shutdown (run 'wsl --shutdown' manually if needed)"
    }
}
