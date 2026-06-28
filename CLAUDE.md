# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Tim Warner's **Certified Kubernetes Administrator (CKA) v1.35 Skill Path** for Pluralsight -- an 11-course video training series covering the February 2025 CKA curriculum revision. The repo holds exercise files, YAML manifests, lab configurations, shared demo applications, and a two-path lab environment that accompany the courses.

## Repository Structure

- `exercise-files/` -- All course content, organized as `course-NN-topic/mNN-module-name/`. **Every course folder and every module folder has a `README.md`** (navigation hub at the course level, file table + CKA objectives at the module level). Recorded courses (1, 2, 3) ship real learner resources; Courses 4-11 module READMEs carry a "coming as recorded" boilerplate until each is recorded. Course 3 is fully populated (etcd backup/restore scripts, kubeadm upgrade scripts, Helm/Kustomize/CRD demos) sourced from the shipped course folders. Manifests get written as each course is recorded.
- `exercise-files/shared/apps/` -- Reusable demo applications (catalog-api, fleet-dashboard, telemetry-worker) for the Globomantics storyline. Also placeholder folders today.
- `exercise-files/K8S/` -- Reference book directories (Bayfield, Muschko, Qin, Sachdeva, etc.). Tracked as `.gitkeep` stubs; PDFs are pulled in locally and not committed.
- `k8s-foundations-exercise-files.md` -- Pluralsight Course 1 download pointer. Lives at the repo root because Pluralsight's exercise-file download is a single Markdown file; this one points learners back to the GitHub repo for everything (manifests, lab scripts, runbooks). Treat as learner-facing copy: tone, badges, and link targets all matter.
- `src/cka-lab/` -- The lab environment (KIND console app + Hyper-V Vagrant lab). See `src/cka-lab/CLAUDE.md` for internal architecture.
- `cka-cert-buddy/` -- **Separate** GitHub Copilot agent workspace for CKA practice scenarios, labs, and study plans. Primary runtime is GitHub Copilot Chat, not Claude Code. Has its own `cka-cert-buddy/CLAUDE.md` with authoring rules. Do not duplicate the lab-runner code here.
- `dev/` -- Recording-only assets: per-module demo runbooks for Course 1 (`m01-`/`m02-`/`m03-demo-runbook.md`). `test-environments.ps1` is an empty placeholder. Nothing in `dev/` ships to learners.
- `reference/` -- **Gitignored.** Tim's local strategic reference: official CKA candidate handbook + curriculum PDFs/MD, LLM research outputs (`cka-research-{chatgpt,claude,gemini}.md`), `tim-proposed-skill-path.md`, working module decks. Read it for context, but do not author against it as if it were repo content.
- `temp/` -- **Gitignored.** Transient working files: course outlines (DOCX), slide decks (PPTX), in-flight research.

## Public-repo hygiene (HARD RULES)

This is a **public** repo at `timothywarner-org/ps-cka` (note: the org, not the personal `timothywarner` account -- all repo URLs use `timothywarner-org/ps-cka`).

- **No Pluralsight proprietary work product, ever.** Raw slide decks (`.pptx`/`.potx`/`.ppt`), course outlines (`.docx`/`.doc`), full slide-plus-speaker-notes markdown extracts, and internal audit/QA reports must never be committed. `.gitignore` blocks these file types and `.github/workflows/validate.yml` fails the build if any are tracked. Share **PDF exports** of decks if learners need a visual, never the source.
- **No Hyper-V/VM binaries.** `.vhd`/`.vhdx`/`.avhdx`/`.vmcx`/`.iso`/`.box` etc. are gitignored. Only the lab scripts, Vagrantfile, and configs that BUILD the lab belong here.
- **Canonical authoring hub:** `L:\Dropbox-2025\Dropbox\pluralsight\tim-warner (1)\CKA-Skill-Path\course-NN-*`. Shipped runbooks, decks, outlines, and demo scripts live there. When populating the repo, copy learner-facing assets (scripts, manifests, runbooks, diagrams) and leave decks/outlines/internal reports behind. **Authority = what was actually recorded** (verify against the demo runbook and the on-rails lab driver), not a later `demos.zip` repackaging.
- **When a new PPTX or proprietary file shows up:** purge it from the working tree AND from git history (`git filter-repo`), then force-push. A prior cleanup removed tracked decks/outlines and shrank `.git` from 6.8 GB to ~1.4 MB. The repo has forks, so treat any leaked file as already exposed.

## Markdown + CI

- `.markdownlint.json` is the house ruleset (adapted from `timothywarner-org/ai901`). MD013/MD041/MD060/MD036/MD040/MD028 are intentionally disabled for Tim's long-prose runbooks, centered-banner READMEs, and bare terminal-output code fences. Run `npx markdownlint-cli2 --fix "exercise-files/**/*.md"` before committing docs.
- `.github/workflows/validate.yml` runs markdownlint, the proprietary-file guard, an em-dash/curly-quote warning, and a markdown link check on every PR and push to `main`.
- Escape literal `|` as `\|` inside table cells (common in command examples) or markdownlint MD056 fails the build.

## Course Architecture

11 courses, 3 modules each (~25-30 min/module), ~15 hours total. Weighted to CKA exam domains:

| Domain | Weight | Primary Courses |
|--------|--------|-----------------|
| Troubleshooting | 30% | 9, 10 |
| Cluster Architecture/Install/Config | 25% | 1, 2, 3, 4 |
| Services & Networking | 20% | 7, 8 |
| Workloads & Scheduling | 15% | 5 |
| Storage | 10% | 6 |

Course 11 is the exam-prep capstone. Course 1 establishes the shared lab cluster and diagnostic ladder pattern used throughout.

## Two Lab Paths

Both paths live under `src/cka-lab/`. Pick based on the module scenario.

### Fast path -- KIND console app

PowerShell 7 interactive menus that spin up multi-node clusters as Docker containers on Windows/WSL2. Sub-30-second create, four topology choices in the `kind-up.ps1` menu (`Simple` 1+1, `Standard` 1+2 = CKA exam topology, `HA` 3+2, `Workloads` 1+3), four guided tutorials dot-sourced from `lib/tutorials.ps1`. Entry points: `kind-up.ps1`, `kind-down.ps1`, `Start-Tutorial.ps1`. Status probes (read-only, CI-safe): `kind-status.ps1` (universal), `kind-multi-status.ps1` (cka-dev/cka-prod pair), `cka-status.ps1` (Hyper-V VMs). Used for the vast majority of demos across all 11 courses.

- Learner walkthrough: `src/cka-lab/TUTORIAL-KIND.md`
- Internal architecture: `src/cka-lab/CLAUDE.md`

### Multi-cluster add-on -- kubectl context practice

Layered on top of the KIND path for the Course 1, Module 2 context drills. Brings up TWO clusters side by side so learners can practice `kubectl config use-context`, `--context`, `rename-context`, and `set-context --current --namespace`.

- `kind-multi-up.ps1` -- creates `cka-dev` (1 CP + 1 worker, host ports 30100/30180) and `cka-prod` (1 CP + 2 workers, host ports 30200/30280)
- `kind-multi-down.ps1` -- teardown; `-ClearRenamed` also removes the `dev` / `prod` renamed contexts
- `Start-ContextPractice.ps1` -- 8-drill interactive walkthrough
- Configs: `src/cka-lab/configs/cka-dev.yaml`, `src/cka-lab/configs/cka-prod.yaml`
- All three scripts carry `#!/usr/bin/env pwsh` shebangs, so `./kind-multi-up.ps1` works from bash in WSL2 -- not only `pwsh ./kind-multi-up.ps1`

### Exam-shaped path -- Hyper-V Vagrant lab

Three Ubuntu 22.04 VMs (`control1`, `worker1`, `worker2`) with 2 GB / 2 vCPU each, kubeadm v1.35 prereqs pre-installed, static IPs on the `CKA-NAT` Hyper-V switch (`192.168.50.0/24`). Stops before `kubeadm init` so the learner bootstraps the cluster from scratch. Native Hyper-V checkpoints provide the snapshot/restore practice loop. Used primarily for Course 2 (kubeadm install) and any scenario that needs real systemd, a real package manager, or node-level break/fix drills.

- Learner walkthrough: `src/cka-lab/TUTORIAL-HYPERV.md`
- Reliability features: atomic snapshot/restore, self-sufficient `join_worker.sh`, pinned Flannel + kubeadm versions, NodePort preflight, tutorial cleanup on Ctrl-C.

Target Kubernetes version for both paths: **v1.35** (exam-aligned).

**Course 3 lab controls (renamed, plain-English).** Course 3 records off the Hyper-V Vagrant lab using clearly-named copies in `src/cka-lab/course-03-lifecycle-upgrades/` -- `Start-CkaLab`, `Stop-CkaLab`, `Save-CkaSnapshot`, `Restore-CkaSnapshot`, `Get-CkaLabStatus`, `Get-CkaConnectionInfo`, `Test-CkaLabReady`. They drive the **same** VMs (`VAGRANT_CWD` -> parent `src/cka-lab`); the generic `cka-*.ps1` stay as the shared engine. Node names are **`control1` / `worker1` / `worker2`**, single-sourced in `lib/CkaLab.ps1` (`Get-CkaLabVMs`/`Get-CkaLabNodes`). The Vagrantfile K8s version is parameterized via `$env:CKA_K8S_MINOR` (default `1.35`) so M02 can start at v1.34 and upgrade on camera. Map + workflow: `src/cka-lab/course-03-lifecycle-upgrades/README.md`.

## Key Conventions

- **Globomantics storyline**: All demos follow a fictional company migrating to Kubernetes. Maintain this narrative when creating exercise content.
- **Diagnostic ladder pattern**: `get > describe > logs > events` -- introduced in Course 1, Module 3, and reinforced in every subsequent course.
- **Imperative-first demos**: Use `kubectl run`, `kubectl create`, `kubectl expose` with `--dry-run=client -o yaml` pipeline for exam speed. Write YAML only when imperative shortcuts don't exist.
- **Standard test target** (per `CONTRIBUTING.md`): manifests must work on a default kind cluster (1 CP + 2 workers) at Kubernetes v1.35.
- **Course outline format**: DOCX following the Pluralsight author template.
- **Slide decks**: PPTX built from the Pluralsight 2026.03.a brand template.
- **On-rails tutorials cap at 10 sections**: every interactive tutorial in `src/cka-lab/lib/tutorials.ps1` (Module functions `Start-TutorialM0X`) is sized for on-camera pacing — 10 sections max, every section carries `-CommandBreakdown` and (where output is shown) `-OutputFields`. Bar is exam-relevance × pacing, not comprehensive coverage. Drop or merge to fit; the demo runbook in `dev/` must match the section numbers exactly. Never let a tutorial drift past 10.
- **Sections may contain multiple beats**: 10 SECTIONS is still the hard cap, but a section may split into 2-3 BEATS via the `-Steps` array on `Write-TutorialSection` when teaching a cause/effect arc that needs an Enter press between cause and effect (e.g. delete pod -> watch ReplicaSet resurrect; scale Deployment -> watch EndpointSlice grow). M03 uses this on sections 1, 2, 3, 5, 9, 10 (14 multi-beats across those six sections; sections 4, 6, 7, 8 stay single-command). Render rule the helper enforces: an Enter press belongs in front of a teaching output, never in front of setup or `Start-Sleep`. Setup beats may carry an empty `OutputFields` so the "What you just saw" block is skipped — the next beat's output IS the lesson.
- **Tutorial breathing-room render**: `Write-TutorialBeatBody` frames every block (beat header, command line, breakdown, command output, output-fields, terminator dashes) with blank-line padding so the on-camera frame doesn't crowd. Yellow Command line + Wong sky-blue command output = instant cause/effect contrast. If you add or edit a tutorial, render through the helper -- do not bypass it with raw Write-Output blocks or the breathing-room rhythm desyncs.

## Working with Exercise Files

Exercise files are Kubernetes YAML manifests, shell scripts, and kind/Vagrant configs. When creating new exercise files:

1. Place them in the correct `course-NN/mNN-module/` directory.
2. Use descriptive filenames matching the demo scenario (e.g., `broken-deployment.yaml`, `networkpolicy-deny-all.yaml`).
3. Include comments linking to CKA exam objectives where relevant.
4. Ensure manifests work on both lab paths with Kubernetes v1.35.

## Per-Module Demo Runbooks

Recording runbooks for Course 1 (Foundations) live in `dev/`. Each has pre-flight, camera checklist, exact Enter-press click path, timed demos mapped to section numbers in `src/cka-lab/lib/tutorials.ps1`, reset-between-takes, and a recovery cheat sheet.

- `dev/m01-demo-runbook.md` -- Architecture & Lab Setup (~12-13 min)
- `dev/m02-demo-runbook.md` -- kubectl Workflows (~10-12 min; section 5/10 is the scripted `kubectl apply -f` round-trip + `get all` "all is a lie" callout; multi-cluster intentionally NOT in this module)
- `dev/m03-demo-runbook.md` -- Core Resources & Diagnostic Ladder (~16-18 min; sections 1, 2, 3, 5, 9, 10 are multi-beat via `-Steps` -- the runbook click path enumerates each beat's Enter press; the diagnostic ladder anchors the module: rung 1 GET (status), rung 2 DESCRIBE (events), rung 3 LOGS (with `--previous` for CrashLoopBackOff), rung 4 EVENTS (timeline); section 10/10 covers multi-cluster context switching with a graceful skip if `cka-dev`/`cka-prod` aren't up; uses EndpointSlices not legacy Endpoints)

Older drafts under `dev/archive/` are superseded -- kept around, not authoritative.

## February 2025 Curriculum Additions (High Priority)

These topics are new to the CKA exam and represent the primary differentiator of this skill path:

- Gateway API (GatewayClass, Gateway, HTTPRoute) -- Course 7
- Helm and Kustomize for cluster components -- Course 3
- CRDs and operators -- Course 3
- Workload autoscaling (HPA/VPA) -- Course 5
- Ephemeral containers / kubectl debug -- Course 10
- Native sidecar containers (initContainers with restartPolicy: Always) -- Course 10
- Extension interfaces: CNI, CSI, CRI -- Course 1
