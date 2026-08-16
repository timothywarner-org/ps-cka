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

**Lab controls (plain-English, Verb-Noun).** The Hyper-V Vagrant lab is driven by clearly-named scripts flat at `src/cka-lab/` -- `Start-CkaLab`, `Stop-CkaLab`, `Save-CkaSnapshot`, `Restore-CkaSnapshot`, `Get-CkaLabStatus`, `Get-CkaConnectionInfo`, `Test-CkaLabReady`, plus Course-3-specific `Build-M02UpgradeLab`, `Invoke-M02Upgrade`, `Invoke-M03Lab`, `Invoke-KubeletFlagRepair`. Node names are **`control1` / `worker1` / `worker2`**, single-sourced in `lib/CkaLab.ps1` (`Get-CkaLabVMs`/`Get-CkaLabNodes`). The Vagrantfile K8s version is parameterized via `$env:CKA_K8S_MINOR` (default `1.35`) so M02 can start at v1.34 and upgrade on camera. Recording workflow: `src/cka-lab/RECORDING-WORKFLOW.md`.

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

---

## Working agreement with Tim — read this FIRST, every session

Locked 2026-08-16 at Tim's instruction. This overrides convenience and overrides
politeness. It does not override the voice rules in `cka-course-builder`.

### 1. Presuppose the question "is Claude hallucinating?" and answer it unasked

Tim's default and correct posture is skepticism. Do not wait to be challenged.
Every substantive deliverable ends with a **verification ledger**: what is
PROVEN, by what specific evidence, and what is UNVERIFIED. Name the unverified
items yourself, ranked by risk. An unprompted "I have not run this" buys more
trust than three paragraphs of confident prose.

### 2. An assertion about your own work proves nothing

"I checked" is not evidence. Evidence is: a command that ran and its output, a
verbatim source quote, a validator exit code, a parse result. If you cannot
produce one, the claim is UNVERIFIED and must be labeled that way in the
deliverable itself, not just in chat.

### 3. Quote the source; never trust a paraphrase on a load-bearing claim

Real incident, C04 M01: a summarizing pass reported "configmaps are not in the
`view` ClusterRole." Demo 3 used `kubectl get configmaps` as its central proof.
Forcing a verbatim quote of `viewRules()` in
`plugin/pkg/auth/authorizer/rbac/bootstrappolicy/policy.go` showed configmaps
IS present and the summary was wrong. Had it shipped, the demo would have
thrown a 403 on camera. **For any fact a demo depends on, fetch the defining
source and demand the exact line.** For Kubernetes RBAC defaults that file is
the source of truth, not the docs prose and not memory.

### 4. Read Tim's actual shipped artifacts before authoring in his format

Do not author from a skill template when real examples exist in this repo. The
published runbook standard lives in
`exercise-files/course-NN-*/mNN-*/cNN-mNN-demo-runbook.md` (C02 M01/M03, C03
M01). Read one end to end first. Note: the `cka-course-builder` skill's
`validate_runbook.py` FAILS Tim's own published `c02-m01` runbook — it expects
"Beat N" and "## Sources" while the real corpus uses "Demo N" and
"## Source mapping". The corpus wins. Validators encode assumptions; a failure
may be the validator's defect, and you must check which.

### 5. One folder per module. Do not scatter.

Everything for a module goes in its `exercise-files/course-NN-*/mNN-*/` folder:
runbook, scripts, manifests, START-HERE. The only permitted exception is code
with a hard technical dependency on another location — e.g. lab scripts that
dot-source `src/cka-lab/lib/CkaLab.ps1` or need to sit beside the `Vagrantfile`.
When you place a file outside the module folder, say why in one line.

### 6. Few scripts, subcommands not files

Tim runs these live while recording. Prefer ONE script with subcommands
(`./lab.sh reset|mint|verify`, bare invocation = the sensible default) over four
single-purpose scripts. Setup and reset must never be "a bunch of commands."

### 7. Idempotent by construction, and verified so

Every script re-runnable any number of times. Deletes use `--ignore-not-found`.
Anything that consumes a one-shot object (a CSR cannot be re-approved) clears it
before recreating. Scripts VERIFY their end state rather than assuming it, and a
dry-run harness must fail on an unexpected **success** — a stale grant that
silently still works is more dangerous than a visible error.

### 8. Runtime budgets include command execution, not just talking

A talk-track word count understates a demo. Count the ENTERs too (~1.5s each of
output and dead air). Report speech time, execution time, and the total, and
supply a ranked trim ladder plus an explicit do-not-cut list.

### 9. Course 4 standing convention — show and switch context every demo

Every demo opens with `kubectl config get-contexts` or `current-context`. The
opening line is non-negotiable at any runtime: the exam runs six clusters and
every task begins with a `use-context`. Mid-demo switches are negotiable; the
opening line is not.

### 10. Deck wins, then fix the other assets

When the deck and an outline/script/runbook disagree, the recorded deck is the
contract (see `Recording-Readiness-Report.md`). Fix the other asset, flag the
change in one line, and never silently edit a deck to match an outline.

### 11. Environment constraints to state plainly, not work around

- Hyper-V and Vagrant require an **elevated** shell. Remote sessions here are
  NOT elevated, so lab boot is always Tim's action. Say so; do not pretend.
- This authoring sandbox blocks container registries and `dl.k8s.io`, so no
  substitute cluster can be built to test against. When Tim's VMs are off,
  execution against Kubernetes is impossible — report that instead of implying
  verification happened.
- Files pushed to a node with `cat >` land 0644. `chmod +x` any `.sh`, then
  verify the bit, or `./script.sh` fails on camera.

### 12. Lab facts — established by past work, do not re-derive or guess

Set in Course 2 and used ever since. Confirmed 2026-08-16 by counting the
shipped exercise files: 14 `calico-node`, 9 `tigera-operator`, 7 `calico-system`,
**zero** `kube-flannel`.

- **Nodes:** control1 / worker1 / worker2 at `192.168.50.10` / `.11` / `.12`,
  Ubuntu 22.04, Kubernetes **v1.35**, containerd.
- **CNI: Calico**, installed via the **Tigera operator**, manifests pinned to
  **v3.29.1** (`tigera-operator.yaml` then `custom-resources.yaml`). Namespaces
  `tigera-operator` and `calico-system`; DaemonSet `calico-system/calico-node`.
- **Pod CIDR `192.168.0.0/16`**, Service CIDR `10.96.0.0/12`. The pod CIDR is
  load-bearing: Calico's default Installation CR ships `192.168.0.0/16`, and
  `c02-m03-demo-runbook.md` Step 1.0 proves the alignment **on camera**. Any
  other value silently contradicts a recorded module.
- **kubeadm init is declarative** in this course — `kubeadm config print
  init-defaults > init.yaml`, edit, `kubeadm init --config init.yaml` (C02 M02).
- **Known gotcha:** a Hyper-V checkpoint restore invalidates Calico's CNI token;
  nodes sit NotReady until `kubectl -n calico-system rollout restart
  ds/calico-node`. Every bring-up script must heal this before running workloads.
- **`src/cka-lab/bootstrap_cp.sh` is STALE** — it installs Flannel v0.24.4 on
  `10.244.0.0/16`, a Course 1 leftover. Do not call it. `Initialize-C04M01Lab.ps1`
  deliberately does not.

**The rule this encodes:** when an environment detail is already settled by
recorded work, go read the recorded work. Counting references across
`exercise-files/` takes one grep and beats any assumption. If the repo
contradicts itself, the artifact that was RECORDED wins, and the loser gets
flagged as stale rather than quietly accommodated.

### 13. Bug classes this repo has actually shipped — check these every time

Found 2026-08-16 by a five-lens adversarial audit of C04 M01, each finding then
handed to a skeptic told to refute it. 15 of 16 survived. These are not
hypotheticals; they were all live in code that had already passed `bash -n`,
a PowerShell parse, and a careful human read.

**The assertion that cannot fail.** `kubectl delete pod --all` in an EMPTY
namespace lists (allowed), finds nothing, deletes nothing, and exits **0** —
authorization for `delete` is never consulted, so the expected 403 never
appears. Any "prove this is denied" step must use an operation that reaches the
API server unconditionally: a NAMED delete, or a create. Bonus: the API server
authorizes *before* it looks for the object, so deleting a nonexistent named
Pod returns **403, not 404** — a better teaching beat than the broken original.

**Half-assertions.** If a harness only asserts the DENY cases, an expected-ALLOW
step that starts failing produces a green run. Always assert both directions.
The catastrophic outcome is never a visible error; it is a false green.

**Nonzero is not a reason.** Treating any nonzero exit as "denied as expected"
silently accepts a missing binary, a refused connection, and a 401 from an
expired credential. Match the actual expected signal in the output.

**Negative assertions over a failing command.** "Output must NOT contain X" is
trivially true when the command errors and prints nothing. `grep` exits 1 when
it finds nothing, which is indistinguishable from total failure. Prefer a
command that exits 0 and prints the full set (`-o jsonpath=...`), and require
exit 0 before believing any negative result.

**kubectl `--wait` without `--timeout` is 168 HOURS** (`pkg/cmd/delete/delete.go`
substitutes 168h when Timeout is 0). Always pass `--timeout`.

**`$OutputEncoding = [System.Text.Encoding]::UTF8` emits a BOM.** Every file
piped to a Linux node with `cat >` lands with EF BB BF before byte 0, so a
shebang stops being a shebang and `./script.sh` dies with a bad-interpreter
error that points nowhere. Use `[System.Text.UTF8Encoding]::new($false)` for the
copy, then verify remotely that byte 0 is `#`.

**`\"` inside a double-quoted PowerShell string does not escape a quote — it
ENDS the string.** Arguments then split silently and reach the remote shell
malformed. Use single-quoted here-strings for anything containing shell quoting.

**Substring `-match` for a version check** passes a mixed-version cluster,
because the expected string appears somewhere in the blob. Require exactly one
distinct value across nodes.

**`rm -rf <dir>` during staging** yanks the cwd out from under any SSH session
already sitting in it. Clear contents, keep the directory.

**Pipelines eat exit codes.** `./script.sh | tee log` reports TEE's status. A
script whose exit code is a go/no-go signal must self-log (process substitution)
rather than being documented behind a pipe.

**`Push-Location` with no `finally`** leaves the caller's stack dirty on any
terminating error.

### 14. Run the adversarial audit before calling demo code done

Five lenses, in parallel, over the same files: shell correctness, PowerShell
correctness, domain semantics (does the command do what the narration CLAIMS),
cross-asset coherence (script vs runbook vs index), and idempotency/false-green
hunting. Then hand every finding to a separate skeptic instructed to REFUTE it
and to default to refuted when uncertain. Survivors only.

This is not optional polish. On the C04 M01 pass it caught a bug that would have
been discovered ON CAMERA, mid-take, in the module's most important beat — and
no amount of syntax checking or careful reading had found it across several
review rounds.
