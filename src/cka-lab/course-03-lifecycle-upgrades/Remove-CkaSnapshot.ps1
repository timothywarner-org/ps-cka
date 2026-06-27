<#
.SYNOPSIS
    Inventory and prune the Hyper-V checkpoints across the CKA lab
    (control1, worker1, worker2) -- keep the VMs and your key save points,
    clear out the recording cruft.

.DESCRIPTION
    The re-record loop is generous with checkpoints. Every M02 upgrade take drops
    'm02-after-control1' and 'm02-after-worker1', and because Hyper-V lets two
    checkpoints share a name, ten takes leave ten copies of each -- with a stack of
    differencing disks (.avhdx) growing underneath every one. After a recording
    sprint you want the machines and a couple of clean save points, not the pile.

    This script is the cleanup pass. It runs in three gears:

      * INVENTORY (default, read-only). With no -Name and no -Prune it changes
        nothing -- it lists every checkpoint across all three VMs, grouped by name,
        with how many copies and how old, and flags which names are protected. Run
        it first, every time, to see the tree before you cut it.

      * TARGETED. -Name <names> removes exactly those checkpoint names from all
        three VMs (every copy of each, so duplicate-named cruft goes in one shot).

      * PRUNE. -Prune removes every checkpoint whose name is NOT in -Keep. The
        keep-list defaults to the two save points the courses depend on
        ('pre-cluster' and 'm02-pre-upgrade'); everything else is cleared.

    The VMs themselves are never touched -- this only removes checkpoints. Removing
    a Hyper-V checkpoint merges its .avhdx back into the parent in the background,
    which is how the disk space comes back. The merge is safe while the VM runs.

    SAFETY -- protected names, dry run, confirm:
    Names in -Keep are NEVER removed, even if you also pass them to -Name -- you
    cannot fat-finger away your pristine baseline. Both -Name and -Prune support
    -WhatIf (show what would go, change nothing) and prompt before each delete
    unless you pass -Confirm:$false.

    ACCESSIBILITY:
    Output flows through the shared helpers in lib\CkaLab.ps1, which label every
    line ([OK]/[INFO]/[WARN]/[ERROR]) on the Wong colorblind-safe palette. Meaning
    never rides on color alone.

.PARAMETER Keep
    Checkpoint names to protect. These are never removed by -Prune and are skipped
    even if named in -Name. Defaults to 'pre-cluster' and 'm02-pre-upgrade' -- the
    clean baselines the Module 2 and Module 3 demos rewind to.

.PARAMETER Name
    Specific checkpoint name(s) to remove from all three VMs. Every copy of each
    name goes, which is what clears duplicate-named recording cruft. Protected
    names (see -Keep) are skipped with a warning.

.PARAMETER Prune
    Remove every checkpoint whose name is not in -Keep. Use this to reclaim the
    whole pile after a recording sprint while keeping your save points.

.EXAMPLE
    .\Remove-CkaSnapshot.ps1
    Inventory only. Lists every checkpoint on every VM, grouped, protected names
    flagged. Changes nothing. Start here.

.EXAMPLE
    .\Remove-CkaSnapshot.ps1 -Name m02-after-control1, m02-after-worker1
    Removes every copy of those two node-boundary checkpoints from all three VMs.

.EXAMPLE
    .\Remove-CkaSnapshot.ps1 -Prune
    Removes everything except 'pre-cluster' and 'm02-pre-upgrade'. The big sweep.

.EXAMPLE
    .\Remove-CkaSnapshot.ps1 -Prune -Keep pre-cluster, m02-pre-upgrade, m01-cluster-ready -WhatIf
    Dry run of a prune that also protects the M01 save point. Changes nothing.

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Save-CkaSnapshot.ps1 (create), Restore-CkaSnapshot.ps1 (rewind),
                Get-CkaLabStatus.ps1 (inspect)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'Inventory')]
param(
    [Parameter(ParameterSetName = 'Targeted', Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Name,

    [Parameter(ParameterSetName = 'Prune', Mandatory)]
    [switch]$Prune,

    [Parameter(ParameterSetName = 'Targeted')]
    [Parameter(ParameterSetName = 'Prune')]
    [Parameter(ParameterSetName = 'Inventory')]
    [string[]]$Keep = @('pre-cluster', 'm02-pre-upgrade')
)

$ErrorActionPreference = 'Stop'

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# One definition of the node list lives in lib\CkaLab.ps1 (Get-CkaLabVMs),
# so every wrapper agrees on control1 / worker1 / worker2.
$VMs = Get-CkaLabVMs

# --- Pre-flight: confirm every VM exists before reading or removing anything ---
# Same atomic guard the Save/Restore pair uses -- we would rather report a clean
# failure than act against a half-present lab.
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
    Write-ErrorMsg "Aborted -- missing VM(s): $($missing -join ', '). Nothing was read or removed."
    Write-Info 'Bring the lab up first with:  .\Start-CkaLab.ps1'
    exit 1
}

# --- Gather every checkpoint across all VMs, grouped by name ------------------
# Group by name because that is the unit the learner reasons about ("the
# m02-after-control1 checkpoints"), and the unit Remove-VMCheckpoint -Name acts on.
$all = foreach ($vm in $VMs) {
    Get-VMCheckpoint -VMName $vm -ErrorAction SilentlyContinue |
        Select-Object @{ N = 'VM'; E = { $vm } }, Name, CreationTime
}

if (-not $all) {
    Write-Step "No checkpoints found on any lab VM. Nothing to clean -- you are already tidy."
    exit 0
}

$groups = $all | Group-Object Name | Sort-Object Name

# --- Inventory (always shown) -------------------------------------------------
Write-Step "Checkpoint inventory across $($VMs.Count) VMs ($($all.Count) total, $($groups.Count) distinct name(s))"
foreach ($g in $groups) {
    $protected = $Keep -contains $g.Name
    $oldest = ($g.Group | Measure-Object CreationTime -Minimum).Minimum
    $newest = ($g.Group | Measure-Object CreationTime -Maximum).Maximum
    $span = if ($oldest -eq $newest) { $newest.ToString('yyyy-MM-dd HH:mm') }
            else { "$($oldest.ToString('yyyy-MM-dd HH:mm')) .. $($newest.ToString('yyyy-MM-dd HH:mm'))" }
    $tag = if ($protected) { '[KEEP]  ' } else { '        ' }

    # A name present on fewer than every VM, or more than once per VM, is a smell
    # worth surfacing -- partial or duplicated checkpoints are exactly the cruft.
    $perVm = ($g.Group | Group-Object VM | Measure-Object).Count
    $note = ''
    if ($g.Count -gt $VMs.Count) { $note = "  (duplicated -- $($g.Count) copies across $perVm VM[s])" }
    elseif ($perVm -lt $VMs.Count) { $note = "  (partial -- only on $perVm of $($VMs.Count) VMs)" }

    if ($protected) { Write-Success "  $tag$($g.Name)  x$($g.Count)  $span$note" }
    else { Write-Info "  $tag$($g.Name)  x$($g.Count)  $span$note" }
}

# Inventory-only run stops here -- this is the read-only default gear.
if ($PSCmdlet.ParameterSetName -eq 'Inventory') {
    Write-Step "Read-only inventory. To clean up:  .\Remove-CkaSnapshot.ps1 -Prune   (keeps: $($Keep -join ', '))"
    exit 0
}

# --- Decide the removal target ------------------------------------------------
$presentNames = $groups.Name

if ($Prune) {
    $targets = $presentNames | Where-Object { $Keep -notcontains $_ }
}
else {
    # Targeted: honor the protect-list even here, so -Keep is an absolute guard.
    $targets = @()
    foreach ($n in $Name) {
        if ($Keep -contains $n) {
            Write-Warn "Skipping '$n' -- it is in the protected -Keep list. Drop it from -Keep to remove it."
        }
        elseif ($presentNames -notcontains $n) {
            Write-Warn "Skipping '$n' -- no checkpoint by that name on any lab VM."
        }
        else {
            $targets += $n
        }
    }
}

if (-not $targets) {
    Write-Step 'Nothing to remove. The protected save points are all that is left.'
    exit 0
}

$doomedCount = ($all | Where-Object { $targets -contains $_.Name }).Count
Write-Step "Removing $($targets.Count) checkpoint name(s) ($doomedCount copies) -- protected: $($Keep -join ', ')"

# --- Remove each target name from every VM -----------------------------------
$failed = @()
foreach ($n in $targets) {
    foreach ($vm in $VMs) {
        # Skip VMs that never had this checkpoint, so partial-name cruft does not
        # spray harmless "not found" noise.
        if (-not (Get-VMCheckpoint -VMName $vm -Name $n -ErrorAction SilentlyContinue)) { continue }

        # -WhatIf flows through ShouldProcess: it prints the intent and removes nothing.
        if ($PSCmdlet.ShouldProcess("$vm -> $n", 'Remove checkpoint (merges .avhdx into parent)')) {
            try {
                # -Name removes EVERY copy with this name on the VM -- the duplicate sweep.
                Remove-VMCheckpoint -VMName $vm -Name $n -Confirm:$false -ErrorAction Stop
                Write-Success "  $vm -- removed '$n'"
            }
            catch {
                Write-ErrorMsg "  $vm -- FAILED to remove '$n': $($_.Exception.Message)"
                $failed += "$vm/$n"
            }
        }
    }
}

if ($failed.Count -gt 0) {
    Write-ErrorMsg "One or more removals FAILED: $($failed -join ', ')"
    exit 1
}

Write-Step 'Cleanup complete. Disk merges run in the background -- give Hyper-V a minute to reclaim space.'
Write-Info 'Re-run with no arguments any time to confirm the tree is tidy.'
