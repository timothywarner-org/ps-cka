# cka-up.ps1 — Boot all CKA lab VMs (no re-provisioning)
# Run from L:\cka-lab

#Requires -RunAsAdministrator

Write-Host "`n=== Starting CKA lab VMs ===" -ForegroundColor Cyan
vagrant up --no-provision
Write-Host ""
.\cka-info.ps1
