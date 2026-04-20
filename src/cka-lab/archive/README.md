# Archive

Stale scripts preserved for reference. The canonical scripts live in the repo root.

## Bash (`kind-up.sh`, `kind-down.sh`)

Stale Bash versions of the KIND entry points. Missing features added to the PS1 scripts (4-topology menu, ShowKubeadm, Tutorial mode, HA topology, workloads labels/taints). Do not use without updating first.

## `snapshot.ps1` (legacy Vagrant checkpoint wrapper)

Original multi-action snapshot wrapper (`save | restore | list | delete`). Superseded by the split pair `cka-snapshot.ps1` / `cka-restore.ps1` in the repo root, which have atomic pre-flight checks and clearer on-camera semantics. Kept here for history — do not run on camera.
