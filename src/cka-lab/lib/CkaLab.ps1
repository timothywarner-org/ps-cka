<#
.SYNOPSIS
    Shared functions for CKA lab scripts.
    Dot-sourced by kind-up.ps1, kind-down.ps1, and Start-Tutorial.ps1.
#>

#region Output Helpers

# Neon green (#39FF14) via 24-bit ANSI so the color survives colorblind / dark
# VS Code themes that remap the 16-color `Green` to something muted. `[INFO]`
# was previously Yellow, which reads as orange/red on Tim's theme — red is
# reserved for errors, not informational chatter. PS7-only (`#Requires 7.0`
# at the entry points), so `` `e `` is always available.
$Script:NeonGreen = "`e[38;2;57;255;20m"
$Script:AnsiReset = "`e[0m"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "$($Script:NeonGreen)>>> $Message$($Script:AnsiReset)"
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "$($Script:NeonGreen)[OK] $Message$($Script:AnsiReset)"
}

function Write-Info {
    param([string]$Message)
    Write-Host "$($Script:NeonGreen)[INFO] $Message$($Script:AnsiReset)"
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

#endregion

#region Environment Setup

function Initialize-LabEncoding {
    <#
    .SYNOPSIS
        Forces the console and PowerShell pipeline to UTF-8.

    .DESCRIPTION
        KIND, kubectl, and docker emit UTF-8 (bullets, checkmarks, emoji). The
        default Windows console code page is cp437 / cp1252, so those bytes
        render as garbage like "ΓÇó Γ£ô ≡ƒû╝". Setting both the OS code page
        and PowerShell's OutputEncoding fixes it without altering any command.
        Call this FIRST in every entry point, before any external command runs.

        On Linux (including pwsh inside WSL2) the terminal is already UTF-8 and
        chcp.com does not exist, so this function is a no-op there.
    #>
    if (-not $IsWindows) { return }

    try {
        # OS-level console code page (affects what external tools print).
        # 65001 = UTF-8. chcp output is noisy; redirect it.
        $null = & chcp.com 65001 2>&1
    } catch {
        # chcp not available (unlikely on Windows); non-fatal
    }
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
        # $OutputEncoding controls how PowerShell encodes bytes it sends
        # through the pipeline to external commands.
        $global:OutputEncoding = [System.Text.Encoding]::UTF8
    } catch {
        Write-Output "[WARN] Could not set UTF-8 console encoding: $($_.Exception.Message)"
    }
}

function Initialize-LabPath {
    <#
    .SYNOPSIS
        Adds winget, Docker, and System32 to PATH if missing.
        Spawned PowerShell sessions often inherit a minimal PATH.

        On Linux (including pwsh inside WSL2) the PATH is inherited from the
        launching shell (bash/zsh) and already contains kind/kubectl/docker
        via Docker Desktop's WSL integration, so this function is a no-op.
        Also avoids touching $env:LOCALAPPDATA / $env:SystemRoot which are
        unset on Linux and would throw Join-Path null-binding errors.
    #>
    if (-not $IsWindows) { return }

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

        On Linux / WSL2 PowerShell: cannot launch Docker Desktop from here
        (it lives on the Windows host). Report readiness and return without
        attempting to Start-Process a Windows .exe.
    #>
    if (Test-DockerReady) {
        Write-Info "Docker Desktop is already running"
        return $true
    }

    if (-not $IsWindows) {
        Write-Info "Docker daemon not responding from this shell. In WSL2, start Docker Desktop on the Windows host (or use -SkipDdStart once it's running)."
        return $false
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

        On Linux / WSL2 PowerShell: Docker Desktop runs on the Windows host.
        We can't Stop-Process Windows processes from here; log and skip.
    #>
    if (-not $IsWindows) {
        Write-Info "Skipping Docker Desktop stop (runs on Windows host; stop it there manually if needed)."
        return
    }

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
