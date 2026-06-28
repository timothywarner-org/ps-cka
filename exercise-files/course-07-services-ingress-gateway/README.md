# Course 7 -- Services, Ingress, and Gateway API

[Skill path home](../../README.md)

**Course 7 of 11**  |  **CKA domain:** Services & Networking (20%)  |  **Runtime:** ~90 min

Expose workloads: Service types, Ingress for HTTP routing, and the new Gateway API (GatewayClass, Gateway, HTTPRoute) added in the February 2025 curriculum.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Service Types](m01-service-types/README.md) | ClusterIP, NodePort, LoadBalancer, and how Services map to EndpointSlices. | Coming as recorded |
| M02 | [Ingress](m02-ingress/README.md) | Ingress resources, ingress controllers, and host/path routing rules. | Coming as recorded |
| M03 | [Gateway API](m03-gateway-api/README.md) | GatewayClass, Gateway, and HTTPRoute (new in Feb 2025; the successor to Ingress). | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
