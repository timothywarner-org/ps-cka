# Course 4, M02 -- ServiceAccounts

[Course 4 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** ServiceAccounts, token projection, and binding workload identities to RBAC roles.

---

## Exercise files

| File | What it is |
|------|------------|
| [`lab.sh`](lab.sh) | The only script you run on the node. Reset, mint, and verify subcommands; asserts both the expected allows and the expected denials. Idempotent. |
| [`m02.demo.sh`](m02.demo.sh) | Presenter script for the four demos, driving `demo-drive.sh`. |
| [`demo-drive.sh`](demo-drive.sh) | The presenter engine, with a record/replay output cache for safe retakes. |
| [`commands.sh`](commands.sh) | Every command from the module in order, to copy or paste-run. |
| [`check-token-exp.sh`](check-token-exp.sh) | Mints a token and decodes its claims to show TTL and audience. Cleans up the ServiceAccount it creates. |
| [`capture-m02.sh`](capture-m02.sh) | Captures demo output for review. Writes `capture-m02.txt`, which is gitignored because a real token can appear in it. |
| [`deploy-runner.yaml`](deploy-runner.yaml) | Deployment whose Pod spec carries no projected volume -- admission adds it, which is the lesson. |
| [`ghost-sa.yaml`](ghost-sa.yaml) | A ServiceAccount with no Secret, proving auto-generation stopped in v1.24. |
| [`no-automount.yaml`](no-automount.yaml) | `automountServiceAccountToken: false`, the least-privilege default worth teaching. |
| [`c04-m02-demo-runbook.md`](c04-m02-demo-runbook.md) | Full runbook with pre-flight and timings. |
| [`CKA-C04-M02-RUNBOOK.md`](CKA-C04-M02-RUNBOOK.md) | Condensed on-camera prompter. |

Run `./lab.sh` first. It is safe to re-run any number of times.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with the exam-shaped lab:

- **Hyper-V + Vagrant:** three real Ubuntu VMs (`control1`, `worker1`, `worker2`) running kubeadm-built Kubernetes v1.35 with Calico, for node-level break/fix drills.
- Bring it up with `Start-CkaLab.ps1`, check it with `Get-CkaLabStatus.ps1`, and snapshot before risky steps with `Save-CkaSnapshot.ps1`.
