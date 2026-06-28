# Course 1 -- Kubernetes Foundations

[Skill path home](../../README.md)

**Course 1 of 11**  |  **CKA domain:** Cross-domain  |  **Runtime:** ~75 min

Cluster architecture, the kubectl workflow, core resources, and the diagnostic ladder that every later course builds on.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Architecture and Lab Setup](m01-architecture-lab-setup/README.md) | Kubernetes architecture; control plane and node components; the CNI, CSI, and CRI extension interfaces. | Coming as recorded |
| M02 | [kubectl Workflows](m02-kubectl-workflows/README.md) | Imperative and declarative kubectl; the dry-run to YAML pipeline; multi-cluster context switching. | Coming as recorded |
| M03 | [Core Resources and the Diagnostic Ladder](m03-core-resources-diagnostic-ladder/README.md) | Pods, ReplicaSets, Deployments, Services, EndpointSlices; the get > describe > logs > events diagnostic ladder. | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
