# Course 10 -- Troubleshooting Workloads and Services

[Skill path home](../../README.md)

**Course 10 of 11**  |  **CKA domain:** Troubleshooting (30%)  |  **Runtime:** ~90 min

Diagnose workload and service failures: container output and logs, service/networking faults, and ephemeral containers plus native sidecars.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Container Output and Logs](m01-container-output/README.md) | Reading container logs (including --previous for CrashLoopBackOff) and stdout/stderr behavior. | Coming as recorded |
| M02 | [Troubleshooting Services and Networking](m02-services-networking/README.md) | Service-to-pod wiring, EndpointSlices, and diagnosing broken service connectivity. | Coming as recorded |
| M03 | [Ephemeral Containers and Native Sidecars](m03-ephemeral-sidecars/README.md) | kubectl debug with ephemeral containers and native sidecars (initContainers with restartPolicy: Always) (new in Feb 2025). | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
