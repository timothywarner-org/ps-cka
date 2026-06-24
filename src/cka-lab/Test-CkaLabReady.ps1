<#
.SYNOPSIS
    Verify kubeadm prereqs on all 3 CKA lab VMs -- friendly-named shim.

.DESCRIPTION
    Thin forwarder so the Course 3 readiness check runs straight from src\cka-lab.
    The real per-node validation (validate-node.sh piped over stdin, PASS/WARN/FAIL
    tally) lives ONCE in the subfolder copy; this calls it and propagates the exit
    code, so a [FAIL] still surfaces as a non-zero exit.

.EXAMPLE
    .\Test-CkaLabReady.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab. Forwards to:
            course-03-lifecycle-upgrades\Test-CkaLabReady.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

& (Join-Path -Path $PSScriptRoot -ChildPath 'course-03-lifecycle-upgrades\Test-CkaLabReady.ps1') @args
exit $LASTEXITCODE
