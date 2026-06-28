# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- **M03 tutorial helper now supports multi-beat sections** via a `-Steps` hashtable array on `Write-TutorialSection`. Six sections (1, 2, 3, 5, 9, 10) split into 2-3 teaching beats each so cause and effect get separate Enter presses (delete pod → watch ReplicaSet resurrect; scale Deployment → watch EndpointSlice grow; switch context → re-prove the ladder). 10-section cap is unchanged; beats live INSIDE a section. Setup beats carry an empty `OutputFields` so the "What you just saw" block is skipped — the next beat's output IS the lesson. Sections 4, 6, 7, 8 stay single-command.
- **Tutorial visual render gained breathing room.** Both the multi-beat path and the legacy single-command path now route through `Write-TutorialBeatBody`, which frames every block (beat header, Command line, breakdown, command output, OutputFields, terminator dashes) with blank-line padding for on-camera readability. Yellow Command + Wong sky-blue output preserved end-to-end. If you add a section, render through the helper — do not bypass it with raw Write-Output blocks or the breathing-room rhythm desyncs.
- **M02 tutorial consolidated 17 → 10 sections** for on-camera pacing. Merged deployment + expose, folded `kubectl get all` into the apply round-trip + "all is a lie" beat, merged JSONPath + custom-columns, dropped pod dry-run (redundant with deployment dry-run), non-recursive `kubectl explain` (recursive carries the LO), api-resources (M01 dupe), and field selector (peripheral on blueprint). Added `--show-labels` to label selector section. Target runtime 14-15 min → 10-12 min on camera; Enter-press count 19 → 12.
- **M03 tutorial consolidated 21 → 10 sections** for on-camera pacing. Merged bare-vs-managed + side-by-side, self-healing arc, service + slices + scale, namespaces + compound selectors, DNS short + FQDN, multi-cluster sticky-switch + one-shot. Dropped single-cluster context verify (M02 owns it) and the no-run summary flashcard. Target runtime stays 16-18 min; Enter-press count 23 → 12.
- **M03 swapped legacy `kubectl get endpoints` to v1.35-aligned `kubectl get endpointslices -l kubernetes.io/service-name=...`** to match the modern `discovery.k8s.io/v1` API that kube-proxy actually reads. Endpoints API is frozen — no dual-stack, no topology hints — and the CKA Feb 2025 curriculum was rewritten around EndpointSlices.
- **M03 added compound label selector** (`-l app=catalog,env=staging`) to namespaces section. Exam-frequent pattern that was missing from prior versions.
- **M03 added `kubectl logs --previous` callout** to the LOGS + EVENTS section. Seeds CrashLoopBackOff debugging muscle memory for Course 10 troubleshooting scenarios.
- Tutorial output styling: yellow command lines + Wong sky-blue command output for instant cause→effect contrast on camera; neon-green INFO banners.
- `Start-Tutorial.ps1` menu labels updated to reflect the 10-step counts for Modules 2 and 3.

### Added

- **`k8s-foundations-exercise-files.md` pointer file** at the repo root — single-file Pluralsight Course 1 ("Kubernetes Foundations") exercise-files download that points learners back to `github.com/timothywarner-org/ps-cka` for all manifests, lab scripts, and recording runbooks.
- **Multi-cluster context lab** (`kind-multi-up.ps1`, `kind-multi-down.ps1`, `Start-ContextPractice.ps1`) — stands up `cka-dev` (1 CP + 1 worker, ports 30100/30180) and `cka-prod` (1 CP + 2 workers, ports 30200/30280) side by side. Powers M03's gated section 10/10 with graceful-degrade if either cluster is missing.
- **Status probes** (read-only, CI-safe): `kind-status.ps1`, `kind-multi-status.ps1`, `cka-status.ps1` (Hyper-V VMs).
- **Per-module recording runbooks** in `dev/`: `m01-`, `m02-`, `m03-demo-runbook.md`. Each carries pre-flight, camera checklist, click path, timed demos, reset-between-takes, and recovery cheat sheet mapped to the section numbering in `lib/tutorials.ps1`.
- **Vim cheatsheet** at `src/cka-lab/docs/vim-cheatsheet.md` for the on-rails YAML-editing demos.
- Cross-platform port preflight via `[System.Net.Sockets.TcpListener]` (replaces Windows-only `Get-NetTCPConnection`) so the multi-cluster scripts work from pwsh-in-WSL2.
- Targeted WSL terminate in `kind-down -Force` (opt-in pruning instead of nuke-all).

### Fixed

- Standardized Tim's contact email to `timothywarner316@gmail.com` across `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`.
- Doc consistency sweep: corrected stale section counts (16/18/57 → 10/10/42) and stale section references (`1/21`, `20/21`, `21/21`, `8/17`) across both CLAUDE.md files, `TUTORIAL-KIND.md`, and the M01/M02 runbooks. The 4 parallel doc audits found 7 drift items; all fixed.
- M01 runbook source-mapping line number (177 → 190).

### Initial scaffolding (earlier)

- Repository scaffolding with 11 course directories and 33 module directories
- Shared demo apps structure (catalog-api, fleet-dashboard, telemetry-worker)
- Kustomize demo structure with base and overlays (production, staging)
- Reference research directory and K8S reference books directory
- README with skill path overview, lab setup, and exam resources
- CLAUDE.md for AI-assisted development context
- Standard repo metadata (CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, CHANGELOG)
- Course 1 outline (DOCX V4) and working slide decks for all 3 modules (in temp/)
