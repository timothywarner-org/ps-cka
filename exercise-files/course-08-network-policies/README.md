# Course 8 -- Network Policies and Traffic Management

[Skill path home](../../README.md)

**Course 8 of 11**  |  **CKA domain:** Services & Networking (20%)  |  **Runtime:** ~75 min

Secure and troubleshoot cluster networking: pod networking and the CNI, NetworkPolicy rules, and DNS/CoreDNS troubleshooting.

---

## Modules

| # | Module | Exam objectives | Files |
| --- | --- | --- | --- |
| M01 | [Pod Networking Fundamentals and the CNI](m01-pod-networking-fundamentals-cni/README.md) | The pod network model and how the CNI plugin wires pod-to-pod connectivity. | Coming as recorded |
| M02 | [Network Policy Rules](m02-network-policies-rules/README.md) | NetworkPolicy ingress and egress rules, default-deny, and label selectors. | Coming as recorded |
| M03 | [DNS, CoreDNS, and Troubleshooting](m03-dns-coredns-troubleshooting/README.md) | Cluster DNS resolution, the CoreDNS deployment, and diagnosing name-resolution failures. | Coming as recorded |

---

## How to use this course

1. Open the module folder for the video you're watching; its **README** lists every file and maps it to the CKA exam objectives.
2. Spin up a cluster from [`src/cka-lab/`](../../src/cka-lab/) and run the demos yourself.
3. Manifests target a standard kind cluster (1 control-plane + 2 workers) at Kubernetes **v1.35**.
