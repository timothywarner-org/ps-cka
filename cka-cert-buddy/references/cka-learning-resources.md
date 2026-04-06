# CKA Learning Resources

Curated, verified resources for the Certified Kubernetes Administrator (CKA) exam -- organized by learning phase for maximum efficiency. Every link has been verified against official sources.

Last updated: 2026-04-06

---

## Table of contents

1. [Learning path overview](#learning-path-overview)
2. [Phase 1: Foundations (weeks 1-2)](#phase-1-foundations-weeks-1-2)
3. [Phase 2: Core skills (weeks 3-6)](#phase-2-core-skills-weeks-3-6)
4. [Phase 3: Exam-specific topics (weeks 7-9)](#phase-3-exam-specific-topics-weeks-7-9)
5. [Phase 4: Practice and simulation (weeks 10-12)](#phase-4-practice-and-simulation-weeks-10-12)
6. [Official Kubernetes documentation](#official-kubernetes-documentation)
7. [Official courses and training](#official-courses-and-training)
8. [Community courses and platforms](#community-courses-and-platforms)
9. [Books](#books)
10. [Free video resources](#free-video-resources)
11. [Hands-on lab environments](#hands-on-lab-environments)
12. [Practice exams and simulators](#practice-exams-and-simulators)
13. [GitHub study repositories](#github-study-repositories)
14. [Official references to bookmark](#official-references-to-bookmark)
15. [CKA domain-specific resources](#cka-domain-specific-resources)
16. [Community and support](#community-and-support)
17. [Study time estimates by experience level](#study-time-estimates-by-experience-level)

---

## Learning path overview

The CKA exam is 100% performance-based. Studying theory alone will not prepare you. Allocate at least **80% of your study time to hands-on practice** -- typing real kubectl commands against real clusters.

```
Phase 1: Foundations        [Weeks 1-2]    Theory + first cluster
Phase 2: Core skills        [Weeks 3-6]    Domain-by-domain hands-on
Phase 3: Exam-specific      [Weeks 7-9]    Feb 2025 new topics + speed
Phase 4: Practice + sim     [Weeks 10-12]  Mock exams + killer.sh
```

**Key principle:** Learn a concept, immediately practice it, then move on. Do not batch theory and practice into separate phases.

---

## Phase 1: Foundations (weeks 1-2)

**Goal:** Understand Kubernetes architecture, set up a local cluster, and get comfortable with kubectl.

### What to do

1. **Read:** [Kubernetes Concepts Overview](https://kubernetes.io/docs/concepts/overview/) -- understand Pods, nodes, control plane, etcd, API server.
2. **Watch:** One of the beginner courses listed in [Free video resources](#free-video-resources).
3. **Build:** Set up a local kind cluster (1 control plane + 2 workers). The CKA skill path repo includes the standard cluster config.
4. **Practice:** Work through the [Kubernetes Basics interactive tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/).
5. **Memorize:** kubectl imperative commands and the `--dry-run=client -o yaml` pipeline.

### Key resources for this phase

| Resource | Type | Cost |
| --- | --- | --- |
| [Kubernetes Concepts](https://kubernetes.io/docs/concepts/) | Official docs | Free |
| [Kubernetes Basics Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/) | Interactive tutorial | Free |
| [Hello Minikube](https://kubernetes.io/docs/tutorials/hello-minikube/) | Tutorial | Free |
| [kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/) | Cheat sheet | Free |
| [kind Quick Start](https://kind.sigs.k8s.io/docs/user/quick-start/) | Tool setup | Free |

---

## Phase 2: Core skills (weeks 3-6)

**Goal:** Build hands-on proficiency in each of the five CKA domains, weighted by exam importance.

### Study order (by exam weight)

1. **Troubleshooting (30%)** -- Start here. The diagnostic ladder (`get > describe > logs > events`) is used in every other domain.
2. **Cluster Architecture, Installation and Configuration (25%)** -- RBAC, kubeadm, etcd backup/restore.
3. **Services and Networking (20%)** -- Services, NetworkPolicies, Ingress, CoreDNS.
4. **Workloads and Scheduling (15%)** -- Deployments, rollouts, ConfigMaps, Secrets, scheduling.
5. **Storage (10%)** -- PV, PVC, StorageClasses.

### Key resources for this phase

| Resource | Type | Cost |
| --- | --- | --- |
| [Kubernetes Tasks Documentation](https://kubernetes.io/docs/tasks/) | Official how-to guides | Free |
| [Troubleshooting Applications](https://kubernetes.io/docs/tasks/debug/debug-application/) | Official guide | Free |
| [Troubleshooting Clusters](https://kubernetes.io/docs/tasks/debug/debug-cluster/) | Official guide | Free |
| [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) | Official reference | Free |
| [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) | Official concepts | Free |
| [Configure Persistent Volumes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/) | Official task | Free |
| [Administer a Cluster](https://kubernetes.io/docs/tasks/administer-cluster/) | Official task collection | Free |

---

## Phase 3: Exam-specific topics (weeks 7-9)

**Goal:** Master the February 2025 curriculum additions. These topics represent approximately 50% of exam questions per recent candidate reports.

### New topics to prioritize

| Topic | Domain | Resource |
| --- | --- | --- |
| Gateway API | Services & Networking | [Gateway API Concepts](https://kubernetes.io/docs/concepts/services-networking/gateway/) |
| Gateway API (detailed) | Services & Networking | [Gateway API Guides](https://gateway-api.sigs.k8s.io/guides/) |
| HTTPRoute | Services & Networking | [HTTP Routing Guide](https://gateway-api.sigs.k8s.io/guides/http-routing/) |
| Helm | Cluster Architecture | [Helm Documentation](https://helm.sh/docs/) |
| Helm quickstart | Cluster Architecture | [Helm Quickstart Guide](https://helm.sh/docs/intro/quickstart/) |
| Helm commands | Cluster Architecture | [Helm Commands Reference](https://helm.sh/docs/helm/) |
| Kustomize | Cluster Architecture | [Managing Objects with Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) |
| CRDs and operators | Cluster Architecture | [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) |
| CRD creation | Cluster Architecture | [Extend the Kubernetes API with CRDs](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) |
| HPA | Workloads & Scheduling | [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) |
| HPA walkthrough | Workloads & Scheduling | [HPA Walkthrough](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) |
| Ephemeral containers | Troubleshooting | [Ephemeral Containers](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/) |
| kubectl debug | Troubleshooting | [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) |
| Native sidecars | Workloads & Scheduling | [Sidecar Containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) |
| CNI, CSI, CRI | Cluster Architecture | [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) |

### Speed practice

During this phase, start timing yourself. You have approximately **7 minutes per task** on the real exam. Practice completing common tasks within that time budget.

---

## Phase 4: Practice and simulation (weeks 10-12)

**Goal:** Simulate exam conditions repeatedly until you can consistently score above 66%.

### What to do

1. **Activate killer.sh session 1.** Score does not matter -- identify weak areas.
2. **Study your weak areas** for 3-5 days using the domain-specific resources below.
3. **Activate killer.sh session 2.** Target 70%+ for confidence.
4. **Take mock exams** on KodeKloud or other platforms.
5. **Practice the three-pass strategy:**
   - Pass 1 (60-70 min): Easy tasks (2-4 min each) -- secure 60-70% of points.
   - Pass 2 (30-40 min): Medium tasks (4-7 min each).
   - Pass 3 (15-20 min): Return to flagged hard tasks.

### Key resources for this phase

| Resource | Type | Cost |
| --- | --- | --- |
| [killer.sh](https://killer.sh/) | Exam simulator (2 sessions included with purchase) | Included |
| [KodeKloud CKA Mock Exams](https://kodekloud.com/courses/ultimate-certified-kubernetes-administrator-cka-mock-exam) | Mock exam series | Paid |
| [Killercoda CKA Scenarios](https://killercoda.com/killer-shell-cka) | Browser-based practice | Free |

---

## Official Kubernetes documentation

These are the primary documentation pages you should know. They are also the only resources accessible during the exam.

### Concepts (understand how things work)

| Topic | URL |
| --- | --- |
| Overview and components | [kubernetes.io/docs/concepts/overview/](https://kubernetes.io/docs/concepts/overview/) |
| Pods | [kubernetes.io/docs/concepts/workloads/pods/](https://kubernetes.io/docs/concepts/workloads/pods/) |
| Deployments | [kubernetes.io/docs/concepts/workloads/controllers/deployment/](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) |
| Services | [kubernetes.io/docs/concepts/services-networking/service/](https://kubernetes.io/docs/concepts/services-networking/service/) |
| Volumes | [kubernetes.io/docs/concepts/storage/volumes/](https://kubernetes.io/docs/concepts/storage/volumes/) |
| Persistent Volumes | [kubernetes.io/docs/concepts/storage/persistent-volumes/](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) |
| ConfigMaps | [kubernetes.io/docs/concepts/configuration/configmap/](https://kubernetes.io/docs/concepts/configuration/configmap/) |
| Secrets | [kubernetes.io/docs/concepts/configuration/secret/](https://kubernetes.io/docs/concepts/configuration/secret/) |
| RBAC | [kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) |
| Network Policies | [kubernetes.io/docs/concepts/services-networking/network-policies/](https://kubernetes.io/docs/concepts/services-networking/network-policies/) |
| Gateway API | [kubernetes.io/docs/concepts/services-networking/gateway/](https://kubernetes.io/docs/concepts/services-networking/gateway/) |
| Ingress | [kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/) |
| DNS for Services and Pods | [kubernetes.io/docs/concepts/services-networking/dns-pod-service/](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) |
| Storage Classes | [kubernetes.io/docs/concepts/storage/storage-classes/](https://kubernetes.io/docs/concepts/storage/storage-classes/) |
| Taints and tolerations | [kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) |
| Node affinity | [kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) |
| Custom Resources | [kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) |
| Ephemeral containers | [kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/) |
| Sidecar containers | [kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) |

### Tasks (learn how to do things)

| Topic | URL |
| --- | --- |
| Install kubeadm | [kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) |
| Create a cluster with kubeadm | [kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) |
| Upgrade a cluster | [kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/) |
| Backup and restore etcd | [kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) |
| Configure persistent volume storage | [kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/) |
| Configure a Pod to use a ConfigMap | [kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) |
| Manage Secrets | [kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/) |
| Declare Network Policies | [kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/) |
| HPA walkthrough | [kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) |
| Debug running Pods | [kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) |
| Debug Services | [kubernetes.io/docs/tasks/debug/debug-application/debug-service/](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) |
| Manage objects with Kustomize | [kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) |
| Extend the API with CRDs | [kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) |

### Reference (look things up fast)

| Topic | URL |
| --- | --- |
| kubectl quick reference | [kubernetes.io/docs/reference/kubectl/quick-reference/](https://kubernetes.io/docs/reference/kubectl/quick-reference/) |
| kubectl command reference | [kubernetes.io/docs/reference/kubectl/](https://kubernetes.io/docs/reference/kubectl/) |
| kubectl generated reference | [kubernetes.io/docs/reference/kubectl/generated/](https://kubernetes.io/docs/reference/kubectl/generated/) |
| Kubernetes API reference | [kubernetes.io/docs/reference/kubernetes-api/](https://kubernetes.io/docs/reference/kubernetes-api/) |
| kubeadm reference | [kubernetes.io/docs/reference/setup-tools/kubeadm/](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) |
| Well-known labels and annotations | [kubernetes.io/docs/reference/labels-annotations-taints/](https://kubernetes.io/docs/reference/labels-annotations-taints/) |
| Ports and protocols | [kubernetes.io/docs/reference/networking/ports-and-protocols/](https://kubernetes.io/docs/reference/networking/ports-and-protocols/) |
| Glossary | [kubernetes.io/docs/reference/glossary/](https://kubernetes.io/docs/reference/glossary/) |

### Tutorials (guided walkthroughs)

| Topic | URL |
| --- | --- |
| Kubernetes Basics (interactive) | [kubernetes.io/docs/tutorials/kubernetes-basics/](https://kubernetes.io/docs/tutorials/kubernetes-basics/) |
| Configure Redis using a ConfigMap | [kubernetes.io/docs/tutorials/configuration/configure-redis-using-configmap/](https://kubernetes.io/docs/tutorials/configuration/configure-redis-using-configmap/) |
| Adopting sidecar containers | [kubernetes.io/docs/tutorials/configuration/pod-sidecar-containers/](https://kubernetes.io/docs/tutorials/configuration/pod-sidecar-containers/) |
| Expose an external IP | [kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/](https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/) |
| PHP Guestbook with Redis | [kubernetes.io/docs/tutorials/stateless-application/guestbook/](https://kubernetes.io/docs/tutorials/stateless-application/guestbook/) |
| WordPress with Persistent Volumes | [kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/](https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/) |
| StatefulSet basics | [kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/) |
| Connecting apps with Services | [kubernetes.io/docs/tutorials/services/connect-applications-service/](https://kubernetes.io/docs/tutorials/services/connect-applications-service/) |

---

## Official courses and training

### Linux Foundation (exam vendor)

| Course | Format | Cost | Notes |
| --- | --- | --- | --- |
| [Kubernetes Fundamentals (LFS258)](https://training.linuxfoundation.org/training/kubernetes-fundamentals/) | Self-paced | $645 with CKA exam | Aligns directly with CKA objectives |
| [Kubernetes Administration (LFS458)](https://training.linuxfoundation.org/training/kubernetes-administration/) | Instructor-led | Varies | Live cohort; includes free CKA exam registration |
| [Introduction to Kubernetes (LFS158)](https://training.linuxfoundation.org/training/introduction-to-kubernetes/) | Self-paced | Free | Foundational course on edX |
| [Kubernetes and Cloud Native Essentials (LFS250)](https://training.linuxfoundation.org/training/kubernetes-and-cloud-native-essentials-lfs250/) | Self-paced | Free/Paid | Broader cloud-native context |

### CNCF training hub

| Resource | URL | Cost |
| --- | --- | --- |
| All CNCF courses | [cncf.io/training/courses/](https://www.cncf.io/training/courses/) | Free and paid |
| CNCF certifications overview | [cncf.io/training/certification/](https://www.cncf.io/training/certification/) | Reference |
| Kubernetes training page | [kubernetes.io/training/](https://kubernetes.io/training/) | Directory |

---

## Community courses and platforms

These are the most recommended third-party resources based on community consensus and candidate reports.

### KodeKloud (most recommended by exam passers)

| Resource | URL | Cost | Notes |
| --- | --- | --- | --- |
| CKA Certification Course | [kodekloud.com/courses/cka-certification-course-certified-kubernetes-administrator](https://kodekloud.com/courses/cka-certification-course-certified-kubernetes-administrator) | Paid | Integrated browser-based labs for every concept |
| CKA Learning Path | [kodekloud.com/learning-path/cka](https://kodekloud.com/learning-path/cka) | Paid | Structured learning sequence |
| Ultimate CKA Mock Exam Series | [kodekloud.com/courses/ultimate-certified-kubernetes-administrator-cka-mock-exam](https://kodekloud.com/courses/ultimate-certified-kubernetes-administrator-cka-mock-exam) | Paid | 20 questions across 4 clusters simulating real exam |

### Udemy

| Resource | URL | Cost | Notes |
| --- | --- | --- | --- |
| CKA with Practice Tests (Mumshad Mannambeth) | [udemy.com/course/certified-kubernetes-administrator-with-practice-tests/](https://www.udemy.com/course/certified-kubernetes-administrator-with-practice-tests/) | Paid (frequent sales) | Same content as KodeKloud CKA, with Udemy platform |

### Pluralsight

| Resource | URL | Cost | Notes |
| --- | --- | --- | --- |
| CKA v1.35 Skill Path (Tim Warner) | [pluralsight.com/authors/tim-warner](https://www.pluralsight.com/authors/tim-warner) | Subscription | 11 courses, 15 hours, built for Feb 2025 curriculum |

---

## Books

### CKA-specific

| Book | Author | Edition | Notes |
| --- | --- | --- | --- |
| *Certified Kubernetes Administrator (CKA) Study Guide* | Benjamin Muschko | 2nd (Jan 2026) | First book aligned with Feb 2025 curriculum revision. Covers CRDs, Gateway API, Helm. Practice exercises mirror exam format. |
| *Kubernetes: Preparing for the CKA and CKAD Certifications* | Philippe Martin | 2021 | Covers older curriculum but excellent for core concepts. |

### Kubernetes fundamentals

| Book | Author | Notes |
| --- | --- | --- |
| *The Kubernetes Book* | Nigel Poulton | 2026 edition. Best entry point. Assumes zero prior knowledge. Covers Pods, Deployments, Services, storage, RBAC with hands-on labs. |
| *Kubernetes in Action* | Marko Luksa, Kevin Conner | 2nd edition. Deep dive into K8s architecture and internals. Excellent for understanding why things work the way they do. |
| *Kubernetes: Up and Running* | Brendan Burns, Joe Beda, Kelsey Hightower, Lachlan Evenson | 3rd edition. Written by Kubernetes co-founders. Practical introduction to deploying and managing containers. |

**Recommended reading order:** *The Kubernetes Book* (foundations) then *CKA Study Guide* (exam-targeted) then *Kubernetes in Action* (deep understanding).

---

## Free video resources

### YouTube channels

| Channel | Best for | Recommended content |
| --- | --- | --- |
| [TechWorld with Nana](https://www.youtube.com/@TechWorldwithNana) | Visual explanations of complex concepts | Full Kubernetes course, CI/CD, GitOps |
| [KodeKloud](https://www.youtube.com/@KodeKloud) | Lab-focused walkthroughs | Kubernetes for Absolute Beginners playlist, CKA tips |
| [freeCodeCamp](https://www.youtube.com/@freecodecamp) | Long-form comprehensive courses | Docker and Kubernetes full courses (3-8 hours) |
| [That DevOps Guy (Marcel Dempers)](https://www.youtube.com/@introgadgets) | Practical cloud-native demos | Kubernetes networking deep dives |
| [Just me and Opensource](https://www.youtube.com/@introgadgets) | Cluster setup from scratch | kubeadm, HA clusters, etcd |

### Specific videos to watch

- TechWorld with Nana: "Kubernetes Tutorial for Beginners" -- full course overview
- KodeKloud: "Kubernetes Crash Course" -- with free labs
- TechWorld with Nana: CKA preparation course at [techworld-with-nana.com/kubernetes-administrator-cka](https://www.techworld-with-nana.com/kubernetes-administrator-cka)

---

## Hands-on lab environments

Practice environments are critical. Aim for 80% of your study time in a terminal.

### Free browser-based

| Platform | URL | Notes |
| --- | --- | --- |
| Killercoda | [killercoda.com/playgrounds/scenario/kubernetes](https://killercoda.com/playgrounds/scenario/kubernetes) | Free Kubernetes playground. Same K8s version as current exam. No install needed. |
| Killercoda CKA scenarios | [killercoda.com/killer-shell-cka](https://killercoda.com/killer-shell-cka) | CKA-specific practice scenarios in browser |
| Play with Kubernetes | [labs.play-with-k8s.com](https://labs.play-with-k8s.com/) | Docker-provided K8s playground. 4-hour sessions. |
| Play with Kubernetes Classroom | [training.play-with-kubernetes.com](https://training.play-with-kubernetes.com/) | Guided workshops without local setup |

### Local environments (recommended for deeper practice)

| Tool | URL | Notes |
| --- | --- | --- |
| kind (Kubernetes IN Docker) | [kind.sigs.k8s.io](https://kind.sigs.k8s.io/) | **Recommended for CKA prep.** Multi-node clusters in Docker. Fast startup. Exam-aligned. |
| minikube | [minikube.sigs.k8s.io](https://minikube.sigs.k8s.io/) | Single-node cluster. Good for beginners. Multiple driver options. |
| k3d (k3s in Docker) | [k3d.io](https://k3d.io/) | Lightweight alternative to kind. Faster startup, lower resource use. |
| Vagrant + VirtualBox | [vagrantup.com](https://www.vagrantup.com/) | Required for kubeadm practice with real systemd and package management. |

**Recommendation:** Use kind for 85% of scenarios. Use Vagrant + VirtualBox for kubeadm init/join/upgrade practice.

---

## Practice exams and simulators

| Resource | URL | Cost | Notes |
| --- | --- | --- | --- |
| killer.sh | [killer.sh](https://killer.sh/) | Included (2 sessions with CKA purchase) | Identical to exam environment. Intentionally harder than real exam. 36 hours per session. |
| KodeKloud Mock Exams | [kodekloud.com/courses/ultimate-certified-kubernetes-administrator-cka-mock-exam](https://kodekloud.com/courses/ultimate-certified-kubernetes-administrator-cka-mock-exam) | Paid | 20 questions, 4 clusters, exam-realistic simulation |
| KodeKloud Lightning Labs | Included in CKA course | Paid | Quick-fire timed exercises |
| Killercoda CKA Practice | [killercoda.com/killer-shell-cka](https://killercoda.com/killer-shell-cka) | Free | Browser-based CKA scenarios |

### killer.sh strategy

- **Session 1:** Take early in your study (week 8-9). Use it to identify gaps. A score of 40-50% is normal on the first attempt.
- **Gap study:** Spend 3-5 days studying your weak areas.
- **Session 2:** Take 2-3 days before your real exam. Target 70%+ for confidence. A score of 90%+ on killer.sh means you are very well prepared.
- **Do not activate both sessions at once.** Each starts a 36-hour timer immediately.

---

## GitHub study repositories

Community-maintained repositories with notes, cheat sheets, and practice exercises.

| Repository | URL | Notes |
| --- | --- | --- |
| The Ultimate CKA Guide | [github.com/anouarharrou/The-Ultimate-CKA-Guide](https://github.com/anouarharrou/The-Ultimate-CKA-Guide) | Notes, labs, cheat sheets aligned with CNCF curriculum |
| CKA Guide 2025 (Cloud Native Islamabad) | [github.com/Cloud-Native-Islamabad/Certified-Kubernetes-Administrator-CKA-Guide-2025](https://github.com/Cloud-Native-Islamabad/Certified-Kubernetes-Administrator-CKA-Guide-2025) | Concepts, commands, practical examples. Includes cheat sheet. |
| CKA Certified Kubernetes Administrator | [github.com/techwithmohamed/CKA-Certified-Kubernetes-Administrator](https://github.com/techwithmohamed/CKA-Certified-Kubernetes-Administrator) | v1.35 syllabus, etcd, RBAC, Gateway API, killer.sh prep |
| CKA Certification Guide (DevOpsCube) | [github.com/techiescamp/cka-certification-guide](https://github.com/techiescamp/cka-certification-guide) | In-depth explanations, hands-on labs, study materials |
| CKA Certification Course 2025 | [github.com/CloudWithVarJosh/CKA-Certification-Course-2025](https://github.com/CloudWithVarJosh/CKA-Certification-Course-2025) | Beginner-friendly, organized into daily lessons |
| CNCF Curriculum (official) | [github.com/cncf/curriculum](https://github.com/cncf/curriculum) | Official exam curriculum PDF |

---

## Official references to bookmark

These pages are accessible during the exam and worth bookmarking in advance. Practice navigating to them quickly.

### Must-bookmark pages

| Page | Why | URL |
| --- | --- | --- |
| kubectl quick reference | Every exam task uses kubectl | [kubernetes.io/docs/reference/kubectl/quick-reference/](https://kubernetes.io/docs/reference/kubectl/quick-reference/) |
| RBAC | Role/ClusterRole/Binding YAML examples | [kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) |
| Network Policies | Ingress/egress YAML patterns | [kubernetes.io/docs/concepts/services-networking/network-policies/](https://kubernetes.io/docs/concepts/services-networking/network-policies/) |
| Persistent Volumes | PV/PVC/SC YAML examples | [kubernetes.io/docs/concepts/storage/persistent-volumes/](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) |
| etcd backup/restore | Exact commands with TLS flags | [kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) |
| kubeadm upgrade | Step-by-step upgrade procedure | [kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/) |
| Gateway API | GatewayClass/Gateway/HTTPRoute YAML | [kubernetes.io/docs/concepts/services-networking/gateway/](https://kubernetes.io/docs/concepts/services-networking/gateway/) |
| Gateway API guides | Routing examples | [gateway-api.sigs.k8s.io/guides/](https://gateway-api.sigs.k8s.io/guides/) |
| Helm commands | install, upgrade, rollback, list | [helm.sh/docs/helm/](https://helm.sh/docs/helm/) |
| Debug running Pods | kubectl debug, ephemeral containers | [kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) |
| Kustomize | kubectl apply -k, kustomization.yaml | [kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) |
| ConfigMaps | Creation and mounting patterns | [kubernetes.io/docs/concepts/configuration/configmap/](https://kubernetes.io/docs/concepts/configuration/configmap/) |
| Secrets | Creation and injection patterns | [kubernetes.io/docs/concepts/configuration/secret/](https://kubernetes.io/docs/concepts/configuration/secret/) |

---

## CKA domain-specific resources

### Cluster Architecture, Installation and Configuration (25%)

| Topic | Resource |
| --- | --- |
| RBAC deep dive | [kubernetes.io/docs/reference/access-authn-authz/rbac/](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) |
| kubeadm cluster creation | [kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) |
| kubeadm upgrade | [kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/) |
| etcd operations | [kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/) |
| HA topology | [kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/) |
| Helm quickstart | [helm.sh/docs/intro/quickstart/](https://helm.sh/docs/intro/quickstart/) |
| Helm using | [helm.sh/docs/intro/using_helm/](https://helm.sh/docs/intro/using_helm/) |
| Kustomize | [kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/) |
| Custom resources | [kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) |
| CRD creation | [kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/) |
| Container runtimes (CRI) | [kubernetes.io/docs/setup/production-environment/container-runtimes/](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) |

### Workloads and Scheduling (15%)

| Topic | Resource |
| --- | --- |
| Deployments | [kubernetes.io/docs/concepts/workloads/controllers/deployment/](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) |
| Rolling updates | [kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/) |
| ConfigMaps | [kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) |
| Secrets | [kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/](https://kubernetes.io/docs/tasks/configmap-secret/managing-secret-using-kubectl/) |
| HPA | [kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/) |
| Taints and tolerations | [kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) |
| Node affinity | [kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) |
| Resource management | [kubernetes.io/docs/concepts/configuration/manage-resources-containers/](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) |
| Sidecar containers | [kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/) |

### Services and Networking (20%)

| Topic | Resource |
| --- | --- |
| Services | [kubernetes.io/docs/concepts/services-networking/service/](https://kubernetes.io/docs/concepts/services-networking/service/) |
| Network Policies | [kubernetes.io/docs/concepts/services-networking/network-policies/](https://kubernetes.io/docs/concepts/services-networking/network-policies/) |
| Declare Network Policy | [kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/) |
| Gateway API | [kubernetes.io/docs/concepts/services-networking/gateway/](https://kubernetes.io/docs/concepts/services-networking/gateway/) |
| Gateway API guides | [gateway-api.sigs.k8s.io/guides/](https://gateway-api.sigs.k8s.io/guides/) |
| HTTP routing | [gateway-api.sigs.k8s.io/guides/http-routing/](https://gateway-api.sigs.k8s.io/guides/http-routing/) |
| Ingress | [kubernetes.io/docs/concepts/services-networking/ingress/](https://kubernetes.io/docs/concepts/services-networking/ingress/) |
| Ingress controllers | [kubernetes.io/docs/concepts/services-networking/ingress-controllers/](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) |
| DNS for Services | [kubernetes.io/docs/concepts/services-networking/dns-pod-service/](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) |
| Debug Services | [kubernetes.io/docs/tasks/debug/debug-application/debug-service/](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) |

### Storage (10%)

| Topic | Resource |
| --- | --- |
| Volumes | [kubernetes.io/docs/concepts/storage/volumes/](https://kubernetes.io/docs/concepts/storage/volumes/) |
| Persistent Volumes | [kubernetes.io/docs/concepts/storage/persistent-volumes/](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) |
| Storage Classes | [kubernetes.io/docs/concepts/storage/storage-classes/](https://kubernetes.io/docs/concepts/storage/storage-classes/) |
| Dynamic provisioning | [kubernetes.io/docs/concepts/storage/dynamic-provisioning/](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/) |
| Configure PV storage | [kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-persistent-volume-storage/) |

### Troubleshooting (30%)

| Topic | Resource |
| --- | --- |
| Troubleshoot applications | [kubernetes.io/docs/tasks/debug/debug-application/](https://kubernetes.io/docs/tasks/debug/debug-application/) |
| Troubleshoot clusters | [kubernetes.io/docs/tasks/debug/debug-cluster/](https://kubernetes.io/docs/tasks/debug/debug-cluster/) |
| Debug running Pods | [kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) |
| Debug Services | [kubernetes.io/docs/tasks/debug/debug-application/debug-service/](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) |
| Determine reason for Pod failure | [kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/](https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/) |
| Get shell to running container | [kubernetes.io/docs/tasks/debug/debug-application/get-shell-running-container/](https://kubernetes.io/docs/tasks/debug/debug-application/get-shell-running-container/) |
| Ephemeral containers | [kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/](https://kubernetes.io/docs/concepts/workloads/pods/ephemeral-containers/) |
| Monitor resource usage | [kubernetes.io/docs/tasks/debug/debug-cluster/resource-usage-monitoring/](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-usage-monitoring/) |
| Logging architecture | [kubernetes.io/docs/concepts/cluster-administration/logging/](https://kubernetes.io/docs/concepts/cluster-administration/logging/) |

---

## Community and support

| Resource | URL | Notes |
| --- | --- | --- |
| Kubernetes Slack | [slack.k8s.io](https://slack.k8s.io/) | Channels: #cka-exam-prep, #kubernetes-users |
| CNCF Slack | [cloud-native.slack.com](https://cloud-native.slack.com/) | Cloud-native community |
| r/kubernetes (Reddit) | [reddit.com/r/kubernetes](https://www.reddit.com/r/kubernetes/) | Exam experiences, tips, study group formation |
| Kubernetes Forum | [discuss.kubernetes.io](https://discuss.kubernetes.io/) | Official discussion forum |
| Stack Overflow | [stackoverflow.com/questions/tagged/kubernetes](https://stackoverflow.com/questions/tagged/kubernetes) | Technical Q&A |
| KodeKloud Community | [kodekloud.com/community](https://kodekloud.com/community/) | CKA-specific study discussions |
| Linux Foundation Support | [trainingsupport.linuxfoundation.org](https://trainingsupport.linuxfoundation.org/) | Exam registration and technical issues |

---

## Study time estimates by experience level

| Experience level | Description | Estimated study time |
| --- | --- | --- |
| **Beginner** | New to Kubernetes, some Linux/Docker experience | 200-250 hours (12-16 weeks) |
| **Intermediate** | Use Kubernetes at work, familiar with core concepts | 100-150 hours (8-12 weeks) |
| **Advanced** | Daily Kubernetes administration, strong kubectl skills | 40-60 hours (4-6 weeks) |
| **Recertifying** | Previously certified, need to learn new Feb 2025 topics | 20-40 hours (2-4 weeks) |

### How to allocate your time

| Activity | Percentage | Notes |
| --- | --- | --- |
| Hands-on practice (labs, clusters) | 50% | This is where learning sticks |
| Practice exams and timed exercises | 20% | Build speed and exam stamina |
| Video courses and reading | 20% | Concepts and mental models |
| Review and note-taking | 10% | Reinforce weak areas |

### The 80/20 rule for CKA

Focus 80% of your effort on these high-impact areas:

1. **kubectl imperative commands** -- You will use these in every single task.
2. **Troubleshooting** -- 30% of the exam. Master the diagnostic ladder.
3. **RBAC** -- Appears frequently. Know Role, ClusterRole, RoleBinding, ClusterRoleBinding cold.
4. **NetworkPolicies** -- Complex ingress/egress rules are heavily tested.
5. **etcd backup/restore** -- Appears on nearly every exam.
6. **Helm operations** -- New topic, frequently tested.
7. **Gateway API** -- New topic, frequently tested.
8. **kubeadm upgrades** -- Drain, upgrade, uncordon sequence.
