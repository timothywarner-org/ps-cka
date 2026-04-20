# cka-validate.ps1 — Verify all 3 VMs have CKA prereqs intact
# Run from L:\cka-lab in admin PowerShell after vagrant up or snapshot restore
#
# Implementation note: the validation script is kept in lib/validate-node.sh
# and piped to each VM via stdin (`bash -s`). Passing a long multi-line
# heredoc as `vagrant ssh -c "$script"` truncates on Windows OpenSSH and
# also causes $LASTEXITCODE to reflect only the outer vagrant process —
# stdin delivery is both reliable and propagates the inner script's
# exit code correctly.

#Requires -RunAsAdministrator

$VMs = @("control1", "worker1", "worker2")
$AllPassed = $true

# Roll-up counters across all VMs. validate-node.sh emits [PASS]/[WARN]/[FAIL]
# tags on each finding — we tally by scraping the captured output so the PS
# wrapper can surface a human-readable summary without touching the bash side.
$TotalPass = 0
$TotalWarn = 0
$TotalFail = 0

$ScriptPath = Join-Path $PSScriptRoot 'lib\validate-node.sh'
if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: validation script not found at $ScriptPath" -ForegroundColor Red
    exit 1
}

# --- Run validation on each VM ---
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  CKA Lab — Pre-cluster Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Note: [WARN] findings do NOT fail the validator —" -ForegroundColor Yellow
Write-Host "  only [FAIL] blocks. Review warnings to improve lab health." -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

foreach ($vm in $VMs) {
    # Pipe the script to `bash -s` over stdin. -c "bash -s" is the sole
    # argument to vagrant ssh, so OpenSSH can't truncate our payload —
    # the payload never rides on the SSH command line.
    $result = Get-Content -Raw $ScriptPath | vagrant ssh $vm -c "bash -s" 2>&1
    Write-Host $result

    # Tally per-VM findings from the captured output.
    $resultText = ($result | Out-String)
    $TotalPass += ([regex]::Matches($resultText, '\[PASS\]')).Count
    $TotalWarn += ([regex]::Matches($resultText, '\[WARN\]')).Count
    $TotalFail += ([regex]::Matches($resultText, '\[FAIL\]')).Count

    if ($LASTEXITCODE -ne 0) {
        Write-Host ">>> $vm FAILED validation <<<`n" -ForegroundColor Red
        $AllPassed = $false
    } else {
        Write-Host ""
    }
}

# --- Aggregate summary across all 3 VMs ---
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Summary across all nodes:" -ForegroundColor Cyan
Write-Host ("    PASS: {0}" -f $TotalPass) -ForegroundColor Green
Write-Host ("    WARN: {0}" -f $TotalWarn) -ForegroundColor Yellow
Write-Host ("    FAIL: {0}" -f $TotalFail) -ForegroundColor Red
Write-Host "========================================" -ForegroundColor Cyan

# --- Final verdict ---
if ($AllPassed) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ALL NODES READY — safe to snapshot" -ForegroundColor Green
    Write-Host "  or run: kubeadm init on control1" -ForegroundColor Green
    if ($TotalWarn -gt 0) {
        Write-Host "  ($TotalWarn warning(s) present — non-blocking)" -ForegroundColor Yellow
    }
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ONE OR MORE NODES FAILED" -ForegroundColor Red
    Write-Host "  Re-provision:  vagrant provision <name>" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}
