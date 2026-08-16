<#
.SYNOPSIS
    The Module 2 demo, on rails: upgrade a kubeadm cluster from Kubernetes
    v1.34 to v1.35, one phase at a time, with the talk track on screen and the
    REAL commands executed live against the lab.

.DESCRIPTION
    This single script IS the Module 2 demo. Each phase prints a short, plain
    explanation (the WHY), shows the exact command, runs it for real on the lab
    VMs over SSH, and shows the output. You press Enter between phases. The
    cluster genuinely moves from v1.34 to v1.35 as you watch.

    It is built to be run "for real" over and over:

      * IDEMPOTENT START. On launch it restores the 'm02-pre-upgrade' Hyper-V
        checkpoint, so every run begins from the identical pristine v1.34
        cluster. Run it ten times and take ten gets the same starting frame.

      * SNAPSHOT BETWEEN NODES. After each node finishes upgrading it takes a
        checkpoint ('m02-after-control1', 'm02-after-worker1'), so a botched
        worker take rewinds to the node boundary instead of the whole demo.

      * SAFE TO ABORT. Ctrl-C at any point leaves the VMs as they are; re-launch
        and the restore puts you back to pristine v1.34.

    Learners get the source. It is written to be READ: every phase explains the
    mechanism in first principles before the command, expands acronyms once, and
    drops a CKA exam tip where one earns its place.

.PARAMETER PreUpgradeSnapshot
    The pristine v1.34 checkpoint to restore on launch. Default 'm02-pre-upgrade'.

.PARAMETER FromVersion / .PARAMETER ToVersion
    Display strings for the minor-version hop. Defaults '1.34' -> '1.35'.

.PARAMETER ToPackage
    The exact v1.35 apt package to install (kubeadm/kubelet/kubectl). Default
    '1.35.0-1.1'. Confirm what the repo actually has on recording day with:
        ssh vagrant@192.168.50.10 "sudo apt-cache madison kubeadm | head"

.PARAMETER SkipRestore
    Do NOT restore on launch. Use only when continuing a partially-run take and
    you know the cluster's current state. Off by default -- the restore is what
    makes this idempotent.

.PARAMETER AutoSnapshot
    Take the per-node checkpoints between phases. On by default.

.EXAMPLE
    .\Invoke-M02Upgrade.ps1
    Restore pristine v1.34, then walk the upgrade to v1.35 phase by phase.

.EXAMPLE
    .\Invoke-M02Upgrade.ps1 -ToPackage 1.35.6-1.1
    Same, pinned to the exact v1.35 patch you confirmed with apt-cache madison.

.NOTES
    Author: Tim Warner | CKA Course 3, Module 2 (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from
            C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Grounding: kubernetes.io kubeadm-upgrade, change-package-repository, and
               version-skew-policy. Commands verified live against the lab.
    Pairs with: Restore-CkaSnapshot.ps1 m02-pre-upgrade (manual rewind),
                CKA-C03-M02-demo-runbook.md (the written companion)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$PreUpgradeSnapshot = 'm02-pre-upgrade',

    [ValidateNotNullOrEmpty()]
    [string]$FromVersion = '1.34',

    [ValidateNotNullOrEmpty()]
    [string]$ToVersion = '1.35',

    [ValidatePattern('^\d+\.\d+\.\d+-\d+\.\d+$')]
    [string]$ToPackage = '1.35.0-1.1',

    [switch]$SkipRestore,

    [bool]$AutoSnapshot = $true
)

$ErrorActionPreference = 'Stop'

# Reuse the shared engine: Write-* palette helpers, Get-CkaLabNodes (Name+IP),
# Initialize-LabEncoding. One definition of the lab, never duplicated here.
. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# Point Vagrant/SSH at the lab. The three nodes and their static IPs come from
# the shared module so this script can never disagree with the rest of the lab.
$env:VAGRANT_CWD = Split-Path -Parent $PSScriptRoot
$Nodes      = Get-CkaLabNodes
$Control    = ($Nodes | Where-Object Name -eq 'control1')
$Workers    = ($Nodes | Where-Object Name -ne 'control1')
$AllVMs     = $Nodes.Name

#region On-rails render helpers ------------------------------------------------
# These three helpers ARE the on-camera look. One place defines the rhythm:
# phase banner -> one-line crumb -> command in yellow -> live output -> Enter.
# Full talk track lives in the runbook, NOT here.

function Write-PhaseBanner {
    param([int]$Number, [int]$Total, [string]$Title)
    Write-Host ""
    Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)  >>> PHASE $Number of $Total  --  $Title$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
    Write-Host ""
}

function Write-Talk {
    # The talk track. Plain paragraphs, already wrapped. Printed dim-neutral so
    # the yellow command below it is what the eye lands on.
    param([string[]]$Lines)
    foreach ($l in $Lines) { Write-Host "  $l" }
    Write-Host ""
}

function Write-ExamTip {
    param([string[]]$Lines)
    Write-Host "$($Script:BrightYellow)  CKA TIP$($Script:AnsiReset)"
    foreach ($l in $Lines) { Write-Host "$($Script:BrightYellow)  $l$($Script:AnsiReset)" }
    Write-Host ""
}

function Invoke-OnNode {
    <#
        Run a command block on one lab node over `vagrant ssh`, echoing the
        command in yellow first (so the learner sees exactly what ran) then the
        live output. Returns the remote exit code so phases can fail fast.
    #>
    param(
        [Parameter(Mandatory)][string]$Node,
        [Parameter(Mandatory)][string]$Command,
        [string]$Label
    )
    if ($Label) { Write-Host "  $($Script:NeonGreen)# $Label$($Script:AnsiReset)" }
    Write-Host "  $($Script:BrightYellow)[$Node] `$ $Command$($Script:AnsiReset)"
    Write-Host ""
    # -T: no pseudo-tty (we're scripting). Output streams straight through.
    vagrant ssh $Node -c $Command 2>&1 | ForEach-Object { Write-Host "    $_" }
    $code = $LASTEXITCODE
    Write-Host ""
    return $code
}

function Wait-Enter {
    param([string]$Prompt = 'Press Enter for the next phase')
    Write-Host "$($Script:NeonGreen)  --> $Prompt (Ctrl-C to stop)$($Script:AnsiReset)"
    [void](Read-Host)
}

function Save-NodeCheckpoint {
    # Atomic per-node boundary checkpoint. Skipped if -AutoSnapshot:$false.
    param([string]$Name)
    if (-not $AutoSnapshot) { return }
    Write-Info "Checkpointing all VMs as '$Name' (node boundary -- your rewind point)"
    foreach ($vm in $AllVMs) {
        # Remove a same-named stale checkpoint first so re-runs stay idempotent.
        Get-VMCheckpoint -VMName $vm -Name $Name -ErrorAction SilentlyContinue |
            Remove-VMCheckpoint -Confirm:$false -ErrorAction SilentlyContinue
        Checkpoint-VM -Name $vm -SnapshotName $Name -Confirm:$false -ErrorAction Stop
    }
    Write-Success "Checkpoint '$Name' taken on all 3 VMs"
}
#endregion

#region Phase 0 -- idempotent restore + preflight -------------------------------

Clear-Host
Write-Host "$($Script:NeonGreen)"
Write-Host '  CKA COURSE 3 / MODULE 2  --  UPGRADING A KUBEADM CLUSTER'
Write-Host "  $FromVersion  ->  $ToVersion   (on rails, real commands, live)"
Write-Host "$($Script:AnsiReset)"
Write-Host "  Target patch: kubeadm/kubelet/kubectl = $ToPackage"
Write-Host "  Runbook/App rev: 2.0"
Write-Host ""

# Preflight: the pristine checkpoint must exist on every VM, or the idempotent
# restore is a lie. Verify all three BEFORE touching anything.
if (-not $SkipRestore) {
    Write-Step "Idempotent start: restoring '$PreUpgradeSnapshot' on all 3 VMs"
    $missing = @($AllVMs | Where-Object {
        -not (Get-VMCheckpoint -VMName $_ -Name $PreUpgradeSnapshot -ErrorAction SilentlyContinue)
    })
    if ($missing.Count -gt 0) {
        Write-ErrorMsg "Checkpoint '$PreUpgradeSnapshot' missing on: $($missing -join ', ')."
        Write-Info "Build the pristine v$FromVersion lab first, then snapshot it:"
        Write-Info "    .\Build-M02UpgradeLab.ps1   (then it auto-snapshots '$PreUpgradeSnapshot')"
        exit 1
    }
    foreach ($vm in $AllVMs) {
        Restore-VMCheckpoint -VMName $vm -Name $PreUpgradeSnapshot -Confirm:$false -ErrorAction Stop
        Start-VM -Name $vm -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Success "Restored to pristine v$FromVersion. Waiting for the API server to answer..."

    # Don't start narrating until kubectl actually responds -- a restored VM
    # needs a few seconds for the kubelet + apiserver static pods to come back.
    $ready = $false
    foreach ($i in 1..30) {
        $out = (vagrant ssh control1 -c 'kubectl get --raw=/readyz 2>/dev/null' 2>&1) -join ''
        if ($out -match 'ok') { $ready = $true; break }
        Start-Sleep -Seconds 4
    }
    if (-not $ready) {
        Write-Warn 'API server did not report ready in time. Continuing, but the first command may need a moment.'
    } else {
        Write-Success 'Cluster is up and answering.'
    }
}
else {
    Write-Warn "-SkipRestore set: using the cluster's CURRENT state, not a pristine restore."
}

# Setup: deploy the demo workload so the worker drain (Phase 7) visibly evicts
# pods. The pristine snapshot predates this workload, so the app owns it -- that
# keeps the demo self-contained: restore wipes everything, then we redeploy here,
# so every run has the same pods to drain no matter what the snapshot holds.
# Idempotent: 'create ... || true' so a re-run against an existing deploy is a no-op.
Write-Step 'Setup: deploy the Globomantics workload (gives drain something to evict)'
[void](Invoke-OnNode -Node 'control1' -Label 'deploy globo-shop, 3 replicas across the workers' `
    -Command 'kubectl create deployment globo-shop --image=nginx --replicas=3 2>/dev/null; kubectl rollout status deployment/globo-shop --timeout=60s; kubectl get pods -l app=globo-shop -o wide')

Write-Step 'Starting state (this is the frame every run begins from)'
[void](Invoke-OnNode -Node 'control1' -Label 'all three nodes, current version' `
    -Command 'kubectl get nodes')
Wait-Enter -Prompt 'Press Enter to begin the upgrade'
#endregion

$TOTAL = 8

#region Phase 1 -- the mental model + why control plane first -------------------
Write-PhaseBanner -Number 1 -Total $TOTAL -Title 'Why the control plane goes first'
Write-Talk @(
    "Control plane first: the kubelet may lag the apiserver by 3 minors, never lead",
    "it. Brain before limbs."
)
Write-ExamTip @(
    "Skew axes: kubelet up to 3 minors behind apiserver; kubectl within 1 either side."
)
Wait-Enter
#endregion

#region Phase 2 -- etcd backup (the only true rollback) -------------------------
Write-PhaseBanner -Number 2 -Total $TOTAL -Title 'Back up etcd before you mutate the control plane'
Write-Talk @(
    "Snapshot etcd first -- it is the whole cluster in one file, your only true",
    "rollback. We exec into the etcd pod so there is nothing to install on the host."
)
$etcdBackup = @'
sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl -n kube-system exec etcd-control1 -- \
  etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key \
  snapshot save /var/lib/etcd/m02-pre-1.35.db && echo "etcd snapshot saved"
'@.Trim()
[void](Invoke-OnNode -Node 'control1' -Label 'snapshot etcd from inside the etcd pod' -Command $etcdBackup)
Write-ExamTip @(
    "etcd cert paths live under /etc/kubernetes/pki/etcd/: ca.crt, server.crt, server.key."
)
Wait-Enter
#endregion

#region Phase 3 -- repoint the apt repo to the new minor ------------------------
Write-PhaseBanner -Number 3 -Total $TOTAL -Title "Repoint the package repo to v$ToVersion"
Write-Talk @(
    "Don't change the command, change what the repo POINTS at: /v$FromVersion/ becomes",
    "/v$ToVersion/, then apt-get update so the same install resolves to the new binary."
)
$repoSwap = @"
echo '--- before ---'; cat /etc/apt/sources.list.d/kubernetes.list; \
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$ToVersion/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list; \
sudo apt-get update -qq && echo '--- v$ToVersion now visible ---' && sudo apt-cache madison kubeadm | head -3
"@.Trim()
[void](Invoke-OnNode -Node 'control1' -Label 'flip the repo, then update the package index' -Command $repoSwap)
Write-ExamTip @(
    "No apt-get update means apt still resolves the old version -- the #1 'upgrade does nothing' cause."
)
Wait-Enter
#endregion

#region Phase 4 -- upgrade the kubeadm binary ----------------------------------
Write-PhaseBanner -Number 4 -Total $TOTAL -Title "Upgrade the kubeadm tool to $ToPackage"
Write-Talk @(
    "unhold -> install exact patch -> re-hold. The TOOL becomes v$ToVersion; the",
    "cluster isn't yet."
)
$kubeadmUp = @"
sudo apt-mark unhold kubeadm && \
sudo apt-get install -y kubeadm='$ToPackage' && \
sudo apt-mark hold kubeadm && kubeadm version -o short
"@.Trim()
[void](Invoke-OnNode -Node 'control1' -Label 'unhold -> install exact patch -> re-hold' -Command $kubeadmUp)
Wait-Enter
#endregion

#region Phase 5 -- plan, then apply (control plane becomes v1.35) ---------------
Write-PhaseBanner -Number 5 -Total $TOTAL -Title 'Plan, then apply -- the control plane upgrade'
Write-Talk @(
    "plan = dry run. apply rewrites the static-pod manifests and rolls the control",
    "plane."
)
[void](Invoke-OnNode -Node 'control1' -Label 'dry run: what WILL change' -Command 'sudo kubeadm upgrade plan')
Wait-Enter -Prompt "Reviewed the plan? Press Enter to APPLY v$ToVersion"
[void](Invoke-OnNode -Node 'control1' -Label "apply -- control plane to v$ToVersion" `
    -Command "sudo kubeadm upgrade apply v$ToVersion -y")
[void](Invoke-OnNode -Node 'control1' -Label "components are v$ToVersion, but the NODE still shows v$FromVersion (kubelet next)" -Command 'kubectl get nodes')
Write-ExamTip @(
    "'apply <version>' runs on the first control plane only; everywhere else runs 'kubeadm upgrade node'."
)
Wait-Enter
#endregion

#region Phase 6 -- drain control1, bump its kubelet, uncordon -------------------
Write-PhaseBanner -Number 6 -Total $TOTAL -Title 'Drain control1, upgrade its kubelet, uncordon'
Write-Talk @(
    "drain = cordon + evict. Bump the kubelet, then the node flips to v$ToVersion.",
    "--ignore-daemonsets is mandatory or drain refuses."
)
[void](Invoke-OnNode -Node 'control1' -Label 'cordon + evict (control1 is tainted, so this is light)' `
    -Command 'kubectl drain control1 --ignore-daemonsets')
Write-ExamTip @(
    "A 'violate disruption budget ... will retry' line is NOT an error -- drain respects the PDB and retries."
)
$kubeletUp = @"
sudo apt-mark unhold kubelet kubectl && \
sudo apt-get install -y kubelet='$ToPackage' kubectl='$ToPackage' && \
sudo apt-mark hold kubelet kubectl && \
sudo systemctl daemon-reload && sudo systemctl restart kubelet && echo 'kubelet restarted'
"@.Trim()
[void](Invoke-OnNode -Node 'control1' -Label 'bump kubelet+kubectl, restart the kubelet' -Command $kubeletUp)
[void](Invoke-OnNode -Node 'control1' -Label 'back to schedulable' -Command 'kubectl uncordon control1')
[void](Invoke-OnNode -Node 'control1' -Label "NOW control1 reports v$ToVersion" -Command 'kubectl get nodes')
Save-NodeCheckpoint -Name 'm02-after-control1'
Wait-Enter
#endregion

#region Phase 7 -- upgrade the workers (the repeatable arc) ---------------------
Write-PhaseBanner -Number 7 -Total $TOTAL -Title 'Upgrade the workers'
Write-Talk @(
    "Workers run 'upgrade node', NOT apply. drain/uncordon run FROM control1."
)
foreach ($w in $Workers) {
    $name = $w.Name
    Write-Step "Worker: $name"

    # ON the worker: repo swap + kubeadm upgrade node
    $wRepo = @"
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$ToVersion/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list; \
sudo apt-get update -qq && sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm='$ToPackage' && sudo apt-mark hold kubeadm
"@.Trim()
    [void](Invoke-OnNode -Node $name -Label "ON ${name}: repo swap + kubeadm tool" -Command $wRepo)
    [void](Invoke-OnNode -Node $name -Label "ON ${name}: 'upgrade node' (NOT apply)" -Command 'sudo kubeadm upgrade node')

    # FROM control1: drain the worker (admin kubeconfig lives on control1)
    [void](Invoke-OnNode -Node 'control1' -Label "FROM control1: drain $name (worker has no kubeconfig)" `
        -Command "kubectl drain $name --ignore-daemonsets --delete-emptydir-data")

    # ON the worker: bump kubelet + restart
    $wKubelet = @"
sudo apt-mark unhold kubelet kubectl && sudo apt-get install -y kubelet='$ToPackage' kubectl='$ToPackage' && sudo apt-mark hold kubelet kubectl && \
sudo systemctl daemon-reload && sudo systemctl restart kubelet && echo 'kubelet restarted'
"@.Trim()
    [void](Invoke-OnNode -Node $name -Label "ON ${name}: bump kubelet, restart" -Command $wKubelet)

    # FROM control1: uncordon
    [void](Invoke-OnNode -Node 'control1' -Label "FROM control1: uncordon $name" -Command "kubectl uncordon $name")
    Save-NodeCheckpoint -Name "m02-after-$name"
    Wait-Enter -Prompt "Worker $name done. Press Enter to continue"
}
#endregion

#region Phase 8 -- verify the whole cluster is v1.35 ----------------------------
Write-PhaseBanner -Number 8 -Total $TOTAL -Title "Verify -- the whole cluster is v$ToVersion"
Write-Talk @(
    "Three nodes at v$ToVersion, app never went down. kubeadm did NOT touch Calico."
)
[void](Invoke-OnNode -Node 'control1' -Label 'every node at the new version' -Command 'kubectl get nodes')
[void](Invoke-OnNode -Node 'control1' -Label 'control plane + workloads all Running' -Command 'kubectl get pods -A | grep -E "globo-shop|kube-system|calico" | head -20')
Write-ExamTip @(
    "Memorize the arc: repo, kubeadm, plan/apply, drain, kubelet, uncordon."
)
Write-Host ""
Write-Success "Module 2 demo complete. Cluster upgraded v$FromVersion -> v$ToVersion."
Write-Info "Re-run from pristine any time:  .\Invoke-M02Upgrade.ps1"
Write-Info "Or rewind to a node boundary:   .\Restore-CkaSnapshot.ps1 m02-after-control1"
#endregion
