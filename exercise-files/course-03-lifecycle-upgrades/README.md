# Course 3 -- Managing Cluster Lifecycle and Upgrades

[Skill path home](../../README.md)

**Course 3 of 11**  |  **CKA domain:** Cluster Architecture (25%)  |  **Runtime:** ~75 min

Keep a cluster healthy over time: back up and restore etcd, run a live kubeadm version upgrade, and manage cluster components with Helm, Kustomize, and CRDs.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Backing Up and Restoring etcd](m01-backing-up-etcd/README.md) | etcd snapshot save (etcdctl) and offline status/restore (etcdutl); the backup discipline that protects cluster state. | Recorded |
| M02 | [Upgrading Clusters with kubeadm](m02-upgrading-clusters/README.md) | The version skew policy and a live control-plane plus worker upgrade (v1.34 to v1.35) with drain, kubelet upgrade, and uncordon. | Recorded |
| M03 | [Helm, Kustomize, and CRDs](m03-helm-kustomize-crds/README.md) | Package management with Helm, template-free customization with Kustomize, and extending the API with CRDs (the operator pattern). | Recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.

### Course 3 lab drivers

Course 3 records off the Hyper-V Vagrant lab using plain-English control scripts in [`src/cka-lab/course-03-lifecycle-upgrades/`](../../src/cka-lab/course-03-lifecycle-upgrades/) (`Start-CkaLab`, `Save-CkaSnapshot`, `Restore-CkaSnapshot`, and the on-rails `Invoke-M02Upgrade.ps1` / `Invoke-M03Lab.ps1` demo runners). See that folder's [README](../../src/cka-lab/course-03-lifecycle-upgrades/README.md) for the full map.
