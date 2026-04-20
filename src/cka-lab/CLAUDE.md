# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Scope of This File

When users want to **DO** things (run a cluster, drive a tutorial, practice the exam loop), point them at `TUTORIAL-KIND.md` (Docker-based path) or `TUTORIAL-HYPERV.md` (VM-based path). When users want to **UNDERSTAND or MODIFY** the code, this CLAUDE.md is the entry point -- it explains architecture, invariants, and the patterns you must preserve when editing.

## What This Is

CKA (Certified Kubernetes Administrator) lab environment for Tim Warner's Pluralsight training content. Two deployment paths for multi-node Kubernetes clusters:

1. **KIND (Kubernetes in Docker)** -- Primary, fast-iteration path. PowerShell scripts with interactive menus. K8s nodes run as Docker containers on Windows/WSL2.
2. **Vagrant + Hyper-V** -- Exam-shaped path. Ubuntu 22.04 VMs with real kubeadm v1.35, systemd, apt, and a snapshot-and-rollback practice loop.

## Repository Layout

```
cka-lab/
├── README.md                  # Landing page for both paths
├── CLAUDE.md                  # This file -- code/architecture guidance
├── TUTORIAL-KIND.md           # Hands-on KIND walkthrough
├── TUTORIAL-HYPERV.md         # Hands-on Hyper-V walkthrough + practice loop
│
├── kind-up.ps1                # Entry point: create KIND cluster
├── kind-down.ps1              # Entry point: destroy KIND cluster
├── Start-Tutorial.ps1         # Run tutorials against a running cluster
│
├── lib/
│   ├── CkaLab.ps1             # Shared module (helpers, Docker mgmt, prereqs)
│   ├── tutorials.ps1          # Tutorial functions (dot-sourced by CkaLab.ps1)
│   └── validate-node.sh       # Node-level health checks (piped over stdin)
│
├── configs/
│   ├── cka-simple.yaml        # 1 CP + 1 worker
│   ├── cka-3node.yaml         # 1 CP + 2 workers (CKA exam topology)
│   ├── cka-ha.yaml            # 3 CP + 2 workers (extraPortMappings on worker)
│   └── cka-workloads.yaml     # 1 CP + 3 workers (scheduling, affinity)
│
├── Vagrantfile                # 3-VM Hyper-V cluster (control1/worker1/worker2)
├── bootstrap_cp.sh            # kubeadm init for Vagrant control plane
├── join_worker.sh             # Self-sufficient worker join (fetches fresh token)
├── join_worker.sh.template    # Legacy template (preserved)
├── create-nat-switch.ps1      # Creates CKA-NAT switch with preflight checks
├── cka-snapshot.ps1           # Hyper-V checkpoint: save all 3 VMs (atomic)
├── cka-restore.ps1            # Hyper-V checkpoint: restore all 3 VMs (atomic)
├── cka-validate.ps1           # Health check across all 3 VMs via stdin pipe
├── cka-up.ps1 / cka-down.ps1  # Boot / shutdown all VMs
├── cka-info.ps1               # Connection table with live UP/DOWN status
│
├── archive/                   # Stale scripts (kind-*.sh, old snapshot.ps1)
└── docs/                      # Architecture diagrams
```

## Architecture

### KIND Path

`kind-up.ps1` and `kind-down.ps1` dot-source `lib/CkaLab.ps1` at the top, then present interactive menus (topology choice, optional tutorial, shutdown scope). `Start-Tutorial.ps1` is the standalone tutorial runner -- it dot-sources `lib/CkaLab.ps1` and calls `Test-ClusterExists` before driving tutorials against an already-running cluster.

Key invariants you must preserve when editing `kind-up.ps1`:

- **NodePort preflight**: before `kind create cluster`, the script checks host ports 30000/30080/30443 with `Get-NetTCPConnection` and warns (with process name) on conflicts. `-Force` bypasses the prompt for non-interactive CI/teaching runs.
- **Topology-aware `--wait`**: the `--wait` timeout is chosen from the config leaf name -- `cka-ha.yaml` -> 300s (etcd quorum negotiation across 3 CPs), `cka-workloads.yaml` -> 180s (label/taint follow-up), everything else -> 120s. Cold image caches need this headroom.
- **`Invoke-KubectlWithRetry` helper**: post-creation `kubectl label` / `kubectl taint` calls can race the API server briefly returning 404 on node names. The helper retries 3x with 2s backoff. Any new post-create kubectl plumbing should route through it rather than calling kubectl directly.
- **Filtered `docker stats`**: the resource-usage summary filters to cluster containers only so unrelated dev containers don't pollute the output.

### HA Port-Mapping Design

`configs/cka-ha.yaml` puts `extraPortMappings` on a **worker** node, not a control plane. Rationale: HA failover demos kill a control plane; if host ports are bound to CP #1, the demo breaks the ingress path along with the CP. Putting the mappings on a worker keeps 30000/30080/30443 reachable through any CP failure. Do not move them back to the control plane.

### Shared Module: `lib/CkaLab.ps1`

All entry points dot-source this file. It provides:

- **Output helpers**: `Write-Step`, `Write-Success`, `Write-Info`, `Write-ErrorMsg`
- **Environment**: `Initialize-LabPath` (PATH refresh for winget/Docker/System32; uses a HashSet-based dedup so repeat dot-sources don't stack duplicate segments)
- **Docker management**: `Test-DockerReady`, `Start-DockerDesktop`, `Wait-DockerReady`, `Stop-DockerDesktop`. `Wait-DockerReady` **throws** on timeout (rather than `exit 1`) so callers can try/catch around Docker startup.
- **Prerequisites**: `Test-Prerequisites` (docker, kind, kubectl checks)
- **KIND ops**: `Get-KindClusters`, `Test-ClusterExists`
- **Host info**: `Get-HostMemoryInfo`, `Write-HostMemory`
- **Tutorials**: auto-sources `lib/tutorials.ps1` at the bottom

There is no `$Script:CkaLabRoot`. Earlier revisions exposed one; it's been removed as dead state. Scripts use `$PSScriptRoot` or `Join-Path $PSScriptRoot ...` directly.

### Tutorial System

`lib/tutorials.ps1` contains four tutorial functions:

- `Start-ComponentWalkthrough` -- 12-step verification of all K8s components
- `Start-TutorialM01` -- Course 1 Module 1: architecture & lab setup (10 steps)
- `Start-TutorialM02` -- Course 1 Module 2: kubectl workflows (16 steps)
- `Start-TutorialM03` -- Course 1 Module 3: core resources & diagnostics (18 steps)

All 57 steps are rendered through `Write-TutorialSection`, which accepts five content params:

- `-Title` -- section header (e.g. `"2/16  IMPERATIVE: CREATE A DEPLOYMENT"`)
- `-Explanation` -- the "why" shown before the command runs
- `-Command` -- the literal string passed to `Invoke-Expression`
- `-CommandBreakdown` -- pre-run flag-by-flag dissection, one line per token (`flag = what it does`)
- `-OutputFields` -- post-run column/field explainer for the output the learner just saw

`-CommandBreakdown` and `-OutputFields` are optional but populated on every step. If you add a new section, fill both -- the enrichment is uniform across all 57 calls and the helper is the only place that renders them.

Invariants the tutorial code relies on (do not regress these):

- **`try/finally` with `--ignore-not-found`**: every tutorial that creates cluster objects wraps its body in `try { ... } finally { kubectl delete ... --ignore-not-found }`. This survives Ctrl-C mid-tutorial and leaves the cluster clean for the next run.
- **No TTY dependency**: `kubectl run -it` is banned. All interactive pod runs use `--restart=Never --attach --rm` so tutorials work over SSH, in CI, and inside recording sessions where a TTY isn't guaranteed.
- **Topology-agnostic narration**: tutorial copy never hard-codes node counts. Functions query `kubectl get nodes --no-headers | Measure-Object` into `$nodeCount` and interpolate that into output. A tutorial should read correctly against 2, 3, 4, or 5 nodes.
- **Word-boundary regex**: tutorial output matchers use `\broles?\b`, `\brolebindings?\b`, `\bconfigmap\w*` so that `rolebinding` doesn't match `role` and `configmaps` matches `configmap`.
- **Breakdown + OutputFields parity**: when adding or editing a section, both `-CommandBreakdown` and `-OutputFields` must stay in sync with the command. Silent drift (command changed, breakdown not updated) is the top regression risk here.

Tutorials use deterministic names for all commands:

- Bare pods created by `kubectl run` use the exact name given (e.g., `broken`, `standalone`)
- Deployment pod names are queried at runtime via jsonpath (never hardcoded)
- Service names use `--name=` flag for determinism
- System pods follow static naming: `etcd-{cluster}-control-plane`

### Vagrant / Hyper-V Path

`Vagrantfile` provisions 3 Ubuntu 22.04 VMs (control1, worker1, worker2) on a dedicated NAT switch (`CKA-NAT`, 192.168.50.0/24) with static IPs. Key design points to preserve:

- **Interface picker in provisioning**: the script prefers `eth0` and explicitly excludes `docker*`, `cni*`, `veth*`, `virbr*`, `br-*`, `flannel*`, `cali*`. Previously a naive "first non-loopback" pick could grab a cluster-internal interface after a previous test run.
- **`netplan try --timeout 30`**: netplan is applied with auto-revert so a misconfig that breaks SSH rolls back automatically instead of bricking the VM.
- **`auto_config: false` in Vagrant**: Vagrant is not allowed to touch the interface -- netplan is authoritative. This prevents Vagrant's `ifdown`/`ifup` dance from fighting cloud-init.
- **Pinned K8s packages**: `kubelet/kubeadm/kubectl` are installed at exactly `1.35.0-1.1` and then `apt-mark hold`'d. Version drift would invalidate exam-parity.
- **No password logging**: the `vagrant` user's password is set via a method that doesn't echo to `/var/log/cka-provision.log`.
- **`bootstrap_cp.sh` hardening**: `set -euo pipefail`; Flannel pinned to `v0.24.4`; a comment block at the top documents how to swap Cilium or Calico in place of Flannel.

`join_worker.sh` is **self-sufficient** -- it SSHes to control1 at 192.168.50.10, pulls a fresh `kubeadm token create --print-join-command`, and runs the join locally. The old static template is preserved at `join_worker.sh.template` for comparison.

`create-nat-switch.ps1` uses exact-match (`Get-NetAdapter -Name "vEthernet ($SwitchName)"`) instead of `-like` to avoid matching `vEthernet (WSL)` or other lookalikes, and preflights for a /24 collision on 192.168.50.0/24 before touching Hyper-V.

### Snapshot / Restore Atomicity

`cka-snapshot.ps1` and `cka-restore.ps1` are **all-or-nothing**. Both scripts preflight *every* target VM (and, for restore, every named checkpoint) before making a single change. If one VM is missing or one checkpoint doesn't exist, neither script writes anything -- both fail closed with a per-VM summary of what was found vs. expected. This prevents half-restored clusters where control1 is at `pre-cluster` but worker1 is current.

### Validator: `cka-validate.ps1` + `lib/validate-node.sh`

`cka-validate.ps1` SSHes into each VM and runs the node-level health checks in `lib/validate-node.sh`. The script is **piped over stdin**:

```powershell
Get-Content -Raw $ScriptPath | vagrant ssh $vm -c "bash -s"
```

This matters because `vagrant ssh -c "<long inlined script>"` has argv-length limits and causes `$LASTEXITCODE` to reflect only the outer `vagrant` process -- the inner script could fail silently. Stdin delivery propagates the inner bash exit correctly. After all three nodes run, the PowerShell wrapper prints an aggregate PASS/WARN/FAIL summary.

## Safety Headers

- All Hyper-V PowerShell scripts carry `#Requires -RunAsAdministrator`. Hyper-V cmdlets fail confusingly without elevation; this fails clearly.
- `cka-info.ps1` carries `#Requires -Version 7.0` (uses PS7 formatting/operators).
- KIND scripts carry `#Requires -Version 7.0`.

## Naming Conventions

KIND cluster name defaults to `cka-lab` (set by `--name` CLI flag, not YAML). Node names are deterministic:

- `cka-lab-control-plane`, `cka-lab-control-plane2`, `cka-lab-control-plane3` (HA)
- `cka-lab-worker`, `cka-lab-worker2`, `cka-lab-worker3`

Tutorials rely on this deterministic naming for all kubectl commands.

## Cluster Configs

All configs are KIND `v1alpha4`. Name is set by CLI `--name`, not in YAML.

| Config | Nodes | CKA Topics |
|--------|-------|------------|
| `configs/cka-simple.yaml` | 1 CP + 1 worker | Quick practice |
| `configs/cka-3node.yaml` | 1 CP + 2 workers | CKA exam topology |
| `configs/cka-ha.yaml` | 3 CP + 2 workers | etcd quorum, HA (port maps on worker) |
| `configs/cka-workloads.yaml` | 1 CP + 3 workers | Scheduling, affinity, taints, DaemonSets |

All configs include: PodSecurity + NodeRestriction admission plugins, NodePort mappings (30000, 30080, 30443), containerd runtime. The workloads topology auto-applies node labels (`zone=east/west`, `tier=frontend/backend`) and a taint (`dedicated=special:NoSchedule` on worker3) after creation -- via `Invoke-KubectlWithRetry`.

## Platform Notes

- PowerShell scripts require PS 7.0+
- Kubernetes version target: v1.35
- Stale Bash scripts (old `kind-up.sh`, `kind-down.sh`) live in `archive/`; legacy `snapshot.ps1` was also moved there with a note explaining the split into `cka-snapshot.ps1`/`cka-restore.ps1`
- `.gitignore` excludes `*.deb`, `*.zip`, `temp/`, `.vagrant/`
- `bootstrap_cp.sh` auto-detects the CP IP via `hostname -I` (DHCP-compatible)
- Vagrant VMs: 2 CPU / 2 GB RAM each, static IPs on `CKA-NAT`, checkpoints enabled
