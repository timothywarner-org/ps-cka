# CKA Course 1 / Module 3 — Core Resources and the Diagnostic Ladder

**Target runtime:** 16-18 min on camera
**Environment:** pwsh 7 in Windows Terminal or WSL2 Ubuntu
**Lab:** `kind-cka-lab` from Module 1 still running; default namespace clean
**Authoritative demo script:** `src/cka-lab/lib/tutorials.ps1` → `Start-TutorialM03`
**Cleanup:** automatic via `try/finally` inside the tutorial function

**This is the most important module in Course 1.** Troubleshooting is 30% of the CKA exam. The diagnostic ladder you teach in Demo 5 (sections 7-9) is the pattern learners will use in every subsequent course.

---

## Pre-flight (run these BEFORE hitting record)

```powershell
cd c:\github\ps-cka\src\cka-lab

# 1. Cluster still up and default namespace clean
kubectl config current-context                                          # kind-cka-lab
kubectl get all -n default                                              # only 'kubernetes' service
kubectl get ns staging --ignore-not-found                               # should be empty

# 2. Multi-cluster lab feeds the SCRIPTED Demo 6 (section 10/10)
./kind-multi-up.ps1 -SkipDdStart -Force                                 # idempotent; brings up cka-dev + cka-prod if missing
kind get clusters                                                       # expect: cka-lab, cka-dev, cka-prod

# 3. Switch back to the recording cluster BEFORE you hit record
kubectl config use-context kind-cka-lab
kubectl config current-context                                          # MUST print: kind-cka-lab

# 4. Test-run the tutorial once off-camera
./Start-Tutorial.ps1                                                    # menu [4] Module 3 (10 steps)
# 10 sections. The diagnostic ladder (7-9/10) is the climax.
# Section 10/10 is gated — if cka-dev or cka-prod aren't up, the tutorial
# prints a friendly skip banner and ends cleanly. The diagnostic ladder
# demos in sections 1-9 still run regardless.
# Watch the cleanup in try/finally — staging ns takes a few seconds to terminate.
```

**Camera checklist:**

- [ ] `kubectl get pods -A` shows only `kube-system` entries
- [ ] `kubectl get ns` shows only default / kube-* / local-path-storage
- [ ] M02 narration left learners on `kind-cka-lab` — confirm `current-context` before opening (Module 3 does NOT re-teach context verification; that's M02's territory)
- [ ] Terminal width 140+ (pod names with ReplicaSet hashes are long)
- [ ] Second tab open for watch commands if you want split-screen

---

## Click path (the exact button presses)

From a fresh pwsh prompt in `src/cka-lab`:

1. `./Start-Tutorial.ps1` → ENTER
2. Tutorial menu appears → type `4` → ENTER (selects Module 3, advertised as `10 steps — core resources, diagnostics, multi-cluster`)
3. Banner prints with "Press Enter to begin" → ENTER
4. **For each scripted section, the rhythm is:**
    1. Section header + explanation appears (ONCE per section, no matter how many beats)
    2. **Per beat** (sections 4, 6, 7, 8 are single-beat; sections 1, 2, 5, 9 are 2-beat; sections 3 and 10 are 3-beat):
        1. `---- Beat N.M: TITLE ----` header appears
        2. Command + "What each part does" breakdown appears
        3. **Command fires automatically** (do NOT press Enter to trigger it)
        4. Output streams inline
        5. "What you just saw" output-field explainer appears (skipped for silent-setup beats — 1.1, 2.1, 3.2, 5.1)
        6. `Press Enter to continue` prompt → ENTER to advance to the next beat (or next section)
5. After section 9/10, the multi-cluster guard runs. If `cka-dev` and `cka-prod` are both up, section 10/10 fires as **three teaching beats** (10.1 sticky switch + ladder, 10.2 one-shot `--context`, 10.3 cleanup + return home) — each beat fires its own Press-Enter prompt (3 prompts total for the section). If either cluster is missing, a skip banner prints (no Press-Enter prompt) and the tutorial moves to cleanup.
6. Cleanup runs automatically (`kubectl delete` for standalone, broken, managed-svc, managed, staging — plus a guarded `broken-dev` delete on `kind-cka-dev` and a final `kubectl config use-context kind-cka-lab` reset — prints "Done.")
7. You're back at your pwsh prompt. Cluster still up, demo objects + `staging` namespace gone (namespace takes 3-5 sec to finish Terminating).

**Total Enter presses for M03 (post-refactor — beat-level pacing):**

- Multi-cluster lab UP: 1 (launch) + 1 (begin banner) + 18 (beat advances: 2+2+3+1+2+1+1+1+2+3) = **20 Enter keys**
- Multi-cluster lab DOWN: 1 + 1 + 15 (sections 1-9 beats only: 2+2+3+1+2+1+1+1+2; section 10 skip-bannered) = **17 Enter keys** (the skip banner does not issue a Press-Enter prompt)

**Why beat-level pacing:** an Enter press belongs in front of a *teaching output* (something the learner is meant to read columns from, count rows, or compare against a previous beat) — never in front of *setup* or `Start-Sleep`. The scale → grown-slice transition in 3.2 → 3.3 is the highest-value cause/effect pairing in Course 1, and you want that Enter press between them so the learner pauses on the baseline-2-endpoints output before watching it grow.

**Pacing notes for recording — this module has built-in sleeps, don't fight them:**

- **Section 1/10** — Beat 1.1 chains both creates + `Start-Sleep 4` (silent setup). Beat 1.2 is the `kubectl get pods -o wide` teaching beat. Narrate the ownership column (`standalone` vs `managed-<rs-hash>-<pod-hash>`) on the 1.2 output, not 1.1.
- **Section 2/10** — Beat 2.1 deletes both pods + `Start-Sleep 6` (silent setup). Beat 2.2 is the **self-healing money shot** — `kubectl get pods -l app=managed; kubectl get rs`. The new pod (fresh AGE, different `<pod-hash>`) appears here. Pause here, narrate slowly: "This pod did not exist when we started this command. Reconciliation in action."
- **Section 3/10** — Three beats. **The EndpointSlice money shot is 3.2 → 3.3.** Beat 3.1 is the baseline (2 endpoints — matches `--replicas=2` from beat 1.1). Beat 3.2 is the scale (just the API ack — silent beat, no output explainer). Beat 3.3 is the grown slice (4 endpoints — the climax). Press Enter from 3.1 to 3.2 only after you've narrated the 2-endpoint baseline; press Enter from 3.2 to 3.3 only after the scale ack so the learner sees cause cleanly separated from effect.
- **Section 4/10** — Single beat. Spins up a debug pod, waits for nginx welcome page, auto-deletes. If you see `wget: bad address`, the Service isn't ready — Ctrl-C, wait 10 sec, re-run the tutorial.
- **Section 5/10** — Beat 5.1 creates the namespace, deploys catalog, applies the second label, `Start-Sleep 5` (silent setup). Beat 5.2 is the teaching beat — `-A` filter then compound `-l app=catalog,env=staging`. Narrate isolation on the `-A` output, narrate AND-semantics on the compound selector output.
- **Section 6/10** — Single beat. Same `sh -c '<two lookups>'` Pod (intentional — proves both lookups hit the same `/etc/resolv.conf`).
- **Section 7/10** runs `Start-Sleep 8` on purpose so the bad image tag trips `ImagePullBackOff` (not just `ErrImagePull`) by the time you see the status. Single beat.
- **Section 8/10** — Single beat. Filtered `kubectl describe`. Read the Events timeline top-to-bottom: Scheduled → Pulling → Failed.
- **Section 9/10** — Two beats. Beat 9.1 is `kubectl logs broken` (rung 3 — absence-as-clue). Beat 9.2 is `kubectl get events` (rung 4 — timeline). Drop the `--previous` exam tip on the 9.1 narration before you Enter into 9.2.
- **Section 10/10 is gated, three beats.** Beat 10.1 includes the same `Start-Sleep 8` as section 7 — wait for status to move from `ErrImagePull` to `ImagePullBackOff`. Beat 10.2 is the one-shot `--context` proof. Beat 10.3 is cleanup + return home. If `cka-dev` or `cka-prod` is missing the tutorial prints a skip banner pointing the learner at `./kind-multi-up.ps1` and exits to cleanup. No Enter press required for the skip path.

Ctrl-C at any point triggers the `try/finally` cleanup. Safe to abort a take.

---

## Open (45 sec on camera)

> "Thirty percent of the CKA exam is troubleshooting. Think about that — almost a third of your score depends on one skill: diagnosing broken clusters and broken workloads *fast*. In this module we build up to the single most important pattern in Kubernetes debugging: the four-rung diagnostic ladder. GET, DESCRIBE, LOGS, EVENTS. Every time, in that order. By the end of this module that sequence will be reflex. Then we'll switch to a second cluster and prove the ladder works anywhere — only the context changes."

---

## Demo 1 — Bare pod vs managed deployment, then self-healing (3 min)

**Goal:** Self-healing in action. Two sections, one arc: ownership creates self-healing.

**Section 1/10 — `BARE POD vs MANAGED DEPLOYMENT`** (2 beats)

```powershell
# Beat 1.1: CREATE BOTH (silent setup, no output explainer)
kubectl run standalone --image=nginx --restart=Never
kubectl create deployment managed --image=nginx --replicas=2
Start-Sleep 4

# ---  Press Enter ---

# Beat 1.2: VERIFY OWNERSHIP (the teaching beat)
kubectl get pods -o wide
```

Beat 1.1 is silent setup — Enter past it. Beat 1.2 is where you narrate. Point at the name pattern in the output: `standalone` has no suffix, `managed-<rs-hash>-<pod-hash>` has two. "That hash is the ReplicaSet's fingerprint. The `standalone` pod has no hash because no controller owns it. Ownership is the only thing that matters here."

**Section 2/10 — `SELF-HEALING: BARE DIES, MANAGED RESURRECTS`** (2 beats)

```powershell
# Beat 2.1: KILL BOTH (silent setup)
kubectl delete pod standalone --grace-period=1
$pod = (kubectl get pods -l app=managed -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $pod --grace-period=1
Start-Sleep 6

# ---  Press Enter ---

# Beat 2.2: WATCH IT RESURRECT (the money shot)
kubectl get pods -l app=managed
Write-Output '---'
kubectl get replicasets
```

Beat 2.1 = the kill (silent). Beat 2.2 = the resurrection (narrate slowly).

**Pluralsight money shot — narrate slowly:**

> "Look at the names after the sleep. One pod is seconds old. That pod didn't exist when we started this command. The ReplicaSet controller saw `actual=1, desired=2`, and did what controllers do — it reconciled. **This** is Kubernetes. Not the API, not the YAML — the reconciliation loop."

Then point at the ReplicaSet output below the divider: DESIRED, CURRENT, READY all match. "All three columns equal. The loop is quiet. When they don't match, something is wrong — that's your first diagnostic signal."

---

## Demo 2 — Services and EndpointSlices (3 min)

**Goal:** Services + EndpointSlices (v1.35 mechanism, NOT legacy Endpoints) in one section, then end-to-end test.

**Section 3/10 — `SERVICE + ENDPOINTSLICE: SCALE AND WATCH IT GROW`** (3 beats — the highest-value cause/effect pairing in Course 1)

```powershell
# Beat 3.1: BASELINE SLICE (2 endpoints — matches --replicas=2 from beat 1.1)
kubectl expose deployment managed --port=80 --type=ClusterIP --name=managed-svc
Start-Sleep 3
kubectl get endpointslices -l kubernetes.io/service-name=managed-svc -o wide

# ---  Press Enter (after narrating the baseline) ---

# Beat 3.2: SCALE TO 4 (the cause — silent, just the API ack)
kubectl scale deployment managed --replicas=4

# ---  Press Enter (the scale ack landed; new Pods are starting) ---

# Beat 3.3: GROWN SLICE (4 endpoints — the effect, the money shot)
Start-Sleep 8
kubectl get endpointslices -l kubernetes.io/service-name=managed-svc -o wide
```

Three beats, two snapshots of the same EndpointSlice. Narrate the baseline on 3.1 ("two endpoints, matches `--replicas=2`"). Beat 3.2 is just the scale ack — no output explainer fires. Beat 3.3 is where the slice grew to 4 — narrate the reconciliation chain: Deployment → ReplicaSet → Pods Ready → EndpointSlice updated → kube-proxy reprogrammed.

**Pluralsight money shot — exam-aligned:**

> "EndpointSlices, not Endpoints. The legacy Endpoints API is frozen — no dual-stack support, no topology hints. Since v1.21 every modern cluster — including the v1.35 cluster on your CKA exam — uses `discovery.k8s.io/v1` EndpointSlices. `kube-proxy` reads slices, not the legacy object. When a CKA question asks 'is the Service connected?', you check `kubectl get endpointslices -l kubernetes.io/service-name=<svc>`. Not `kubectl get endpoints`. That command still works for back-compat, but it's the wrong muscle memory."

**Section 4/10 — `TEST THE SERVICE END-TO-END`**

```powershell
kubectl run debug --image=busybox:1.36 --rm --restart=Never --attach `
  -- wget -qO- managed-svc | Select-Object -First 5
```

`<title>Welcome to nginx!</title>` = full path works. Call out the four-layer diagnostic: DNS, ClusterIP, kube-proxy, Pod. Each failure mode points at a different layer.

**Exam-pattern callout:**

> "Empty EndpointSlice is the most common 'Service is broken' clue. Label typo in the selector, Pods not Ready, wrong namespace — all show up here as a missing IP. This `wget` command exercises all four layers in one shot. Different errors point at different rungs."

---

## Demo 3 — Namespaces + compound label selectors (2 min)

**Goal:** Partitioning + the compound selector pattern the exam tests.

**Section 5/10 — `NAMESPACES + COMPOUND LABEL SELECTORS`** (2 beats)

```powershell
# Beat 5.1: SET UP STAGING (silent setup — namespace + deploy + label)
kubectl create namespace staging
kubectl -n staging create deployment catalog --image=nginx --replicas=2
kubectl -n staging label deployment catalog env=staging --overwrite
Start-Sleep 5

# ---  Press Enter ---

# Beat 5.2: ISOLATION + COMPOUND SELECTOR (the teaching beat)
kubectl get pods -A | Select-String -Pattern '(NAMESPACE|default|staging)'
Write-Output '---'
kubectl -n staging get pods -l app=catalog,env=staging
```

Beat 5.1 = silent setup. The `--overwrite` flag is a free exam-tip — call it out on 5.1's command-breakdown screen: "If the label key already exists, `kubectl label` requires `--overwrite` or the command fails. Cheap gotcha." Beat 5.2 = where you teach: isolation on the `-A` output, AND-semantics on the compound selector.

**Pluralsight money shot:**

> "Comma equals AND. `-l app=catalog,env=staging` matches Pods carrying BOTH labels — drop one and the result is empty. That's the compound selector. It's how Services pick the right Pods, how NetworkPolicies scope traffic, how the exam asks you to filter when 'all the catalog Pods' isn't specific enough. On the exam: `-A` on get to see across namespaces, compound `-l` to narrow. Get in the habit."

---

## Demo 4 — DNS (1-2 min)

**Goal:** Short name + FQDN in one beat. Same query, two scopes.

**Section 6/10 — `DNS: SHORT NAME + FQDN`**

```powershell
kubectl run dns-test --image=busybox:1.36 --rm --restart=Never --attach `
  -- sh -c 'getent hosts managed-svc; echo ---; nslookup managed-svc.default.svc.cluster.local'
```

One Pod, two lookups inside it (`sh -c` chains them). Point at why we use `getent` for the short name (busybox `nslookup` skips the search list — `getent` walks `/etc/resolv.conf` honestly).

**Exam mnemonic:** `service.namespace.svc.cluster.local`. Read it left to right — narrow to wide.

---

## Demo 5 — The diagnostic ladder (CLIMAX — 4-5 min)

**Goal:** Teach the four-rung pattern that solves 95% of Kubernetes problems. Three sections, one arc.

**Section 7/10 — `LADDER: BREAK IT ON PURPOSE`**

```powershell
kubectl run broken --image=nginx:doesnotexist --restart=Never
Start-Sleep 8
kubectl get pods broken
```

Expect STATUS = `ErrImagePull` or `ImagePullBackOff`. **Slow down here** — this is the key teaching moment. "Status is your first clue. RUNG ONE of the ladder is GET. Read the status before you describe anything."

**Section 8/10 — `LADDER: GET (status) + DESCRIBE (events)`**

```powershell
kubectl describe pod broken |
  Select-String -Pattern '(Status:|Events:|Normal|Warning|Failed|Back-off)' -Context 0,1
```

Narrate the output line by line:

- "Status is Pending — container never started."
- "State: Waiting: ImagePullBackOff — what's happening NOW."
- "Events timeline at the bottom. Read it top to bottom. `Scheduled` → `Pulling` → `Failed to pull`. **That's the smoking gun.** The pod was scheduled fine, kubelet tried to pull the image, the registry said no."

**Section 9/10 — `LADDER: LOGS + EVENTS`** (2 beats — rungs 3 and 4)

```powershell
# Beat 9.1: RUNG 3 -- LOGS (absence-as-clue)
kubectl logs broken 2>&1

# ---  Press Enter (after narrating the absence + the --previous exam tip) ---

# Beat 9.2: RUNG 4 -- EVENTS (the timeline)
kubectl get events --sort-by=.metadata.creationTimestamp `
  --field-selector involvedObject.name=broken
```

"Logs are empty — the container never started. That absence itself is a clue: the problem is image-related, not app-related." Drop the `--previous` exam tip on 9.1 BEFORE you Enter into 9.2, then narrate the events timeline as a different angle on the same problem.

**Drop the `--previous` exam tip here, on camera:**

> "One flag you must memorize: `kubectl logs --previous` — also written `-p`. After a container CRASHES and restarts, the regular `logs` command shows the new instance. `--previous` reads the LAST terminated container's stdout. That's the only way to debug a CrashLoopBackOff after the container has restarted. We can't demo it on this Pod because the container never started — there's no 'previous' to read. But on the exam, when you see CrashLoopBackOff, your hand goes to `--previous` automatically."

**Make viewers repeat the ladder:**

> "GET, DESCRIBE, LOGS, EVENTS. Say it with me. GET for status, DESCRIBE for events, LOGS for what the app said, EVENTS for the cluster-wide timeline. Every CKA troubleshooting question. Every one. In that order. This is the pattern that's going to carry you through Courses 9 and 10."

---

## Demo 6 — Same ladder, any cluster — SCRIPTED, ~3 min (gated)

**Goal:** Same ladder, different cluster. Show that the diagnostic pattern is universal — the only thing that changes is the context. **Three teaching beats inside one section** — each beat ends with its own Press-Enter prompt (3 prompts total for the section) so each cause/effect pairing reads cleanly on camera.

**Graceful-degrade:** if either `cka-dev` or `cka-prod` is missing, the tutorial prints

```text
Section 10/10 (multi-cluster ladder) skipped.
Bring up cka-dev + cka-prod with: ./kind-multi-up.ps1
Then re-run this tutorial to see the context-switching demo.
```

and exits to cleanup. No Enter press, no error. The diagnostic ladder demos in sections 7-9 still ran — the recording is recoverable even if the multi-cluster lab is down.

**Section 10/10 — `SAME LADDER, ANY CLUSTER`** (3 beats)

```powershell
# Beat 10.1: STICKY SWITCH + LADDER ON cka-dev
kubectl config use-context kind-cka-dev
kubectl get nodes                                       # 2 nodes confirms switch landed
kubectl run broken-dev --image=nginx:doesnotexist --restart=Never
Start-Sleep 8
kubectl get pod broken-dev                              # rung 1 on cka-dev
kubectl describe pod broken-dev |
  Select-String -Pattern '(Status:|Events:|Failed)' -Context 0,1   # rung 2 on cka-dev

# ---  Press Enter ---

# Beat 10.2: ONE-SHOT --context (no state mutation)
kubectl --context kind-cka-prod get nodes               # reads cka-prod WITHOUT switching
kubectl config current-context                          # STILL kind-cka-dev — proof

# ---  Press Enter ---

# Beat 10.3: CROSS-CLUSTER CLEANUP + RETURN HOME
kubectl --context kind-cka-dev delete pod broken-dev --ignore-not-found
kubectl config use-context kind-cka-lab                 # sticky home
kubectl config current-context                          # final sanity check
```

Each beat fires its own Press-Enter prompt. Narrate per beat:

- **Beat 10.1**: "Sticky switch — `use-context kind-cka-dev`. Future commands target cka-dev. Node count drops to 2 (1 CP + 1 worker) — visible proof. Same `nginx:doesnotexist` break pattern as section 7. Rungs 1 and 2 of the ladder fire identically on a fresh cluster."
- **Beat 10.2**: "`--context` is a one-shot override — query cka-prod's nodes WITHOUT switching the active context. After it runs, `current-context` STILL says kind-cka-dev. Proof that `--context` doesn't mutate state."
- **Beat 10.3**: "Cross-cluster delete via `--context kind-cka-dev` — we're cleaning up cka-dev's broken pod from a different active context. Then sticky switch home to `kind-cka-lab`. Final `current-context` confirms the session lands clean."

**Pluralsight money shot:**

> "Same ladder, any cluster. The diagnostic pattern is universal — the *only* thing that changes is which context you're in. That's why context discipline matters."
>
> "`--context` for verification, `use-context` for working sessions, ALWAYS end at home. That's the discipline that protects you on the exam."

---

## Close (45 sec)

> "Bare pods vs managed pods. Services and EndpointSlices. Namespaces and compound selectors. DNS short names and FQDNs. And the diagnostic ladder that's going to solve every broken thing you see on the exam — on whichever cluster the question drops you onto. GET, DESCRIBE, LOGS, EVENTS. Add `--previous` after a crash. That's Module 3 — ten sections, one pattern. That's Course 1. You now have a cluster, you can drive it, and you can debug it. In Course 2 we throw KIND away and build a real kubeadm cluster on Linux VMs — the exam-shaped environment. See you there."

---

## Reset between takes

The tutorial's `try/finally` block auto-deletes: `pod/standalone`, `pod/broken`, `svc/managed-svc`, `deployment/managed`, `namespace/staging`, plus a guarded `pod/broken-dev` on `kind-cka-dev` (only runs if `cka-dev` still exists). The finally block ends by forcing the active context back to `kind-$ClusterName` (defaults to `kind-cka-lab`) so back-to-back takes always start on the same cluster — even if Ctrl-C landed mid-section-10 with the context still pointing at `kind-cka-dev`.

```powershell
# Fast reset (cluster stays, demo objects go)
./Start-Tutorial.ps1                             # rerun M03 from the menu

# If something got stuck (rare)
kubectl delete pod standalone broken --ignore-not-found
kubectl delete deploy managed --ignore-not-found
kubectl delete svc managed-svc --ignore-not-found
kubectl delete ns staging --ignore-not-found
kubectl --context kind-cka-dev delete pod broken-dev --ignore-not-found
kubectl config use-context kind-cka-lab          # always end on the recording cluster

# If the cluster itself looks wedged
./kind-down.ps1 -Force
./kind-up.ps1                                    # [2] Standard, tutorial [0]
```

**Watch out:** `namespace/staging` takes ~5 sec to Terminate. Don't restart the tutorial while it's still disappearing — the deployment recreate will race.

**cka-dev / cka-prod stay UP between takes.** They're cheap to keep running and re-running `./kind-multi-up.ps1` between every take wastes minutes. Tear them down only when M03 recording wraps for the day:

```powershell
./kind-multi-down.ps1 -Force                     # end-of-day teardown
```

---

## Recovery cheat sheet

- **Section 2/10 "self-healing" doesn't show a new pod** → you timed the `get pods` too fast. Wait 5 more seconds. The replacement is coming.
- **Section 3/10 EndpointSlice shows zero ENDPOINTS** → the Deployment hasn't reached Ready yet. `kubectl get pods -l app=managed` to confirm. Wait 3-5 sec.
- **Section 3/10 returns "No resources found" instead of a slice** → label selector typo or Kubernetes < v1.21. Verify v1.35: `kubectl version --short`. The canonical slice label is `kubernetes.io/service-name=<svc>`.
- **`getent hosts` returns nothing in section 6/10** → busybox version pulled from a mirror without glibc. Re-pull `busybox:1.36` explicitly.
- **Broken pod in section 7/10 shows `ContainerCreating` forever** → image pull hit a rate limit on your real image, not the fake tag. Swap `nginx:doesnotexist` for `nosuchimage:v999`.
- **Tutorial cleanup leaves `staging` in `Terminating`** → stuck finalizer. `kubectl get ns staging -o json | jq '.spec.finalizers=[]' | kubectl replace --raw "/api/v1/namespaces/staging/finalize" -f -` (rare; only if you see it twice).
- **Demo 6 lands on the wrong context unexpectedly** → another tool (Rancher Desktop, Docker Desktop k8s) wrote contexts. See the M02 recovery cheat sheet — `kubectl config view -o jsonpath='{.contexts[*].name}'` to inventory.
- **Section 10/10 unexpectedly skips with a banner** → the guard requires both `cka-dev` and `cka-prod`. Run `kind get clusters` — you should see all three. If one is missing, `./kind-multi-up.ps1` will rebuild the pair.
- **`kind-multi-up.ps1` fails on port binding in pre-flight** → see the M02 recovery cheat sheet; pass `-Force` or free ports 30100/30180/30200/30280.

---

## Source mapping

Commands and narration come from [`src/cka-lab/lib/tutorials.ps1`](../src/cka-lab/lib/tutorials.ps1) → `Start-TutorialM03` (line 491; the `Write-TutorialBeatBody` helper at line 99 is what renders both the multi-beat `-Steps` path and the legacy single-`-Command` path). The `try/finally` cleanup block is around line 692 (after the multi-cluster guard) — verify those deletions against your pre-flight `kubectl get pods -A` before each take.

The diagnostic ladder (GET → DESCRIBE → LOGS → EVENTS) shows up again in Course 9 (troubleshoot clusters) and Course 10 (troubleshoot workloads). Keep the narration **identical** across modules — learners should be able to recite it back by Course 3. The `--previous` flag callout in section 9/10 is the seed for Course 10's CrashLoopBackOff scenarios.

EndpointSlices over legacy Endpoints is a deliberate v1.35 alignment — Course 7 (Services & Networking) doubles down on slices for the Gateway API + topology-aware routing demos. Don't accidentally drift back to `kubectl get endpoints` in any module.
