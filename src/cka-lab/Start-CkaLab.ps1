<#
.SYNOPSIS
    Boot all three CKA lab VMs (control1, worker1, worker2) without re-provisioning.

.DESCRIPTION
    Powers on the existing Vagrant Hyper-V VMs with --no-provision (so a normal
    start never re-runs the prereq shell scripts), then prints the connection guide.

.EXAMPLE
    .\Start-CkaLab.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Stop-CkaLab.ps1, Get-CkaLabStatus.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# These Course 3 controls live one level down from the lab. The Vagrantfile and
# your existing VMs are in the parent folder (src\cka-lab), so point Vagrant
# there -- it drives the SAME VMs, never a second copy.
$env:VAGRANT_CWD = Split-Path -Parent $PSScriptRoot

Write-Step 'Starting CKA lab VMs (no re-provision)'
vagrant up --no-provision

& (Join-Path -Path $PSScriptRoot -ChildPath 'Get-CkaConnectionInfo.ps1')
