<#
.SYNOPSIS
    Atomic Hyper-V checkpoint of all 3 CKA lab VMs -- friendly-named shim.

.DESCRIPTION
    Thin forwarder so the Course 3 "save point" control runs straight from
    src\cka-lab. The real atomic checkpoint logic lives ONCE in the subfolder copy;
    this passes every argument through (positional name, -WhatIf) and propagates the
    exit code.

.EXAMPLE
    .\Save-CkaSnapshot.ps1 m01-cluster-ready

.EXAMPLE
    .\Save-CkaSnapshot.ps1 -SnapshotName test -WhatIf

.NOTES
    Author: Tim Warner | CKA Course 3 lab. Forwards to:
            course-03-lifecycle-upgrades\Save-CkaSnapshot.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

& (Join-Path -Path $PSScriptRoot -ChildPath 'course-03-lifecycle-upgrades\Save-CkaSnapshot.ps1') @args
exit $LASTEXITCODE
