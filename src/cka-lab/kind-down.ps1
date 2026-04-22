<#
.SYNOPSIS
    Destroys the CKA KIND cluster and optionally stops Docker Desktop.

.DESCRIPTION
    Full lifecycle shutdown script for Tim's CKA certification lab environment.

    By default, destroys the cluster but leaves Docker Desktop running so you
    can immediately re-run kind-up.ps1. Use -StopDockerDesktop to also stop
    Docker Desktop and terminate its WSL2 distros (other WSL distros untouched).

    Performs a clean teardown in order:
    1. Deletes the KIND cluster (removes containers and network)
    2. Optionally prunes Docker resources (opt-in only, never prompted)
    3. Optionally stops Docker Desktop and terminates docker-desktop WSL distros

    Idempotent - safe to run even if the cluster is already gone or DD is already stopped.

.PARAMETER ClusterName
    Name of the KIND cluster to destroy. Default: cka-lab

.PARAMETER Prune
    Remove **dangling** images only (docker system prune -f). Safe for multi-project
    Docker setups -- does not touch images tagged by other projects or volumes.

.PARAMETER DeepPrune
    Remove ALL unused images, networks, build cache, AND unused volumes
    (docker system prune -af --volumes). Nuclear option -- will pull the base
    images of any OTHER KIND clusters or side projects out from under them.

.PARAMETER StopDockerDesktop
    Stop Docker Desktop and terminate its internal docker-desktop and
    docker-desktop-data WSL2 distros. Leaves any Ubuntu/Debian/other WSL
    distros you have open completely untouched.

.EXAMPLE
    .\kind-down.ps1
    Destroys cka-lab cluster, leaves Docker Desktop running for quick restart.

.EXAMPLE
    .\kind-down.ps1 -StopDockerDesktop
    Destroys cluster, stops Docker Desktop, terminates docker-desktop WSL distros.

.EXAMPLE
    .\kind-down.ps1 -Prune
    Destroys cluster and removes dangling images only. Other projects unaffected.

.EXAMPLE
    .\kind-down.ps1 -DeepPrune -StopDockerDesktop
    Full cleanup: destroy cluster, deep-prune (all unused + volumes), stop DD.

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
    [switch]$DeepPrune,

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
    Write-Output "  [1] Destroy cluster only  (Docker Desktop stays running)"
    Write-Output "  [2] Stop Docker Desktop   (also terminates docker-desktop WSL distros;"
    Write-Output "                             other WSL distros are left running)"
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
            Write-Output "  >> Stop Docker Desktop selected"
        }
        default {
            Write-ErrorMsg "Invalid choice '$choice'. Please enter 1 or 2."
            exit 1
        }
    }
    Write-Output ""
} else {
    if ($stopDD) {
        Write-Output "  Mode: Destroy cluster + stop Docker Desktop (docker-desktop WSL distros only)"
    } else {
        Write-Output "  Mode: Destroy cluster (Docker Desktop stays running)"
    }
    Write-Output ""
}

# Prune is OPT-IN ONLY via -Prune or -DeepPrune flags. No interactive prompt --
# 99% of the time the learner just wants the cluster gone and the base images
# cached for the next kind-up.ps1. Prune only when the user explicitly asks.
$doPrune = [bool]$Prune -or [bool]$DeepPrune
if ($Prune -and $DeepPrune) {
    Write-Info "-DeepPrune takes precedence over -Prune"
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
    if ($DeepPrune) {
        Write-Step "Step 2: Deep-pruning Docker (ALL unused images + volumes)"
    } else {
        Write-Step "Step 2: Pruning dangling Docker resources"
    }

    if ($dockerRunning) {
        if ($DeepPrune) {
            Write-Info "Removing ALL unused images, networks, build cache, AND volumes..."
            Write-Info "This will affect other KIND clusters and side projects."
            docker system prune -af --volumes 2>&1 | ForEach-Object {
                if ($_ -match "(?i)Total reclaimed space") {
                    Write-Output $_
                }
            }
        } else {
            Write-Info "Removing dangling images and unused networks only (other projects safe)..."
            docker system prune -f 2>&1 | ForEach-Object {
                if ($_ -match "(?i)Total reclaimed space") {
                    Write-Output $_
                }
            }
        }
    } else {
        Write-Info "Docker is not running - skipping prune"
    }
} else {
    Write-Step "Step 2: Skipping Docker prune (pass -Prune or -DeepPrune to opt in)"
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
# Step 4: Terminate Docker Desktop's WSL distros (deferred to end)
# ---------------------------------------------------------------
# Targeted terminate instead of `wsl --shutdown`. `wsl --shutdown` kills EVERY
# WSL distro on the machine -- including an Ubuntu/Debian terminal the user is
# actively working in. `wsl --terminate docker-desktop[-data]` only releases
# the two distros Docker Desktop owns, leaving the rest of the user's WSL
# environment intact.
$WslShutdownPending = $false
if ($stopDD) {
    Write-Step "Step 4: Terminating docker-desktop WSL distros"
    Write-Info "Will terminate ONLY: docker-desktop, docker-desktop-data"
    Write-Info "Your other WSL distros (Ubuntu, Debian, etc.) stay running."
    $WslShutdownPending = $true
} else {
    Write-Step "Step 4: Skipping WSL terminate (Docker Desktop left running)"
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
    Write-Output "  (other WSL distros untouched)"
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

# Execute targeted WSL terminate as the very last action (if pending).
# Only terminates docker-desktop + docker-desktop-data -- never `wsl --shutdown`,
# which would kill any Ubuntu/Debian WSL session the user is working in.
if ($WslShutdownPending) {
    if (-not $IsWindows) {
        # Inside WSL ourselves. `wsl.exe --terminate docker-desktop` from inside
        # a non-docker-desktop distro is safe, but we skip by default to keep
        # this path predictable. User can run it manually from Windows.
        Write-Info "Skipping WSL terminate (running inside WSL)."
        Write-Info "From a Windows terminal: wsl --terminate docker-desktop; wsl --terminate docker-desktop-data"
    } else {
        Write-Info "Terminating docker-desktop WSL distros in 3 seconds..."
        Start-Sleep -Seconds 3

        # Prefer whatever wsl the current PATH resolves to. On ARM64 Windows,
        # %SystemRoot%\System32 gets Sysnative-redirected when a 32-bit host runs,
        # so hardcoding that path can point at the wrong wsl.exe (or nothing).
        $wslExe = Get-Command wsl -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
        if (-not $wslExe) {
            $wslExe = Get-Command wsl.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
        }

        if ($wslExe -and (Test-Path -Path $wslExe)) {
            $ddDistros = @('docker-desktop', 'docker-desktop-data')
            $anyTerminated = $false
            foreach ($distro in $ddDistros) {
                & $wslExe --terminate $distro 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Terminated WSL distro: $distro"
                    $anyTerminated = $true
                }
                # Non-zero exit is normal if the distro isn't running / doesn't
                # exist (DD not installed via WSL2 backend). Stay quiet.
            }
            if (-not $anyTerminated) {
                Write-Info "No docker-desktop WSL distros were running (nothing to terminate)"
            }
        } else {
            Write-Info "wsl.exe not found on PATH - skipping. Run manually: wsl --terminate docker-desktop"
        }
    }
}
