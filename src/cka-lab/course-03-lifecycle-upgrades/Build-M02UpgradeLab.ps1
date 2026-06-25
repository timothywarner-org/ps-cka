<#
.SYNOPSIS
    Build the Module 2 upgrade lab: a clean 3-node cluster ONE MINOR BEHIND
    (v1.34) so you can record the kubeadm upgrade to v1.35 live on camera,
    then auto-snapshot it as your re-record point.

.DESCRIPTION
    The Course 3 lab defaults to v1.35 (that is what Module 1 and Module 3 need).
    Module 2 is different: the whole demo IS the upgrade, so it has to START at
    v1.34. You cannot downgrade a running cluster in place, so this script does
    the one thing that actually lands a v1.34 cluster:

        1. Sets CKA_K8S_MINOR / CKA_K8S_PKG_VERSION so the SAME Vagrantfile
           provisions v1.34 instead of the v1.35 default.
        2. Destroys the existing VMs and re-provisions them clean at v1.34.
        3. Saves a 'm02-pre-upgrade' checkpoint across all three VMs, so your
           first re-record is a single Restore-CkaSnapshot call away.

    This is a thin wrapper over the existing controls, not a second lab. There
    is ONE Vagrantfile and ONE set of VMs; this script just boots them at a
    different version and names the snapshot for you, so you never have to
    remember the environment-variable dance before a take.

    DESTRUCTIVE: this destroys your current lab VMs. If you are sitting on a
    v1.35 snapshot you care about (for example 'm01-cluster-ready'), that
    Hyper-V checkpoint survives the destroy on disk only if it was taken on
    VMs that still exist; a full 'vagrant destroy' removes the VMs and their
    checkpoints. Save anything you need on a DIFFERENT host path first. The
    script confirms before it destroys anything, and -WhatIf changes nothing.

.PARAMETER PackageVersion
    The exact v1.34 apt package string the Vagrantfile installs (kubeadm/kubelet/
    kubectl). Defaults to '1.34.6-1.1'. Patch releases come and go, so confirm
    the exact one available before a real take, from inside a VM:
        ssh vagrant@192.168.50.10 "apt-cache madison kubeadm | head"
    then pass it here, for example: -PackageVersion 1.34.7-1.1

.PARAMETER SnapshotName
    Name for the re-record checkpoint created at the end. Defaults to
    'm02-pre-upgrade' to match the Module 2 runbook and README.

.PARAMETER SkipSnapshot
    Provision the v1.34 cluster but do NOT take the checkpoint (you will snapshot
    by hand later). Off by default -- the auto-snapshot is the whole point.

.PARAMETER ExportBaseline
    Export a v1.35 baseline checkpoint to disk BEFORE the destroy. The destroy
    removes the VMs and every checkpoint on them, so the v1.35 state that M01
    (re-record) and M03 (starting point) both rely on would otherwise be lost.
    With this switch, the baseline survives as a portable Export-VM copy you can
    Import-VM later. Strongly recommended whenever you still need v1.35.

.PARAMETER BaselineSnapshot
    Which checkpoint -ExportBaseline saves. Defaults to 'm01-cluster-ready' (the
    known-good v1.35 cluster the Module 1 workflow tells you to save). Must exist
    on all three VMs or the script aborts before any destroy.

.PARAMETER ExportPath
    Folder the baseline export lands in. Defaults to 'baseline-exports' beside the
    lab (src\cka-lab\baseline-exports). A dated subfolder is created per run.

.EXAMPLE
    .\Build-M02UpgradeLab.ps1
    Destroys the current VMs, re-provisions a clean v1.34 cluster (1.34.6-1.1),
    and checkpoints all three VMs as 'm02-pre-upgrade'.

.EXAMPLE
    .\Build-M02UpgradeLab.ps1 -PackageVersion 1.34.7-1.1
    Same, but pin the exact 1.34 patch you confirmed with apt-cache madison.

.EXAMPLE
    .\Build-M02UpgradeLab.ps1 -ExportBaseline
    Saves the 'm01-cluster-ready' v1.35 baseline to disk FIRST, then destroys, rebuilds at
    v1.34, and snapshots 'm02-pre-upgrade'. Use this whenever you still need v1.35
    for M01 re-records or M03.

.EXAMPLE
    .\Build-M02UpgradeLab.ps1 -ExportBaseline -WhatIf
    Dry run: shows the baseline export, the destroy, the provision, and the
    snapshot it WOULD do, and changes nothing.

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from
            C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Restore-CkaSnapshot.ps1 m02-pre-upgrade (rewind to re-record),
                Save-CkaSnapshot.ps1 (manual checkpoints),
                Start-CkaLab.ps1 (normal v1.35 boot), README.md (cheat sheet)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$PackageVersion = '1.34.6-1.1',

    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName = 'm02-pre-upgrade',

    [switch]$SkipSnapshot,

    # Export a v1.35 baseline checkpoint to disk BEFORE the destroy, so the
    # rebuild can never cost you the one v1.35 state that M01 (re-record) and M03
    # (starting point) both depend on. 'vagrant destroy' removes the VMs and ALL
    # their checkpoints, so without this the baseline is gone for good.
    [switch]$ExportBaseline,

    # Which checkpoint to export when -ExportBaseline is set. Defaults to
    # 'm01-cluster-ready' -- the v1.35 baseline the Module 1 workflow saves. Not
    # hard-coded so a renamed baseline still works.
    [ValidateNotNullOrEmpty()]
    [string]$BaselineSnapshot = 'm01-cluster-ready',

    # Where the exported baseline lands. Defaults to a dated folder beside the lab.
    [ValidateNotNullOrEmpty()]
    [string]$ExportPath = (Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'baseline-exports')
)

$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# Derive the minor (1.34) from the package string (1.34.6-1.1) so the two can
# never disagree -- the Vagrantfile reads BOTH env vars and a mismatch would
# build a repo for one minor while pinning a package from another.
if ($PackageVersion -notmatch '^(\d+\.\d+)\.\d+-\d+\.\d+$') {
    Write-ErrorMsg "PackageVersion '$PackageVersion' is not a valid apt version (expected like 1.34.6-1.1)."
    exit 1
}
$minor = $Matches[1]

Write-Step "Building the Module 2 upgrade lab at v$minor (package $PackageVersion)"
Write-Info  "Target snapshot after provisioning: '$SnapshotName'"
Write-Warn  "This DESTROYS the current lab VMs and rebuilds them clean at v$minor."

# The Course 3 controls live one level down from the lab. Point Vagrant at the
# parent (src\cka-lab) so it drives the SAME VMs and reads the SAME Vagrantfile.
$env:VAGRANT_CWD = Split-Path -Parent $PSScriptRoot

# These two are what flip the Vagrantfile off its v1.35 default. They must be set
# in THIS process before 'vagrant up' runs; the Vagrantfile does ENV.fetch on them.
$env:CKA_K8S_MINOR       = $minor
$env:CKA_K8S_PKG_VERSION = $PackageVersion
Write-Info "Set CKA_K8S_MINOR=$minor and CKA_K8S_PKG_VERSION=$PackageVersion for this build."

# --- Step 0: export the v1.35 baseline before we destroy anything -------------
# 'vagrant destroy' removes the VMs and every checkpoint on them, including the
# v1.35 baseline M01 re-records and M03 both rely on. -ExportBaseline saves a
# portable copy first. To capture v1.35 (not the VMs' current state), we APPLY
# the baseline checkpoint, then Export-VM the resulting state to disk.
if ($ExportBaseline) {
    $VMs = Get-CkaLabVMs
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest  = Join-Path -Path $ExportPath -ChildPath "$BaselineSnapshot-$stamp"

    Write-Step "Exporting baseline checkpoint '$BaselineSnapshot' to: $dest"

    # Pre-flight: the named checkpoint must exist on every VM, or the export is
    # not a coherent cluster restore point. Verify all three BEFORE touching any.
    $missing = @()
    foreach ($vm in $VMs) {
        if (-not (Get-VMCheckpoint -VMName $vm -Name $BaselineSnapshot -ErrorAction SilentlyContinue)) {
            $missing += $vm
        }
    }
    if ($missing.Count -gt 0) {
        Write-ErrorMsg "Checkpoint '$BaselineSnapshot' is missing on: $($missing -join ', '). Aborting -- nothing destroyed."
        Write-Info "List what exists:  Get-VMCheckpoint -VMName control1 | Select-Object Name, CreationTime"
        exit 1
    }

    foreach ($vm in $VMs) {
        if ($PSCmdlet.ShouldProcess($vm, "Restore checkpoint '$BaselineSnapshot' then Export-VM to $dest")) {
            try {
                # Apply the checkpoint so the VM's live state IS the v1.35 baseline,
                # then export that state. Export-VM captures the running config + disks.
                Restore-VMCheckpoint -VMName $vm -Name $BaselineSnapshot -Confirm:$false -ErrorAction Stop
                Export-VM -Name $vm -Path $dest -ErrorAction Stop
                Write-Success "  $vm exported"
            }
            catch {
                Write-ErrorMsg "  $vm export FAILED: $($_.Exception.Message). Aborting before destroy."
                exit 1
            }
        }
    }
    Write-Success "Baseline '$BaselineSnapshot' exported. Re-import later with: Import-VM -Path <vmcx under $dest>"
}
else {
    Write-Warn "No -ExportBaseline: the destroy below removes ALL checkpoints (including any v1.35 baseline)."
}

# --- Step 1: destroy the current VMs (the only honest way to reach v1.34) -----
if ($PSCmdlet.ShouldProcess('control1, worker1, worker2', "vagrant destroy -f (rebuild at v$minor)")) {
    Write-Step 'Destroying current lab VMs'
    vagrant destroy -f
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "vagrant destroy failed (exit $LASTEXITCODE). Nothing was rebuilt."
        exit 1
    }
    Write-Success 'Old VMs removed'
}

# --- Step 2: provision a clean v1.34 cluster ----------------------------------
if ($PSCmdlet.ShouldProcess('control1, worker1, worker2', "vagrant up (provision at v$minor)")) {
    Write-Step "Provisioning a clean v$minor cluster (this runs the full prereq + kubeadm init)"
    vagrant up
    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg "vagrant up failed (exit $LASTEXITCODE). Fix the error above, then re-run this script."
        exit 1
    }
    Write-Success "Cluster provisioned at v$minor"
}

# --- Step 3: auto-snapshot the re-record point --------------------------------
if ($SkipSnapshot) {
    Write-Info "Skipping snapshot (-SkipSnapshot). Take it later with:  .\Save-CkaSnapshot.ps1 $SnapshotName"
}
else {
    # Hand off to the existing, atomic snapshot wrapper rather than re-implement
    # Checkpoint-VM here -- one definition of "snapshot all three VMs" stays in
    # Save-CkaSnapshot.ps1. -WhatIf and -Confirm flow through to it.
    Write-Step "Checkpointing the clean v$minor cluster as '$SnapshotName'"
    $saver = Join-Path -Path $PSScriptRoot -ChildPath 'Save-CkaSnapshot.ps1'
    & $saver -SnapshotName $SnapshotName
}

Write-Step "Module 2 upgrade lab is ready at v$minor"
Write-Info  "SSH in:        ssh vagrant@192.168.50.10   (password: vagrant)"
Write-Info  "Confirm:       kubectl get nodes   (all three Ready, v$minor)"
Write-Info  "Re-record any time:  .\Restore-CkaSnapshot.ps1 $SnapshotName"
Write-Info  "After the upgrade take the cluster sits at v1.35 -- exactly Module 3's start state."
