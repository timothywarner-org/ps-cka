# Course 1, M01 -- Architecture and Lab Setup

[Course 1 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cross-domain  

**Exam objectives:** Kubernetes architecture; control plane and node components; the CNI, CSI, and CRI extension interfaces.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`m01-architecture-lab-setup-slides.pdf`](m01-architecture-lab-setup-slides.pdf) | Slide deck (PDF) for this module. |
| [`../../../dev/m01-demo-runbook.md`](../../../dev/m01-demo-runbook.md) | Recording runbook: pre-flight, click path, and timed demos. |

Every manifest here is built to run on a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with two paths:

- **Fast path (KIND on Docker):** `cd src/cka-lab; ./kind-up.ps1` for a sub-30-second multi-node cluster.
- **Exam-shaped path (Hyper-V + Vagrant):** real VMs with kubeadm v1.35 for node-level break/fix drills.
