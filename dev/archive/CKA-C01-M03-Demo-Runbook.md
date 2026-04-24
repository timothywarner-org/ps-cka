# Module 3 Demo Runbook: Creating Core Resources and Building the Diagnostic Ladder

> **13-Minute Demo Script** — Deploy bare Pods vs. managed Deployments, expose with ClusterIP/NodePort/LoadBalancer Services, verify EndpointSlices, break a selector label and watch traffic stop, deploy a broken image and walk the full diagnostic ladder (get > describe > logs > events)

## Prerequisites

**Before recording:**

- [ ] kind cluster `cka-lab` running from Module 1 (3 nodes, all Ready)
- [ ] kubectl v1.35 with k alias configured
- [ ] Resources from Module 2 cleaned up (`k delete all --all` in default namespace)
- [ ] Default namespace active (`k config view --minify -o jsonpath='{.contexts[0].context.namespace}'` returns empty or `default`)

**Expected state:**

- Clean default namespace (only the `kubernetes` ClusterIP service)
- All 3 nodes Ready
- No leftover Deployments, Services, or Pods from Module 2

---

## Demo Part 1: Bare Pod vs. Managed Deployment — Why Controllers Matter (2.5 min)

### Step 1.1: Create a Bare Pod and a Managed Deployment

**What to type:**

```bash
# Bare pod — no controller, no safety net
k run standalone --image=nginx

# Managed deployment — ReplicaSet controller maintains desired state
k create deployment managed --image=nginx --replicas=2

# Show what got created: Pod, Deployment, ReplicaSet
k get pods,deploy,rs
```

**Checkpoint:** 1 standalone Pod + 2 managed Pods running. Deployment shows 2/2 READY.

**Talking points:**

> "Two different ways to run nginx. The standalone Pod has no controller watching it. The managed Pods are owned by a ReplicaSet, which is owned by the Deployment. That ownership chain is what makes Kubernetes self-healing."

---

### Step 1.2: Delete Both and See the Difference

**What to type:**

```bash
# Delete the bare pod — it's gone forever
k delete pod standalone
k get pods

# Delete one of the managed pods — watch what happens
k delete pod $(k get pods -l app=managed -o jsonpath='{.items[0].metadata.name}')

# Wait 2-3 seconds, then check
k get pods
```

**What to show:**

- `standalone` is gone permanently — no recreation
- The managed Pod was immediately replaced by a new Pod (different name, same label)

**Talking points:**

> "The standalone Pod is gone. Deleted. No reconciliation, no resurrection. But the managed Pod? The ReplicaSet noticed desired state (2) didn't match actual state (1), and it immediately created a replacement. This is the reconciliation loop that makes Kubernetes reliable."

> "On the exam, you almost never create bare Pods. Deployments are the standard. The only exceptions: one-off debug pods with kubectl run and DaemonSets."

---

### Step 1.3: Show the ReplicaSet

**What to type:**

```bash
# The ReplicaSet is the actual controller maintaining pod count
k get rs -l app=managed
k describe rs -l app=managed | head -20
```

**Talking points:**

> "The Deployment doesn't manage Pods directly. It creates a ReplicaSet, and the ReplicaSet manages the Pods. Deployment > ReplicaSet > Pod. This three-tier hierarchy enables rolling updates — which we'll cover in depth in Course 5."

> **[Exam: Define and understand the role of Pods]**

---

## Demo Part 2: Services, EndpointSlices, and the Selector-Label Contract (3 min)

### Step 2.1: Expose the Deployment as ClusterIP

**What to type:**

```bash
# Create a ClusterIP Service — internal load balancer
k expose deployment managed --port=80 --type=ClusterIP --name=managed-svc

# Show the Service
k get svc managed-svc

# Show that EndpointSlice IPs match Pod IPs
k get endpointslices -l kubernetes.io/service-name=managed-svc
k get pods -l app=managed -o wide
```

**What to show:**

- Service has a ClusterIP (e.g., 10.96.X.X)
- EndpointSlice contains the same IPs as the Pod INTERNAL-IPs

**Talking points:**

> "A Service provides a stable virtual IP that load-balances across matching Pods. The key word is 'matching' — the Service uses a label selector to find its Pods. Those Pod IPs are stored in an EndpointSlice. When traffic hits the ClusterIP, kube-proxy routes it to one of those endpoint IPs."

---

### Step 2.2: Scale and Watch Endpoints Update

**What to type:**

```bash
# Scale from 2 to 4 replicas
k scale deployment managed --replicas=4

# Watch endpoints grow
k get pods -l app=managed -o wide
k get endpointslices -l kubernetes.io/service-name=managed-svc -o yaml | grep -A1 "addresses:"
```

**Checkpoint:** 4 pods running. EndpointSlice shows 4 addresses.

**Talking points:**

> "Scale to 4, and the EndpointSlice automatically picks up the new Pod IPs. No manual registration. The selector-label contract handles everything: if a Pod has the right label and passes its readiness probe, it gets added to the EndpointSlice. If it fails, it gets removed. Automatic."

---

### Step 2.3: Break the Selector Label — Watch Traffic Stop

**What to type:**

```bash
# Remove the selector label from one Pod
TARGET_POD=$(k get pods -l app=managed -o jsonpath='{.items[0].metadata.name}')
echo "Breaking label on: $TARGET_POD"

k label pod $TARGET_POD app-

# Check: Pod still runs, but endpoints dropped
k get pods --show-labels
k get endpointslices -l kubernetes.io/service-name=managed-svc
```

**What to show:**

- The unlabeled Pod is still Running (it's healthy, just invisible to the Service)
- EndpointSlice now shows only 3 addresses instead of 4
- A NEW Pod was created by the ReplicaSet (because it sees only 3 matching Pods, but desired is 4)

**Talking points:**

> "This is the selector-label contract in action. Remove the label, and two things happen. First, the Service drops the Pod from its EndpointSlice — no more traffic. Second, the ReplicaSet counts only 3 matching Pods, sees desired is 4, and creates a new one. The unlabeled Pod is now an orphan — running but disconnected."

---

### Step 2.4: Fix the Label

**What to type:**

```bash
# Re-add the label
k label pod $TARGET_POD app=managed

# Now we have 5 pods — ReplicaSet will terminate one to get back to 4
k get pods -l app=managed
```

**Talking points:**

> "Re-add the label and the ReplicaSet sees 5 matching Pods — one too many. It terminates the newest extra Pod to converge back to 4. This is reconciliation working in both directions: too few? Create. Too many? Terminate."

> **[Exam: Use ClusterIP, NodePort, LoadBalancer service types and endpoints]**

---

## Demo Part 3: Service Types — ClusterIP, NodePort, LoadBalancer (2 min)

### Step 3.1: Test ClusterIP from Inside the Cluster

**What to type:**

```bash
# ClusterIP is internal-only — access from a debug pod
k run debug --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- managed-svc
```

**What to show:**

- nginx welcome page HTML returned

**Talking points:**

> "ClusterIP is the default Service type. It's internal-only — reachable from inside the cluster but not from your laptop. On the exam, if a task says 'expose internally,' ClusterIP is the answer."

---

### Step 3.2: Create a NodePort Service

**What to type:**

```bash
# NodePort extends ClusterIP with an external port on every node
k expose deployment managed --port=80 --type=NodePort --name=managed-nodeport

# Get the assigned port (30000-32767 range)
NODE_PORT=$(k get svc managed-nodeport -o jsonpath='{.spec.ports[0].nodePort}')
echo "NodePort assigned: $NODE_PORT"

# Access via localhost (kind maps ports to host)
curl -s localhost:$NODE_PORT | head -5
```

**Talking points:**

> "NodePort extends ClusterIP by opening a static port (30000-32767) on every node. External clients hit any node IP on that port, and traffic routes to the Service. kind maps these to localhost, so curl works from our terminal."

---

### Step 3.3: Create a LoadBalancer Service

**What to type:**

```bash
# LoadBalancer extends NodePort with a cloud provider LB
k expose deployment managed --port=80 --type=LoadBalancer --name=managed-lb

# Show it — EXTERNAL-IP will stay Pending on kind
k get svc managed-lb
```

**What to show:**

- EXTERNAL-IP column shows `<pending>` — expected behavior without a cloud provider

**Talking points:**

> "LoadBalancer extends NodePort by requesting a load balancer from the cloud provider. On kind, there's no cloud provider, so EXTERNAL-IP stays Pending. That's expected. On AKS, EKS, or GKE, this would get a real public IP. Know the three-tier relationship: LoadBalancer builds on NodePort, which builds on ClusterIP."

> **[Exam: Use ClusterIP, NodePort, LoadBalancer service types and endpoints]**

---

## Demo Part 4: Namespaces, Labels, and Compound Selectors (1.5 min)

### Step 4.1: Create a Namespace and Deploy Into It

**What to type:**

```bash
# Create a namespace for Globomantics' staging environment
k create namespace staging

# Deploy into staging
k -n staging create deployment catalog-api --image=nginx --replicas=2
k -n staging label deploy catalog-api team=backend env=staging

# Label the pods too
k -n staging label pods -l app=catalog-api team=backend env=staging
```

---

### Step 4.2: Query Across Namespaces and With Compound Selectors

**What to type:**

```bash
# All pods across all namespaces
k get pods -A | head -15

# Compound selector: team=backend AND env=staging
k get pods -n staging -l team=backend,env=staging

# All resources in staging namespace
k -n staging get all
```

**Talking points:**

> "Namespaces scope resource names and RBAC policies. Labels drive selection — Services find Pods, NetworkPolicies find targets, and you find resources during troubleshooting. Compound selectors with comma separation are AND logic: both conditions must be true."

> **[Exam: Define and understand the role of Pods]**

---

## Demo Part 5: The Diagnostic Ladder — get > describe > logs > events (4 min)

### Step 5.1: Deploy a Broken Pod

**What to type:**

```bash
# Deploy a pod with an image tag that doesn't exist
k run broken --image=nginx:doesnotexist
```

**Talking points:**

> "This simulates the most common CKA troubleshooting scenario: something is broken and you need to figure out why. The diagnostic ladder is your systematic approach. Let's walk it."

---

### Step 5.2: Step 1 of the Ladder — kubectl get (What is the state?)

**What to type:**

```bash
# Step 1: WHAT is the current state?
k get pods
```

**Expected output:**

```
NAME     READY   STATUS             RESTARTS   AGE
broken   0/1     ImagePullBackOff   0          15s
```

**Talking points:**

> "Step one: get. What's the state? Status shows ImagePullBackOff. That tells you the container runtime tried to pull the image and failed. It's now backing off before retrying. But WHY did it fail? Move to step two."

---

### Step 5.3: Step 2 of the Ladder — kubectl describe (What happened?)

**What to type:**

```bash
# Step 2: WHAT events happened to this resource?
k describe pod broken
```

**What to show (scroll to Events section):**

```
Events:
  Type     Reason     Age   From               Message
  ----     ------     ----  ----               -------
  Normal   Scheduled  30s   default-scheduler  Successfully assigned default/broken to cka-lab-worker
  Normal   Pulling    28s   kubelet            Pulling image "nginx:doesnotexist"
  Warning  Failed     27s   kubelet            Failed to pull image "nginx:doesnotexist": ...tag does not exist
  Warning  Failed     27s   kubelet            Error: ErrImagePull
  Normal   BackOff    25s   kubelet            Back-off pulling image "nginx:doesnotexist"
  Warning  Failed     25s   kubelet            Error: ImagePullBackOff
```

**Talking points:**

> "Step two: describe. Scroll straight to Events at the bottom — this is where the story is. Scheduled successfully, started pulling the image, failed because the tag doesn't exist. Now you know exactly what's wrong. On the exam, if you can read Events, you can diagnose 80% of failures."

---

### Step 5.4: Step 3 of the Ladder — kubectl logs (What did the container say?)

**What to type:**

```bash
# Step 3: What did the container output?
k logs broken
```

**Expected output:**

```
Error from server (BadRequest): container "broken" in pod "broken" is waiting to start: trying and failing to pull image
```

**Talking points:**

> "Step three: logs. In this case, the container never started, so there are no application logs. But for running containers, kubectl logs reads stdout and stderr captured by the container runtime. For multi-container Pods, add -c container-name. For crashed containers, add --previous to see logs from the last run before it died."

---

### Step 5.5: Step 4 of the Ladder — kubectl get events (What happened cluster-wide?)

**What to type:**

```bash
# Step 4: Cluster-wide event timeline — sorted chronologically
k get events --sort-by=.metadata.creationTimestamp | tail -10
```

**Talking points:**

> "Step four: events. This gives you a cluster-wide timeline. When multiple things are failing — a node goes NotReady, pods get evicted, new pods fail to schedule — this timeline shows the cascade. Sort by creation timestamp to see cause before effect."

---

### Step 5.6: Fix the Problem and Verify

**What to type:**

```bash
# Fix: delete the broken pod and create with the correct image tag
k delete pod broken
k run fixed --image=nginx:latest

# Walk the ladder on a healthy pod for comparison
k get pod fixed
k describe pod fixed | tail -10
k logs fixed | head -5
```

**Checkpoint:** Pod `fixed` shows Running. Events show successful pull and start.

**Talking points:**

> "The diagnostic ladder: get, describe, logs, events. Four commands in order. get tells you WHAT. describe tells you WHY. logs tell you what the APPLICATION thinks. events give you the TIMELINE. This is the pattern for every troubleshooting question on the CKA exam — 30% of your score."

> "Practice this until it's muscle memory. When something breaks, your fingers should type these four commands automatically, without thinking."

> **[Exam: Troubleshoot clusters and nodes + Manage and evaluate container output streams]**

---

## Wrap-Up (30 sec)

**Talking points:**

> "Module 3 demo recap: Bare Pods are ephemeral — Deployments with ReplicaSets provide self-healing. Services use selector-label matching to find Pods, and EndpointSlices update automatically. Three Service types: ClusterIP for internal, NodePort for external via high port, LoadBalancer for cloud. And the diagnostic ladder — get, describe, logs, events — is the single most valuable skill for the CKA exam."

> "That wraps Course 1: Kubernetes Foundations. You've built a cluster, mastered kubectl workflows, deployed and exposed applications, and built the diagnostic instincts you'll use in every remaining course. Course 2 takes you to bare metal: installing clusters with kubeadm."

---

## Quick Reference

### Resources Created in This Demo

| Resource | Command | Purpose |
|----------|---------|---------|
| Pod `standalone` | `k run standalone --image=nginx` | Demonstrate ephemeral bare Pod |
| Deployment `managed` | `k create deployment managed --image=nginx --replicas=2` | Self-healing controller hierarchy |
| Service `managed-svc` | `k expose deployment managed --port=80 --type=ClusterIP` | Internal load balancing |
| Service `managed-nodeport` | `k expose deployment managed --port=80 --type=NodePort` | External access via high port |
| Service `managed-lb` | `k expose deployment managed --port=80 --type=LoadBalancer` | Cloud LB (Pending on kind) |
| Namespace `staging` | `k create namespace staging` | Organizational boundary |
| Pod `broken` | `k run broken --image=nginx:doesnotexist` | Diagnostic ladder walkthrough |

### The Diagnostic Ladder

| Step | Command | Answers |
|------|---------|---------|
| 1. get | `k get pods` | WHAT is the current state? |
| 2. describe | `k describe pod <name>` | WHY is it in that state? (scroll to Events) |
| 3. logs | `k logs <pod> [-c container] [--previous]` | What did the APPLICATION output? |
| 4. events | `k get events --sort-by=.metadata.creationTimestamp` | What happened CLUSTER-WIDE? |

### Service Type Comparison

| Type | Accessible From | Builds On | Use Case |
|------|----------------|-----------|----------|
| ClusterIP | Inside cluster only | — | Internal service-to-service |
| NodePort | External via nodeIP:30000-32767 | ClusterIP | Dev/test external access |
| LoadBalancer | External via cloud LB IP | NodePort + ClusterIP | Production external access |

### Exam Tips Mentioned

| Topic | Key Point |
|-------|-----------|
| Bare Pods vs. Deployments | Almost never create bare Pods on the exam |
| Selector-label contract | Remove a label and the Service drops the Pod immediately |
| EndpointSlices | Modern replacement for Endpoints — IPs auto-update on scale/failure |
| LoadBalancer Pending | Expected on kind/bare metal — no cloud provider to assign IP |
| Diagnostic ladder | get > describe > logs > events — 30% of exam score |
| --previous flag | See logs from crashed/restarted containers |
| Event sorting | `--sort-by=.metadata.creationTimestamp` for causal ordering |

---

## Troubleshooting

**Scale command fails with "not found"?**
- Verify the Deployment exists: `k get deploy`
- Check namespace: `k get deploy -A` to find it

**ClusterIP not reachable from debug pod?**
- Verify endpoints exist: `k get endpointslices -l kubernetes.io/service-name=<svc>`
- Check pod labels match service selector: `k get svc <name> -o yaml | grep selector`
- Verify the backend pods are Running and Ready

**NodePort curl returns "Connection refused"?**
- Verify the port: `k get svc <name> -o jsonpath='{.spec.ports[0].nodePort}'`
- On kind, use `localhost:<nodePort>` not the node IP
- Check the extraPortMappings in cka-lab-cluster.yaml include the assigned port range

**Diagnostic ladder: describe shows no events?**
- Events expire after 1 hour by default
- If the pod is old, recreate it to generate fresh events
- Check cluster-wide: `k get events -A --sort-by=.metadata.creationTimestamp`

**Label removal didn't trigger new Pod creation?**
- Verify the ReplicaSet spec: `k get rs -l app=managed -o yaml | grep replicas`
- The ReplicaSet counts pods by label — removing the label drops the count

---

**Demo Length:** ~13 minutes
**Module:** 3 — Creating Core Resources and Building the Diagnostic Ladder
**Cluster:** kind-cka-lab (1 control-plane + 2 workers from Module 1)
**Tools:** kubectl v1.35, curl, busybox debug pod
