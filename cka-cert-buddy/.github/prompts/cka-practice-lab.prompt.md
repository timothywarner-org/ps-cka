---
name: cka-practice-lab
description: "Build a guided hands-on CKA lab with validation and cleanup."
argument-hint: "domain='networking' timebox='20'"
agent: cka-cert-buddy-agent
tools:
  - ckabuddy-k8sdocs/*
---

# CKA Practice Lab

Generate **ONE** guided, self-validating **CKA** practice lab.

## Use this skill

You must follow the workspace skill **cka-lab-creator** for lab structure, guardrails, workflow, output format, and **delivery rules** (full lab in a single message).

## Inputs (from chat)

- Domain: ${input:domain:Pick a CKA domain (or leave blank and the agent picks one)}
- Objective: ${input:objective:Specific objective to practice (optional)}
- Timebox: ${input:timebox:Duration in minutes (default 20)}

## Grounding and validation rules

1. Ground the lab in official **Kubernetes documentation**.
2. Verify all kubectl commands are syntactically correct for Kubernetes v1.35.
3. Provide **kubernetes.io/docs URLs** in the References section.

## Key rules

- Randomize the fictional company name from `references/fictional-companies.md`.
- Follow all style rules from `references/style-guide.md`.
- Labs must run on a **kind** cluster (no cloud provider dependencies).
- All resource names must follow Kubernetes conventions (lowercase, hyphens).
- Always specify namespace explicitly.
- No contractions. Cleanup is mandatory.

## Output format

Use the YAML output format defined in the **cka-lab-creator** skill exactly. The output must include: title, objective, domain, estimated_time, prerequisites, starting_state, tasks (each with steps and validation), troubleshooting, cleanup (with validation), and references.
