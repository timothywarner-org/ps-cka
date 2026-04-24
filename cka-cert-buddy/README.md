<div align="center">
  <img src="images/banner.png" alt="CKA Cert Buddy Banner" width="800">
</div>

# CKA Cert Buddy

[![CKA Exam](https://img.shields.io/badge/CKA-Feb%202025%20Curriculum-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.35-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Pluralsight Author](https://img.shields.io/badge/Pluralsight-Author-E80A89?style=for-the-badge&logo=pluralsight&logoColor=white)](https://www.pluralsight.com/authors/tim-warner)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

A **GitHub Copilot agent** that generates exam-realistic CKA practice scenarios, guided hands-on labs, and personalized study plans -- all grounded in official Kubernetes documentation.

The CKA exam is **100% performance-based**: approximately 17 practical tasks in 120 minutes, no multiple choice. This agent creates practice tasks that match the format, difficulty, and style of the real exam.

Built for the **February 2025 CKA curriculum revision** -- the largest update in CKA history.

> **Scope:** Cert Buddy is practice-focused (scenarios, lab walkthroughs, study plans). The runnable lab environment used throughout Tim Warner's CKA skill path -- KIND console app and Hyper-V Vagrant lab -- lives in [`../src/cka-lab/`](../src/cka-lab/).

## Prerequisites

| Requirement | Details |
| --- | --- |
| **VS Code** | Latest version |
| **GitHub Copilot** | Active subscription (Individual, Business, or Enterprise) |
| **GitHub Copilot Chat extension** | Install from the VS Code Extensions marketplace |
| **kind cluster** (optional) | For running hands-on labs locally |
| **kubectl v1.35** (optional) | For executing practice commands |

## Quick Start

1. **Clone the repository** and open it in VS Code.

   ```bash
   git clone https://github.com/timothywarner/ps-cka.git
   cd ps-cka/cka-cert-buddy
   code .
   ```

2. **Verify the MCP server** is active. Open Copilot Chat and check that the documentation server is listed. No API key is required.

3. **Start practicing.** Use slash commands or mention the agent directly.

## How to Use It

### Slash commands

| Command | What it does |
| --- | --- |
| `/cka-practice-scenario` | Generates an exam-realistic practical scenario |
| `/cka-practice-lab` | Creates a guided hands-on lab with validation gates |
| `/cka-study-planner` | Builds a personalized study plan based on your confidence |

### Agent mention

Type `@cka-cert-buddy-agent` in Copilot Chat followed by a natural language request:

- "Give me a hard troubleshooting scenario"
- "Build a lab on Gateway API"
- "I need a study plan -- I am weak on networking"
- "Quiz me on RBAC"

### Two-phase scenario delivery

Practice scenarios use a two-phase flow that mirrors exam conditions:

1. **Phase 1:** The agent presents the scenario -- metadata, context-switch command, and task description. You attempt the task on your own.
2. **Phase 2:** When you are ready, type **solution** to see the full answer with step-by-step commands, explanation, verification, exam speed tips, and common mistakes.

You can also type **hint** for a clue or **skip** to see the answer immediately.

## Skills

| Skill | What it generates |
| --- | --- |
| **Scenario creator** | Exam-realistic practical tasks with context-switch command, specific task, measurable completion criteria, and on-request solution. Calibrated difficulty across all five CKA domains. |
| **Lab creator** | 15-30 minute guided hands-on labs on kind clusters with inline explanations, validation gates, troubleshooting tips, and cleanup. Learning-focused, not exam simulation. |
| **Study planner** | Personalized study plan based on self-assessed confidence across the five domains. Prioritizes weak areas by exam weight, estimates hours, and highlights February 2025 additions. |

## Reference Documentation

The `references/` directory contains comprehensive reference materials for CKA exam preparation:

| Document | Description |
| --- | --- |
| [`cka-command-guide.md`](references/cka-command-guide.md) | Comprehensive command reference (1,500+ lines) covering every kubectl, kubeadm, etcdctl, Helm, and Kustomize command tested on the CKA exam, organized by exam domain with examples |
| [`cka-exam-guide.md`](references/cka-exam-guide.md) | Complete exam lifecycle guide (750+ lines) covering registration, PSI system requirements, check-in process, exam environment, allowed resources, scoring, digital badges, certification renewal, and policies |
| [`cka-learning-resources.md`](references/cka-learning-resources.md) | Curated learning resources (500+ lines) with a 12-week phased study plan, official documentation links, courses, books, lab environments, practice exams, and study time estimates |
| [`cka-objectives.md`](references/cka-objectives.md) | Official CKA v1.35 curriculum with all 5 domains and their weights |

## CKA Exam Domains

| Domain | Weight |
| --- | --- |
| Troubleshooting | 30% |
| Cluster Architecture, Installation and Configuration | 25% |
| Services and Networking | 20% |
| Workloads and Scheduling | 15% |
| Storage | 10% |

## February 2025 Curriculum Additions

These topics are new to the CKA exam and represent approximately 50% of questions per recent candidate reports:

- **Gateway API** -- GatewayClass, Gateway, HTTPRoute
- **Helm and Kustomize** -- installing and managing cluster components
- **CRDs and operators** -- custom resources and the controller pattern
- **Workload autoscaling** -- HPA and VPA configuration
- **Ephemeral containers** -- `kubectl debug` for distroless image debugging
- **Native sidecar containers** -- init containers with `restartPolicy: Always`
- **Extension interfaces** -- CNI, CSI, CRI plugin boundaries

## Key Rules

All generated content is original (no braindumps), grounded in kubernetes.io, uses explicit contexts and namespaces, prefers imperative kubectl, and ships with verification and cleanup steps. Full authoring rules live in [CLAUDE.md](CLAUDE.md) and [CONTRIBUTING.md](CONTRIBUTING.md).

## Exam Resources

- [CKA Exam Registration](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) ($445, includes retake + 2 killer.sh sessions)
- [CKA Curriculum v1.35](https://github.com/cncf/curriculum) (PDF)
- [Kubernetes Documentation](https://kubernetes.io/docs/) (allowed during exam)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/) (allowed during exam)
- [Helm Documentation](https://helm.sh/docs/) (allowed during exam)
- [killer.sh Exam Simulator](https://killer.sh/)

## Troubleshooting

- **MCP server does not start** -- the server in `.vscode/mcp.json` is a free HTTP endpoint and requires no API key. Restart VS Code and check the MCP output panel.
- **Agent not found** -- open the `cka-cert-buddy/` folder (not the parent repo) as your VS Code workspace. The agent at `.github/agents/cka-cert-buddy-agent.agent.md` is only visible when this folder is the workspace root.
- **Slash commands not showing** -- slash commands live in `.github/prompts/`. Run **Developer: Reload Window** in VS Code if they do not appear.

## Repository Structure

```
cka-cert-buddy/
  .github/
    agents/cka-cert-buddy-agent.agent.md   # Copilot agent definition
    skills/                                  # auto-discovered by name/description
      cka-scenario-creator/SKILL.md
      cka-lab-creator/SKILL.md
      cka-study-planner/SKILL.md
    prompts/                                 # slash-command entry points
      cka-practice-scenario.prompt.md
      cka-practice-lab.prompt.md
      cka-study-planner.prompt.md
    copilot-instructions.md                  # repo-wide Copilot instructions
    workflows/validate.yml                   # non-blocking content checks
  .vscode/mcp.json                           # MCP server config (tracked)
  references/                                # grounding docs (see table above)
  data/                                      # placeholder for future learner data
  images/banner.png
  CLAUDE.md  CONTRIBUTING.md  SECURITY.md  LICENSE  README.md
```

Internal architecture, authoring rules, and skill-discovery gotchas are documented in [CLAUDE.md](CLAUDE.md).

## Author

**Tim Warner** -- Microsoft MVP, Pluralsight author with 200+ courses, and technical trainer specializing in cloud infrastructure and certification preparation.

- [Pluralsight](https://www.pluralsight.com/authors/tim-warner)
- [GitHub](https://github.com/timothywarner)
- [Website](https://techtrainertim.com)

## Help and Support

- **Issues:** [Open an issue](https://github.com/timothywarner/ps-cka/issues) for bugs, incorrect content, or feature requests.
- **Contributing:** See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
- **Security:** See [SECURITY.md](SECURITY.md) for vulnerability reporting.

## License

This project is licensed under the MIT License -- see the [LICENSE](LICENSE) file for details.
