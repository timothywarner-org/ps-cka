<#
.SYNOPSIS
    Gracefully halt the 3 CKA lab VMs (control1, worker1, worker2) -- friendly-named shim.

.DESCRIPTION
    Thin forwarder so the Course 3 control runs straight from src\cka-lab. The real
    `vagrant halt` logic lives ONCE in the subfolder copy; this calls it and
    propagates the exit code.

.EXAMPLE
    .\Stop-CkaLab.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab. Forwards to:
            course-03-lifecycle-upgrades\Stop-CkaLab.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

& (Join-Path -Path $PSScriptRoot -ChildPath 'course-03-lifecycle-upgrades\Stop-CkaLab.ps1') @args
exit $LASTEXITCODE
