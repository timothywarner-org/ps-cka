---
name: cka-practice-scenario
description: "Generate an exam-realistic CKA practical scenario with two-phase delivery."
argument-hint: "domain='troubleshooting' difficulty='medium'"
agent: cka-cert-buddy-agent
tools:
  - ckabuddy-k8sdocs/*
---

# CKA Practice Scenario

Generate **ONE** original, exam-realistic **CKA** practice scenario.

## Use this skill

You must follow the workspace skill **cka-scenario-creator** for scenario structure, guardrails, workflow, output format, and **delivery rules** (Phase 1 / Phase 2 interactive flow).

## Inputs (from chat)

- Domain: ${input:domain:Pick a CKA domain (or leave blank and the agent picks one)}
- Objective: ${input:objective:Specific objective to test (optional)}
- Difficulty: ${input:difficulty:easy | medium | hard}

## Grounding and validation rules

1. Ground the expected solution in official **Kubernetes documentation**.
2. Verify all kubectl commands are syntactically correct for Kubernetes v1.35.
3. Provide **kubernetes.io/docs URLs** in the Phase 2 References section.

## Key rules

- Randomize the fictional company name from `references/fictional-companies.md`.
- Follow all style rules from `references/style-guide.md`.
- Every scenario must start with `kubectl config use-context <cluster>`.
- Prefer imperative kubectl commands over writing YAML from scratch.
- All resource names must follow Kubernetes conventions (lowercase, hyphens).
- Always specify namespace explicitly.
- No contractions.

## Output format (exact) -- two-phase delivery

### Phase 1 (send first, then STOP and wait for user to request solution)

#### Metadata

- Exam: CKA
- Domain:
- Objective:
- Difficulty:
- Estimated time:
- Cluster:

---

Set the correct cluster context:

`kubectl config use-context <cluster-name>`

**Task:**

`<Company context. Specific task description with measurable completion criteria.>`

*(Do NOT reveal the solution. Wait for the user to type "solution," "hint," or "skip.")*

### Phase 2 (send after the user requests the solution)

#### Step-by-step commands

1. `<command with explanation>`
2. `<command with explanation>`

#### Explanation

`<Why each step works, Kubernetes concepts involved>`

#### Verification

```bash
<commands to verify the solution>
```

#### Exam speed tips

- `<imperative shortcuts>`
- `<time-saving techniques>`

#### Common mistakes

- `<what candidates get wrong>`

#### References

- `<kubernetes.io/docs URL 1>`
- `<kubernetes.io/docs URL 2 if needed>`
