# Security Policy

## Scope

This repository contains GitHub Copilot agent definitions, skill specifications,
prompt templates, and MCP server configurations for CKA certification study.
It does not contain application code, backend services, or deployable software.

The MCP server configurations in `.vscode/mcp.json` reference public
documentation endpoints only. No secrets are hardcoded in any tracked file.
The `.gitignore` file excludes `.env` files, private keys, and other sensitive
material from version control.

## Reporting a Vulnerability

If you discover a security issue in this repository, please report it by email:

- **To:** <tim@techtrainertim.com>
- **Subject line:** Security: cka-cert-buddy
- **Include:** A clear description of the issue, the affected file(s), and steps
  to reproduce the problem if applicable.

You can expect an initial response within 48 hours.

## What Counts as a Security Issue

The following are considered security issues and should be reported through the
process described above:

- **Hardcoded secrets or API keys** in any tracked file (agent definitions,
  skill specs, MCP configs, prompt templates, or reference documents).
- **MCP server configurations that could leak credentials**, such as configs
  that write secrets to logs, pass them as visible command-line arguments, or
  store them in plaintext outside of VS Code secure input prompts.
- **Prompt injection vulnerabilities** in agent or skill definitions that could
  cause the agent to bypass its safety rules, exfiltrate context, or execute
  unintended actions.
- **References to real exam content** that compromise the integrity of the
  CKA certification exam. This repository must contain only original practice
  material.

## What Is NOT a Security Issue

The following should be reported through regular GitHub Issues rather than the
security reporting process:

- Feature requests or suggestions for new content.
- Outdated Kubernetes terminology or API version changes.
- General documentation improvements.

## Responsible Disclosure

Please do not publicly disclose a security issue until it has been reviewed and
addressed. If you have reported a vulnerability and have not received a response
within 48 hours, you may send a follow-up email to the same address.

## Maintainer

- **Name:** Tim Warner
- **Email:** <tim@techtrainertim.com>
- **Website:** TechTrainerTim.com
