#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$VmName,

    [Parameter(Mandatory)]
    [string]$IPAddress,

    [string]$Gateway = '192.168.50.1',
    [string]$DnsServer = '8.8.8.8',
    [switch]$Worker
)

$ErrorActionPreference = 'Stop'
$logPath = Join-Path $env:TEMP "cka-$VmName-network-bootstrap.log"

if (-not $Worker) {
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"",
        '-VmName', "`"$VmName`"",
        '-IPAddress', $IPAddress,
        '-Gateway', $Gateway,
        '-DnsServer', $DnsServer,
        '-Worker'
    )
    # Vagrant executes triggers inside a Windows job that closes child
    # processes when the trigger exits. Create the watcher outside that job so
    # it can wait for the VM import and first boot.
    $commandLine = "powershell.exe $($arguments -join ' ')"
    $created = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
        CommandLine = $commandLine
    }
    if ($created.ReturnValue -ne 0) {
        throw "Could not start network bootstrap watcher (Win32 error $($created.ReturnValue))"
    }
    Write-Host "[OK] Started guest network bootstrap watcher for $VmName ($IPAddress)"
    exit 0
}

function Write-BootstrapLog {
    param([string]$Message)

    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -LiteralPath $logPath -Value $line -Encoding utf8
}

Set-Content -LiteralPath $logPath -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Waiting for $VmName" -Encoding utf8

$remoteScript = @'
set -euo pipefail

IP_ADDRESS="$1"
GATEWAY="$2"
DNS_SERVER="$3"

IFACE="$(find /sys/class/net -mindepth 1 -maxdepth 1 -type l -printf '%f\n' | grep -v '^lo$' | head -n 1)"
if [ -z "$IFACE" ]; then
  echo "Could not detect a non-loopback interface" >&2
  exit 1
fi

MAC="$(cat "/sys/class/net/$IFACE/address")"
rm -f /etc/netplan/00-installer-config.yaml
rm -f /etc/netplan/50-cloud-init.yaml
rm -f /etc/netplan/50-vagrant.yaml

cat > /etc/netplan/01-cka-static.yaml <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    cka:
      match:
        macaddress: "$MAC"
      dhcp4: false
      addresses:
        - $IP_ADDRESS/24
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS_SERVER, 8.8.4.4]
NETPLAN

chmod 600 /etc/netplan/01-cka-static.yaml
netplan generate
nohup bash -c 'sleep 2; systemctl reboot' >/var/log/cka-network-bootstrap.log 2>&1 </dev/null &
echo "Static network prepared for $IP_ADDRESS"
'@

$deadline = (Get-Date).AddMinutes(10)
while ((Get-Date) -lt $deadline) {
    $temporaryKey = $null
    try {
        $adapter = Get-VMNetworkAdapter -VMName $VmName -ErrorAction Stop | Select-Object -First 1
        $addresses = @($adapter.IPAddresses)
        if ($addresses -contains $IPAddress) {
            Write-BootstrapLog "Static address $IPAddress is active"
            exit 0
        }

        $linkLocal = $addresses | Where-Object { $_ -like 'fe80::*' } | Select-Object -First 1
        if (-not $linkLocal) {
            Start-Sleep -Seconds 5
            continue
        }

        $hostAdapter = Get-NetAdapter -Name 'vEthernet (CKA-NAT)' -ErrorAction Stop
        $target = "vagrant@$linkLocal%$($hostAdapter.ifIndex)"
        $sourceKey = Join-Path $env:USERPROFILE '.vagrant.d\insecure_private_key'
        $temporaryKey = Join-Path $env:TEMP "cka-$VmName-$PID-insecure-key"
        Copy-Item -LiteralPath $sourceKey -Destination $temporaryKey -Force
        & icacls.exe $temporaryKey /inheritance:r /grant:r "$env:USERNAME`:(R)" | Out-Null

        Write-BootstrapLog "Configuring $target with Windows OpenSSH"
        $savedErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $remoteScript | & "$env:WINDIR\System32\OpenSSH\ssh.exe" `
            -i $temporaryKey `
            -o BatchMode=yes `
            -o ConnectTimeout=10 `
            -o LogLevel=ERROR `
            -o StrictHostKeyChecking=no `
            -o UserKnownHostsFile=NUL `
            $target `
            "sudo bash -s -- '$IPAddress' '$Gateway' '$DnsServer'" 2>&1 |
            ForEach-Object { Write-BootstrapLog $_ }
        $sshExitCode = $LASTEXITCODE
        $ErrorActionPreference = $savedErrorActionPreference

        if ($sshExitCode -eq 0) {
            Write-BootstrapLog 'Guest accepted the static network configuration'
        } else {
            Write-BootstrapLog "SSH exited with code $sshExitCode; retrying if the address is still absent"
        }
        Start-Sleep -Seconds 10
    } catch {
        Write-BootstrapLog "Waiting after error: $($_.Exception.Message)"
        Start-Sleep -Seconds 5
    } finally {
        if ($temporaryKey -and (Test-Path -LiteralPath $temporaryKey)) {
            Remove-Item -LiteralPath $temporaryKey -Force
        }
    }
}

Write-BootstrapLog "Timed out waiting to configure $VmName"
exit 1
