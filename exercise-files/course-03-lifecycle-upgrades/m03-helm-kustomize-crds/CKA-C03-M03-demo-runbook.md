# CKA Course 3 / Module 3 - Helm, Kustomize & CRDs

**Runbook rev: 1.5**  (1.5: added the cold-open intro blurb + a one-line hook on the app title frame. 1.4: on-screen explications are full teaching sentences; Phase 0 auto-heals Calico after the restore so workloads never hang. 1.3: app strips the talk track - screen shows command + one-line explication + a `[N.M]` beat tag matching this runbook; commands cleaned up. 1.2: SAY/PRESS ENTER marking. 1.1: file-forward cat + per-phase clear)

**Target runtime:** 14-16 min on camera
**Environment:** Hyper-V Vagrant lab (`control1`, `worker1`, `worker2`), Ubuntu 22.04, 2 vCPU / 2 GB each
**Lab starts at:** clean **v1.35** cluster (the state Module 2 left), **no Helm, no CRDs**
**CKA domain:** Cluster Architecture, Installation & Configuration (25%) - "Use Helm and Kustomize to install cluster components" and "Understand CRDs, and install and configure operators" (both Feb 2025 additions)

> **You read THIS; the app runs the commands.** The on-rails app
> [`Invoke-M03Lab.ps1`](../../../src/cka-lab/course-03-lifecycle-upgrades/Invoke-M03Lab.ps1)
> shows the command, a one-sentence explication, and the live output - it does
> **NOT** print this talk track. Your spoken narration is the **blockquotes** below.
>
> **Cross-reference by the `[N.M]` beat tags.** The app prints `[3.4]` next to a
> command; find `[3.4]` here for what to say. Phase number, then beat number. The
> bold `[N.M]` line in this runbook is the same full sentence the app shows on
> screen, so what you read and what the learner sees stay in lockstep.

---

## Recording cue card (glance here mid-take)

**SCREEN** = what the app runs when you press Enter. **SAY** = the ONE teaching beat
that must land before the next phase. Each phase fires on one Enter press; within a
phase the app streams its beats `[N.1]`, `[N.2]`, ... back to back.

| # | SCREEN runs | The ONE thing you SAY |
|---|---|---|
| 0 | `Restore m03-pre-helm` -> heal Calico -> push manifests -> `get nodes` | "Clean v1.35 cluster, no Helm, no CRDs. Our blank slate." |
| 1 | `explain --recursive`, `create --dry-run=client -o yaml` | **"Your fastest exam docs are in the TERMINAL. explain and dry-run scaffolding first, the one kubernetes.io tab second."** |
| 2 | install Helm -> `upgrade --install` -> `--set` -> `rollback` -> `history` | **"Every release is a numbered revision. upgrade rolls a new one, rollback is the undo. That history IS the lifecycle."** |
| 3 | `cat` base + overlays -> render -> `apply -k production` | **"One base, two overlays, no templating. namePrefix, replicas, a pinned prod image - the base never changes."** |
| 4 | `cat` CRD -> apply -> `explain backuppolicy` -> create CR -> `get bp` | **"A CRD teaches the API server a new noun. And because it has a schema, explain works against OUR kind."** |
| 5 | uninstall + `delete -k` + delete CRD | "Helm packages, Kustomize customizes, CRDs extend. Restore rewinds for the next take." |

**Bold rows (1-4) are the teaching beats.** The two signature moments: the
terminal-first doc reflex (Phase 1), and `kubectl explain` lighting up against a
kind that did not exist five seconds earlier (Phase 4).

---

## How to run it

```powershell
# Elevated PowerShell 7, from the Course 3 lab controls folder:
cd C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades

# One command. Auto-restores the clean v1.35 cluster, heals Calico, pushes the
# manifests, walks all 5 phases. The screen shows commands + [N.M] tags; you
# narrate from this MD.
.\Invoke-M03Lab.ps1
```

**Idempotent by design.** Launch restores `m03-pre-helm`, so every run starts from
the identical clean v1.35 cluster (no Helm, no CRDs). The restore wipes the pushed
manifests too, so the app re-pushes them before Phase 0's starting frame. Ctrl-C is
safe; re-launch resets you.

**Camera checklist:**

- [ ] `m03-pre-helm` checkpoint exists on all 3 VMs (the app verifies and aborts if not)
- [ ] **Network reachable** - beat `[2.1]` installs Helm from the internet AND `[2.2]/[2.3]` pull the podinfo chart live. **Rehearse once** (`.\Invoke-M03Lab.ps1 -SkipRestore`) before recording to warm DNS and confirm both reach out cleanly. This is the only live external dependency.
- [ ] **Calico auto-heal is automatic.** Restoring the snapshot invalidates Calico's CNI token, which would otherwise make pods fail with `calico ... Unauthorized` and hang `helm --wait`. Phase 0 now bounces `calico-node` and waits for it (~30-60s, off-camera) before any workload runs. If you ever see that error, the manual fix is `kubectl -n calico-system rollout restart daemonset/calico-node`.
- [ ] Terminal >= 18pt, scrollback clear

> **Paths:** the app runs the Kustomize/CRD beats from the demo folder on the node,
> so the on-screen commands use **relative paths** (`m03-kustomize-demo/...`). The
> commands below match exactly - what you read is what learners see.

---

## Cold open (say this, ~20 seconds, before you press Enter into Phase 1)

> "Last module, we upgraded this cluster to v1.35 by hand, one component at a time -
> that's the control the exam wants from you. This module is the other half of
> cluster lifecycle: doing it the **easy** way. Three tools, one job each.
>
> **Helm** packages an entire application as a chart, so you install it, upgrade it,
> and roll it back with single commands. **Kustomize** takes one base and bends it
> into staging or production with no templating and no copy-paste. And a **Custom
> Resource Definition** teaches the Kubernetes API a brand-new kind of object -
> which is exactly how operators extend the platform.
>
> Package it, customize it, extend it. All live, about fifteen minutes. Let's build."

---

## Phase 1 - Documentation: your terminal is the manual

> "On exam day the clock is the enemy, and your fastest documentation is not the
> browser - it is the terminal. `kubectl explain` is the live, version-correct schema
> for any field, and `--recursive` walks the whole tree. And `--dry-run=client -o yaml`
> SCAFFOLDS a manifest in seconds instead of typing it. Two reflexes that save you
> minutes per task."

**[1.1]** kubectl explain prints the live, version-correct schema for any field, straight from the API server.
```bash
kubectl explain deployment.spec.strategy --recursive
```

**[1.2]** The --dry-run=client flag scaffolds a manifest as YAML without creating anything on the cluster.
```bash
kubectl create deployment web --image=nginx --dry-run=client -o yaml
```

> **DOC DIVE (say this):** "When the terminal isn't enough, you get ONE browser tab -
> kubernetes.io/docs. Confirm the exact allowed domains on the Linux Foundation exam
> page before test day."
>
> **CKA TIP (say this):** "`explain --recursive`, `--help`, and `--dry-run=client -o yaml`
> are offline and instant. Reach for them before the browser - zero context switches."

---

## Phase 2 - Helm: install, release, upgrade, rollback

> "Helm packages a whole application - many manifests - as one versioned CHART, and
> each install is a tracked RELEASE with a revision history you can roll back. It is
> not on the cluster yet, so first we install the client. This is a teaching beat: on
> the exam, Helm is already on the box."

**[2.1]** We install the Helm client using the canonical one-line installer from helm.sh.
```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**[2.2]** We register a chart repository and refresh its local index so Helm can find the chart.
```bash
helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update
```

**[2.3]** helm upgrade --install deploys the release, creating it the first time and upgrading it on later runs.
```bash
helm upgrade --install globo-podinfo podinfo/podinfo --wait
```

**[2.4]** helm list shows our release sitting at revision 1.
```bash
helm list
```

> "Change ONE value - bump the replica count - and Helm rolls a NEW revision instead
> of editing live objects by hand."

**[2.5]** Changing a single value makes Helm roll a brand-new revision instead of editing the live objects by hand.
```bash
helm upgrade globo-podinfo podinfo/podinfo --reuse-values --set replicaCount=3 --wait
```

**[2.6]** Rolling back to revision 1 proves that every Helm release has an undo button.
```bash
helm rollback globo-podinfo 1 --wait
```

**[2.7]** helm history is the revision ledger, recording the install, the upgrade, and the rollback.
```bash
helm history globo-podinfo
```

> **CKA TIP (say this):** "`helm upgrade --install` is idempotent - install or upgrade
> in one verb. Every release keeps a numbered revision history; `helm rollback <rel>
> <rev>` is your undo."

---

## Phase 3 - Kustomize: one base, many overlays

> "Kustomize is built into kubectl - no extra binary. You keep ONE base, then layer
> overlays that patch it per environment. No templating language, no copies. These
> commands run from the demo folder, so the paths are relative - exactly what you'd
> type on the exam."

**[3.1]** This is the base Deployment, the plain workload with no environment-specific opinions baked in.
```bash
cat m03-kustomize-demo/base/deployment.yaml
```

**[3.2]** The base kustomization simply lists the resources that make up the application.
```bash
cat m03-kustomize-demo/base/kustomization.yaml
```

**[3.3]** The staging overlay patches the base, adding a name prefix, an env label, and two replicas.
```bash
cat m03-kustomize-demo/overlays/staging/kustomization.yaml
```

**[3.4]** kubectl kustomize renders the staging result so you can inspect it before anything is applied.
```bash
kubectl kustomize m03-kustomize-demo/overlays/staging
```

**[3.5]** The production overlay patches the same base with four replicas and a pinned image tag.
```bash
cat m03-kustomize-demo/overlays/production/kustomization.yaml
```

**[3.6]** Rendering production shows the pinned image, so this environment never drifts onto a floating tag.
```bash
kubectl kustomize m03-kustomize-demo/overlays/production
```

**[3.7]** kubectl apply -k applies the production overlay to the cluster for real.
```bash
kubectl apply -k m03-kustomize-demo/overlays/production
```

**[3.8]** The result proves the overlay worked: four replicas, prod- names, and the env=production label.
```bash
kubectl get deploy,svc -l env=production
```

> **CKA TIP (say this):** "`kubectl apply -k <dir>` applies an overlay; `kubectl
> kustomize <dir>` renders it so you can eyeball the result first. Both ship inside
> kubectl - nothing to install."

---

## Phase 4 - CRDs: a new kind in the API

> "A CustomResourceDefinition adds a brand-new kind to the API as if it shipped
> natively. We define BackupPolicy - a Globomantics object that records an etcd
> backup schedule. Apply the CRD and the API server starts serving that type."

**[4.1]** This CustomResourceDefinition declares a new BackupPolicy kind along with the schema that validates it.
```bash
cat m03-crds-demo/backuppolicy-crd.yaml
```

**[4.2]** Applying the CRD registers the new kind with the API server.
```bash
kubectl apply -f m03-crds-demo/backuppolicy-crd.yaml
```

**[4.3]** The API server now serves our kind, which we can query by name with no grep required.
```bash
kubectl get crd backuppolicies.globomantics.io
```

> "Here is the payoff that ties back to Phase 1: because we gave the CRD a structural
> schema, `kubectl explain` now works against our OWN kind."

**[4.4]** Because the CRD carries a schema, kubectl explain now documents our own custom kind.
```bash
kubectl explain backuppolicy.spec
```

**[4.5]** This custom resource is a single instance of the BackupPolicy kind we just defined.
```bash
cat m03-crds-demo/globomantics-backuppolicy.yaml
```

**[4.6]** Creating the instance makes the API server validate it against the CRD schema on admission.
```bash
kubectl apply -f m03-crds-demo/globomantics-backuppolicy.yaml
```

**[4.7]** Listing the resource shows the custom printer columns the CRD defined (its short name is bp).
```bash
kubectl get backuppolicies
```

> **CKA TIP (say this):** "A CRD is typed storage; an OPERATOR is a CRD plus a
> controller that reconciles those objects. The CRD is the data model - the operator
> is what makes it act."

---

## Phase 5 - Reset

> "Recap: Helm PACKAGES an app and gives its lifecycle an undo; Kustomize CUSTOMIZES
> one base into many environments with no templating; CRDs EXTEND the API with your
> own kinds. And through all three, the same doc reflex: explain and --help first,
> the one kubernetes.io tab second."

**[5.1]** We uninstall the Helm release to remove it from the cluster.
```bash
helm uninstall globo-podinfo
```

**[5.2]** We delete the Kustomize overlay we applied earlier.
```bash
kubectl delete -k m03-kustomize-demo/overlays/production
```

**[5.3]** We delete the CRD, which also removes any custom resources of that kind.
```bash
kubectl delete -f m03-crds-demo/backuppolicy-crd.yaml
```

---

## Reset between takes

```powershell
# Full rewind to the clean v1.35 cluster (the app does this automatically on launch):
.\Restore-CkaSnapshot.ps1 m03-pre-helm
```

---

Source of truth: [`Invoke-M03Lab.ps1`](../../../src/cka-lab/course-03-lifecycle-upgrades/Invoke-M03Lab.ps1).
Manifests: [`m03-kustomize-demo/`](m03-kustomize-demo/) + [`m03-crds-demo/`](m03-crds-demo/) (this folder).
Lab controls + snapshots: [`course-03-lifecycle-upgrades/README.md`](../../../src/cka-lab/course-03-lifecycle-upgrades/README.md).
