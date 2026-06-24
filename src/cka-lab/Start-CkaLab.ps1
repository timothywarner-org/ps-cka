<#
.SYNOPSIS
    Boot the 3 CKA lab VMs (control1, worker1, worker2) -- friendly-named shim.

.DESCRIPTION
    Thin forwarder so the plain-English Course 3 control is runnable straight from
    src\cka-lab, without cd-ing into course-03-lifecycle-upgrades. The real logic
    (vagrant up --no-provision + connection guide) lives ONCE in the subfolder copy;
    this just calls it and propagates its exit code. Single source of truth, no
    divergent duplicate to keep in sync.

.EXAMPLE
    .\Start-CkaLab.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab. Forwards to:
            course-03-lifecycle-upgrades\Start-CkaLab.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

& (Join-Path -Path $PSScriptRoot -ChildPath 'course-03-lifecycle-upgrades\Start-CkaLab.ps1') @args
exit $LASTEXITCODE
