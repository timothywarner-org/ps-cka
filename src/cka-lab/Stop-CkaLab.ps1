<#
.SYNOPSIS
    Gracefully halt all three CKA lab VMs (control1, worker1, worker2).

.DESCRIPTION
    Runs `vagrant halt`, which sends a clean ACPI/OS shutdown so kubelet, etcd, and
    containerd stop in order and the disks stay healthy. This is the command to run
    at the end of a work session (prefer it over suspend for long-term VMs).

.EXAMPLE
    .\Stop-CkaLab.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Start-CkaLab.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# These Course 3 controls live one level down from the lab. The Vagrantfile and
# your existing VMs are in the parent folder (src\cka-lab), so point Vagrant
# there -- it drives the SAME VMs, never a second copy.
$env:VAGRANT_CWD = Split-Path -Parent $PSScriptRoot

Write-Step 'Shutting down CKA lab VMs (graceful halt)'
vagrant halt

Write-Success 'All VMs stopped.'
Write-Info 'Start again with:  .\Start-CkaLab.ps1'
