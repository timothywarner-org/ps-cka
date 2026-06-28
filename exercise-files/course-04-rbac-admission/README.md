# Course 4 -- Securing Access with RBAC and Admission Controls

[Skill path home](../../README.md)

**Course 4 of 11**  |  **CKA domain:** Cluster Architecture (25%)  |  **Runtime:** ~75 min

Control who can do what in the cluster: RBAC roles and bindings, ServiceAccounts for workloads, and admission controllers that enforce policy.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [RBAC Fundamentals](m01-rbac-fundamentals/README.md) | Roles, ClusterRoles, RoleBindings, ClusterRoleBindings, and verifying access with kubectl auth can-i. | Coming as recorded |
| M02 | [ServiceAccounts](m02-serviceaccounts/README.md) | ServiceAccounts, token projection, and binding workload identities to RBAC roles. | Coming as recorded |
| M03 | [Admission Controls](m03-admission-controls/README.md) | Admission controller plugins and validating/mutating admission for cluster policy enforcement. | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
