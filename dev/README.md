# dev/

Production assets used while recording the CKA v1.35 skill path. Nothing in this folder ships to learners — the shipping lab code lives under [../src/cka-lab/](../src/cka-lab/).

## Runbooks

On-camera scripts for Course 1, each targeting 12-14 minutes.

- [m01-demo-runbook.md](m01-demo-runbook.md) — Course 1 Module 1, 12-13 min. Architecture and lab setup.
- [m03-demo-runbook.md](m03-demo-runbook.md) — Course 1 Module 3, 16-18 min. Core resources and the diagnostic ladder.

There is no `m02-demo-runbook.md`. Earlier versions of this file and the root `CLAUDE.md` listed one; it has never existed on disk.

Each runbook contains: pre-flight checks, camera checklist, on-camera open, click-path (Enter-press sequence), timed demo sections, close narration, reset-between-takes notes, and a recovery cheat sheet.

> **Read these as a historical record, not as runnable instructions.** They drive the KIND-on-Docker tutorial flow (`kind-up.ps1`, `Start-Tutorial.ps1`, `lib/tutorials.ps1`), which was removed from the repo in `b9f37a6`. The commands and narration they describe were what Course 1 actually recorded, so the files are worth keeping — but the scripts they invoke are gone, and Courses 2 through 4 were recorded against the Hyper-V Vagrant lab instead.

## Historical drafts

Earlier drafts live in [archive/](archive/):

- [archive/CKA-C01-M01-Demo-Runbook.md](archive/CKA-C01-M01-Demo-Runbook.md)
- [archive/CKA-C01-M03-Demo-Runbook.md](archive/CKA-C01-M03-Demo-Runbook.md)

Superseded by the `mNN-demo-runbook.md` files above. Kept for reference.

`archive/` also holds untracked, gitignored working files: superseded Course 4 drafts and one-shot helper scripts (`_*.ps1`). Those are local-only and never published.
