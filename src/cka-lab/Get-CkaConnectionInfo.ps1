<#
.SYNOPSIS
    Print the CKA lab connection guide (IPs + SSH) -- friendly-named shim.

.DESCRIPTION
    Thin forwarder so the Course 3 connection-info control runs straight from
    src\cka-lab. The real listing logic lives ONCE in the subfolder copy; this calls
    it and propagates the exit code.

.EXAMPLE
    .\Get-CkaConnectionInfo.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab. Forwards to:
            course-03-lifecycle-upgrades\Get-CkaConnectionInfo.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

& (Join-Path -Path $PSScriptRoot -ChildPath 'course-03-lifecycle-upgrades\Get-CkaConnectionInfo.ps1') @args
exit $LASTEXITCODE
