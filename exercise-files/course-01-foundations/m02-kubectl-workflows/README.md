# Course 1, M02 -- kubectl Workflows

[Course 1 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cross-domain  

**Exam objectives:** Imperative and declarative kubectl; the dry-run to YAML pipeline; multi-cluster context switching.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`m02-kubectl-workflows-slides.pdf`](m02-kubectl-workflows-slides.pdf) | Slide deck (PDF) for this module. |

Every manifest here is built to run on a standard cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
