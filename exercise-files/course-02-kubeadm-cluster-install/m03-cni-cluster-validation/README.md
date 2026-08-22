# Course 2, M03 -- Installing a CNI Plugin and Validating Cluster Health

[Course 2 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** Installing a CNI, confirming pod networking and DNS, and the six-point cluster validation checklist.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`m03-cni-cluster-validation-slides.pdf`](m03-cni-cluster-validation-slides.pdf) | Slide deck (PDF) for this module. |
| [`c02-m03-demo-runbook.md`](c02-m03-demo-runbook.md) | Recording runbook: CNI install, DNS smoke test, and the diagnostic ladder applied to a fresh cluster. |

Every manifest here is built to run on a standard cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
