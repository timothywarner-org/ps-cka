# Kubernetes Foundations — Exercise Files

**Course 1 of 11** in Tim Warner's **Certified Kubernetes Administrator (CKA) v1.35 Skill Path** on Pluralsight.
Aligned to the **CKA v1.35 (February 2025) curriculum** revision.

[![Author](https://img.shields.io/badge/Author-Tim%20Warner-0078D4?style=for-the-badge&logo=pluralsight&logoColor=white)](https://TechTrainerTim.com)
[![Website](https://img.shields.io/badge/Website-TechTrainerTim.com-1F6FEB?style=for-the-badge&logo=googlechrome&logoColor=white)](https://TechTrainerTim.com)
[![Email](https://img.shields.io/badge/Email-tim%40techtrainertim.com-EA4335?style=for-the-badge&logo=gmail&logoColor=white)](mailto:tim@techtrainertim.com)

> Pluralsight author, Microsoft MVP, 200+ courses published.

---

## The exercise files live on GitHub — not in this download

> **Heads up:** This file is a **pointer**. Every manifest, lab config, demo app, and recording runbook for this course lives in the public GitHub repo below. Bookmark it, clone it, and keep it open while you watch the videos.

<p align="center">
  <a href="https://github.com/timothywarner-org/ps-cka">
    <img src="https://img.shields.io/badge/GO%20TO%20THE%20REPO-timothywarner-org%2Fps--cka-2EA043?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117" alt="Go to the repo" height="60">
  </a>
</p>

<p align="center">
  <a href="https://github.com/timothywarner-org/ps-cka/stargazers"><img src="https://img.shields.io/github/stars/timothywarner-org/ps-cka?style=flat-square&logo=github&color=FFD33D" alt="GitHub stars"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/Kubernetes-v1.35-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="Kubernetes v1.35"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/CKA-Feb%202025%20Curriculum-1F6FEB?style=flat-square" alt="CKA Feb 2025 Curriculum"></a>
  <a href="https://github.com/timothywarner-org/ps-cka"><img src="https://img.shields.io/badge/License-See%20Repo-lightgrey?style=flat-square" alt="License: see repo"></a>
  <a href="https://TechTrainerTim.com"><img src="https://img.shields.io/badge/Maintained%20by-Tim%20Warner-0078D4?style=flat-square&logo=microsoft&logoColor=white" alt="Maintained by Tim Warner"></a>
</p>

---

## What's in the repo

Welcome — I'm Tim, and here's the lay of the land when you arrive at [github.com/timothywarner-org/ps-cka](https://github.com/timothywarner-org/ps-cka):

- **`exercise-files/`** — All course manifests, organized by `course-NN-topic/mNN-module-name/`. Each module's YAML, scripts, and supporting assets live here.
- **`exercise-files/shared/apps/`** — Reusable demo applications (`catalog-api`, `fleet-dashboard`, `telemetry-worker`) backing the **Globomantics** storyline you'll see throughout the skill path.
- **`src/cka-lab/`** — A two-path lab environment so you can pick the right tool for the scenario:
  - **KIND path (fast, Docker-based)** — `kind-up.ps1` spins up a multi-node cluster in under 30 seconds. Pick from four topologies via interactive menu: **Simple** (1 CP + 1 worker), **Standard** (1 CP + 2 workers — the CKA exam topology), **HA** (3 CP + 2 workers), or **Workloads** (1 CP + 3 workers). Four on-rails tutorials walk you through architecture, kubectl workflows, core resources, and the diagnostic ladder.
  - **Hyper-V Vagrant path (exam-shaped)** — Three Ubuntu 22.04 VMs (`control1`, `worker1`, `worker2`) with kubeadm v1.35 prereqs pre-installed, static IPs on a dedicated `CKA-NAT` switch, and a native checkpoint-based snapshot/restore loop for unlimited practice resets.
- **`dev/m01-demo-runbook.md`**, **`dev/m02-demo-runbook.md`**, **`dev/m03-demo-runbook.md`** — Per-module recording runbooks containing my actual talk track, click paths, and timing — a peek behind the curtain so you can replay every demo at your own pace.
- **Multi-cluster context lab** — `kind-multi-up.ps1` stands up `cka-dev` and `cka-prod` side-by-side so you can drill `kubectl config use-context`, `--context`, `rename-context`, and `set-context --current --namespace` against two real clusters.

---

## Quick start (three commands)

```powershell
git clone https://github.com/timothywarner-org/ps-cka.git
cd ps-cka/src/cka-lab
./kind-up.ps1                      # interactive menu: pick topology + tutorial
```

That's it. The script handles Docker startup, prerequisite checks, NodePort preflight, and post-create labelling — you just pick a topology and start learning.

---

## What makes this skill path different

The February 2025 CKA curriculum revision added a meaningful slate of new objectives. This skill path covers all of them with dedicated demos and exercise files:

- **Gateway API** (`GatewayClass`, `Gateway`, `HTTPRoute`) — *Course 7*
- **Helm and Kustomize** for cluster components — *Course 3*
- **CRDs and operators** — *Course 3*
- **Workload autoscaling** (HPA/VPA) — *Course 5*
- **Ephemeral containers** and `kubectl debug` — *Course 10*
- **Native sidecar containers** (initContainers with `restartPolicy: Always`) — *Course 10*
- **Extension interfaces**: CNI, CSI, CRI — *Course 1*

If you've studied the older CKA curriculum, these are the deltas. If you're new to CKA, you're learning the current exam — not yesterday's.

---

## One more time — go to the repo

<p align="center">
  <a href="https://github.com/timothywarner-org/ps-cka">
    <img src="https://img.shields.io/badge/CLONE%20THE%20REPO-github.com%2Ftimothywarner-org%2Fps--cka-2EA043?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117" alt="Clone the repo" height="60">
  </a>
</p>

---

## Stay in touch

Thanks for taking this course — it genuinely means a lot. If you hit a snag, spot a bug, or just want to say hello, reach out:

- **Website:** [TechTrainerTim.com](https://TechTrainerTim.com)
- **Email:** [tim@techtrainertim.com](mailto:tim@techtrainertim.com)
- **Repo issues:** [github.com/timothywarner-org/ps-cka/issues](https://github.com/timothywarner-org/ps-cka/issues)

Now go pass that exam.

— **Tim Warner**
