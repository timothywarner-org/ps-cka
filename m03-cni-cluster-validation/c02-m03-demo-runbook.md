# CKA Course 2 / Module 3 — Installing a CNI Plugin and Validating Cluster Health

**Target runtime:** 12-14 min on camera
**Environment:** Admin pwsh 7 on Windows 11 → `vagrant ssh control1` (Ubuntu 22.04)
**Lab:** **Hyper-V + Vagrant** — `src/cka-lab` with control1, worker1, worker2 on `192.168.50.10/.11/.12`
**Starting state:** `post-init-join` snapshot from Module 2 (control plane up, both workers joined, every node NotReady, CoreDNS Pending).
**Authoritative command source:** Deck slide 11 (YAML two-liner + DNS smoke test), slide 12 (Helm sidebar, if present), slide 13 (diagnostic ladder).
**Validator:** Six-point cluster validation checklist (slides 8 + 9) run end-to-end on camera.
**Cleanup between takes:** `cka-restore.ps1 post-init-join` rewinds in 60-90 sec. Snapshot to `post-cni-validation` at the end so the course closes from a known-good baseline.

> **YAML-first, with Helm as the production sidebar.** The CKA exam still tests `kubectl create -f` against the upstream Calico/Tigera manifests far more often than it tests Helm. So on camera, the primary command path is **two `kubectl create -f` lines** -- the same two lines the exam expects. Helm gets a focused 60-second sidebar showing the production-grade alternative (operator-managed, version-pinned, upgradeable cleanly), because v1.35 added Helm/Kustomize as a curriculum objective. **Slide 11 is the YAML command source. Slide 12 (if present) covers Helm.**

> **Lab path reminder:** This module uses the **Vagrant / Hyper-V** lab. The `cka-*.ps1` scripts (`cka-up`, `cka-status`, `cka-snapshot`, `cka-restore`, `cka-info`) are the Vagrant entry points. The `kind-*.ps1` scripts are for Course 1 only.

> **Course 2 design principle:** No `Start-TutorialMXX` wrapper. You type every command on the real Linux shell. That is the pedagogical bet for this whole course — and the break-and-fix exercise is the entire reason the course exists.

---

## Slide-to-demo map (glance here mid-take to stay on pace)

| Slides | Block | What you're teaching | Time |
|---|---|---|---|
| 1-3 | Open + Globomantics frame | Module 2 recap, four framing questions, Robert's "CIDR or die" warning | ~75 sec |
| 4-6 | LO 1 → **Demo 1** (CNI rationale + plugin comparison) | Why NotReady, why Calico, what a CNI does | ~2 min |
| 7-11 | LO 2 → **Demo 2** (YAML install + Helm sidebar + six-point validation) | `kubectl create -f` two-liner (primary, exam path), `helm install` (60-sec production sidebar), NotReady → Ready, busybox:1.28 DNS test, explicit cross-node pod ping | ~5.5 min |
| 12-13 | LO 3 → **Demo 3** (break-and-fix) | Stop kubelet, walk the diagnostic ladder, recover | ~2-3 min |
| 14 | Demo transition | "Time to put it into practice" | 10 sec |
| 15 | Globomantics checkout | Robert signs off — cluster green, workload serving | ~30 sec |
| 16-17 | From Globomantics to you + course wrap | Four takeaways → end of Course 2 | ~45 sec |
| 18 | Closing slide | Thank you + Course 3 cliffhanger | ~15 sec |

---

## Pre-flight (run these BEFORE hitting record)

**Run from admin pwsh 7 on Windows.** Every line is a literal command. Type or paste in order.

### Step 0 — Open admin pwsh and `cd` to the lab

```powershell
cd C:\github\ps-cka\src\cka-lab
```

### Step 1 — Restore the Module 2 finish line

```powershell
.\cka-restore.ps1 post-init-join
```

Atomic restore across all three VMs. ~60-90 sec. Three nodes registered, all NotReady, CoreDNS Pending. **Every recording of M3 starts here.**

### Step 2 — Confirm the post-init-join state is clean

```powershell
.\cka-status.ps1
vagrant ssh control1 -c "kubectl get nodes; kubectl get pods -n kube-system | head -8"
```

**Must show:** three nodes NotReady, four control-plane static pods Running, CoreDNS Pending, kube-proxy ContainerCreating. If anything is different, the snapshot drifted — rebuild.

### Step 3 — Snapshot the pre-record state

```powershell
.\cka-snapshot.ps1 pre-record-m3
```

A failed take = `.\cka-restore.ps1 pre-record-m3` in ~60-90 sec.

### Step 4 — Dry-run the demo OFF camera

```powershell
vagrant ssh control1
```

Inside control1, walk Demos 1-3. Confirm Helm is installed (`helm version` should print a v3.x version), confirm `busybox:1.28` image pulls cleanly, confirm `journalctl -u kubelet` reads. Then `exit` and restore the snapshot.

### Camera checklist (final scan before recording)

- [ ] Admin pwsh, font 16pt+, 140 cols wide, prompt trimmed
- [ ] `.\cka-info.ps1` shows all 3 nodes **UP** with their `.10/.11/.12` IPs
- [ ] `kubectl get nodes` from control1 shows three NotReady — the correct starting state
- [ ] `helm version` returns v3.x+ on control1 (the Vagrantfile provisioner installed it)
- [ ] Only one terminal window visible — no chat apps, no notifications
- [ ] Screen recorder set to 1080p, no HiDPI blur, no taskbar
- [ ] Deck slides 8, 9, 11, 12 (validation checklist + YAML install + Helm sidebar) open on second monitor

---

## Click path (the exact ENTER sequence — high level)

1. `vagrant ssh control1` → ENTER → land at `vagrant@control1:~$`
2. **Demo 1** — `kubectl describe node control1 | grep -A5 Conditions` (show NetworkPluginNotReady)
3. **Demo 2a** — `kubectl create -f tigera-operator.yaml` + `kubectl create -f custom-resources.yaml` (the exam path, primary on camera); then 60-sec on-camera Helm sidebar showing the production alternative (don't run, just narrate)
4. **Demo 2b** — `kubectl get nodes -w` (watch NotReady → Ready, ~30 sec) → Ctrl+C
5. **Demo 2c** — Six-point validation: `kubectl get nodes` / `kubectl get pods -A` / busybox:1.28 nslookup / cross-node ping / `kubectl cluster-info`
6. **Demo 3a** — `exit` → `vagrant ssh worker1` → `sudo systemctl stop kubelet` → `exit`
7. **Demo 3b** — `vagrant ssh control1` → `kubectl get nodes -w` (watch worker1 go NotReady, ~40 sec) → Ctrl+C
8. **Demo 3c** — `exit` → `vagrant ssh worker1` → `sudo journalctl -u kubelet -n 20` → `sudo systemctl start kubelet` → `exit`
9. **Demo 3d** — `vagrant ssh control1` → `kubectl get nodes` (worker1 Ready again)
10. **Demo 4** — `kubectl create deployment nginx --image=nginx --replicas=3` → `kubectl expose deployment nginx --type=NodePort --port=80` → `curl` test
11. `exit` → `.\cka-snapshot.ps1 post-cni-validation`

**Total ENTERs:** ~30 across the whole module. Slow is smooth, smooth is fast.

**Why kubectl as the vagrant user (no `sudo -i`):** kubectl reads `~/.kube/config`, which Module 2 already chowned to the vagrant user. Adding `sudo -i` here would point kubectl at root's empty config.

**Pedagogical frame for the open:** "Module 2 left us with three NotReady nodes and a Pending CoreDNS. Robert's monitoring dashboard is on fire and nothing is actually broken — we just haven't installed a CNI yet. The fix is two `kubectl create -f` lines against the upstream Tigera manifests, plus thirty seconds of patience. Then we validate every layer, deliberately break one node to practice the diagnostic ladder the CKA exam grades you on, and deploy our first real workload."

---

## Open — slides 1-3 (~75 sec)

**Verbatim talk track:**

> "Three nodes from Module 2, all NotReady. CoreDNS Pending. Robert at Globomantics is watching every alert in his dashboard go red. **None of this is actually broken** — we just haven't installed the CNI plugin yet. The fix is two `kubectl create -f` lines against the upstream Tigera manifests — the same path the CKA exam typically hands you. The risk is the same risk Diana flagged in Module 2: pod CIDR mismatch. Our `init.yaml` set `192.168.0.0/16` — Calico's default — so we're aligned. **The CKA exam loves to trap candidates on the CIDR alignment question, so we're going to prove it on camera.**"

**Slide 2 — Four framing questions:** read each beat-by-beat, don't pre-answer.
**Slide 3 — Globomantics check-in:** read Robert's quote in character. Monitoring team lead. The CIDR warning lands hardest.

---

## Demo 1 — Show why the cluster is NotReady (1 min)

**Goal:** Prove that NotReady is not random. It's a specific kubelet condition we can read, name, and resolve.

### Step 1.0 — Prove the pod CIDR alignment on camera (15 sec)

```bash
sudo grep -E "podSubnet|serviceSubnet" /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null \
  || kubectl -n kube-system get cm kubeadm-config -o yaml | grep -E "podSubnet|serviceSubnet"
```

**Expected** (one of these surfaces; either is sufficient proof):

```text
podSubnet: 192.168.0.0/16
serviceSubnet: 10.96.0.0/12
```

**Narrate:** "**Diana's CIDR warning, now proven on camera.** kubeadm wrote `192.168.0.0/16` into the cluster config -- that's the pod CIDR. Calico's default Installation custom resource uses the same `192.168.0.0/16`. **Aligned.** If these two values ever disagreed, pods would get IPs from one range and Calico would route the other range, and you'd spend an exam-stressed hour chasing the wrong fault. **One grep, fifteen seconds, exam insurance.**"

### Step 1.1 — Show the node condition that's blocking Ready

```bash
kubectl describe node control1 | grep -A 8 "Conditions:"
```

**Expected (relevant rows):**

```
Type             Status  Reason                    Message
----             ------  ------                    -------
Ready            False   KubeletNotReady           container runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:Network plugin returns error: cni plugin not initialized
```

**Windows lens:** `kubectl describe` is the equivalent of `Get-ADComputer -Identity X -Properties *` — fully expanded property output for one resource, including event history. Use it whenever `kubectl get` doesn't tell you enough.

**What `NetworkPluginNotReady` actually means:** The kubelet starts in a "not ready" state by default and ticks boxes as each subsystem reports healthy. One of those boxes is "is there a CNI binary in `/opt/cni/bin/` and a valid config in `/etc/cni/net.d/`?" Until a CNI plugin drops those files in place, the kubelet refuses to mark the node Ready, which means the scheduler refuses to place pods on it. That is why every node looks broken and nothing is actually broken.

**Narrate:** "**`NetworkPluginNotReady`** in plain English. The kubelet's readiness checklist has one unticked box: it cannot find a CNI plugin. Not a runtime problem, not a certificate problem, not a kubelet bug, just an unfilled dependency. **One install fixes every NotReady node at once.**"

### Step 1.2 — Confirm CoreDNS is Pending for the same reason

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

**Expected:** two CoreDNS pods, both **Pending**, no pod IPs assigned.

**Narrate:** "CoreDNS is a Deployment that needs a pod IP to start. No CNI, no IP, no CoreDNS. **Same root cause, different symptom.** Service discovery is offline until we fix the CNI."

---

## Demo 2 — Helm install Calico and watch nodes go Ready (4-5 min)

**Goal:** Install Calico via Helm + Tigera operator, watch the transition, then run the six-point validation checklist.

### Step 2.1 — Confirm the manifest URLs are reachable (5 sec)

```bash
curl -sI https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/tigera-operator.yaml | head -1
```

**Expected:** `HTTP/2 200`. The Tigera v3.32.0 manifests are reachable. Helm repo refresh is moved to the sidebar (Step 2.2b).

**Narrate:** "**One curl headers check.** Two manifest URLs, both pinned to Tigera v3.32.0. Reproducible across every recording, every learner, every exam VM."

### Step 2.2a — Install Calico via the upstream manifests (the exam path)

**This is the primary on-camera command path. The CKA exam typically hands you the upstream `kubectl create -f` URLs, so this is the muscle memory you actually need.**

```bash
# Step 1: install the Tigera operator + every CRD it manages
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/tigera-operator.yaml

# Step 2: declare the Installation custom resource (this is what the operator watches for)
# Default custom-resources.yaml ships with calicoNetwork.ipPools[0].cidr = 192.168.0.0/16,
# which exactly matches the kubeadm init podSubnet we proved in Step 1.0.
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/custom-resources.yaml
```

**Windows lens - what is an "operator"?:** A Kubernetes operator is a long-running pod that watches for a specific custom resource and reconciles cluster state to match it. The closest Windows analog is a **watchdog Windows Service** (think the WMI provider host) that exists only to manage other things, not to do work itself. Concretely: the **Tigera operator pod** sits in the `tigera-operator` namespace, watches for an `Installation` custom resource named `default`, and when that CR exists it rolls out the `calico-node` DaemonSet, `calico-kube-controllers` Deployment, and `calico-typha` Deployment on your behalf. You declare *what* you want (the CR). The operator figures out *how* to get there. **This is the same pattern Course 11 covers for CRDs and operators in depth.**

**Windows lens on `kubectl create -f <url>`:** This is the Linux/Kubernetes equivalent of `Install-Package -Source <url>` on Windows -- fetch the manifest, apply it, no package manager in the middle. **Use `create` not `apply` here** because the operator manifest declares CRDs that must be created before any CR that references them; `apply` works too but `create` is the documented Tigera path.

**Narrate -- slow down on the version pin:** "**`v3.32.0` in the URL is the exam-day discipline.** A bare `latest` URL grabs whatever ships today, which means tomorrow's recording uses a different Calico version than today's. Pin the manifest version in the path. Reproducibility is worth ten characters of typing."

### Demo 2a money shot (verbatim — say this)

> "**Two `kubectl create -f` lines. That's the install.** The first line drops the Tigera operator and its CRDs into the cluster. The second line declares the Installation custom resource the operator is watching for. The operator reconciles -- rolls out `calico-node` as a DaemonSet, `calico-kube-controllers` as a Deployment -- and every node ticks the last unticked box on its readiness checklist. **This is the path the CKA exam grades you on. Memorize the two URLs.**"

### Step 2.2b — Helm sidebar: the production-grade alternative (~60 sec on camera)

**Don't run this on camera -- just show it on the second-monitor reference and read the narrate beat.** The exam path is the YAML two-liner above. Helm is what you reach for in production at Globomantics: operator-managed, version-pinned in a values file, upgradeable cleanly, rollback-friendly. The v1.35 curriculum added Helm/Kustomize for cluster components as an objective, so you need to recognize this path too.

```bash
# Same Tigera operator, wrapped in a Helm chart.
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update

helm install calico projectcalico/tigera-operator --version v3.32.0 \
  --namespace tigera-operator --create-namespace
```

**Windows lens:** Helm is the Kubernetes package manager. The closest Windows analog is `winget` or `Chocolatey` -- a CLI that fetches versioned application bundles from a remote index and installs them with one command. `helm repo add` is the equivalent of `winget source add`.

**YAML vs Helm decision matrix:**

| Situation | YAML (`kubectl create -f`) | Helm |
|---|---|---|
| CKA exam question with curl URLs | Yes | Rare |
| CKA exam question that says "use Helm" | Possible | Yes |
| Air-gapped cluster (no chart repo reachable) | Works with a pre-staged YAML | Needs `helm pull` workaround |
| Cluster where Helm isn't installed at all | Works immediately | Install Helm first |
| Tracking version drift across many clusters | Filename version pin | Chart version pin + values file |
| Globomantics production teaching standard | Acceptable | Preferred |

**On-camera narrate beat (verbatim):**

> "**This is what you'll do in production at Globomantics. The CKA exam will still hand you the `kubectl create -f` URLs from Step 2.2a -- know both, default to YAML on the exam.** Helm wraps the same two objects in a chart, adds a values file you can pin in Git, and gives you `helm upgrade` and `helm rollback` for free. For the exam, you want the muscle memory of the two `kubectl create -f` URLs. For production, you want this."

### Step 2.3 — Watch nodes transition from NotReady to Ready

```bash
# Brief pause so the Tigera operator can reconcile -- keeps the watch screen lively, not dead
kubectl -n tigera-operator wait --for=condition=Ready pod -l name=tigera-operator --timeout=90s

# Now watch nodes flip NotReady -> Ready
kubectl get nodes -w
```

**What to show on camera (~30-60 sec):**

```
NAME       STATUS     ROLES           AGE   VERSION
control1   NotReady   control-plane   8m    v1.35.x
worker1    NotReady   <none>          5m    v1.35.x
worker2    NotReady   <none>          5m    v1.35.x
control1   Ready      control-plane   9m    v1.35.x       ← first transition
worker1    Ready      <none>          6m    v1.35.x
worker2    Ready      <none>          6m    v1.35.x
```

Press **Ctrl+C** when all three say Ready.

**Windows lens:** The `-w` watch flag streams updates as they happen — equivalent to `Get-EventLog -Newest 1 -Wait` or any tail-style PowerShell loop. It's how you observe cluster changes in real time without polling.

**Narrate:** "**One wait, then watch.** The Tigera operator has to be Ready before it rolls out the calico-node DaemonSet. This `wait` line trades 5 seconds of clean transition for 30 seconds of black-screen confusion. **On camera, pacing IS pedagogy.** Then the magic moment: as soon as the Calico DaemonSet finishes rolling out one pod per node, the kubelet on each node ticks the last unticked box on its readiness checklist. All three nodes flip to Ready within seconds of each other."

### Step 2.4 — Verify Calico's own pods are healthy

```bash
kubectl get pods -n calico-system -o wide
```

**Expected (note the `NODE` column -- one `calico-node` per node, visually verifiable):**

```
NAME                            READY   STATUS    RESTARTS   AGE   IP              NODE       NOMINATED NODE   READINESS GATES
calico-kube-controllers-...     1/1     Running   0          90s   192.168.x.x     worker1    <none>           <none>
calico-node-...                 1/1     Running   0          90s   192.168.50.10   control1   <none>           <none>
calico-node-...                 1/1     Running   0          90s   192.168.50.11   worker1    <none>           <none>
calico-node-...                 1/1     Running   0          90s   192.168.50.12   worker2    <none>           <none>
calico-typha-...                1/1     Running   0          90s   192.168.50.11   worker1    <none>           <none>
```

**Narrate:** "**`-o wide` adds the NODE column so you can visually confirm the DaemonSet shape.** Three `calico-node` pods, one each on control1, worker1, worker2 -- that's the DaemonSet pattern, the same shape as kube-proxy. `calico-kube-controllers` is the single controller Deployment that manages BGP and IPAM state. **Operator-managed, version-pinned, upgradeable cleanly.**"

### Step 2.5 — Six-point cluster validation (the exam-day checklist)

**Six discrete checks, each one a different layer of the stack.** Run them in order. Each layer being green proves the previous layer is also green.

| # | Layer being validated | Command shape |
|---|---|---|
| 1 | Kubelet readiness on every node | `kubectl get nodes` |
| 2 | Control-plane and DNS pods | `kubectl get pods -n kube-system` |
| 3 | CoreDNS service discovery from inside a pod | `kubectl run` busybox + `nslookup` |
| 4 | API server + service endpoint addresses | `kubectl cluster-info` |
| 5 | Cluster-wide pod health | `kubectl get pods -A` filtered |
| 6 | Cross-node pod-to-pod routing | Two pinned pods + ping |

#### Check 1 - All nodes Ready

```bash
kubectl get nodes
```

**Expected:**

```
NAME       STATUS   ROLES           AGE   VERSION
control1   Ready    control-plane   12m   v1.35.x
worker1    Ready    <none>          9m    v1.35.x
worker2    Ready    <none>          9m    v1.35.x
```

**Pass criteria:** All three nodes `Ready`. Anything else, stop and jump to Demo 3's diagnostic ladder.

#### Check 2 - All kube-system pods Running

```bash
kubectl get pods -n kube-system
```

**Expected (every pod Running, zero Pending):**

```
NAME                                READY   STATUS    RESTARTS   AGE
coredns-...                         1/1     Running   0          12m
coredns-...                         1/1     Running   0          12m
etcd-control1                       1/1     Running   0          12m
kube-apiserver-control1             1/1     Running   0          12m
kube-controller-manager-control1    1/1     Running   0          12m
kube-proxy-...                      1/1     Running   0          12m
kube-proxy-...                      1/1     Running   0          9m
kube-proxy-...                      1/1     Running   0          9m
kube-scheduler-control1             1/1     Running   0          12m
```

**Pass criteria:** Nothing in Pending, CrashLoopBackOff, or ContainerCreating. CoreDNS flipped from Pending to Running the moment CNI installed, that's the leading indicator.

#### Check 3 - CoreDNS resolves names from inside a pod

```bash
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never \
  -- nslookup kubernetes.default
```

**Expected:**

```
Server:    10.96.0.10
Address:   10.96.0.10:53

Name:      kubernetes.default
Address:   10.96.0.1
```

**Narrate, the money beat:** "**`10.96.0.10` is the CoreDNS Service ClusterIP. `10.96.0.1` is the API server's internal service IP.** Seeing both addresses echoed back proves the entire chain is healthy: kubelet schedules the test pod, Calico assigns it an IP, kube-proxy programs the iptables rules, CoreDNS receives the query, the cluster's service registry answers. **Five layers, one nslookup. If this works, the cluster works.**"

#### Check 4 - Cluster-info reports the control plane endpoints

```bash
kubectl cluster-info
```

**Expected:**

```
Kubernetes control plane is running at https://k8s.globomantics.local:6443
CoreDNS is running at https://k8s.globomantics.local:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

**Pass criteria:** Both URLs print. Note the `k8s.globomantics.local` hostname, that's the `controlPlaneEndpoint` you set in Module 2's `init.yaml` paying off here. If you see `192.168.50.10` instead, controlPlaneEndpoint was empty during `kubeadm init` and Course 3's HA conversion will cost you a certificate reissue.

#### Check 5 - No stuck pods anywhere in the cluster

```bash
kubectl get pods -A | grep -vE 'Running|Completed' || echo "All pods healthy"
```

**Expected (just the header row, no data rows):**

```
NAMESPACE      NAME   READY   STATUS   RESTARTS   AGE
```

**Pass criteria:** Only the header row prints. Any data row is a pod that's not Running or Completed and that's your investigation target.

#### Check 6 - Cross-node pod-to-pod connectivity (the one that actually proves routing)

**This is the only check that proves packets move between nodes.** Node Ready status says "kubelet is happy." A successful ping says "Calico's BGP / IP-in-IP mesh actually works." The CKA exam tests this directly.

Four sub-steps. Don't skip the wait, `kubectl run` returns before the pod has a pod IP assigned.

##### Step 6a - Pin pod-w1 to worker1

```bash
kubectl run pod-w1 --image=busybox:1.28 --restart=Never \
  --overrides='{"spec":{"nodeName":"worker1"}}' \
  --command -- sleep 600
```

**Expected (one line):**

```
pod/pod-w1 created
```

##### Step 6b - Wait for Ready, then capture pod-w1's IP into a shell variable

```bash
kubectl wait --for=condition=Ready pod/pod-w1 --timeout=30s
POD_W1_IP=$(kubectl get pod pod-w1 -o jsonpath='{.status.podIP}')
echo "pod-w1 IP on worker1: $POD_W1_IP"
```

**Expected:**

```
pod/pod-w1 condition met
pod-w1 IP on worker1: 192.168.X.X
```

**Pass criteria:** The IP must fall inside `192.168.0.0/16`, that's Calico's pod CIDR (matches Module 2's `init.yaml`). If the IP is in a different range, the CIDR alignment failed and you'll see broken routing in Step 6c.

##### Step 6c - Spawn a one-shot pod on worker2 and ping pod-w1

```bash
kubectl run pod-w2 --image=busybox:1.28 --restart=Never \
  --overrides='{"spec":{"nodeName":"worker2"}}' \
  --rm -it --command -- ping -c 3 $POD_W1_IP
```

**Expected (3 echo replies, low single-digit ms latency):**

```
PING 192.168.X.X (192.168.X.X): 56 data bytes
64 bytes from 192.168.X.X: seq=0 ttl=62 time=1.2 ms
64 bytes from 192.168.X.X: seq=1 ttl=62 time=0.9 ms
64 bytes from 192.168.X.X: seq=2 ttl=62 time=0.8 ms

--- 192.168.X.X ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
```

**Pass criteria:** `0% packet loss`. Any loss means CNI is up but routing is broken, most likely a firewall or BGP peering issue (Course 9 territory).

##### Step 6d - Clean up the pinned pod

pod-w2 self-deletes via `--rm`. pod-w1 stays running because we didn't `--rm` it (we needed it as the ping target).

```bash
kubectl delete pod pod-w1
```

**Narrate, the exam beat:** "**The CKA exam grades you on this exact test.** A node Ready status doesn't prove pods can talk; only an actual ping does. Pin two pods to different nodes, capture one IP, ping it from the other. **Three echo replies, cross-node routing confirmed.**"

---

**Windows lens on `kubectl run --rm -it --restart=Never`:** This is the equivalent of running a one-shot container interactively, the same idea as `docker run --rm -it`, but the container runs as a Kubernetes Pod scheduled by the cluster. `--rm` deletes the pod on exit, `-it` attaches an interactive TTY, `--restart=Never` makes it a Pod (not a Job or Deployment).

**What the `--overrides` JSON is doing:** `kubectl run` builds a Pod spec for you. `--overrides` lets you splice raw JSON into that spec before it's submitted to the API. The JSON `{"spec":{"nodeName":"worker1"}}` merges into the generated PodSpec and pins the pod to `worker1`, the same as writing `spec.nodeName: worker1` in a YAML manifest. **It's the one-liner alternative to writing a full Pod YAML just to set one field.** PowerShell analog: think of it as splatting a hashtable onto a cmdlet to override one parameter without rewriting the whole call.

### Demo 2 money shot (verbatim — say this)

> "Six checks, thirty seconds of typing, and you have proven the cluster is healthy end to end. **This is the same checklist you run on the exam after any infrastructure change.** Owning it is the difference between a verification question that takes two minutes and one that takes fifteen."

### Demo 2 exam tip — `busybox:1.28` (verbatim)

> "Pin `busybox:1.28` for every in-cluster DNS test. Later versions ship a broken `nslookup` that returns success even when DNS is misconfigured — and that lie costs you the question on the exam. **The pin is the exam-safe choice. Memorize the tag.**"

---

## Demo 3 — Break it, diagnose it, fix it (2-3 min)

**Goal:** Practice the troubleshooting ladder on a real failure. Stop the kubelet on worker1, walk the diagnostic ladder, recover.

### Step 3.1 — Stop the kubelet on worker1

```bash
exit   # leave control1
```

```powershell
vagrant ssh worker1
```

Inside worker1:

```bash
sudo systemctl stop kubelet
```

**Windows lens:** `systemctl stop` is the equivalent of `Stop-Service -Name kubelet` on Windows. systemd is the service controller (the rough equivalent of the Windows Service Control Manager), and `systemctl` is its CLI.

```bash
exit   # leave worker1
```

### Step 3.2 — Watch worker1 transition through the failure states

```powershell
vagrant ssh control1
```

Inside control1:

```bash
kubectl get nodes -w
```

**What to show on camera (~60 sec):**

```
NAME       STATUS   ROLES           AGE     VERSION
worker1    Ready    <none>          12m     v1.35.x
worker1    Ready    <none>          12m     v1.35.x       ← last heartbeat
worker1    Unknown  <none>          13m     v1.35.x       ← ~40 sec later
worker1    NotReady <none>          13m     v1.35.x       ← shortly after
```

Press **Ctrl+C** when worker1 reads NotReady.

**Narrate:** "**Kubelet sends a heartbeat every 10 seconds.** The controller manager waits 40 seconds (the `--node-monitor-grace-period` default in v1.35) before flipping the node to Unknown, and then a bit longer before the status reads NotReady. Once it's NotReady the scheduler stops sending it new pods. **This is the default failure-detection budget on every Kubernetes cluster, and the exam expects you to know the 40-second number.**"

### Step 3.3 — Walk the diagnostic ladder

This is the exam-graded workflow. Hit every rung on camera. **Each rung answers one specific question; climb until the failure is obvious.**

| Rung | Where you are | Question it answers |
|---|---|---|
| 1 | Cluster API view | Does the resource look healthy at the surface? |
| 2 | Cluster API view | What does the cluster say is wrong? |
| 3 | Switch context | (transition rung — leave cluster view, drop to node) |
| 4 | Node host shell | Is the service even running? |
| 5 | Node host shell | What did the service say before it died? |

#### Rung 1 - `kubectl get` (surface status)

```bash
kubectl get nodes
```

**Expected:**

```
NAME       STATUS     ROLES           AGE   VERSION
control1   Ready      control-plane   ...   v1.35.x
worker1    NotReady   <none>          ...   v1.35.x
worker2    Ready      <none>          ...   v1.35.x
```

**What this tells you:** one node is NotReady. Doesn't yet say *why*. Climb to Rung 2.

#### Rung 2 - `kubectl describe` (conditions + events)

```bash
kubectl describe node worker1 | head -40
```

**Expected (the rows that matter):**

```
Conditions:
  Type     Status   Reason              Message
  ----     ------   ------              -------
  Ready    Unknown  NodeStatusUnknown   Kubelet stopped posting node status

Events:
  Type     Reason         Age   From             Message
  ----     ------         ----  ----             -------
  Normal   NodeNotReady   ...   node-controller  Node worker1 status is now: NodeNotReady
```

**What this tells you:** the kubelet stopped phoning home. You now know *which* subsystem stopped responding. Cluster API view exhausted, climb to Rung 3.

**Narrate:** "**Describe gives you the why.** `Kubelet stopped posting node status` is the cluster telling you exactly which subsystem stopped responding. You don't need to guess."

#### Rung 3 - Switch from cluster view to node host shell

```bash
exit
```

```powershell
vagrant ssh worker1
```

You're now inside worker1's host shell. The next two rungs run on the node itself, not against the API server.

#### Rung 4 - `systemctl status` (is the service even running?)

```bash
sudo systemctl status kubelet --no-pager
```

**Expected (the line that matters):**

```
● kubelet.service - kubelet: The Kubernetes Node Agent
     Loaded: loaded (/lib/systemd/system/kubelet.service; enabled; preset: enabled)
     Active: inactive (dead) since Wed 2025-05-15 14:23:45 UTC; 2min ago
```

**What this tells you:** kubelet is `inactive (dead)`, not crashing or restarting. **`inactive (dead)`** is the smoking-gun keyword for a manual stop or a clean exit. If it had said `activating (auto-restart)`, the failure mode would be a config-driven crash loop instead, and you'd dig into `/var/lib/kubelet/config.yaml` or the drop-in unit file at `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf`.

#### Rung 5 - `journalctl` (what did the service say before it died?)

```bash
sudo journalctl -u kubelet -n 20 --no-pager
```

**Expected (the last line is the smoking gun):**

```
...
May 15 14:23:45 worker1 systemd[1]: Stopping kubelet.service - kubelet: The Kubernetes Node Agent...
May 15 14:23:45 worker1 systemd[1]: kubelet.service: Deactivated successfully.
May 15 14:23:45 worker1 systemd[1]: Stopped kubelet.service - kubelet: The Kubernetes Node Agent.
```

**What this tells you:** the service was stopped cleanly, no panic, no OOM kill, no cgroup error. In production this is where you'd see the real failures: `failed to start container`, `disk pressure`, `cgroup driver mismatch`, `cni config uninitialized`. **The point is the workflow, not the specific failure.**

**Windows lens:** `journalctl` is the Linux equivalent of `Get-WinEvent -LogName System -MaxEvents 20` filtered to one service. The `-u kubelet` flag scopes it to the kubelet unit; `-n 20` limits output to the last 20 lines.

**Narrate, the ladder summary (keep it tight, the exam tip below expands the rung list):** "**Cluster view first, then drop to the node.** Get and describe live in `kubectl`. systemctl and journalctl live on the host. Climb in that order. Never skip rungs."

### Step 3.4 — Recover

```bash
sudo systemctl start kubelet
sudo systemctl status kubelet --no-pager | head -5
```

**Expected:** `Active: active (running)`. The kubelet is back.

```bash
exit   # leave worker1
```

### Step 3.5 — Verify the node returns to Ready

```powershell
vagrant ssh control1
```

```bash
kubectl get nodes -w
```

**Expected within 30-60 seconds:**

```
worker1    NotReady   <none>   14m   v1.35.x
worker1    Ready      <none>   14m   v1.35.x       ← back to Ready
```

Ctrl+C. Done.

### Demo 3 money shot (verbatim — say this)

> "**Identify, diagnose, fix, verify.** Four steps, every troubleshooting question on the CKA exam follows this shape. `kubectl get` identifies the failed resource. `kubectl describe` plus `journalctl` diagnose the failure mode. `systemctl start` (or the equivalent corrective action) is the fix. `kubectl get` again verifies. **Practice the loop on a real Linux shell, not by reading about it.**"

### Demo 3 exam tip — the ladder (verbatim)

> "Memorize the diagnostic ladder in order: **`kubectl get`, `kubectl describe`, `kubectl logs`, `kubectl get events`, `journalctl -u <service>`, `crictl ps`/`crictl logs`.** Top-down. Each rung tells you whether to climb further. Most exam questions resolve at rung two or three. Some need rung five or six. **None ever need you to skip rungs.**"

---

## Demo 4 — Deploy a real workload (1 min)

**Goal:** Prove the cluster can carry actual traffic. nginx, three replicas, exposed via NodePort.

### Step 4.1 — Create the Deployment and Service

```bash
kubectl create deployment nginx --image=nginx:1.27 --replicas=3
kubectl expose deployment nginx --type=NodePort --port=80
kubectl get pods -l app=nginx -o wide
kubectl get svc nginx
```

**Windows lens:** A Kubernetes `Deployment` is the equivalent of a Windows Service Fabric application with a target replica count — the controller maintains the desired state, restarting or rescheduling pods as needed. A `NodePort` Service opens a TCP port on every node in the cluster, equivalent to a Windows Firewall rule plus a port-forwarding mapping.

**Expected pod placement:** three nginx pods, ideally one per node (scheduler-driven, not guaranteed). Each pod has an IP from the `192.168.0.0/16` pod CIDR.

**Expected service:** `nginx   NodePort   10.X.X.X   <none>   80:30XXX/TCP`. The `30XXX` is the random NodePort in the 30000-32767 range.

### Step 4.2 — Hit the service from the control-plane node

```bash
NODEPORT=$(kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort is $NODEPORT"
curl -sI http://192.168.50.10:$NODEPORT | head -1
curl -sI http://192.168.50.11:$NODEPORT | head -1
curl -sI http://192.168.50.12:$NODEPORT | head -1
```

**Expected:** three `HTTP/1.1 200 OK` responses. **One NodePort, every node responds — that's kube-proxy's load-balancing at work.**

**Narrate:** "**One NodePort. Three nodes. Three 200 OKs.** The Service abstraction handles the routing — kube-proxy programmed iptables (or IPVS) rules on every node, so a request hitting any node's IP on that port reaches one of the three nginx pods regardless of which node it lives on. **That's a fully working cluster.**"

### Demo 4 money shot (verbatim — say this)

> "**This is what production-ready means.** Three nodes Ready. CNI assigning pod IPs from `192.168.0.0/16`. CoreDNS resolving service names. **Calico's NetworkPolicy enforcement is sitting right there, dormant, waiting for Course 8 to switch it on with a single `kind: NetworkPolicy` manifest.** NodePort serving HTTP. **Robert's monitoring dashboard goes green and the Globomantics rollout is on track.**"

**Why Calico, not Flannel, for this skill path:** Flannel is simpler but it does not enforce NetworkPolicy. Calico does. The CKA exam tests NetworkPolicy directly in the workloads-and-scheduling domain, and Course 8 of this skill path walks you through writing one. **Picking Calico in Module 3 is what makes Course 8 possible.**

---

## Snapshot + slides 15-18 + close (~75 sec)

### Step 5.1 — Clean up the demo workload and snapshot

```bash
kubectl delete deployment nginx
kubectl delete svc nginx
exit
```

```powershell
.\cka-snapshot.ps1 post-cni-validation
```

**Snapshot narration (verbatim):**

> "Atomic Hyper-V checkpoint across all three VMs, named `post-cni-validation`. **This is the finish line for Course 2.** Three nodes Ready, CNI installed, CoreDNS resolving, troubleshooting ladder rehearsed. Course 3 picks up from here when we replace this single control plane with three control planes behind a load balancer."

### Slide 15 — Globomantics checkout (~30 sec)

Read Robert's quote in character. Monitoring dashboard green. Cluster validated. nginx served. **The intentional break-and-fix is the part that costs candidates the exam if they only watch happy-path demos.**

### Slide 16 — From Globomantics to you (~45 sec)

Read the four takeaways off the slide and **add the exam framing** on each:

1. **CNI is what makes nodes Ready.** Every NotReady-after-init question on the exam is "install or fix the CNI." Don't overthink it.
2. **Calico is the CKA default for a reason.** NetworkPolicy enforcement, `192.168.0.0/16` default CIDR matching kubeadm out-of-the-box, and **the exam typically hands you the upstream `kubectl create -f` URLs** -- so default to YAML on the exam and reach for Helm in production.
3. **Validate every layer after infrastructure changes.** The six-point checklist is the exam's verification surface. Own it.
4. **Break it on purpose to build troubleshooting muscle.** Thirty percent of the exam. The diagnostic ladder is the same workflow for every failure.

### Slide 17 — Course 2 wrap (~30 sec)

Three modules. Module 1 prepared infrastructure. Module 2 bootstrapped the cluster with kubeadm. Module 3 installed the CNI and validated. **Roughly forty percent of the CKA exam surface, covered.** The remaining courses build on the cluster you just stood up.

### Slide 18 — Closing (~15 sec, verbatim)

> "That closes Course 2: Installing Clusters with kubeadm. Three bare Ubuntu VMs became a fully validated, traffic-serving Kubernetes cluster. **In Course 3 we replace this single control plane with a highly available three-node control plane behind HAProxy — and you'll see exactly why setting `controlPlaneEndpoint` in Module 2 was worth ten seconds of typing.** I'm Tim Warner. See you there."

---

## Reset between takes

Every command in this module is idempotent against `helm uninstall` plus `kubectl delete`, but the cleanest path is to restore the snapshot.

### Fast rewind (most common)

```powershell
.\cka-restore.ps1 pre-record-m3
```

~60-90 sec. Back to the pre-record baseline (post-init-join from Module 2).

### Uninstall Calico without snapshot (slower path)

```bash
helm uninstall calico -n tigera-operator
kubectl delete namespace calico-system calico-apiserver tigera-operator
kubectl delete crd $(kubectl get crd | grep -E 'calico|tigera' | awk '{print $1}')
```

Then restore Module 2's post-init-join snapshot for a clean restart.

### Snapshot library to build during dry-runs

```powershell
.\cka-snapshot.ps1 pre-record-m3        # baseline before each M3 take
.\cka-snapshot.ps1 post-cni-validation  # after Demo 4 — Course 3's starting point
```

---

## Recovery cheat sheet

| Symptom | Likely cause | Fix |
|---|---|---|
| `helm install` fails with "context deadline exceeded" | API server slow during startup | Wait 15 seconds, retry — first install after restore is slowest |
| Nodes stay NotReady more than 2 min after Calico install | `calico-node` pod failing on a specific node | `kubectl get pods -n calico-system -o wide` to find the bad node, then `kubectl logs -n calico-system calico-node-XXX` |
| CoreDNS stays Pending after Calico installs | Pod CIDR mismatch | Run `kubectl get installation default -o yaml` and look for the `cidr:` line -- must show `192.168.0.0/16`. If not, kubeadm init used wrong CIDR, must re-init cluster |
| `nslookup kubernetes.default` returns SERVFAIL | CoreDNS pod crashloop | `kubectl logs -n kube-system -l k8s-app=kube-dns` |
| `nslookup` returns success but wrong IP | Used wrong busybox tag (e.g., `latest`) | Always pin `busybox:1.28` for DNS tests |
| `kubectl get nodes -w` doesn't update | Cluster API server overloaded or paused | Run `kubectl get pods -n kube-system` and look for the `kube-apiserver-control1` row -- should be Running |
| Worker won't return to Ready after `systemctl start kubelet` | containerd died alongside kubelet | `sudo systemctl status containerd` — restart if needed |
| `curl` to NodePort returns "connection refused" | nginx pod not Ready yet | `kubectl get pods -l app=nginx -o wide` — wait for all three Running |
| `kubectl create deployment` fails with "ImagePullBackOff" | DNS broken on the node OR registry unreachable | Re-check Demo 2 step 5 nslookup; check `crictl pull nginx:1.27` on the node |
| Helm command not found | Provisioner skipped Helm install on this VM | `vagrant provision control1` re-runs the installer idempotently |

---

## Source mapping

- **Live commands:** Deck slide 11 (YAML two-liner + DNS smoke test), slide 12 (Helm sidebar, if present), slide 13 (diagnostic ladder). One-to-one with what you type on camera.
- **Lab setup from Modules 1-2:** `src/cka-lab/Vagrantfile` installs Helm during provisioning; Module 2 leaves the `post-init-join` snapshot.
- **Snapshot helpers:** `src/cka-lab/cka-snapshot.ps1` and `src/cka-lab/cka-restore.ps1` — atomic, all-or-nothing across the three VMs.
- **Snapshot chain across Course 2:** `post-prereqs` (m01) → `post-init-join` (m02) → `pre-record-m3` (m03 takes) → `post-cni-validation` (Course 3 starting point).
- **Deck markdown extract:** `m03-cni-cluster-validation-TimEdits-WindowsFriendly.md` — every slide + full speaker notes (regenerated alongside this runbook).

---

## Appendix — The diagnostic ladder, fully expanded

| Rung | Command | What it tells you |
|---|---|---|
| 1 | `kubectl get nodes`/`pods`/`svc` | Does the resource exist? What's its surface status? |
| 2 | `kubectl describe <resource>` | Conditions, events, resource limits — the why behind the status |
| 3 | `kubectl logs <pod>` | What did the container print to stdout/stderr before it died? |
| 4 | `kubectl get events -A --sort-by=.lastTimestamp` | Cluster-wide chronological timeline |
| 5 | `journalctl -u kubelet -n 50 --no-pager` (on the node) | Host-level kubelet logs — the equivalent of Windows Event Log for systemd services |
| 6 | `crictl ps` / `crictl logs <id>` (on the node) | Container runtime view — bypasses kubelet entirely |
| 7 | `cat /etc/kubernetes/<file>` or `cat /etc/containerd/config.toml` | Configuration files — last resort, but the source of truth |

**Rule of thumb:** start at rung 1, climb until the failure mode is obvious, never skip rungs.

---

## Appendix — CNI plugin comparison (for the exam)

| Plugin | Default Pod CIDR | NetworkPolicy | Install style | Best for |
|---|---|---|---|---|
| **Calico** | `192.168.0.0/16` | Yes (native) | Helm + Tigera operator | **CKA practice + production** |
| Flannel | `10.244.0.0/16` | No | `kubectl apply` | Lightweight homelab only |
| Cilium | `10.0.0.0/8` | Yes (eBPF-native) | Helm or CLI | Advanced production, overkill for CKA |
| Weave | `10.32.0.0/12` | Yes | `kubectl apply` | Multi-cloud, less common on exam |

**Exam-day truth:** Calico is the default the CKA curriculum and most practice clusters assume. Recognize the others on the question stem, pick Calico for the cluster you actually build.

---

---

## Appendix — Full manifest-based Calico install (production + exam reference)

This is what Step 2.2a points at. **For your own production work**, this is the path you reach for when Helm isn't installed, when the cluster is air-gapped, or when an exam question explicitly hands you a manifest URL.

### Full workflow (mirror image of the Helm path)

```bash
# Step A — install the Tigera operator + every CRD it manages
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/tigera-operator.yaml

# Step B — wait for the operator pod to be Running
kubectl -n tigera-operator wait --for=condition=Ready pod -l name=tigera-operator --timeout=60s

# Step C — declare the Installation custom resource
# The default custom-resources.yaml ships with calicoNetwork.ipPools[0].cidr = 192.168.0.0/16
# which matches our kubeadm init exactly. If your kubeadm init used a different CIDR, download
# the file first, edit the cidr field, then kubectl create against the local copy.
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/custom-resources.yaml

# Step D — same validation as the Helm path
kubectl get nodes -w                               # NotReady → Ready
kubectl get pods -n calico-system                  # calico-node DaemonSet + calico-kube-controllers Running
kubectl get installation default -o yaml | grep cidr  # confirm CIDR matches kubeadm init
```

### When the default CIDR doesn't match (real production scenario)

```bash
# Pull the file, edit the cidr, then apply your local copy
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/custom-resources.yaml

# Edit cidr to match what kubeadm init used (e.g., 10.244.0.0/16 if you inherited a Flannel-style init)
sed -i 's|192.168.0.0/16|10.244.0.0/16|' custom-resources.yaml

kubectl create -f custom-resources.yaml
```

**Windows lens:** `sed -i` is the Linux in-place stream editor — closest Windows analog is `(Get-Content file).Replace('a','b') | Set-Content file`, but one line instead of three.

### Uninstall (clean rollback if you need to swap CNIs)

```bash
# Reverse order: delete the Installation CR first, then the operator
kubectl delete installation default
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.32.0/manifests/tigera-operator.yaml

# Clean up leftover namespaces
kubectl delete namespace calico-system calico-apiserver tigera-operator --ignore-not-found
```

### How to decide between Helm and manifest on the exam (decision tree)

```
Question hands you a Helm chart URL or says "use Helm"
  └─→ Helm install path (Step 2.1 + 2.2)

Question hands you a curl URL or a kubectl apply line
  └─→ Manifest install path (this appendix)

Question says "install a CNI" with no specific method
  ├─→ Helm if it's installed on the exam VM
  └─→ Manifest otherwise — always works

Question says "the cluster has no internet access"
  └─→ Pre-staged manifest only (Helm chart repo unreachable)
```

### Operator architecture (why both paths land in the same place)

```
        ┌─────────────────────────────────┐
        │  helm install calico ...        │
        │  OR                              │
        │  kubectl create -f tigera-operator.yaml │
        └────────────────┬─────────────────┘
                         │
                         ▼
        ┌─────────────────────────────────┐
        │  tigera-operator pod            │
        │  (runs in tigera-operator ns)   │
        │  Watches: Installation CR       │
        └────────────────┬─────────────────┘
                         │  reads
                         ▼
        ┌─────────────────────────────────┐
        │  Installation CR "default"      │
        │  (from custom-resources.yaml    │
        │   OR Helm values)               │
        │  Spec: calicoNetwork.ipPools    │
        └────────────────┬─────────────────┘
                         │  rolls out
                         ▼
        ┌─────────────────────────────────┐
        │  calico-node DaemonSet (1/node) │
        │  calico-kube-controllers (1)    │
        │  calico-typha (HA tier)         │
        │  (all in calico-system ns)      │
        └─────────────────────────────────┘
```

**The takeaway:** The operator and the Installation custom resource are the actual API. Helm and `kubectl create -f` are just two ways to get those two objects into the cluster. **Once you know the operator pattern, the install method becomes interchangeable.**

---

*Three Ready nodes. One manifest pair (or one Helm release). Six validation checks. One intentional break-and-fix. Course 2, closed.*
