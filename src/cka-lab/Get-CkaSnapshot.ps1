<#
.SYNOPSIS
    Read-only inventory of Hyper-V checkpoints across the CKA lab
    (control1, worker1, worker2) -- what you have and when it was created.

.DESCRIPTION
    Quick "what save points do I have" check. Lists every checkpoint on every
    lab VM, grouped by name, newest first, with creation time and how many
    copies exist. Changes nothing -- for the cleanup pass (targeted removal
    or -Prune), use Remove-CkaSnapshot.ps1, which shares this same grouped
    view as its default read-only mode.

    A name present on fewer than all three VMs, or more than once per VM, is
    flagged -- that is exactly the kind of partial/duplicated checkpoint that
    Remove-CkaSnapshot.ps1 is built to clean up.

    ACCESSIBILITY:
    Output flows through the shared helpers in lib\CkaLab.ps1, which label
    every line ([OK]/[INFO]/[WARN]/[ERROR]) on the Wong colorblind-safe
    palette. Meaning never rides on color alone.

.PARAMETER Name
    Show only checkpoints matching this name (exact match). Omit to list
    every checkpoint on every VM.

.EXAMPLE
    .\Get-CkaSnapshot.ps1
    Lists every checkpoint across all three VMs, grouped by name, newest first.

.EXAMPLE
    .\Get-CkaSnapshot.ps1 -Name m02-pre-upgrade
    Shows only the m02-pre-upgrade checkpoint's per-VM creation times.

.NOTES
    Author: Tim Warner | CKA lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab
    Pairs with: Save-CkaSnapshot.ps1 (create), Restore-CkaSnapshot.ps1 (rewind),
                Remove-CkaSnapshot.ps1 (clean up)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Name
)

$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath 'lib\CkaLab.ps1')
Initialize-LabEncoding

# One definition of the node list lives in lib\CkaLab.ps1 (Get-CkaLabVMs),
# so every wrapper agrees on control1 / worker1 / worker2.
$VMs = Get-CkaLabVMs

# --- Pre-flight: confirm every VM exists before reading anything --------------
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
    Write-ErrorMsg "Aborted -- missing VM(s): $($missing -join ', '). Nothing to report."
    Write-Info 'Bring the lab up first with:  .\Start-CkaLab.ps1'
    exit 1
}

# --- Gather every checkpoint across all VMs, optionally filtered by -Name -----
$all = foreach ($vm in $VMs) {
    $checkpoints = Get-VMCheckpoint -VMName $vm -ErrorAction SilentlyContinue
    if ($Name) { $checkpoints = $checkpoints | Where-Object { $_.Name -eq $Name } }
    $checkpoints | Select-Object @{ N = 'VM'; E = { $vm } }, Name, CreationTime
}

if (-not $all) {
    if ($Name) {
        Write-Step "No checkpoint named '$Name' found on any lab VM."
    }
    else {
        Write-Step 'No checkpoints found on any lab VM.'
        Write-Info 'Create one with:  .\Save-CkaSnapshot.ps1 <name>'
    }
    exit 0
}

# Group by name -- the unit you reason about when deciding what to restore
# or prune -- newest checkpoint first so the current re-record point is on top.
$groups = $all | Group-Object Name | Sort-Object { ($_.Group | Measure-Object CreationTime -Maximum).Maximum } -Descending

Write-Step "Checkpoint inventory across $($VMs.Count) VMs ($($all.Count) total, $($groups.Count) distinct name(s))"
foreach ($g in $groups) {
    $oldest = ($g.Group | Measure-Object CreationTime -Minimum).Minimum
    $newest = ($g.Group | Measure-Object CreationTime -Maximum).Maximum
    $span = if ($oldest -eq $newest) { $newest.ToString('yyyy-MM-dd HH:mm') }
            else { "$($oldest.ToString('yyyy-MM-dd HH:mm')) .. $($newest.ToString('yyyy-MM-dd HH:mm'))" }

    # A name present on fewer than every VM, or more than once per VM, is a smell
    # worth surfacing -- partial or duplicated checkpoints are cleanup candidates.
    $perVm = ($g.Group | Group-Object VM | Measure-Object).Count
    $note = ''
    if ($g.Count -gt $VMs.Count) { $note = "  (duplicated -- $($g.Count) copies across $perVm VM[s])" }
    elseif ($perVm -lt $VMs.Count) { $note = "  (partial -- only on $perVm of $($VMs.Count) VMs)" }

    if ($note) { Write-Warn "  $($g.Name)  x$($g.Count)  $span$note" }
    else { Write-Success "  $($g.Name)  x$($g.Count)  $span" }
}

Write-Host ''
Write-Info 'Rewind to any of these with:   .\Restore-CkaSnapshot.ps1 <name>'
Write-Info 'Clean up cruft with:           .\Remove-CkaSnapshot.ps1 -Prune'
