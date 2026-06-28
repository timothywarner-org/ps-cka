# Course 5, M03 -- Scheduling and Autoscaling

[Course 5 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Workloads & Scheduling (15%)  

**Exam objectives:** Node selectors, affinity, taints and tolerations, and workload autoscaling with HPA and VPA.

---

## Coming as recorded

This module's exercise files (manifests, scripts, and any demo apps) land here as the module is recorded. Nothing is missing on your end. **Clone the repo and pull periodically**, or watch the repo on GitHub, so you get each module's files the day it ships.

Until then, the objectives above tell you exactly what this module covers on the exam.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with two paths:

- **Fast path (KIND on Docker):** `cd src/cka-lab; ./kind-up.ps1` for a sub-30-second multi-node cluster.
- **Exam-shaped path (Hyper-V + Vagrant):** real VMs with kubeadm v1.35 for node-level break/fix drills.
