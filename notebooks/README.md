# CKA Course 2 — Recording Notebooks

JupyterLab notebooks for **on-camera recording** of the three Course 2 demo modules. Each notebook is generated from the authoritative markdown runbook in the sibling `mXX-*` folders. **Edit the runbook, regenerate the notebook.** Notebooks are derived artifacts.

## Architecture

- **Kernel:** `.NET Interactive` PowerShell kernel (`.net-powershell`). Every code cell is real `pwsh` 7. `vagrant`, `.\cka-restore.ps1`, `ssh control1 kubectl get nodes` all work natively.
- **Host:** native Windows 11 pwsh 7 in Windows Terminal. No WSL2, no bash kernel.
- **Source of truth:** `../mXX-*/c02-mXX-demo-runbook.md`. The parser at `tools/runbook_to_ipynb.py` walks the markdown and emits a notebook.
- **Lab:** the existing `C:\github\ps-cka\src\cka-lab` Vagrant + Hyper-V environment. Unchanged.

## One-time bootstrap (Windows pwsh 7)

```powershell
# 1) .NET SDK 8.0+
dotnet --version
# Install if missing: winget install Microsoft.DotNet.SDK.8

# 2) .NET Interactive PowerShell kernel
dotnet tool install -g Microsoft.dotnet-interactive
dotnet interactive jupyter install

# 3) Verify kernel registration
jupyter kernelspec list   # must show .net-powershell

# 4) uv (for the parser)
uv --version              # install via winget if missing

# 5) Project deps — venv lives OUTSIDE Dropbox to avoid sync hell
cd 'L:\Dropbox-2025\Dropbox\pluralsight\tim-warner (1)\CKA-Skill-Path\course-02-kubeadm-cluster-install\notebooks'
$env:UV_PROJECT_ENVIRONMENT = "$HOME\.venvs\cka-c02"
uv sync
```

> **`UV_PROJECT_ENVIRONMENT` matters.** Without it, uv creates `.venv/` next to `pyproject.toml` — which is in Dropbox — and you get ~5000 sync events every time deps resolve. `launch.ps1` and `clear-outputs.ps1` set this var automatically; only direct `uv ...` invocations need it.

## Daily workflow

```powershell
cd 'L:\Dropbox-2025\Dropbox\pluralsight\tim-warner (1)\CKA-Skill-Path\course-02-kubeadm-cluster-install\notebooks'

# Regenerate notebooks from the latest runbook content (idempotent)
uv run python tools\runbook_to_ipynb.py ..\m01-linux-host-prep\c02-m01-demo-runbook.md
uv run python tools\runbook_to_ipynb.py ..\m02-kubeadm-init-join\c02-m02-demo-runbook.md
uv run python tools\runbook_to_ipynb.py ..\m03-cni-cluster-validation\c02-m03-demo-runbook.md

# Launch JupyterLab (Simple Mode for recording)
.\launch.ps1
```

## Pre-record ritual

Before every take, see **`PRE-RECORD.md`**. The short version:

1. `.\clear-outputs.ps1`
2. `..\..\src\cka-lab\cka-restore.ps1 <module-starting-snapshot>`
3. `..\..\src\cka-lab\cka-validate.ps1` returns `ALL NODES READY`
4. JupyterLab → View → Simple Interface
5. Browser zoom 125%
6. Snapshot to `pre-record`

## Files

| File | Role |
|---|---|
| `pyproject.toml` | uv project for the parser (markdown-it-py, nbformat, jupyterlab) |
| `tools/runbook_to_ipynb.py` | Markdown → .ipynb converter |
| `launch.ps1` | One-button JupyterLab launcher (Simple Mode + custom CSS) |
| `clear-outputs.ps1` | `jupyter nbconvert --clear-output --inplace *.ipynb` |
| `assets/recording.css` | Hides JupyterLab chrome and highlights destructive cells |
| `PRE-RECORD.md` | On-camera pre-flight checklist |
| `c02-m01-host-prep.ipynb` | Generated from m01 runbook |
| `c02-m02-kubeadm-init-join.ipynb` | Generated from m02 runbook |
| `c02-m03-cni-validation.ipynb` | Generated from m03 runbook |

## Cell tags

The parser auto-tags cells. JupyterLab shows these in the cell metadata panel; `assets/recording.css` styles them.

| Tag | Meaning | Visual |
|---|---|---|
| `pre-flight` | Cells inside the "Pre-flight" section | (none) |
| `demo-N` | Cells inside the matching `## Demo N` block | (none) |
| `destructive` | Cell modifies cluster state irreversibly | red left border |
| `expected-output` | Markdown cell showing expected terminal output | grey quoted block |

## Voice lint (run before commit)

Same regex pattern as `claude-architect/notebooks/`. Borrowed verbatim:

```powershell
$bad = '—|AWS|\b(an|the|big) ask\b'
Get-ChildItem *.ipynb | ForEach-Object {
  $hits = Select-String -Path $_.FullName -Pattern $bad
  if ($hits) { Write-Host "VOICE LINT FAIL: $($_.Name)"; $hits }
}
```

Must return zero hits.
