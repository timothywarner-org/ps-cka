# 🧪 CKA Lab — Two Ways to Practice

> *The CKA exam doesn't care how you got here. It only cares whether `kubeadm init`
> is muscle memory and whether you can debug a crashlooping pod before the timer beeps.*

Two paths, same destination: pass the exam on the first try. Pick based on how much
time you have and how close to the real thing you want the lab to feel.

> **Cross-platform note:** every PS7 script in this folder carries a `#!/usr/bin/env pwsh`
> shebang and the executable bit, so you can invoke them as `./kind-up.ps1` from bash
> inside WSL2 *or* from pwsh in Windows Terminal. Pick whichever shell you already have open.

---

## 🍝 Pick Your Poison

| | **KIND (Docker)** | **Hyper-V + Vagrant (VMs)** |
|---|---|---|
| **Up time** | ~60-90 seconds | ~10-15 minutes (first run) |
| **Reset time** | `kind-down` + `kind-up` (~90s) | `cka-restore.ps1` (~30s) |
| **Fidelity** | Pods, Services, CNI, kubectl — all real | Real systemd, kubelet, containerd, kubeadm |
| **Teaches `kubeadm init`?** | No (KIND wraps it) | Yes — you run it |
| **Teaches CNI install?** | No (kindnet pre-wired) | Yes — pick Flannel / Cilium / Calico |
| **RAM cost** | ~2 GB | ~6 GB (3x 2GB VMs) |
| **Prereqs** | Docker Desktop, KIND, kubectl | Hyper-V (Win Pro/Ent), Vagrant |
| **Best for** | Workloads, RBAC, Services, storage drills | Cluster bootstrap, HA, bare-metal feel |
| **Exam overlap** | ~60% of objectives | ~95% of objectives |

**TL;DR:** Use **KIND** for the 80% of objectives that don't care how the cluster was built.
Use **Hyper-V** for the 20% that do — and for the exam-shaped dress rehearsals a week before test day.

---

## 🚀 Quickstart

### Path A — KIND (single cluster)

```powershell
cd src/cka-lab
./kind-up.ps1                 # menu: pick topology, optional tutorial
# ... drill ...
./kind-down.ps1               # menu: cluster-only or full shutdown
```

Deep dive and guided walkthrough: **[TUTORIAL-KIND.md](TUTORIAL-KIND.md)**

### Path A.2 — KIND (two clusters, kubectl context practice)

Context-switching is worth ~5% of the CKA and shows up in nearly every task. This lab
spins up **two** KIND clusters side-by-side (`cka-dev`: 1 CP + 1 worker, `cka-prod`:
1 CP + 2 workers) on disjoint host ports so they don't collide, then drops you into an
8-drill walkthrough covering `get-contexts`, `use-context`, `--context` one-shots,
`rename-context`, `set-context --current --namespace=`, and `config view --minify`.

```powershell
cd src/cka-lab
./kind-multi-up.ps1                 # creates both clusters, prints cheat sheet
./kind-multi-up.ps1 -Practice       # same, then drops into the 8-drill walkthrough
./Start-ContextPractice.ps1         # standalone drill runner against existing clusters
./kind-multi-down.ps1 -ClearRenamed # clean teardown, also removes any renamed contexts
```

### Path B — Hyper-V

```powershell
# Admin PowerShell (Hyper-V cmdlets require elevation, every time)
cd src/cka-lab
./cka-up.ps1                  # boots all 3 VMs (or: vagrant up --provider=hyperv on first run)
./cka-validate.ps1            # confirms all 9 categories pass on every node
./cka-snapshot.ps1            # save the "pre-cluster" baseline
vagrant ssh control1          # your canvas — kubeadm init is on you
./cka-restore.ps1             # atomic rollback when you want to redrill
./cka-down.ps1                # graceful shutdown of all 3 VMs
```

Deep dive and the practice loop: **[TUTORIAL-HYPERV.md](TUTORIAL-HYPERV.md)**

---

## 📦 What's in the Box

### Shared
| File | What It Does |
|------|-------------|
| `README.md` | This page — the landing pad |
| `CLAUDE.md` | Architecture/code-level guidance for editors and AI agents |
| `TUTORIAL-KIND.md` | Hands-on KIND walkthrough |
| `TUTORIAL-HYPERV.md` | Hands-on VM walkthrough + practice loop |

### KIND path
| File | What It Does |
|------|-------------|
| `kind-up.ps1` | Interactive menu → creates a KIND cluster (simple / 3-node / HA / workloads). NodePort preflight, topology-aware `--wait`, optional tutorial. |
| `kind-down.ps1` | Interactive menu → cluster-only teardown or full Docker Desktop + WSL2 shutdown. |
| `kind-multi-up.ps1` | Creates **both** `cka-dev` and `cka-prod` clusters for context-switching practice. `-Practice` drops straight into the 8-drill walkthrough. |
| `kind-multi-down.ps1` | Teardown for both clusters. `-ClearRenamed` sweeps any contexts you renamed during the drills. |
| `Start-Tutorial.ps1` | Runs guided Course 1 tutorials against a single cluster that's already up. |
| `Start-ContextPractice.ps1` | Standalone 8-drill `kubectl config` walkthrough — assumes `cka-dev` and `cka-prod` are already up. |
| `lib/CkaLab.ps1` | Shared module — output helpers, Docker mgmt, prereq checks, KIND cluster helpers. |
| `lib/tutorials.ps1` | Tutorial content (Course 1, Modules 1-3 + component walkthrough). Wraps bodies in `try/finally` so Ctrl-C leaves a clean cluster. |
| `configs/cka-*.yaml` | Six topologies — simple, 3-node (exam), HA (3 CPs, port maps on worker), workloads (labels/taints), plus `cka-dev` / `cka-prod` for the multi-cluster context lab (disjoint host ports). |

### Hyper-V path
| File | What It Does |
|------|-------------|
| `Vagrantfile` | 3 headless Ubuntu 22.04 VMs (control1, worker1, worker2), all prereqs installed, pinned to Kubernetes `1.35.0-1.1`. Stops *before* `kubeadm init`. |
| `create-nat-switch.ps1` | Builds the `CKA-NAT` switch on `192.168.50.0/24`. Exact-match adapter lookup, /24 collision preflight. |
| `bootstrap_cp.sh` | kubeadm init on control1 (`set -euo pipefail`, Flannel pinned `v0.24.4`, CNI-swap comments). |
| `join_worker.sh` | Self-sufficient — SSHes to control1, fetches a fresh kubeadm token, runs the join locally. |
| `cka-snapshot.ps1` / `cka-restore.ps1` | Atomic, all-or-nothing Hyper-V checkpoints. Preflight every VM and every checkpoint before writing anything. |
| `cka-validate.ps1` | 9-category health check across all 3 VMs. Pipes `lib/validate-node.sh` over stdin so `$LASTEXITCODE` reflects the inner bash exit. |
| `cka-info.ps1` | Live UP/DOWN table + SSH cheat sheet. |
| `cka-up.ps1` / `cka-down.ps1` | Boot / graceful shutdown for all VMs. |

### Housekeeping
| Path | What It Does |
|------|-------------|
| `archive/` | Retired scripts (old bash `kind-up.sh`, legacy `snapshot.ps1`). Preserved for reference. |
| `docs/` | Architecture diagrams (HTML, drop into a browser). |

---

## ✅ Prerequisites

### KIND path
- Windows 10/11 with **Docker Desktop** (WSL2 backend recommended)
- **KIND** — `winget install Kubernetes.kind`
- **kubectl** — `winget install Kubernetes.kubectl`
- **PowerShell 7+** — `winget install Microsoft.PowerShell`

One-shot install on a fresh box:

```powershell
winget install --id Microsoft.PowerShell --source winget
winget install --id Docker.DockerDesktop --source winget
winget install --id Kubernetes.kind       --source winget
winget install --id Kubernetes.kubectl    --source winget
```

Verify:

```powershell
docker --version; kind version; kubectl version --client --output=yaml; $PSVersionTable.PSVersion
```

### Hyper-V path
- **Windows 11 Pro / Enterprise** (Hyper-V is gated out of Home)
- **Hyper-V** feature enabled (reboot required)
- **[Vagrant](https://developer.hashicorp.com/vagrant/install)** 2.4.x+
- **Admin PowerShell 7+** — Hyper-V cmdlets require elevation, every time, no exceptions
- ~6 GB free RAM for the 3 VMs

One-shot install (run the first two lines elevated; reboot after Hyper-V):

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
winget install --id Microsoft.PowerShell --source winget
winget install --id Hashicorp.Vagrant    --source winget
```

Verify:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select FeatureName,State
vagrant --version; $PSVersionTable.PSVersion
```

Running both at once is fine if you have the RAM for it — KIND lives inside Docker Desktop's WSL2 VM, Hyper-V runs alongside it.

---

## 🎯 Which One Should I Start With?

**If you're still learning Kubernetes concepts:** start with KIND. A 90-second reset loop is the
right feedback cadence for "deploy a pod, break it, fix it, move on." Don't waste time on
`kubeadm init` until you understand what it produces.

**If you're a month from your exam date:** flip to Hyper-V. The exam's cluster-bootstrap questions
want you in a real shell, with real systemd, running real `kubeadm`. Muscle memory for
`kubeadm init`, CNI install, and `kubeadm join` is worth drilling in a VM where it matters.

**If you want the best of both:** alternate. Use KIND for 5 days a week (workloads, RBAC, services,
storage, scheduling). Use Hyper-V on weekends (cluster bootstrap, HA, upgrades, certificate renewal).
That's the mix this lab was designed to support.

**And before exam week:** run `./kind-multi-up.ps1 -Practice` at least twice. Every real CKA task
starts with "given this context…" — fumbling `kubectl config use-context` on the clock is an
unforced error, and the multi-cluster drill is how you stop making it.

---

## 🧠 CKA Exam Prep Tips

1. **Time your cluster bootstraps.** `kubeadm init` → CNI → worker joins should take < 10 minutes.
2. **Practice without the docs.** The exam gives you access to kubernetes.io, but searching burns clock.
3. **Use the `k` alias.** Pre-configured on the Hyper-V VMs. `k get pods -A` is muscle memory on the exam.
4. **Break things on purpose.** Delete a kubelet config. Corrupt a cert. Fix it. That's where the learning lives.
5. **Snapshot after each milestone.** Pre-cluster, post-init, post-CNI, with-workloads — build a checkpoint library.
6. **Learn `kubectl run --dry-run=client -o yaml | kubectl apply -f -`.** Imperative-first scaffolding beats writing YAML from scratch under timer.
7. **Read the question twice.** Half the exam's difficulty is parsing what's actually being asked.

---

## 🔥 Common Gotchas

| Symptom | Cause | Fix |
|---|---|---|
| `kind create cluster` fails partway | Host port 30000/30080/30443 already bound | `kind-up.ps1` preflights and warns; close the conflicting app, or re-run with `-Force` |
| `vagrant up` fails with a Hyper-V error | Not running as admin | Open a PowerShell session **as Administrator** — no workaround exists |
| `kubelet` crashloops right after VM boot | Normal — it's waiting for cluster config until `kubeadm init` runs | Ignore it. It settles after init. |
| HA cluster created but port 30080 doesn't resolve on failover | Old config had `extraPortMappings` on CP #1 | Current `cka-ha.yaml` puts mappings on a **worker** — pull latest |
| `kind-multi-up.ps1` fails on the second cluster with port-in-use | Leftover `cka-lab` cluster from an earlier `kind-up.ps1` session is holding 30000/30080/30443 | `./kind-down.ps1` first, or run `./kind-multi-down.ps1` and start fresh — the multi lab expects its own ports (30100/30180/30200/30280) to be the only KIND ports bound |
| `cka-restore.ps1` says "nothing restored" | Atomic preflight — one VM or checkpoint is missing | Check the per-VM summary; create missing checkpoints before retrying |
| `cka-validate.ps1` exits 0 but a node actually failed | You're on an old version | Current version pipes validator over stdin; `$LASTEXITCODE` now reflects inner bash exit |

More troubleshooting in the platform-specific tutorial files.

---

## 📚 Deeper Reading

- **[TUTORIAL-KIND.md](TUTORIAL-KIND.md)** — step-by-step KIND walkthrough, tutorial system guide, topology decision tree
- **[TUTORIAL-HYPERV.md](TUTORIAL-HYPERV.md)** — step-by-step Hyper-V walkthrough, snapshot strategy, the practice loop
- **[CLAUDE.md](CLAUDE.md)** — architecture and code-level guidance (read this before editing any script)
- **[docs/](docs/)** — architecture diagrams (open the `.html` files in a browser)

---

*Built with 🤖 Claude, ☕ too much coffee, and the quiet determination of someone
who refuses to let a certification exam be the boss of them.*
