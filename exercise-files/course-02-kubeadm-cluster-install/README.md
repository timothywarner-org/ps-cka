# Course 2 -- Installing Clusters with kubeadm

[Skill path home](../../README.md)

**Course 2 of 11**  |  **CKA domain:** Cluster Architecture (25%)  |  **Runtime:** ~90 min

Bootstrap a real multi-node cluster from scratch on Linux VMs: host prep, kubeadm init and join, and CNI install with cluster validation.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Preparing Linux Hosts for kubeadm](m01-linux-host-prep/README.md) | Kernel modules, sysctl, containerd as the CRI runtime, and pinning kubeadm/kubelet/kubectl. | Recorded |
| M02 | [Bootstrapping a Cluster with kubeadm init and join](m02-kubeadm-init-join/README.md) | Declarative kubeadm init.yaml, kubectl admin config, and joining workers with a fresh token. | Recorded |
| M03 | [Installing a CNI Plugin and Validating Cluster Health](m03-cni-cluster-validation/README.md) | Installing a CNI, confirming pod networking and DNS, and the six-point cluster validation checklist. | Recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
