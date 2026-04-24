# cka-info.ps1 — Print CKA lab connection info + verify VMs are running
# Run from L:\cka-lab

#Requires -Version 7.0
#Requires -RunAsAdministrator

$Nodes = @(
    @{ Name = "control1"; IP = "192.168.50.10" },
    @{ Name = "worker1";  IP = "192.168.50.11" },
    @{ Name = "worker2";  IP = "192.168.50.12" }
)

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "  CKA LAB — CONNECTION GUIDE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("  {0,-12} {1,-18} {2,-8} {3}" -f "NODE", "IP", "STATUS", "SSH COMMAND") -ForegroundColor White
# Separator spans the widest data row, not just the header labels: data rows
# format as "  {NODE,-12} {IP,-18} {STATUS,-8} ssh vagrant@<13-char IP>" =
# 2 + 12 + 1 + 18 + 1 + 8 + 1 + 25 = 68 chars total, so dashes = 68 - 2 = 66.
Write-Host ("  " + "-" * 66) -ForegroundColor DarkGray

foreach ($n in $Nodes) {
    # Quick ping test (1 packet, 1s timeout)
    $ping = Test-Connection -ComputerName $n.IP -Count 1 -Quiet -TimeoutSeconds 1 -ErrorAction SilentlyContinue
    $status = if ($ping) { "UP" } else { "DOWN" }
    $color  = if ($ping) { "Green" } else { "Red" }

    Write-Host ("  {0,-12} {1,-18} " -f $n.Name, $n.IP) -NoNewline
    Write-Host ("{0,-8} " -f $status) -ForegroundColor $color -NoNewline
    Write-Host ("ssh vagrant@{0}" -f $n.IP)
}

Write-Host ""
Write-Host "  Username:  vagrant" -ForegroundColor Gray
Write-Host "  Password:  vagrant" -ForegroundColor Gray
Write-Host "  Vagrant:   vagrant ssh <node>" -ForegroundColor Gray
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
