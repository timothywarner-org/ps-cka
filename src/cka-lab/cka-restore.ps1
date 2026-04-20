# cka-restore.ps1 — Restore all CKA VMs to a Hyper-V checkpoint
# Run from admin PowerShell
#
# Atomicity: All three VMs must have the named checkpoint before ANY
# restore runs. If any VM is missing the checkpoint, the script aborts
# before touching anything — prevents the inconsistent state where one
# VM is at baseline and the others are at current.

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$SnapshotName = if ($args[0]) { $args[0] } else { "pre-cluster" }
$VMs = @("control1", "worker1", "worker2")

Write-Host "`n=== Restoring all CKA VMs to '$SnapshotName' ===" -ForegroundColor Cyan

# --- Pre-flight: every VM must exist AND have the named checkpoint ---
Write-Host "`n[pre-flight] Verifying all VMs and checkpoints exist..." -ForegroundColor Gray
$missing = @()
foreach ($vm in $VMs) {
    try {
        Get-VM -Name $vm -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "  [MISSING VM]        $vm" -ForegroundColor Red
        $missing += "$vm (VM not found)"
        continue
    }

    $cp = Get-VMCheckpoint -VMName $vm -Name $SnapshotName -ErrorAction SilentlyContinue
    if ($null -eq $cp) {
        Write-Host "  [MISSING CHECKPOINT] $vm has no '$SnapshotName'" -ForegroundColor Red
        $missing += "$vm (no checkpoint '$SnapshotName')"
    } else {
        Write-Host "  [OK]                $vm has '$SnapshotName'" -ForegroundColor Gray
    }
}

if ($missing.Count -gt 0) {
    Write-Host "`n=== ABORTED: nothing was restored ===" -ForegroundColor Red
    Write-Host "Missing:" -ForegroundColor Red
    foreach ($m in $missing) { Write-Host "  - $m" -ForegroundColor Red }
    Write-Host "Create checkpoints with:  .\cka-snapshot.ps1 $SnapshotName" -ForegroundColor Red
    exit 1
}

# --- All pre-flights passed — restore sequentially ---
$restoreResults = @{}
$anyRestoreFailed = $false
foreach ($vm in $VMs) {
    Write-Host "  Restoring $vm..." -ForegroundColor Yellow
    try {
        Restore-VMCheckpoint -VMName $vm -Name $SnapshotName -Confirm:$false -ErrorAction Stop
        $restoreResults[$vm] = 'restored'
    } catch {
        $restoreResults[$vm] = "FAILED: $($_.Exception.Message)"
        $anyRestoreFailed = $true
    }
}

if ($anyRestoreFailed) {
    Write-Host "`n=== Restore Summary ===" -ForegroundColor Red
    foreach ($vm in $VMs) {
        Write-Host ("  {0,-10} {1}" -f $vm, $restoreResults[$vm]) -ForegroundColor Red
    }
    Write-Host "`n=== One or more restores FAILED — NOT starting any VMs ===" -ForegroundColor Red
    exit 1
}

# --- Only after all 3 restores succeeded — start VMs ---
$startResults = @{}
$anyStartFailed = $false
foreach ($vm in $VMs) {
    try {
        Start-VM -Name $vm -ErrorAction Stop
        $startResults[$vm] = 'started'
    } catch {
        $startResults[$vm] = "FAILED: $($_.Exception.Message)"
        $anyStartFailed = $true
    }
}

# --- Summary ---
Write-Host "`n=== Restore Summary ===" -ForegroundColor Cyan
foreach ($vm in $VMs) {
    $state = try { (Get-VM -Name $vm -ErrorAction Stop).State } catch { 'unknown' }
    $line = "  {0,-10} restored={1,-10} start={2,-10} state={3}" -f `
        $vm, $restoreResults[$vm], $startResults[$vm], $state
    $color = if ($startResults[$vm] -eq 'started') { 'Green' } else { 'Red' }
    Write-Host $line -ForegroundColor $color
}

if ($anyStartFailed) {
    Write-Host "`n=== One or more VMs FAILED to start ===" -ForegroundColor Red
    exit 1
}

Write-Host "`n=== All VMs restored and running ===" -ForegroundColor Green
Write-Host "SSH in:  vagrant ssh control1" -ForegroundColor Gray
