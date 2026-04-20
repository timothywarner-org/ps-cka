# create-nat-switch.ps1 — Create CKA-NAT Hyper-V internal switch + NAT
# Called automatically by Vagrantfile trigger before 'vagrant up'

#Requires -RunAsAdministrator

$SwitchName = "CKA-NAT"
$NATName    = "CKA-NAT-Network"
$Subnet     = "192.168.50.0/24"
$GatewayIP  = "192.168.50.1"
$PrefixLen  = 24

# --- Subnet collision check: another interface already owns 192.168.50.0/24? ---
$existingRoute = Get-NetRoute -DestinationPrefix $Subnet -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceAlias -ne "vEthernet ($SwitchName)" }
if ($existingRoute) {
    Write-Error @"
Subnet $Subnet already routed via interface '$($existingRoute[0].InterfaceAlias)'.
This collides with the CKA-NAT lab network. Free the subnet before continuing:
  - Stop/remove the other lab (Docker bridge, WSL, another vagrant env, etc.)
  - Or edit `$Subnet / `$GatewayIP at the top of this script to a free /24.
"@
    exit 1
}

# --- Create the internal switch if it doesn't exist ---
$existingSwitch = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
if ($existingSwitch) {
    Write-Host "[OK] Switch '$SwitchName' already exists" -ForegroundColor Green
} else {
    Write-Host "[+]  Creating internal switch '$SwitchName'..." -ForegroundColor Yellow
    New-VMSwitch -Name $SwitchName -SwitchType Internal
    Write-Host "[OK] Switch created" -ForegroundColor Green
}

# --- Assign gateway IP to the host-side adapter ---
# Hyper-V names internal-switch host adapters exactly "vEthernet (<SwitchName>)".
# Match exactly to avoid picking up CKA-NAT-Legacy or user-created look-alikes.
$adapterName = "vEthernet ($SwitchName)"
$adapters = @(Get-NetAdapter | Where-Object { $_.Name -eq $adapterName })
if ($adapters.Count -eq 0) {
    Write-Error "Could not find adapter named '$adapterName' for switch '$SwitchName'"
    exit 1
} elseif ($adapters.Count -gt 1) {
    Write-Error "Found $($adapters.Count) adapters named '$adapterName' — ambiguous. Remove duplicates via Get-NetAdapter and retry."
    exit 1
}
$adapter = $adapters | Select-Object -First 1

$existingIP = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $GatewayIP -ErrorAction SilentlyContinue
if ($existingIP) {
    Write-Host "[OK] Gateway IP $GatewayIP already assigned" -ForegroundColor Green
} else {
    Write-Host "[+]  Assigning $GatewayIP to host adapter..." -ForegroundColor Yellow
    New-NetIPAddress -IPAddress $GatewayIP -PrefixLength $PrefixLen -InterfaceIndex $adapter.ifIndex
    Write-Host "[OK] Gateway IP assigned" -ForegroundColor Green
}

# --- Create NAT for internet access ---
$existingNAT = Get-NetNat -Name $NATName -ErrorAction SilentlyContinue
if ($existingNAT) {
    Write-Host "[OK] NAT '$NATName' already exists" -ForegroundColor Green
} else {
    Write-Host "[+]  Creating NAT '$NATName' for $Subnet..." -ForegroundColor Yellow
    New-NetNat -Name $NATName -InternalIPInterfaceAddressPrefix $Subnet
    Write-Host "[OK] NAT created" -ForegroundColor Green
}

Write-Host "`n[OK] CKA-NAT switch ready: $Subnet (gateway $GatewayIP)" -ForegroundColor Cyan
