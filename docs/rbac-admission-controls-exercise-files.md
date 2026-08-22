# Securing Access with RBAC and Admission Controls - Exercise Files

**Course 4 of 11** in Tim Warner's **Certified Kubernetes Administrator (CKA) v1.35 Skill Path** on Pluralsight.
Aligned to the **CKA v1.35 (February 2025) curriculum** revision.

[![Author](https://img.shields.io/badge/Author-Tim%20Warner-0078D4?style=for-the-badge&logo=pluralsight&logoColor=white)](https://TechTrainerTim.com)
[![Website](https://img.shields.io/badge/Website-TechTrainerTim.com-1F6FEB?style=for-the-badge&logo=googlechrome&logoColor=white)](https://TechTrainerTim.com)
[![Email](https://img.shields.io/badge/Email-tim%40techtrainertim.com-EA4335?style=for-the-badge&logo=gmail&logoColor=white)](mailto:tim@techtrainertim.com)

> Pluralsight author, Microsoft MVP, 200+ courses published.

---

## The exercise files live on GitHub - not in this download

> **Heads up:** This file is a **pointer**. Every manifest, lab script, kubeconfig bootstrapper, and demo runbook for this course lives in the public GitHub repo below. Bookmark it, clone it, and keep it open while you watch the videos.

<p align="center">
  <a href="https://github.com/timothywarner-org/ps-cka">
    <img src="https://img.shields.io/badge/GO%20TO%20THE%20REPO-timothywarner--org%2Fps--cka-2EA043?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117" alt="Go to the course repository on GitHub" height="60">
  </a>
</p>

**Direct link:** [https://github.com/timothywarner-org/ps-cka](https://github.com/timothywarner-org/ps-cka)

**This course's folder:** [`exercise-files/course-04-rbac-admission/`](https://github.com/timothywarner-org/ps-cka/tree/main/exercise-files/course-04-rbac-admission)

<p align="center">
  <a href="https://github.com/timothywarner-org/ps-cka/stargazers"><img src="https://img.shields.io/github/stars/timothywarner-org/ps-cka?style=flat-square&logo=github&color=FFD33D" alt="GitHub stars"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/Kubernetes-v1.35-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="Kubernetes v1.35"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/CKA-Feb%202025%20Curriculum-1F6FEB?style=flat-square" alt="CKA Feb 2025 curriculum"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/Domain-Cluster%20Architecture%2025%25-326CE5?style=flat-square" alt="CKA domain: Cluster Architecture 25 percent"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/RBAC-rbac.authorization.k8s.io%2Fv1-575757?style=flat-square" alt="RBAC API group"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/Pod%20Security%20Admission-stable-2EA043?style=flat-square" alt="Pod Security Admission is stable"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/License-See%20Repo-lightgrey?style=flat-square" alt="License: see repo"></a>
  <a href="https://TechTrainerTim.com"><img src="https://img.shields.io/badge/Maintained%20by-Tim%20Warner-0078D4?style=flat-square&logo=microsoft&logoColor=white" alt="Maintained by Tim Warner"></a>
</p>

---

## What this course covers

Courses 1 through 3 built a cluster and kept it alive. Course 4 answers a different question: **who is allowed to do what inside it, and what does the API server refuse before an object ever reaches etcd?**

That's two separate gates, and conflating them is the single most common RBAC misconception I see:

1. **Authentication and authorization** decide whether *you* may make the request. RBAC lives here.
2. **Admission control** decides whether the *object* is acceptable, and it runs after authorization succeeds. LimitRanger, ResourceQuota, and Pod Security Admission live here.

A request has to clear both. Passing RBAC and then getting a `Forbidden` from a ResourceQuota isn't a contradiction, and by the end of Module 3 you'll be able to read either error at a glance and know which gate spoke.

Three modules, ~75 minutes total:

| # | Module | What you walk out able to do |
|---|---|---|
| **M1** | **Authentication, Authorization, and RBAC Fundamentals** | Mint a real human identity from an X.509 certificate through the CSR API, build Roles and ClusterRoles with the matching two binding kinds, and prove any permission with `kubectl auth can-i --as` before a user ever hits a 403. |
| **M2** | **Service Accounts and Least-Privilege Access** | Give a *workload* an identity, bind it to a Role, decode the projected token it actually carries, and switch the automount off for Pods that have no business holding a credential. |
| **M3** | **Admission Controls, Resource Limits, and Governance** | Watch LimitRanger mutate a Pod on the way in, watch ResourceQuota and Pod Security Admission reject one outright, and diagnose the rejection from the error message alone. |

**Primary exam domain:** Cluster Architecture, Installation and Configuration (25%). This course also feeds Troubleshooting (30%), because most of what you do here is reading a refusal and naming the component that issued it.

---

## What's in the repo

Welcome - I'm Tim, and here's the lay of the land when you arrive at [github.com/timothywarner-org/ps-cka](https://github.com/timothywarner-org/ps-cka). Everything for this course sits under [`exercise-files/course-04-rbac-admission/`](https://github.com/timothywarner-org/ps-cka/tree/main/exercise-files/course-04-rbac-admission):

### Course-level assets

- **[`setup-contexts.sh`](https://github.com/timothywarner-org/ps-cka/blob/main/exercise-files/course-04-rbac-admission/setup-contexts.sh)** - Run this once before anything else. It builds the two kubectl contexts the whole course leans on: `cka-vagrant` (the cluster-admin context every demo pins to) and `frontend-dev` (a **genuine X.509 client certificate**, signed by the cluster CA through the CertificateSigningRequest API). It's idempotent, so re-run it freely.
- **[`COURSE_RESOURCES.md`](https://github.com/timothywarner-org/ps-cka/blob/main/exercise-files/course-04-rbac-admission/COURSE_RESOURCES.md)** - The curated first-party reading list, module by module, with the pages worth bookmarking in your exam browser called out.

> **Why real credentials instead of `--as` impersonation?** Because this course *is* the credentials. Impersonation is a fantastic verification tool and you will use it constantly in Module 1, but a course about identity that never issues an identity teaches you the syntax and hides the mechanism. So we sign a certificate, and in Module 2 we mint a token, and you get to see that the same API server authenticates a human and a workload through two completely different credential types.

### Module 1 - RBAC fundamentals

Folder: [`m01-rbac-fundamentals/`](https://github.com/timothywarner-org/ps-cka/tree/main/exercise-files/course-04-rbac-admission/m01-rbac-fundamentals)

- **`c04-m01-demo-runbook.md`** - My actual recording script: talk track, click paths, timing, and a verification ledger at the bottom that states plainly which claims are source-verified and which need a live cluster. Read it on a second monitor and you can replay every demo at your own pace.
- **`lab.sh`** - The one script that matters on the node. Three verbs: `reset` (back to frame zero in about 8 seconds), `mint` (re-issue the frontend-dev certificate, idempotent), `verify` (assert that every expected allow is allowed **and** every expected 403 is denied). Exit 0 means the cluster agrees with the deck.
- **`frontend-dev-csr.yaml`** - The CertificateSigningRequest. Read the comment header before you run it: **CN becomes the RBAC username, O becomes an RBAC group.** There's no User object in Kubernetes, and that one line explains why.
- **`pod-reader.yaml`** - The namespace-scoped Role the imperative demo generates with `--dry-run=client -o yaml`. Imperative first for exam speed, declarative second for understanding.
- **`START-HERE.md`** - The two-command path from cold VMs to recording-ready.

### Module 2 - ServiceAccounts

Folder: [`m02-serviceaccounts/`](https://github.com/timothywarner-org/ps-cka/tree/main/exercise-files/course-04-rbac-admission/m02-serviceaccounts)

- **`c04-m02-demo-runbook.md`** - Recording script for the module.
- **`commands.sh`** - Every command in demo order, byte-identical to the deck code slides. Creates `deploy-bot` in `staging`, binds it to a `deployer` Role, and builds a **third kubectl context on camera** from a bearer token.
- **`deploy-runner.yaml`** - A Pod that names `serviceAccountName: deploy-bot`. This is the one you `exec` into to read the projected token off the filesystem.
- **`ghost-sa.yaml`** - A Pod naming a ServiceAccount that doesn't exist. **This is the trap slide made real.** The ServiceAccount admission plugin rejects it at the API server, so no Pod object is persisted, nothing is scheduled, and no container is created. So there's no `CreateContainerConfigError` to go find - that error belongs to a missing ConfigMap or Secret, not a missing ServiceAccount. If a study guide told you otherwise, this manifest is your proof.
- **`no-automount.yaml`** - `automountServiceAccountToken: false`. The projected volume disappears entirely, and `/var/run/secrets/kubernetes.io/` won't exist inside the container. Least privilege for workloads that never call the API server.
- **`lab.sh`** - Reset and verification for the module.

### Module 3 - Admission controls

Folder: [`m03-admission-controls/`](https://github.com/timothywarner-org/ps-cka/tree/main/exercise-files/course-04-rbac-admission/m03-admission-controls)

- **`commands.sh`** - Every command in demo order, byte-identical to the deck.
- **`limitrange.yaml`** - The **mutating** half. `defaultRequest` and `default` for CPU and memory. Apply it, then run a Pod that names no resources at all, and read back an object that isn't the object you sent. That's a mutating admission plugin writing on your behalf.
- **`limitrange-ceiling.yaml`** - The same LimitRange plus `min` and `max`, so the next manifest has something to be rejected against.
- **`oversized-pod.yaml`** - `limits.cpu: 1500m` against a `max` of `800m`. The **validating** pass refuses it, and the message names both the constraint and your value. Learn to read that shape.
- **`resourcequota.yaml`** - A namespace cap on `requests.cpu`, `requests.memory`, `limits.cpu`, `limits.memory`. **Exam trap baked into the comments:** bare `cpu` and `memory` in a quota mean **requests**, never limits.
- **`privileged-deployment.yaml`** - `privileged: true` against the **Baseline** Pod Security Standard. Here's the good part: the Deployment is created, the ReplicaSet is created, and **zero Pods appear.** The refusal is waiting one level down, on the ReplicaSet's events. That controller-versus-Pod indirection is worth real points on the exam.
- **`hardened-pod.yaml`** - The Pod that passes **Restricted**: `runAsNonRoot` paired with an actual non-root `runAsUser`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, and an unprivileged image that listens on 8080. Note the pairing - `runAsNonRoot: true` on an image that only knows how to be root fails at the kubelet, not at admission, and that's a different error in a different place.

### The lab environment

Folder: [`src/cka-lab/`](https://github.com/timothywarner-org/ps-cka/tree/main/src/cka-lab)

Course 4 records against the **Hyper-V Vagrant path**, because signing certificates and reading kubelet-side failures wants a real machine:

- `control1` / `worker1` / `worker2` at **192.168.50.10 / .11 / .12**, Ubuntu 22.04, Kubernetes **v1.35**, containerd
- CNI: **Calico** via the Tigera operator (pinned v3.29.1), the course standard set back in Course 2 Module 3
- Pod CIDR `192.168.0.0/16`, Service CIDR `10.96.0.0/12`
- Admin context: **`cka-vagrant`**
- `Initialize-C04M01Lab.ps1` boots, health-checks, stages the module folder onto the node, snapshots, and **fact-gates the deck against the live cluster** - it asks the cluster whether five sentences I say on camera are still true

> **Not on Windows?** The Vagrantfile pattern is identical on **VirtualBox 7.x** for macOS and Linux. Same three VMs, same provisioning, same commands. I record on Hyper-V because that's my rig, not because the lab requires it.

---

## Quick start

```powershell
# 1. Clone
git clone https://github.com/timothywarner-org/ps-cka.git
cd ps-cka/src/cka-lab

# 2. Bring up the three-VM cluster (add -Bootstrap the first time on fresh VMs)
./Initialize-C04M01Lab.ps1
```

```bash
# 3. On the control plane node, build the course contexts once
ssh vagrant@192.168.50.10          # password: vagrant
cd ~/course-04 && ./setup-contexts.sh

# 4. Then walk a module
cd ~/m01 && ./lab.sh               # reset + verify all four M1 demos
```

Exit 0 from `lab.sh` means every expected allow was allowed and every expected 403 was denied. Exit 1 names the check that drifted. Between practice reps, `./lab.sh reset` puts you back at frame zero in about 8 seconds.

**On another cluster?** The manifests and `setup-contexts.sh` are portable to any conformant Kubernetes v1.35 cluster; only the node-level break/fix drills need the VMs.

---

## What makes this course different

- **Real credentials, not just impersonation.** You will sign an X.509 certificate through the CSR API and mint a ServiceAccount token, then watch the same API server treat them as two different kinds of identity. Most RBAC training never leaves `--as`.
- **401 versus 403 gets its own beat.** Authentication failure and authorization failure are different problems with different fixes, and the exam will hand you both. Module 1 Demo 1 produces a real 403 from a real authenticated user with zero permissions, on purpose.
- **The binding sets the scope, not the role.** The highest-yield concept in the module: one ClusterRole, bound two ways, produces two completely different blast radii. You see the same ClusterRole through a RoleBinding and a ClusterRoleBinding back to back.
- **Every failure mode is demonstrated, not described.** The missing ServiceAccount. The oversized Pod. The privileged Deployment that creates a ReplicaSet and no Pods. You watch each one fail and read the actual message.
- **The trap slides are backed by manifests.** Where the course outline and the cluster disagreed, the cluster won, and the manifest comments record why. Read the header comments - they are part of the curriculum.
- **Imperative first, declarative second.** `kubectl create role ... --dry-run=client -o yaml` is the exam-speed path. The YAML file is the understanding path. You get both, in that order, every time.

---

## Where this course sits in the skill path

The full **[Certified Kubernetes Administrator (CKA) path on Pluralsight](https://www.pluralsight.com/paths/certified-kubernetes-administrator)**. My 11-course v1.35 series is the spine; the path also carries excellent courses from other authors, listed further down.

### My CKA v1.35 series

| # | Course | Status |
|---|---|---|
| 1 | [Certified Kubernetes Administrator (CKA): Kubernetes Foundations](https://www.pluralsight.com/courses/cka-kubernetes-foundations) | **Live** |
| 2 | [Certified Kubernetes Administrator (CKA): Installing Clusters with kubeadm](https://www.pluralsight.com/courses/cka-kubeadm-installing-clusters) | **Live** |
| 3 | [Certified Kubernetes Administrator (CKA): Managing Cluster Lifecycle and Upgrades](https://www.pluralsight.com/courses/cka-kubernetes-managing-cluster-lifecycle-upgrades) | **Live** |
| **4** | **Securing Access with RBAC and Admission Controls** | **You are here** |
| 5 | Managing Workloads and Scheduling | In production |
| 6 | Managing Storage | In production |
| 7 | Services, Ingress, and Gateway API | In production |
| 8 | Network Policies and Traffic Management | In production |
| 9 | Troubleshooting Clusters and Nodes | In production |
| 10 | Troubleshooting Workloads and Services | In production |
| 11 | Exam Prep, Practice Labs, and Strategy | In production |

New courses land on my author page as they publish: **[pluralsight.com/authors/tim-warner](https://www.pluralsight.com/authors/tim-warner)**. Exercise files for all eleven live in the [same repo](https://github.com/timothywarner-org/ps-cka), organized as `exercise-files/course-NN-topic/mNN-module-name/`.

### Other CKA courses in the Pluralsight path

Worth your time, especially for a second pass on a weak domain. Different author, different angle, same objectives:

**Cluster architecture, installation, and configuration**

- [Certified Kubernetes Administrator: Using kubeadm to Install a Basic Cluster](https://www.pluralsight.com/courses/cka-kubeadm-install-basic-cluster-using-cert) - Anthony Nocentino
- [Certified Kubernetes Administrator: Working with Your Cluster](https://www.pluralsight.com/courses/cka-cluster-working-cert) - Anthony Nocentino
- [Cluster Architecture, Installation, and Configuration for CKA: Cluster Management and Lifecycle](https://www.pluralsight.com/courses/cluster-architecture-installation-configuration-for-cka-cluster-management-lifecycle) - Anthony Nocentino
- [Certified Kubernetes Administrator: Performing Cluster Version Upgrades](https://www.pluralsight.com/courses/cka-cluster-version-upgrades-performing-cert) - Anthony Nocentino
- [CKA Advanced Cluster Configuration: Cluster Architecture, Installation, and Configuration](https://www.pluralsight.com/courses/cka-advanced-cluster-configuration-cluster-architecture-installation-configuration) - Patrick Rusch
- **[Configuring and Managing Kubernetes Security](https://www.pluralsight.com/courses/configuring-managing-kubernetes-security-2) - Elton Stoneman.** The closest companion to *this* course in the path. If you want a second voice on RBAC and cluster security, start here.

**Services and networking**

- [Configuring and Managing Kubernetes Networking, Services, and Ingress](https://www.pluralsight.com/courses/configuring-managing-kubernetes-networking-services-ingress) - Anthony Nocentino

**Storage**

- [Storage for CKA](https://www.pluralsight.com/courses/storage-for-cka-cert) - Antonio Jesús Piedra
- [Configuring and Managing Kubernetes Storage and Scheduling](https://www.pluralsight.com/courses/config-managing-kubernetes-storage-scheduling) - Patrick Rusch

**Workloads and scheduling**

- [Workloads and Scheduling for CKA](https://www.pluralsight.com/courses/workloads-scheduling-cka-cert) - Antonio Jesús Piedra
- [Managing Kubernetes Controllers and Deployments](https://www.pluralsight.com/courses/managing-kubernetes-controllers-deployments) - Anthony Nocentino
- [Managing the Kubernetes API Server and Pods](https://www.pluralsight.com/courses/managing-kubernetes-api-server-pods) - Anthony Nocentino

**Troubleshooting**

- [Maintaining, Monitoring, and Troubleshooting Kubernetes](https://www.pluralsight.com/courses/maintaining-monitoring-troubleshoot-kubernetes) - James Willett

**Hands-on practice**

- [Certified Kubernetes Administrator (CKA) practice exams and labs](https://www.pluralsight.com/labs) - Pluralsight's browser-based lab library includes a multi-part CKA practice exam series. Use it after Course 11, under a timer.

---

## Read this before you click a single docs link

**The exam and the docs are one version apart right now, and that matters.**

- The **CKA exam covers Kubernetes v1.35**, per the [Linux Foundation exam page](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/).
- **kubernetes.io/docs renders v1.36** as of August 2026. Every link below shows you v1.36 content.

For 95% of RBAC and admission material that difference doesn't matter. Where it does, I flag it inline. If you want the exam-pinned copy of any page, swap the host: **`https://v1-35.docs.kubernetes.io/docs/...`**. The version selector at the top of every docs page does the same thing.

**Exam-day reality check:** the CKA is open-book against `kubernetes.io/docs` and a short list of official subdomains. You can't open Google, a blog, your own notes, or this file. Fast doc-navigation is itself a scored skill, so the pages marked **[bookmark]** below are the ones worth pinning in your exam browser *before* test day.

---

## Resource library - verified August 2026

Every link below was fetched and verified live in August 2026, grouped by module so you can read alongside each video.

### Module 1 - Authentication, authorization, and RBAC

**The spine**

- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) **[bookmark]** - Roles, ClusterRoles, RoleBindings, ClusterRoleBindings, aggregation, and the default built-in roles. If you bookmark one page for this course, it's this one.
- [Authorization Overview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/) - The request attributes Kubernetes actually authorizes against (the verb-resource-namespace tuple) and where RBAC sits among Node, Webhook, and ABAC.
- [Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/) - Why there is no User object, how an X.509 CN maps to a username and O maps to a group, and the impersonation headers behind `--as`.
- [RBAC Good Practices](https://kubernetes.io/docs/concepts/security/rbac-good-practices/) - The privilege-escalation paths RBAC doesn't close for you: Secret reading, `escalate`, `bind`, `impersonate`, and Pod creation as a lateral-movement primitive. Short, and it will change how you write a Role.

**Verification - your RBAC unit test**

- [kubectl auth (can-i, whoami, reconcile)](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/) **[bookmark]** - Prove a permission with `--as` before a user ever hits a 403. `kubectl auth can-i --list --as=frontend-dev -n dev-team` is the single most useful RBAC command there is.
- [kubectl create (role, rolebinding, clusterrole, clusterrolebinding, serviceaccount)](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/) **[bookmark]** - The imperative generators, flag by flag. Pair every one with `--dry-run=client -o yaml`.
- [kubectl Quick Reference (cheat sheet)](https://kubernetes.io/docs/reference/kubectl/quick-reference/) **[bookmark]** - The highest-value page in the exam browser, full stop.

**Certificates and identity**

- [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/) - The `certificates.k8s.io` API, the signer names, and the approve/deny flow. This is the API `setup-contexts.sh` drives.
- [Manage TLS Certificates in a Cluster](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/) - The task-flavored walkthrough: create a CSR, approve it, retrieve the signed certificate, build a kubeconfig from it.
- [Access Clusters Using the Kubernetes API](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/) - kubeconfig structure and direct API access with `curl`, useful when you want to see the bare HTTP under `kubectl`.
- [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) - Clusters, users, contexts, and why `use-context` is the first keystroke of every exam task.

**Authorization modes beyond RBAC (know they exist)**

- [Using Node Authorization](https://kubernetes.io/docs/reference/access-authn-authz/node/) - The `Node` authorizer plus `NodeRestriction`. This is why a kubelet can read only the Secrets its own Pods use.
- [Webhook Mode](https://kubernetes.io/docs/reference/access-authn-authz/webhook/) - External authorization, for when you are asked "what else could be in `--authorization-mode`?"
- [Kubelet Authentication and Authorization](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-authn-authz/) - The kubelet's own API and the `system:anonymous` question that shows up in hardening reviews.

**Auditing - who actually did what**

- [Auditing](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/) - Audit policy, the four levels, and log versus webhook backends. It isn't a named CKA objective, but it's how you answer "which identity deleted that Deployment?" in real life.

**Third-party tooling worth knowing (not on the exam - use it at work)**

- [alcideio/rbac-tool](https://github.com/alcideio/rbac-tool) - The most actively maintained of the bunch (v1.20.0, Rapid7). Visualizes RBAC as a graph, audits for over-permission, and generates least-privilege policies from audit logs. Start here.
- [aquasecurity/kubectl-who-can](https://github.com/aquasecurity/kubectl-who-can) - Reverse lookup: "who can delete Pods in production?" Answers the question `auth can-i` can't. *Maintenance note: last release v0.4.0, February 2022. Still works, still useful, no longer actively developed.*
- [corneliusweig/rakkess](https://github.com/corneliusweig/rakkess) - An access matrix for every resource at once, per user. Excellent for eyeballing what a ServiceAccount really has. *Last release v0.5.1, November 2022.*
- [liggitt/audit2rbac](https://github.com/liggitt/audit2rbac) - Point it at an audit log and it writes the minimal Role that would have permitted exactly those requests. The right way to build least privilege for an existing workload. *Last release v0.10.0, February 2023.*
- [Kubernetes SIG Auth](https://github.com/kubernetes/community/tree/master/sig-auth) - The upstream group that owns RBAC, admission, and authentication. Meeting notes and KEPs land here first, which means you can see the next release's changes before they ship.

**Deep read**

- [Effective RBAC - Jordan Liggitt (KubeCon NA 2017)](https://www.youtube.com/watch?v=Nw1ymxcLIDI) - Dated in its examples and it predates Pod Security Admission entirely, but this is still the clearest explanation of the RBAC *model* on the internet, from the person who built much of it. Watch it for the mental model, not the syntax.

---

### Module 2 - ServiceAccounts and least privilege

**Concept and configuration**

- [Service Accounts](https://kubernetes.io/docs/concepts/security/service-accounts/) - What identity a Pod gets by default, what the `default` ServiceAccount can and can't do, and the three ways to obtain a token.
- [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) **[bookmark]** - `serviceAccountName`, projected token volumes, `automountServiceAccountToken`, and `imagePullSecrets`. The task page behind every demo in this module.
- [Managing Service Accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/) - The TokenRequest API, time-bound projected tokens, the token controller, and the cleanup controller that purges unused legacy tokens.
- [Authenticating - Service Account Tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#service-account-tokens) - The JWT claims (`iss`, `sub`, `aud`, `exp`) you will decode on camera, and the `system:serviceaccount:<namespace>:<name>` username format RBAC binds against. Memorize that format.

**Minting tokens**

- [kubectl create token](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_token/) - Short-lived tokens on demand, with `--duration` and `--bound-object-kind`. This replaced "go read the Secret," and the exam expects the new answer.

**Related**

- [Admission Control - ServiceAccount plugin](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#serviceaccount) - The plugin that rejects `ghost-sa.yaml`. Worth reading in Module 2 even though it belongs to Module 3's topic, because it's the bridge between the two.
- [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) - `imagePullSecrets` on a ServiceAccount, the most common real-world reason to touch one.
- [cert-manager](https://cert-manager.io/docs/) - Not a CKA objective, but the moment you leave the lab, this is how certificates get issued and rotated in a real cluster. Source: [cert-manager/cert-manager](https://github.com/cert-manager/cert-manager).

---

### Module 3 - Admission control, limits, and governance

**Admission control itself**

- [Admission Control in Kubernetes](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/) **[bookmark]** - How plugins intercept a request after authorization and before persistence, the mutating-then-validating order, and the full plugin list with the default-enabled set called out. *Caution: this page's ValidatingAdmissionPolicy section still carries stale alpha-era wording about feature gates. Trust the dedicated reference page below over that paragraph.*
- [Dynamic Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/) - `MutatingWebhookConfiguration` and `ValidatingWebhookConfiguration`. Know the shape and the failure policy; you aren't expected to write a webhook on the exam.
- [Validating Admission Policy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/) - **GA (stable since v1.30)** on `admissionregistration.k8s.io/v1`, in-tree, CEL-based, default-enabled. Recognize it, and know it replaces most simple webhooks, though it isn't a named CKA objective.
- [Explore Validating and Mutating Admission Policies](https://kubernetes.io/docs/tutorials/cluster-management/admission-policies/) - Newer hands-on tutorial covering both policy types side by side. The fastest way to get CEL policy under your fingers.
- [Kubernetes 1.30: Validating Admission Policy Is Generally Available](https://kubernetes.io/blog/2024/04/24/validating-admission-policy-ga/) - The GA announcement, with the "why not a webhook" reasoning laid out.

**Limits, quotas, and requests**

- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/) **[bookmark]** - Per-namespace defaults plus min and max for CPU and memory. Note that a LimitRange both **mutates** (fills in defaults) and **validates** (enforces min/max), which is why it's the perfect teaching example.
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/) **[bookmark]** - Aggregate namespace caps, the object-count quotas, and the exact `Forbidden: exceeded quota` message. **Trap:** bare `cpu` and `memory` keys mean requests. Use `limits.cpu` and `limits.memory` when you mean limits.
- [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) - What requests and limits actually do at schedule time and at runtime, plus the QoS classes that fall out of them. Read this before you decide a LimitRange default is "just a number."
- [Configure Default CPU Requests and Limits for a Namespace](https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/cpu-default-namespace/) - The single-purpose task page. Fastest thing to find under exam pressure.
- [Configure Memory and CPU Quotas for a Namespace](https://kubernetes.io/docs/tasks/administer-cluster/manage-resources/quota-memory-cpu-namespace/) - Same, for quotas.

**Pod security**

- [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) - Privileged, Baseline, Restricted. Know which field violates which profile; that's the actual exam question.
- [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/) **[bookmark]** - **Stable since v1.25.** The built-in enforcer, driven entirely by namespace labels for `enforce`, `audit`, and `warn`, each with an optional version pin.
- [Enforce Pod Security Standards with the Built-In Admission Controller](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-admission-controller/) - Cluster-wide defaults and exemptions via `AdmissionConfiguration`. The task page behind the root-Pod rejection demo.
- [Enforce Pod Security Standards with Namespace Labels](https://kubernetes.io/docs/tasks/configure-pod-container/enforce-standards-namespace-labels/) - The one-liner version: `kubectl label ns production pod-security.kubernetes.io/enforce=baseline`. That's the exam answer.
- [Configure a Security Context for a Pod or Container](https://kubernetes.io/docs/tasks/configure-pod-container/security-context/) **[bookmark]** - `runAsNonRoot`, `runAsUser`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation`, capabilities, `seccompProfile`. Every field in `hardened-pod.yaml`.
- [Kubernetes v1.25: Pod Security Admission Controller in Stable](https://kubernetes.io/blog/2022/08/25/pod-security-admission-stable/) - The announcement that also documents PodSecurityPolicy's removal. Read alongside [PodSecurityPolicy: The Historical Context](https://kubernetes.io/blog/2022/08/23/podsecuritypolicy-the-historical-context/) if you have ever seen PSP in a study guide and wondered what happened.
- [Security Checklist](https://kubernetes.io/docs/concepts/security/security-checklist/) - A single page that ties authentication, authorization, admission, and network policy into one hardening pass. Excellent review sheet.

**Policy engines - where real clusters go next (not on the exam)**

The CKA tests the built-ins. Production almost always adds one of these two, and knowing the landscape is the difference between passing an exam and doing the job:

- [Kyverno](https://kyverno.io/) - **CNCF graduated project** (graduated March 2026). Policies are Kubernetes resources written in YAML, no new language to learn. The lowest-friction on-ramp if you already think in manifests. Source: [kyverno/kyverno](https://github.com/kyverno/kyverno).
- [OPA Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/) - The Open Policy Agent admission controller, policies written in **Rego**. Steeper learning curve, more expressive, and the incumbent in a lot of enterprises. Source: [open-policy-agent/gatekeeper](https://github.com/open-policy-agent/gatekeeper), language docs at [openpolicyagent.org/docs](https://www.openpolicyagent.org/docs/).
- **My recommendation:** learn `ValidatingAdmissionPolicy` first, because it is in-tree, needs no operator, and covers a surprising amount of ground. Reach for Kyverno when you outgrow it. Reach for Gatekeeper when the organization already runs it.

**Cluster hardening and benchmarks**

- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes) - The industry baseline (**v2.0.1**). Free PDF, no registration required for non-commercial use. Managed-service variants exist for EKS, AKS, GKE, and OpenShift.
- [aquasecurity/kube-bench](https://github.com/aquasecurity/kube-bench) - Runs the CIS Benchmark against a live cluster and auto-detects which benchmark version applies. Point it at your Vagrant lab and read the failures - it's a superb study aid, and about half its findings are things this course just taught you.
- [FairwindsOps/polaris](https://github.com/FairwindsOps/polaris) - 30+ built-in checks for workload configuration, runnable as a dashboard, a CI gate, or an admission controller. The gentlest introduction to policy-as-a-gate.
- [Kubescape](https://kubescape.io/) - CNCF incubating scanner that maps findings to NSA/CISA hardening guidance and MITRE ATT&CK. Broader than kube-bench. Source: [kubescape/kubescape](https://github.com/kubescape/kubescape).

**Deep read**

- [Unlocking Kyverno: Mastering Policy Management in Large-Scale Kubernetes Clusters (KubeCon 2025)](https://www.youtube.com/watch?v=_KQijmHBk6E) - What admission policy looks like when you run it across hundreds of namespaces. Good perspective on why the built-ins stop being enough.

---

## Version currency notes for v1.35

Kubernetes moves fast, and stale study guides get these exact points wrong. Verified August 2026:

| Claim | Status |
|---|---|
| **PodSecurityPolicy** | **Removed** in v1.25 (deprecated v1.21), so it is four releases gone before the exam version. If any source tells you to write a PSP, that source is at least four years stale. The current answer is **always** Pod Security Admission plus the Pod Security Standards. |
| **Pod Security Admission** | **Stable since v1.25**, built in, enabled by default. Driven by namespace labels. |
| **ValidatingAdmissionPolicy** | **GA / stable since v1.30** on `admissionregistration.k8s.io/v1`, default-enabled. Recognize it; it isn't a named CKA objective. |
| **MutatingAdmissionPolicy** | **Beta and off by default in v1.35** - the exam version. Heads up: it went **stable in v1.36**, so the live docs page now reads "stable, enabled by default." Both statements are true, one version apart. Treat it as mention-only either way. |
| **Legacy Secret-based ServiceAccount tokens** | Auto-generation stopped in **v1.24**. Since **v1.29** legacy tokens unused for a year are marked invalid and then purged by a cleanup controller. Prefer `kubectl create token` and projected volume tokens - they are time-bound and are invalidated when the Pod goes away. |
| **`kubectl auth whoami`** | Stable and available. Fastest way to confirm which identity a kubeconfig context is actually presenting. |
| **The docs version** | kubernetes.io renders **v1.36**; the exam covers **v1.35**. Pin a page with the version selector or the `v1-35.docs.kubernetes.io` host when the difference matters. |

---

## CKA exam and curriculum references

- [Certified Kubernetes Administrator (CKA) - Linux Foundation](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) - The official exam page. Format, pricing, the five domains, validity period, and the number of attempts included. Read the current page rather than trusting any figure quoted secondhand, including mine.
- [Certified Kubernetes Administrator (CKA) - CNCF](https://www.cncf.io/training/certification/cka/) - CNCF's mirror of the exam page.
- [cncf/curriculum](https://github.com/cncf/curriculum) - The authoritative, versioned domain-and-competency list. Grab `CKA_Curriculum_v1.35.pdf` and keep it in your study folder. CC-BY licensed.
- [CKA program changes (February 2025 revision)](https://training.linuxfoundation.org/certified-kubernetes-administrator-cka-program-changes/) - What changed in the largest CKA revision to date, including the domain weights this course maps to.
- [Linux Foundation Certification Candidate Handbook](https://docs.linuxfoundation.org/tc-docs/certification/lf-handbook2) - Proctoring rules, ID requirements, what you may have on your desk, and the exact list of documentation domains allowed during the exam. Read it once, a week before you sit.
- [Kubernetes Documentation home](https://kubernetes.io/docs/home/) - The only reference open during the exam.
- [killer.sh CKA simulator](https://killer.sh/) - Two free sessions ship with your exam registration. It's harder than the real thing and the closest available match to the exam environment. Don't burn a session until you have finished Course 11.

**CKA domain weights (v1.35):** Troubleshooting 30% · Cluster Architecture, Installation and Configuration 25% · Services and Networking 20% · Workloads and Scheduling 15% · Storage 10%. This course lives in that 25% block.

---

## Your five-minute RBAC pocket card

Print this. It's the whole course compressed to what you need under a timer.

```bash
# WHO AM I, AND WHAT CLUSTER AM I ON -- first two keystrokes of every task
kubectl config get-contexts
kubectl config use-context <name>
kubectl auth whoami

# CAN X DO Y? -- your unit test
kubectl auth can-i get pods -n dev-team --as=frontend-dev
kubectl auth can-i --list -n dev-team --as=frontend-dev
kubectl auth can-i create deployments -n staging \
  --as=system:serviceaccount:staging:deploy-bot

# BUILD IT FAST (imperative), THEN READ IT (declarative)
kubectl create role pod-reader --verb=get,list,watch \
  --resource=pods -n dev-team --dry-run=client -o yaml
kubectl create rolebinding read-pods --role=pod-reader \
  --user=frontend-dev -n dev-team
kubectl create clusterrolebinding cluster-viewer \
  --clusterrole=view --user=frontend-dev

# WORKLOAD IDENTITY
kubectl create sa deploy-bot -n staging
kubectl create rolebinding deploy-bot-deployer --role=deployer \
  --serviceaccount=staging:deploy-bot -n staging
kubectl create token deploy-bot -n staging --duration=1h

# ADMISSION: GATE THE NAMESPACE
kubectl label ns production \
  pod-security.kubernetes.io/enforce=baseline
kubectl describe limitrange -n production
kubectl describe quota -n production
```

**Four things to keep straight:**

1. **401 is authentication. 403 is authorization.** Different problem, different fix.
2. **The binding sets the scope.** A ClusterRole bound with a RoleBinding is namespace-scoped. Same role, different blast radius.
3. **A ServiceAccount's username is `system:serviceaccount:<namespace>:<name>`.** RBAC binds to that string.
4. **RBAC and admission are two separate gates.** `Forbidden` from a quota isn't an RBAC problem, and no amount of Role editing will fix it.

---

## One more time - go to the repo

<p align="center">
  <a href="https://github.com/timothywarner-org/ps-cka">
    <img src="https://img.shields.io/badge/CLONE%20THE%20REPO-github.com%2Ftimothywarner--org%2Fps--cka-2EA043?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117" alt="Clone the course repository" height="60">
  </a>
</p>

---

## Stay in touch

Thanks for taking this course - it genuinely means a lot. If you hit a snag, spot a bug, or just want to say hello, reach out:

- **Website:** [TechTrainerTim.com](https://TechTrainerTim.com)
- **Email:** [tim@techtrainertim.com](mailto:tim@techtrainertim.com)
- **YouTube:** [youtube.com/@TechTrainerTim](https://www.youtube.com/@TechTrainerTim)
- **LinkedIn:** [linkedin.com/in/timothywarner](https://www.linkedin.com/in/timothywarner)
- **Pluralsight author page:** [pluralsight.com/authors/tim-warner](https://www.pluralsight.com/authors/tim-warner)
- **Microsoft MVP profile:** [mvp.microsoft.com/timothywarner](https://mvp.microsoft.com/en-US/mvp/profile/e9a13bca-2798-4247-be56-f116f780869d)
- **Repo issues:** [github.com/timothywarner-org/ps-cka/issues](https://github.com/timothywarner-org/ps-cka/issues)

Now go pass that exam.

- **Tim Warner**

---

*Links verified August 2026 against kubernetes.io (rendering v1.36) with exam alignment to Kubernetes v1.35. Spot a dead link or a stale fact? Open an issue on the repo and I'll fix it.*
