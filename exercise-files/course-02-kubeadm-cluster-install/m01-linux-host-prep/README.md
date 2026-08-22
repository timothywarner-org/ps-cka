# Course 2, M01 -- Preparing Linux Hosts for kubeadm

[Course 2 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** Kernel modules, sysctl, containerd as the CRI runtime, and pinning kubeadm/kubelet/kubectl.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`m01-linux-host-prep-slides.pdf`](m01-linux-host-prep-slides.pdf) | Slide deck (PDF) for this module. |
| [`c02-m01-demo-runbook.md`](c02-m01-demo-runbook.md) | Recording runbook: verify-first host-prep demo against the Hyper-V Vagrant lab. |

Every manifest here is built to run on a standard cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
