# Course 4, M01 -- RBAC Fundamentals

[Course 4 overview](../README.md)  |  [Skill path home](../../../README.md)

**CKA domain:** Cluster Architecture (25%)  

**Exam objectives:** Roles, ClusterRoles, RoleBindings, ClusterRoleBindings, and verifying access with kubectl auth can-i.

---

## Exercise files

| File | What it is |
|------|------------|
| [`lab.sh`](lab.sh) | The only script you run on the node. `./lab.sh` resets then verifies; `reset` returns to frame zero between takes; `mint` creates the `frontend-dev` user; `verify` walks the module and exits 0 or 1. Idempotent. |
| [`m01.demo.sh`](m01.demo.sh) | Presenter script for the four demos. Types each command onto the shared terminal and routes the talk track to a private second terminal. |
| [`demo-drive.sh`](demo-drive.sh) | The presenter engine `m01.demo.sh` drives. Supports a record/replay output cache so a take cannot be ruined by a flaky node. |
| [`pod-reader.yaml`](pod-reader.yaml) | Role granting `get`/`list`/`watch` on pods -- the least-privilege starting point. |
| [`frontend-dev-csr.yaml`](frontend-dev-csr.yaml) | CertificateSigningRequest for the `frontend-dev` user, showing X.509 client-cert authentication end to end. |
| [`c04-m01-demo-runbook.md`](c04-m01-demo-runbook.md) | Full runbook: pre-flight, timings, verification ledger, trim ladder. |
| [`CKA-C04-M01-RUNBOOK.md`](CKA-C04-M01-RUNBOOK.md) | Condensed on-camera prompter: run the command, read the Say block. |
| [`START-HERE.md`](START-HERE.md) | One-page orientation for a recording session. |

Run `./lab.sh` first. It is safe to re-run any number of times.

---

## Spin up a lab

Practice every demo on your own cluster. The lab environment lives in [`src/cka-lab/`](../../../src/cka-lab/) with two paths:

- **Fast path (KIND on Docker):** `cd src/cka-lab; ./kind-up.ps1` for a sub-30-second multi-node cluster.
- **Exam-shaped path (Hyper-V + Vagrant):** real VMs with kubeadm v1.35 for node-level break/fix drills.
