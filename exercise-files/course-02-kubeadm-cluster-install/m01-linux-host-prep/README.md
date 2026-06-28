# Course 2, M01 -- Preparing Linux Hosts for kubeadm

[Course 2 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** Kernel modules, sysctl, containerd as the CRI runtime, and pinning kubeadm/kubelet/kubectl.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`c02-m01-demo-runbook.md`](c02-m01-demo-runbook.md) | Recording runbook: verify-first host-prep demo against the Hyper-V Vagrant lab. |

Every manifest here is built to run on a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with two paths:

- **Fast path (KIND on Docker):** `cd src/cka-lab; ./kind-up.ps1` for a sub-30-second multi-node cluster.
- **Exam-shaped path (Hyper-V + Vagrant):** real VMs with kubeadm v1.35 for node-level break/fix drills.
