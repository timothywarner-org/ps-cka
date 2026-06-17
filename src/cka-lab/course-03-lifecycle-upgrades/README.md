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
| **Stop-CkaLab.ps1** | Gracefully halt the 3 VMs (end of session) | cka-down.ps1 |
| **Save-CkaSnapshot.ps1** `<name>` | Checkpoint all 3 VMs -- your "save point" before a take | cka-snapshot.ps1 |
| **Restore-CkaSnapshot.ps1** `<name>` | Rewind all 3 VMs to a checkpoint -- the "re-record" button | cka-restore.ps1 |
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
minor behind, snapshot it, then upgrade live.

```powershell
# 1) Build the lab at v1.34 -- set these BEFORE Start-CkaLab, in this same window:
$env:CKA_K8S_MINOR       = "1.34"
$env:CKA_K8S_PKG_VERSION = "1.34.6-1.1"   # exact patch: see note below
.\Start-CkaLab.ps1

#    Find the exact 1.34 patch available, from inside a VM:
#      vagrant ssh control1 -c "apt-cache madison kubeadm | head"

# 2) Snapshot the clean v1.34 cluster -- your M02 re-record point:
.\Save-CkaSnapshot.ps1 m02-pre-upgrade

# 3) Record the kubeadm upgrade (v1.34 -> v1.35). The cluster now sits at v1.35,
#    which is exactly Module 3's starting state.

# 4) Re-record any time by rewinding to the clean v1.34 cluster:
.\Restore-CkaSnapshot.ps1 m02-pre-upgrade
```
Leave `CKA_K8S_MINOR` unset and the lab builds at **v1.35** exactly like today.

### Module 3 -- Helm, Kustomize & CRDs  (runs on the upgraded v1.35 cluster)
```powershell
.\Save-CkaSnapshot.ps1 m03-pre-helm
# ...record M03...
.\Restore-CkaSnapshot.ps1 m03-pre-helm
```

## Housekeeping

```powershell
# List checkpoints on one VM (Hyper-V tracks them per VM):
Get-VMCheckpoint -VMName control1 | Select-Object Name, CreationTime

# Delete a checkpoint across all three VMs (needed before reusing a name):
'control1','worker1','worker2' | ForEach-Object {
    Remove-VMCheckpoint -VMName $_ -Name 'm02-pre-upgrade' -Confirm:$false -ErrorAction SilentlyContinue
}
```

> The original generic `cka-*.ps1` scripts in the parent `src\cka-lab` folder still
> work and are unchanged -- they are the shared engine. **For Course 3, use the
> clearly-named scripts in this folder.**
