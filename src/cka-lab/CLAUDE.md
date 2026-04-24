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
├── kind-multi-up.ps1          # Entry point: create cka-dev + cka-prod back-to-back
├── kind-multi-down.ps1        # Entry point: destroy both clusters (-ClearRenamed removes dev/prod contexts)
├── Start-ContextPractice.ps1  # 8-drill kubectl context walkthrough (Ctrl-C safe)
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
│   ├── cka-workloads.yaml     # 1 CP + 3 workers (scheduling, affinity)
│   ├── cka-dev.yaml           # 1 CP + 1 worker, host ports 30100/30180 (multi-cluster lab)
│   └── cka-prod.yaml          # 1 CP + 2 workers, host ports 30200/30280 (multi-cluster lab)
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

### Multi-Cluster Context Lab

A second KIND subsystem that stands up **two** clusters (`cka-dev` and `cka-prod`) side by side so the learner can drill `kubectl config` context management -- a CKA Troubleshooting/Cluster Architecture topic that is hard to practice against a single cluster. Entry points:

- [kind-multi-up.ps1](kind-multi-up.ps1) -- creates both clusters, preflights ports, optionally chains into the practice runner with `-Practice`
- [kind-multi-down.ps1](kind-multi-down.ps1) -- tears both clusters down; `-ClearRenamed` also removes `dev`/`prod` contexts if the learner renamed them
- [Start-ContextPractice.ps1](Start-ContextPractice.ps1) -- 8-drill walkthrough: list, current, switch-and-prove, `--context` one-shot, rename, per-context default namespace, `config view --minify`, restore

Invariants you must preserve when editing any of the three:

- **Disjoint host port ranges per cluster**: `cka-dev` owns 30100/30180, `cka-prod` owns 30200/30280. `kind create cluster` allocates ALL `extraPortMappings` at create time; a collision on either set kills the second cluster mid-flight. Do not reuse 30000/30080/30443 here -- those belong to the single-cluster configs and would collide if a learner forgot to `kind-down` first.
- **Distinct topologies (2 vs 3 nodes)**: `cka-dev` is 1+1, `cka-prod` is 1+2. The asymmetry is intentional -- `kubectl get nodes` looks visibly different after every switch, so the learner self-confirms the context change with no extra command.
- **Cross-platform port preflight**: probe via `[System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)` + bind-then-stop. Do NOT use `Get-NetTCPConnection` -- it's Windows-only and silently no-ops under pwsh-in-WSL2, defeating the preflight.
- **Fail-fast cluster creation**: if the first `kind create cluster` fails, exit BEFORE attempting the second. A half-built multi-cluster state is worse than a clean failure -- the learner would get a working dev with no prod and still hit 30200 collisions on retry.
- **Single `$clusters` pscustomobject array**: both cluster definitions (name, config path, port list) live in one array in `kind-multi-up.ps1`. Adding a third cluster later should be a one-line change to that array, not a structural edit.
- **Idempotent create**: `Test-ClusterExists` gates each `kind create` call. Re-running `./kind-multi-up.ps1` against an already-running pair is a no-op, not a failure. This matches the ergonomics of the single-cluster `kind-up.ps1`.
- **Context rename cleanup**: `kind-multi-down.ps1 -ClearRenamed` runs `kubectl config delete-context dev` and `... prod` with errors suppressed. The practice runner teaches `rename-context`, so teardown must be able to unwind that state without noisy second-run errors.
- **Practice runner Ctrl-C safety**: `Start-ContextPractice.ps1` captures `$startContext` at the top, wraps the drill body in `try { ... } finally { kubectl config use-context $startContext }`. The learner is guaranteed to land back on whatever context they launched from, even on Ctrl-C mid-drill. Same pattern as the tutorial system's cluster-object cleanup.
- **Shared-module reuse**: all three scripts dot-source [lib/CkaLab.ps1](lib/CkaLab.ps1) and call `Initialize-LabEncoding`, `Initialize-LabPath`, `Wait-DockerReady`, `Test-Prerequisites`, `Test-ClusterExists`, `Get-KindClusters`. Do not duplicate those helpers into multi-cluster-specific copies -- any fix to the shared module must benefit both subsystems.
- **Shebang + exec bit**: line 1 of all three scripts is `#!/usr/bin/env pwsh` and the POSIX exec bit is set. This lets `./kind-multi-up.ps1` run from bash under WSL2. The shebang is a comment to pwsh on Windows, so it's transparent to Windows Terminal / PowerShell ISE usage -- keep it on line 1.

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

| Config | Nodes | Host Ports | CKA Topics |
| --- | --- | --- | --- |
| `configs/cka-simple.yaml` | 1 CP + 1 worker | 30000/30080/30443 | Quick practice |
| `configs/cka-3node.yaml` | 1 CP + 2 workers | 30000/30080/30443 | CKA exam topology |
| `configs/cka-ha.yaml` | 3 CP + 2 workers | 30000/30080/30443 | etcd quorum, HA (port maps on worker) |
| `configs/cka-workloads.yaml` | 1 CP + 3 workers | 30000/30080/30443 | Scheduling, affinity, taints, DaemonSets |
| `configs/cka-dev.yaml` | 1 CP + 1 worker | 30100/30180 | Multi-cluster context lab (dev side) |
| `configs/cka-prod.yaml` | 1 CP + 2 workers | 30200/30280 | Multi-cluster context lab (prod side) |

The single-cluster configs (`cka-simple`, `cka-3node`, `cka-ha`, `cka-workloads`) include: PodSecurity + NodeRestriction admission plugins, NodePort mappings (30000, 30080, 30443), containerd runtime. The workloads topology auto-applies node labels (`zone=east/west`, `tier=frontend/backend`) and a taint (`dedicated=special:NoSchedule` on worker3) after creation -- via `Invoke-KubectlWithRetry`.

The multi-cluster configs (`cka-dev`, `cka-prod`) use disjoint host port ranges so both clusters can coexist on one host -- see the Multi-Cluster Context Lab section for why this is non-negotiable.

## Platform Notes

- PowerShell scripts require PS 7.0+
- Kubernetes version target: v1.35
- Stale Bash scripts (old `kind-up.sh`, `kind-down.sh`) live in `archive/`; legacy `snapshot.ps1` was also moved there with a note explaining the split into `cka-snapshot.ps1`/`cka-restore.ps1`
- `.gitignore` excludes `*.deb`, `*.zip`, `temp/`, `.vagrant/`
- `bootstrap_cp.sh` auto-detects the CP IP via `hostname -I` (DHCP-compatible)
- Vagrant VMs: 2 CPU / 2 GB RAM each, static IPs on `CKA-NAT`, checkpoints enabled
