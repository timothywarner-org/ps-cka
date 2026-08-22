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

Every manifest here is built to run on a standard cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
