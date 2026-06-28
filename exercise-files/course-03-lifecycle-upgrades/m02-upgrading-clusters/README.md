# Course 3, M02 -- Upgrading Clusters with kubeadm

[Course 3 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** The version skew policy and a live control-plane plus worker upgrade (v1.34 to v1.35) with drain, kubelet upgrade, and uncordon.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`m02-upgrading-clusters-slides.pdf`](m02-upgrading-clusters-slides.pdf) | Slide deck (PDF) for this module. |
| [`CKA-C03-M02-demo-runbook.md`](CKA-C03-M02-demo-runbook.md) | Recording runbook: an eight-phase kubeadm upgrade, mirroring the on-rails Invoke-M02Upgrade.ps1 lab driver. |
| [`m02-kubeadm-upgrade.sh`](m02-kubeadm-upgrade.sh) | Control-plane upgrade: apt repo repoint, kubeadm upgrade plan/apply, kubelet upgrade. |
| [`m02-worker-upgrade.sh`](m02-worker-upgrade.sh) | Worker upgrade: drain, kubeadm upgrade node, kubelet upgrade, uncordon. |

Every manifest here is built to run on a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with two paths:

- **Fast path (KIND on Docker):** `cd src/cka-lab; ./kind-up.ps1` for a sub-30-second multi-node cluster.
- **Exam-shaped path (Hyper-V + Vagrant):** real VMs with kubeadm v1.35 for node-level break/fix drills.
