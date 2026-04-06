---
name: cka-lab-creator
description: Create guided hands-on CKA practice labs (15-30 minutes) that run on kind clusters. Every lab includes prerequisites, step-by-step instructions with explanations, validation gates, troubleshooting tips, and cleanup. Use when the user asks for a hands-on lab, guided exercise, or learning walkthrough.
---

# Skill: cka.practice_labs.guided

**Description:** Create guided hands-on CKA practice labs (15-30 minutes) that run on kind clusters. Unlike scenarios (which simulate exam conditions), labs are teaching-focused -- they include inline explanations to build understanding. Every lab includes prerequisites, step-by-step tasks with validation gates, troubleshooting tips, and cleanup.

## Grounding

**Required sources:**

- Kubernetes official documentation (primary truth source for correct behavior and kubectl syntax)
- `references/cka-objectives.md` for the CKA v1.35 curriculum objectives
- `references/style-guide.md` for writing style and Kubernetes conventions

**Allowed reference domains:**

- kubernetes.io/docs
- kubernetes.io/blog
- helm.sh/docs
- gateway-api.sigs.k8s.io

## Style

Follow all rules in `references/style-guide.md`. Key rules:

- Use `code style` for all commands, YAML keys, resource names, file paths, and namespaces.
- Imperative mood in procedure steps.
- No contractions.
- Plain ASCII only.

## Guardrails

- Keep the lab within CKA scope.
- Labs run on **kind** clusters (Kubernetes IN Docker). Do not require cloud provider resources.
- No contractions.
- No ambiguous steps. Every step must have a clear action and expected result.
- Always include cleanup steps that remove created resources.
- Always use current Kubernetes terminology (see `.github/copilot-instructions.md`).

## Fictional company randomization (non-negotiable)

Use fictional company names from `references/fictional-companies.md` for scenario context in lab titles or descriptions. You MUST randomize the company selection -- do not default to Globomantics for every lab. Draw from the full list of 25+ companies.

## Timebox guidance

A lab should contain no more than 15 steps total across all tasks. If the lab requires more than 15 steps, it likely exceeds the 30-minute timebox. In that case, split the content into two separate labs, each focused on a narrower objective.

## Workflow

1. Choose a single CKA domain and objective from `references/cka-objectives.md` and state it at the top.
2. Ground the intended configuration and commands in official Kubernetes documentation.
3. Draft the lab steps targeting a kind cluster environment.
4. Add explanation paragraphs after key steps to teach the underlying concept.
5. Add verification gates after each major step.
6. Add troubleshooting tips for common failures.
7. Add cleanup that exactly reverses the work.

## Output format

```yaml
lab:
  title: "<Action + resource, e.g., 'Configure RBAC for namespace isolation'>"
  objective: "<One sentence outcome tied to CKA curriculum>"
  domain: "<CKA domain name>"
  estimated_time: "<15-30 min>"
  prerequisites:
    - "kind cluster running with 1 control-plane and 2 worker nodes"
    - "kubectl v1.35 configured"
    - "<Any additional tools (helm, kustomize, etc.)>"
  starting_state:
    - "<What must already exist before the lab begins>"
  tasks:
    - name: "<Task 1 name>"
      steps: |
        <Numbered steps with exact kubectl commands. Include explanation
        paragraphs between steps to teach the concept.>
      validation:
        - "<Validation command + what success looks like>"
    - name: "<Task 2 name>"
      steps: |
        <...>
      validation:
        - "<...>"
  troubleshooting:
    - symptom: "<common failure>"
      fix: "<precise fix>"
  cleanup:
    steps: |
      <Exact kubectl delete commands to remove all created resources>
    validation:
      - "<Check that resources are gone>"
  references:
    - "<kubernetes.io/docs URL(s)>"
```

## Delivery rules

Labs are delivered in full (all sections in a single message). Unlike practice scenarios, there is no interactive hold-back of solutions. If multiple labs are requested, deliver each lab sequentially in the same message.

## Quality checklist

- "Single domain, single objective."
- "Every task has an explicit validation gate."
- "Cleanup is complete and safe."
- "Instructions use Kubernetes conventions from style-guide.md."
- "All kubectl commands are valid for Kubernetes v1.35."
- "All YAML uses correct apiVersion values."
- "Namespaces are always specified explicitly."
- "No contractions in any lab text."
- "Fictional company is randomized (not always Globomantics)."
- "Lab runs on a kind cluster without cloud provider dependencies."

---

## Prompt template

```text
Create {{count}} CKA guided practice labs.

Inputs:

- domain: {{domain}} (or select from CKA curriculum)
- objective: {{objective}} (or derive from curriculum)
- timebox: {{timebox}} (default 20 minutes)

Requirements:

1. Ground the lab in official Kubernetes documentation first.
2. Output using output_format exactly.
3. Randomize the fictional company name from references/fictional-companies.md.
4. Labs must run on kind clusters.
```
