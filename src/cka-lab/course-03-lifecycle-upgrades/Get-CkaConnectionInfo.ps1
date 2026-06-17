<#
.SYNOPSIS
    Print the CKA lab connection guide and show which VMs are reachable.

.DESCRIPTION
    Lists each node (control1, worker1, worker2) with its static IP, a quick ping check
    reported as the words UP / DOWN (text carries the meaning -- never color alone), and
    the SSH command to reach it.

.EXAMPLE
    .\Get-CkaConnectionInfo.ps1

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

$Nodes = Get-CkaLabNodes

Write-Step 'CKA lab -- connection guide'

Write-Host ("  {0,-10} {1,-16} {2,-7} {3}" -f 'NODE', 'IP', 'STATUS', 'SSH COMMAND')
Write-Host ('  ' + ('-' * 58))

foreach ($n in $Nodes) {
    # 1 packet, 1s timeout. Status is reported as UP / DOWN text so the table is
    # readable without relying on color.
    $ping = Test-Connection -ComputerName $n.IP -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction SilentlyContinue
    $status = if ($ping) { 'UP' } else { 'DOWN' }
    Write-Host ("  {0,-10} {1,-16} {2,-7} vagrant ssh {3}" -f $n.Name, $n.IP, $status, $n.Name)
}

Write-Info 'Username / password:  vagrant / vagrant'
Write-Info 'SSH by name:  vagrant ssh control1   (or worker1 / worker2)'
