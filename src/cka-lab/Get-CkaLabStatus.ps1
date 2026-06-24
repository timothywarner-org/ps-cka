<#
.SYNOPSIS
    Report Hyper-V power + ping state of the 3 CKA lab VMs -- friendly-named shim.

.DESCRIPTION
    Thin forwarder so the Course 3 status control runs straight from src\cka-lab.
    The real probe logic lives ONCE in the subfolder copy; this passes arguments
    through (e.g. -Quiet) and propagates the exit code, so CI checks still see the
    "1 if any VM Running" signal.

.EXAMPLE
    .\Get-CkaLabStatus.ps1

.EXAMPLE
    .\Get-CkaLabStatus.ps1 -Quiet

.NOTES
    Author: Tim Warner | CKA Course 3 lab. Forwards to:
            course-03-lifecycle-upgrades\Get-CkaLabStatus.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

& (Join-Path -Path $PSScriptRoot -ChildPath 'course-03-lifecycle-upgrades\Get-CkaLabStatus.ps1') @args
exit $LASTEXITCODE
