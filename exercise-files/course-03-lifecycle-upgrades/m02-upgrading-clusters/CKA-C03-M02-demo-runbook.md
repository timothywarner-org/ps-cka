# CKA Course 3 / Module 2 - Upgrading Kubernetes Clusters with kubeadm

**Runbook rev: 2.0**

**Target runtime:** 16-18 min on camera
**Environment:** Hyper-V Vagrant lab (`control1`, `worker1`, `worker2`), Ubuntu 22.04, 2 vCPU / 2 GB each
**Lab starts at:** Kubernetes **v1.34** | **ends at:** Kubernetes **v1.35** (Module 3's start state)
**CKA domain:** Cluster Architecture, Installation & Configuration (25%) - "Perform a version upgrade on a Kubernetes cluster using kubeadm"

> **This MD mirrors the app. The on-rails console app
> [`Invoke-M02Upgrade.ps1`](../../../src/cka-lab/course-03-lifecycle-upgrades/Invoke-M02Upgrade.ps1)
> is the SOURCE OF TRUTH** for this demo - it runs the real commands, phase by
> phase, with this exact talk track on screen. This document is the readable
> companion: same 8 phases, same names, same narration, same tips. Edit the app,
> then regenerate this MD so the two never drift. The demo IS the app; this is
> how you read it off-camera.

---

## Recording cue card (glance here mid-take)

Two columns. **SCREEN** = what the app shows / runs when you press Enter (your
screenshare). **SAY** = the ONE teaching beat that must land before you press
Enter for the next phase. Each phase fires on one Enter press.

| # | SCREEN shows / runs | The ONE thing you SAY |
|---|---|---|
| 0 | `Restore m02-pre-upgrade` -> `globo-shop` deploys, 3 pods | "Clean v1.34 cluster, a workload running. This is our before." |
| 1 | Talk slide: version-skew arc (no command) | **"Control plane FIRST. Kubelet can lag the apiserver by 3 minors, never lead it. Brain before limbs."** |
| 2 | `etcdctl snapshot save` (via kubectl exec) | "Before I touch the control plane, I snapshot etcd. It's the whole cluster in one file. My only true undo." |
| 3 | `tee .../kubernetes.list` -> `/v1.35/` + `apt update` | **"I don't change the command, I change what the repo POINTS at. /v1.34/ becomes /v1.35/. This is the #1 forgotten step."** |
| 4 | `apt install kubeadm=1.35.6-1.1` -> `kubeadm version` | "unhold, install the exact patch, re-hold. The TOOL is v1.35 now; the cluster isn't yet." |
| 5 | `kubeadm upgrade plan` then `apply v1.35.6` | **"`plan` is a dry run. `apply` rewrites the static pod manifests and rolls the control plane. Watch: node STILL says v1.34 - that's the kubelet, next."** |
| 6 | drain control1 -> kubelet bump -> uncordon -> `get nodes` | "drain = cordon + evict. Then bump the kubelet. NOW the node flips to v1.35. (Red PDB line = normal, it retries.)" |
| 7 | per worker: `upgrade node` -> drain (from control1) -> kubelet -> uncordon | **"Workers run `upgrade node`, NOT apply. And drain runs FROM control1 - the worker has no kubeconfig. Apply once, node everywhere else."** |
| 8 | `get nodes` -> 3x v1.35.6 Ready + workloads up | "Three nodes, all v1.35, app never went down. And kubeadm did NOT touch Calico - the CNI upgrades on its own." |

**Bold rows (1, 3, 5, 7) are the exam-distinguisher beats** - if you only nail four
things, nail those. Full narration for each phase is below.

---

## How to run it

```powershell
# Elevated PowerShell 7, from the Course 3 lab controls folder:
cd C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades

# One command. It auto-restores pristine v1.34 first, then walks all 8 phases.
.\Invoke-M02Upgrade.ps1

# Pin the exact v1.35 patch if 1.35.0-1.1 is gone (confirm first):
#   ssh vagrant@192.168.50.10 "sudo apt-cache madison kubeadm | head"
.\Invoke-M02Upgrade.ps1 -ToPackage 1.35.6-1.1
```

**Idempotent by design.** Launch restores the `m02-pre-upgrade` checkpoint, so
every run starts from the identical v1.34 cluster - run it for real, over and
over, same opening frame every time. Between nodes it auto-checkpoints
(`m02-after-control1`, `m02-after-worker1`) so a botched worker take rewinds to
the node boundary, not the whole demo. Ctrl-C is safe; re-launch resets you.

**Camera checklist:**

- [ ] `m02-pre-upgrade` checkpoint exists on all 3 VMs (the app verifies and aborts if not)
- [ ] Terminal >= 18pt, scrollback clear
- [ ] You know the exact `-ToPackage` patch available on recording day
- [ ] (setup is automatic - the app deploys `globo-shop` after the restore, so the worker drain always has pods to evict)

**Setup beat (the app does this for you, right after the restore):**

```bash
kubectl create deployment globo-shop --image=nginx --replicas=3
kubectl rollout status deployment/globo-shop
kubectl get pods -l app=globo-shop -o wide   # 3 replicas across the workers
```

The app owns this so the demo is self-contained: the pristine snapshot predates
the workload, so restore wipes it, then the app redeploys it - every run has the
same pods to drain regardless of what the snapshot holds.

---

## Phase 1 - Why the control plane goes first

**The mental model. Say this before any command.**

> "Before we touch a package, the rule that drives the whole upgrade. Every
> component talks to the API server - the apiserver is the brain. Kubernetes
> publishes a **version skew policy**, and the load-bearing rule is this: the
> **kubelet may be up to THREE minor versions OLDER than the apiserver, but it
> must NEVER be newer.** So a v1.35 apiserver talking to v1.34 kubelets on the
> workers is supported - that's the entire reason a rolling upgrade is possible.
> The reverse, a newer kubelet calling an older apiserver, is not. That asymmetry
> is why we upgrade the brain before the limbs. It's not a style choice."

The arc you'll see repeat on every node:

```
repo  ->  kubeadm  ->  (plan/apply on control plane)  ->  drain  ->  kubelet  ->  uncordon
```

> **CKA TIP:** kube-proxy follows the same 3-minor rule vs the apiserver, AND
> independently may be up to 3 minor older OR newer than the kubelet beside it.
> kubectl is supported within ONE minor either side of the apiserver. Know all
> three axes - the exam probes the kube-proxy/kubelet one specifically.

---

## Phase 2 - Back up etcd before you mutate the control plane

> "kubeadm will back up the static pod manifests and renew certs for us. But your
> only TRUE rollback if the apply goes sideways is an **etcd snapshot** - etcd is
> the cluster's entire state, every object, in one key-value store. This is the
> adjacent CKA objective (backup/restore) sitting right next to the upgrade
> objective, so we take it here as the production reflex. Note we exec INTO the
> etcd pod - the etcdctl binary ships in that image, nothing to install on the host."

```bash
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system exec etcd-control1 -- \
  etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/m02-pre-1.35.db
```

> **CKA TIP:** the etcd cert paths are always under `/etc/kubernetes/pki/etcd/`.
> Memorize `ca.crt` / `server.crt` / `server.key` - you reuse them for restore.

---

## Phase 3 - Repoint the package repo to v1.35

> "Here's the mechanism. When you ran `apt-get install kubeadm` to BUILD this
> cluster, apt asked one repository what the word 'kubeadm' means. That repo is
> pinned to `/v1.34/` - it only knows 1.34. So to upgrade you don't change the
> command. You change what the WORD points at. Repoint the repo to `/v1.35/`, run
> `apt-get update`, and the same install command now resolves to a different
> binary. Skip this and `apt-get install kubeadm` cheerfully reinstalls the newest
> 1.34 patch - and you'll swear the upgrade is broken."

```bash
cat /etc/apt/sources.list.d/kubernetes.list      # before: /v1.34/
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-cache madison kubeadm | head -3          # after: v1.35 patches visible
```

> **CKA TIP:** `apt-get update` is the "apply" button for this change. No update =
> apt still believes the old version. This file is the #1 reason an upgrade "does
> nothing."

---

## Phase 4 - Upgrade the kubeadm tool

> "Our lab HOLDS kubelet/kubeadm/kubectl so an unattended `apt upgrade` can never
> drift the cluster. So the pattern is surgical: unhold just kubeadm, install the
> exact patch, re-hold. After this the kubeadm TOOL is v1.35 - but the cluster
> COMPONENTS are still v1.34. kubeadm is just the instrument that does the upgrade next."

```bash
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm='1.35.0-1.1'      # match your madison patch
sudo apt-mark hold kubeadm
kubeadm version -o short                          # confirm: v1.35.x
```

---

## Phase 5 - Plan, then apply (the control plane becomes v1.35)

> "`kubeadm upgrade plan` is a dry run with teeth: it reads your current versions,
> confirms the target is one hop away, and prints exactly what it will bump -
> apiserver, controller-manager, scheduler, etcd, CoreDNS. Nothing changes yet."

```bash
sudo kubeadm upgrade plan
```

> "Then `apply` pulls the new static-pod manifests into `/etc/kubernetes/manifests`;
> the kubelet sees the changed files and restarts each control-plane container at
> v1.35. Certs renew automatically - that's the default of `upgrade apply`."

```bash
sudo kubeadm upgrade apply v1.35 -y
kubectl get nodes        # control1 STILL shows v1.34 here - expected, kubelet not done
```

> "SUCCESS means the control-plane COMPONENTS are v1.35. But the NODE still reports
> v1.34. That's the kubelet, and we haven't touched it yet."

> **CKA TIP:** `apply <version>` runs on the FIRST control plane only. Every other
> node - extra control planes AND workers - runs `kubeadm upgrade node`, no version
> arg. **Plan once, apply once, node everywhere else.**

---

## Phase 6 - Drain control1, upgrade its kubelet, uncordon

> "`drain` does two things: CORDON (mark the node unschedulable) and EVICT the
> running pods so they reschedule elsewhere. `--ignore-daemonsets` is mandatory
> because DaemonSet pods (kube-proxy, the CNI agent) run on every node and can't be
> evicted - without the flag, drain refuses. We drain BEFORE bumping the kubelet so
> no workload is disrupted while it restarts."

```bash
kubectl drain control1 --ignore-daemonsets
# control1 is tainted NoSchedule, so this is light. If it stalls on local data,
# add --delete-emptydir-data (same flag the workers use).

sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='1.35.0-1.1' kubectl='1.35.0-1.1'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet

kubectl uncordon control1
kubectl get nodes        # NOW control1 reports v1.35.x and Ready
```

> **CKA TIP (you WILL see this on camera):** drain may print a red line -
> `Cannot evict pod ... would violate the pod's disruption budget ... will retry
> after 5s` - on Calico's apiserver pods. **That is not an error.** Calico ships a
> PodDisruptionBudget (PDB) capping how many of its replicas can be down at once.
> `drain` RESPECTS the PDB, waits, and retries until eviction is safe, then prints
> `node/control1 drained`. PDBs are exactly what protects a real workload during
> maintenance - let it retry, don't panic.

*App auto-checkpoints `m02-after-control1` here - your control-plane-done rewind point.*

---

## Phase 7 - Upgrade the workers

> "Same arc, one difference: workers run `kubeadm upgrade node` instead of `apply` -
> the target version is already recorded in the cluster, so the worker just reads it
> and upgrades its local kubelet config. Watch the run-context: the repo / kubeadm /
> kubelet work runs ON the worker. But **drain and uncordon run from control1** - a
> kubeadm worker has no admin kubeconfig, so kubectl from the worker would just fail.
> This is the single most common live mistake."

**ON the worker** (`ssh vagrant@192.168.50.11`):

```bash
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm='1.35.0-1.1' && sudo apt-mark hold kubeadm
sudo kubeadm upgrade node                 # NOT apply
```

**FROM control1** (admin kubeconfig lives here):

```bash
kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data
```

**Back ON the worker** - bump kubelet, restart:

```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet='1.35.0-1.1' kubectl='1.35.0-1.1'
sudo apt-mark hold kubelet kubectl
sudo systemctl daemon-reload && sudo systemctl restart kubelet
```

**FROM control1** - uncordon:

```bash
kubectl uncordon worker1
```

> **CKA TIP:** if drain hangs, the answer is almost always the flags:
> `--ignore-daemonsets` (DaemonSet pods), `--delete-emptydir-data` (scratch volumes),
> `--force` (pods not managed by a controller).

Repeat the identical block for **worker2** (`192.168.50.12`). The app loops it for
you and checkpoints `m02-after-worker1` between them. On camera, narrate worker2 as
"same arc, no new concepts" and compress.

---

## Phase 8 - Verify the whole cluster is v1.35

> "The payoff. All three nodes Ready at v1.35, workloads never went down. One thing
> kubeadm did NOT touch: your CNI. kubeadm upgrades the core components and
> kube-proxy, but **Calico (the Tigera operator in this lab) is upgraded on its own
> schedule** per Calico's docs. Never assume the rolling upgrade moved your network plugin."

```bash
kubectl get nodes                          # all three: Ready, v1.35.x
kubectl get pods -A | grep -E 'globo-shop|kube-system|calico'
```

> **CKA TIP:** this cluster now sits at v1.35 - exactly where Module 3 begins. On the
> exam this is a high-value task you finish in minutes once the arc is muscle memory:
> repo, kubeadm, plan/apply, drain, kubelet, uncordon.

---

## Reset between takes

```powershell
# Full rewind to pristine v1.34 (the app does this automatically on launch):
.\Restore-CkaSnapshot.ps1 m02-pre-upgrade

# Or rewind to a node boundary the app checkpointed:
.\Restore-CkaSnapshot.ps1 m02-after-control1
.\Restore-CkaSnapshot.ps1 m02-after-worker1
```

---

Source of truth: [`Invoke-M02Upgrade.ps1`](../../../src/cka-lab/course-03-lifecycle-upgrades/Invoke-M02Upgrade.ps1).
Lab controls + snapshots: [`course-03-lifecycle-upgrades/README.md`](../../../src/cka-lab/course-03-lifecycle-upgrades/README.md).
