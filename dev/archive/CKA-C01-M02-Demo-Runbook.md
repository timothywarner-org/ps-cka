# Module 2 Demo Runbook: Mastering kubectl Workflows for Speed and Precision

> **13-Minute Demo Script** — Create resources imperatively, generate YAML via the dry-run pipeline, discover API fields with kubectl explain, query with selectors and JSONPath, and manage multi-cluster contexts

## Prerequisites

**Before recording:**

- [ ] kind cluster `cka-lab` running from Module 1 (3 nodes, all Ready)
- [ ] kubectl v1.35 with k alias configured (`k get nodes` works)
- [ ] No existing Deployments/Services in default namespace (`k get all` shows only kubernetes service)
- [ ] kind CLI available for creating a second cluster
- [ ] Terminal clear and font sized for recording legibility

**Expected state:**

- Clean default namespace (only the `kubernetes` ClusterIP service)
- Single kind cluster context (`kind-cka-lab`) active
- No second cluster yet (we create it live in Part 5)

---

## Demo Part 1: Imperative Resource Creation (3 min)

### Step 1.1: Create a Pod Imperatively

**What to type:**

```bash
# Create a pod in one command — no YAML needed
k run nginx --image=nginx
k get pods
```

**Checkpoint:** Pod `nginx` shows Running status.

**Talking points:**

> "One command, one pod. No YAML file, no manifest. On the CKA exam, when a task says 'create a pod named nginx using the nginx image,' this is the fastest path. Seven seconds versus two minutes of writing YAML."

---

### Step 1.2: Create a Deployment and Service

**What to type:**

```bash
# Deployment with 3 replicas
k create deployment web --image=nginx --replicas=3

# Verify the Deployment created a ReplicaSet which created 3 Pods
k get deploy,rs,pods -l app=web

# Expose as a ClusterIP service — internal load balancer
k expose deployment web --port=80 --type=ClusterIP
k get svc web
```

**Checkpoint:** Deployment shows 3/3 READY. Service has a ClusterIP assigned.

**Talking points:**

> "Three commands, and you have a load-balanced application. The Deployment created a ReplicaSet, the ReplicaSet created 3 Pods, and the Service provides a stable IP that routes to all three. This is the standard production pattern."

---

### Step 1.3: Create ConfigMap, Secret, Role, and RoleBinding

**What to type:**

```bash
# ConfigMap from literal values
k create configmap app-config --from-literal=env=prod --from-literal=log_level=info

# Secret from literal (base64 encoded automatically)
k create secret generic db-pass --from-literal=password=s3cret

# Role: read-only access to Pods in default namespace
k create role pod-reader --verb=get,list,watch --resource=pods

# RoleBinding: bind the role to a user
k create rolebinding pod-reader-binding --role=pod-reader --user=developer

# Verify everything was created
k get configmap app-config -o yaml
k get secret db-pass -o yaml
k get role,rolebinding
```

**Checkpoint:** All four resources created. Secret values are base64 encoded (not encrypted).

**Talking points:**

> "Six imperative patterns — run, create deployment, expose, create configmap, create secret, create role/rolebinding. These cover roughly 60% of CKA exam tasks. Memorize these like chord shapes on guitar — your fingers should know them without thinking."

> **[Exam: Use the Kubernetes API to perform CRUD operations on core resources]**

---

## Demo Part 2: The dry-run-to-YAML Pipeline (2.5 min)

### Step 2.1: Generate a YAML Skeleton

**What to type:**

```bash
# Generate YAML without creating the resource
k run resource-pod --image=busybox --dry-run=client -o yaml > pod.yaml

# Show the generated skeleton
cat pod.yaml
```

**What to show:**

- Valid YAML with apiVersion, kind, metadata, spec pre-filled
- No resource requests/limits (we'll add them)

**Talking points:**

> "The dry-run pipeline is the second-most important exam technique after imperative commands. The --dry-run=client flag tells kubectl to validate the command locally but NOT send it to the API server. Combined with -o yaml, it generates a manifest skeleton you can edit."

---

### Step 2.2: Edit the YAML and Apply

**What to type:**

```bash
# Add resource requests and limits to the generated YAML
cat << 'EOF' > pod.yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: resource-pod
  name: resource-pod
spec:
  containers:
  - image: busybox
    name: resource-pod
    command: ["sleep", "3600"]
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "250m"
EOF

# Apply the edited manifest
k apply -f pod.yaml
k get pod resource-pod -o wide
```

**Checkpoint:** Pod `resource-pod` is Running with resource constraints applied.

**Talking points:**

> "Generate, edit, apply. Three steps, and you have a pod with resource constraints — something you can't set with kubectl run alone. This pipeline handles the 40% of exam tasks that need fields beyond what imperative commands support."

> **[Exam: Use the Kubernetes API to perform CRUD operations on core resources]**

---

### Step 2.3: Generate a Deployment YAML

**What to type:**

```bash
# Deployment skeleton — add nodeSelector, tolerations, etc. as needed
k create deployment api-server --image=nginx --replicas=2 --dry-run=client -o yaml > deploy.yaml
cat deploy.yaml | head -25
```

**Talking points:**

> "Same pipeline for Deployments. Generate the skeleton, add whatever the task requires — resource limits, nodeSelector, tolerations, affinity rules — then apply. For resources without imperative shortcuts like NetworkPolicy, DaemonSet, or PersistentVolume, go to kubernetes.io/docs and copy the example manifest."

---

## Demo Part 3: kubectl explain — The Offline API Reference (2 min)

### Step 3.1: Discover Pod Spec Fields

**What to type:**

```bash
# Field-level docs without opening a browser
k explain pod.spec.containers

# Recursive tree view — find nested fields fast
k explain pod.spec.containers --recursive | head -40
```

**What to show:**

- Field descriptions for image, command, env, ports, resources, volumeMounts
- The recursive tree showing the full hierarchy

**Talking points:**

> "kubectl explain is your offline API reference. On the exam, you have kubernetes.io/docs in a browser, but switching between terminal and Firefox costs time. kubectl explain gives you field-level documentation without leaving the terminal."

---

### Step 3.2: Discover Deployment Strategy Fields

**What to type:**

```bash
# Find the exact path for rolling update settings
k explain deployment.spec.strategy --recursive

# Drill into a specific field
k explain deployment.spec.strategy.rollingUpdate.maxSurge
```

**Talking points:**

> "When a task says 'configure a rolling update with maxSurge of 25%,' you need the exact field path. kubectl explain deployment.spec.strategy.rollingUpdate.maxSurge tells you the type (string or int) and what values are valid. No Googling required."

> **[Exam: Use the Kubernetes API to perform CRUD operations on core resources]**

---

## Demo Part 4: Querying with Selectors, JSONPath, and Custom Columns (2.5 min)

### Step 4.1: Label Selectors

**What to type:**

```bash
# Find all pods with the app=web label
k get pods -l app=web

# All pods that are NOT app=web
k get pods -l 'app!=web'

# Set-based: pods where app is in (web, nginx)
k get pods -l 'app in (web)'
```

**Talking points:**

> "Label selectors are how Kubernetes finds things. Services use them to find Pods. ReplicaSets use them to count Pods. NetworkPolicies use them to select targets. And you use them on the exam to filter output fast."

---

### Step 4.2: Field Selectors

**What to type:**

```bash
# Only Running pods
k get pods --field-selector status.phase=Running

# Pods on a specific node
k get pods -o wide --field-selector spec.nodeName=cka-lab-worker
```

**Talking points:**

> "Field selectors filter by resource fields, not labels. status.phase=Running, spec.nodeName, metadata.namespace — these filter at the API level, so they're fast even with thousands of pods."

---

### Step 4.3: JSONPath and Custom Columns

**What to type:**

```bash
# Extract just pod names
k get pods -o jsonpath='{.items[*].metadata.name}'

# Tabular output: name + node placement
k get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName

# Sort by creation time — most recent last
k get pods --sort-by=.metadata.creationTimestamp
```

**Talking points:**

> "JSONPath extracts specific fields. Custom-columns gives you a formatted table with exactly the columns you need. --sort-by orders chronologically — critical during troubleshooting when you need to see what happened in what order."

> **[Exam: Use the Kubernetes API to perform CRUD operations on core resources]**

---

## Demo Part 5: Context Management with Multiple Clusters (3 min)

### Step 5.1: Create a Second Cluster

**What to type:**

```bash
# Create a minimal second cluster to demonstrate context switching
kind create cluster --name cka-secondary
```

**Checkpoint:** Second cluster created. kubectl context automatically switched to `kind-cka-secondary`.

---

### Step 5.2: List and Switch Contexts

**What to type:**

```bash
# List all available contexts — asterisk marks the current one
k config get-contexts

# Switch back to the primary lab cluster
k config use-context kind-cka-lab

# Verify you're on the right cluster
k get nodes
```

**Expected output from get-contexts:**

```
CURRENT   NAME                CLUSTER             AUTHINFO
          kind-cka-secondary  kind-cka-secondary  kind-cka-secondary
*         kind-cka-lab        kind-cka-lab        kind-cka-lab
```

**Talking points:**

> "The CKA exam uses six clusters. Every task starts with 'Switch to context <name>.' Forgetting this is the number one silent error — you do correct work in the wrong cluster, score zero points, and get no warning."

---

### Step 5.3: Set a Default Namespace on a Context

**What to type:**

```bash
# Set default namespace so you don't have to type -n every time
k create namespace production
k config set-context --current --namespace=production

# Verify: these two commands now return the same result
k get pods
k get pods -n production

# Reset to default namespace for remaining demos
k config set-context --current --namespace=default
```

**Talking points:**

> "On the exam, tasks often say 'work in namespace X.' Set it as the default for your context and every kubectl command automatically targets it. Saves you from typing -n on every command and prevents accidental deployments to the wrong namespace."

> **[Exam: Use the Kubernetes API to perform CRUD operations on core resources]**

---

### Step 5.4: Clean Up the Secondary Cluster

**What to type:**

```bash
# Delete the secondary cluster — we only needed it for the context demo
kind delete cluster --name cka-secondary

# Verify only the primary lab cluster remains
kind get clusters
k config get-contexts
```

**Checkpoint:** Only `cka-lab` cluster remains. Context is `kind-cka-lab`.

---

## Wrap-Up (30 sec)

**Talking points:**

> "Module 2 demo recap: Six imperative patterns that cover 60% of exam tasks. The dry-run-to-YAML pipeline for everything else. kubectl explain as your offline API reference — never leave the terminal. Selectors and JSONPath for targeted queries. And context management — switch context first, every single task."

> "In Module 3, we deploy Globomantics' first microservice, expose it with Services, break it on purpose, and build the diagnostic ladder that carries through the rest of the skill path."

---

## Quick Reference

### Imperative Command Patterns

| Pattern | Command | Creates |
|---------|---------|---------|
| Pod | `k run <name> --image=<img>` | Single Pod |
| Deployment | `k create deployment <name> --image=<img> --replicas=N` | Deployment + ReplicaSet + Pods |
| Service | `k expose deployment <name> --port=80 --type=ClusterIP` | Service targeting Deployment |
| ConfigMap | `k create configmap <name> --from-literal=key=val` | Configuration data |
| Secret | `k create secret generic <name> --from-literal=key=val` | Base64-encoded data |
| Role | `k create role <name> --verb=get,list --resource=pods` | RBAC permissions |
| RoleBinding | `k create rolebinding <name> --role=<role> --user=<user>` | Binds Role to user/SA |

### The dry-run Pipeline

```bash
# Generate → Edit → Apply
k run <name> --image=<img> --dry-run=client -o yaml > resource.yaml
# Edit resource.yaml to add fields not supported by imperative flags
k apply -f resource.yaml
```

### Query Techniques

| Technique | Example |
|-----------|---------|
| Label selector | `k get pods -l app=web` |
| Negative selector | `k get pods -l 'app!=web'` |
| Set-based selector | `k get pods -l 'app in (web,api)'` |
| Field selector | `k get pods --field-selector status.phase=Running` |
| JSONPath | `k get pods -o jsonpath='{.items[*].metadata.name}'` |
| Custom columns | `k get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName` |
| Sort by field | `k get pods --sort-by=.metadata.creationTimestamp` |

### Context Management

| Action | Command |
|--------|---------|
| List contexts | `k config get-contexts` |
| Switch context | `k config use-context <name>` |
| Set default namespace | `k config set-context --current --namespace=<ns>` |
| View current context | `k config current-context` |

### Exam Tips Mentioned

| Topic | Key Point |
|-------|-----------|
| Context switching | Do it FIRST on every task — wrong context = zero points |
| Imperative commands | 6 patterns cover ~60% of exam tasks |
| dry-run pipeline | Generate skeleton → edit → apply for complex resources |
| kubectl explain | Offline API reference — faster than browser |
| Namespace default | `set-context --current --namespace` saves keystrokes |

---

## Troubleshooting

**Imperative command fails with "already exists"?**
- Delete the existing resource: `k delete pod <name>` or `k delete deploy <name>`
- Or use `k apply` with the dry-run pipeline instead

**dry-run output missing expected fields?**
- Some fields require flags: `--port`, `--replicas`, `--command`
- For unsupported fields, generate skeleton and add manually

**Context switch didn't work?**
- Verify with `k config current-context`
- Check spelling: `k config get-contexts` lists exact names
- If kubeconfig is corrupted: `kind export kubeconfig --name cka-lab`

**kubectl explain shows "error: the server doesn't have a resource type"?**
- Check spelling: `k api-resources | grep <resource>` for correct names
- Use full path: `k explain pods` not `k explain pod` (both work, but be precise)

---

**Demo Length:** ~13 minutes
**Module:** 2 — Mastering kubectl Workflows for Speed and Precision
**Cluster:** kind-cka-lab (primary) + kind-cka-secondary (temporary for context demo)
**Tools:** kubectl v1.35, kind CLI
