# Writing Style Guide for CKA Content

Purpose: Governs the voice, tone, and formatting of all generated exam scenarios, solutions, and lab instructions.
Based on: Microsoft Writing Style Guide principles, adapted for Kubernetes certification content.
Last updated: 2026-04-06

---

## Table of contents

1. [Voice and tone](#voice-and-tone)
2. [Capitalization](#capitalization)
3. [Formatting text in instructions](#formatting-text-in-instructions)
4. [Procedures and instructions](#procedures-and-instructions)
5. [Kubernetes-specific conventions](#kubernetes-specific-conventions)
6. [Word choice](#word-choice)
7. [Numbers](#numbers)
8. [Punctuation](#punctuation)
9. [Bias-free communication](#bias-free-communication)

---

## Voice and tone

- **Crisp and clear** -- To the point. Write for scanning first, reading second.
- **Ready to lend a hand** -- Anticipate real needs and offer great information at just the right time.
- **Technically precise** -- Kubernetes has specific terminology. Use it correctly and consistently.

### Style tips

- **Get to the point fast.** Start with the key takeaway. Put the most important thing in the most noticeable spot.
- **Simpler is better.** Short sentences are easier to scan. Prune every excess word.
- **Use second person** (you) most of the time.
- **No contractions** in any generated content. Write "do not" not "don't," "cannot" not "can't."

---

## Capitalization

### Sentence-style capitalization (default)

Capitalize only the first word and any proper nouns. Use for:

- Headings and titles
- List items
- Phrases and subheadings

### Kubernetes resource names

When referring to Kubernetes resource kinds as proper nouns in documentation, capitalize them:

- Pod, Deployment, Service, ConfigMap, Secret, PersistentVolume, PersistentVolumeClaim
- Node, Namespace, Ingress, NetworkPolicy, StorageClass, DaemonSet, StatefulSet
- CronJob, Job, ReplicaSet, HorizontalPodAutoscaler, Gateway, HTTPRoute, GatewayClass

When referring to the general concept (not the specific Kubernetes object), use lowercase:

- "Deploy the pods" (general concept) vs. "Create a Pod named web" (specific resource)
- "The service handles traffic" (general) vs. "Create a Service of type ClusterIP" (specific)

### Product names (always capitalize)

- Kubernetes
- Docker
- Helm
- Kustomize
- CoreDNS
- etcd (always lowercase)
- containerd (always lowercase)
- CRI-O
- Calico, Cilium, Flannel (CNI plugins)
- NGINX (all caps when referring to the company/product)

---

## Formatting text in instructions

### Commands and code

- Use `code style` (backtick) for: kubectl commands, YAML keys and values, file paths, resource names, namespace names, container names, image names, port numbers, environment variables, API versions.
- Use fenced code blocks (triple backtick) with language identifier for multi-line commands and YAML manifests.

Examples:

- "Run `kubectl get pods -n production` to list all Pods in the production namespace."
- "Set the image to `nginx:1.25`."
- "The manifest uses `apiVersion: apps/v1`."

### UI elements

When referring to terminal or documentation UI elements, use **bold**:

- "In the **Terminal**, run the following command."
- "Open the **Kubernetes documentation** at kubernetes.io/docs."

### File paths and names

Use `code style` for file paths and names:

- "Edit the `/etc/kubernetes/manifests/kube-apiserver.yaml` file."
- "Save the manifest as `deployment.yaml`."

---

## Procedures and instructions

### Step-by-step instructions

- Use numbered steps when sequence matters.
- Write a complete sentence for each step. Capitalize the first word. End with a period.
- Use **imperative verb forms**. Tell the reader what to do.
- Keep steps short. One action per step when possible.
- No more than 12 steps per task (for labs).

### Solution format

Solutions must follow this structure:

1. **Step-by-step commands** -- Numbered steps with exact kubectl commands
2. **Explanation** -- Why each step works, Kubernetes concepts involved
3. **Verification** -- Commands to confirm the solution is correct
4. **Exam speed tips** -- Imperative shortcuts, time-saving techniques
5. **Common mistakes** -- What candidates typically get wrong
6. **References** -- kubernetes.io/docs URLs

---

## Kubernetes-specific conventions

### Context switching

Every scenario must start with the cluster context command:

```bash
kubectl config use-context <cluster-name>
```

This matches the real CKA exam format where candidates switch between six pre-built clusters.

### Imperative-first approach

Prefer imperative kubectl commands over writing YAML from scratch. This mirrors exam speed techniques:

```bash
# Create a Deployment imperatively
kubectl create deployment web --image=nginx:1.25 --replicas=3

# Generate YAML from imperative command when customization is needed
kubectl create deployment web --image=nginx:1.25 --dry-run=client -o yaml > deployment.yaml

# Expose a Deployment as a Service
kubectl expose deployment web --port=80 --target-port=80 --type=ClusterIP
```

### Diagnostic ladder pattern

For troubleshooting scenarios, follow the diagnostic ladder: `get > describe > logs > events`

```bash
# Step 1: Get overview
kubectl get pods -n <namespace>

# Step 2: Describe for details
kubectl describe pod <pod-name> -n <namespace>

# Step 3: Check logs
kubectl logs <pod-name> -n <namespace>

# Step 4: Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Namespace convention

Always specify the namespace explicitly. Do not rely on the default namespace:

```bash
# Correct
kubectl get pods -n production

# Incorrect (relies on current context default)
kubectl get pods
```

### Resource naming

- Use lowercase letters, numbers, and hyphens only
- Do not use underscores
- Keep names descriptive but concise: `web-frontend`, `catalog-api`, `db-backup-cronjob`

### API versions

All YAML must use `apiVersion` values valid in Kubernetes v1.35:

| Resource | apiVersion |
| --- | --- |
| Pod, Service, ConfigMap, Secret, Namespace, PersistentVolume, PersistentVolumeClaim | `v1` |
| Deployment, DaemonSet, StatefulSet, ReplicaSet | `apps/v1` |
| Job, CronJob | `batch/v1` |
| Ingress | `networking.k8s.io/v1` |
| NetworkPolicy | `networking.k8s.io/v1` |
| StorageClass | `storage.k8s.io/v1` |
| Role, ClusterRole, RoleBinding, ClusterRoleBinding | `rbac.authorization.k8s.io/v1` |
| ServiceAccount | `v1` |
| HorizontalPodAutoscaler | `autoscaling/v2` |
| PodDisruptionBudget | `policy/v1` |
| GatewayClass, Gateway, HTTPRoute | `gateway.networking.k8s.io/v1` |
| CustomResourceDefinition | `apiextensions.k8s.io/v1` |

### Allowed exam documentation

Reference only URLs from these domains (the only ones accessible during the real exam):

- kubernetes.io/docs
- kubernetes.io/blog
- helm.sh/docs
- gateway-api.sigs.k8s.io

---

## Word choice

- Choose simple, precise words.
- Use technical Kubernetes terms correctly and consistently.
- Do not give new meanings to existing terms.

### Key word preferences

| Instead of | Use |
| --- | --- |
| carry out | run |
| reboot | restart |
| build (general audience) | create |
| enable/disable | turn on/turn off (for toggles); enable/disable (for Kubernetes features) |
| e.g. | for example |
| should | (only for recommended but optional actions) |
| must | (only for required actions) |
| on-premise | on-premises (always plural, always hyphenated) |

---

## Numbers

- Spell out zero through nine in body text. Use numerals for 10 or greater.
- Always use numerals for: measurements, port numbers, replica counts, resource limits, percentages, time durations, and Kubernetes version numbers.
- Use commas in numbers with four or more digits: 1,000; 1,024 MiB.

---

## Punctuation

- End all sentences with a period.
- Use the Oxford comma in lists of three or more items.
- Use double hyphens (`--`) instead of em dashes.
- Use straight quotes only. No curly quotes.
- Keep plain ASCII. No en dashes, em dashes, or non-ASCII characters.

---

## Bias-free communication

- Use people-first language by default.
- Do not use gendered pronouns in generic references. Use "you" or a role.
- Do not use "master/slave" -- use "control plane/worker," "primary/replica," or "primary/secondary."
- Do not use "blacklist/whitelist" -- use "block list/allow list" or "deny list/allow list."

---

## Quick reference for this project

These rules are especially relevant to CKA exam scenarios and lab instructions:

1. **Sentence-style capitalization** everywhere except proper nouns and Kubernetes resource kinds.
2. **Imperative mood** in procedure steps and solution commands.
3. **Oxford comma** in all lists.
4. **No contractions** (non-negotiable).
5. **Plain ASCII only** -- no curly quotes, no en/em dashes.
6. **Code style** for all kubectl commands, YAML keys, resource names, file paths, and namespaces.
7. **Context switch first** -- every scenario starts with `kubectl config use-context`.
8. **Imperative-first** -- prefer kubectl imperative commands over writing YAML from scratch.
9. **Diagnostic ladder** -- troubleshooting follows `get > describe > logs > events`.
10. **Namespace always explicit** -- never rely on the default namespace.
11. **Solutions must be verifiable** -- include verification commands.
12. **Labs must include cleanup** -- kubectl delete commands at the end.
13. **References from allowed exam docs only** -- kubernetes.io, helm.sh, gateway-api.sigs.k8s.io.
