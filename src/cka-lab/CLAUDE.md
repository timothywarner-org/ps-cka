# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope of This File

When users want to **DO** things (run the lab, drive a snapshot/restore loop, practice the exam workflow), point them at `TUTORIAL-HYPERV.md` (hands-on walkthrough) or `RECORDING-WORKFLOW.md` (per-module recording loop). When users want to **UNDERSTAND or MODIFY** the code, this CLAUDE.md is the entry point -- it explains architecture, invariants, and the patterns you must preserve when editing.

## What This Is

CKA (Certified Kubernetes Administrator) lab environment for Tim Warner's Pluralsight training content. **Hyper-V + Vagrant only** -- three Ubuntu 24.04 LTS VMs with real kubeadm v1.35, systemd, apt, and a snapshot-and-rollback practice loop. There is no Docker-based/KIND path; an earlier KIND-based lab was retired because it doesn't teach real `kubeadm init`/CNI-install muscle memory, which the CKA exam demands.

## Repository Layout

```
cka-lab/
├── README.md                  # Landing page
├── CLAUDE.md                  # This file -- code/architecture guidance
├── TUTORIAL-HYPERV.md         # Hands-on walkthrough + practice loop
├── RECORDING-WORKFLOW.md      # Per-module recording loop (snapshot/restore, on-rails demos)
│
├── Start-CkaLab.ps1           # Entry point: boot all 3 VMs (no re-provision)
├── Stop-CkaLab.ps1            # Entry point: graceful halt of all 3 VMs
├── Get-CkaLabStatus.ps1       # Read-only: report Hyper-V VM state, optional teardown prompt
├── Get-CkaConnectionInfo.ps1  # Connection table with live UP/DOWN status
├── Test-CkaLabReady.ps1       # Health check across all 3 VMs via stdin pipe
├── Save-CkaSnapshot.ps1       # Hyper-V checkpoint: save all 3 VMs (atomic)
├── Restore-CkaSnapshot.ps1    # Hyper-V checkpoint: restore all 3 VMs (atomic)
├── Remove-CkaSnapshot.ps1     # Inventory/prune checkpoint cruft
│
├── Build-M02UpgradeLab.ps1    # Rebuild the 3 VMs clean at v1.34, auto-snapshot for the M02 upgrade demo
├── Invoke-M02Upgrade.ps1      # On-rails M02 demo: v1.34 -> v1.35 upgrade, phase by phase
├── Invoke-M03Lab.ps1          # On-rails M03 demo: Helm, Kustomize, CRDs, phase by phase
├── Invoke-KubeletFlagRepair.ps1  # On-rails repair demo for a stale kubelet flag
│
├── lib/
│   ├── CkaLab.ps1             # Shared module (output helpers, lab topology, UTF-8/PATH setup, host info)
│   └── validate-node.sh       # Node-level health checks (piped over stdin)
│
├── Vagrantfile                # 3-VM Hyper-V cluster (control1/worker1/worker2)
├── bootstrap_cp.sh            # kubeadm init for Vagrant control plane
├── join_worker.sh             # Self-sufficient worker join (fetches fresh token)
├── join_worker.sh.template    # Legacy template (preserved)
├── create-nat-switch.ps1      # Creates CKA-NAT switch with preflight checks
│
├── archive/                   # Stale scripts (legacy multi-action snapshot.ps1)
└── docs/                      # Architecture diagrams
```

## Architecture

### Shared Module: `lib/CkaLab.ps1`

Every entry point dot-sources this file. It provides:

- **Output helpers**: `Write-Step`, `Write-Success`, `Write-Info`, `Write-Warn`, `Write-ErrorMsg` -- every line is labeled (`[OK]`/`[INFO]`/`[WARN]`/`[ERROR]`) on the Wong colorblind-safe palette, so meaning never depends on color alone
- **Lab topology (single source of truth)**: `Get-CkaLabNodes` (Name+IP objects) and `Get-CkaLabVMs` (names only) -- the ONE definition of `control1`/`worker1`/`worker2`. Every wrapper pulls the node list from here; do not hardcode the three names again
- **Environment**: `Initialize-LabEncoding` (forces UTF-8 console/pipeline so vagrant/ssh/kubectl output doesn't garble on the default Windows code page), `Initialize-LabPath` (PATH refresh for winget/Vagrant/System32; uses a HashSet-based dedup so repeat dot-sources don't stack duplicate segments)
- **Host info**: `Get-HostMemoryInfo`, `Write-HostMemory`

There is no `$Script:CkaLabRoot`. Scripts use `$PSScriptRoot` or `Join-Path $PSScriptRoot ...` directly.

All entry-point scripts live flat at the repo root (`src/cka-lab/`) -- there is no course-specific subfolder duplicating the engine. If a course needs a specialized demo (e.g. the Module 2 upgrade walkthrough), it's a new `Invoke-*.ps1` at the root, not a copy of the whole engine.

### Vagrant / Hyper-V Path

`Vagrantfile` provisions 3 Ubuntu 24.04 LTS VMs (control1, worker1, worker2) on a dedicated NAT switch (`CKA-NAT`, 192.168.50.0/24) with static IPs. Key design points to preserve:

- **Static networking uses a host-side Windows OpenSSH watcher**: `CKA-NAT` has no DHCP service, but Hyper-V reports each guest's IPv6 link-local address. A before-up trigger starts `bootstrap-static-network.ps1`, which waits for that address, writes persistent netplan configuration, and reboots the guest. Vagrant then connects over static IPv4. This avoids the embedded Ruby socket's unreliable handling of scoped IPv6 on Windows.
- **Interface matching uses the guest MAC address**: the bootstrap watcher detects the first non-loopback interface, then writes a netplan match using its MAC address. This avoids depending on whether Ubuntu names it `eth0` or `enp*`.
- **`auto_config: false` in Vagrant**: Vagrant's generic public-network configuration is disabled; the explicit netplan provisioner is authoritative.
- **Pinned K8s packages**: `kubelet/kubeadm/kubectl` are installed at exactly `1.35.0-1.1` and then `apt-mark hold`'d. Version drift would invalidate exam-parity. The version is **parameterized** via host env vars `CKA_K8S_MINOR` / `CKA_K8S_PKG_VERSION` (defaults `1.35` / `1.35.0-1.1`); set them before `vagrant up` to build the **v1.34** cluster for the Module 2 upgrade demo. Unset, the defaults reproduce the current lab byte-for-byte.
- **No password logging**: the `vagrant` user's password is set via a method that doesn't echo to `/var/log/cka-provision.log`.
- **`bootstrap_cp.sh` hardening**: `set -euo pipefail`; Calico pinned to `v3.29.1`, installed via the Tigera operator on pod CIDR `192.168.0.0/16` to match C02 M03 and every recorded module since; a comment block at the top documents how to swap in another CNI.

`join_worker.sh` is **self-sufficient** -- it SSHes to control1 at 192.168.50.10, pulls a fresh `kubeadm token create --print-join-command`, and runs the join locally. The old static template is preserved at `join_worker.sh.template` for comparison.

`create-nat-switch.ps1` uses exact-match (`Get-NetAdapter -Name "vEthernet ($SwitchName)"`) instead of `-like` to avoid matching `vEthernet (WSL)` or other lookalikes, and preflights for a /24 collision on 192.168.50.0/24 before touching Hyper-V.

### Snapshot / Restore Atomicity

`Save-CkaSnapshot.ps1` and `Restore-CkaSnapshot.ps1` are **all-or-nothing**. Both scripts preflight *every* target VM (and, for restore, every named checkpoint) before making a single change. If one VM is missing or one checkpoint doesn't exist, neither script writes anything -- both fail closed with a per-VM summary of what was found vs. expected. This prevents half-restored clusters where control1 is at `pre-cluster` but worker1 is current.

### Recording-Specific Controls

`Build-M02UpgradeLab.ps1`, `Invoke-M02Upgrade.ps1`, `Invoke-M03Lab.ps1`, and `Invoke-KubeletFlagRepair.ps1` are on-rails demo scripts written for recording sessions, not generic lab plumbing. Invariants to preserve:

- **Recording loop**: `Save-CkaSnapshot <name>` before a take, `Restore-CkaSnapshot <name>` to re-record. M02 builds at v1.34 (env vars above), upgrades to v1.35 on camera -- which is exactly M03's starting state.
- **`Invoke-M03Lab.ps1` pushes exercise-files, not a synced folder**: it resolves `..\..\exercise-files\course-03-lifecycle-upgrades\m03-helm-kustomize-crds` relative to `$PSScriptRoot` (repo root is two levels up from `src/cka-lab`) and copies that tree onto the node over the same stdin->ssh path the validator uses. One source of truth, no Vagrant synced-folder dependency.
- **`Build-M02UpgradeLab.ps1 -ExportBaseline`**: exports the current v1.35 checkpoint to disk BEFORE `vagrant destroy`, since destroy removes the VMs and all their checkpoints. Without this flag, a v1.34 rebuild would permanently lose the v1.35 baseline that M01 re-records and M03 both depend on.
- Human workflow: [`RECORDING-WORKFLOW.md`](RECORDING-WORKFLOW.md).

### Validator: `Test-CkaLabReady.ps1` + `lib/validate-node.sh`

`Test-CkaLabReady.ps1` SSHes into each VM and runs the node-level health checks in `lib/validate-node.sh`. The script is **piped over stdin**:

```powershell
Get-Content -Raw $ScriptPath | vagrant ssh $vm -c "bash -s"
```

This matters because `vagrant ssh -c "<long inlined script>"` has argv-length limits and causes `$LASTEXITCODE` to reflect only the outer `vagrant` process -- the inner script could fail silently. Stdin delivery propagates the inner bash exit correctly. After all three nodes run, the PowerShell wrapper prints an aggregate PASS/WARN/FAIL summary.

## Safety Headers

- All Hyper-V PowerShell scripts carry `#Requires -RunAsAdministrator`. Hyper-V cmdlets fail confusingly without elevation; this fails clearly.
- `Get-CkaConnectionInfo.ps1` carries `#Requires -Version 7.0` (uses PS7 formatting/operators).

## Naming Conventions

Node names are deterministic and single-sourced in `lib/CkaLab.ps1` (`Get-CkaLabVMs` / `Get-CkaLabNodes`): **`control1` / `worker1` / `worker2`**, with static IPs `192.168.50.10` / `.11` / `.12`. If a node is ever renamed or added, change it in `lib/CkaLab.ps1` and nowhere else.

Every entry-point script uses PowerShell **Verb-Noun** naming (`Start-CkaLab.ps1`, `Save-CkaSnapshot.ps1`, `Invoke-M02Upgrade.ps1`) so the script's action is legible without opening it. This is a deliberate muscle-memory convention -- don't introduce a differently-shaped name (e.g. `cka-up.ps1`) for a new entry point.

## Platform Notes

- PowerShell scripts require PS 7.0+
- Kubernetes version target: v1.35
- `.gitignore` excludes `*.deb`, `*.zip`, `temp/`, `.vagrant/`
- `bootstrap_cp.sh` auto-detects the CP IP via `hostname -I` (DHCP-compatible)
- Vagrant VMs: 2 vCPUs / 2 GiB RAM each; storage uses the base box's primary virtual disk, static IPs on `CKA-NAT`, checkpoints enabled
