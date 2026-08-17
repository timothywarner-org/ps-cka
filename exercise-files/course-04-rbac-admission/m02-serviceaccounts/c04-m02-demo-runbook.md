# CKA Course 4 / Module 2 — ServiceAccounts and Least-Privilege Access

**Target runtime:** ~9 min on camera, four demos
**Environment:** Admin pwsh 7 → `vagrant ssh control1` → `cd ~/m02`
**Lab:** Hyper-V + Vagrant, three-node kubeadm cluster (control1/worker1/worker2 on `192.168.50.10/.11/.12`), Ubuntu 22.04, Kubernetes v1.35, containerd, **Calico** via the Tigera operator (pod CIDR `192.168.0.0/16`)
**One script on the node:** `./lab.sh [reset|jwt|verify]` — no arg means reset + verify
**One script on the host:** `src/cka-lab/Initialize-C04M02Lab.ps1` — boot, health-check, stage, gate, reset, checkpoint
**Cleanup between takes:** `./lab.sh reset` — ~10 seconds, no VM restore
**Last verified: 2026-08-17** — facts grounded against Kubernetes v1.35 source + docs. Demos not yet run; see the Verification ledger.

> **No `jq` anywhere, and that is not a style choice.** `jq` is **not installed** on a stock Ubuntu 22.04 server and kubeadm does not pull it in. Demo 3 is "decode the claims," so a `| jq` would have died on camera. Every JSON read here is `-o jsonpath`; the JWT decode is coreutils only, with base64url padding handled correctly (tested against all three padding residues).

> **M02 does not depend on M01.** Different namespace (`staging` vs `dev-team`), different objects. All it needs is the `cka-vagrant` context, which survives everything. Run it right after M01 with no rebuild.

> **Deck edit before you record.** Slide 9's third bullet should read *"Auto-generation stopped in Kubernetes v1.24, and no switch brings it back"* — the current *"the gate in v1.27"* is wrong (locked in v1.27, removed in v1.29) and it's trivia the CKA does not test. See `DECK-CORRECTIONS.md` for the other five.

---

## Slide-to-demo map

| Slides | Block | What you're teaching | Time |
|---|---|---|---|
| 18 | Demo framer | Three-node kubeadm cluster, v1.35, containerd | ~30 sec |
| 19 | **Demo 1** | An account of its own. `--serviceaccount`, never `--user`. **No Secret is created.** | ~2:15 |
| 20 | **Demo 2** | Prove the grant before a Pod exists. Three files, and the volume **admission** wrote. | ~2:45 |
| 21 | **Demo 3** | The claims that decide identity. **exp is a year out, not an hour.** Mint on demand. | ~2:15 |
| 22 | **Demo 4** | The failure worth recognizing on sight. Then take the credential away. | ~2:00 |
| 23-24 | Checkout + takeaways | Priya signs off → Module 3 | ~1:15 |

**Every demo opens with a context command.** Course standing convention — the exam runs six clusters and every task starts with `use-context`. Never cut the opening line.

---

## Setup and reset — the entire command surface

| When | Where | Command |
|---|---|---|
| **Start of a session** | host, admin pwsh | `.\Initialize-C04M02Lab.ps1` |
| VMs already running | host | `.\Initialize-C04M02Lab.ps1 -SkipBoot` |
| **Prove the demo works** | node, `~/m02` | `./lab.sh` |
| **Between takes** | node | `./lab.sh reset` |
| **On camera, Demo 3** | node | `./lab.sh jwt` |
| Broke the control plane | host | `.\Restore-CkaSnapshot.ps1 c04-m02-start` then `.\Initialize-C04M02Lab.ps1` |

**The 90% path is two lines:** `.\Initialize-C04M02Lab.ps1` on the host, then `cd ~/m02 && ./lab.sh` on the node.

**Why `reset` is enough:** deleting the `staging` namespace cascades to the ServiceAccount, Role, RoleBinding, and every Pod. Nothing this module creates is cluster-scoped.

---

## Pre-flight

```powershell
cd C:\github\ps-cka\src\cka-lab
.\Initialize-C04M02Lab.ps1
```

**Must end with:** `[OK] Lab is recording-ready for C04 M02`.

```bash
vagrant ssh control1
cd ~/m02 && ./lab.sh
```

**Exit 0** means every expected ALLOW succeeded and every expected DENY failed **for the right reason**. Read `~/dry-run-m02.txt`, re-run until nothing surprises you, then `./lab.sh reset` and roll.

### The fact gate — six claims, checked live

**A failure means the cluster disagrees with the deck. Do not record — fix the deck.**

| Gate | Protects |
|---|---|
| A fresh SA has an empty `.secrets` and no token Secret | Slide 9 — auto-generation stopped in v1.24 |
| No `LegacyServiceAccountToken*` feature gate is registered | Slide 9 — the behavior is unconditional on v1.35 |
| `expirationSeconds` on the injected volume is **3607** | Slide 10 — a precise number you say out loud |
| The projected token's `exp` is **~1 year**, with a `warnafter` claim | Slide 10 — the subtlest fact in the module |
| `--duration=5m` is refused with `less than 10 minutes` | Slide 13 — why the demo says ten |
| Missing SA → `error looking up service account`, **no Pod persisted** | Slide 14 — the deck is right, the outline is wrong |
| `jq` is **absent** on the node | Demo 3 breaks on camera if this ever changes |

### Camera checklist

- [ ] Admin pwsh, 16pt+, 140 cols, one window only
- [ ] `Initialize-C04M02Lab.ps1` ended `[OK]`
- [ ] On the node: `cd ~/m02`, `./lab.sh reset` printed `READY FOR TAKE`
- [ ] `kubectl config current-context` reads `cka-vagrant`
- [ ] **Slide 9 bullet edited** — no "gate in v1.27" on screen
- [ ] Deck slide 10 (the three files) on the second monitor for Demo 2

---

## Click path

1. `vagrant ssh control1` → `cd ~/m02`
2. **Demo 1** — 8 commands: contexts, namespace, `create sa`, prove no Secret, role, rolebinding, describe
3. **Demo 2** — 9 commands: context, 3 × `can-i --as`, apply Pod, wait, `ls` the mount, `cat` namespace, the 3607 jsonpath
4. **Demo 3** — 5 commands: context, `./lab.sh jwt`, `create token --duration=10m`, the 5m rejection
5. **Demo 4** — 6 commands: context, apply ghost, `get pod` (nothing), apply quiet-runner, wait, `ls` the missing mount
6. After you stop recording: `./lab.sh reset`

**~28 ENTERs**, 4 of them context commands. **No `sudo` anywhere** — nothing touches a root-owned file.

---

## The one concept the module hangs on

| | Human (Module 1) | Workload (this module) |
|---|---|---|
| Credential | X.509 client certificate | **Bearer token** (JWT) |
| Who issues it | The cluster CA, via a CSR you approve | The **TokenRequest API**, via the kubelet |
| Username | The cert's `CN` | `system:serviceaccount:<ns>:<name>` |
| Groups | The cert's `O` | `system:serviceaccounts`, `system:serviceaccounts:<ns>` |
| Where it lives | Your kubeconfig | A **projected volume** inside the Pod |

**Windows lens:** Module 1 issued a smart-card certificate to a person. This module creates a **managed service account** and hands the process a token it never has to store.

---

## Open — slide 18 (30 sec)

**Verbatim talk track:**

> "Priya's staging pipeline has deployed as cluster-admin since day one, and the auditor found it before she did. So here's the fix, live. I'll create a ServiceAccount with a Role narrow enough to defend, prove the grant before a single Pod exists, then run a Pod as that account and read the credential it's carrying — three files the kubelet put there. I'll decode the token and show you the one field everybody gets wrong. Then I'll break a Pod with a ServiceAccount that doesn't exist, because that failure looks nothing like people expect. Three-node kubeadm cluster, Ubuntu 22.04, containerd, Kubernetes v1.35. Let's go."

---

## Demo 1 — An account of its own (~2:15)

**Goal:** Build the identity and the grant, and prove along the way that **no Secret appears** — the v1.24 cutover, visible.

```bash
# [1.0] Look before you touch. Six clusters on the real exam.
kubectl config get-contexts

# [1.1] Namespace, then the account. `sa` is the abbreviation that saves you time.
kubectl create namespace staging
kubectl create sa deploy-bot -n staging

# [1.2] Where's the token Secret? There isn't one. That stopped in v1.24.
kubectl get sa deploy-bot -n staging -o jsonpath='{.secrets}'; echo "  <- empty"
kubectl get secrets -n staging

# [1.3] A Role narrow enough to defend every verb in it.
kubectl create role deployer \
  --verb=create,update,get,list \
  --resource=deployments,services -n staging

# [1.4] The binding. The flag is --serviceaccount, and it takes namespace:name.
kubectl create rolebinding deploy-bot-deployer \
  --role=deployer \
  --serviceaccount=staging:deploy-bot -n staging

kubectl describe rolebinding deploy-bot-deployer -n staging
```

**Expected.** `[1.2]` prints an empty value then `<- empty`, and `No resources found in staging namespace.` for Secrets. `[1.4]` describe shows `Kind: ServiceAccount`, `Name: deploy-bot`, `Namespace: staging`.

**Windows lens:** the ServiceAccount is a **managed service account** — a named identity the platform maintains. The Role is the permission set; the RoleBinding is group membership.

**Say — [1.2], the beat people miss:**

> "Look at that. Empty, and no Secrets in the namespace at all. Before Kubernetes 1.24, creating a ServiceAccount got you a Secret holding a token that never expired — and read access on that Secret was a working credential, forever. That auto-generation stopped in 1.24, and no switch brings it back. So where does the token come from now? That's Demo 2."

**Say — [1.4], the flag that costs people points:**

> "This is the flag worth memorizing: `--serviceaccount`, and it takes **namespace colon name**, not the bare name. And here's the trap — if you reach for `--user=deploy-bot` instead, the command succeeds, the binding gets created, and the grant does absolutely nothing. Green output, zero permission. Because the real username of a ServiceAccount is `system:serviceaccount:staging:deploy-bot`, and `--user` takes you literally."

**Exam tip (verbatim):**

> "Order of operations, and the tasks leave one out on purpose. ServiceAccount, then Role, then RoleBinding, then the Pod. Submit the Pod first and the API server refuses it outright — unlike a RoleBinding aimed at a Role that doesn't exist yet, which is accepted and simply grants nothing until the Role shows up."

**Pause point.**

---

## Demo 2 — Prove the grant, then read the credential (~2:45)

**Goal:** Verify by impersonation *before any Pod exists*, then run the Pod and show the three projected files — and the volume you never wrote.

```bash
# [2.0] Confirm the context.
kubectl config current-context

# [2.1] A ServiceAccount is just a username with a long prefix.
kubectl auth can-i create deployments -n staging \
  --as system:serviceaccount:staging:deploy-bot
kubectl auth can-i create secrets -n staging \
  --as system:serviceaccount:staging:deploy-bot
kubectl auth can-i --list -n staging \
  --as system:serviceaccount:staging:deploy-bot

# [2.2] Now the Pod that names it. One line does the work.
kubectl apply -f deploy-runner.yaml -n staging
kubectl wait --for=condition=Ready pod/deploy-runner -n staging --timeout=90s

# [2.3] Three files, projected in by the kubelet. No Secret involved.
kubectl exec -n staging deploy-runner -- ls -1 /var/run/secrets/kubernetes.io/serviceaccount/
kubectl exec -n staging deploy-runner -- cat /var/run/secrets/kubernetes.io/serviceaccount/namespace; echo

# [2.4] The volume is NOT in my YAML. Admission wrote it. Note the 3607.
kubectl get pod deploy-runner -n staging \
  -o jsonpath='{range .spec.volumes[*]}{.projected.sources[*].serviceAccountToken.expirationSeconds}{end}'; echo
```

**Expected.** `[2.1]` `yes`, then `no`, then a rules table. `[2.3]` exactly three names — `ca.crt`, `namespace`, `token` — then `staging`. `[2.4]` prints `3607`.

**Say — [2.1]:**

> "I'm testing the grant before a Pod exists, and that's the habit worth building. The subject is `system:serviceaccount:staging:deploy-bot` — namespace and name, with a prefix. Deployments, yes. Secrets, no, because the Role never mentioned them. And `--list` dumps everything that subject can do in there, which turns 'why is my pipeline Forbidden' from guesswork into reading."

**Say — [2.3], the memory hook:**

> "Three files. **token is who I am, ca.crt is who I trust, namespace is where I live.** And notice what's missing — there's no Secret object anywhere in this namespace. The kubelet asked the TokenRequest API for this token and wrote it straight into the Pod. Nothing to read, nothing to leak, nothing sitting in etcd waiting to be found."

**Say — [2.4], the sleight of hand worth exposing:**

> "Now open `deploy-runner.yaml` in your head. Did I declare a volume? No. I set one line, `serviceAccountName`. That projected volume was added by the **ServiceAccount admission controller** in the API server, and the kubelet is what fills it. Two different components, and people blur them. And look at the number — **3607** seconds. Everybody expects thirty-six hundred. You can't tune it, so if you need a different lifetime you write your own projection."

**Exam tip (verbatim):**

> "An empty `apiGroups` value means the **core** group, so Pods and Services and ConfigMaps live there — but Deployments do not. Deployments are in `apps`, and `kubectl create role --resource=deployments` fills that in for you. Hand-write the YAML and forget it, and you get a Role that looks right and grants nothing."

**If it breaks:** if `[2.2]` never goes Ready, `kubectl describe pod deploy-runner -n staging` and read the events — an image pull on a fresh node is the usual cause, not RBAC.

**Pause point.** This is the strongest beat in the module.

---

## Demo 3 — Decode the claims, mint on demand (~2:15)

**Goal:** Open the token, read the fields that decide identity and lifetime, and correct the one thing everybody gets wrong about `exp`.

```bash
# [3.0] Confirm the context.
kubectl config current-context

# [3.1] Decode the token the Pod is actually carrying. coreutils only -- no jq on this box.
./lab.sh jwt

# [3.2] Need a credential outside a Pod? Mint one. This is the post-1.24 answer.
kubectl create token deploy-bot -n staging --duration=10m

# [3.3] Ten minutes is the floor, not a round number.
kubectl create token deploy-bot -n staging --duration=5m
```

**Expected.** `[3.1]` prints `sub` = `system:serviceaccount:staging:deploy-bot`, the `aud`, the `iss`, an `exp` roughly **365 days** out, a `warnafter` about **60 minutes** out, and the `kubernetes.io` block naming the namespace, serviceaccount, pod, and node. `[3.3]` fails with `may not specify a duration less than 10 minutes`.

**Say — [3.1], and slow down, this is the correction:**

> "There's the `sub` claim, and that string is the username on the wire — the exact thing you hand to `--as`. Now look at `exp`. Everybody expects an hour, because the volume asked for 3607 seconds. It's about a **year** out. The API server extends injected tokens by default, and `warnafter` is the claim sitting at the hour mark. So what actually limits your exposure is not `exp` — it's **rotation**. The kubelet rewrites that file once the token passes eighty percent of its lifetime, or at twenty-four hours, whichever comes first. Which means your application has to reread the file. Cache it once at startup and you have written a time bomb."

**Say — [3.2] and [3.3]:**

> "`kubectl create token` hits the same TokenRequest API the kubelet uses, and prints a credential that stops working in ten minutes. And notice I said ten, not five — watch." — after the rejection — "Ten minutes is the server's floor. There are two other flags worth knowing: `--audience` names who the token is for, and unset means this API server. `--bound-object-kind` takes Node, Pod, or Secret, and ties the token's life to that object — bind it to a Pod and the token dies with the Pod. Small heads-up: the published API reference still lists only Pod and Secret. It's stale; the server takes Node."

**Exam tip (verbatim) — Distractor Watch:**

> "A task asks you to get a token to test a ServiceAccount, and one of the answers walks you through creating a Secret and reading the token out of it. That was the right answer before 1.24. The scored answer now is `kubectl create token`. If you find yourself hand-writing a Secret of type `kubernetes.io/service-account-token`, you are on the legacy path, and the docs call it the last resort."

**If it breaks:** if `./lab.sh jwt` reports it can't read the token, the Pod from Demo 2 isn't running — `kubectl get pod -n staging`.

**Pause point.**

---

## Demo 4 — Break it, then take the credential away (~2:00)

**Goal:** The failure worth recognizing on sight, and the floor below one narrow Role.

```bash
# [4.0] Confirm the context.
kubectl config current-context

# [4.1] A Pod naming a ServiceAccount that does not exist.
kubectl apply -f ghost-sa.yaml

# [4.2] Go looking for the Pod. There isn't one.
kubectl get pod ghost-runner -n staging

# [4.3] A workload that never calls the API server has no business holding a credential.
kubectl apply -f no-automount.yaml
kubectl wait --for=condition=Ready pod/quiet-runner -n staging --timeout=90s
kubectl exec -n staging quiet-runner -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```

**Expected.** `[4.1]` `Error from server (Forbidden): error when creating "ghost-sa.yaml": pods "ghost-runner" is forbidden: error looking up service account staging/does-not-exist: serviceaccount "does-not-exist" not found`. `[4.2]` `Error from server (NotFound)`. `[4.3]` the Pod goes Ready, then `ls` fails — **no such file or directory**.

**Say — [4.1] and [4.2], read the error aloud:**

> "Read that carefully. **Forbidden**, and the phrase that matters is *error looking up service account*. This happened at the API server during admission — before scheduling, and long before any kubelet was involved. So watch what happens when I go looking for the Pod. Nothing. No Pending Pod, no container error, nothing to describe, because **no Pod object was ever created.** Now here's why that's worth a slide of its own: people expect `CreateContainerConfigError`. That error is real, but it belongs to a missing ConfigMap or a missing Secret — it's a kubelet-stage failure, and the kubelet never saw this. If a Deployment owned the Pod, the evidence moves up to the owner: a `FailedCreate` event on the ReplicaSet and a `ReplicaFailure` condition on the Deployment."

**Say — [4.3]:**

> "Least privilege has a floor below one narrow Role, and that floor is no credential at all. `automountServiceAccountToken: false`, and the whole projected volume is gone — that path doesn't exist inside the container. Watch where the field goes, because it moves: a ServiceAccount has no `spec` block, so on the account it sits at the top level beside `metadata`. On a Pod it lives under `spec`. And if they disagree, **the Pod wins.**"

**Exam tip (verbatim) — Decision Tree:**

> "If the workload never talks to the API server, the branch is `automount false`, and you set it on the ServiceAccount so every Pod inherits it. If most Pods on that account shouldn't get a token but one has to, set false on the account and true on that one Pod. The Pod spec takes precedence, and that is documented, not folklore."

**Pause point.** Demos done. Stop recording, then `./lab.sh reset`.

---

## Slides 23-24 + close (~1:15)

**Slide 23 — Globomantics checkout (~30 sec).** Read Priya's line in character. She came in with a build robot holding cluster-admin; she's leaving with a ServiceAccount per workload and proof behind each one.

**Slide 24 — Key takeaways (~45 sec).** Read the three and add the exam framing:

1. **Every Pod already has an identity.** Didn't choose one? It's the namespace `default`, and on an RBAC cluster that account proves who it is and nothing more.
2. **Name it at creation or never.** `serviceAccountName` is on the Pod template, and a live Pod can't be repointed — the API server enforces that.
3. **The mounted token rotates; the Secret token doesn't.** A projected token belongs to the Pod. A Secret token is a standing credential with no owner and no expiry.

**Final close (verbatim):**

> "One ServiceAccount, one narrow Role, one binding that names it, and one line on the Pod template. We proved the grant before the Pod existed, read the three files the kubelet projected in, and found an `exp` a year out where everybody expects an hour — which is why rotation, not expiry, is what protects you. Then a missing ServiceAccount got refused at admission with no Pod to go looking for, and a quiet workload got no credential at all. There's one gap left, though. Nothing we did stops an engineer submitting a Pod that runs as root or claims every core on the node. Authorization said yes; nobody inspected the object. That's admission control, and that's where we're going next."

---

## Reset between takes

```bash
./lab.sh reset      # ~10 sec, prints READY FOR TAKE
```

Deleting the `staging` namespace takes the ServiceAccount, Role, RoleBinding, and all three Pods with it. Only rewind VMs if you broke the control plane:

```powershell
.\Restore-CkaSnapshot.ps1 c04-m02-start ; .\Initialize-C04M02Lab.ps1
```

---

## Recovery cheat sheet

| Symptom | Cause | Fix |
|---|---|---|
| `vagrant up` throws a Hyper-V error | Shell isn't elevated | Reopen pwsh 7 **as Administrator** |
| `vEthernet (CKA-NAT)` not present / vagrant hangs on SSH | Host adapter disabled | `.\Repair-CkaNatSwitch.ps1`, or enable it in `ncpa.cpl` |
| A fact GATE fails | Cluster disagrees with the deck | **Do not record.** Re-ground the slide first. |
| `./lab.sh jwt` says it can't read the token | Demo 2's Pod isn't running | `kubectl get pod -n staging`, re-apply `deploy-runner.yaml` |
| `jwt` prints garbage or truncated JSON | base64url padding | Shouldn't happen — the decoder is residue-tested. Report it. |
| Pod stuck `ContainerCreating` | Image pull on a cold node | `kubectl describe pod -n staging` and read events |
| `can-i` says `yes` to secrets | A stale binding survived | `./lab.sh reset` |
| `ghost-runner` actually got created | Admission plugin missing | Check `--enable-admission-plugins`; **do not record** |
| Node `NotReady` after a restore | Calico CNI token invalidated | `kubectl -n calico-system rollout restart ds/calico-node` |

---

## Exam pocket card

| Task | Command |
|---|---|
| List / show / switch context | `kubectl config get-contexts` · `current-context` · `use-context NAME` |
| Create a ServiceAccount | `kubectl create sa NAME -n NS` |
| Bind a Role to it | `kubectl create rolebinding NAME --role=R --serviceaccount=NS:SA -n NS` |
| **Never** for a ServiceAccount | `--user=SA` — succeeds, grants nothing |
| Name it on a Pod | `spec.serviceAccountName: SA` (Pod template; can't be changed live) |
| Test its access | `kubectl auth can-i VERB RES -n NS --as system:serviceaccount:NS:SA` |
| Mint a token | `kubectl create token SA -n NS --duration=10m` (10 min is the floor) |
| Tie a token to an object | `--bound-object-kind Pod --bound-object-name P --bound-object-uid U` |
| Turn the token off (account) | `automountServiceAccountToken: false` beside `metadata` |
| Turn it off (one Pod) | same field under `spec` — **the Pod wins** |
| The three projected files | `token`, `ca.crt`, `namespace` at `/var/run/secrets/kubernetes.io/serviceaccount/` |

**Memory hook.** `token` is who I am, `ca.crt` is who I trust, `namespace` is where I live.

**Read the failure, not your assumption.** Missing ServiceAccount → **Forbidden at admission, no Pod exists**. Missing ConfigMap or Secret → **`CreateContainerConfigError`, and the Pod is right there**. Different stages, different evidence.

---

## Source mapping

- **Live commands:** `lab.sh` in this folder is the single source of truth. Deck slides 12, 13, and 17 show the same commands on screen.
- **Manifests:** `deploy-runner.yaml`, `ghost-sa.yaml`, `no-automount.yaml` in this folder.
- **Corrections:** `DECK-CORRECTIONS.md` — six deck claims, with sources.
- **Grounding (v1.35):** [Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/) · [Configure SA for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) · [Managing SAs](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/) · [kubectl create token](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/) · [Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens)

---

## Verification ledger

### PROVEN — against Kubernetes v1.35 primary sources, 2026-08-17

Six-lens research pass, every finding handed to a skeptic instructed to refute it. Confirmed with verbatim quotes: the three projected files and their sources; `expirationSeconds: 3607`; `exp` extended to ~1 year with a `warnafter` claim at the hour; the SA username and group format; `automountServiceAccountToken` placement and Pod precedence; the missing-SA admission rejection text and the fact that **no Pod object is persisted**; the Deployment surfacing path (`FailedCreate` / `ReplicaFailure`); the 10-minute `--duration` floor; **`jq` absent** on stock Ubuntu 22.04.

**Six deck claims corrected** — see `DECK-CORRECTIONS.md`. One is a genuine error a learner could catch (slide 9's "gate in v1.27").

### UNVERIFIED — not yet run

| Unverified | How it closes |
|---|---|
| **Every command in every demo** | `cd ~/m02 && ./lab.sh` — exits 0 or names the check that drifted |
| `Initialize-C04M02Lab.ps1` | Never executed. PowerShell parse only. |
| The ~9 min runtime | Arithmetic from word count + 28 commands. Stopwatch the first take. |

`lab.sh` passes `bash -n`, and its JWT decoder is tested against all three base64url padding residues. **That is syntax and unit-level proof, not end-to-end proof.**
