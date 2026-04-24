# Module 1 Demo Runbook: Kubernetes Architecture and Lab Environment Setup

> **13-Minute Demo Script** — Build a 3-node kind cluster from a YAML config, verify every control plane and worker component, test CoreDNS resolution, and compare the lab to the CKA exam's PSI Bridge desktop

## Prerequisites

**Before recording:**

- [ ] Windows 11 (23H2+) with WSL2 / Ubuntu 22.04 LTS
- [ ] Docker Desktop 4.x running and healthy (`docker info` returns no errors)
- [ ] kind v0.25+ installed (`kind version`)
- [ ] kubectl v1.35 installed (`kubectl version --client`)
- [ ] No existing kind clusters (`kind get clusters` returns empty)
- [ ] Terminal font supports Unicode box-drawing characters (Cascadia Code or similar)
- [ ] `.wslconfig` ready to show (see Step 5.2)

**Expected state:**

- Clean Docker environment (no leftover containers from previous demos)
- No existing kubeconfig contexts except Docker Desktop default
- WSL2 terminal open in VS Code with bash shell

---

## Demo Part 1: Walk Through the kind Configuration File (2 min)

### Step 1.1: Show the Cluster Config YAML

**What to type:**

```bash
# Create the kind config file used across the entire skill path
cat << 'EOF' > cka-lab-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
      - containerPort: 30000
        hostPort: 30000
        protocol: TCP
  - role: worker
  - role: worker
EOF

cat cka-lab-cluster.yaml
```

**Talking points:**

> "This is the cluster configuration file we'll reuse across all 11 courses. One control-plane node, two workers — mirrors a realistic production topology and the multi-node setup you'll see on the CKA exam."

> "The extraPortMappings expose ports 80, 443, and 30000 from the control-plane container to localhost. We need 80 and 443 for Ingress demos later in Course 7, and 30000 for NodePort services in this course's Module 3."

> "The ingress-ready label on the control-plane node is a kind convention — it tells the NGINX Ingress Controller where to schedule. We won't use it today, but it's already wired for Course 7."

**Checkpoint:** File created and contents displayed. Three nodes defined: 1 control-plane, 2 workers.

---

## Demo Part 2: Create the Cluster and Verify Nodes (3 min)

### Step 2.1: Create the Cluster

**What to type:**

```bash
# Create the cluster — watch the output, it shows kubeadm running internally
kind create cluster --name cka-lab --config cka-lab-cluster.yaml
```

**What to show:**

- kind pulling the node image (first run only)
- "Creating cluster" progress with kubeadm phases visible
- "Set kubectl context to kind-cka-lab" confirmation
- Total creation time (~25-30 seconds)

**Talking points:**

> "Under the hood, kind runs kubeadm inside Docker containers — so this is a real Kubernetes cluster, not a simulation. It's CNCF conformant. The same kubeadm you'll use in Course 2 to build bare-metal clusters is running right now."

---

### Step 2.2: Verify All Nodes Are Ready

**What to type:**

```bash
# Verify nodes — all three should show Ready
kubectl get nodes -o wide
```

**Expected output:**

```
NAME                    STATUS   ROLES           AGE   VERSION   INTERNAL-IP   ...
cka-lab-control-plane   Ready    control-plane   30s   v1.35.0   172.18.0.3    ...
cka-lab-worker          Ready    <none>          25s   v1.35.0   172.18.0.2    ...
cka-lab-worker2         Ready    <none>          25s   v1.35.0   172.18.0.4    ...
```

**Checkpoint:** All three nodes show `Ready` status. VERSION matches v1.35.

**Talking points:**

> "Three nodes, all Ready. Notice the control-plane has the role label 'control-plane' — the old 'master' label was deprecated in v1.20. Workers show no role because kind doesn't add one by default."

---

### Step 2.3: Structured Node Health Check with JSONPath

**What to type:**

```bash
# JSONPath extraction — exact exam technique for structured output
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[-1].type}{"\t"}{.status.conditions[-1].status}{"\n"}{end}'
```

**Expected output:**

```
cka-lab-control-plane   Ready   True
cka-lab-worker          Ready   True
cka-lab-worker2         Ready   True
```

**Talking points:**

> "JSONPath is an exam power move. Instead of scrolling through default output, you extract exactly what you need. This pulls the last condition (Ready) for each node. Practice this syntax until it's automatic."

> **[Exam: Prepare underlying infrastructure for installing a Kubernetes cluster]**

---

## Demo Part 3: Inspect kube-system Components (3 min)

### Step 3.1: List All kube-system Pods

**What to type:**

```bash
# See every component running in the cluster's nervous system
kubectl -n kube-system get pods -o wide
```

**What to show (point out each component):**

| Pod | What It Does | Runs On |
|-----|-------------|---------|
| `etcd-cka-lab-control-plane` | Key-value store — ALL cluster state | Control plane only |
| `kube-apiserver-cka-lab-control-plane` | Single entry point for all requests | Control plane only |
| `kube-scheduler-cka-lab-control-plane` | Assigns pods to nodes | Control plane only |
| `kube-controller-manager-cka-lab-control-plane` | Runs reconciliation loops | Control plane only |
| `coredns-*` (x2) | Cluster DNS — service discovery | Scheduled on any node |
| `kube-proxy-*` (x3) | Network rules for Services | DaemonSet — every node |
| `kindnet-*` (x3) | CNI plugin (kind's default) | DaemonSet — every node |

**Talking points:**

> "This is the complete anatomy of a running cluster. Four static pods on the control plane — etcd, API server, scheduler, controller manager. These aren't managed by Deployments; they're static pod manifests in /etc/kubernetes/manifests/."

> "CoreDNS runs as a Deployment with 2 replicas. kube-proxy and kindnet run as DaemonSets — one pod per node, automatically. DaemonSets guarantee node-level coverage."

---

### Step 3.2: Verify CoreDNS Deployment and Service

**What to type:**

```bash
# Show the relationship: CoreDNS Deployment + its fronting Service
kubectl -n kube-system get deploy,svc -l k8s-app=kube-dns
```

**Expected output:**

```
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/coredns   2/2     2            2           2m

NAME               TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)
service/kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP
```

**Talking points:**

> "CoreDNS is deployed as a Deployment with 2 replicas, fronted by the kube-dns Service at a stable ClusterIP. That IP — typically 10.96.0.10 — is hardcoded into every pod's /etc/resolv.conf. This is how service discovery works: pods query kube-dns, which resolves service-name.namespace.svc.cluster.local to a ClusterIP."

> **[Exam: Understand and use CoreDNS]**

---

### Step 3.3: Quick Cluster Info

**What to type:**

```bash
# Fast verification of API server and CoreDNS endpoints
kubectl cluster-info
```

**Checkpoint:** Output shows Kubernetes control plane and CoreDNS URLs.

---

## Demo Part 4: Verify DNS Resolution End-to-End (2.5 min)

### Step 4.1: Create a Test Pod and Resolve Cluster DNS

**What to type:**

```bash
# Spin up a busybox pod and test DNS resolution
kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup kubernetes.default
```

**Expected output:**

```
Server:    10.96.0.10
Address:   10.96.0.10:53

Name:      kubernetes.default.svc.cluster.local
Address:   10.96.0.1
```

**Talking points:**

> "This proves the full DNS chain is working. The busybox pod queries CoreDNS at 10.96.0.10, which resolves 'kubernetes.default' to the API server's ClusterIP at 10.96.0.1. If this fails, your cluster's service discovery is broken."

> "Notice the FQDN: kubernetes.default.svc.cluster.local. Four parts: service name, namespace, 'svc', cluster domain. This naming convention appears on the exam."

**Checkpoint:** DNS resolution succeeds. Server IP matches kube-dns ClusterIP.

> **[Exam: Understand and use CoreDNS]**

---

### Step 4.2: Verify kube-proxy DaemonSet Coverage

**What to type:**

```bash
# Confirm kube-proxy runs on every node (DaemonSet guarantee)
kubectl -n kube-system get daemonset kube-proxy
```

**Expected output:**

```
NAME         DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
kube-proxy   3         3         3       3            3           <none>          3m
```

**Talking points:**

> "DESIRED 3, READY 3. kube-proxy runs on all three nodes because it's a DaemonSet. It maintains iptables or IPVS rules that route Service traffic to the correct pod. No kube-proxy means no Service routing."

---

## Demo Part 5: Compare to CKA Exam Environment (2.5 min)

### Step 5.1: Show the Exam Environment Comparison

**Talking points (no typing — verbal walkthrough with slides):**

> "On exam day, you get a remote XFCE desktop via PSI Bridge. You have: a terminal (pre-configured with the k alias and bash completion), Firefox locked to kubernetes.io/docs only, and six pre-built clusters. You switch between them with kubectl config use-context."

> "Our kind lab mirrors this: multiple nodes, standard Kubernetes components, kubectl as the primary interface. The difference is we have one cluster; the exam has six. We'll add a second cluster in Module 2 to practice context switching."

---

### Step 5.2: Configure WSL2 Resource Limits

**What to type:**

```bash
# Show the .wslconfig file (Windows host)
# This file lives at C:\Users\<username>\.wslconfig on the Windows side
cat << 'EOF'
# Recommended .wslconfig for CKA lab stability
[wsl2]
memory=6GB
processors=4
swap=0
EOF
```

**Talking points:**

> "If you're on Windows with WSL2, cap the memory at 6 GB and disable swap. Kubernetes expects swap to be off — we'll cover exactly why in Course 2 when we prep nodes for kubeadm. Four processors gives the scheduler enough room to spread pods across workers."

> "macOS users: same settings in Docker Desktop preferences. Linux users: you're already running native, just make sure you have 8 GB free."

---

### Step 5.3: Set Up the k Alias (Exam Muscle Memory)

**What to type:**

```bash
# Configure the k alias and bash completion — pre-configured on the exam
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc

# Verify it works
k get nodes
```

**Checkpoint:** `k get nodes` returns the same output as `kubectl get nodes`.

**Talking points:**

> "The k alias is pre-configured on the CKA exam. Start using it now so it's muscle memory by exam day. Every keystroke saved is time saved — and you need every second of those 120 minutes."

> **[Exam: Prepare underlying infrastructure for installing a Kubernetes cluster]**

---

## Wrap-Up (30 sec)

**Talking points:**

> "Module 1 demo recap: We built a 3-node kind cluster from a YAML config in under 30 seconds. We verified every control plane component — API server, etcd, scheduler, controller manager. We confirmed CoreDNS is resolving service names. We verified kube-proxy coverage on all nodes. And we set up the k alias for exam speed."

> "In Module 2, we'll put this cluster to work with imperative kubectl commands, the dry-run-to-YAML pipeline, and context management — the speed toolkit that CKA passers rely on."

---

## Quick Reference

### Key Commands Run in This Demo

| Command | Purpose |
|---------|---------|
| `kind create cluster --name cka-lab --config cka-lab-cluster.yaml` | Create 3-node cluster |
| `kubectl get nodes -o wide` | Verify node status |
| `kubectl get nodes -o jsonpath='{range ...}'` | Structured health output |
| `kubectl -n kube-system get pods -o wide` | List all system components |
| `kubectl -n kube-system get deploy,svc -l k8s-app=kube-dns` | CoreDNS Deployment + Service |
| `kubectl cluster-info` | API server and CoreDNS endpoints |
| `kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup kubernetes.default` | DNS resolution test |
| `kubectl -n kube-system get daemonset kube-proxy` | Verify DaemonSet coverage |

### Architecture Components to Know

| Component | Location | Purpose |
|-----------|----------|---------|
| API server | Control plane | Single entry point for ALL cluster requests |
| etcd | Control plane | Key-value store holding all cluster state |
| Scheduler | Control plane | Assigns pods to nodes based on constraints |
| Controller manager | Control plane | Runs reconciliation loops (desired vs. actual state) |
| kubelet | Every node | Node agent — manages pod lifecycle |
| kube-proxy | Every node (DaemonSet) | Maintains network rules for Service traffic |
| CoreDNS | Deployment (2 replicas) | Cluster DNS — resolves service names to ClusterIPs |
| Container runtime | Every node | containerd — runs containers via CRI |

### Extension Interfaces (NEW on February 2025 Exam)

| Interface | What It Does | Example Implementation |
|-----------|-------------|----------------------|
| CRI (Container Runtime Interface) | How kubelet talks to the container runtime | containerd, CRI-O |
| CNI (Container Network Interface) | How pods get IP addresses and connectivity | Calico, Cilium, Flannel, kindnet |
| CSI (Container Storage Interface) | How persistent storage is provisioned | local-path-provisioner, EBS CSI, Azure Disk CSI |

### Exam Tips Mentioned

| Topic | Key Point |
|-------|-----------|
| kind clusters | Real Kubernetes (kubeadm internally), CNCF conformant, <30 sec creation |
| Control plane vs. worker | Static pods for control plane, DaemonSets for node-level services |
| CoreDNS FQDN format | `service-name.namespace.svc.cluster.local` |
| k alias | Pre-configured on exam — start using it now |
| JSONPath | Exam power move for extracting specific fields from output |
| .wslconfig | memory=6GB, processors=4, swap=0 for lab stability |

---

## Troubleshooting

**kind create cluster hangs or fails?**
- Run `docker info` to verify Docker is running
- Check available memory: `free -h` (need 4 GB+ free)
- Delete stale clusters: `kind delete cluster --name cka-lab`
- Check Docker disk space: `docker system df`

**Nodes showing NotReady?**
- Wait 30 seconds — kindnet and kube-proxy may still be initializing
- Check kube-system pods: `kubectl -n kube-system get pods` — look for CrashLoopBackOff
- Restart Docker Desktop and recreate the cluster

**DNS test fails (nslookup times out)?**
- Verify CoreDNS pods are Running: `kubectl -n kube-system get pods -l k8s-app=kube-dns`
- Check CoreDNS logs: `kubectl -n kube-system logs -l k8s-app=kube-dns`
- Recreate cluster if CoreDNS is stuck in CrashLoopBackOff

**kubectl not connecting?**
- Verify context: `kubectl config current-context` (should show `kind-cka-lab`)
- Check kubeconfig: `cat ~/.kube/config | grep current-context`
- Regenerate kubeconfig: `kind export kubeconfig --name cka-lab`

---

**Demo Length:** ~13 minutes
**Module:** 1 — Kubernetes Architecture and Lab Environment Setup
**Cluster:** kind (1 control-plane + 2 workers)
**Tools:** kind v0.25+, kubectl v1.35, Docker Desktop, WSL2/Ubuntu 22.04
