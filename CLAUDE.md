# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Tim Warner's **Certified Kubernetes Administrator (CKA) v1.35 Skill Path** for Pluralsight -- an 11-course video training series covering the February 2025 CKA curriculum revision. The repo holds exercise files, YAML manifests, lab configurations, shared demo applications, and a two-path lab environment that accompany the courses.

## Repository Structure

- `exercise-files/` -- All course content, organized as `course-NN-topic/mNN-module-name/`
- `exercise-files/shared/apps/` -- Reusable demo applications (catalog-api, fleet-dashboard, telemetry-worker) used in the Globomantics storyline across multiple courses
- `exercise-files/K8S/` -- Reference books directory (not tracked in git)
- `exercise-files/reference-research/` -- Research materials
- `src/cka-lab/` -- The lab environment (two paths: KIND console app and Hyper-V Vagrant lab). See `src/cka-lab/CLAUDE.md` for internal architecture.
- `cka-cert-buddy/` -- GitHub Copilot agent workspace for CKA practice scenarios, labs, and study plans
- `temp/` -- Working files: course outlines (DOCX), slide decks (PPTX), research docs, curriculum PDF. Gitignored.

## Course Architecture

11 courses, 3 modules each (~25-30 min/module), ~15 hours total. Weighted to CKA exam domains:

| Domain | Weight | Primary Courses |
|--------|--------|-----------------|
| Troubleshooting | 30% | 9, 10 |
| Cluster Architecture/Install/Config | 25% | 1, 2, 3, 4 |
| Services & Networking | 20% | 7, 8 |
| Workloads & Scheduling | 15% | 5 |
| Storage | 10% | 6 |

Course 11 is the exam-prep capstone. Course 1 establishes the shared lab cluster and diagnostic ladder pattern used throughout.

## Two Lab Paths

Both paths live under `src/cka-lab/`. Pick based on the module scenario:

### Fast path -- KIND console app

PowerShell 7 interactive menus that spin up multi-node clusters as Docker containers on Windows/WSL2. Sub-30-second create, four topology configs (simple, 3-node, HA, workloads), four guided tutorials dot-sourced from `lib/tutorials.ps1`. Entry points: `kind-up.ps1`, `kind-down.ps1`, `Start-Tutorial.ps1`. Used for the vast majority of demos across all 11 courses.

- Learner-facing walkthrough: `src/cka-lab/TUTORIAL-KIND.md`
- Internal architecture: `src/cka-lab/CLAUDE.md`

### Exam-shaped path -- Hyper-V Vagrant lab

Three Ubuntu 22.04 VMs (`control1`, `worker1`, `worker2`) with 2 GB / 2 vCPU each, kubeadm v1.35 prereqs pre-installed, static IPs on the `CKA-NAT` Hyper-V switch (`192.168.50.0/24`). Stops before `kubeadm init` so the learner bootstraps the cluster from scratch. Native Hyper-V checkpoints provide the snapshot/restore practice loop. Used primarily for Course 2 (kubeadm install) and any scenario that needs real systemd, a real package manager, or node-level break/fix drills.

- Learner-facing walkthrough: `src/cka-lab/TUTORIAL-HYPERV.md`
- Reliability features: atomic snapshot/restore, self-sufficient `join_worker.sh`, pinned Flannel + kubeadm versions, NodePort preflight, tutorial cleanup on Ctrl-C.

Target Kubernetes version for both paths: **v1.35** (exam-aligned).

## Key Conventions

- **Globomantics storyline**: All demos follow a fictional company migrating to Kubernetes. Maintain this narrative when creating exercise content.
- **Diagnostic ladder pattern**: `get > describe > logs > events` -- introduced in Course 1, Module 3, and reinforced in every subsequent course.
- **Imperative-first demos**: Use `kubectl run`, `kubectl create`, `kubectl expose` with `--dry-run=client -o yaml` pipeline for exam speed. Write YAML only when imperative shortcuts don't exist.
- **Course outline format**: DOCX files following the Pluralsight author template (see `temp/CKA-Course-01-Kubernetes-Foundations-Outline.docx` for the canonical example).
- **Slide decks**: PPTX files built from the Pluralsight 2026.03.a brand template.

## Working with Exercise Files

Exercise files are Kubernetes YAML manifests, shell scripts, and kind/Vagrant configs. When creating new exercise files:

1. Place them in the correct `course-NN/mNN-module/` directory
2. Use descriptive filenames matching the demo scenario (e.g., `broken-deployment.yaml`, `networkpolicy-deny-all.yaml`)
3. Include comments linking to CKA exam objectives where relevant
4. Ensure manifests work on both lab paths with Kubernetes v1.35

## February 2025 Curriculum Additions (High Priority)

These topics are new to the CKA exam and represent the primary differentiator of this skill path:

- Gateway API (GatewayClass, Gateway, HTTPRoute) -- Course 7
- Helm and Kustomize for cluster components -- Course 3
- CRDs and operators -- Course 3
- Workload autoscaling (HPA/VPA) -- Course 5
- Ephemeral containers / kubectl debug -- Course 10
- Native sidecar containers (initContainers with restartPolicy: Always) -- Course 10
- Extension interfaces: CNI, CSI, CRI -- Course 1
