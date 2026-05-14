# cka-status.ps1 — Report Hyper-V CKA lab VM state and offer teardown
# Run from admin PowerShell (Hyper-V cmdlets require elevation)
#
# Read-only status probe for the Vagrant + Hyper-V CKA path. Reports per-VM
# Hyper-V state (Running / Off / Saved / Missing) plus IP reachability, and
# if any VM is Running offers to invoke cka-down.ps1 to halt them gracefully.
#
# Pairs with cka-up.ps1 / cka-down.ps1 the same way kind-status.ps1 pairs
# with kind-up.ps1 / kind-down.ps1. Atomicity discipline matches the
# snapshot/restore scripts: never act on a half-built lab without saying so.
#
# Parameters:
#   -Quiet     Skip the interactive teardown prompt. Exit 0 if all VMs are
#              Off or Missing, exit 1 if any VM is Running. Useful for CI
#              or pre-record sanity checks.
#
# Examples:
#   .\cka-status.ps1
#   .\cka-status.ps1 -Quiet

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'

# Same VM list as cka-snapshot.ps1 / cka-restore.ps1 / cka-info.ps1.
# Keep in sync if a fourth node is ever added to Vagrantfile.
$Nodes = @(
    @{ Name = "control1"; IP = "192.168.50.10" },
    @{ Name = "worker1";  IP = "192.168.50.11" },
    @{ Name = "worker2";  IP = "192.168.50.12" }
)

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  CKA LAB - HYPER-V VM STATUS" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ---------------------------------------------------------------
# Hyper-V availability sanity check
# ---------------------------------------------------------------
# Get-VM throws if the Hyper-V module isn't loaded or the service isn't
# running. Detect that up front rather than letting every per-VM lookup
# fail with the same opaque message.
if (-not (Get-Command Get-VM -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Hyper-V PowerShell module not available." -ForegroundColor Red
    Write-Host "        Install with: Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All" -ForegroundColor Gray
    exit 1
}

# ---------------------------------------------------------------
# Per-VM state + reachability
# ---------------------------------------------------------------
# Two signals per node:
#   1. Hyper-V state (authoritative for Running/Off/Saved/Missing)
#   2. Ping (proves networking is up — a Running VM can still be unreachable
#      mid-boot or if CKA-NAT switch is broken)
$results = foreach ($n in $Nodes) {
    $vmState = 'Missing'
    try {
        $vm = Get-VM -Name $n.Name -ErrorAction Stop
        $vmState = "$($vm.State)"
    } catch {
        # Stays 'Missing' — handled in summary
    }

    $ping = $false
    if ($vmState -eq 'Running') {
        # Only ping Running VMs. Pinging an Off VM is wasted seconds.
        $ping = Test-Connection -ComputerName $n.IP -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction SilentlyContinue
    }

    [pscustomobject]@{
        Name     = $n.Name
        IP       = $n.IP
        VmState  = $vmState
        Reachable = $ping
    }
}

# ---------------------------------------------------------------
# Render summary table
# ---------------------------------------------------------------
Write-Host ("  {0,-10} {1,-16} {2,-10} {3}" -f "NODE", "IP", "HYPER-V", "PING") -ForegroundColor White
Write-Host ("  " + ("-" * 50)) -ForegroundColor DarkGray

foreach ($r in $results) {
    $stateColor = switch ($r.VmState) {
        'Running' { 'Green' }
        'Off'     { 'Yellow' }
        'Saved'   { 'Yellow' }
        'Missing' { 'Red' }
        default   { 'Gray' }
    }
    $pingText  = if ($r.VmState -ne 'Running') { '-' } elseif ($r.Reachable) { 'OK' } else { 'NO' }
    $pingColor = if ($r.VmState -ne 'Running') { 'DarkGray' } elseif ($r.Reachable) { 'Green' } else { 'Red' }

    Write-Host ("  {0,-10} {1,-16} " -f $r.Name, $r.IP) -NoNewline
    Write-Host ("{0,-10} " -f $r.VmState) -ForegroundColor $stateColor -NoNewline
    Write-Host $pingText -ForegroundColor $pingColor
}

Write-Host ""

# ---------------------------------------------------------------
# Aggregate state and decide whether to offer teardown
# ---------------------------------------------------------------
$running = @($results | Where-Object { $_.VmState -eq 'Running' })
$missing = @($results | Where-Object { $_.VmState -eq 'Missing' })
$off     = @($results | Where-Object { $_.VmState -eq 'Off' -or $_.VmState -eq 'Saved' })

if ($missing.Count -eq $Nodes.Count) {
    Write-Host "  No Hyper-V CKA VMs exist on this host." -ForegroundColor Gray
    Write-Host "  To create them:  vagrant up" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

if ($missing.Count -gt 0) {
    # Partial lab — flag it loudly. Snapshot/restore would refuse to act here;
    # cka-status just reports it.
    Write-Host ("  [WARN] {0} VM(s) missing: {1}" -f $missing.Count, (($missing.Name) -join ', ')) -ForegroundColor Yellow
    Write-Host "         Lab is in a partial state. Run 'vagrant up' to recreate." -ForegroundColor Gray
    Write-Host ""
}

if ($running.Count -eq 0) {
    Write-Host "  All present VMs are stopped. Nothing to halt." -ForegroundColor Green
    if ($off.Count -gt 0) {
        Write-Host "  Start them with:  .\cka-up.ps1" -ForegroundColor Gray
    }
    Write-Host ""
    exit 0
}

Write-Host ("  {0} VM(s) Running: {1}" -f $running.Count, (($running.Name) -join ', ')) -ForegroundColor Green
$unreachable = @($running | Where-Object { -not $_.Reachable })
if ($unreachable.Count -gt 0) {
    Write-Host ("  [WARN] {0} Running VM(s) not pinging: {1}" -f $unreachable.Count, (($unreachable.Name) -join ', ')) -ForegroundColor Yellow
    Write-Host "         May still be booting, or CKA-NAT switch / netplan needs a look." -ForegroundColor Gray
}
Write-Host ""

# Quiet mode: report-only. Exit 1 to signal "something is up" so callers
# can branch without parsing output. Mirrors kind-status.ps1 semantics.
if ($Quiet) {
    Write-Host "  -Quiet specified — skipping teardown prompt." -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# ---------------------------------------------------------------
# Teardown offer
# ---------------------------------------------------------------
Write-Host "Choose an action:" -ForegroundColor White
Write-Host "  [0] Leave VMs running"
Write-Host "  [1] Halt VMs gracefully  ->  cka-down.ps1  (vagrant halt)"
Write-Host ""

$choice = Read-Host "Enter choice [0]"
if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '0') {
    Write-Host "  Leaving VMs running." -ForegroundColor Gray
    Write-Host ""
    exit 0
}

if ($choice -eq '1') {
    $down = Join-Path -Path $PSScriptRoot -ChildPath "cka-down.ps1"
    if (Test-Path -Path $down) {
        Write-Host ""
        Write-Host "  Running cka-down.ps1..." -ForegroundColor Cyan
        & $down
    } else {
        Write-Host "[ERROR] cka-down.ps1 not found next to this script." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[ERROR] Invalid choice '$choice'. Aborted." -ForegroundColor Red
    exit 1
}
