<#
.SYNOPSIS
    Rewind the whole CKA lab (control1, worker1, worker2) to a named Hyper-V checkpoint.

.DESCRIPTION
    Restores all three lab VMs to the SAME named checkpoint and then starts them, so the
    entire cluster rewinds together to a known-good state in ~60-90 seconds. This is the
    "re-record" button: pair it with Save-CkaSnapshot.ps1, which creates the checkpoint.

    SAFETY -- atomic, all-or-nothing:
    Every VM must exist AND have the named checkpoint before ANY restore runs. If even one
    is missing, the script aborts without touching anything -- you never end up with one
    node rewound and the others left at the current state. VMs are only started after all
    three restores succeed.

    ACCESSIBILITY:
    Output flows through the colorblind-safe helpers in lib\CkaLab.ps1 ([OK]/[INFO]/[WARN]/
    [ERROR] labels on the Wong palette).

.PARAMETER SnapshotName
    Name of the checkpoint to restore. Defaults to "pre-cluster".

.EXAMPLE
    .\Restore-CkaSnapshot.ps1 m02-pre-upgrade
    Rewinds the whole lab to "m02-pre-upgrade" and starts the VMs.

.EXAMPLE
    .\Restore-CkaSnapshot.ps1 -SnapshotName test -WhatIf
    Dry run: shows what WOULD be restored, changes nothing.

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Save-CkaSnapshot.ps1 (create), Get-CkaLabStatus.ps1 (inspect)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName = 'pre-cluster'
)

$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

$VMs = Get-CkaLabVMs

Write-Step "Restoring all CKA VMs to checkpoint '$SnapshotName'"

# --- Pre-flight: every VM must exist AND have the named checkpoint ------------
Write-Info 'Pre-flight: verifying every VM has the checkpoint...'
$missing = @()
foreach ($vm in $VMs) {
    if (-not (Get-VM -Name $vm -ErrorAction SilentlyContinue)) {
        Write-ErrorMsg "  $vm -- VM not found"
        $missing += "$vm (VM not found)"
        continue
    }
    if (Get-VMCheckpoint -VMName $vm -Name $SnapshotName -ErrorAction SilentlyContinue) {
        Write-Success "  $vm has '$SnapshotName'"
    }
    else {
        Write-ErrorMsg "  $vm -- no checkpoint '$SnapshotName'"
        $missing += "$vm (no checkpoint '$SnapshotName')"
    }
}

if ($missing.Count -gt 0) {
    Write-ErrorMsg 'Aborted -- nothing was restored:'
    foreach ($m in $missing) { Write-ErrorMsg "    - $m" }
    Write-Info "Create checkpoints first with:  .\Save-CkaSnapshot.ps1 $SnapshotName"
    exit 1
}

# --- All checks passed -- restore each VM ------------------------------------
$failed = @()
foreach ($vm in $VMs) {
    if ($PSCmdlet.ShouldProcess($vm, "Restore checkpoint '$SnapshotName'")) {
        Write-Info "Restoring $vm..."
        try {
            Restore-VMCheckpoint -VMName $vm -Name $SnapshotName -Confirm:$false -ErrorAction Stop
            Write-Success "  $vm restored"
        }
        catch {
            Write-ErrorMsg "  $vm FAILED: $($_.Exception.Message)"
            $failed += $vm
        }
    }
}

if ($failed.Count -gt 0) {
    Write-ErrorMsg "Restore FAILED on: $($failed -join ', '). NOT starting any VMs."
    exit 1
}

# --- Only after all restores succeeded -- start the VMs ----------------------
foreach ($vm in $VMs) {
    if ($PSCmdlet.ShouldProcess($vm, 'Start VM')) {
        try {
            Start-VM -Name $vm -ErrorAction Stop
            $state = (Get-VM -Name $vm -ErrorAction SilentlyContinue).State
            Write-Success "  $vm started (state: $state)"
        }
        catch {
            Write-ErrorMsg "  $vm failed to start: $($_.Exception.Message)"
            $failed += $vm
        }
    }
}

if ($failed.Count -gt 0) {
    Write-ErrorMsg "One or more VMs failed to start: $($failed -join ', ')"
    exit 1
}

Write-Step 'Lab restored and running. SSH in with:  vagrant ssh control1'
