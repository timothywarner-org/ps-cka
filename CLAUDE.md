# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Tim Warner's **Certified Kubernetes Administrator (CKA) v1.35 Skill Path** for Pluralsight -- an 11-course video training series covering the February 2025 CKA curriculum revision. The repo holds exercise files, YAML manifests, lab configurations, and shared demo applications that accompany the courses.

## Repository Structure

- `exercise-files/` -- All course content, organized as `course-NN-topic/mNN-module-name/`
- `exercise-files/shared/apps/` -- Reusable demo applications (catalog-api, fleet-dashboard, telemetry-worker) used in the Globomantics storyline across multiple courses
- `exercise-files/K8S/` -- Reference books directory (not tracked in git)
- `exercise-files/reference-research/` -- Research materials
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

Course 11 is the exam-prep capstone. Course 1 establishes the shared kind cluster and diagnostic ladder pattern used throughout.

## Lab Environment

Primary: **kind** (Kubernetes IN Docker) on WSL2/Docker Desktop. The standard cluster config is 1 control-plane + 2 workers with extraPortMappings (80, 443, 30000). This config is reused across all 11 courses.

Secondary: **Vagrant + VirtualBox** for kubeadm-specific demos (Course 2) that need real systemd/package management.

Target Kubernetes version: **v1.35** (exam-aligned).

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
4. Ensure manifests work on kind clusters with Kubernetes v1.35

## February 2025 Curriculum Additions (High Priority)

These topics are new to the CKA exam and represent the primary differentiator of this skill path:

- Gateway API (GatewayClass, Gateway, HTTPRoute) -- Course 7
- Helm and Kustomize for cluster components -- Course 3
- CRDs and operators -- Course 3
- Workload autoscaling (HPA/VPA) -- Course 5
- Ephemeral containers / kubectl debug -- Course 10
- Native sidecar containers (initContainers with restartPolicy: Always) -- Course 10
- Extension interfaces: CNI, CSI, CRI -- Course 1
