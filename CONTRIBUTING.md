# Contributing

Thank you for your interest in contributing to the CKA Skill Path exercise files.

## How to Contribute

1. **Fork** this repository
2. **Create a branch** for your change (`git checkout -b fix/broken-manifest`)
3. **Make your changes** and test them against a kind cluster running Kubernetes v1.35
4. **Commit** with a descriptive message (`git commit -m "fix: correct selector label in networkpolicy-deny-all.yaml"`)
5. **Push** to your fork and open a **Pull Request**

## What We Welcome

- Bug fixes in YAML manifests or scripts
- Improvements to exercise instructions
- Corrections to exam objective mappings
- Compatibility updates for newer Kubernetes versions

## Guidelines

- All Kubernetes manifests must work on a standard kind cluster (1 control-plane + 2 workers)
- Target Kubernetes v1.35 unless a specific version is required for the demo
- Use descriptive filenames that match the demo scenario
- Include comments linking to CKA exam objectives where relevant
- Follow the existing directory structure: `exercise-files/course-NN-topic/mNN-module-name/`

## Reporting Issues

If you find a broken manifest, incorrect command, or outdated reference, please [open an issue](https://github.com/timothywarner-org/ps-cka/issues) with:

- The course and module number
- What you expected vs. what happened
- Your Kubernetes version (`kubectl version --short`)

## Contact

- **Tim Warner** -- tim@techtrainertim.com
- Website: [TechTrainerTim.com](https://techtrainertim.com)
