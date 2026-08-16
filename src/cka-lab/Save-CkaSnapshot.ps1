<#
.SYNOPSIS
    Create one atomic Hyper-V checkpoint across the whole CKA lab
    (control1, worker1, worker2) so the entire cluster rewinds together.

.DESCRIPTION
    This is your "save point" before a demo take. It checkpoints all three lab VMs
    to a single named checkpoint in one shot, so when you restore, every node rewinds
    to the exact same instant -- no skew between control plane and workers. Afterward,
    .\Restore-CkaSnapshot.ps1 <Name> rewinds the whole cluster in ~60-90 seconds.

    SAFETY -- atomic, all-or-nothing:
    The script verifies every VM exists BEFORE it checkpoints any of them. If even one
    VM is missing, it aborts without touching anything -- you never end up with a
    half-snapshotted cluster.

    ACCESSIBILITY:
    Status output flows through the shared helpers in lib\CkaLab.ps1, which label every
    line ([OK] / [INFO] / [ERROR]) on the Wong colorblind-safe palette. Meaning never
    rides on color alone.

    RECORDING WORKFLOW:
      1. Bring the lab up:        .\Start-CkaLab.ps1
      2. Save a checkpoint here:  .\Save-CkaSnapshot.ps1 m02-pre-upgrade
      3. Record the demo.
      4. Rewind to re-record:     .\Restore-CkaSnapshot.ps1 m02-pre-upgrade

.PARAMETER SnapshotName
    Name for the checkpoint. Use a take-specific name (for example "m02-pre-upgrade"
    or "post-install"). Defaults to "pre-cluster" -- the clean baseline after host
    prereqs but BEFORE 'kubeadm init'.

.EXAMPLE
    .\Save-CkaSnapshot.ps1
    Creates a checkpoint named "pre-cluster" on all three VMs.

.EXAMPLE
    .\Save-CkaSnapshot.ps1 m02-pre-upgrade
    Creates "m02-pre-upgrade" -- your re-record point for the Module 2 upgrade demo.

.EXAMPLE
    .\Save-CkaSnapshot.ps1 -SnapshotName test -WhatIf
    Dry run: lists what WOULD be checkpointed and creates nothing.

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Restore-CkaSnapshot.ps1 (rewind), Get-CkaLabStatus.ps1 (inspect),
                README.md (copy-paste cheat sheet)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName = 'pre-cluster'
)

$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# One definition of the node list lives in lib\CkaLab.ps1 (Get-CkaLabVMs),
# so every wrapper agrees on control1 / worker1 / worker2.
$VMs = Get-CkaLabVMs

Write-Step "Creating Hyper-V checkpoint '$SnapshotName' across $($VMs.Count) VMs"

# --- Pre-flight: confirm EVERY VM exists before checkpointing ANY of them ------
# Atomic guard -- we would rather do nothing than half-snapshot the cluster.
Write-Info 'Pre-flight: verifying all lab VMs exist...'
$missing = @()
foreach ($vm in $VMs) {
    if (Get-VM -Name $vm -ErrorAction SilentlyContinue) {
        Write-Success "  $vm found"
    }
    else {
        Write-ErrorMsg "  $vm NOT found"
        $missing += $vm
    }
}

if ($missing.Count -gt 0) {
    Write-ErrorMsg "Aborted -- missing VM(s): $($missing -join ', '). Nothing was checkpointed."
    Write-Info 'Bring the lab up first with:  .\Start-CkaLab.ps1'
    exit 1
}

# --- All VMs present -- checkpoint each one -----------------------------------
$failed = @()
foreach ($vm in $VMs) {
    # -WhatIf flows through ShouldProcess: it prints the intent and creates nothing.
    if ($PSCmdlet.ShouldProcess($vm, "Create checkpoint '$SnapshotName'")) {
        Write-Info "Checkpointing $vm..."
        try {
            Checkpoint-VM -Name $vm -SnapshotName $SnapshotName -Confirm:$false -ErrorAction Stop
            Write-Success "  $vm checkpointed"
        }
        catch {
            Write-ErrorMsg "  $vm FAILED: $($_.Exception.Message)"
            $failed += $vm
        }
    }
}

# --- Summary ------------------------------------------------------------------
if ($failed.Count -gt 0) {
    Write-ErrorMsg "One or more checkpoints FAILED: $($failed -join ', ')"
    exit 1
}

Write-Step "Done. Rewind the whole lab any time with:  .\Restore-CkaSnapshot.ps1 $SnapshotName"
