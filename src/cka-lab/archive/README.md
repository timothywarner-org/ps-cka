# Archive

Stale scripts preserved for reference. The canonical scripts live in the repo root.

## `snapshot.ps1` (legacy Vagrant checkpoint wrapper)

Original multi-action snapshot wrapper (`save | restore | list | delete`). Superseded by four single-purpose scripts at `src/cka-lab/`, one per verb: `Save-CkaSnapshot.ps1`, `Restore-CkaSnapshot.ps1`, `Get-CkaSnapshot.ps1`, and `Remove-CkaSnapshot.ps1`. They have atomic pre-flight checks and clearer on-camera semantics. Kept here for history — do not run on camera.
