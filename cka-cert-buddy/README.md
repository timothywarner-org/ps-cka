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

### Scenario creator

Generates exam-realistic practical tasks matching the CKA performance-based format. Each scenario includes a context-switch command, a specific task with measurable completion criteria, and (on request) a comprehensive solution. Scenarios cover all five CKA domains with calibrated difficulty levels.

### Lab creator

Creates guided hands-on labs (15-30 minutes) that run on kind clusters. Labs include inline explanations, validation gates after each step, troubleshooting tips, and cleanup commands. Designed for learning, not exam simulation.

### Study planner

Generates a personalized study plan based on your self-assessed confidence across the five CKA exam domains. Prioritizes weak areas by exam weight, provides estimated study hours, links to official documentation, and highlights February 2025 curriculum additions.

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

1. **No exam copying.** All scenarios are original. No braindumps, no leaked content.
2. **Grounded in official docs.** Every answer is verifiable against kubernetes.io.
3. **Context switching.** Every scenario starts with `kubectl config use-context`.
4. **Imperative-first.** Prefer kubectl imperative commands for exam speed.
5. **Namespace explicit.** Never rely on the default namespace.
6. **Verification included.** Every solution includes commands to confirm correctness.
7. **Cleanup included.** Every lab ends with resource deletion steps.

## Exam Resources

- [CKA Exam Registration](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) ($445, includes retake + 2 killer.sh sessions)
- [CKA Curriculum v1.35](https://github.com/cncf/curriculum) (PDF)
- [Kubernetes Documentation](https://kubernetes.io/docs/) (allowed during exam)
- [Gateway API Documentation](https://gateway-api.sigs.k8s.io/) (allowed during exam)
- [Helm Documentation](https://helm.sh/docs/) (allowed during exam)
- [killer.sh Exam Simulator](https://killer.sh/)

## Troubleshooting

### MCP server does not start

The documentation MCP server is configured in `.vscode/mcp.json`. It is a free HTTP endpoint that requires no API key. If the server does not appear in Copilot Chat, restart VS Code and check the MCP server status in the output panel.

### Agent not found

Ensure you opened the `cka-cert-buddy/` folder (not the parent repository) as your VS Code workspace. The agent is defined in `.github/agents/cka-cert-buddy-agent.agent.md` and is only visible when this folder is the workspace root.

### Slash commands not showing

Slash commands are defined in `.github/prompts/`. They appear in Copilot Chat after the workspace loads. If they do not appear, reload VS Code (**Developer: Reload Window**).

## Repository Structure

```
cka-cert-buddy/
  .github/
    agents/
      cka-cert-buddy-agent.agent.md
    skills/
      cka-scenario-creator/SKILL.md
      cka-lab-creator/SKILL.md
      cka-study-planner/SKILL.md
    prompts/
      cka-practice-scenario.prompt.md
      cka-practice-lab.prompt.md
      cka-study-planner.prompt.md
    copilot-instructions.md
    workflows/
      validate.yml
      mlc-config.json
  .vscode/
    mcp.json
    extensions.json
  references/
    cka-objectives.md
    cka-command-guide.md
    cka-exam-guide.md
    cka-learning-resources.md
    fictional-companies.md
    style-guide.md
  data/
  images/
  CLAUDE.md
  README.md
  CONTRIBUTING.md
  SECURITY.md
  LICENSE
```

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
