# CKA v1.35 Exam Curriculum

Source: Cloud Native Computing Foundation (CNCF) -- Certified Kubernetes Administrator (CKA) Exam Curriculum
Kubernetes version: v1.35 (February 2025 revision)
Last updated: 2026-04-06

---

## Exam overview

- **Format:** Performance-based (100% practical -- no multiple choice)
- **Duration:** 120 minutes
- **Tasks:** Approximately 17 tasks across 6 pre-built clusters
- **Passing score:** 66%
- **Cost:** $445 (includes one free retake and two killer.sh simulator sessions)
- **Allowed documentation during exam:**
  - kubernetes.io/docs
  - kubernetes.io/blog
  - helm.sh/docs
  - gateway-api.sigs.k8s.io

---

## Domains and weights

| Domain | Weight |
| --- | --- |
| Cluster Architecture, Installation and Configuration | 25% |
| Workloads and Scheduling | 15% |
| Services and Networking | 20% |
| Storage | 10% |
| Troubleshooting | 30% |

---

## Cluster Architecture, Installation and Configuration (25%)

- Manage role based access control (RBAC)
- Prepare underlying infrastructure for installing a Kubernetes cluster
- Create and manage Kubernetes clusters using kubeadm
- Manage the lifecycle of Kubernetes clusters
- Implement and configure a highly-available control plane
- Use Helm and Kustomize to install cluster components
- Understand extension interfaces (CNI, CSI, CRI, etc.)
- Understand CRDs, install and configure operators

## Workloads and Scheduling (15%)

- Understand application deployments and how to perform rolling update and rollbacks
- Use ConfigMaps and Secrets to configure applications
- Configure workload autoscaling
- Understand the primitives used to create robust, self-healing, application deployments
- Configure Pod admission and scheduling (limits, node affinity, etc.)

## Services and Networking (20%)

- Understand connectivity between Pods
- Define and enforce Network Policies
- Use ClusterIP, NodePort, LoadBalancer service types and endpoints
- Use the Gateway API to manage Ingress traffic
- Know how to use Ingress controllers and Ingress resources
- Understand and use CoreDNS

## Storage (10%)

- Implement storage classes and dynamic volume provisioning
- Configure volume types, access modes and reclaim policies
- Manage persistent volumes and persistent volume claims

## Troubleshooting (30%)

- Troubleshoot clusters and nodes
- Troubleshoot cluster components
- Monitor cluster and application resource usage
- Manage and evaluate container output streams
- Troubleshoot services and networking
