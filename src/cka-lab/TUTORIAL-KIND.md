# KIND Lab Tutorial — CKA in Containers, Not VMs

> *Hyper-V gives you real VMs. KIND gives you a cluster in 90 seconds.
> Different tools, same exam, and you should be fluent in both.*

This is the hands-on walkthrough for the **KIND-based** CKA lab — the Docker-container
flavor of the environment. You'll boot a cluster, poke at it, break it on purpose,
fix it, and tear it down. Budget **15 minutes** for your first run. After that,
cluster spin-up is under two minutes and you'll be running practice drills all day.

> Looking for the **Hyper-V VM lab** (real Ubuntu 22.04 + `kubeadm` the hard way)?
> That lives in `src/cka-lab/README.md`. This file is its container-native cousin.

---

## Prereqs

No admin PowerShell required. KIND runs as a normal user — it just needs Docker.

| Tool | Minimum | Notes |
|------|---------|-------|
| **Windows 11** | Any edition | Pro/Enterprise not required (that's a Hyper-V thing) |
| **Docker Desktop** | 4.30+ | WSL2 backend. The script will start it for you. |
| **KIND** | 0.23+ | `winget install Kubernetes.kind` or `choco install kind` |
| **kubectl** | 1.32+ | `winget install Kubernetes.kubectl` |
| **PowerShell** | 7.0+ | `pwsh`, not `powershell.exe`. Scripts declare `#Requires -Version 7.0`. |

### First-time install (copy-paste)

Run these once in an elevated PowerShell. `winget` comes with Windows 11 by default.

```powershell
# PowerShell 7 (required — the lab scripts declare #Requires -Version 7.0)
winget install --id Microsoft.PowerShell --source winget

# Docker Desktop (WSL2 backend)
winget install --id Docker.DockerDesktop --source winget

# KIND and kubectl
winget install --id Kubernetes.kind --source winget
winget install --id Kubernetes.kubectl --source winget
```

After Docker Desktop installs, launch it once, sign in, and confirm **Settings → General → Use the WSL 2 based engine** is checked. Then reboot. That one reboot is the only ceremony.

From this point forward, open **PowerShell 7 (`pwsh`)** — not Windows PowerShell — for every script in this lab.

Verify in one line:

```powershell
docker --version; kind version; kubectl version --client --output=yaml; $PSVersionTable.PSVersion
```

> Heads up: if Docker Desktop isn't installed yet, `kind-up.ps1` will fail
> prereq validation and tell you exactly what's missing. No silent stalls.

---

## Section A — First cluster in 60 seconds

The fast path. No flags, no decisions — just run it.

```powershell
cd C:\github\ps-cka\src\cka-lab
.\kind-up.ps1
```

You'll see three prompts:

1. **Topology menu** — press Enter (defaults to **Simple**, 1 CP + 1 worker)
2. **Show kubeadm commands?** — press Enter (defaults to **No**)
3. **Run a tutorial?** — press Enter (defaults to **No**)

Now wait. Script flow:

- Validates `docker`, `kind`, `kubectl` are on PATH
- Starts Docker Desktop if it's not running (up to 120s)
- Preflights host ports 30000 / 30080 / 30443
- Runs `kind create cluster --config configs\cka-simple.yaml`
- Waits for every node to reach Ready
- Prints a `docker stats` summary filtered to just the cluster's containers

When you see `CKA Lab Ready`, you're live:

```powershell
kubectl get nodes
```

Expected output:

```
NAME                        STATUS   ROLES           AGE   VERSION
cka-lab-control-plane       Ready    control-plane   45s   v1.35.x
cka-lab-worker              Ready    <none>          30s   v1.35.x
```

Done. Skip to Section D if you're ready to play, or Section G when you want to tear down.

---

## Section B — Topology deep-dive

The topology menu in `src/cka-lab/kind-up.ps1` exposes **four** prebaked configs.
Pick by exam domain, not by "looks beefy."

| Option | Config | Nodes | When to pick it |
|--------|--------|-------|-----------------|
| **[1] Simple** | `configs/cka-simple.yaml` | 1 CP + 1 worker | Quick smoke test, kubectl drills, restart cycles |
| **[2] Standard** | `configs/cka-3node.yaml` | 1 CP + 2 workers | **CKA exam topology — this is your default.** Scheduling, DaemonSets, multi-node services. |
| **[3] HA** | `configs/cka-ha.yaml` | 3 CP + 2 workers | etcd quorum, control-plane failover, leader election, `etcdctl snapshot save/restore` |
| **[4] Workloads** | `configs/cka-workloads.yaml` | 1 CP + 3 workers | Node affinity, taints/tolerations, topology spread. Auto-applies `zone=east/west`, `tier=frontend/backend`, and `dedicated=special:NoSchedule` on worker3. |

### Picking guidance

- New to the lab? **Start with Standard (2).** It mirrors the real CKA exam cluster shape.
- Practicing `drain` / `cordon` / `uncordon`? **Workloads (4)** — three workers = interesting scheduling.
- Practicing etcd? **HA (3)** — and read the note below about the worker-port fix.
- Just need to verify a manifest works? **Simple (1)** — boots in ~60s.

### The HA worker-port thing

When you pick HA, `configs/cka-ha.yaml` puts the NodePort bindings (30000/30080/30443)
on the **first worker**, not on a control-plane node. That's deliberate:

> HA teaching demos kill a control-plane on purpose to prove etcd quorum survives.
> If NodePort traffic was bound to CP #1, it would die with the CP — and the failover
> demo would look like a cluster-wide outage instead of a successful failover.
> Workers don't get drained in HA scenarios, so host → NodePort routing stays up
> through control-plane failures.

You don't need to do anything with this info. Just know: when you `kill` a control-plane
container during HA practice, your NodePort service will keep responding. That's correct.

### Resource footprint (ballpark)

| Topology | RAM | Create time |
|----------|-----|-------------|
| Simple | ~1.5 GB | 60–90s |
| Standard | ~2.5 GB | 90–120s |
| HA | ~5 GB | 3–5 min |
| Workloads | ~3.5 GB | 2–3 min |

Numbers assume a warm image cache. Cold first-pull adds ~1 GB download and 2 minutes.

---

## Section C — Running a tutorial

The lab ships **four guided tutorials** in `src/cka-lab/lib/tutorials.ps1`. Each is
a sequence of live commands with explanatory narration and a pause-on-Enter between
steps. No slides. No markdown. Just kubectl output and context.

| # | Tutorial | Steps | What it covers |
|---|----------|-------|----------------|
| 1 | **Component Walkthrough** | 12 | Verify every K8s component — etcd, API server, controller-manager, scheduler, kubelet, kube-proxy, CoreDNS, CNI. |
| 2 | **Course 1, Module 1** | 10 | Cluster architecture + kubeconfig anatomy (the Course 1 intro module). |
| 3 | **Course 1, Module 2** | 16 | kubectl workflows — imperative vs. declarative, `--dry-run=client -o yaml`, `explain`. |
| 4 | **Course 1, Module 3** | 18 | Core resources + the **diagnostic ladder**: `get → describe → logs → events`. |

### What each step looks like

Every one of the 57 steps is rendered as a consistent 4-block pattern:

```
================================================================
  2/16  IMPERATIVE: CREATE A DEPLOYMENT
================================================================

  Deployments manage rollouts. Three things just happened:
  a Deployment, a ReplicaSet, and 3 Pods. All from one command.

  Command:  kubectl create deployment web --image=nginx --replicas=3
  ---- What each part does -----------------------------------
  kubectl create  = imperative create (vs apply, which is declarative from YAML)
  deployment      = resource kind (short: deploy)
  web             = Deployment name; becomes the label selector app=web
  --image=nginx   = container image used in the pod template
  --replicas=3    = desired pod count; ReplicaSet enforces this continuously
  ----------------------------------------------------------------

  deployment.apps/web created

  ---- What you just saw -------------------------------------
  deployment.apps/web created = Deployment object persisted
  Chain spawned: Deployment -> ReplicaSet -> 3 Pods (all labeled app=web)
  Pod names follow <deploy>-<rs-hash>-<pod-hash> (e.g. web-7d4b9c8f-xkl2m)
  Verify the chain with: kubectl get deploy,rs,pods

  Press Enter to continue:
```

The **"What each part does"** block explains every flag and argument before the
command runs. The **"What you just saw"** block explains the columns and fields
of the output after it runs. You can skip both by hitting Enter fast — they're
there for the first pass, not to slow down reps two and three.

### Launching a tutorial

Two ways.

**During cluster creation** (pick at the tutorial prompt):

```powershell
.\kind-up.ps1
# ... pick topology ...
# ... pick ShowKubeadm ...
# Run a guided tutorial after cluster creation?
#   [1] Component Walkthrough  <-- pick one of these
```

**Against an already-running cluster** (replay or try a different module):

```powershell
.\Start-Tutorial.ps1
```

`Start-Tutorial.ps1` checks that `cka-lab` is running, switches your kubectl context
to `kind-cka-lab` if needed, then shows the tutorial menu. No cluster recreation.

### Topology-agnostic narration

The tutorials query node count at runtime and speak plainly about what's there.
"You have 3 nodes" on Standard, "you have 5 nodes with 3 control-planes" on HA.
You can run any tutorial against any topology — the narration adjusts.

---

## Section D — Day-in-the-life commands

Once a cluster is up, these are your everyday moves.

### The `k` alias

PowerShell 7 doesn't ship one. Add it to your `$PROFILE`:

```powershell
Set-Alias -Name k -Value kubectl
```

Or define it in-session:

```powershell
function k { kubectl @args }
```

Now `k get pods -A` works. You'll want this on the exam — the VM has it preconfigured.

### Cluster sanity sweep

```powershell
kubectl get nodes -o wide
kubectl get pods -A
kubectl get componentstatus          # "legacy but still works" on v1.35
kubectl cluster-info
kubectl config current-context        # should say: kind-cka-lab
```

### Quick workload smoke test

```powershell
kubectl run nginx --image=nginx --port=80
kubectl expose pod nginx --type=NodePort --port=80 --target-port=80 --name=nginx-svc
kubectl get svc nginx-svc -o wide
```

Now hit it from the host — NodePorts 30000/30080/30443 are mapped to your machine:

```powershell
# Find which NodePort Kubernetes assigned
$port = kubectl get svc nginx-svc -o jsonpath='{.spec.ports[0].nodePort}'
curl.exe "http://localhost:$port"
```

If Kubernetes picked a NodePort outside 30000/30080/30443, it **won't** be reachable
from the host. Force a mapped port with `--node-port=30080` when you expose.

### See the nodes as Docker containers

```powershell
docker ps --filter "label=io.x-k8s.kind.cluster=cka-lab" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

This is the filter `kind-up.ps1` uses for its resource summary. Unlabeled `docker ps`
includes every random container on your machine and buries the useful rows.

### Tail logs from a system pod

```powershell
kubectl -n kube-system logs -l component=kube-apiserver --tail=50
kubectl -n kube-system logs ds/kindnet --tail=20
```

### Describe-driven debugging

```powershell
kubectl describe node cka-lab-worker
kubectl describe pod nginx
kubectl get events --sort-by='.lastTimestamp' | Select-Object -Last 20
```

The **diagnostic ladder** from Course 1, Module 3 — `get → describe → logs → events` —
solves 80% of "why is this broken" questions on the exam. Drill it until it's reflex.

---

## Section E — Breaking and fixing

Reading docs makes you confident. Fixing broken stuff makes you fast. Deliberately
sabotage the cluster and use the diagnostic ladder to recover. These drills map
directly to the Troubleshooting domain (30% of the exam).

### Drill 1: Kill a system pod

```powershell
kubectl -n kube-system delete pod -l component=kube-apiserver
kubectl -n kube-system get pods -l component=kube-apiserver -w
```

Kubernetes restarts it from its static pod manifest within seconds. Watch the
`RESTARTS` count increment. Teaching point: **static pods are managed by kubelet,
not the scheduler** — delete one and kubelet recreates it.

### Drill 2: Stop kubelet on a worker

```powershell
docker exec cka-lab-worker systemctl stop kubelet
kubectl get nodes          # worker goes NotReady within 40s
docker exec cka-lab-worker systemctl start kubelet
kubectl get nodes          # back to Ready
```

The lag before `NotReady` is the `node-monitor-grace-period` (40s default). This is
a classic CKA scenario: a node shows `NotReady`, and you need to SSH in and check
kubelet. In the exam you'd use `ssh`; here you use `docker exec`.

### Drill 3: Break a manifest, diagnose with events

```powershell
kubectl run broken --image=nginx:doesnotexist
kubectl get pod broken                                    # ImagePullBackOff
kubectl describe pod broken | Select-String -Context 0,3 Events
kubectl delete pod broken
```

Reading `Events` under `describe` is the exam-shortcut to "why didn't it start."

### Drill 4: Drain a node

```powershell
kubectl drain cka-lab-worker --ignore-daemonsets --delete-emptydir-data
kubectl get pods -A -o wide | Select-String cka-lab-worker  # empty (except DaemonSets)
kubectl uncordon cka-lab-worker
```

### Drill 5: HA failover (HA topology only)

```powershell
# Prove the cluster survives losing a control-plane
docker stop cka-lab-control-plane2
kubectl get nodes                # CP #2 shows NotReady
kubectl get pods -A              # everything else keeps running
kubectl run still-works --image=nginx
docker start cka-lab-control-plane2
```

Because NodePorts are on a worker (see Section B), your test services stay reachable
from the host throughout the failover. That's the demo working as designed.

> After each drill, if you wedge the cluster past recovery: `.\kind-down.ps1` →
> `.\kind-up.ps1`. It's 60–90 seconds. Embrace the rebuild.

---

## Section F — Non-interactive recipes

For recording sessions, CI smoke tests, or when you don't feel like clicking menus.
Every prompt has a matching parameter — pass it and the menu is skipped.

### Create a 3-node cluster, no prompts

```powershell
.\kind-up.ps1 -ConfigPath .\configs\cka-3node.yaml -SkipDdStart:$false -ShowKubeadm:$false
```

`-ConfigPath` skips the topology menu. `-ShowKubeadm:$false` answers the verbose prompt.
No `-Tutorial` means the tutorial prompt also auto-skips.

### Fast recreate (DD already running)

```powershell
.\kind-up.ps1 -ConfigPath .\configs\cka-simple.yaml -SkipDdStart -ShowKubeadm:$false
```

`-SkipDdStart` cuts the Docker Desktop wait to 15 seconds (still verifies daemon is up).

### Teaching mode: show kubeadm internals + run tutorial

```powershell
.\kind-up.ps1 -ConfigPath .\configs\cka-3node.yaml -ShowKubeadm -Tutorial
```

`-Tutorial` runs the Component Walkthrough automatically. For the Course 1 modules,
launch `.\Start-Tutorial.ps1` after creation.

### Force through NodePort conflicts

Got a dev server on port 30080 you can't kill right now?

```powershell
.\kind-up.ps1 -ConfigPath .\configs\cka-simple.yaml -Force
```

`-Force` acknowledges the warning and proceeds. The cluster will create, but anything
bound to the occupied host port won't be reachable via `localhost:30080`.

### Tear down to bare metal

```powershell
.\kind-down.ps1 -StopDockerDesktop -Prune
```

Deletes the cluster, prunes unused Docker images, stops Docker Desktop, shuts down
WSL2. Good end-of-day command when you want your RAM back.

### Cluster-only teardown (keep DD warm)

```powershell
.\kind-down.ps1 -StopDockerDesktop:$false
```

Cluster gone, DD still running, ready for the next `kind-up.ps1` in seconds.

---

## Section G — Tear-down options

Two modes, one script.

### Mode 1: Cluster-only (default)

```powershell
.\kind-down.ps1
# [1] Destroy cluster only      (Docker Desktop stays running)  <-- default
```

- Deletes the KIND cluster (containers + network)
- Docker Desktop stays up
- Next `kind-up.ps1` boots in 60–90 seconds because DD is already warm

Use this **between drills** in the same session.

### Mode 2: Full shutdown

```powershell
.\kind-down.ps1
# [2] Full shutdown              (stop Docker Desktop + WSL2)
```

- Deletes the KIND cluster
- Stops Docker Desktop
- Runs `wsl --shutdown` as the final step (reclaims the WSL2 memory allotment)

Use this **end of day** or when you want your laptop back for non-Docker work.

### The Prune prompt

Either mode asks:

```
Prune unused Docker images to reclaim disk space? [y/N]
```

Answer **Y** once a week or when disk is tight. It runs `docker system prune -af --volumes`
and can free several gigabytes after repeated cluster creations. Answer **N** to keep the
`kindest/node` image cached — that's what makes the next `kind create` fast.

### WSL2 shutdown timing

`kind-down.ps1` defers the `wsl --shutdown` call until the very last line so it doesn't
kill the PowerShell session mid-script. You'll see a 3-second countdown before it fires.

---

## Section H — Troubleshooting

### Docker Desktop won't come up

Symptom: `kind-up.ps1` hangs at *"Waiting for Docker daemon to respond..."* past 120s.

Checks:

```powershell
Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
docker version
```

If `docker version` says *"error during connect: open //./pipe/dockerDesktopLinuxEngine"*,
DD's WSL backend is wedged. Fix:

```powershell
wsl --shutdown
# Then start Docker Desktop from the Start menu
```

Re-run `.\kind-up.ps1 -SkipDdStart` once the whale icon is solid.

### "NodePort host-port already in use" preflight warning

```
WARNING: The following NodePort host-ports are already in use:
  - Port 30080 (held by: node)
```

Something on your box already owns 30080. Common culprits: local dev server,
reverse proxy, prior KIND cluster that didn't clean up. Fix either way:

```powershell
# Option A: find and kill the offender
Get-NetTCPConnection -LocalPort 30080 -State Listen | ForEach-Object {
    Get-Process -Id $_.OwningProcess
}

# Option B: bypass the preflight
.\kind-up.ps1 -Force
```

### `Invoke-KubectlWithRetry` warnings on workloads topology

Symptom, on the **Workloads (4)** topology:

```
WARNING: One or more label/taint commands failed after retries.
```

The cluster is up, but `zone` / `tier` / `dedicated` labels didn't all land. The API
server occasionally 404s on node names in the first few seconds after `kind create`
returns — the helper retries 3×, and sometimes that's not enough on cold boxes.

Fix by hand:

```powershell
kubectl label node cka-lab-worker  zone=east tier=frontend --overwrite
kubectl label node cka-lab-worker2 zone=west tier=backend  --overwrite
kubectl label node cka-lab-worker3 zone=east tier=backend  --overwrite
kubectl taint node cka-lab-worker3 dedicated=special:NoSchedule --overwrite
kubectl get nodes --show-labels
```

### "Cluster name mismatch" — kubectl points at the wrong cluster

Symptom: `kubectl get nodes` shows someone else's cluster (GKE, AKS, a different KIND).

```powershell
kubectl config get-contexts
kubectl config use-context kind-cka-lab
```

`Start-Tutorial.ps1` does this automatically. `kind-up.ps1` sets it on create. If you
manually changed context, just switch it back.

### The cluster exists but `kind-up.ps1` says "already exists"

That's idempotence, not an error. The script detects the existing cluster and exits
cleanly. To rebuild fresh:

```powershell
.\kind-down.ps1
.\kind-up.ps1
```

### Windows Defender / antivirus slowing image pulls

First `kind create` can take 5+ minutes if Defender is scanning every layer. Add an
exclusion for `C:\Users\<you>\.kind\` and your Docker Desktop data dir. One-time fix,
massive speedup.

---

## Section I — What's NOT installed on purpose

KIND gives you a working cluster. It does **not** give you a pre-provisioned playground.
That's intentional — the exam tests whether **you** can install these, not whether
a script did it for you.

| Not installed | Why you do it yourself |
|---------------|------------------------|
| **Your CNI of choice** | KIND ships `kindnet` by default. For real CNI practice (Calico, Cilium, Flannel), create with `--config` that disables the default CNI, then `kubectl apply` your pick. |
| **Helm** | Install during practice: `winget install Helm.Helm`. Drill `helm repo add / install / upgrade / rollback`. |
| **Ingress controller** | No NGINX Ingress, no Traefik. Install one as an exam drill. The NodePort mappings at 30080/30443 are pre-wired for exactly this. |
| **Workloads** | Zero demo deployments. `kubectl run nginx` is your friend. |
| **Metrics Server** | `kubectl top` won't work until you install `metrics-server`. That's a Course 5 (HPA/VPA) exercise. |
| **RBAC test users** | No service accounts beyond the defaults. Build them per-scenario. |
| **StorageClass beyond the default** | KIND's default `standard` class uses local-path-provisioner. PV/PVC practice works; advanced CSI doesn't. |

### What IS baked in

- Kubernetes **v1.35** on every node
- **containerd** runtime (matches CKA exam environment)
- **kindnet** CNI (simple, works, swap it out when you want to practice CNI installs)
- **PodSecurity** + **NodeRestriction** admission plugins enabled
- NodePort host-port mappings on 30000 / 30080 / 30443
- **Static pod manifests** under `/etc/kubernetes/manifests/` on the control-plane(s) — perfect for `docker exec <cp> ls /etc/kubernetes/manifests`

---

## Quick Reference Card

```powershell
# Spin up
cd C:\github\ps-cka\src\cka-lab
.\kind-up.ps1                                                    # interactive
.\kind-up.ps1 -ConfigPath .\configs\cka-3node.yaml -SkipDdStart  # scripted

# Tutorial (against running cluster)
.\Start-Tutorial.ps1

# Verify
kubectl get nodes -o wide
kubectl get pods -A
kubectl config current-context                                    # kind-cka-lab

# Day-in-the-life
kubectl run nginx --image=nginx --port=80
kubectl expose pod nginx --type=NodePort --node-port=30080 --port=80 --name=nginx-svc
curl.exe http://localhost:30080

# See KIND nodes as Docker containers
docker ps --filter "label=io.x-k8s.kind.cluster=cka-lab"

# Break and fix drills
kubectl -n kube-system delete pod -l component=kube-apiserver    # static pod returns
docker exec cka-lab-worker systemctl stop kubelet                # NotReady demo
kubectl drain cka-lab-worker --ignore-daemonsets --delete-emptydir-data
kubectl uncordon cka-lab-worker

# HA failover (HA topology only)
docker stop cka-lab-control-plane2
docker start cka-lab-control-plane2

# Tear down
.\kind-down.ps1                                                   # cluster only
.\kind-down.ps1 -StopDockerDesktop -Prune                         # full shutdown

# Full rebuild
.\kind-down.ps1 ; .\kind-up.ps1
```

---

## Where to go next

- **Real VMs, real kubeadm:** `src/cka-lab/README.md` (Hyper-V + Vagrant path)
- **Tutorial source:** `src/cka-lab/lib/tutorials.ps1`
- **Cluster configs:** `src/cka-lab/configs/*.yaml`
- **Shared helpers:** `src/cka-lab/lib/CkaLab.ps1`
- **Course content:** `exercise-files/course-01-*/` through `course-11-*/`

The exam rewards muscle memory. Spin this lab up every day for a week and you'll
feel the difference by Friday.
