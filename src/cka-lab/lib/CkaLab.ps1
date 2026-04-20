<#
.SYNOPSIS
    Shared functions for CKA lab scripts.
    Dot-sourced by kind-up.ps1, kind-down.ps1, and Start-Tutorial.ps1.
#>

#region Output Helpers

function Write-Step {
    param([string]$Message)
    Write-Output ""
    Write-Output ">>> $Message"
    Write-Output ""
}

function Write-Success {
    param([string]$Message)
    Write-Output "[SUCCESS] $Message"
}

function Write-Info {
    param([string]$Message)
    Write-Output "[INFO] $Message"
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Output "[ERROR] $Message"
}

#endregion

#region Environment Setup

function Initialize-LabPath {
    <#
    .SYNOPSIS
        Adds winget, Docker, and System32 to PATH if missing.
        Spawned PowerShell sessions often inherit a minimal PATH.
    #>
    $pathsToAdd = @(
        (Join-Path -Path $env:LOCALAPPDATA -ChildPath "Microsoft\WinGet\Links"),    # kind.exe
        "C:\Program Files\Docker\Docker\resources\bin",                              # docker.exe, kubectl.exe
        (Join-Path -Path $env:SystemRoot -ChildPath "System32")                      # wsl.exe
    )

    # Normalize existing PATH once: split on ';', trim trailing slashes, lowercase,
    # and drop empty segments. Use a HashSet for O(1) membership checks and to
    # avoid double-prepending when a scoop/winget variant of the same path exists.
    $existing = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($segment in ($env:Path -split ';')) {
        if (-not [string]::IsNullOrWhiteSpace($segment)) {
            [void]$existing.Add($segment.TrimEnd('\').ToLowerInvariant())
        }
    }

    foreach ($p in $pathsToAdd) {
        if (-not (Test-Path -Path $p)) { continue }
        $normalized = $p.TrimEnd('\').ToLowerInvariant()
        if (-not $existing.Contains($normalized)) {
            $env:Path = "$p;$env:Path"
            [void]$existing.Add($normalized)
        }
    }
}

#endregion

#region Docker Desktop Management

function Test-DockerReady {
    <#
    .SYNOPSIS
        Returns $true if the Docker daemon is responding.
    #>
    try {
        $null = docker info 2>$null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Start-DockerDesktop {
    <#
    .SYNOPSIS
        Launches Docker Desktop if not already running.
        Returns $true if it was already running, $false if launched.
    #>
    if (Test-DockerReady) {
        Write-Info "Docker Desktop is already running"
        return $true
    }

    $ddExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path -Path $ddExe) {
        Write-Info "Launching Docker Desktop..."
        Start-Process -FilePath $ddExe -WindowStyle Minimized
    } else {
        Write-Info "Docker Desktop.exe not found at expected path - assuming it will be started manually"
    }

    return $false
}

function Wait-DockerReady {
    <#
    .SYNOPSIS
        Polls Docker daemon until it responds or timeout is reached.
        Returns the elapsed seconds. Exits with error on timeout.
    #>
    param(
        [int]$TimeoutSeconds = 120,
        [int]$PollInterval = 5
    )

    Write-Info "Waiting for Docker daemon to become ready (timeout: ${TimeoutSeconds}s)..."

    $elapsed = 0
    while ($elapsed -lt $TimeoutSeconds) {
        if (Test-DockerReady) {
            Write-Success "Docker daemon is ready (took ~${elapsed}s)"
            return $elapsed
        }
        $remaining = $TimeoutSeconds - $elapsed
        Write-Output "  ... Docker not ready yet (${remaining}s remaining)"
        Start-Sleep -Seconds $PollInterval
        $elapsed += $PollInterval
    }

    Write-ErrorMsg "Docker Desktop failed to start within ${TimeoutSeconds} seconds. Check Docker Desktop for errors."
    throw "Docker Desktop failed to become ready within $TimeoutSeconds seconds"
}

function Stop-DockerDesktop {
    <#
    .SYNOPSIS
        Force-stops Docker Desktop and its backend processes.
    #>
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Info "Sending Docker Desktop quit signal..."
        Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }

    Stop-Process -Name "com.docker.backend" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "com.docker.proxy" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

#endregion

#region Prerequisites

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Checks that docker, kind, and kubectl are on PATH.
        Returns an array of missing tool descriptions (empty = all good).
    #>
    $missing = @()

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        $missing += "docker (Docker Desktop not installed, or docker.exe not on PATH)"
    }
    if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
        $missing += "KIND (install with: winget install Kubernetes.kind)"
    }
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        $missing += "kubectl (usually ships with Docker Desktop)"
    }

    return $missing
}

#endregion

#region KIND Cluster Operations

function Get-KindClusters {
    <#
    .SYNOPSIS
        Returns an array of KIND cluster names currently running.
    #>
    $raw = kind get clusters 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return ($raw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
}

function Test-ClusterExists {
    <#
    .SYNOPSIS
        Returns $true if the named cluster exists.
    #>
    param([string]$ClusterName)
    return ($ClusterName -in (Get-KindClusters))
}

#endregion

#region Host Info

function Get-HostMemoryInfo {
    <#
    .SYNOPSIS
        Returns a hashtable with FreeGB, UsedGB, TotalGB or $null if unavailable.
    #>
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        return @{
            FreeGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
            UsedGB  = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
            TotalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        }
    } catch {
        return $null
    }
}

function Write-HostMemory {
    <#
    .SYNOPSIS
        Writes host memory info line if available.
    #>
    $mem = Get-HostMemoryInfo
    if ($mem) {
        Write-Info "Host memory: $($mem.UsedGB)GB used / $($mem.TotalGB)GB total ($($mem.FreeGB)GB free)"
    }
}

#endregion

# Auto-source tutorial functions
. (Join-Path -Path $PSScriptRoot -ChildPath "tutorials.ps1")
