# Course 9 -- Troubleshooting Clusters and Nodes

[Skill path home](../../README.md)

**Course 9 of 11**  |  **CKA domain:** Troubleshooting (30%)  |  **Runtime:** ~90 min

Diagnose cluster-level failures: control-plane component problems, worker-node failures, and monitoring resource health.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Troubleshooting the Control Plane](m01-troubleshoot-control-plane/README.md) | Diagnosing API server, scheduler, controller-manager, and etcd failures via static pods and logs. | Coming as recorded |
| M02 | [Troubleshooting Worker Nodes](m02-troubleshoot-worker-nodes/README.md) | kubelet, container runtime, and node-status diagnosis (NotReady, pressure conditions). | Coming as recorded |
| M03 | [Monitoring Resource Health](m03-monitor-resources-health/README.md) | kubectl top, the metrics pipeline, and reading resource health across the cluster. | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
