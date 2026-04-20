# cka-snapshot.ps1 — Direct Hyper-V checkpoint for all CKA VMs
# Run from admin PowerShell
#
# Atomicity: All three VMs must exist before ANY checkpoint runs.
# If any VM is missing, the script aborts before touching anything —
# prevents partial-snapshot state where some VMs have the checkpoint
# and others don't.

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$SnapshotName = if ($args[0]) { $args[0] } else { "pre-cluster" }
$VMs = @("control1", "worker1", "worker2")

Write-Host "`n=== Creating Hyper-V checkpoint '$SnapshotName' ===" -ForegroundColor Cyan

# --- Pre-flight: confirm every VM exists before checkpointing any ---
Write-Host "`n[pre-flight] Verifying all VMs exist..." -ForegroundColor Gray
$missing = @()
foreach ($vm in $VMs) {
    try {
        Get-VM -Name $vm -ErrorAction Stop | Out-Null
        Write-Host "  [OK]     $vm found" -ForegroundColor Gray
    } catch {
        Write-Host "  [MISSING] $vm not found" -ForegroundColor Red
        $missing += $vm
    }
}

if ($missing.Count -gt 0) {
    Write-Host "`n=== ABORTED: missing VM(s): $($missing -join ', ') ===" -ForegroundColor Red
    Write-Host "No checkpoints were created. Run 'vagrant up' first." -ForegroundColor Red
    exit 1
}

# --- All VMs present — now checkpoint each one ---
$results = @{}
$anyFailed = $false
foreach ($vm in $VMs) {
    Write-Host "  Checkpointing $vm..." -ForegroundColor Yellow
    try {
        Checkpoint-VM -Name $vm -SnapshotName $SnapshotName -Confirm:$false -ErrorAction Stop
        $results[$vm] = 'OK'
    } catch {
        $results[$vm] = "FAILED: $($_.Exception.Message)"
        $anyFailed = $true
    }
}

# --- Summary ---
Write-Host "`n=== Checkpoint Summary ===" -ForegroundColor Cyan
foreach ($vm in $VMs) {
    $status = $results[$vm]
    $color = if ($status -eq 'OK') { 'Green' } else { 'Red' }
    Write-Host ("  {0,-10} {1}" -f $vm, $status) -ForegroundColor $color
}

if ($anyFailed) {
    Write-Host "`n=== One or more checkpoints FAILED ===" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Done. Restore with:  .\cka-restore.ps1 $SnapshotName ===" -ForegroundColor Green
