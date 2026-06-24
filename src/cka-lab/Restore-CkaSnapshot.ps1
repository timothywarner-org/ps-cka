<#
.SYNOPSIS
    Rewind all 3 CKA lab VMs to a named checkpoint -- friendly-named shim.

.DESCRIPTION
    Thin forwarder so the Course 3 "re-record" control runs straight from
    src\cka-lab. The real atomic restore logic lives ONCE in the subfolder copy;
    this passes every argument through (positional name, -WhatIf) and propagates the
    exit code.

.EXAMPLE
    .\Restore-CkaSnapshot.ps1 m01-cluster-ready

.EXAMPLE
    .\Restore-CkaSnapshot.ps1 -SnapshotName test -WhatIf

.NOTES
    Author: Tim Warner | CKA Course 3 lab. Forwards to:
            course-03-lifecycle-upgrades\Restore-CkaSnapshot.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

& (Join-Path -Path $PSScriptRoot -ChildPath 'course-03-lifecycle-upgrades\Restore-CkaSnapshot.ps1') @args
exit $LASTEXITCODE
