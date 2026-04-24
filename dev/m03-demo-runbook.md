# CKA Course 1 / Module 3 — Core Resources and the Diagnostic Ladder

**Target runtime:** 13-14 min on camera
**Environment:** pwsh 7 in Windows Terminal or WSL2 Ubuntu
**Lab:** `kind-cka-lab` from Module 1 still running; default namespace clean
**Authoritative demo script:** `src/cka-lab/lib/tutorials.ps1` → `Start-TutorialM03`
**Cleanup:** automatic via `try/finally` inside the tutorial function

**⚠️ This is the most important module in Course 1.** Troubleshooting is 30% of the CKA exam. The diagnostic ladder you teach in Demo 5 is the pattern learners will use in every subsequent course.

---

## Pre-flight (run these BEFORE hitting record)

```powershell
cd c:\github\ps-cka\src\cka-lab

# 1. Cluster still up and default namespace clean
kubectl config current-context                                          # kind-cka-lab
kubectl get all -n default                                              # only 'kubernetes' service
kubectl get ns staging --ignore-not-found                               # should be empty

# 2. Multi-cluster lab from M02 should be DOWN (avoid context confusion)
kind get clusters                                                       # expect: cka-lab only

# 3. Test-run the tutorial once off-camera
./Start-Tutorial.ps1                                                    # menu [4] Module 3
# 18 sections. The diagnostic ladder at the end (15-18) is the climax.
# Watch the cleanup in try/finally — staging ns takes a few seconds to terminate.
```

**Camera checklist:**

- [ ] `kubectl get pods -A` shows only `kube-system` entries
- [ ] `kubectl get ns` shows only default / kube-* / local-path-storage
- [ ] Terminal width 140+ (pod names with ReplicaSet hashes are long)
- [ ] Second tab open for watch commands if you want split-screen

---

## Click path (the exact button presses)

From a fresh pwsh prompt in `src/cka-lab`:

1. `./Start-Tutorial.ps1` → ENTER
2. Tutorial menu appears → type `4` → ENTER (selects Module 3)
3. Banner prints with "Press Enter to begin" → ENTER
4. **For each of the 18 sections, the rhythm is:**
    1. Section header + explanation appears
    2. Command + "What each part does" breakdown appears
    3. **Command fires automatically** (do NOT press Enter to trigger it)
    4. Output streams inline
    5. "What you just saw" output-field explainer appears
    6. `Press Enter to continue` prompt → ENTER to advance
5. After section 18, cleanup runs automatically (`kubectl delete` for standalone, broken, managed-svc, managed, staging — prints "Done.")
6. You're back at your pwsh prompt. Cluster still up, demo objects + `staging` namespace gone (namespace takes 3-5 sec to finish Terminating).

**Total Enter presses for M03:** 1 (launch) + 1 (begin banner) + 18 (section advances) = **20 Enter keys across the whole module**.

**Pacing notes for recording — this module has built-in sleeps, don't fight them:**

- **Section 4** runs `Start-Sleep 3` after the delete. Let it run — gives kubelet time to tombstone.
- **Section 5** runs `Start-Sleep 5` after deleting a managed pod. This is the **self-healing moment** — the sleep is what makes the new pod appear in the next `get` call. Press Enter to advance only AFTER you see the new pod with a fresh AGE.
- **Section 9** runs `Start-Sleep 8` after `kubectl scale`. Needed for the new pods to reach Ready so they show up in Endpoints.
- **Section 10** spins up a debug pod, waits for nginx welcome page, auto-deletes. If you see `wget: bad address`, the Service isn't ready — Ctrl-C, wait 10 sec, re-run the tutorial.
- **Section 12** runs `Start-Sleep 5` after creating the catalog deploy in `staging`.
- **Section 15** runs `Start-Sleep 8` on purpose so the bad image tag trips `ImagePullBackOff` (not just `ErrImagePull`) by the time you see the status.
- **Section 18** uses `-NoRun` — the helper prints the command but doesn't execute it. The line is just a mnemonic slide.

Ctrl-C at any point triggers the `try/finally` cleanup. Safe to abort a take.

---

## Open (45 sec on camera)

> "Thirty percent of the CKA exam is troubleshooting. Think about that — almost a third of your score depends on one skill: diagnosing broken clusters and broken workloads *fast*. In this module we build up to the single most important pattern in Kubernetes debugging: the four-rung diagnostic ladder. GET, DESCRIBE, LOGS, EVENTS. Every time, in that order. By the end of this module that sequence will be reflex."

---

## Demo 1 — Bare pod vs managed deployment (3 min)

**Goal:** Self-healing in action. Delete a managed pod and watch the ReplicaSet resurrect it.

Start the tutorial:

```powershell
./Start-Tutorial.ps1                             # menu [4] Module 3
```

**Section 1/18 — `kubectl run standalone --image=nginx --restart=Never`**
"Bare pod. No controller. If it dies, nobody brings it back."

**Section 2/18 — `kubectl create deployment managed --image=nginx --replicas=2`**
"A Deployment owns a ReplicaSet, which owns Pods. That chain is what makes self-healing possible."

**Section 3/18 — `kubectl get pods -o wide`**
Point at the name pattern: `managed-<rs-hash>-<pod-hash>`. Say: "That hash is the ReplicaSet's fingerprint. The `standalone` pod has no hash because no controller owns it."

**Section 4/18 — delete the bare pod**
Gone. Done. "No resurrection because there's no controller."

**Section 5/18 — the self-healing money shot:**

```powershell
$pod = (kubectl get pods -l app=managed -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $pod --grace-period=1
Start-Sleep 5
kubectl get pods -l app=managed
```

**Pluralsight money shot — narrate slowly:**

> "Look at the names. One is seconds old. That pod didn't exist when we started this command. The ReplicaSet controller saw `actual=1, desired=2`, and did what controllers do — it reconciled. **This** is Kubernetes. Not the API, not the YAML — the reconciliation loop."

**Section 6/18 — `kubectl get replicasets`**
Point at the columns: DESIRED, CURRENT, READY. "All three match. The loop is quiet. When they don't match, something is wrong — and that's your first diagnostic signal."

---

## Demo 2 — Services and the selector-label contract (3 min)

**Goal:** Services, endpoints, and how they stay in sync with pods.

**Section 7/18 — `kubectl expose deployment managed --port=80 --type=ClusterIP --name=managed-svc`**
"A Service is Kubernetes' internal load balancer. It targets pods by label. DNS was auto-created: `managed-svc.default.svc.cluster.local`."

**Section 8/18 — `kubectl get endpoints managed-svc`**
This is the key concept: "The Service has a selector (`app=managed`). The endpoints controller watches pods with that label and populates this list. When a pod dies, its IP is removed. When a new pod joins with the right label, its IP is added. Real-time."

**Section 9/18 — scale to 4 and re-check endpoints:**

```powershell
kubectl scale deployment managed --replicas=4
Start-Sleep 8
kubectl get endpoints managed-svc
```

"The list grew. No manual Endpoint editing ever. This is the selector-label contract doing its job."

**Section 10/18 — test the Service from inside:**

```powershell
kubectl run debug --image=busybox:1.36 --rm --restart=Never --attach `
  -- wget -qO- managed-svc | Select-Object -First 5
```

`<title>Welcome to nginx!</title>` = routing works end-to-end. DNS resolved, ClusterIP answered, kube-proxy DNATed to a real Pod IP.

**Exam-pattern callout:**

> "Empty Endpoints list is the most common 'Service is broken' clue. Label typo in the selector, pods not Ready, wrong namespace — all show up here as a missing IP."

---

## Demo 3 — Namespaces (1-2 min)

**Goal:** Partitioning, and why `kubectl get pods` lies to you.

**Section 11/18 — `kubectl create namespace staging`**
"Namespaces partition resources. Pods in `staging` are invisible from `default` by default."

**Section 12/18 — Deployment into staging:**

```powershell
kubectl -n staging create deployment catalog --image=nginx --replicas=2
Start-Sleep 5
kubectl get pods -A | Select-String -Pattern '(NAMESPACE|default|staging)'
```

"`-n staging` targets one command. `-A` on get lists ALL namespaces — without it, you only see `default`. On the exam, `get pods` without `-A` will hide the answer more than once. Get in the habit."

---

## Demo 4 — DNS (1-2 min)

**Goal:** Short-name resolution within a namespace, FQDN across namespaces.

**Section 13/18 — short-name resolution (same namespace):**

```powershell
kubectl run dns-short --image=busybox:1.36 --rm --restart=Never --attach `
  -- getent hosts managed-svc
```

"We use `getent` here, not busybox nslookup — `getent` actually walks `/etc/resolv.conf`'s search list. Short name `managed-svc` resolves because we're in `default` and so is the Service."

**Section 14/18 — FQDN (any namespace):**

```powershell
kubectl run dns-fqdn --image=busybox:1.36 --rm --restart=Never --attach `
  -- nslookup managed-svc.default.svc.cluster.local
```

"FQDN is unambiguous. Works from any namespace. Format: `<service>.<namespace>.svc.cluster.local`."

**Exam mnemonic:** `service.namespace.svc.cluster.local`. Read it left to right — narrow to wide.

---

## Demo 5 — The diagnostic ladder (CLIMAX — 3-4 min)

**Goal:** Teach the four-rung pattern that solves 95% of Kubernetes problems.

**Section 15/18 — break something on purpose:**

```powershell
kubectl run broken --image=nginx:doesnotexist --restart=Never
Start-Sleep 8
kubectl get pods broken
```

Expect STATUS = `ErrImagePull` or `ImagePullBackOff`. **Slow down here** — this is the key teaching moment.

**Section 16/18 — Rungs 1 + 2 (GET + DESCRIBE):**

```powershell
kubectl describe pod broken |
  Select-String -Pattern '(Status:|Events:|Normal|Warning|Failed|Back-off)' -Context 0,1
```

Narrate the output line by line:

- "Status is Pending — container never started."
- "Events timeline at the bottom. Read it top to bottom. `Scheduled` → `Pulling` → `Failed to pull`. **That's the smoking gun.** The pod was scheduled fine, kubelet tried to pull the image, the registry said no."

**Section 17/18 — Rungs 3 + 4 (LOGS + cluster EVENTS):**

```powershell
kubectl logs broken 2>&1
Write-Output '---'
kubectl get events --sort-by=.metadata.creationTimestamp `
  --field-selector involvedObject.name=broken
```

"Logs are empty — the container never started. That absence itself is a clue: the problem is image-related, not app-related. Then cluster events show the same timeline from a different angle — useful when you don't know which pod is broken yet."

**Section 18/18 — the summary slide:**

```powershell
echo 'The diagnostic ladder: GET -> DESCRIBE -> LOGS -> EVENTS'
```

**Make viewers repeat it:**

> "GET, DESCRIBE, LOGS, EVENTS. Say it with me. GET for status, DESCRIBE for events, LOGS for what the app said, EVENTS for the cluster-wide timeline. Every CKA troubleshooting question. Every one. In that order. This is the pattern that's going to carry you through Courses 9 and 10."

---

## Close (45 sec)

> "Bare pods vs managed pods. Services and the selector-label contract. Namespaces. DNS short names and FQDNs. And the diagnostic ladder that's going to solve every broken thing you see on the exam. That's Module 3. That's Course 1. You now have a cluster, you can drive it, and you can debug it. In Course 2 we throw KIND away and build a real kubeadm cluster on Linux VMs — the exam-shaped environment. See you there."

---

## Reset between takes

The tutorial's `try/finally` block auto-deletes: `pod/standalone`, `pod/broken`, `svc/managed-svc`, `deployment/managed`, `namespace/staging`. Even on Ctrl-C.

```powershell
# Fast reset (cluster stays, demo objects go)
./Start-Tutorial.ps1                             # rerun M03 from the menu

# If something got stuck (rare)
kubectl delete pod standalone broken --ignore-not-found
kubectl delete deploy managed --ignore-not-found
kubectl delete svc managed-svc --ignore-not-found
kubectl delete ns staging --ignore-not-found

# If the cluster itself looks wedged
./kind-down.ps1 -Force
./kind-up.ps1                                    # [2] Standard, tutorial [0]
```

**Watch out:** `namespace/staging` takes ~5 sec to Terminate. Don't restart the tutorial while it's still disappearing — the deployment recreate will race.

---

## Recovery cheat sheet

- **Section 5 "self-healing" doesn't show a new pod** → you timed the `get pods` too fast. Wait 5 more seconds. The replacement is coming.
- **Section 8 shows empty ENDPOINTS** → the Deployment hasn't reached Ready yet. `kubectl get pods -l app=managed` to confirm. Wait 3-5 sec.
- **`getent hosts` returns nothing in section 13** → busybox version pulled from a mirror without glibc. Re-pull `busybox:1.36` explicitly.
- **Broken pod in section 15 shows `ContainerCreating` forever** → image pull hit a rate limit on your real image, not the fake tag. Swap `nginx:doesnotexist` for `nosuchimage:v999`.
- **Tutorial cleanup leaves `staging` in `Terminating`** → stuck finalizer. `kubectl get ns staging -o json | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/staging/finalize" -f -` (rare; only if you see it twice).

---

## Source mapping

Commands and narration come from [`src/cka-lab/lib/tutorials.ps1`](../src/cka-lab/lib/tutorials.ps1) → `Start-TutorialM03` (line 429). The `try/finally` cleanup block is at line 590 — verify those deletions against your pre-flight `kubectl get pods -A` before each take.

The diagnostic ladder (GET → DESCRIBE → LOGS → EVENTS) shows up again in Course 9 (troubleshoot clusters) and Course 10 (troubleshoot workloads). Keep the narration **identical** across modules — learners should be able to recite it back by Course 3.
