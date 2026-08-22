# Course 9, M01 -- Troubleshooting the Control Plane

[Course 9 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Troubleshooting (30%)  

**Exam objectives:** Diagnosing API server, scheduler, controller-manager, and etcd failures via static pods and logs.

---

## Coming as recorded

This module's exercise files (manifests, scripts, and any demo apps) land here as the module is recorded. Nothing is missing on your end. **Clone the repo and pull periodically**, or watch the repo on GitHub, so you get each module's files the day it ships.

Until then, the objectives above tell you exactly what this module covers on the exam.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
