<#
.SYNOPSIS
    Verify all three CKA VMs (control1, worker1, worker2) have the kubeadm prereqs intact.

.DESCRIPTION
    Runs lib\validate-node.sh on each VM, piped over stdin to `bash -s`. Delivering the
    script on stdin (rather than as a `vagrant ssh -c "<long script>"` argument) avoids
    Windows OpenSSH command-line truncation AND makes $LASTEXITCODE reflect the inner
    script's exit code. Findings tagged [PASS]/[WARN]/[FAIL] are tallied into a per-lab
    summary. [WARN] does NOT fail the run; only [FAIL] blocks. Use it after `vagrant up`
    or `Restore-CkaSnapshot.ps1`, before you snapshot a clean baseline.

.EXAMPLE
    .\Test-CkaLabReady.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param()

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# These Course 3 controls live one level down from the lab. The Vagrantfile and
# your existing VMs are in the parent folder (src\cka-lab), so point Vagrant
# there -- it drives the SAME VMs, never a second copy.
$env:VAGRANT_CWD = Split-Path -Parent $PSScriptRoot

$VMs = Get-CkaLabVMs
$AllPassed = $true
$TotalPass = 0
$TotalWarn = 0
$TotalFail = 0

$ScriptPath = Join-Path -Path $PSScriptRoot -ChildPath '..\lib\validate-node.sh'
if (-not (Test-Path -Path $ScriptPath)) {
    Write-ErrorMsg "Validation script not found at $ScriptPath"
    exit 1
}

Write-Step 'CKA lab -- pre-cluster validation'
Write-Info '[WARN] findings do NOT fail the validator -- only [FAIL] blocks.'

foreach ($vm in $VMs) {
    # Pipe the script to `bash -s` over stdin (see .DESCRIPTION for why stdin).
    $result = Get-Content -Raw $ScriptPath | vagrant ssh $vm -c 'bash -s' 2>&1
    Write-Host $result

    $resultText = ($result | Out-String)
    $TotalPass += ([regex]::Matches($resultText, '\[PASS\]')).Count
    $TotalWarn += ([regex]::Matches($resultText, '\[WARN\]')).Count
    $TotalFail += ([regex]::Matches($resultText, '\[FAIL\]')).Count

    if ($LASTEXITCODE -ne 0) {
        Write-ErrorMsg ">>> $vm FAILED validation <<<"
        $AllPassed = $false
    }
}

Write-Step 'Summary across all nodes'
Write-Success ("PASS: {0}" -f $TotalPass)
Write-Warn    ("WARN: {0}" -f $TotalWarn)
if ($TotalFail -gt 0) { Write-ErrorMsg ("FAIL: {0}" -f $TotalFail) } else { Write-Info ("FAIL: {0}" -f $TotalFail) }

if ($AllPassed) {
    Write-Success 'ALL NODES READY -- safe to snapshot, or run: kubeadm init on control1'
    if ($TotalWarn -gt 0) { Write-Warn ("{0} warning(s) present -- non-blocking" -f $TotalWarn) }
}
else {
    Write-ErrorMsg 'ONE OR MORE NODES FAILED'
    Write-Info 'Re-provision:  vagrant provision <name>'
    exit 1
}
