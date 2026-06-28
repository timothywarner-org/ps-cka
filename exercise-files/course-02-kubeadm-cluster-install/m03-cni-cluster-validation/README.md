# Course 2, M03 -- Installing a CNI Plugin and Validating Cluster Health

[Course 2 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** Installing a CNI, confirming pod networking and DNS, and the six-point cluster validation checklist.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`c02-m03-demo-runbook.md`](c02-m03-demo-runbook.md) | Recording runbook: CNI install, DNS smoke test, and the diagnostic ladder applied to a fresh cluster. |

Every manifest here is built to run on a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with two paths:

- **Fast path (KIND on Docker):** `cd src/cka-lab; ./kind-up.ps1` for a sub-30-second multi-node cluster.
- **Exam-shaped path (Hyper-V + Vagrant):** real VMs with kubeadm v1.35 for node-level break/fix drills.
