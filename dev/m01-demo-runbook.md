# CKA Course 1 / Module 1 — Kubernetes Architecture and Lab Setup

**Target runtime:** 12-13 min on camera
**Environment:** pwsh 7 in Windows Terminal or WSL2 Ubuntu
**Lab:** `src/cka-lab/kind-up.ps1` → Standard topology (1 CP + 2 workers, K8s v1.35)
**Authoritative demo script:** `src/cka-lab/lib/tutorials.ps1` → `Start-TutorialM01`

---

## Pre-flight (run these BEFORE hitting record)

```powershell
# 1. Prove the toolchain is alive
docker info | Select-String "Server Version"   # daemon responds
kind version                                   # >= v0.25
kubectl version --client                       # >= 1.35

# 2. Clean slate (so demo is reproducible)
cd c:\github\ps-cka\src\cka-lab
./kind-down.ps1 -Force                         # nukes any existing cka-lab

# 3. Test-run the up + tutorial ONCE off-camera
./kind-up.ps1                                  # choose [2] Standard, tutorial [2] M01
# Read through all 10 steps. Re-run until nothing surprises you.
./kind-down.ps1 -Force                         # back to zero for the real take
```

**Camera checklist:**

- [ ] Terminal font 16pt+, 140 cols wide
- [ ] Prompt short (`PS>` or `tim@host:~$`), current dir trimmed
- [ ] Screen scaling matches Pluralsight template (1080p, no HiDPI blur)
- [ ] No other Docker containers running (`docker ps` clean)
- [ ] `.kube/config` doesn't already have stale contexts (`kubectl config get-contexts` shows nothing kind-related)

---

## Open (30 sec on camera)

> "Before you troubleshoot a cluster you have to understand what's inside one. In this module we build a three-node lab from scratch, then walk every architectural piece the CKA exam tests you on — nodes, control-plane static pods, the CNI, CoreDNS. Pop quiz at the end: I'll make you explain what `kubectl cluster-info` talks to. Let's go."

---

## Demo 1 — Build the cluster (2-3 min)

**Goal:** Show declarative, three-node KIND cluster coming up in under a minute.

```powershell
cd c:\github\ps-cka\src\cka-lab
./kind-up.ps1
```

**Menu choices** (read the prompts out loud for the viewer):

- Topology → `2` (Standard, 1 CP + 2 workers)
- Show kubeadm? → `n` (keep clean)
- Tutorial? → `0` (no — I'll run it manually for teaching pace)

**Narration cues while cluster creates:**

- "This config is under `configs/cka-3node.yaml`. Declarative YAML, NodePort mappings on 30000/30080/30443, containerd runtime — same as the exam."
- "KIND is running `kubeadm init` inside a Docker container. Real kubeadm, real API server. Not a simulator."
- Watch for "Set kubectl context to kind-cka-lab" — that's your trigger to move on.

**If it breaks:** Port conflict warnings print the offending process. Kill it (or answer `y` if you don't need that app running during the take).

---

## Demo 2 — Nodes and what KIND actually built (2 min)

**Goal:** Prove the architecture from the lecture exists in real bytes.

Drive the tutorial from here on:

```powershell
./Start-Tutorial.ps1                           # menu: [2] Module 1 walkthrough
```

**Section 1/10 — `kubectl get nodes -o wide`**
All 3 nodes Ready. **Emphasize the CONTAINER-RUNTIME column** — `containerd` is what ships on the real CKA exam.

**Section 2/10 — `docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'`**
Say it out loud: "These aren't VMs. Each node is a Docker container running a full kubelet."

**Section 3/10 — `kubectl config current-context`**
"`kind-cka-lab`. On the real CKA exam there are FOUR clusters. Always verify before any destructive command."

**Teaching moment after step 3:**

> "A context is a triple: cluster + user + namespace. Switching context switches all three at once."

---

## Demo 3 — Control plane & system pods (2-3 min)

**Goal:** Name the 4 control-plane components and show they're static pods.

**Section 4/10 — `kubectl get pods -n kube-system -o wide`**
Point at each of the four: `etcd-`, `kube-apiserver-`, `kube-scheduler-`, `kube-controller-manager-`. All suffixed with the control-plane node name because they're **static pods**, managed by kubelet from `/etc/kubernetes/manifests/` — not by the API server itself. This is chicken-and-egg: kubelet can bring these up even when the API server is down.

**Section 5/10 — `kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide`**
Exactly three kube-proxy pods — one per node. That's the DaemonSet contract. If a node is missing kube-proxy, Services break on that node.

**Pause cue:** after step 4, let viewers scan the pod list. Say:

> "The API server is a pod. Think about that. It's the thing serving the API, packaged as a pod, managed by kubelet even when etcd is down."

---

## Demo 4 — DNS end-to-end (2-3 min)

**Goal:** CoreDNS → kube-dns Service → FQDN resolution works.

**Section 6/10 — `kubectl -n kube-system get svc kube-dns`**
"The **Service** is still called kube-dns for backward compatibility. The pods behind it are CoreDNS."

**Section 7/10 — `kubectl -n kube-system get deploy coredns`**
"2 replicas. DNS has to stay up even during node maintenance."

**Section 8/10 — the DNS lookup:**

```powershell
kubectl run dns-test --image=busybox:1.36 --rm --restart=Never --attach `
  -- nslookup kubernetes.default.svc.cluster.local
```

Expect `Address: 10.96.0.1`. Call it out: "That's the Kubernetes service — a stable DNS name every pod can use to reach the API server."

**Gotcha to call out:** busybox nslookup doesn't walk the search list, so we query the full FQDN here. Short names only work from getent or Go-native resolvers. We'll use `getent hosts` in Module 3.

---

## Demo 5 — cluster-info & api-resources (1-2 min)

**Goal:** First-response commands for a broken cluster.

**Section 9/10 — `kubectl cluster-info`**
"If this fails, your kubeconfig is wrong — not your cluster. Always check here first on the exam."

**Section 10/10 — `kubectl api-resources | Select-Object -First 20`**
**The SHORTNAMES column is gold.** Memorize: `po`, `svc`, `deploy`, `cm`, `ns`, `sa`, `pv`, `pvc`, `ing`, `netpol`.

---

## Close (30 sec)

> "You now have a 3-node cluster you built yourself, you've named every control-plane component, you've tested DNS end-to-end, and you know the two commands to run when a cluster looks broken. In Module 2 we push this cluster hard with imperative kubectl — the speed workflow you need to pass the exam. See you there."

---

## Reset between takes

```powershell
# Fast: just rerun the tutorial (cleanup is in try/finally; M01 is read-only anyway)
./Start-Tutorial.ps1

# Full reset (rare — M01 creates nothing but a throwaway dns-test pod that auto-deletes)
./kind-down.ps1 -Force
./kind-up.ps1
```

---

## Recovery cheat sheet

- **`kind create` fails on port 30000/30080/30443** → rerun with `-Force` (or answer the prompt). Find owner with `Get-NetTCPConnection -LocalPort 30000` on Windows or `ss -ltnp | grep 30000` on Linux.
- **Cluster exists from an earlier run** → `./kind-down.ps1 -Force && ./kind-up.ps1`.
- **`busybox:1.36` pull fails (rate limit)** → swap to `busybox:stable`; behavior identical.
- **DNS test returns NXDOMAIN** → `kubectl get pods -n kube-system -l k8s-app=coredns`; if replicas aren't Ready, `kubectl rollout restart deploy/coredns -n kube-system`.
- **Docker Desktop not responding** → start DD manually, then rerun with `-SkipDdStart`.

---

## Source mapping

Every command above comes from [`src/cka-lab/lib/tutorials.ps1`](../src/cka-lab/lib/tutorials.ps1) → `Start-TutorialM01` (line 177). When you want to edit narration permanently, edit that file — **don't drift this runbook**. This runbook is the on-camera script; that file is the single source of truth for commands + output-field explainers.
