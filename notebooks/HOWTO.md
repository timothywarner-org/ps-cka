# HOWTO — CKA Course 2 Recording Notebooks

The TL;DR for future-you. Three notebooks, one kernel, one launcher.

## What this is

Three JupyterLab notebooks (one per Course 2 module) that **mirror** the markdown runbooks in `../mXX-*/c02-mXX-demo-runbook.md`. Notebooks are **generated**, not hand-edited. Edit the markdown, regenerate the notebook.

**Kernel:** `.NET Interactive` PowerShell. Every code cell is real `pwsh` 7. `vagrant`, `cka-*.ps1`, `ssh control1 …` all work as you'd type them. No WSL2, no bash kernel, no shellouts.

**Audience:** you on camera. Click "Run," output appears inline, narrate over it.

## First-time setup (already done on this box, here for the next workstation)

```powershell
# 1. .NET SDK 8+ — already installed (dotnet --version → 10.0.x)
# 2. PowerShell kernel
dotnet tool install -g Microsoft.dotnet-interactive
dotnet interactive jupyter install

# 3. Verify
jupyter kernelspec list           # must include .net-powershell

# 4. Project deps (venv lives OUTSIDE the repo)
cd notebooks
$env:UV_PROJECT_ENVIRONMENT = "$HOME\.venvs\cka-c02"
uv sync
```

## Daily workflow

```powershell
cd notebooks

# Regenerate notebooks after any runbook edit (idempotent — safe to re-run)
uv run python tools\runbook_to_ipynb.py ..\m01-linux-host-prep\c02-m01-demo-runbook.md
uv run python tools\runbook_to_ipynb.py ..\m02-kubeadm-init-join\c02-m02-demo-runbook.md
uv run python tools\runbook_to_ipynb.py ..\m03-cni-cluster-validation\c02-m03-demo-runbook.md

# Launch (opens browser to JupyterLab)
.\launch.ps1

# Before every take: strip stale rehearsal output
.\clear-outputs.ps1
```

## On-camera rules

| Cell border | Tag | What to do |
|---|---|---|
| **Red** | `destructive` | Verify your snapshot before clicking Run. `kubeadm init`, `kubeadm join`, `cka-restore` live here. |
| **Yellow** | `interactive` | DO NOT click Run. Switch to your VM terminal (vim, vagrant ssh, kubectl edit). The notebook cell is a visual marker, not the executor. |
| **Blue (left edge)** | `pre-flight` | Pre-recording checks. Run these before hitting record. |
| **None** | normal | Click Run on camera. |

Always: **View → Simple Interface** in JupyterLab. Hides the sidebar/toolbar so they don't show in the recording.

## Pre-record ritual

See `PRE-RECORD.md`. Short version:

1. `.\clear-outputs.ps1`
2. `cd C:\github\ps-cka\src\cka-lab` → `.\cka-restore.ps1 <module-snapshot>` (m01→`fresh-vms`, m02→`post-prereqs`, m03→`post-init-join`)
3. `.\cka-validate.ps1` must say `ALL NODES READY`
4. JupyterLab Simple Mode, 125% browser zoom, notifications off
5. Take a `pre-record` snapshot

## How the parser works

`tools/runbook_to_ipynb.py` walks the runbook markdown:

- **H1** → notebook title
- **`## Demo N` / `## Pre-flight`** → section markdown cell with tag (`demo-N`, `pre-flight`)
- **`### Step N.N`** → markdown header cell + (if there's a fenced code block) one code cell
- **` ```powershell ` blocks** → pwsh cell, raw
- **` ```bash ` blocks** → pwsh cell wrapped as `ssh <host> @'...'@`. Host inferred from nearest heading (worker1 / worker2 / all-nodes / default control1)
- **` ```yaml ` blocks** → here-string written to `$env:TEMP\<name>.yaml` then `scp` to control1
- **` ```text ` blocks** → markdown cell as expected-output (grey quoted block, not executed)
- **Destructive regex** (`kubeadm init|join|reset`, `vagrant destroy`, `cka-restore`, `etcdctl snapshot restore`, `rm -rf`) → adds `destructive` tag
- **Interactive regex** (`vim`, `nano`, `vagrant ssh`, `kubectl edit/exec/attach/port-forward`, `less`, `top`, `watch`) → adds `interactive` tag

Notebooks are **byte-stable** on re-run. Two runs = identical SHA256.

## When things break

| Symptom | Fix |
|---|---|
| `uv sync` creates `.venv\` beside pyproject.toml | You forgot `$env:UV_PROJECT_ENVIRONMENT = "$HOME\.venvs\cka-c02"`. Delete `.venv\` and re-set the var. |
| JupyterLab won't start | `jupyter kernelspec list` — if `.net-powershell` is missing, re-run `dotnet interactive jupyter install` |
| Cell hangs forever | You probably clicked Run on a yellow `interactive` cell. Use the Kernel menu → Interrupt. Switch to your VM terminal for that step. |
| Cells run but output is stale | You forgot `.\clear-outputs.ps1` before the take. Stop, clear, restart. |
| Notebook changed and you didn't edit it | Someone regenerated it. Diff against the runbook — the runbook is source of truth. |

## What this DOES NOT do

- Run cells against the actual VMs (you do that on camera)
- Validate `kubeadm` exit codes
- Replace your `cka-validate.ps1` cross-node check
- Course 1 or Course 3 (deferred — prove m01 on camera first)

## Files at a glance

```
notebooks/
├── HOWTO.md                                  ← this file
├── PRE-RECORD.md                             ← per-take checklist
├── README.md                                 ← full README
├── pyproject.toml + uv.lock                  ← parser deps only
├── .gitignore
├── launch.ps1                                ← one-button JupyterLab
├── clear-outputs.ps1                         ← strip outputs before take
├── assets/recording.css                      ← Simple Mode CSS + tag styling
├── tools/
│   ├── runbook_to_ipynb.py                   ← THE parser
│   └── smoke-kernel.py                       ← prove the kernel works
├── c02-m01-linux-host-prep.ipynb             ← generated
├── c02-m02-kubeadm-init-join.ipynb           ← generated
└── c02-m03-cni-cluster-validation.ipynb      ← generated
```

## The one decision to make

After your first camera-off rehearsal of m01: does click-to-run on camera work, or does losing the "type every command" pedagogy feel wrong?

- **Works:** replicate the pattern to Course 1 and Course 3
- **Doesn't:** kill the experiment; runbooks stay authoritative; total cost was ~one sprint
