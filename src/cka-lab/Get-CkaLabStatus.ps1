<#
.SYNOPSIS
    Report Hyper-V state and reachability for the CKA lab VMs, and optionally halt them.

.DESCRIPTION
    Read-only status probe for the Vagrant + Hyper-V CKA lab. For each node
    (control1, worker1, worker2) it reports the authoritative Hyper-V state
    (Running / Off / Saved / Missing) plus a ping check, then -- if any VM is Running
    and you did not pass -Quiet -- offers to halt them gracefully via Stop-CkaLab.ps1.
    State and ping are printed as text, so meaning never depends on color alone.

.PARAMETER Quiet
    Skip the interactive teardown prompt. Exit 0 if all VMs are Off or Missing, exit 1
    if any VM is Running. Useful for CI or pre-record sanity checks.

.EXAMPLE
    .\Get-CkaLabStatus.ps1

.EXAMPLE
    .\Get-CkaLabStatus.ps1 -Quiet

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Start-CkaLab.ps1, Stop-CkaLab.ps1
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

$Nodes = Get-CkaLabNodes

Write-Step 'CKA lab -- Hyper-V VM status'

# Hyper-V availability sanity check -------------------------------------------
# Get-VM is missing if the Hyper-V module isn't installed. Catch that up front
# instead of letting every per-VM lookup fail with the same opaque message.
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    Write-ErrorMsg 'Hyper-V PowerShell module not available.'
    Write-Info 'Install with: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All'
    exit 1
}

# Per-VM state + reachability -------------------------------------------------
#   1. Hyper-V state is authoritative for Running/Off/Saved/Missing.
#   2. Ping proves networking is up (a Running VM can still be unreachable
#      mid-boot or if the CKA-NAT switch is broken).
$results = foreach ($n in $Nodes) {
    $vmState = 'Missing'
    try {
        $vm = Get-VM -Name $n.Name -ErrorAction Stop
        $vmState = "$($vm.State)"
    }
    catch {
        # stays 'Missing' -- handled in the summary
    }

    $ping = $false
    if ($vmState -eq 'Running') {
        $ping = Test-Connection -ComputerName $n.IP -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction SilentlyContinue
    }

    [pscustomobject]@{
        Name      = $n.Name
        IP        = $n.IP
        VmState   = $vmState
        Reachable = $ping
    }
}

# Summary table (state + ping reported as text) -------------------------------
Write-Host ("  {0,-10} {1,-16} {2,-10} {3}" -f 'NODE', 'IP', 'HYPER-V', 'PING')
Write-Host ('  ' + ('-' * 50))
foreach ($r in $results) {
    $pingText = if ($r.VmState -ne 'Running') { '-' } elseif ($r.Reachable) { 'OK' } else { 'NO' }
    Write-Host ("  {0,-10} {1,-16} {2,-10} {3}" -f $r.Name, $r.IP, $r.VmState, $pingText)
}
Write-Host ''

# Aggregate state and decide whether to offer teardown ------------------------
$running = @($results | Where-Object { $_.VmState -eq 'Running' })
$missing = @($results | Where-Object { $_.VmState -eq 'Missing' })
$off     = @($results | Where-Object { $_.VmState -eq 'Off' -or $_.VmState -eq 'Saved' })

if ($missing.Count -eq $Nodes.Count) {
    Write-Info 'No Hyper-V CKA VMs exist on this host.'
    Write-Info 'To create them:  vagrant up'
    exit 0
}

if ($missing.Count -gt 0) {
    Write-Warn ("{0} VM(s) missing: {1}" -f $missing.Count, (($missing.Name) -join ', '))
    Write-Info "Lab is in a partial state. Run 'vagrant up' to recreate."
}

if ($running.Count -eq 0) {
    Write-Success 'All present VMs are stopped. Nothing to halt.'
    if ($off.Count -gt 0) { Write-Info 'Start them with:  .\Start-CkaLab.ps1' }
    exit 0
}

Write-Success ("{0} VM(s) Running: {1}" -f $running.Count, (($running.Name) -join ', '))
$unreachable = @($running | Where-Object { -not $_.Reachable })
if ($unreachable.Count -gt 0) {
    Write-Warn ("{0} Running VM(s) not pinging: {1}" -f $unreachable.Count, (($unreachable.Name) -join ', '))
    Write-Info 'May still be booting, or the CKA-NAT switch / netplan needs a look.'
}
Write-Host ''

# Quiet mode: report-only. Exit 1 signals "something is up" so callers can branch.
if ($Quiet) {
    Write-Info '-Quiet specified -- skipping teardown prompt.'
    exit 1
}

# Teardown offer --------------------------------------------------------------
Write-Host 'Choose an action:'
Write-Host '  [0] Leave VMs running'
Write-Host '  [1] Halt VMs gracefully  ->  Stop-CkaLab.ps1  (vagrant halt)'
Write-Host ''

$choice = Read-Host 'Enter choice [0]'
if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0') {
    Write-Info 'Leaving VMs running.'
    exit 0
}

if ($choice -eq '1') {
    $down = Join-Path -Path $PSScriptRoot -ChildPath 'Stop-CkaLab.ps1'
    if (Test-Path -Path $down) {
        Write-Step 'Running Stop-CkaLab.ps1...'
        & $down
    }
    else {
        Write-ErrorMsg 'Stop-CkaLab.ps1 not found next to this script.'
        exit 1
    }
}
else {
    Write-ErrorMsg "Invalid choice '$choice'. Aborted."
    exit 1
}
