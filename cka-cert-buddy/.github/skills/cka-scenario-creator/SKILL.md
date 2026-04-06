---
name: cka-scenario-creator
description: Generate CKA exam-realistic practical scenarios that match the format, difficulty, and style of real CKA performance-based tasks. Each scenario presents a task the candidate must complete using kubectl commands against a Kubernetes cluster. Use when the user asks for practice scenarios, exam tasks, or exam prep exercises.
---

# Skill: cka.practice_scenarios.exam_realistic

**Description:** Generate CKA exam-realistic practical scenarios that match the format, difficulty, and style of real CKA performance-based tasks. The CKA exam is 100% performance-based -- there are no multiple-choice questions. Candidates execute real commands against live clusters.

## Grounding

**Required sources:**

- Kubernetes official documentation (primary truth source for correct behavior, kubectl syntax, and YAML manifests; access via the **documentation MCP server** using available search and fetch tools)
- `references/cka-objectives.md` for the full CKA v1.35 curriculum objectives
- `references/style-guide.md` for writing style and Kubernetes conventions

**Allowed reference domains (matching real exam):**

- kubernetes.io/docs
- kubernetes.io/blog
- helm.sh/docs
- gateway-api.sigs.k8s.io

## Style

Follow all rules in `references/style-guide.md`. Key rules for scenarios:

- Sentence-style capitalization everywhere except proper nouns and Kubernetes resource kinds.
- Capitalize Kubernetes resource kinds when referring to specific objects (Pod, Deployment, Service).
- `Code style` for kubectl commands, YAML keys, resource names, file paths, namespaces, and image names.
- Imperative mood in task descriptions. Tell the candidate what to do.
- Oxford comma in all lists.
- No contractions.
- Plain ASCII only -- no curly quotes, no en/em dashes.

## Guardrails

**Exam integrity:**

- Do not recreate or paraphrase real exam tasks.
- Do not reference braindumps or leaked content.
- Write original scenarios every time.

**Technical accuracy:**

- All kubectl commands must be syntactically correct for Kubernetes v1.35.
- All YAML manifests must use correct apiVersion values (see `references/style-guide.md` for the API version table).
- Resource names must follow Kubernetes conventions (lowercase, hyphens, no underscores).
- Always specify namespace explicitly.
- Prefer imperative kubectl commands over writing YAML from scratch.

**Content quality:**

- No contractions.
- Each scenario tests a single CKA objective.
- Task descriptions must be specific and measurable -- the candidate must know exactly what "done" looks like.
- Do not include ambiguous requirements like "configure appropriately" without specifying what that means.

## Fictional company randomization (non-negotiable)

Use fictional company names from `references/fictional-companies.md` for scenario context. You MUST randomize the company selection -- do not default to Globomantics for every scenario. Draw from the full list of 25+ companies.

## Exam cluster assignment

Every scenario must include a context-switch command. Use cluster names from this list:

- `k8s-prod` -- production cluster (most common)
- `k8s-staging` -- staging environment
- `k8s-dev` -- development cluster
- `ek8s` -- etcd-focused tasks (ETCD backup/restore, HA control plane)
- `mk8s` -- multi-node cluster tasks (kubeadm, node management)
- `wk8s` -- worker-node focused tasks (scheduling, affinity, taints)

Match the cluster to the scenario type. For example, etcd tasks use `ek8s`, scheduling tasks use `wk8s`.

## Difficulty calibration

| Difficulty | Estimated time | Example tasks |
| --- | --- | --- |
| Easy | 2-3 minutes | Create a Pod, expose a Service, create a ConfigMap, create a Secret |
| Medium | 4-5 minutes | Configure RBAC, create a NetworkPolicy, set up HPA, configure a PersistentVolumeClaim |
| Hard | 6-8 minutes | ETCD backup and restore, kubeadm cluster upgrade, Gateway API routing, troubleshoot a multi-component failure, configure a CRD and operator |

## Workflow

1. Choose a single CKA domain and objective from `references/cka-objectives.md`.
2. Ground the expected solution in official Kubernetes documentation.
3. Pick a random fictional company from `references/fictional-companies.md` and draft a workplace scenario.
4. Assign an appropriate exam cluster from the cluster list above.
5. Write a clear, specific task description with measurable completion criteria.
6. Prepare the full solution internally but **do not deliver it yet** (see delivery rules below).
7. Run a technical accuracy check: verify all commands and YAML are valid for v1.35.
8. Run a completeness check: the task has a clear "done" state, namespace is specified, all resource names are given.

## Delivery rules (non-negotiable)

When presenting a scenario to the user:

**Phase 1 -- Scenario only:**

Show metadata, context-switch command, and task description. Do **NOT** include the solution, explanation, verification, or references. End the message and wait for the user to request the solution.

**Phase 2 -- Solution:**

After the user requests the solution (by typing "solution," "show solution," "answer," "reveal," or similar), show:

- Step-by-step commands (numbered, with exact kubectl syntax)
- Explanation (why each step works, Kubernetes concepts involved)
- Verification (commands to confirm the solution is correct)
- Exam speed tips (imperative shortcuts, time-saving techniques, common aliases)
- Common mistakes (what candidates typically get wrong on this type of task)
- References (kubernetes.io/docs URLs from allowed exam domains only)

If multiple scenarios were requested, repeat this Phase 1 / Phase 2 cycle for each scenario sequentially.

## Invalid input handling

- If the user types **"hint"**, provide a clue that narrows the approach (for example, suggest the relevant kubectl subcommand or point to the right documentation page) without revealing the full solution.
- If the user types **"skip"**, reveal the full solution (Phase 2), then move to the next scenario.
- If the user types something unrecognized, prompt: "Type **solution** to see the answer, **hint** for a clue, or **skip** to move on."

## Progress tracking

When multiple scenarios are requested:

- Prefix each scenario with **"Scenario N of M"** (for example, "Scenario 3 of 5").
- After all scenarios have been delivered, present a summary:
  - Total attempted
  - Total skipped
  - Domains covered
  - Suggested areas for additional practice

## Output format

**Phase 1 message (scenario only):**

```markdown
### CKA Practice Scenario [N of M]

**Domain:** <domain name> (<weight>%)
**Objective:** <specific objective from cka-objectives.md>
**Difficulty:** <easy | medium | hard>
**Estimated time:** <2-8 minutes>
**Cluster:** <cluster name>

---

Set the correct cluster context:

`kubectl config use-context <cluster-name>`

**Task:**

<Company context sentence.> <Specific task description with measurable completion criteria. Include namespace, resource names, image names, port numbers, and any other specifics the candidate needs.>
```

*(Stop here. Wait for the user to request the solution.)*

**Phase 2 message (solution, after user requests it):**

```markdown
### Solution

#### Step-by-step commands

1. Set the cluster context.

   ```bash
   kubectl config use-context <cluster-name>
   ```

2. <Next step with exact command.>

   ```bash
   <command>
   ```

<...continue for all steps>

#### Explanation

<Why each step works. Kubernetes concepts involved. How the pieces fit together.>

#### Verification

```bash
<Commands to verify the solution is correct, with expected output described>
```

#### Exam speed tips

- <Imperative shortcut or alias>
- <Time-saving technique>
- <Documentation page to bookmark>

#### Common mistakes

- <What candidates typically get wrong>
- <Subtle gotcha to watch for>

#### References

- <kubernetes.io/docs URL 1>
- <kubernetes.io/docs URL 2 if needed>
```

---

## Prompt template

```text
Create {{count}} CKA exam-realistic practice scenarios.

Inputs:

- domain: {{domain}} (or select from CKA curriculum)
- objective: {{objective}} (or derive from curriculum)
- difficulty: {{difficulty}} (easy | medium | hard)

Requirements:

1. Ground every scenario in official Kubernetes documentation first.
2. Follow guardrails and output format exactly.
3. Randomize the exam cluster assignment appropriately.
4. Randomize the fictional company name from references/fictional-companies.md.
5. Use two-phase delivery: scenario first, solution only after requested.

Deliver {{count}} scenarios.
```
