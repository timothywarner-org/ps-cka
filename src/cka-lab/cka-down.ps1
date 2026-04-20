# cka-down.ps1 — Gracefully shut down all CKA lab VMs
# Run from L:\cka-lab

#Requires -RunAsAdministrator

Write-Host "`n=== Shutting down CKA lab VMs ===" -ForegroundColor Cyan
vagrant halt
Write-Host "`n=== All VMs stopped ===" -ForegroundColor Green
Write-Host "Start again with:  .\cka-up.ps1" -ForegroundColor Gray
