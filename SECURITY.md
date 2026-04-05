# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in any exercise file, script, or configuration in this repository, please report it responsibly.

**Do not** open a public GitHub issue for security vulnerabilities.

Instead, email **tim@techtrainertim.com** with:

- A description of the vulnerability
- Steps to reproduce
- The affected file(s) and course/module

You will receive a response within 72 hours.

## Scope

This repository contains **training exercise files** -- YAML manifests, shell scripts, and cluster configurations intended for local lab environments. These files are designed for learning, not production use.

That said, we take security seriously and will address:

- Manifests that grant unnecessary privileges (e.g., cluster-admin where a scoped role suffices)
- Scripts that expose secrets or credentials
- Configurations that could be harmful if accidentally applied to a production cluster

## Best Practices for Learners

- Never apply exercise manifests to production clusters
- Review all YAML before applying (`kubectl apply -f` is an action, not a suggestion)
- Use dedicated lab clusters (kind, minikube) for all exercises
- Do not commit real secrets, tokens, or credentials to forks of this repo
