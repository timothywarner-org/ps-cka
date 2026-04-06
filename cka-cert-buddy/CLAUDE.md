# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Content-only repository for a CKA (Certified Kubernetes Administrator) certification study buddy powered by GitHub Copilot agents. No application code, no build system, no tests. Artifacts are agent definitions, skill specs, prompt templates, and MCP server configurations.

## Architecture

The **cka-cert-buddy-agent** (`.github/agents/`) orchestrates three auto-discovered skills (`.github/skills/`):

- **cka-scenario-creator** -- Exam-realistic practical scenarios with two-phase interactive delivery (scenario first, solution after user requests it). Supports "hint" and "skip" commands. The CKA exam is 100% performance-based -- no multiple choice.
- **cka-lab-creator** -- 15-30 minute guided labs on kind clusters with validation gates and mandatory cleanup.
- **cka-study-planner** -- Personalized study plans based on confidence self-assessment across five CKA exam domains.

Three prompt templates (`.github/prompts/`) provide slash-command entry points: `/cka-practice-scenario`, `/cka-practice-lab`, `/cka-study-planner`.

All content targets **Kubernetes v1.35** and the **February 2025 CKA curriculum revision**.

### Skill Discovery (Critical Gotcha)

GitHub Copilot **does not** support a `skills:` field in agent YAML frontmatter. Skills are auto-discovered from `.github/skills/` folders based on `name` and `description` in SKILL.md frontmatter. The agent references skills by name in its Markdown body only.

### Cross-Reference Dependencies

When renaming anything, update all dependents:
- Agent `name` field -> all `.github/prompts/*.prompt.md` `agent:` fields
- Skill `name` field -> agent Markdown body references
- MCP server ID in `.vscode/mcp.json` -> agent and prompt `tools:` lists

## Reference Documentation

The `references/` directory contains grounding material used by the agent and skills:

- **cka-objectives.md** -- CKA v1.35 curriculum with five domains and weights. Primary source for scenario and study plan generation.
- **cka-command-guide.md** -- Comprehensive command reference covering kubectl, kubeadm, etcdctl, Helm, and Kustomize. Organized by CKA exam domain. Includes syntax, examples, and exam speed techniques.
- **cka-exam-guide.md** -- Complete exam lifecycle from registration through renewal. Covers PSI requirements, check-in process, allowed resources, scoring, digital badges, and policies.
- **cka-learning-resources.md** -- Curated learning resources with a 12-week phased study plan, official documentation links, courses, books, lab environments, and practice exams.
- **fictional-companies.md** -- 25+ fictional company names for scenario context. Globomantics is primary (from the course storyline). Randomization across the full list is non-negotiable.
- **style-guide.md** -- Writing style guide adapted for Kubernetes content. Governs voice, formatting, capitalization of K8s resource kinds, and kubectl command conventions.

## CI Validation

`.github/workflows/validate.yml` runs on PR to `main` (non-blocking, `continue-on-error: true`):

1. **Deprecated API version check** -- greps for `extensions/v1beta1`, `apps/v1beta1`, etc.
2. **Non-ASCII check** -- greps for curly quotes, en dashes, em dashes
3. **Contraction check** -- greps for `don't`, `doesn't`, `won't`, etc.
4. **Context-switch check** -- verifies scenario files mention `kubectl config use-context`
5. **Terminology check** -- greps for `master node`, `slave node`, `ETCD`, etc.
6. **Markdown link check** -- validates URLs using mlc-config.json

## Kubernetes Terminology

Always use correct and current terminology:

| Incorrect | Correct |
| --- | --- |
| master node | control plane node |
| slave node | worker node |
| master/slave | primary/replica or control plane/worker |
| blacklist/whitelist | deny list/allow list or block list/allow list |
| kube-master | control plane |
| ETCD | etcd (always lowercase) |
| Containerd | containerd (always lowercase) |

## CKA Exam Clusters

Every scenario must include a context-switch command. Standard cluster names:

| Cluster | Use case |
| --- | --- |
| k8s-prod | Production cluster (most common) |
| k8s-staging | Staging environment |
| k8s-dev | Development cluster |
| ek8s | etcd-focused tasks |
| mk8s | Multi-node cluster tasks |
| wk8s | Worker-node focused tasks |

## Authoring Rules

These are enforced across all generated content and are non-negotiable:

- **Plain ASCII only** -- no curly quotes, no en/em dashes. Use `--` instead.
- **No contractions** -- write "do not" not "don't."
- **Sentence-style capitalization** everywhere except proper nouns and Kubernetes resource kinds.
- **Capitalize Kubernetes resource kinds** when referring to specific objects (Pod, Deployment, Service).
- **Code style** for kubectl commands, YAML keys, resource names, file paths, namespaces, and image names.
- **Imperative-first** -- prefer `kubectl create/run/expose --dry-run=client -o yaml` over writing YAML from scratch.
- **Diagnostic ladder** -- troubleshooting follows `get > describe > logs > events`.
- **Context switch first** -- every scenario starts with `kubectl config use-context <cluster>`.
- **Namespace always explicit** -- never rely on the default namespace.
- **Fictional company randomization** -- draw from the full 25+ list in `references/fictional-companies.md`, not always Globomantics.
- **Solutions must include verification** -- commands to confirm the task is complete.
- **Labs must include cleanup** -- kubectl delete commands at the end.
- **References from allowed exam docs only** -- kubernetes.io/docs, kubernetes.io/blog, helm.sh/docs, gateway-api.sigs.k8s.io.

## Default Behaviors

Preserve these when editing agent or skill content:

- Scenarios use two-phase delivery: Phase 1 (scenario only, wait for solution request), Phase 2 (full solution with verification and tips).
- Labs default to a **kind cluster** environment.
- Agent picks a domain from the CKA curriculum when none is specified.
- Default difficulty is **medium** when not specified.
