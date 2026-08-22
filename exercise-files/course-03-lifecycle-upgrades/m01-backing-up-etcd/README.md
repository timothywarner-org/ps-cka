# Course 3, M01 -- Backing Up and Restoring etcd

[Course 3 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** etcd snapshot save (etcdctl) and offline status/restore (etcdutl); the backup discipline that protects cluster state.

---

## What's in this folder

| File | What it is |
| --- | --- |
| [`m01-backing-up-etcd-slides.pdf`](m01-backing-up-etcd-slides.pdf) | Slide deck (PDF) for this module. |
| [`CKA-C03-M01-demo-runbook.md`](CKA-C03-M01-demo-runbook.md) | Recording runbook for the etcd backup and restore demo. |
| [`commands.sh`](commands.sh) | The copy-paste demo path, in beat order, matching the video. |
| [`m01-etcd-backup.sh`](m01-etcd-backup.sh) | Take a timestamped etcd snapshot with etcdctl and certificate auth. |
| [`m01-etcd-restore.sh`](m01-etcd-restore.sh) | Restore etcd from a snapshot into a new data dir, then repoint the static pod. |
| [`stacked-vs-external-etcd.png`](stacked-vs-external-etcd.png) | The stacked-vs-external etcd topology diagram from the module. |

Every manifest here is built to run on a standard cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**, the exam topology.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
