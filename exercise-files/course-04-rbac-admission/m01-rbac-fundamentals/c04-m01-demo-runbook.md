# CKA Course 4 / Module 1 — Authentication, Authorization, and RBAC Fundamentals

**Target runtime:** ~12 min on camera, four demos
**Environment:** Admin pwsh 7 → `vagrant ssh control1` → `cd ~/m01`
**Lab:** Hyper-V + Vagrant, three-node kubeadm cluster (control1/worker1/worker2 on `192.168.50.10/.11/.12`), Ubuntu 22.04, Kubernetes v1.35, containerd, **Calico** via the Tigera operator (pod CIDR `192.168.0.0/16`) — the course standard since C02 M03
**One script on the node:** `./lab.sh [reset|mint|verify]` — no arg means reset + verify
**One script on the host:** `src/cka-lab/Initialize-C04M01Lab.ps1` — boot, health-check, stage, gate, reset, checkpoint
**Cleanup between takes:** `./lab.sh reset` — 8 seconds, no VM restore
**Last verified: 2026-08-17** — cluster health and all five fact gates PASSED live on control1; runbook↔`lab.sh` coherence verified command-for-command (38/39, two documented divergences). The four demos themselves are still unrun; see the Verification ledger.

> **Everything is idempotent.** Run anything twice. `reset` cascades the namespace delete, `mint` clears the spent CSR before resubmitting, `verify` exits 0 or names the check that drifted. Nothing here is worth restoring a checkpoint for — save that for a broken control plane.

> **Context discipline is a course standing convention.** Every demo opens with a context command. The exam runs **six clusters** and every task starts by telling you to `use-context` something; skip it and you do perfect work on the wrong cluster. Never cut the opening line, at any runtime.

---

## Slide-to-demo map

| Slides | Block | What you're teaching | Time |
|---|---|---|---|
| 19 | Demo framer | Three-node kubeadm cluster, v1.35, containerd | ~30 sec |
| 20 | **Demo 1** | No User object. Identity is free, authorization is not. **401 vs 403** | ~2:00 |
| 21 | **Demo 2** | Two objects never one. Read granted, write refused. `can-i --as` | ~3:00 |
| 22 | **Demo 3** | Same ClusterRole, two binding kinds. **The binding sets the scope** | ~2:45 |
| 23 | **Demo 4** | `view` never reads Secrets, `edit` does. Aggregation callout. `--dry-run` | ~1:50 |
| 24-25 | Checkout + takeaways | Priya signs off → Module 2 | ~1:15 |

**Measured runtime: ~9:40 at your usual 165 wpm, ~10:10 at 155.** That's 1,421 words you actually say aloud (the `> "..."` talk track plus the **Narrate** lines) over 39 demo commands at ~1.5 sec each. It corrects an earlier ~12:07 estimate that wrongly counted the design-note callouts as script. **You have room** — don't rush the two 403 beats.

**If you run long, cut in this order:** `describe role` in Demo 2 (~35 sec, it's on slide 13) → the `get secrets` 403 in Demo 2 (~25 sec, Step 2.4 already proved deny-by-default) → pre-create the namespace so Demo 1 opens on the mint (~30 sec, but you lose the order-matters teaching). **Never cut** an opening context command, the 403 in Demo 1, Demo 3's before/after pairs, or `--dry-run=client`.

---

## Setup and reset — the entire command surface

Two scripts, nine invocations, and that is everything. Nothing else to remember.

| When | Where | Command | What it does |
|---|---|---|---|
| **Start of a session** | host, admin pwsh | `.\Initialize-C04M01Lab.ps1` | Boot (`--no-provision`) → wait for SSH → confirm 3 Ready at v1.35/containerd → heal `calico-node` if needed → stage this folder to `~/m01` and `chmod +x` → rename context to `cka-vagrant` → 5-claim fact gate → reset → checkpoint |
| First run on fresh VMs | host | `.\Initialize-C04M01Lab.ps1 -Bootstrap` | The above, plus `kubeadm init --pod-network-cidr=192.168.0.0/16` and Calico via Tigera v3.29.1, then joins both workers |
| VMs already running | host | `.\Initialize-C04M01Lab.ps1 -SkipBoot` | Skips `vagrant up`; still verifies, stages, gates, resets |
| Mid-sprint, keep your save point | host | `.\Initialize-C04M01Lab.ps1 -SkipSnapshot` | Same, without writing a new checkpoint |
| **Prove the demo works** | node, `~/m01` | `./lab.sh` | Reset, then walk all four demos live. **Exit 0** = every expected allow allowed and every expected 403 denied. Exit 1 names the check that drifted. |
| Re-verify without resetting | node | `./lab.sh verify` | Just the walk, against current cluster state |
| **Between takes** | node | `./lab.sh reset` | Frame zero in ~8 sec. Prints `READY FOR TAKE`. Refuses to go green if it can't reach the API server. |
| **On camera, Demo 1** | node | `./lab.sh mint` | Key → CSR → `certificate approve` → signed cert → kubeconfig context. Idempotent. |
| Broke the control plane | host | `.\Restore-CkaSnapshot.ps1 c04-m01-rbac-ready` then `.\Initialize-C04M01Lab.ps1` | Rewinds all 3 VMs, ~60-90 sec |
| Absolute zero | host | `vagrant destroy -f` → `vagrant up --provider=hyperv` → `.\Initialize-C04M01Lab.ps1 -Bootstrap` | ~15-20 min. Only when a restore can't recover. |

**The 90% path is two lines.** `.\Initialize-C04M01Lab.ps1` on the host, then `cd ~/m01 && ./lab.sh` on the node. Everything else is an exception.

**Why `reset` is enough and a VM restore usually isn't needed:** deleting the `dev-team` namespace cascades to the Role and both RoleBindings. Only the ClusterRoleBinding, the CSR, and the two kubeconfig entries are cluster-scoped, and `reset` names those explicitly. Nothing this module creates is worth 90 seconds of checkpoint restore.

---

## Pre-flight

### Host — Administrator pwsh 7 (Hyper-V needs elevation, every time)

```powershell
cd C:\github\ps-cka\src\cka-lab
.\Initialize-C04M01Lab.ps1          # add -Bootstrap the first time on new VMs
```

Boots with `--no-provision`, waits for SSH on all three nodes, confirms 3 Ready at v1.35 on containerd, heals the CNI if a restore stranded it, pushes this folder to `~/m01/` and chmods the scripts, renames the context to `cka-vagrant`, runs the fact gate, resets, checkpoints.

**Must end with:** `[OK] Lab is recording-ready for C04 M01`.

### Node — one command

```bash
vagrant ssh control1
cd ~/m01 && ./lab.sh
```

Resets and then walks the whole module against the live cluster. **Exit 0** means every expected allow was allowed and every expected 403 was denied. Read `~/dry-run.txt` top to bottom, re-run until nothing surprises you, then `./lab.sh reset` and roll.

### The fact gate — five claims, checked live

`Initialize-C04M01Lab.ps1` asks the cluster whether the deck is still telling the truth. **A failure means the cluster disagrees with the deck. Do not record — fix the deck.**

| Gate | Protects |
|---|---|
| `system:basic-user` bound to `system:authenticated` | Demo 1 — `auth whoami` works with zero grants |
| `view` has no Secrets rule | Demo 4, slides 14/15/25 |
| `edit` can write Secrets | Demo 4, "the most-missed RBAC fact" |
| `view` covers Namespaces | **Demo 3 breaks on camera if this drifts** |
| `edit` has an `aggregationRule` | Demo 4's aggregation callout |

### Camera checklist

- [ ] Admin pwsh, 16pt+, 140 cols, prompt trimmed, one window only
- [ ] `Initialize-C04M01Lab.ps1` ended `[OK]`
- [ ] On the node: `cd ~/m01`, `./lab.sh reset` printed `READY FOR TAKE`
- [ ] `kubectl config current-context` reads `cka-vagrant`
- [ ] 1080p, no HiDPI blur, no taskbar, notifications off
- [ ] Deck slide 10 (RoleBinding vs ClusterRoleBinding) on the second monitor for Demo 3

---

## Click path

1. `vagrant ssh control1` → `cd ~/m01`
2. **Demo 1** — 8 commands: contexts, namespace, `./lab.sh mint`, contexts, switch, whoami, get pods (**403**), switch back
3. **Demo 2** — 13 commands: context, role, describe, binding, switch, get pods, 2 denials, switch back, 3 × `can-i`
4. **Demo 3** — 13 commands: context, RoleBinding, switch, 3 questions, back, ClusterRoleBinding, switch, same 3, back
5. **Demo 4** — 5 commands: context, built-ins, 2 greps, `--dry-run`
6. After you stop recording: `./lab.sh reset`

**39 demo commands** (8 / 13 / 13 / 5), **13 of them context commands** — plus `vagrant ssh`, `cd ~/m01`, and the post-take `./lab.sh reset`. Those are content, not overhead — each one is a beat where you say who you're becoming and why. Slow is smooth, smooth is fast.

**No `sudo` anywhere in this module.** Nothing touches a root-owned file. Say that on camera — it keeps the Linux user and the Kubernetes user from blurring together, which is the single most common confusion in this topic.

---

## The one concept the module hangs on

| Gate | Question | Failure | Meaning |
|---|---|---|---|
| **Authentication** | Who are you? | **401** | The cluster couldn't tell. Fix the credential. |
| **Authorization** | Are you allowed? | **403** | It knows exactly who you are and refuses. Fix the RBAC. |
| **Admission** | Should this object exist as written? | 4xx | Module 3. |

**Windows lens:** 401 is a bad or missing Kerberos ticket. 403 is "you're authenticated to the domain just fine, and the ACL on that share still says no."

---

## Open — slide 19 (30 sec)

> "Every engineer at Globomantics holds cluster-admin, and last Friday one of them deleted the production namespace. Priya's fixing that today, and so are we, live. Here's the plan. I'll build a real user out of a certificate and the cluster's going to refuse them. Then I'll grant one narrow permission and watch that same command start working. Then I'll try to write, and get refused again, which is the point. Three-node kubeadm cluster, Ubuntu 22.04, containerd, Kubernetes v1.35. The error messages are the lesson. Let's go."

---

## Demo 1 — Identity is free, authorization is not (~2:00)

**Goal:** The API server names this user precisely and still returns **403**. Every later demo leans on this.

```bash
# [1.0] Look before you touch. Six clusters on the real exam.
kubectl config get-contexts

# [1.1] Namespace first -- a Role is namespaced, so the order is tested.
kubectl create namespace dev-team

# [1.2] Mint a real user: key -> CSR -> cluster CA signs -> kubeconfig context.
./lab.sh mint

# [1.3] Two contexts now. Creating one does NOT switch you into it.
kubectl config get-contexts
kubectl config use-context frontend-dev
kubectl auth whoami

# [1.4] Now let them look at something.
kubectl get pods -n dev-team

# [1.5] Borrow an identity, do the one thing, hand it back.
kubectl config use-context cka-vagrant
```

**Expected:** `[1.3]` two rows with the star still on `cka-vagrant`, then `Switched to context "frontend-dev".`, then Username `frontend-dev` / Groups `[globomantics system:authenticated]`. `[1.4]` `Error from server (Forbidden): pods is forbidden: User "frontend-dev" cannot list resource "pods" in API group "" in the namespace "dev-team"`.

**Windows lens:** `./lab.sh mint` is issuing a smart-card style client certificate from your enterprise CA. `use-context` is `runas /user:` — you're not asking *about* an account, you're operating *as* one.

**Say — [1.0], set the convention and hold it all course:**

> "Every demo in this course opens exactly like this. A context is three things at once: a cluster, a user, and a default namespace. The real CKA exam runs **six clusters**, and every task starts by telling you to run `use-context` something. Skip that line and you'll do perfect work on the wrong cluster and score zero. Look before you touch."

**Say — [1.2], land the surprise:**

> "Here's what trips everybody up. **There is no User object in Kubernetes.** Try `kubectl get users`. Nothing comes back. A user is whatever the authentication layer decides your credential means, and for an X.509 cert that's two fields: CN becomes the username, O becomes a group. That's the entire user model. The script generated a key, submitted a CertificateSigningRequest, approved it with `kubectl certificate approve` — itself an exam command — and wired the signed cert into a context."

**Say — [1.3], slow down:**

> "Two contexts now, and notice creating one didn't switch me into it. So I switch, out loud, because from here every command runs as somebody else. Username frontend-dev. Group globomantics, straight out of the O field. And system:authenticated, added because the cert checked out against the cluster CA. **The cluster knows precisely who this is** — and that worked with zero permissions granted, because `system:basic-user` is bound to `system:authenticated`. Asking about yourself is free."

**Say — [1.4], the money shot:**

> "And it still says no. Read the status code, not the sentence: **403 Forbidden.** That's not a 401. A 401 would mean the cluster couldn't work out who you are. A 403 means it knows exactly who you are and it's refusing anyway. Authentication passed. Authorization failed. **That gap is the entire subject of this module.** And the error names four things — the user, the verb, the resource, and the namespace. Kubernetes hands you most of the diagnosis for free. RBAC is **deny by default**; there's nothing for me to take away here, because nothing was ever granted."

**Exam tip (verbatim):**

> "The CKA hands you a user who can't do something and asks you to fix it. **First thing you type is `kubectl auth whoami`.** Identity comes back? Authentication's fine, go find the missing Role or binding. Unauthorized? Stop looking at RBAC — your credential is wrong, and no Role you write will help."

**If it breaks:** `AlreadyExists` on the namespace or CSR means a prior take left state — narrate it ("already there from my last run, clearing it"), run `./lab.sh reset`, resume. A 401 instead of a 403 means the cert is bad: `./lab.sh mint` and resume at `[1.3]`.

**Pause point.** Stop the clip. You have a user who can prove who they are and do nothing.

---

## Demo 2 — Two objects, never one (~3:00)

**Goal:** Turn the 403 into a 200, then prove the grant is **narrow** by hitting a write wall. This is LO 1's highest-frequency exam skill.

```bash
# [2.0] Confirm the context before creating anything.
kubectl config current-context

# [2.1] A Role is a permission set attached to nobody yet.
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n dev-team
kubectl describe role pod-reader -n dev-team

# [2.2] The binding is the half that actually grants.
kubectl create rolebinding frontend-dev-reads --role=pod-reader --user=frontend-dev -n dev-team

# [2.3] Same command that failed in [1.4]. Nothing about the user changed.
kubectl config use-context frontend-dev
kubectl get pods -n dev-team

# [2.4] Write wall. get/list/watch was the whole grant.
#       Note the NAMED pod: `delete pod --all` would list (allowed), find
#       nothing, and exit 0 without ever asking about delete.
kubectl delete pod web-1 -n dev-team
kubectl create deployment nginx --image=nginx -n dev-team
kubectl get secrets -n dev-team

# [2.5] Hand it back, then ask the admin's version.
kubectl config use-context cka-vagrant
kubectl auth can-i list   pods -n dev-team --as frontend-dev
kubectl auth can-i delete pods -n dev-team --as frontend-dev
kubectl auth can-i --list      -n dev-team --as frontend-dev
```

**Expected:** `[2.1]` PolicyRule table, Resource Names **blank**, Verbs `[get list watch]`. `[2.3]` `No resources found in dev-team namespace.` — a success. `[2.4]` **three** Forbiddens — and note the first one is a 403, not a 404, even though `web-1` does not exist. `[2.5]` `yes`, `no`, then a rules table.

**Windows lens:** a Role is a permission set, not a group — the ACL entry list with nobody attached. The RoleBinding is group membership. `can-i --as` is the Effective Access tab.

**Say — [2.1] and [2.2]:**

> "Three flags is the whole command: verbs, resource, namespace. Type it until it's muscle memory, because you'll type it under a timer. And look at that empty Resource Names column — blank means all Pods here. Pass `--resource-name=web-1` and the rule reaches exactly one Pod. Then the binding, which is the half that actually grants. Two objects, never one. The Role says **what**, the binding says **who**, and 'I created the Role and it still doesn't work' is the number one RBAC ticket on earth."

**Say — [2.3], set it up before you press ENTER:**

> "Watch. I haven't touched the certificate. Same user, same command, and this is the exact thing that threw a 403 ninety seconds ago." — then, after it returns — "**No resources found is a success.** That's the API server saying *yes, you're allowed, and the namespace is empty*. A 403 looks nothing like this. One RoleBinding turned a refusal into an answer."

**Say — [2.4] and [2.5]:**

> "And here's the other half of the lesson. I granted get, list, and watch. I didn't grant delete. So the write comes back Forbidden — and that isn't a bug to go fix, that's the grant being **exactly as narrow as I designed it.** Now look closely at that first error, because there's a free lesson in it. There is no Pod called `web-1` in this namespace. I still got a **403, not a 404.** The API server authorizes your request *before* it ever goes looking for the object, which means a Forbidden tells you nothing about whether the thing exists. Handy on the exam, and handy at 2am. Secrets, same 403, different reason: nothing in pod-reader mentions Secrets at all. Then the version you'll actually use at work. `can-i --as` is your RBAC unit test, and you run it **before** a developer hits a 403 and files a ticket. `--list` is the one to memorize — it dumps every rule that applies to that subject, which turns 'why can't they do the thing' from guesswork into reading."

**Exam tip (verbatim):**

> "Classic trap. Binding to a ServiceAccount is `--serviceaccount=namespace:name`, **never** `--user`. Pass `--user=my-sa` and the command succeeds, the binding gets created, and the grant does nothing — because a ServiceAccount's real username is `system:serviceaccount:namespace:name`. Green output, zero permission."

**If it breaks:** `[2.3]` still Forbidden means the binding landed in the wrong namespace — `kubectl get rolebinding -A | grep frontend-dev`.

**Pause point.** Strongest beat in the module. Give it room.

---

## Demo 3 — The binding sets the scope (~2:45)

**Goal:** A controlled experiment. Hold the ClusterRole constant, change only the binding kind, ask the identical three questions before and after. Highest-yield concept in the module.

```bash
# [3.0] Admin again?
kubectl config current-context

# [3.1] Attach the built-in `view` with a NAMESPACED RoleBinding.
kubectl create rolebinding view-in-dev-team --clusterrole=view --user=frontend-dev -n dev-team

# [3.2] Three questions. Remember the answers.
kubectl config use-context frontend-dev
kubectl get configmaps -n dev-team
kubectl get configmaps -n kube-system
kubectl get namespaces
kubectl config use-context cka-vagrant

# [3.3] SAME ClusterRole. Different binding kind. No -n -- it has no namespace.
kubectl create clusterrolebinding frontend-dev-views-all --clusterrole=view --user=frontend-dev

# [3.4] The identical three questions.
kubectl config use-context frontend-dev
kubectl get configmaps -n dev-team
kubectl get configmaps -n kube-system
kubectl get namespaces
kubectl config use-context cka-vagrant
```

**Expected:** `[3.2]` allow, **deny**, **deny**. `[3.4]` allow, allow, allow — `get namespaces` lists every namespace on the cluster.

**Windows lens:** the RoleBinding grants rights on one OU. The ClusterRoleBinding grants the same rights at the domain root, inheriting to every OU that exists now or gets created later.

**Say — frame it as an experiment before `[3.1]`:**

> "I'm changing exactly one variable. Same user, same ClusterRole, same three questions. The only difference is the kind of binding object. And note the flag — `--clusterrole`, not `--role`. I'm reaching for a ClusterRole that already ships with Kubernetes and attaching it with a namespaced binding. That combination is the most useful pattern in RBAC: reuse one ClusterRole across many teams, let each team's RoleBinding decide where it applies."

**Say — [3.2]:**

> "ConfigMaps, not Pods — pod-reader never mentioned ConfigMaps, so that first result came from `view`. Then two refusals. **A RoleBinding is a fence,** and it doesn't care that `view` is a ClusterRole. The binding lives in dev-team, so the grant stops there. And a namespaced binding can't reach a cluster-scoped object like Namespaces with any role, ever."

**Say — [3.3] and [3.4], land it hard:**

> "Same ClusterRole by name. I'm not editing it, I'm not copying it, I haven't written a single rule. One new binding object — and no `-n` flag, because a ClusterRoleBinding has no namespace of its own. Now the identical three questions. Nothing about the permissions changed. The **reach** changed. Say it with me: **the role says what, the binding says where.**"

**Exam tip (verbatim):**

> "This is the decision tree for basically every RBAC question on the exam. Does the task name a namespace? RoleBinding. Does it say 'in all namespaces,' or name a cluster-scoped object like Nodes or PersistentVolumes? ClusterRoleBinding. One question, and you've picked the right object. And a ClusterRoleBinding is the one you get wrong at two in the morning — it applies in every namespace that exists today **and** every one anybody creates next year, and nothing about the object reminds you. Reach for a RoleBinding first, every time."

**If it breaks:** `[3.4]`'s `get namespaces` still denied — RBAC propagation lag. Wait two seconds and re-run. Don't debug on camera.

**Pause point.**

---

## Demo 4 — Built-ins, then let kubectl write the YAML (~1:50)

**Goal:** The declarative bookend. Prove the most-missed fact on the exam, land aggregation verbally, finish on the habit that saves the most exam time.

```bash
# [4.0] Context check, one last time. No switch needed -- this is all admin reading.
kubectl config current-context

# [4.1] The four that matter.
kubectl get clusterrole view edit admin cluster-admin

# [4.2] Prove the claim instead of asserting it.
kubectl describe clusterrole view | grep -i secret || echo "NO secrets rule in view"
kubectl describe clusterrole edit | grep -i '^  secrets'

# [4.3] Generate, don't memorize. --dry-run=client never hits the API server.
kubectl create role pod-reader --verb=get,list,watch --resource=pods --dry-run=client -o yaml
```

**Expected:** `[4.2]` prints `NO secrets rule in view` — `grep` matches nothing, so the `||` branch fires and echoes that line. Then a `secrets` row for `edit` listing the write verbs. `[4.3]` prints a Role manifest with the same rules as `pod-reader.yaml`. It is **not** byte-identical: the dry-run adds `creationTimestamp: null` and omits `namespace:` (there is no `-n` on the command). Say "same rules, and I'd add the namespace" rather than claiming they match exactly.

**Say — [4.2], the money shot:**

> "Here it is, the fact people miss. `view` never reads Secrets — no rule, nothing. `edit` reads them **and writes them.** So 'read-only' and 'safe' are not the same sentence. If an exam question hands you a user who shouldn't see credentials and offers `edit`, that's the trap."

**Say — aggregation callout, 15 seconds, no command (slides 16-17 already taught it):**

> "And `edit` doesn't own most of those rules. It carries a **label selector**, and a controller merges in every ClusterRole wearing that label. You compose permissions, you never copy them — and you never hand-write rules onto an aggregated ClusterRole, because the controller overwrites you."

**Say — [4.3]:**

> "That command created nothing. `--dry-run=client` means kubectl built the object in memory, printed it, and never touched the API server. Built-ins first, and remember `edit` reads Secrets. When they don't fit, don't write YAML from memory — run the imperative command with `--dry-run=client -o yaml`, redirect it to a file, edit the two lines that matter. That habit is worth minutes on the exam."

**Exam tip (verbatim):**

> "`can-i --list` and `--dry-run=client -o yaml` are the two to have loaded before you sit down. One tells you what a subject can already do, the other writes the object you're about to create. Between them you'll answer most RBAC tasks without opening the docs — and that saved time goes to the questions that are actually hard."

**Pause point.** Demos done. Stop recording, then `./lab.sh reset`.

---

## Slides 24-25 + close (~1:15)

**Slide 24 — Globomantics checkout (~30 sec).** Read Priya's line in character. She came in with a deleted namespace and a cluster where everyone was a superuser; she's leaving with an authorization model she can prove. The next gap is the workloads themselves.

**Slide 25 — Key takeaways (~45 sec).** Read the three and add the exam framing:

1. **Two objects, never one.** A Role says what, a binding says who. Unbound grants nothing.
2. **The binding sets the scope.** Same ClusterRole, one namespace or the whole cluster. That's the decision tree.
3. **Reach for the built-ins first** — and `edit` reads Secrets, which is the trap.

**Final close (verbatim):**

> "One user, built from a certificate, walked from a flat 403 to reading Pods and stopped cold at the first write — because that's exactly how far I granted. Then the same ClusterRole reached one namespace or the whole cluster depending on nothing but which binding I picked. Read the status code before the sentence, remember the binding sets the scope, and never hand over a grant the API server hasn't confirmed. One hole left, though. Every Pod here authenticates as a ServiceAccount, and unless somebody chose one, it's the namespace default. That's where we're going next."

---

## Reset between takes

```bash
./lab.sh reset      # 8 sec, prints READY FOR TAKE
```

Deleting the namespace takes the Role and both RoleBindings with it, so this genuinely returns you to frame one. Only rewind VMs if you broke the control plane:

```powershell
.\Restore-CkaSnapshot.ps1 c04-m01-rbac-ready ; .\Initialize-C04M01Lab.ps1
```

Rebuild from absolute zero (~15-20 min, rare): `vagrant destroy -f ; vagrant up --provider=hyperv ; .\Initialize-C04M01Lab.ps1 -Bootstrap`

---

## Recovery cheat sheet

| Symptom | Cause | Fix |
|---|---|---|
| `vagrant up` throws a Hyper-V error | Shell isn't elevated | Reopen pwsh 7 **as Administrator**. No workaround. |
| A fact GATE fails | The cluster disagrees with the deck | **Do not record.** Re-ground the slide against kubernetes.io. |
| **401** from the frontend-dev context | Cert bad or past its 7-day life | `./lab.sh mint`, resume at `[1.3]` |
| **403** where you expected success | Binding in the wrong namespace | `kubectl get rolebinding -A \| grep frontend-dev` |
| `can-i` says `yes` when you expect `no` | ClusterRoleBinding survived a take | `./lab.sh reset` |
| `AlreadyExists` on namespace or CSR | Prior take left state | `./lab.sh reset`. On camera, just narrate it. |
| Demo 3 `get namespaces` still denied | RBAC propagation lag | Wait 2 sec, re-run |
| Node `NotReady` after a restore | Checkpoint restore invalidated Calico's CNI token | `Initialize-C04M01Lab.ps1` heals it. By hand: `kubectl -n calico-system rollout restart ds/calico-node` |
| `Permission denied` on `./lab.sh` | Execute bit missing | `chmod +x ~/m01/lab.sh` — the staging step should have done this |

---

## Exam pocket card

| Task | Command |
|---|---|
| **List / show / switch context** | `kubectl config get-contexts` · `current-context` · `use-context NAME` |
| Set a default namespace | `kubectl config set-context --current --namespace=NS` |
| Namespaced Role | `kubectl create role NAME --verb=get,list,watch --resource=pods -n NS` |
| Cluster-wide Role | `kubectl create clusterrole NAME --verb=get,list --resource=nodes` |
| Bind inside one namespace | `kubectl create rolebinding NAME --role=R --user=U -n NS` |
| Bind a *ClusterRole* in one namespace | `kubectl create rolebinding NAME --clusterrole=view --user=U -n NS` |
| Bind cluster-wide | `kubectl create clusterrolebinding NAME --clusterrole=view --user=U` |
| Bind to a ServiceAccount | `--serviceaccount=NS:SA_NAME` (never `--user`) |
| Test somebody else's access | `kubectl auth can-i VERB RESOURCE -n NS --as USER` |
| Dump every rule for a subject | `kubectl auth can-i --list -n NS --as USER` |
| Who am I right now | `kubectl auth whoami` |
| Generate the manifest | append `--dry-run=client -o yaml` |

**Memory hook.** A Role is a job description. A binding is the offer letter. Nobody works there until somebody signs.

---

## Verification ledger — what is proven, and what is not

Read this before you trust anything above. **No command in this runbook has been executed against any Kubernetes cluster.** Your VMs were powered off during authoring (SSH on `.10/.11/.12` refused), and this authoring environment blocks container registries, so no substitute cluster could be built either. Every "Expected" line above is a prediction until `./lab.sh` says otherwise.

### PROVEN — on Tim's live cluster, 2026-08-16

`Initialize-C04M01Lab.ps1` ran against control1/worker1/worker2 and **all five fact gates passed**:

```
[OK] All 3 nodes report Ready
[OK] Kubelet version is v1.35.0 on all 3 nodes
[OK] Container runtime is containerd
[OK] GATE PASS  system:basic-user is bound to system:authenticated
[OK] GATE PASS  view has NO rule mentioning Secrets
[OK] GATE PASS  edit can write Secrets (create/delete/patch/update)
[OK] GATE PASS  view covers Namespaces (cluster-scoped reach for Beat 3)
[OK] GATE PASS  edit is composed via aggregationRule, not hand-written rules
```

That is the whole deck-claim surface, confirmed by the cluster rather than by anybody's assertion. Demo 3's
`get namespaces` payoff and Demo 4's `view`/`edit` Secrets contrast are now backed by this box, not just by
upstream source. `lab.sh reset` also ran clean here and printed `READY FOR TAKE`.

Still unrun as of that pass: the four demos end to end (`./lab.sh`). Until that exits 0, the per-command
expectations below remain predictions.

### ALSO PROVEN — against the Kubernetes `release-1.35` source of truth

Checked in `plugin/pkg/auth/authorizer/rbac/bootstrappolicy/policy.go`, the file that *defines* the default ClusterRoles. Verbatim quotes, not summaries.

| Claim | Evidence |
|---|---|
| `view` reads **configmaps** (Demo 3's proof) | `NewRule(Read...).Groups(legacyGroup).Resources("pods", ..., "configmaps")` |
| `view` reads **namespaces** (Demo 3's ClusterRoleBinding payoff) | `NewRule(Read...).Groups(legacyGroup).Resources("namespaces")` |
| `view` has **no** Secrets rule | `secrets` appears nowhere in `viewRules()` |
| `view` has **no** Nodes or PersistentVolumes rule | Neither string appears in `viewRules()` |
| `edit` **writes** Secrets | `NewRule(Write...)...Resources(... "secrets")`, Write = create/update/patch/delete/deletecollection |
| `edit`, `view`, `admin` are **aggregated** | `MatchLabels: {"rbac.authorization.k8s.io/aggregate-to-edit": "true"}` and siblings |
| `auth whoami` works with **zero grants** (Demo 1's whole hinge) | `NewRule("create").Groups(authenticationGroup).Resources("selfsubjectreviews")` in `basicUserRules`, bound via `NewClusterBinding("system:basic-user").Groups(user.AllAuthenticated)` |

> **One near-miss worth knowing.** A summarizing pass first reported "configmaps are **not** in view." Forcing a verbatim quote of `viewRules()` proved that wrong. If Demo 3 had shipped on the summary, Step 3.2's first command would have thrown a 403 on camera and the whole scope experiment would have collapsed. When a claim is load-bearing, quote the source; don't accept a paraphrase.

### FIXED after an adversarial multi-agent audit (2026-08-16)

Five independent lenses (bash, PowerShell, kubectl/RBAC semantics, cross-asset coherence, idempotency) audited
these files; every finding then faced a skeptic instructed to refute it. **15 of 16 findings survived.** The ones
that would have shown up on camera:

| Was | Why it mattered |
|---|---|
| Demo 2's write wall used `kubectl delete pod --all` | In an empty namespace kubectl LISTs (allowed), finds nothing, deletes nothing, **exits 0** — authorization for `delete` is never consulted, so **no 403 ever appears.** The single most important beat in the module produced "No resources found." Now a **named** delete (`web-1`), which the API server authorizes *before* looking for the object — so it returns 403, not 404, and that became a better teaching beat than the original. |
| `expect_deny` accepted **any** nonzero exit as a 403 | A missing kubectl, a refused connection, and a 401 from an expired cert all "passed." Now it requires a Forbidden in the output and reports 401 separately. |
| **No assertion existed on any expected-ALLOW step** | `verify` could print "every expected allow allowed" while an allow step was 403-ing. A false green — the exact failure this script exists to prevent. `expect_allow` now guards every one. |
| `delete namespace --wait=true` had no `--timeout` | kubectl substitutes **168 hours** when `--timeout` is omitted (`pkg/cmd/delete/delete.go`). A finalizer-stuck namespace would hang reset for a week, silently. Now `--timeout=90s`. |
| `$OutputEncoding` is BOM-emitting UTF8 | Every file piped to the node with `cat >` landed with `EF BB BF` before the shebang, so `./lab.sh` would die with a bad-interpreter error pointing nowhere. Now written BOM-less, and the staging check asserts byte 0 is `#`. |
| Fact gate 2 was a negative match over a piped `grep` | `grep` exits 1 when it finds nothing — indistinguishable from the whole command failing. The gate **passed whenever it broke.** Now jsonpath, and `Test-Gate` refuses to believe a negative assertion whose command exited nonzero. |
| Version check used substring `-match` | A mixed 1.34/1.35 cluster passed because "v1.35" appeared somewhere in the blob. Now requires exactly one distinct version across all three nodes. |
| A `\"` inside a double-quoted PowerShell string | Does not escape a quote in PowerShell — it *ends the string*. The CNI-heal awk reached the node malformed. Now a single-quoted here-string. |
| `rm -rf ~/m01` on every staging run | Yanked the working directory out from under any SSH session already sitting there. Now clears contents, keeps the directory. |

### UNVERIFIED — nobody has run these, including me

| Unverified | Risk | How `./lab.sh` closes it |
|---|---|---|
| Every command in every demo | High | `./lab.sh` runs all four demos and exits nonzero on any drift |
| Exact 403 wording on v1.35 | Low — format is stable, but I predicted it | It prints live; fix the "Expected" line if it differs |
| CSR signing latency on your hardware | Low | `mint` polls 20× at 1s instead of a blind sleep |
| `Initialize-C04M01Lab.ps1` actually working | **High** | Never executed. PowerShell **parses** clean (1360 tokens) — that is all that has been proven |
| `lab.sh` actually working | **High** | `bash -n` clean only. Syntax, not behavior. |
| The ~12 min runtime | Medium | Arithmetic from word count + ~38 ENTERs. **Not a stopwatch.** Time your dry run. |
| Your VMs' real state | — | Powered off at authoring time. Version, node count, CNI all unconfirmed. |

### One repo inconsistency — now resolved, in Calico's favour

**The course standard is Calico, and it is not close.** Evidence from the shipped exercise files: 14 references to `calico-node`, 9 to `tigera-operator`, 7 to `calico-system`, and **zero** to `kube-flannel`. `c02-m03-demo-runbook.md` installs it on camera with two pinned `kubectl create -f` lines (Tigera **v3.29.1**) and its Step 1.0 proves the pod CIDR alignment — kubeadm's `podSubnet: 192.168.0.0/16` matching Calico's default Installation CR. `Invoke-M03Lab.ps1` heals `calico-node` after every restore.

`src/cka-lab/bootstrap_cp.sh` is the **lone dissenter**: it installs Flannel `v0.24.4` on `10.244.0.0/16`. It's a Course 1 leftover. Booting a lab from it would put you on the wrong CNI *and* a pod CIDR that silently contradicts what you proved on camera in C02 M03.

**Handled:** `Initialize-C04M01Lab.ps1 -Bootstrap` no longer calls `bootstrap_cp.sh`. It runs `kubeadm init --pod-network-cidr=192.168.0.0/16` and installs Calico with the same two pinned Tigera URLs C02 M03 uses, then prints a warning that `bootstrap_cp.sh` is still stale. **Your call whether to delete that file or update it** — nothing in Course 4 touches it now.

---

## Source mapping

- **Live commands:** `lab.sh` in this folder is the single source of truth. Deck slides 13 and 18 show the same commands. Change one, change all three.
- **Lab bring-up + fact gate:** `src/cka-lab/Initialize-C04M01Lab.ps1` — lives beside the `Vagrantfile` because it dot-sources `lib/CkaLab.ps1` and walks `..\..\exercise-files\` to stage this folder.
- **Grounding (Kubernetes v1.35):** [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) · [Authorization](https://kubernetes.io/docs/reference/access-authn-authz/authorization/) · [Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/) · [CSRs](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/) · [kubectl auth](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/)
