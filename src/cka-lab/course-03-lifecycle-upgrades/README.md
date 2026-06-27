# Course 3 -- Cluster Lifecycle & Upgrades -- Lab Controls

These are your **Course 3 lab controls**: the same Hyper-V Vagrant lab as always
(3 VMs -- **control1**, **worker1**, **worker2**), with **plain-English script names**
so you always know which one to run.

> **The lab itself lives one level up** (`..\` = `src\cka-lab` -- the Vagrantfile,
> the `lib\` folder, and your existing VMs). The scripts in here drive **those same
> VMs**. They do **not** create a second cluster, and they do **not** touch your
> working setup -- they just wrap it with clearer names.

## How to run

Open an **Administrator PowerShell 7** window, then:

```powershell
cd C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
.\Start-CkaLab.ps1
```

Every script has full help: `Get-Help .\Start-CkaLab.ps1 -Full`.
The snapshot pair supports `-WhatIf` (safe dry run that changes nothing).

## Which script does what

| Run this | What it does | (was) |
|---|---|---|
| **Start-CkaLab.ps1** | Boot the 3 VMs (no re-provision), then show how to connect | cka-up.ps1 |
| **Build-M02UpgradeLab.ps1** | Rebuild the 3 VMs clean at **v1.34** and auto-snapshot `m02-pre-upgrade` (for the M02 upgrade demo) | (new) |
| **Stop-CkaLab.ps1** | Gracefully halt the 3 VMs (end of session) | cka-down.ps1 |
| **Save-CkaSnapshot.ps1** `<name>` | Checkpoint all 3 VMs -- your "save point" before a take | cka-snapshot.ps1 |
| **Restore-CkaSnapshot.ps1** `<name>` | Rewind all 3 VMs to a checkpoint -- the "re-record" button | cka-restore.ps1 |
| **Remove-CkaSnapshot.ps1** | Inventory (default) then prune checkpoint cruft -- keeps the VMs and your save points | (new) |
| **Invoke-M02Upgrade.ps1** | On-rails M02 demo: restore v1.34, upgrade to v1.35 live, phase by phase | (new) |
| **Invoke-M03Lab.ps1** | On-rails M03 demo: Helm, Kustomize, CRDs + the exam doc technique, live | (new) |
| **Get-CkaLabStatus.ps1** | Show each VM's power + ping state (offers graceful halt) | cka-status.ps1 |
| **Get-CkaConnectionInfo.ps1** | Show node IPs + SSH commands | cka-info.ps1 |
| **Test-CkaLabReady.ps1** | Check kubeadm prereqs on all 3 VMs | cka-validate.ps1 |

All output uses **text labels** (`[OK]` / `[INFO]` / `[WARN]` / `[ERROR]`) on the
colorblind-safe palette -- nothing depends on color alone.

## Recording workflow, per module

### Module 1 -- Backing up etcd  (cluster at v1.35)
```powershell
.\Start-CkaLab.ps1
.\Save-CkaSnapshot.ps1 m01-cluster-ready   # save point
# ...record M01...
.\Restore-CkaSnapshot.ps1 m01-cluster-ready  # rewind to re-record
```

### Module 2 -- Upgrading clusters  (start at v1.34, upgrade to v1.35 on camera)
You do **not** build a second cluster. You bring the **same 3-node lab** up one
minor behind, snapshot it, then upgrade live. **One helper does the whole v1.34
build-and-snapshot in a single shot**, so you never have to remember the
environment-variable dance:

```powershell
# 1) Build the v1.34 cluster AND auto-snapshot it as 'm02-pre-upgrade'.
#    -ExportBaseline saves your v1.35 'm01-cluster-ready' to disk FIRST, so the
#    destroy can't cost you the baseline M01 re-records and M03 both need:
.\Build-M02UpgradeLab.ps1 -ExportBaseline
#    (exports m01-cluster-ready, destroys the current VMs, re-provisions clean at v1.34,
#     then checkpoints all 3 as 'm02-pre-upgrade')

#    Pin a specific 1.34 patch if 1.34.6-1.1 is gone. Confirm what's available:
#      ssh vagrant@192.168.50.10 "apt-cache madison kubeadm | head"
#    then:  .\Build-M02UpgradeLab.ps1 -PackageVersion 1.34.7-1.1

# 2) Record the kubeadm upgrade (v1.34 -> v1.35). The cluster now sits at v1.35,
#    which is exactly Module 3's starting state.

# 3) Re-record any time by rewinding to the clean v1.34 cluster:
.\Restore-CkaSnapshot.ps1 m02-pre-upgrade
```

> **Doing it by hand instead?** The helper just wraps these three: set
> `$env:CKA_K8S_MINOR="1.34"` and `$env:CKA_K8S_PKG_VERSION="1.34.6-1.1"` in this
> same window, then `vagrant destroy -f && vagrant up` (a plain `Start-CkaLab`
> won't downgrade an existing v1.35 cluster), then
> `.\Save-CkaSnapshot.ps1 m02-pre-upgrade`.

Leave `CKA_K8S_MINOR` unset and the lab builds at **v1.35** exactly like today.

### Module 3 -- Helm, Kustomize & CRDs  (runs on the upgraded v1.35 cluster)
M03 records off the **clean v1.35 cluster** (no Helm, no CRDs) that M02 produced.
**One on-rails script IS the demo** -- it restores the snapshot, pushes the
manifests, and walks Helm -> Kustomize -> CRDs (plus the exam doc technique) phase
by phase. Same harness as `Invoke-M02Upgrade.ps1`.

```powershell
# 1) From the clean v1.35 cluster, take the save point ONCE (no Helm installed yet):
.\Save-CkaSnapshot.ps1 m03-pre-helm

# 2) Record the module. The script restores to pristine v1.35 on launch, so every
#    take starts from the identical frame. -OpenDocs also pops kubernetes.io at
#    each documentation beat:
.\Invoke-M03Lab.ps1            # or:  .\Invoke-M03Lab.ps1 -OpenDocs

# 3) Re-record any time -- the launch restore is the rewind. Or do it by hand:
.\Restore-CkaSnapshot.ps1 m03-pre-helm
```

> Manifests live in `exercise-files\course-03-lifecycle-upgrades\m03-helm-kustomize-crds\`
> (the learner download). The script pushes that exact tree to the node, so there
> is one source of truth and no Vagrant synced-folder dependency. Helm is installed
> live in Phase 2 -- a teaching beat; on the real exam it is already on the box.

## Housekeeping -- clearing checkpoint cruft after a recording sprint

The re-record loop is generous with checkpoints. Every M02 take drops
`m02-after-control1` / `m02-after-worker1`, and Hyper-V lets duplicate names pile
up, each with its own differencing disk (`.avhdx`). When you are done recording,
clear the pile but keep the VMs and your save points:

```powershell
# 1) See the tree first (read-only -- changes nothing):
.\Remove-CkaSnapshot.ps1

# 2) Dry-run the sweep (still changes nothing):
.\Remove-CkaSnapshot.ps1 -Prune -WhatIf

# 3) Prune everything EXCEPT your save points (default keep: pre-cluster, m02-pre-upgrade):
.\Remove-CkaSnapshot.ps1 -Prune

# Protect an extra save point on the way through:
.\Remove-CkaSnapshot.ps1 -Prune -Keep pre-cluster, m02-pre-upgrade, m01-cluster-ready

# Or surgically remove just the node-boundary cruft (every copy, all 3 VMs):
.\Remove-CkaSnapshot.ps1 -Name m02-after-control1, m02-after-worker1
```

The VMs are never touched -- only checkpoints. Removing a checkpoint merges its
`.avhdx` back into the parent in the background, which is how the disk space comes
back. Names in `-Keep` are never removed, even if you also name them in `-Name`.

> The original generic `cka-*.ps1` scripts in the parent `src\cka-lab` folder still
> work and are unchanged -- they are the shared engine. **For Course 3, use the
> clearly-named scripts in this folder.**
