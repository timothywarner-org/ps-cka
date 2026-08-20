# CLAUDE.md — src/cka-lab-macos

Architecture and invariants for the macOS / VMware Fusion CKA lab. Read this before modifying any file in this directory.

## What this is

macOS twin of `../cka-lab/` (Windows / Hyper-V / PowerShell). Same 3-node kubeadm cluster
(control1/worker1/worker2, 192.168.50.0/24, Kubernetes v1.35), different hypervisor
(VMware Fusion via `vmware_desktop` Vagrant provider) and different control language (zsh).

## Repository layout

```
cka-lab-macos/
├── cka-lab.sh           # Single dispatcher (start/stop/status/info/validate/save/restore/snapshots)
├── Vagrantfile          # 3-VM VMware Fusion cluster
├── bootstrap_cp.sh      # kubeadm init on control1 (run manually inside the VM)
├── join_worker.sh       # Worker join on worker1/worker2 (run manually inside each VM)
├── lib/
│   ├── common.sh        # Shared helpers (colors, topology, vagrant state)
│   └── validate-node.sh # Node-level prereq checks (piped via stdin)
├── CLAUDE.md            # This file
├── README.md            # Learner quickstart
├── TUTORIAL-VMWARE.md   # Hands-on walkthrough (sections A-K)
├── .gitignore
└── docs/
    ├── vagrant-commands.txt
    └── vim-cheatsheet.md
```

## Key design decisions

### One dispatcher, not many scripts

The Windows path has ~7 separate `.ps1` entry points. The macOS path collapses these into
a single `cka-lab.sh` dispatcher with subcommands (per working-agreement rule 6).
Bare invocation = `status` (read-only, safe default). `-h/--help` prints the table.

### lib/common.sh is the single source of topology

`CKA_NODES=("control1:192.168.50.10" ...)` in `lib/common.sh` is the ONE place node names
and IPs are defined. Every subcommand reads it. If you rename a node or add one, change it
here and nowhere else — mirrors `Get-CkaLabNodes`/`Get-CkaLabVMs` in `../cka-lab/lib/CkaLab.ps1`.

### Provider differences vs. the Windows path

| Concern | Windows (Hyper-V) | macOS (VMware Fusion) |
|---------|------------------|----------------------|
| NAT switch | `create-nat-switch.ps1` (manual, elevated) | Automatic (vmnet managed by VMware) |
| Static IPs | Custom netplan provisioner in Vagrantfile | `private_network, ip:` (Vagrant guest capability) |
| Snapshots | `Checkpoint-VM`, `Restore-VMCheckpoint` | `vagrant snapshot save/restore` |
| Admin elevation | `#Requires -RunAsAdministrator` | Not required |
| Network name | `CKA-NAT` Hyper-V switch | VMware vmnet (auto-assigned) |

### Snapshot atomicity (preserved from the Windows path)

`save` and `restore` subcommands are **all-or-nothing**:
- `save`: preflights that all 3 VMs exist before snapshotting any of them.
- `restore`: preflights that all 3 VMs have the named snapshot before restoring any of them.
If a preflight fails, the subcommand exits without touching anything and reports which VM
and which check failed. A half-snapshotted or half-restored cluster is worse than a clean error.

### Validate stdin delivery (preserved)

`cka-lab.sh validate` delivers `lib/validate-node.sh` via stdin:
```zsh
vagrant ssh "${vm}" -c 'bash -s' < "${SCRIPT_DIR}/lib/validate-node.sh"
```
This matches the PowerShell original. Stdin delivery matters because:
1. It avoids argv-length limits that would truncate a long inlined script.
2. The inner bash exit code (`exit $FAIL`) propagates correctly to the calling shell.
   `vagrant ssh -c` returns the outer vagrant process exit code only if stdin is not used;
   with stdin + `bash -s`, the inner exit flows through.

### bootstrap_cp.sh: eth1 for the API server advertise address

With VMware `private_network`, the NAT interface is `eth0` and the lab network is `eth1`.
`bootstrap_cp.sh` detects `eth1`'s IP (`192.168.50.10`) and passes it to
`--apiserver-advertise-address`. This ensures workers reach the API server on the lab
network, not on the ephemeral NAT address. The Windows version used `hostname -I | awk '{print $1}'`
(first IP, which was the static one on Hyper-V bridged adapters); on VMware the first IP
is the NAT one, so detection logic is explicitly interface-name-based here.

### STALE: bootstrap_cp.sh uses Flannel, not Calico

`bootstrap_cp.sh` ships Flannel v0.24.4 (`10.244.0.0/16`). The shipped lab environment
for Courses 2+ uses Calico v3.29.1 via the Tigera operator (`192.168.0.0/16`). The file
documents both options in its comment block. Do not assume Flannel is authoritative for
Course 2+ content — the runbooks specify which CNI to install.

## Invariants to preserve when editing

- **Topology single-source**: only `lib/common.sh` `CKA_NODES` may define node names and IPs.
- **Atomicity in save/restore**: both subcommands must remain all-or-nothing with per-VM
  found-vs-expected preflight output.
- **Stdin delivery for validate**: never inline the validate script as a `vagrant ssh -c` arg.
- **No color-only meaning**: all output helpers include a text label (`[OK]/[INFO]/[WARN]/[ERROR]`)
  alongside color, so the output is readable in a no-color terminal or in a log file.
- **Idempotent provisioner**: `./cka-lab.sh up` can be run multiple times safely —
  Vagrant's idempotency + the provisioner's guards (`if ! grep -q 'alias k=kubectl'`) ensure it.
- **chmod +x on all .sh files**: `bootstrap_cp.sh`, `join_worker.sh`, `cka-lab.sh`, and
  `lib/validate-node.sh` all carry a shebang on line 1. Verify byte 0 is `#` before pushing;
  a BOM prefix silently breaks the shebang on Linux.

## What was intentionally NOT ported (scope: core lifecycle only)

- `create-nat-switch.ps1`, `Repair-CkaNatSwitch.ps1` — no VMware equivalent needed.
- `Initialize-C04M01Lab.ps1` / `Initialize-C04M02Lab.ps1` — Course 4 demo scripts, deferred.
- `Build-M02UpgradeLab.ps1`, `Invoke-M02Upgrade.ps1` — Module 2 upgrade demo, deferred.
- `Invoke-M03Lab.ps1` — Module 3 Helm/Kustomize/CRD demo, deferred.
- `Invoke-KubeletFlagRepair.ps1` — Module-specific break/fix demo, deferred.
- `Remove-CkaSnapshot.ps1` — can become `./cka-lab.sh snapshots --prune` in a later pass.
- KIND path — macOS users who want KIND can use the Windows scripts under `../cka-lab/`
  (they run on macOS with `pwsh` or under Docker Desktop).
- `lib/tutorials.ps1`, `Start-Tutorial.ps1` — KIND/interactive tutorial system; no equivalent
  planned for the Vagrant path.

## Runtime environment constraint

This authoring sandbox cannot test against VMware Fusion or Vagrant — both are absent and
network access to `dl.k8s.io` / container registries is blocked. All code is verified by
static parse check only (`zsh -n`, `bash -n`, `ruby -c`). Full runtime verification is Tim's
on a Mac with VMware Fusion 13+.
