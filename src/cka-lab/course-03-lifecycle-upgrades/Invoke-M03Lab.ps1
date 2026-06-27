<#
.SYNOPSIS
    On-rails console demo for Course 3 / Module 3 -- Helm, Kustomize, and CRDs --
    on the upgraded v1.35 cluster. Commands run live over SSH, phase by phase.

.DESCRIPTION
    This app drives the COMMANDS for the Module 3 demo. It does NOT print the talk
    track -- the spoken narration lives in the runbook
    (CKA-C03-M03-demo-runbook.md), which is what you read off-camera. The screen
    shows only what the learner needs: each command, a one-sentence explication, and
    the live output.

    CROSS-REFERENCE. Every command carries a beat tag like [3.4]. The runbook tags
    the same commands with the same numbers, so your eye maps runbook <-> screen at
    a glance: phase number, then beat number.

    What it covers, in ~15 minutes:
      Phase 1  Documentation technique -- kubectl explain and dry-run scaffolding
      Phase 2  Helm -- install, release, upgrade with a changed value, rollback
      Phase 3  Kustomize -- one base, staging and production overlays, applied
      Phase 4  CRDs -- define a kind, explain it, create a custom resource
      Phase 5  Reset -- tear the demo objects down

    IDEMPOTENT START. On launch it restores the 'm03-pre-helm' checkpoint, so every
    run begins from the identical clean v1.35 cluster (no Helm, no CRDs). The
    restore wipes the pushed demo files too, so the app re-pushes them first. The
    restore also invalidates Calico's CNI token, so Phase 0 bounces calico-node
    before any workload runs (see the comment there).

    SELF-CONTAINED MANIFESTS. The Kustomize tree and CRD/CR live in the repo under
    exercise-files\...\m03-helm-kustomize-crds\ (the learner download). The app
    pushes that exact tree to the node and runs commands against it with clean
    relative paths, so the screen matches the runbook line for line.

    ACCESSIBILITY. Output flows through the shared palette helpers in lib\CkaLab.ps1
    -- status lines are labeled on the Wong colorblind-safe palette, and the PRESS
    ENTER bar is marked by shape + label, not color alone (red/green safe).

.PARAMETER PreHelmSnapshot
    The clean v1.35 checkpoint to restore on launch. Default 'm03-pre-helm'.

.PARAMETER SkipRestore
    Do NOT restore on launch. Use only when continuing a partially-run take.

.PARAMETER HelmVersion
    Pin a specific Helm version (for example 'v3.16.4'). Default empty installs the
    latest stable Helm.

.PARAMETER Node
    The control-plane node to drive. Default 'control1'.

.EXAMPLE
    .\Invoke-M03Lab.ps1
    Restore the clean v1.35 cluster, then walk all 5 phases.

.EXAMPLE
    .\Invoke-M03Lab.ps1 -SkipRestore
    Continue against the cluster's current state without rewinding.

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from a window OTHER than your recording SSH
            session, in C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: CKA-C03-M03-demo-runbook.md (your spoken talk track + the same beat tags)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$PreHelmSnapshot = 'm03-pre-helm',

    [switch]$SkipRestore,

    [string]$HelmVersion = '',

    [ValidateNotNullOrEmpty()]
    [string]$Node = 'control1'
)

$ErrorActionPreference = 'Stop'
# Teaching demo: a remote command that exits nonzero must NOT halt the script.
$PSNativeCommandUseErrorActionPreference = $false

. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

$env:VAGRANT_CWD = Split-Path -Parent $PSScriptRoot
$AllVMs     = (Get-CkaLabVMs)
$RemoteBase = '/home/vagrant/m03-demo'

#region On-rails render helpers -------------------------------------------------
function Write-PhaseBanner {
    param([int]$Number, [int]$Total, [string]$Title)
    # Clear first so every phase opens on a clean frame at the top of the terminal.
    Clear-Host
    Write-Host ""
    Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)  >>> PHASE $Number of $Total  --  $Title$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
    Write-Host ""
}

function Invoke-Beat {
    <#
        Run ONE command on the node over `vagrant ssh`. Prints the beat tag + a
        one-SENTENCE explication (a teaching line, not talk track), echoes the
        command in yellow, then streams the live output. The beat tag [N.M] matches
        the runbook so you can cross-reference screen <-> runbook instantly.

        -WorkDir runs the command from that directory (so the displayed command can
        use clean relative paths) WITHOUT showing the cd -- the screen stays tidy
        and matches the runbook's relative paths.
    #>
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Explain,
        [Parameter(Mandatory)][string]$Command,
        [string]$WorkDir
    )
    Write-Host "  $($Script:NeonGreen)[$Tag] $Explain$($Script:AnsiReset)"
    Write-Host "  $($Script:BrightYellow)`$ $Command$($Script:AnsiReset)"
    Write-Host ""
    $run = if ($WorkDir) { "cd '$WorkDir' && $Command" } else { $Command }
    vagrant ssh $Node -c $run 2>&1 | ForEach-Object { Write-Host "    $_" }
    Write-Host ""
}

function Wait-Enter {
    # PRESS ENTER action bar -- your "click now" cue. Dashed rules + label mark it by
    # shape, not color (red/green safe). This is the only thing you act on; your
    # words come from the runbook.
    param([string]$Prompt = 'for the next phase')
    $bar = '  ' + ('-' * 60)
    Write-Host "$($Script:NeonGreen)$bar$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)  >>> PRESS ENTER $Prompt    (Ctrl-C to stop)$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)$bar$($Script:AnsiReset)"
    [void](Read-Host)
}

function Push-DemoTree {
    # Copy the repo's m03 manifest tree onto the node as text (LF-normalized) over
    # the same stdin->ssh path the validator uses. One source of truth, no
    # synced-folder dependency.
    $src = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\exercise-files\course-03-lifecycle-upgrades\m03-helm-kustomize-crds')).Path
    $files = Get-ChildItem -Path $src -Recurse -File -Filter *.yaml
    [void](vagrant ssh $Node -c "rm -rf '$RemoteBase'")
    foreach ($f in $files) {
        $rel    = $f.FullName.Substring($src.Length).TrimStart('\', '/').Replace('\', '/')
        $remote = "$RemoteBase/$rel"
        $dir    = $remote.Substring(0, $remote.LastIndexOf('/'))
        $body   = (Get-Content -Raw -LiteralPath $f.FullName) -replace "`r`n", "`n"
        $body | vagrant ssh $Node -c "mkdir -p '$dir' && cat > '$remote'"
    }
    Write-Success "Pushed $($files.Count) manifest(s) to $RemoteBase on $Node"
}
#endregion

$TOTAL = 5
$helmEnv = if ($HelmVersion) { "DESIRED_VERSION=$HelmVersion " } else { '' }

#region Phase 0 -- restore + heal Calico + push manifests + starting frame -------
Clear-Host
Write-Host "$($Script:NeonGreen)"
Write-Host '  CKA COURSE 3 / MODULE 3  --  HELM, KUSTOMIZE & CRDs'
Write-Host '  Three jobs, three tools: PACKAGE it (Helm), CUSTOMIZE it (Kustomize), EXTEND it (CRDs).'
Write-Host '  Commands on screen. Talk track in the runbook. Beat tags [N.M] link them.'
Write-Host "$($Script:AnsiReset)"
Write-Host "  Driving node: $Node    Restore point: $PreHelmSnapshot"
Write-Host "  Runbook/App rev: 1.5"
Write-Host ""

if (-not $SkipRestore) {
    Write-Step "Idempotent start: restoring '$PreHelmSnapshot' on all 3 VMs"
    $missing = @($AllVMs | Where-Object {
        -not (Get-VMCheckpoint -VMName $_ -Name $PreHelmSnapshot -ErrorAction SilentlyContinue)
    })
    if ($missing.Count -gt 0) {
        Write-ErrorMsg "Checkpoint '$PreHelmSnapshot' missing on: $($missing -join ', ')."
        Write-Info 'Take it first from the clean v1.35 cluster:  .\Save-CkaSnapshot.ps1 m03-pre-helm'
        exit 1
    }
    foreach ($vm in $AllVMs) {
        Restore-VMCheckpoint -VMName $vm -Name $PreHelmSnapshot -Confirm:$false -ErrorAction Stop
        Start-VM -Name $vm -ErrorAction SilentlyContinue | Out-Null
    }
    Write-Success 'Restored to clean v1.35. Waiting for the API server to answer...'
    $ready = $false
    foreach ($i in 1..30) {
        $out = (vagrant ssh $Node -c 'kubectl get --raw=/readyz 2>/dev/null' 2>&1) -join ''
        if ($out -match 'ok') { $ready = $true; break }
        Start-Sleep -Seconds 4
    }
    if ($ready) { Write-Success 'Cluster is up and answering.' }
    else { Write-Warn 'API server did not report ready in time. Continuing -- the first command may need a moment.' }

    # KNOWN LAB GOTCHA: restoring a Hyper-V checkpoint invalidates Calico's CNI
    # token. New pods then fail with "calico ... ClusterInformation: Unauthorized"
    # and helm --wait hangs to its timeout. Bounce calico-node so networking is
    # healthy BEFORE any workload beat runs. This is off-camera setup cost (~30-60s),
    # and it is why we restart it here rather than firefighting a stuck --wait later.
    Write-Step 'Healing Calico after the restore (refreshes the CNI token)'
    $calicoNs = (vagrant ssh $Node -c "kubectl get ds -A --no-headers 2>/dev/null | awk '/calico-node/{print `$1; exit}'" 2>&1 | Where-Object { $_ -match '\S' } | Select-Object -Last 1)
    if ($calicoNs) {
        $calicoNs = $calicoNs.Trim()
        [void](vagrant ssh $Node -c "kubectl -n $calicoNs rollout restart daemonset/calico-node")
        vagrant ssh $Node -c "kubectl -n $calicoNs rollout status daemonset/calico-node --timeout=150s" 2>&1 |
            ForEach-Object { Write-Host "    $_" }
        Write-Success 'Calico healthy -- pod networking ready'
    }
    else {
        Write-Warn 'calico-node daemonset not found -- skipping heal (not a Calico cluster?)'
    }
}
else {
    Write-Warn "-SkipRestore set: using the cluster's CURRENT state, not a clean restore."
}

Write-Step 'Staging the demo manifests on the node'
Push-DemoTree

Write-Step 'Starting frame'
Invoke-Beat -Tag '0' -Explain 'All three nodes are Ready at v1.35, so this is our clean starting slate.' -Command 'kubectl get nodes'
Wait-Enter -Prompt 'to begin the demo'
#endregion

#region Phase 1 -- Documentation: your terminal is the manual --------------------
Write-PhaseBanner -Number 1 -Total $TOTAL -Title 'Documentation: your terminal is the manual'
Invoke-Beat -Tag '1.1' -Explain 'kubectl explain prints the live, version-correct schema for any field, straight from the API server.' `
    -Command 'kubectl explain deployment.spec.strategy --recursive'
Invoke-Beat -Tag '1.2' -Explain 'The --dry-run=client flag scaffolds a manifest as YAML without creating anything on the cluster.' `
    -Command 'kubectl create deployment web --image=nginx --dry-run=client -o yaml'
Wait-Enter
#endregion

#region Phase 2 -- Helm: install, release, upgrade, rollback ---------------------
Write-PhaseBanner -Number 2 -Total $TOTAL -Title 'Helm: install, release, upgrade, rollback'
Invoke-Beat -Tag '2.1' -Explain 'We install the Helm client using the canonical one-line installer from helm.sh.' `
    -Command "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | ${helmEnv}bash"
Invoke-Beat -Tag '2.2' -Explain 'We register a chart repository and refresh its local index so Helm can find the chart.' `
    -Command 'helm repo add podinfo https://stefanprodan.github.io/podinfo && helm repo update'
Invoke-Beat -Tag '2.3' -Explain 'helm upgrade --install deploys the release, creating it the first time and upgrading it on later runs.' `
    -Command 'helm upgrade --install globo-podinfo podinfo/podinfo --wait'
Invoke-Beat -Tag '2.4' -Explain 'helm list shows our release sitting at revision 1.' `
    -Command 'helm list'
Invoke-Beat -Tag '2.5' -Explain 'Changing a single value makes Helm roll a brand-new revision instead of editing the live objects by hand.' `
    -Command 'helm upgrade globo-podinfo podinfo/podinfo --reuse-values --set replicaCount=3 --wait'
Invoke-Beat -Tag '2.6' -Explain 'Rolling back to revision 1 proves that every Helm release has an undo button.' `
    -Command 'helm rollback globo-podinfo 1 --wait'
Invoke-Beat -Tag '2.7' -Explain 'helm history is the revision ledger, recording the install, the upgrade, and the rollback.' `
    -Command 'helm history globo-podinfo'
Wait-Enter
#endregion

#region Phase 3 -- Kustomize: one base, many overlays ---------------------------
Write-PhaseBanner -Number 3 -Total $TOTAL -Title 'Kustomize: one base, many overlays'
Invoke-Beat -Tag '3.1' -WorkDir $RemoteBase -Explain 'This is the base Deployment, the plain workload with no environment-specific opinions baked in.' `
    -Command 'cat m03-kustomize-demo/base/deployment.yaml'
Invoke-Beat -Tag '3.2' -WorkDir $RemoteBase -Explain 'The base kustomization simply lists the resources that make up the application.' `
    -Command 'cat m03-kustomize-demo/base/kustomization.yaml'
Invoke-Beat -Tag '3.3' -WorkDir $RemoteBase -Explain 'The staging overlay patches the base, adding a name prefix, an env label, and two replicas.' `
    -Command 'cat m03-kustomize-demo/overlays/staging/kustomization.yaml'
Invoke-Beat -Tag '3.4' -WorkDir $RemoteBase -Explain 'kubectl kustomize renders the staging result so you can inspect it before anything is applied.' `
    -Command 'kubectl kustomize m03-kustomize-demo/overlays/staging'
Invoke-Beat -Tag '3.5' -WorkDir $RemoteBase -Explain 'The production overlay patches the same base with four replicas and a pinned image tag.' `
    -Command 'cat m03-kustomize-demo/overlays/production/kustomization.yaml'
Invoke-Beat -Tag '3.6' -WorkDir $RemoteBase -Explain 'Rendering production shows the pinned image, so this environment never drifts onto a floating tag.' `
    -Command 'kubectl kustomize m03-kustomize-demo/overlays/production'
Invoke-Beat -Tag '3.7' -WorkDir $RemoteBase -Explain 'kubectl apply -k applies the production overlay to the cluster for real.' `
    -Command 'kubectl apply -k m03-kustomize-demo/overlays/production'
Invoke-Beat -Tag '3.8' -WorkDir $RemoteBase -Explain 'The result proves the overlay worked: four replicas, prod- names, and the env=production label.' `
    -Command 'kubectl get deploy,svc -l env=production'
Wait-Enter
#endregion

#region Phase 4 -- CRDs: a new kind in the API ----------------------------------
Write-PhaseBanner -Number 4 -Total $TOTAL -Title 'CRDs: a new kind in the API'
Invoke-Beat -Tag '4.1' -WorkDir $RemoteBase -Explain 'This CustomResourceDefinition declares a new BackupPolicy kind along with the schema that validates it.' `
    -Command 'cat m03-crds-demo/backuppolicy-crd.yaml'
Invoke-Beat -Tag '4.2' -WorkDir $RemoteBase -Explain 'Applying the CRD registers the new kind with the API server.' `
    -Command 'kubectl apply -f m03-crds-demo/backuppolicy-crd.yaml'
Invoke-Beat -Tag '4.3' -WorkDir $RemoteBase -Explain 'The API server now serves our kind, which we can query by name with no grep required.' `
    -Command 'kubectl get crd backuppolicies.globomantics.io'
Invoke-Beat -Tag '4.4' -WorkDir $RemoteBase -Explain 'Because the CRD carries a schema, kubectl explain now documents our own custom kind.' `
    -Command 'kubectl explain backuppolicy.spec'
Invoke-Beat -Tag '4.5' -WorkDir $RemoteBase -Explain 'This custom resource is a single instance of the BackupPolicy kind we just defined.' `
    -Command 'cat m03-crds-demo/globomantics-backuppolicy.yaml'
Invoke-Beat -Tag '4.6' -WorkDir $RemoteBase -Explain 'Creating the instance makes the API server validate it against the CRD schema on admission.' `
    -Command 'kubectl apply -f m03-crds-demo/globomantics-backuppolicy.yaml'
Invoke-Beat -Tag '4.7' -WorkDir $RemoteBase -Explain 'Listing the resource shows the custom printer columns the CRD defined (its short name is bp).' `
    -Command 'kubectl get backuppolicies'
Wait-Enter
#endregion

#region Phase 5 -- Reset --------------------------------------------------------
Write-PhaseBanner -Number 5 -Total $TOTAL -Title 'Reset (a clean restore would also do this)'
Invoke-Beat -Tag '5.1' -Explain 'We uninstall the Helm release to remove it from the cluster.' `
    -Command 'helm uninstall globo-podinfo'
Invoke-Beat -Tag '5.2' -WorkDir $RemoteBase -Explain 'We delete the Kustomize overlay we applied earlier.' `
    -Command 'kubectl delete -k m03-kustomize-demo/overlays/production --ignore-not-found'
Invoke-Beat -Tag '5.3' -WorkDir $RemoteBase -Explain 'We delete the CRD, which also removes any custom resources of that kind.' `
    -Command 'kubectl delete -f m03-crds-demo/backuppolicy-crd.yaml --ignore-not-found'
Write-Host "$($Script:NeonGreen)  >>> Module 3 complete. Rewind for another take:  .\Restore-CkaSnapshot.ps1 $PreHelmSnapshot$($Script:AnsiReset)"
Write-Host ""
#endregion
