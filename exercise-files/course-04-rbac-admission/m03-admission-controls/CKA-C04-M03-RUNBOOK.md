# CKA C04 M03 -- Admission Controls, Resource Limits, and Governance

**31 commands, four demos.**

For every numbered step: read the first **Say**, type the command, compare the output with **Expected**, then read the second **Say** while the output is on screen.

---

## Before you roll

```powershell
cd C:\github\ps-cka\src\cka-lab
.\Initialize-C04M03Lab.ps1       # must end [OK] recording-ready
```

```bash
ssh vagrant@192.168.50.10        # password: vagrant
cd ~/m03
./lab.sh reset                   # wait for READY FOR TAKE
```

**Between takes:** `./lab.sh reset`

**Expected results:** Step 11 is refused. Step 24 contains an intentional write failure. Step 15 settles at three of six replicas, and Step 29 shows no Pods.

**No helper script appears on camera in this module.** You type every command.

---

# Demo 1 -- LimitRanger writes what you left out

### 1

**Say:** "Module 2 ended with a gap. RBAC can authorize a request without deciding whether the object itself is safe. I am pinning the context, then we move to the next gate: admission."

```bash
kubectl config use-context cka-vagrant
```

**Expected:** `Switched to context "cka-vagrant".`

**Say:** "Same cluster, same admin identity. Authentication and authorization already happened. Every result from here is about what the API server does with the object."

### 2

**Say:** "Priya's production workloads need their own policy boundary. LimitRanges and ResourceQuotas are namespaced, so production comes first."

```bash
kubectl create namespace production
```

**Expected:** `namespace/production created`

**Say:** "Fresh namespace, no resource policy yet. That is our control state before the platform team adds guardrails."

### 3

**Say:** "This LimitRange defines defaults, not a minimum or maximum. It supplies resource values when a container leaves them out."

```bash
kubectl apply -f limitrange.yaml
```

**Expected:** `limitrange/production-defaults created`

**Say:** "The policy now supplies a 100 millicore CPU request and a 500 millicore CPU limit, plus memory values. Requests guide scheduling. CPU and memory limits are enforced by the runtime and kernel, but in different ways."

### 4

**Say:** "Now I am submitting a Pod with no requests and no limits. Watch what I leave out, because that omission is the point."

```bash
kubectl run web-1 --image=nginx:1.27 -n production
```

**Expected:** `pod/web-1 created`

**Say:** "The API server accepted the Pod. Before storing it, the LimitRanger admission plugin had a chance to fill in the missing resource fields."

### 5

**Say:** "I need the Pod running before I inspect it, so I will wait on the Ready condition instead of guessing how long startup takes."

```bash
kubectl wait --for=condition=Ready pod/web-1 -n production --timeout=90s
```

**Expected:** `pod/web-1 condition met`

**Say:** "Ready tells me scheduling and startup succeeded. Admission did its work earlier, while the API server was processing the create request."

### 6

**Say:** "Now I will read the live object back from the API. The stored spec is the evidence."

```bash
kubectl get pod web-1 -n production -o jsonpath='{.spec.containers[0].resources}'; echo
```

**Expected:** `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"100m","memory":"128Mi"}}`

**Say:** "There are all four values: CPU and memory requests, CPU and memory limits. The object I got back is not the object I sent. LimitRanger is both mutating and validating, and this is its mutating pass."

### 7

**Say:** "JSONPath gives me precision. Now I will show the same values in the human-readable description you are more likely to use under exam pressure."

```bash
kubectl describe pod web-1 -n production | grep -A6 -i 'limits\|requests'
```

**Expected:** A **Limits and Requests** section showing `500m`, `256Mi`, `100m`, and `128Mi`.

**Say:** "Nobody typed those values into the Pod command. If a workload has resources you did not declare, inspect the namespace's LimitRange. A task that requires default container resources is a LimitRange problem, not a quota problem."

> **Pause point.** The object came in incomplete; admission completed it.

---

# Demo 2 -- The same plugin refuses, and a quota fills up

### 8

**Say:** "New demo, same first move. I am pinning the context before I change policy."

```bash
kubectl config use-context cka-vagrant
```

**Expected:** `Switched to context "cka-vagrant".`

**Say:** "Still on the lab cluster. Now we move from admission helping a workload to admission refusing one."

### 9

**Say:** "I am updating the same LimitRange with a minimum and maximum. The defaults remain, but now there is a ceiling to violate."

```bash
kubectl apply -f limitrange-ceiling.yaml
```

**Expected:** `limitrange/production-defaults configured`

**Say:** "The result says `configured`, not `created`, because this is the same `production-defaults` object. Its CPU range now runs from 50 to 800 millicores per container."

### 10

**Say:** "Before I test the ceiling, I will read the policy back. Troubleshooting starts with the live object, not the YAML file I hope I applied."

```bash
kubectl describe limitrange production-defaults -n production
```

**Expected:** A `Container` row with CPU `Min 50m`, `Max 800m`, `Default Request 100m`, and `Default Limit 500m`.

**Say:** "One object now does two jobs. It defaults missing values during mutation, then validates the final values against the minimum and maximum."

### 11

**Say:** "This Pod requests a 1500 millicore CPU limit against an 800 millicore maximum. The API server should refuse it."

```bash
kubectl apply -f oversized-pod.yaml
```

**Expected:**

```text
Error from server (Forbidden): error when creating "oversized-pod.yaml": pods "greedy" is forbidden: maximum cpu usage per Container is 800m, but limit is 1500m
```

**Say:** "That refusal names both numbers: the 800 millicore constraint and the 1500 millicore value. A `Forbidden` message with a resource constraint points toward admission. A `Forbidden` message naming a user, verb, and resource points toward RBAC. Read the reason, not just the status code."

### 12

**Say:** "A LimitRange constrains an individual container. A ResourceQuota caps the namespace total. Now I am giving production a shared budget."

```bash
kubectl apply -f resourcequota.yaml
```

**Expected:** `resourcequota/production-cap created`

**Say:** "The namespace now has two CPU cores of requests, two CPU cores of limits, and four gibibytes for each memory total. In a quota, bare `cpu` means `requests.cpu`, and bare `memory` means `requests.memory`. Limits require the `limits` prefix."

### 13

**Say:** "A quota is a live ledger, so I am reading both columns: used and hard."

```bash
kubectl describe resourcequota production-cap -n production
```

**Expected:** `limits.cpu   500m   2` - `web-1` is already counted.

**Say:** "`web-1` is already counted even though it existed before the quota. Its default 500 millicore limit is now part of the namespace total."

### 14

**Say:** "Now Priya's team scales out. I am requesting six replicas, and LimitRanger will give every generated Pod a 500 millicore CPU limit."

```bash
kubectl create deployment filler --image=nginx:1.27 --replicas=6 -n production
```

**Expected:** `deployment.apps/filler created`

**Say:** "The Deployment object is valid, so it is created. The interesting admission decisions happen when its ReplicaSet starts creating Pods."

### 15

**Say:** "Let the controllers reconcile, then read the Deployment and ReplicaSet together. The arithmetic predicts three ready replicas, not six."

```bash
kubectl get deployment,replicaset -n production
```

**Expected:** `filler` settles at **3/6 ready**; its ReplicaSet shows `DESIRED 6`, `CURRENT 3`, `READY 3`.

**Say:** "`web-1` uses 500 millicores. Three new Pods use another 1500. That reaches the 2000 millicore limit exactly, so the fourth Pod request is refused. The Deployment was admitted, but quota prevents it from reaching its desired state."

### 16

**Say:** "The Deployment shows the shortfall. The ReplicaSet events explain it, so I will follow the ownership chain down one level."

```bash
kubectl describe rs -n production | tail -25
```

**Expected:** `FailedCreate ... exceeded quota: production-cap`

**Say:** "`FailedCreate` names `production-cap`. That is the diagnostic path: start with the Deployment, follow its ReplicaSet, then inspect a Pod if one exists. The clearest controller failure is usually on the object that attempted the create."

### 17

**Say:** "I will close the loop by checking the ledger again."

```bash
kubectl describe resourcequota production-cap -n production
```

**Expected:** `limits.cpu   2   2`

**Say:** "Two cores used, two cores hard. The quota is full, so new Pods that increase the counted total will be refused until the namespace gives some budget back."

> **Pause point.** LimitRange governs each container; ResourceQuota governs the namespace total.

---

# Demo 3 -- Give the budget back, then harden a Pod

### 18

**Say:** "Quota is accounting, not a permanent wall. I will delete the workload that consumed the budget."

```bash
kubectl delete deployment filler -n production
```

**Expected:** `deployment.apps "filler" deleted`

**Say:** "Deleting the Deployment removes its ReplicaSet and Pods. As those Pods leave, the quota controller returns their resources to the namespace budget."

### 19

**Say:** "Now I will read the ledger instead of assuming the budget came back."

```bash
kubectl describe resourcequota production-cap -n production
```

**Expected:** After quota reconciliation, `limits.cpu   500m   2`.

**Say:** "Usage is back to the 500 millicores held by `web-1`. That reclaim is what makes ResourceQuota useful as continuous namespace governance."

### 20

**Say:** "I am pinning the context before we change from resource governance to workload hardening."

```bash
kubectl config use-context cka-vagrant
```

**Expected:** `Switched to context "cka-vagrant".`

**Say:** "Same production namespace, same admission path. This time the object carries an explicit security context."

### 21

**Say:** "This Pod is designed to run as UID 101, refuse privilege escalation, and mount its root filesystem read-only. It uses the unprivileged NGINX image because ordinary NGINX expects to start as root."

```bash
kubectl apply -f hardened-pod.yaml
```

**Expected:** `pod/hardened created`

**Say:** "The API server admitted it. The manifest meets the `baseline` Pod Security Standard. It does not meet `restricted` because it lacks an explicit seccomp profile and does not drop all Linux capabilities."

### 22

**Say:** "Admission is not the end of the story. The kubelet still has to start the container, so I will wait for proof."

```bash
kubectl wait --for=condition=Ready pod/hardened -n production --timeout=90s
```

**Expected:** `pod/hardened condition met`

**Say:** "The Pod is Ready. If an image resolves to UID zero while `runAsNonRoot` is true, the kubelet refuses to start the container. That is a post-admission failure, and its evidence lives on the Pod."

### 23

**Say:** "The spec claims UID 101. I would rather question the running process than trust the claim."

```bash
kubectl exec -n production hardened -- id
```

**Expected:** Output begins with `uid=101(nginx) gid=101(nginx)`.

**Say:** "UID 101 and GID 101. That is runtime evidence that the container process is not running as root."

### 24

**Say:** "Now I will test the read-only root filesystem by trying to create a file at its root. The failure is the expected result."

```bash
kubectl exec -n production hardened -- touch /root-test 2>&1 || \
  echo "read-only root filesystem -- exactly what readOnlyRootFilesystem buys you"
```

**Expected:**

```text
touch: cannot touch '/root-test': Read-only file system
read-only root filesystem -- exactly what readOnlyRootFilesystem buys you
```

**Say:** "The write failed because the container's root filesystem is read-only. Writable volumes are still writable, which is why this Pod mounts an `emptyDir` at `/tmp`. The design is an immutable root with explicit writable paths."

> **Pause point.** The manifest claimed it; the running container proved it.

---

# Demo 4 -- Pod Security Admission, and reading the refusal

### 25

**Say:** "Final demo. I am pinning the context, then we will trace a failure from namespace policy to controller event."

```bash
kubectl config use-context cka-vagrant
```

**Expected:** `Switched to context "cka-vagrant".`

**Say:** "Same cluster. The rest of this demo forms a diagnostic ladder, and each rung narrows where the request failed."

### 26

**Say:** "Pod Security Admission is built into this cluster. I am labeling `production` to enforce and warn on the `baseline` standard."

```bash
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=baseline --overwrite
```

**Expected:** `namespace/production labeled`

**Say:** "`enforce` rejects violating Pods. `warn` allows the request but returns a user-facing warning. There is also an `audit` mode for audit annotations. I am leaving the policy version at `latest` for this lab; production rollouts should consider pinning the version during upgrades."

### 27

**Say:** "Rung one: which Pod Security policy applies to this namespace? I will inspect the labels rather than trust the previous command."

```bash
kubectl get ns production --show-labels
```

**Expected:** Both `pod-security.kubernetes.io/enforce=baseline` and `pod-security.kubernetes.io/warn=baseline` appear in the `LABELS` column.

**Say:** "Both labels are present, both at `baseline`. Namespace labels can select `enforce`, `warn`, and `audit` independently, so always read the mode as well as the policy level."

### 28

**Say:** "Now I am submitting a Deployment whose Pod template sets `privileged: true`. Watch for two results at once: a warning and a successful Deployment create."

```bash
kubectl apply -f privileged-deployment.yaml
```

**Expected:**

```text
Warning: would violate PodSecurity "baseline:latest": privileged
deployment.apps/legacy-agent created
```

The warning may include more detail about container `agent` and `securityContext.privileged=true`.

**Say:** "Warning, then created. That is not a contradiction. Warning mode inspected the Deployment's Pod template, but enforce mode applies to the actual Pods created from that template, not to the Deployment object."

### 29

**Say:** "Rung two: what exists? I will count the objects at every level of the ownership chain."

```bash
kubectl get deploy,rs,pods -n production -l app=legacy-agent
```

**Expected:** One `legacy-agent` Deployment, one ReplicaSet, and **no Pod row**.

**Say:** "The Deployment exists. Its ReplicaSet exists. No Pod exists. The ReplicaSet submitted a Pod create request, and something in admission refused it before storage."

### 30

**Say:** "Rung three: the Pod does not exist, so there is no Pod to describe. I will inspect the ReplicaSet that tried to create it."

```bash
kubectl describe rs -n production -l app=legacy-agent | tail -20
```

**Expected:** `FailedCreate ... violates PodSecurity "baseline:latest": privileged`

**Say:** "`FailedCreate` names Pod Security `baseline` and the privileged field. That event is the evidence. The quota has room now, so the budget is not the culprit."

### 31

**Say:** "Final rung: compare that admission refusal with a Pod that made it through admission and reached a node."

```bash
kubectl describe pod web-1 -n production | tail -15
```

**Expected:** Normal `Scheduled`, `Pulled`, `Created`, and `Started` events for the healthy `web-1` Pod.

**Say:** "`web-1` exists, so its events show scheduling and kubelet activity. In this demo, no `legacy-agent` Pod plus `FailedCreate` means admission refused creation. A Pod that exists but will not start is already past admission, so inspect that Pod's events and container status. Different stage, different evidence."

> **Pause point.** Demos done.

---

# Close -- slides 25 and 26

**Say:** "Checking out with Globomantics. Priya's cluster now says no on its own. LimitRanger fills in what developers leave out and refuses values outside the range. ResourceQuota holds the namespace to a shared budget and returns that budget when work leaves. A security context narrows what a running container can do. Pod Security Admission stopped a privileged Pod before it existed. And when a workload fails, we follow the evidence: Deployment, ReplicaSet, Pod, and events. Authentication proves who you are. Authorization decides what you may do. Admission inspects the object. That is the complete gate, and that is this course."

---

## Kubernetes docs grounding -- not read aloud

- [Limit Ranges](https://v1-35.docs.kubernetes.io/docs/concepts/policy/limit-range/)
- [Resource Quotas](https://v1-35.docs.kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Resource Management for Pods and Containers](https://v1-35.docs.kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Configure a Security Context](https://v1-35.docs.kubernetes.io/docs/tasks/configure-pod-container/security-context/)
- [Pod Security Standards](https://v1-35.docs.kubernetes.io/docs/concepts/security/pod-security-standards/)
- [Pod Security Admission](https://v1-35.docs.kubernetes.io/docs/concepts/security/pod-security-admission/)
- [Admission Controllers](https://v1-35.docs.kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)

---

# Wrap

**31 commands.** Reset for the next take:

```bash
./lab.sh reset
```
