# Course 4, M03 -- Admission Controls

[Course 4 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** Admission controller plugins and validating/mutating admission for cluster policy enforcement.

---

## Exercise files

| File | What it is |
|------|------------|
| [`lab.sh`](lab.sh) | The only script you run on the node. Reset, mint, and verify subcommands, asserting both allows and denials. Idempotent. |
| [`m03.demo.sh`](m03.demo.sh) | Presenter script for the four demos, driving `demo-drive.sh`. |
| [`demo-drive.sh`](demo-drive.sh) | The presenter engine, with a record/replay output cache for safe retakes. |
| [`commands.sh`](commands.sh) | Every command from the module in order, to copy or paste-run. |
| [`limitrange.yaml`](limitrange.yaml) | LimitRange supplying default requests and limits -- LimitRanger mutating on admission. |
| [`limitrange-ceiling.yaml`](limitrange-ceiling.yaml) | LimitRange with a hard maximum, so the same plugin now refuses a Pod. |
| [`oversized-pod.yaml`](oversized-pod.yaml) | Pod that exceeds the ceiling and is rejected at admission. |
| [`resourcequota.yaml`](resourcequota.yaml) | ResourceQuota capping namespace totals. |
| [`privileged-deployment.yaml`](privileged-deployment.yaml) | Privileged Pod that Pod Security Admission rejects under `baseline`. |
| [`hardened-pod.yaml`](hardened-pod.yaml) | The same workload rewritten to satisfy `baseline`. It sets `runAsNonRoot` and `allowPrivilegeEscalation: false`, but deliberately does NOT meet `restricted` -- that needs a `seccompProfile` and `capabilities.drop: [ALL]`. `lab.sh` asserts this on every run. |
| [`CKA-C04-M03-RUNBOOK.md`](CKA-C04-M03-RUNBOOK.md) | On-camera runbook for the module. |

Run `./lab.sh` first. It is safe to re-run any number of times.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
