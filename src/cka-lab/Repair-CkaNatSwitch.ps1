<#
.SYNOPSIS
    Repair the CKA-NAT host networking when `vagrant up` hangs at
    "Waiting for machine to boot".

.DESCRIPTION
    THE SYMPTOM. `vagrant up` prints "IP: 192.168.50.10" (so the VM booted and
    Hyper-V's KVP service can see it), then sits at "Waiting for machine to
    boot ... SSH address: 192.168.50.10:22" until it times out. Meanwhile
    create-nat-switch.ps1 has already printed a red `New-NetIPAddress ...
    Element not found`.

    THE CAUSE. The Hyper-V switch object named CKA-NAT still exists, but its
    HOST virtual adapter -- `vEthernet (CKA-NAT)` -- is reported `Not Present`.
    That adapter is the host's leg into the lab subnet. Without it:

      * New-NetIPAddress has no interface to bind 192.168.50.1 to, hence
        "Element not found" -- the error names the missing INTERFACE, not a
        missing IP, which is why it reads so cryptically;
      * the host holds no address on 192.168.50.0/24 and has no route to it;
      * the NAT object is Active but orphaned, serving a prefix no adapter
        carries;
      * so SSH to 192.168.50.10 cannot connect, and vagrant waits forever.

    The VMs are FINE. This is purely host-side plumbing, and it usually happens
    after a Windows update, a Hyper-V service restart, or a switch that got
    flipped from Internal to Private (a Private switch has no host adapter at
    all, by design).

    WHAT THIS SCRIPT DOES. Diagnoses first and prints what it found, then makes
    the smallest change that restores the host leg: forces the switch back to
    Internal if needed (which recreates the host vNIC), waits for the adapter to
    appear, assigns the gateway IP, and re-creates the NAT only if its prefix
    disagrees. Then it VERIFIES -- adapter Up, IP present, route present -- and
    refuses to report success on any of those failing.

    IDEMPOTENT. Safe to run when everything is already healthy; it reports
    "nothing to do" and exits 0.

.PARAMETER SwitchName
    Hyper-V switch name. Default 'CKA-NAT'.

.PARAMETER GatewayIP
    Host address on the lab subnet. Default '192.168.50.1'.

.PARAMETER PrefixLength
    Subnet prefix. Default 24.

.EXAMPLE
    .\Repair-CkaNatSwitch.ps1
    Diagnose and repair, then verify.

.EXAMPLE
    .\Repair-CkaNatSwitch.ps1 -WhatIf
    Show what would change without touching anything.

.NOTES
    Author:  Tim Warner | CKA lab
    Run as:  Administrator PowerShell 7+ (Hyper-V and NetAdapter cmdlets need it)
    Then:    .\Initialize-C04M01Lab.ps1
    Exit:    0 healthy, 1 could not repair
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateNotNullOrEmpty()][string]$SwitchName   = 'CKA-NAT',
    [ValidateNotNullOrEmpty()][string]$GatewayIP    = '192.168.50.1',
    [ValidateRange(8, 30)]   [int]   $PrefixLength = 24
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'lib\CkaLab.ps1')
Initialize-LabEncoding

$Alias  = "vEthernet ($SwitchName)"
$Subnet = ($GatewayIP -replace '\.\d+$', '.0') + "/$PrefixLength"
$NatName = "$SwitchName-Network"

Write-Host ""
Write-Host "$($Script:NeonGreen)=== CKA-NAT host networking repair ===$($Script:AnsiReset)"
Write-Host "  switch  : $SwitchName"
Write-Host "  adapter : $Alias"
Write-Host "  gateway : $GatewayIP/$PrefixLength   subnet: $Subnet"
Write-Host ""

#region Diagnose ----------------------------------------------------------------

Write-Step 'Diagnosing'

$vmSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if (-not $vmSwitch) {
    Write-ErrorMsg "Hyper-V switch '$SwitchName' does not exist at all."
    Write-Info    "Create it first:  .\create-nat-switch.ps1"
    exit 1
}
Write-Success "switch '$SwitchName' exists, SwitchType = $($vmSwitch.SwitchType)"

$adapter = Get-NetAdapter -Name $Alias -ErrorAction SilentlyContinue
$adapterOk = $adapter -and $adapter.Status -eq 'Up'
if ($adapterOk) { Write-Success "host adapter '$Alias' is Up" }
elseif ($adapter) { Write-Warn "host adapter '$Alias' exists but Status = $($adapter.Status)" }
else { Write-Warn "host adapter '$Alias' does not exist" }

$ipOk = [bool](Get-NetIPAddress -IPAddress $GatewayIP -ErrorAction SilentlyContinue)
if ($ipOk) { Write-Success "host holds $GatewayIP" } else { Write-Warn "host does NOT hold $GatewayIP" }

if ($adapterOk -and $ipOk) {
    Write-Host ""
    Write-Success 'Nothing to do -- host networking is already healthy.'
    Write-Info    'If vagrant still hangs, the problem is inside the VM, not on the host.'
    exit 0
}

#endregion

#region Repair ------------------------------------------------------------------

# A Private switch has no host adapter by design, so a NAT lab on a Private
# switch can never route. Internal is the only correct type here.
if ($vmSwitch.SwitchType -ne 'Internal') {
    if ($PSCmdlet.ShouldProcess($SwitchName, "Set-VMSwitch -SwitchType Internal")) {
        Write-Step "Switch is '$($vmSwitch.SwitchType)' -- forcing it to Internal (this recreates the host adapter)"
        Set-VMSwitch -Name $SwitchName -SwitchType Internal
        Write-Success 'SwitchType set to Internal'
    }
}
elseif (-not $adapter) {
    # Internal switch with a missing host vNIC: bounce the type to force
    # Windows to rebuild the adapter. Private has no host leg, so the round
    # trip Internal -> Private -> Internal is what actually recreates it.
    if ($PSCmdlet.ShouldProcess($SwitchName, "Bounce SwitchType to rebuild the host adapter")) {
        Write-Step 'Internal switch is missing its host adapter -- bouncing the switch type to rebuild it'
        Set-VMSwitch -Name $SwitchName -SwitchType Private
        Start-Sleep -Seconds 2
        Set-VMSwitch -Name $SwitchName -SwitchType Internal
        Write-Success 'switch type bounced'
    }
}

# The adapter appears asynchronously; poll rather than sleeping blind.
Write-Step "Waiting for '$Alias' to appear"
$adapter = $null
foreach ($i in 1..20) {
    $adapter = Get-NetAdapter -Name $Alias -ErrorAction SilentlyContinue
    if ($adapter -and $adapter.Status -eq 'Up') { break }
    Start-Sleep -Seconds 1
}
if (-not $adapter) {
    Write-ErrorMsg "'$Alias' never appeared. Reboot, or remove and recreate the switch:"
    Write-Info    "  Remove-VMSwitch -Name $SwitchName -Force ; .\create-nat-switch.ps1"
    exit 1
}
Write-Success "'$Alias' is present (Status = $($adapter.Status))"

# Clear any stale address on this interface before assigning ours, so a
# half-configured adapter cannot leave two addresses fighting.
if (-not (Get-NetIPAddress -IPAddress $GatewayIP -ErrorAction SilentlyContinue)) {
    if ($PSCmdlet.ShouldProcess($Alias, "New-NetIPAddress $GatewayIP/$PrefixLength")) {
        Write-Step "Assigning $GatewayIP/$PrefixLength to '$Alias'"
        Get-NetIPAddress -InterfaceAlias $Alias -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        New-NetIPAddress -IPAddress $GatewayIP -PrefixLength $PrefixLength -InterfaceAlias $Alias | Out-Null
        Write-Success "assigned $GatewayIP"
    }
}

# The NAT is usually fine and survives the adapter going missing. Only touch it
# when its prefix disagrees with the subnet we just configured.
$nat = Get-NetNat -Name $NatName -ErrorAction SilentlyContinue
if (-not $nat) {
    if ($PSCmdlet.ShouldProcess($NatName, "New-NetNat $Subnet")) {
        Write-Step "Creating NAT '$NatName' for $Subnet"
        New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $Subnet | Out-Null
        Write-Success 'NAT created'
    }
}
elseif ($nat.InternalIPInterfaceAddressPrefix -ne $Subnet) {
    if ($PSCmdlet.ShouldProcess($NatName, "Recreate NAT with prefix $Subnet")) {
        Write-Warn "NAT '$NatName' has prefix $($nat.InternalIPInterfaceAddressPrefix), expected $Subnet -- recreating"
        Remove-NetNat -Name $NatName -Confirm:$false
        New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $Subnet | Out-Null
        Write-Success 'NAT recreated'
    }
}
else { Write-Success "NAT '$NatName' already correct for $Subnet" }

#endregion

#region Verify ------------------------------------------------------------------

Write-Step 'Verifying (asserting, not assuming)'
$fail = 0

$adapter = Get-NetAdapter -Name $Alias -ErrorAction SilentlyContinue
if ($adapter -and $adapter.Status -eq 'Up') { Write-Success "adapter '$Alias' Up" }
else { Write-ErrorMsg "adapter '$Alias' is not Up"; $fail++ }

if (Get-NetIPAddress -IPAddress $GatewayIP -ErrorAction SilentlyContinue) { Write-Success "host holds $GatewayIP" }
else { Write-ErrorMsg "host does not hold $GatewayIP"; $fail++ }

if (Get-NetRoute -DestinationPrefix $Subnet -ErrorAction SilentlyContinue) { Write-Success "route to $Subnet present" }
else { Write-ErrorMsg "no route to $Subnet"; $fail++ }

Write-Host ""
if ($fail -gt 0) {
    Write-ErrorMsg "$fail check(s) still failing. Do NOT re-run vagrant yet."
    Write-Info 'Last resort:  Remove-VMSwitch -Name CKA-NAT -Force ; .\create-nat-switch.ps1 ; then re-run this script.'
    exit 1
}

Write-Success 'Host networking repaired.'
Write-Host ""
Write-Host '  Next:'
Write-Host '    .\Initialize-C04M01Lab.ps1'
Write-Host ''
Write-Host '  The VMs may already be running from the hung attempt -- that is fine,'
Write-Host '  vagrant up --no-provision is idempotent and will just reconnect.'
Write-Host ''
exit 0

#endregion
