---
name: cka-study-planner
description: "Create a personalized CKA study plan based on your confidence ratings."
argument-hint: "Rate your confidence: 'architecture: Weak, workloads: Moderate, networking: Strong, storage: Weak, troubleshooting: Unknown'"
agent: cka-cert-buddy-agent
tools:
  - ckabuddy-k8sdocs/*
---

# CKA Study Planner

Generate a **personalized CKA study plan** based on your confidence across the five exam domains.

## Use this skill

You must follow the workspace skill **cka-study-planner** for workflow, output format, and **delivery rules** (full plan in a single message).

## Inputs (from chat)

- Architecture confidence: ${input:architecture:Strong | Moderate | Weak | Unknown}
- Workloads confidence: ${input:workloads:Strong | Moderate | Weak | Unknown}
- Networking confidence: ${input:networking:Strong | Moderate | Weak | Unknown}
- Storage confidence: ${input:storage:Strong | Moderate | Weak | Unknown}
- Troubleshooting confidence: ${input:troubleshooting:Strong | Moderate | Weak | Unknown}

## Grounding and validation rules

1. Ground all documentation links in real kubernetes.io/docs pages. Do not invent URLs.
2. Use the CKA curriculum from `references/cka-objectives.md` for objective mapping.
3. Prioritize weak domains first. Within equal confidence levels, prioritize by exam weight.

## Key rules

- No contractions.
- Do not skip any domain, even if rated Strong.
- Treat "Unknown" the same as "Weak."
- Highlight February 2025 curriculum additions (Gateway API, Helm, Kustomize, CRDs, operators, HPA/VPA, ephemeral containers, native sidecars, CNI/CSI/CRI).
