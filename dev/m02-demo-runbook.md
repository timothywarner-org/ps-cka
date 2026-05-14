# CKA Course 1 / Module 2 — Mastering kubectl Workflows

**Target runtime:** 10-12 min on camera
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
# 10 sections. The headline is section 5/10 — apply round-trip + 'kubectl get all'
# in one beat. The try/finally cleans up apply-demo plus $HOME/web-apply.yaml.
```

**Camera checklist:**

- [ ] Only system pods running (`kubectl get pods -A` shows nothing in `default`)
- [ ] Tab completion on for `kubectl` (type `kubectl get po` + TAB to confirm)
- [ ] Terminal scrollback clear
- [ ] `kind-multi-up.ps1` clusters NOT running — multi-cluster context drills are M03's territory, not M02's

---

## Click path (the exact button presses)

From a fresh pwsh prompt in `src/cka-lab`:

1. `./Start-Tutorial.ps1` → ENTER
2. Tutorial menu appears → type `3` → ENTER (selects Module 2)
3. Banner prints with "Press Enter to begin" → ENTER
4. **For each of the 10 sections, the rhythm is:**
    1. Section header + explanation appears
    2. Command + "What each part does" breakdown appears
    3. **Command fires automatically** (do NOT press Enter to trigger it)
    4. Output streams inline
    5. "What you just saw" output-field explainer appears
    6. `Press Enter to continue` prompt → ENTER to advance
5. After section 10, cleanup runs automatically (8 `kubectl delete ... --ignore-not-found` calls plus a `Remove-Item $HOME/web-apply.yaml` inside a `finally` block — prints "Done.")
6. You're back at your pwsh prompt. Cluster still up, demo objects gone.

**Total Enter presses for M02:** 1 (launch) + 1 (begin banner) + 10 (section advances) = **12 Enter keys across the whole module**.

**Pacing notes for recording:**

- Sections 1-3 and 5 are the resource-creators. Sections 1-3 build the nine imperative resources; section 5 creates `apply-demo` from a saved manifest. All fire sub-second. Resist the urge to rush — the "What you just saw" block is where the teaching lives.
- Section 4 pipes through `Select-Object -First 25` — PS trims the output so you don't scroll past 60 lines of YAML.
- Section 5 chains five PowerShell statements end-to-end (`Set-Content`, `Get-Content | Select-Object -First 20`, `kubectl apply` x2, `kubectl get all`). Output is dense — the teaching beats are the `created` → `unchanged` flip on the second apply, then the `get all` reveal that ConfigMaps/Secrets/RBAC are MISSING from the listing (the "all is a lie" callout).
- Section 7 depends on the `web` Deployment from section 2 reaching Running state. That's ~5 sections / ~40 seconds later — plenty of time on a warm cluster. On a cold cache (first run of the day) pause on section 6 an extra 10 seconds to be safe.
- Ctrl-C at any point triggers the `try/finally` cleanup. Safe to abort a take.

---

## Open (30 sec on camera)

> "Two hours. Seventeen questions. Multiple clusters. The CKA exam isn't about knowing Kubernetes — it's about knowing it *fast*. In this module I'm going to give you the five kubectl workflows that win exam time: imperative creation, dry-run YAML, declarative apply, `kubectl explain`, and resource querying. By the end you'll create nine resources in under a minute with zero YAML files — then round-trip a manifest through `kubectl apply` to see idempotency in action."

---

## Demo 1 — Imperative speed run (2-3 min)

**Goal:** Nine resources, zero YAML, under 60 seconds.

Start the tutorial:

```powershell
./Start-Tutorial.ps1                             # menu [3] Module 2
```

**Section 1/10 — `kubectl run nginx --image=nginx`**
The atomic unit. One command, one pod, one container. Fastest path to "is my cluster alive?".

**Section 2/10 — Deployment + expose chained**

```powershell
kubectl create deployment web --image=nginx --replicas=3
kubectl expose deployment web --port=80 --type=ClusterIP
```

Two commands, five resources. Call out the chain: "Deployment, ReplicaSet, three Pods, then a Service with auto-created DNS at `web.default.svc.cluster.local`. The selector `app=web` came from the Deployment's labels — Service didn't need a YAML file." Verify with `kubectl get deploy,rs,pods,svc` (off-screen).

**Section 3/10 — ConfigMap + Secret + Role + RoleBinding in four back-to-back commands**
Speed-read these — the point is the *rhythm* of imperative creation, not a deep RBAC lesson. Say: "Nine resources, zero YAML files, under a minute of typing. On the exam, this is how you answer easy questions fast."

---

## Demo 2 — Dry-run pipeline + declarative apply (3-4 min)

**Goal:** Generate a manifest without touching the API server, then round-trip it through `kubectl apply -f` to see idempotency, then `get all` to verify the apply landed.

**Section 4/10 — Deployment dry-run (first 25 lines only):**

```powershell
kubectl create deployment limited --image=nginx --replicas=2 --dry-run=client -o yaml |
  Select-Object -First 25
```

Walk viewers through the nested structure: `spec.replicas`, `spec.selector.matchLabels`, `spec.template.spec.containers`. That's the shape of every managed workload in Kubernetes. Call out: "`--dry-run=client` renders locally. Nothing hit the cluster. Pipe this to a file, edit, then `kubectl apply -f`. That's GitOps-ready. The same flag works for `kubectl run`."

**Section 5/10 — APPLY: ROUND-TRIP + SEE EVERYTHING**

Now scripted in `tutorials.ps1`. The section runs this chain end-to-end with no manual typing:

```powershell
kubectl create deployment apply-demo --image=nginx --replicas=2 --dry-run=client -o yaml |
  Set-Content $HOME/web-apply.yaml
Get-Content $HOME/web-apply.yaml | Select-Object -First 20
kubectl apply -f $HOME/web-apply.yaml
kubectl apply -f $HOME/web-apply.yaml
kubectl get all
```

Closes the loop in one section: section 4 generates, this section saves to `$HOME/web-apply.yaml`, reads it back, applies it twice, then `get all` to verify and to set up the "all is a lie" callout. Point at each verb on screen as it lands:

- The first 20 lines of YAML preview = the artifact a GitOps repo would version
- `deployment.apps/apply-demo created` = first apply persisted the object
- `deployment.apps/apply-demo unchanged` = same manifest, server-side diff was empty, no rollout
- `kubectl get all` lists Pods, Services, Deployments, ReplicaSets — but watch what's missing

**Pluralsight money shot (the idempotency beat):**

> "Generate, save, apply, apply again. The second apply is the teaching point — `unchanged` is what idempotency looks like in Kubernetes. The exam asks 'apply this manifest' for a reason: declarative is safe to re-run, version-controllable, and how every real cluster outside the exam is managed."

**Pluralsight money shot (the 'all is a lie' beat):**

> "Look at this `get all` output. You see Pods, Services, Deployments, ReplicaSets. You do NOT see `app-config`, `db-pass`, `pod-reader`, or the RoleBinding I made in section 3. `kubectl get all` is a misleading alias — it skips ConfigMaps, Secrets, Ingresses, PVCs, and all RBAC. Don't trust it as a namespace inventory. On the exam, when you need a real audit, query each kind explicitly."

---

## Demo 3 — kubectl explain (1 min)

**Goal:** Teach them to never leave the terminal to look up a field.

**Section 6/10 — `kubectl explain deployment.spec.strategy --recursive`**
"This is the OpenAPI schema from the live cluster. No internet needed. `--recursive` expands the whole subtree — gold for rollout strategy fields like `RollingUpdate`, `maxSurge`, `maxUnavailable`. Drop `--recursive` for a single-level view of any one field."

**Exam tip to drop here:**

> "Know the defaults cold: `maxSurge=25%`, `maxUnavailable=25%`. Writing a Deployment by hand on the exam? Delete the `strategy:` block entirely and you get these for free."

---

## Demo 4 — Resource querying (3 min)

**Goal:** Three ways to slice the same cluster state, ordered from simplest to most surgical.

**Section 7/10 — `kubectl get pods -l app=web --show-labels`**
Label selector + label visibility in one. "This is how Services find Pods, how Deployments find their ReplicaSets — labels are the glue of Kubernetes. `--show-labels` reveals the LABELS column so you can see what you're filtering against. Field-side cousin: `--field-selector status.phase=Running` filters by built-in object fields instead of labels."

**Section 8/10 — JSONPath + custom-columns (merged):**

```powershell
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
# blank line + ---
kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase
```

The "aha" is the path reuse. "JSONPath gives you raw extracted values — space-separated pod names, perfect for scripting. Custom-columns wraps the SAME paths in a designed table. `.metadata.name` is the same string in both. Empty NODE column means scheduler failed — instant debug signal."

**Section 9/10 — Sorted events:**

```powershell
kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 10
```

"Events are the cluster's activity log. Warning events at the bottom = your most recent problem. This is the entry point to the diagnostic ladder you'll learn in Module 3."

---

## Demo 5 — Context awareness (1 min)

**Goal:** Single-cluster sanity check. Multi-cluster switching is Module 3's territory.

**Section 10/10 — `kubectl config get-contexts`**

The single-cluster minimum. The asterisk in the CURRENT column marks the active context. On camera, point at it and tee up M03:

> "One context, one asterisk — that's the minimum. The CKA exam puts you in front of multiple clusters. One wrong `use-context` and you're editing the wrong cluster, scoring zero on a question you actually know how to answer. In Module 3 we bring up a second cluster and drill the muscle memory: verify first, switch explicitly, use `--context` for one-shots."

---

## Close (30 sec)

> "Five workflows: imperative creation, dry-run YAML, declarative apply, `kubectl explain`, resource querying — and the context check that wraps everything. Nine imperative resources, one round-trip apply, and the queries that save you minutes per exam task. In Module 3 we dig into the most important 30% of the CKA — troubleshooting — with the four-rung diagnostic ladder that solves 95% of broken clusters, and we'll finally drill multi-cluster context switching against a live second cluster. See you there."

---

## Reset between takes

The tutorial's `try/finally` block auto-deletes: `pod/nginx`, `deployment/web`, `svc/web`, `configmap/app-config`, `secret/db-pass`, `role/pod-reader`, `rolebinding/pod-reader-binding`, `deployment/apply-demo`, plus `Remove-Item $HOME/web-apply.yaml`. Even on Ctrl-C mid-tutorial.

```powershell
# Fast reset (cluster stays, demo objects go)
./Start-Tutorial.ps1                             # rerun the tutorial

# If state looks weird, nuke and rebuild
./kind-down.ps1 -Force
./kind-up.ps1                                    # menu [2], tutorial [0]
```

---

## Recovery cheat sheet

- **A create command fails "already exists"** → prior run's cleanup didn't complete. `kubectl delete pod nginx deployment/web svc/web cm/app-config secret/db-pass role/pod-reader rolebinding/pod-reader-binding deployment/apply-demo --ignore-not-found`.
- **Section 5 `apply-demo` already exists from a prior run the cleanup somehow missed** → `kubectl delete deploy apply-demo --ignore-not-found; Remove-Item $HOME/web-apply.yaml -ErrorAction SilentlyContinue`.
- **JSONPath returns empty** → you're in the wrong namespace. `kubectl config view --minify | grep namespace`.
- **Custom-columns command errors** → PowerShell ate a backtick. Paste as a single line or use a here-string.
- **Context shows multiple clusters unexpectedly** → another tool (Rancher Desktop, Docker Desktop k8s) or a forgotten `kind-multi-up.ps1` run wrote contexts. `kubectl config view -o jsonpath='{.contexts[*].name}'` to see all. If `cka-dev`/`cka-prod` are present, run `./kind-multi-down.ps1 -Force -ClearRenamed` before recording.

---

## Source mapping

Commands and narration come from [`src/cka-lab/lib/tutorials.ps1`](../src/cka-lab/lib/tutorials.ps1) → `Start-TutorialM02` (line 374). Multi-cluster context switching is intentionally NOT in this module — it lives in Module 3 (`Start-TutorialM03`, section 10/10) with graceful-degrade behavior when `cka-dev`/`cka-prod` aren't running. Edit the PowerShell if you want the change to survive across modules; edit this runbook only for recording cues.
