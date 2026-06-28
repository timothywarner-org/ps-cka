# Course 2, M02 -- Bootstrapping a Cluster with kubeadm init and join

[Course 2 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** Declarative kubeadm init.yaml, kubectl admin config, and joining workers with a fresh token.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`m02-kubeadm-init-join-slides.pdf`](m02-kubeadm-init-join-slides.pdf) | Slide deck (PDF) for this module. |
| [`c02-m02-demo-runbook.md`](c02-m02-demo-runbook.md) | Recording runbook: control-plane init and worker join, with a troubleshooting table. |

Every manifest here is built to run on a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with two paths:

- **Fast path (KIND on Docker):** `cd src/cka-lab; ./kind-up.ps1` for a sub-30-second multi-node cluster.
- **Exam-shaped path (Hyper-V + Vagrant):** real VMs with kubeadm v1.35 for node-level break/fix drills.
