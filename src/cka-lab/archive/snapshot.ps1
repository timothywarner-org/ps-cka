<#
.SYNOPSIS
    Snapshot and restore all CKA lab VMs for teaching resets.

.DESCRIPTION
    Wraps Hyper-V checkpoints across all 3 VMs so you can save state
    after provisioning (pre-kubeadm) and restore between demos.

.PARAMETER Action
    save    — Create a named checkpoint on all VMs
    restore — Restore all VMs to a named checkpoint
    list    — List available checkpoints
    delete  — Delete a named checkpoint from all VMs

.PARAMETER Name
    Checkpoint name. Default: "pre-cluster"

.EXAMPLE
    .\snapshot.ps1 save                        # Save "pre-cluster" on all VMs
    .\snapshot.ps1 save -Name "post-cni"       # Save custom checkpoint
    .\snapshot.ps1 restore                     # Restore all to "pre-cluster"
    .\snapshot.ps1 list                        # Show available checkpoints
    .\snapshot.ps1 delete -Name "post-cni"     # Remove a checkpoint

.NOTES
    Author: Tim Warner
    Requires: PowerShell 7.0+, Hyper-V admin rights
#>

#Requires -Version 7.0
#Requires -Modules Hyper-V

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet("save", "restore", "list", "delete")]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$Name = "pre-cluster"
)

$VMs = @("control1", "worker1", "worker2")

switch ($Action) {
    "save" {
        foreach ($vm in $VMs) {
            Write-Output "Creating checkpoint '$Name' on $vm..."
            Checkpoint-VM -Name $vm -SnapshotName $Name
        }
        Write-Output ""
        Write-Output "Checkpoint '$Name' saved on all VMs."
        Write-Output "Restore with: .\snapshot.ps1 restore -Name '$Name'"
    }
    "restore" {
        foreach ($vm in $VMs) {
            Write-Output "Restoring $vm to checkpoint '$Name'..."
            Restore-VMCheckpoint -VMName $vm -Name $Name -Confirm:$false
        }
        # Start VMs after restore (checkpoints leave them in saved state)
        foreach ($vm in $VMs) {
            Write-Output "Starting $vm..."
            Start-VM -Name $vm
        }
        Write-Output ""
        Write-Output "All VMs restored to '$Name' and started."
    }
    "list" {
        foreach ($vm in $VMs) {
            Write-Output "=== $vm ==="
            Get-VMCheckpoint -VMName $vm | Format-Table Name, CreationTime -AutoSize
        }
    }
    "delete" {
        foreach ($vm in $VMs) {
            Write-Output "Removing checkpoint '$Name' from $vm..."
            Remove-VMCheckpoint -VMName $vm -Name $Name -ErrorAction SilentlyContinue
        }
        Write-Output "Checkpoint '$Name' removed."
    }
}
