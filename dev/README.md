# dev/

Production assets used while recording the CKA v1.35 skill path. Runbooks, draft scripts, and recording-time helpers live here. Nothing in this folder ships to learners — the shipping lab code lives under [../src/cka-lab/](../src/cka-lab/).

## Final runbooks

On-camera scripts for Course 1. Each targets 12-14 minutes and drives the KIND tutorial flow from [../src/cka-lab/lib/tutorials.ps1](../src/cka-lab/lib/tutorials.ps1).

- [m01-demo-runbook.md](m01-demo-runbook.md) — Course 1 Module 1, ~13 min. Architecture and lab setup.
- [m02-demo-runbook.md](m02-demo-runbook.md) — Course 1 Module 2, ~13 min. kubectl workflows.
- [m03-demo-runbook.md](m03-demo-runbook.md) — Course 1 Module 3, ~14 min. Core resources and the diagnostic ladder.

Each runbook contains: pre-flight checks, camera checklist, on-camera open, click-path (Enter-press sequence), five timed demo sections mapped to tutorial section numbers, close narration, reset-between-takes notes, and a recovery cheat sheet.

### Source of truth

The runbooks are on-camera scripts only. The actual demo commands and narration live in [../src/cka-lab/lib/tutorials.ps1](../src/cka-lab/lib/tutorials.ps1). When a demo step changes, update `tutorials.ps1` first and let the runbook index reference the new section number.

### Multi-cluster lab

M02 Demo 5 uses [../src/cka-lab/kind-multi-up.ps1](../src/cka-lab/kind-multi-up.ps1) to spin up a second cluster for real context-switching practice. Everything else uses the standard [../src/cka-lab/kind-up.ps1](../src/cka-lab/kind-up.ps1).

## Historical drafts

The earlier March 29 drafts live in [archive/](archive/):

- `archive/CKA-C01-M01-Demo-Runbook.md`
- `archive/CKA-C01-M02-Demo-Runbook.md`
- `archive/CKA-C01-M03-Demo-Runbook.md`

Superseded by the final `mNN-demo-runbook.md` files above. Safe to delete once Course 1 ships; kept for reference until then.

## Placeholders

- [test-environments.ps1](test-environments.ps1) — empty file. Either a future test harness for verifying both lab paths (KIND + Hyper-V) before a recording session, or dead code. Remove or repurpose.
