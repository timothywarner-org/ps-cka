# CKA Course 1 / Module 2 — Mastering kubectl Workflows

**Target runtime:** 13-14 min on camera
**Environment:** pwsh 7 in Windows Terminal or WSL2 Ubuntu
**Lab:** `kind-cka-lab` from Module 1 must still be running
**Authoritative demo script:** `src/cka-lab/lib/tutorials.ps1` → `Start-TutorialM02`
**Cleanup:** automatic via `try/finally` inside the tutorial function

---

## Pre-flight (run these BEFORE hitting record)

```powershell
# 1. Cluster from M01 should still be up
cd c:\github\ps-cka\src\cka-lab
kubectl config current-context                   # expect: kind-cka-lab
kubectl get nodes                                # expect: 3 Ready
kubectl get pods -A | Select-String -Pattern "default"  # expect: empty (clean default ns)

# 2. If M01 cluster is gone, rebuild FAST
# ./kind-up.ps1                                  # menu [2] Standard, tutorial [0]

# 3. Test-run the tutorial once off-camera
./Start-Tutorial.ps1                             # menu [3] Module 2
# 16 sections. Pay attention to the ones that create resources so
# you know what the try/finally block cleans up.
```

**Camera checklist:**

- [ ] Only system pods running (`kubectl get pods -A` shows nothing in `default`)
- [ ] Tab completion on for `kubectl` (type `kubectl get po` + TAB to confirm)
- [ ] Terminal scrollback clear
- [ ] `kind-multi-up.ps1` clusters NOT running yet (keeps focus on single cluster for first 15 steps)

---

## Click path (the exact button presses)

From a fresh pwsh prompt in `src/cka-lab`:

1. `./Start-Tutorial.ps1` → ENTER
2. Tutorial menu appears → type `3` → ENTER (selects Module 2)
3. Banner prints with "Press Enter to begin" → ENTER
4. **For each of the 16 sections, the rhythm is:**
    1. Section header + explanation appears
    2. Command + "What each part does" breakdown appears
    3. **Command fires automatically** (do NOT press Enter to trigger it)
    4. Output streams inline
    5. "What you just saw" output-field explainer appears
    6. `Press Enter to continue` prompt → ENTER to advance
5. After section 16, cleanup runs automatically (7 `kubectl delete ... --ignore-not-found` calls inside a `finally` block — prints "Done.")
6. You're back at your pwsh prompt. Cluster still up, demo objects gone.

**Total Enter presses for M02:** 1 (launch) + 1 (begin banner) + 16 (section advances) = **18 Enter keys across the whole module**.

**Pacing notes for recording:**

- Sections 1-5 fire instantly (API create is sub-second). Resist the urge to rush — the "What you just saw" block is where the teaching lives.
- Section 7 pipes through `Select-Object -First 25` — PS trims the output so you don't scroll past 60 lines of YAML.
- Sections 11-12 depend on the `web` Deployment from section 2 reaching Running state. That's ~9 sections / ~60 seconds later — plenty of time on a warm cluster. On a cold cache (first run of the day) pause on section 10 an extra 10 seconds to be safe.
- Ctrl-C at any point triggers the `try/finally` cleanup. Safe to abort a take.

---

## Open (30 sec on camera)

> "Two hours. Seventeen questions. Four clusters. The CKA exam isn't about knowing Kubernetes — it's about knowing it *fast*. In this module I'm going to give you the five kubectl workflows that win exam time: imperative creation, dry-run YAML generation, `kubectl explain`, resource querying, and context switching. By the end you'll create seven resources in under a minute with zero YAML files."

---

## Demo 1 — Imperative speed run (2-3 min)

**Goal:** Seven resources, zero YAML, under 60 seconds.

Start the tutorial:

```powershell
./Start-Tutorial.ps1                             # menu [3] Module 2
```

**Section 1/16 — `kubectl run nginx --image=nginx`**
The atomic unit. One command, one pod, one container. Fastest path to "is my cluster alive?".

**Section 2/16 — `kubectl create deployment web --image=nginx --replicas=3`**
Call out the chain: "Three things just happened — a Deployment, a ReplicaSet, and 3 Pods. Verify with `kubectl get deploy,rs,pods`."

**Section 3/16 — `kubectl expose deployment web --port=80 --type=ClusterIP`**
"Kubernetes auto-created DNS: `web.default.svc.cluster.local`. And the selector `app=web` came from the Deployment's labels."

**Section 4/16 — ConfigMap + Secret + Role + RoleBinding in four back-to-back commands**
Speed-read these — the point is the *rhythm* of imperative creation, not a deep RBAC lesson. Say: "That's seven resources, zero YAML files, about 45 seconds of typing. On the exam, this is how you answer easy questions fast."

**Section 5/16 — `kubectl get all`**
Quick sanity check. Call out the caveat: "`all` is a lie — it doesn't show ConfigMaps, Secrets, or RBAC. Don't trust it as a namespace inventory."

---

## Demo 2 — Dry-run YAML pipeline (2 min)

**Goal:** Generate manifests without touching the API server.

**Section 6/16 — Pod dry-run:**

```powershell
kubectl run temp --image=busybox --restart=Never --dry-run=client -o yaml
```

Call out: "`--dry-run=client` renders locally. Nothing hit the cluster. Pipe this to a file, edit, then `kubectl apply -f`. That's GitOps-ready."

**Section 7/16 — Deployment dry-run (first 25 lines only):**

```powershell
kubectl create deployment limited --image=nginx --replicas=2 --dry-run=client -o yaml |
  Select-Object -First 25
```

Walk viewers through the nested structure: `spec.replicas`, `spec.selector.matchLabels`, `spec.template.spec.containers`. That's the shape of every managed workload in Kubernetes.

---

## Demo 3 — kubectl explain (1-2 min)

**Goal:** Teach them to never leave the terminal to look up a field.

**Section 8/16 — `kubectl explain pod.spec.containers.resources`**
"This is the OpenAPI schema from the live cluster. No internet needed. Dot-path drilldown."

**Section 9/16 — `kubectl explain deployment.spec.strategy --recursive`**
"`--recursive` expands the whole subtree. This is gold for rollout strategy fields — `RollingUpdate`, `maxSurge`, `maxUnavailable`."

**Exam tip to drop here:**

> "Know the defaults cold: `maxSurge=25%`, `maxUnavailable=25%`. Writing a Deployment by hand on the exam? Delete the `strategy:` block entirely and you get these."

---

## Demo 4 — Resource querying (3 min)

**Goal:** Six ways to slice the same cluster state.

**Section 10/16 — `kubectl api-resources` filtered to common kinds**
Point at the SHORTNAMES column: `po`, `svc`, `deploy`, `cm`. Memorize them.

**Section 11/16 — `kubectl get pods -l app=web`**
Label selector. "This is how Services find Pods, how Deployments find their ReplicaSets — labels are the glue of Kubernetes."

**Section 12/16 — `kubectl get pods --field-selector status.phase=Running`**
"Field selectors filter on object *fields*, not labels. Only Running pods here — Pending, Failed, Succeeded are hidden. Combine with `-l` for compound filters."

**Section 13/16 — JSONPath extraction:**

```powershell
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
```

"Space-separated pod names. Perfect for `for p in $(...); do kubectl logs $p; done`."

**Section 14/16 — Custom columns:**

```powershell
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
```

"Design your own table. Empty NODE column means scheduler failed — instant debug signal."

**Section 15/16 — Sorted events:**

```powershell
kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 10
```

"Events are the cluster's activity log. Warning events at the bottom = your most recent problem."

---

## Demo 5 — Context switching with TWO real clusters (3 min)

**Goal:** Not just read the context — switch between two live clusters and prove the switch.

**Section 16/16 runs `kubectl config get-contexts`** against the single cluster. That's the minimum. But you're going to level this up on camera with the multi-cluster lab:

```powershell
# Tutorial step 16 runs, then let it finish cleanup.
# Open a second terminal tab to avoid the tutorial's try/finally cleanup race.

cd c:\github\ps-cka\src\cka-lab
./kind-multi-up.ps1 -SkipDdStart -Force          # creates cka-dev + cka-prod

# Now you have THREE contexts. Show them all:
kubectl config get-contexts
kubectl config use-context kind-cka-dev
kubectl get nodes                                # 2 nodes
kubectl config use-context kind-cka-prod
kubectl get nodes                                # 3 nodes
kubectl --context kind-cka-lab get nodes         # one-shot without switching
kubectl config current-context                   # still kind-cka-prod — one-shot didn't change default
```

**Pluralsight money shot:**

> "Four clusters on the exam. One wrong `use-context` and you're editing the wrong cluster and scoring zero on a question you actually know how to answer. The muscle memory is: verify first, switch explicitly, use `--context` for one-shots."

**Clean up the multi-cluster lab before recording Module 3:**

```powershell
./kind-multi-down.ps1 -Force                     # teardown
```

---

## Close (30 sec)

> "Five workflows: imperative creation, dry-run YAML, `kubectl explain`, resource querying, context switching. These are the muscle memory you need to pass. In Module 3 we dig into the most important 30% of the CKA — troubleshooting — and I'll teach you the four-rung diagnostic ladder that solves 95% of broken clusters. See you there."

---

## Reset between takes

The tutorial's `try/finally` block auto-deletes: `pod/nginx`, `deployment/web`, `svc/web`, `configmap/app-config`, `secret/db-pass`, `role/pod-reader`, `rolebinding/pod-reader-binding`. Even on Ctrl-C mid-tutorial.

```powershell
# Fast reset (cluster stays, demo objects go)
./Start-Tutorial.ps1                             # rerun the tutorial

# If state looks weird, nuke and rebuild
./kind-down.ps1 -Force
./kind-up.ps1                                    # menu [2], tutorial [0]
```

---

## Recovery cheat sheet

- **A create command fails "already exists"** → prior run's cleanup didn't complete. `kubectl delete pod nginx deployment/web svc/web cm/app-config secret/db-pass role/pod-reader rolebinding/pod-reader-binding --ignore-not-found`.
- **JSONPath returns empty** → you're in the wrong namespace. `kubectl config view --minify | grep namespace`.
- **Custom-columns command errors** → PowerShell ate a backtick. Paste as a single line or use a here-string.
- **`kind-multi-up.ps1` fails on port binding** → pass `-Force` or free ports 30100/30180/30200/30280.
- **Context switch lands somewhere unexpected** → another tool (Rancher Desktop, Docker Desktop k8s) may have written contexts. `kubectl config view -o jsonpath='{.contexts[*].name}'` to see all.

---

## Source mapping

Commands and narration come from [`src/cka-lab/lib/tutorials.ps1`](../src/cka-lab/lib/tutorials.ps1) → `Start-TutorialM02` (line 273). The multi-cluster context section uses [`src/cka-lab/kind-multi-up.ps1`](../src/cka-lab/kind-multi-up.ps1) (the two-cluster lab). Edit the PowerShell if you want the change to survive across modules; edit this runbook only for recording cues.
