# Contributing to CKA Cert Buddy

Thank you for your interest in contributing to this project. CKA Cert Buddy is an educational resource that helps people prepare for the Certified Kubernetes Administrator exam using GitHub Copilot agents. Contributions of all kinds are welcome -- whether you are fixing a typo, updating terminology, proposing a new skill, or improving reference material.

## How to Contribute

### Report Issues

If you find something that is incorrect, outdated, or broken, please open a GitHub issue. Common examples include:

- **Outdated Kubernetes API versions** -- a manifest using a deprecated apiVersion that should use the current stable version
- **Incorrect Kubernetes behavior** -- a scenario solution or lab step that does not match current Kubernetes v1.35 functionality
- **Broken MCP configurations** -- a server definition in `.vscode/mcp.json` that fails to start or uses an outdated endpoint
- **Inaccurate references** -- a kubernetes.io URL that no longer resolves or points to the wrong topic

When opening an issue, include enough detail to locate and reproduce the problem (file path, line number, expected vs. actual behavior).

### Suggest New Skills or Prompt Templates

Have an idea for a new agent skill or prompt template? Open an issue describing:

- What the skill or prompt would do
- Which CKA domain(s) and objective(s) it would cover
- How it would differ from the existing `cka-scenario-creator`, `cka-lab-creator`, and `cka-study-planner` skills

### Improve Reference Documents

The `references/` directory contains supporting material used by the agent:

- `cka-objectives.md` -- CKA v1.35 curriculum objectives
- `fictional-companies.md` -- fictional company names for scenario context
- `style-guide.md` -- writing style guide for Kubernetes content

If any of these documents are out of date or incomplete, submit a pull request with corrections.

### Fix Documentation

Improvements to the README, this file, CLAUDE.md, or any other documentation are always appreciated.

## Contribution Guidelines

All contributions must follow these rules. These are the same rules the agent itself enforces.

### Writing Style

- **No contractions** in any generated content or instructions. Write "do not" instead of "don't," "cannot" instead of "can't," and so on.
- **Plain ASCII only.** Do not use curly quotes, en dashes, em dashes, or other non-ASCII characters. Use straight quotes and double hyphens (`--`) instead.
- **Sentence-style capitalization** for headings and labels.
- **Imperative mood** in procedure steps. Tell the reader what to do.
- **Oxford comma** in all lists.

### Kubernetes Conventions

- All YAML manifests must use `apiVersion` values valid in Kubernetes v1.35.
- Resource names must follow Kubernetes conventions: lowercase, hyphens, no underscores.
- Always specify the namespace explicitly in commands and manifests.
- Every scenario must include a `kubectl config use-context` command.
- Prefer imperative kubectl commands with `--dry-run=client -o yaml` pipeline over writing YAML from scratch.

### Content Integrity

- **Scenarios must be original.** Do not copy, paraphrase, or reference real exam tasks, braindumps, or leaked content. Every scenario must be written from scratch.
- **Solutions must be accurate.** All kubectl commands must be syntactically correct and produce the expected result on Kubernetes v1.35.
- **Labs must include cleanup steps.** Every practice lab must end with steps that remove all resources created during the exercise.
- **All claims must be groundable in official documentation.** Reference only kubernetes.io/docs, kubernetes.io/blog, helm.sh/docs, and gateway-api.sigs.k8s.io.

## File Conventions

### Skill Files

Skill files live in `.github/skills/<skill-name>/SKILL.md`. Each file must have:

- **YAML frontmatter** with at least `name` and `description` fields
- **Markdown body** containing the skill specification

The `name` field in the YAML frontmatter is the canonical skill identifier. Agents and prompts reference skills by this name, not by the folder name.

### Prompt Files

Prompt files live in `.github/prompts/` and use the `.prompt.md` extension. Each file must have:

- **YAML frontmatter** with `name`, `description`, `agent`, and `tools` fields
- **Markdown body** containing the prompt template

The `agent` field must reference the agent by its frontmatter `name` (currently `cka-cert-buddy-agent`).

### MCP Server References

Tool IDs used in agent and prompt files must match the server IDs defined in `.vscode/mcp.json`. The current server ID is:

- `ckabuddy-k8sdocs` -- documentation MCP server

## Pull Request Process

1. **Fork the repository** and create a feature branch from `main`. Use a descriptive branch name (for example, `fix/rbac-scenario` or `add/gateway-api-lab`).

2. **Keep changes focused.** Submit one skill, one prompt template, or one logical fix per pull request. Small, focused pull requests are easier to review.

3. **Describe what you changed and why.** In the pull request description, explain the motivation for the change and summarize what files were modified.

4. **Verify Kubernetes accuracy.** Before submitting, check that all kubectl commands, YAML manifests, and API versions are correct for Kubernetes v1.35.

5. **Check ASCII compliance.** Make sure your changes do not introduce curly quotes, en dashes, or other non-ASCII characters.

6. **Test MCP references.** If your change adds or modifies tool references, confirm that the tool IDs match the server IDs in `.vscode/mcp.json`.

## Code of Conduct

This is an educational project built to help people learn and succeed. All contributors are expected to:

- **Be respectful.** Treat every contributor and learner with courtesy and professionalism.
- **Be constructive.** Offer specific, actionable feedback. Explain the "why" behind suggestions.
- **Be supportive of learners.** Remember that this project serves people at all experience levels. Avoid dismissive language or assumptions about what others should already know.
- **Be collaborative.** Work together toward the shared goal of producing accurate, helpful study material.

Harassment, discrimination, and disrespectful behavior will not be tolerated.

## Questions

If you have questions about contributing, reach out to the maintainer:

- **Name:** Tim Warner
- **Email:** <tim@techtrainertim.com>
- **Website:** [TechTrainerTim.com](https://TechTrainerTim.com)

Thank you for helping make CKA Cert Buddy a better resource for everyone preparing for the Certified Kubernetes Administrator exam.
