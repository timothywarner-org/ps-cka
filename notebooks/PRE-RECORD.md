# Pre-Record Checklist (run before every take)

The notebook only works on camera if the lab state and the JupyterLab UI are both clean. Walk this list top-to-bottom every single take. No skipping.

## State reset

- [ ] `cd 'L:\Dropbox-2025\Dropbox\pluralsight\tim-warner (1)\CKA-Skill-Path\course-02-kubeadm-cluster-install\notebooks'`
- [ ] `.\clear-outputs.ps1` — strips stale rehearsal outputs from every .ipynb
- [ ] `cd C:\github\ps-cka\src\cka-lab`
- [ ] Module-specific snapshot restore:
    - **m01:** `.\cka-up.ps1` (or `.\cka-restore.ps1 fresh-vms` if recordings have polluted state)
    - **m02:** `.\cka-restore.ps1 post-prereqs`
    - **m03:** `.\cka-restore.ps1 post-init-join`
- [ ] `.\cka-validate.ps1` — must end with `ALL NODES READY`

## JupyterLab UI

- [ ] Launch JupyterLab via `notebooks\launch.ps1`
- [ ] **View → Simple Interface** (hides left sidebar, file browser, etc.)
- [ ] Open the module's notebook (e.g., `c02-m01-host-prep.ipynb`)
- [ ] Confirm kernel shows `.NET (PowerShell)` in the top-right
- [ ] Browser zoom set to **125%** for screen recording
- [ ] Notifications muted (Windows Focus Assist on, Slack DND, Teams Do Not Disturb)
- [ ] Recording overlay (OBS / Camtasia) closed or minimized so it isn't visible

## Camera safety net

- [ ] Take a `pre-record` snapshot AFTER all of the above passes:
    ```powershell
    cd C:\github\ps-cka\src\cka-lab
    .\cka-snapshot.ps1 pre-record
    ```
- [ ] If anything goes sideways mid-take, `.\cka-restore.ps1 pre-record` rewinds in 60-90 sec.

## During the take

- **Destructive cells show a red left border.** Pause before clicking Run. Verify you're on the right snapshot.
- **Never re-run a destructive cell** without a snapshot restore first. `kubeadm init` twice in a row corrupts the cluster.
- **Expected-output blocks (grey quoted)** are markdown — they don't execute. They're there for you to compare against the actual cell output.

## After the take

- [ ] Stop recording
- [ ] If the take is a keeper: snapshot the end state as `post-<module>` for the next module's starting point
- [ ] `.\clear-outputs.ps1` again so the notebook is clean for the next rehearsal or take
