# Copilot instructions

## Repository purpose

- This repo defines GitHub Copilot agent behavior and CKA (Certified Kubernetes Administrator) skills. There is no app code; the primary artifacts are agent definitions and skill specs.

## Key locations

- Agent definition: .github/agents/cka-cert-buddy-agent.agent.md
- Skills: .github/skills/\*/SKILL.md
- Prompts: .github/prompts/cka-practice-scenario.prompt.md, .github/prompts/cka-practice-lab.prompt.md, .github/prompts/cka-study-planner.prompt.md
- MCP servers (workspace only): .vscode/mcp.json
- Writing style guide: references/style-guide.md
- Fictional companies: references/fictional-companies.md
- CKA objectives: references/cka-objectives.md

## Skill and agent conventions

- Each skill file is a single YAML frontmatter block followed by Markdown.
- The skill name used by agents must match the YAML frontmatter name in the skill file, not the folder name.
- Skills are auto-discovered from `.github/skills/` folders. The agent references them by name in its Markdown body; there is no `skills:` field in agent YAML frontmatter.
- Agent files use YAML frontmatter with tools lists. Keep tool IDs scoped to MCP servers defined in .vscode/mcp.json.
- Prompt files (in .github/prompts/) reference agents by the `name` field in the agent's YAML frontmatter via the `agent:` key. The current value is `cka-cert-buddy-agent`. If the agent is renamed, update all prompt files that reference it.
- Current skills:
  - cka-scenario-creator (exam-realistic practical scenarios)
  - cka-lab-creator (guided hands-on labs)
  - cka-study-planner (personalized study plan generation)

## MCP server IDs

- ckabuddy-k8sdocs -- documentation MCP server for grounding content in official Kubernetes documentation

## Grounding and validation rules

- Scenarios and solutions must be grounded in official Kubernetes documentation first.
- Labs must be grounded in kubernetes.io/docs for correct configuration and kubectl syntax.
- If a request mixes scenarios and labs, split the output and apply the correct skill to each section.
- Reference only URLs from allowed exam documentation domains: kubernetes.io/docs, kubernetes.io/blog, helm.sh/docs, gateway-api.sigs.k8s.io.

## CKA exam format (non-negotiable)

The CKA exam is 100% performance-based. There are no multiple-choice questions. Candidates execute real commands against live Kubernetes clusters. All generated content must reflect this format:

- **Scenarios** present a practical task the candidate must complete using kubectl and YAML manifests.
- **Solutions** provide step-by-step commands with explanations, verification, and exam speed tips.
- Every scenario must include a `kubectl config use-context <cluster>` command at the top.
- Prefer imperative kubectl commands (`kubectl create`, `kubectl run`, `kubectl expose`, `--dry-run=client -o yaml`) over writing YAML from scratch.

## Exam clusters

The CKA exam uses six pre-built clusters. Use these names in scenarios:

| Cluster | Use case |
| --- | --- |
| k8s-prod | Production cluster (most common) |
| k8s-staging | Staging environment |
| k8s-dev | Development cluster |
| ek8s | etcd-focused tasks |
| mk8s | Multi-node cluster tasks |
| wk8s | Worker-node focused tasks |

## Fictional company randomization (non-negotiable)

Use fictional company names from references/fictional-companies.md for scenario context. Randomize the company selection across the full list of 25+ companies. Do not default to Globomantics for every scenario.

## Interactive scenario delivery

When the user asks for a practice scenario (one or more tasks):

1. Present **only** the metadata, context-switch command, and task description.
2. Do **NOT** include the solution, explanation, or references in the same message.
3. Wait for the user to request the solution (type "solution," "show solution," "answer," or similar).
4. After the user requests it, reveal the full solution with step-by-step commands, explanation, verification, exam speed tips, common mistakes, and references.

This rule applies to all scenario-generation skills and prompts in this workspace.

## Authoring guidance

- Keep instructions and outputs in plain ASCII (avoid curly quotes and en dashes).
- No contractions; avoid negatives unless required.
- Follow the writing style guide in references/style-guide.md for all generated content.
- All YAML must use apiVersion values valid in Kubernetes v1.35.
- Resource names must follow Kubernetes conventions (lowercase, hyphens, no underscores).
- Always specify namespace explicitly in commands and manifests.

## Kubernetes terminology

Always use correct and current Kubernetes terminology:

| Incorrect | Correct |
| --- | --- |
| master node | control plane node |
| slave node | worker node |
| master/slave | primary/replica or control plane/worker |
| blacklist/whitelist | deny list/allow list or block list/allow list |
| kube-master | control plane |
| pod (when referring to the resource kind) | Pod |
| deployment (when referring to the resource kind) | Deployment |
| etcd (capitalized) | etcd (always lowercase) |
| ETCD | etcd |
| containerd (capitalized) | containerd (always lowercase) |

## Diagnostic ladder pattern

For troubleshooting scenarios, reinforce the diagnostic ladder pattern introduced in Course 1:

```
get > describe > logs > events
```

This is the standard investigative sequence for any Kubernetes issue.
