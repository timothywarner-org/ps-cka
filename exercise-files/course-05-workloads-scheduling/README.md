# Course 5 -- Managing Workloads and Scheduling

[Skill path home](../../README.md)

**Course 5 of 11**  |  **CKA domain:** Workloads & Scheduling (15%)  |  **Runtime:** ~90 min

Run and tune workloads: Deployments and rolling updates, configuration via ConfigMaps and Secrets, and scheduling controls including HPA and VPA autoscaling.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Deployments and Rolling Updates](m01-deployments-rolling-updates/README.md) | Deployment rollouts, rollbacks, and rolling-update strategy tuning. | Coming as recorded |
| M02 | [ConfigMaps and Secrets](m02-configmaps-secrets/README.md) | Injecting configuration and secrets as env vars and volumes. | Coming as recorded |
| M03 | [Scheduling and Autoscaling](m03-scheduling-autoscaling/README.md) | Node selectors, affinity, taints and tolerations, and workload autoscaling with HPA and VPA. | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
