<#
.SYNOPSIS
    Get the 3-node Hyper-V lab recording-ready for CKA Course 4 / Module 1
    (Authentication, Authorization, and RBAC Fundamentals).

.DESCRIPTION
    One command between "my VMs are off" and "I can hit record." It boots the
    lab, proves the cluster is actually healthy, stages the module's exercise
    files on the control plane, GATES the five RBAC facts the deck asserts out
    loud, scrubs anything a prior take left behind, and checkpoints the result.

    WHY A FACT GATE. This module says five specific things on camera -- for
    example "view never reads Secrets" and "edit reads AND writes them." Those
    are properties of the cluster's bootstrapped RBAC policy, not of the deck.
    If a future Kubernetes release changes one, the deck becomes wrong and the
    only place you would find out is mid-take. So the gate asks the live
    cluster all five and refuses a green light on any drift. An assertion about
    your own content proves nothing; the cluster's answer proves something.

    WHAT IT DOES NOT DO. It never drives the demo. Module 1 is typed live on
    camera, because watching a human build a Role is the pedagogy. This script
    only guarantees the starting frame is identical every take.

    IDEMPOTENT. Safe to re-run between takes, and cheap -- a warm re-run is
    about 20 seconds because the boot and bootstrap steps no-op.

.PARAMETER Bootstrap
    Run kubeadm init on control1 and join both workers. Use this ONCE, on VMs
    that have been provisioned (containerd + kubeadm installed) but never had a
    cluster created on them. Skipped automatically if a cluster already answers.

.PARAMETER SkipBoot
    Do not call vagrant up. Use when the VMs are already running and you just
    want the verify + stage + gate + scrub passes.

.PARAMETER SkipSnapshot
    Do not checkpoint at the end. Use for a quick mid-sprint reset when you
    already hold a good save point.

.PARAMETER SnapshotName
    Checkpoint name written at the end. Default 'c04-m01-rbac-ready'.

.PARAMETER Node
    The control-plane node to drive. Default 'control1'.

.EXAMPLE
    .\Initialize-C04M01Lab.ps1
    The normal path. Boot, verify, stage, gate, scrub, checkpoint.

.EXAMPLE
    .\Initialize-C04M01Lab.ps1 -Bootstrap
    First run on freshly provisioned VMs -- also does kubeadm init and the joins.

.EXAMPLE
    .\Initialize-C04M01Lab.ps1 -SkipBoot -SkipSnapshot
    Fast reset between takes on an already-running lab.

.NOTES
    Author:  Tim Warner | CKA lab (control1, worker1, worker2)
    Run as:  Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab
             (Hyper-V cmdlets require elevation, every time, no exceptions)
    Pairs with: exercise-files\course-04-rbac-admission\m01-rbac-fundamentals\c04-m01-demo-runbook.md
    Exit codes: 0 = recording-ready, 1 = a gate failed (read the [ERROR] lines)
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Bootstrap,
    [switch]$SkipBoot,
    [switch]$SkipSnapshot,

    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName = 'c04-m01-rbac-ready',

    [ValidateNotNullOrEmpty()]
    [string]$Node = 'control1'
)

$ErrorActionPreference = 'Stop'
# Several probes below are EXPECTED to exit nonzero (a 403 is a passing result
# in an RBAC course). Native exit codes must not abort the script.
$PSNativeCommandUseErrorActionPreference = $false

. (Join-Path -Path $PSScriptRoot -ChildPath 'lib\CkaLab.ps1')
Initialize-LabEncoding
Initialize-LabPath

$AllVMs      = Get-CkaLabVMs
$LabNodes    = Get-CkaLabNodes
$RemoteBase  = '/home/vagrant/m01'
$ExpectMinor = '1.35'
$Failures    = [System.Collections.Generic.List[string]]::new()
$Script:LastNodeRC = -1

# Push-Location with no finally leaves the caller's location stack dirty on any
# terminating error. Register the pop on the engine's exit event so it happens
# whether we exit cleanly, throw, or the user hits Ctrl-C.
Push-Location $PSScriptRoot
$null = Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action {
    Pop-Location -ErrorAction SilentlyContinue
}

#region Helpers -----------------------------------------------------------------

function Invoke-Node {
    <#
    .SYNOPSIS
        Run one command on the control-plane node over `vagrant ssh` and return
        its stdout+stderr as a single trimmed string.
    .DESCRIPTION
        Returns text, never throws on a nonzero remote exit. Callers decide what
        a failure means -- in this module a 403 is frequently the pass condition.
    #>
    param([Parameter(Mandatory)][string]$Command)
    # Capture the REMOTE exit status too. Without it, a gate phrased as a
    # negative assertion ("this output must NOT contain 'secrets'") passes
    # whenever the command fails outright and prints nothing -- a false pass
    # on the exact check that is supposed to stop a bad recording.
    $out = vagrant ssh $Node -c "$Command; echo __RC__=`$?" 2>&1
    $text = ($out | Out-String)
    if ($text -match '__RC__=(\d+)') { $Script:LastNodeRC = [int]$Matches[1] }
    else { $Script:LastNodeRC = -1 }   # sentinel never arrived: ssh itself failed
    return (($text -replace '__RC__=\d+\s*', '').Trim())
}

function Test-Gate {
    <#
    .SYNOPSIS
        Assert one live-cluster fact. Records a failure instead of throwing so a
        single run reports EVERY drift, not just the first one.
    .PARAMETER Name
        Human-readable claim, phrased the way Tim says it on camera.
    .PARAMETER Command
        The command whose output is evaluated on the node.
    .PARAMETER Match
        Regex the output must match for the gate to pass.
    .PARAMETER ShouldNotMatch
        Invert the test: the gate passes only when the regex does NOT match.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Match,
        [switch]$ShouldNotMatch
    )
    $out  = Invoke-Node -Command $Command
    $rc   = $Script:LastNodeRC

    # A negative assertion is only meaningful if the command actually RAN.
    # "output does not contain 'secrets'" is trivially true of an error, so
    # require exit 0 before believing a ShouldNotMatch gate.
    if ($ShouldNotMatch -and $rc -ne 0) {
        Write-ErrorMsg "GATE FAIL  $Name"
        Write-Host  "           the command itself failed (remote exit $rc), so the"
        Write-Host  "           'must not match' result proves nothing."
        Write-Host  "           command : $Command"
        Write-Host  "           got     : $(if ($out) { ($out -split "`n")[0] } else { '<empty>' })"
        $Failures.Add($Name)
        return
    }

    $hit  = $out -match $Match
    $pass = if ($ShouldNotMatch) { -not $hit } else { $hit }

    if ($pass) {
        Write-Success "GATE PASS  $Name"
    }
    else {
        Write-ErrorMsg "GATE FAIL  $Name"
        Write-Host  "           command : $Command"
        Write-Host  "           expected: $(if ($ShouldNotMatch) { 'NO match for' } else { 'match for' }) /$Match/"
        Write-Host  "           got     : $(if ($out) { ($out -split "`n")[0] } else { '<empty>' })"
        $Failures.Add($Name)
    }
}

function Wait-NodeSsh {
    <#
    .SYNOPSIS
        Block until every lab VM answers a trivial SSH command, or time out.
    #>
    param([int]$TimeoutSeconds = 240)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    foreach ($n in $LabNodes) {
        Write-Info "Waiting for SSH on $($n.Name) ($($n.IP))..."
        do {
            $probe = (vagrant ssh $n.Name -c 'echo __UP__' 2>&1 | Out-String)
            if ($probe -match '__UP__') { Write-Success "$($n.Name) is answering"; break }
            Start-Sleep -Seconds 5
        } while ((Get-Date) -lt $deadline)

        if ($probe -notmatch '__UP__') {
            Write-ErrorMsg "$($n.Name) never answered SSH within $TimeoutSeconds seconds."
            $Failures.Add("SSH timeout on $($n.Name)")
        }
    }
}

function Push-ModuleAssets {
    <#
    .SYNOPSIS
        Copy the M01 exercise files onto the node as LF-normalized text.
    .DESCRIPTION
        Same stdin->ssh path the rest of the lab uses: one source of truth in the
        repo, no Vagrant synced-folder dependency, and CRLF can never reach a
        bash script. Also lands setup-contexts.sh in the home directory as the
        on-camera safety net.
    #>
    $srcDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..\exercise-files\course-04-rbac-admission\m01-rbac-fundamentals')).Path
    $ctxSrc = (Resolve-Path (Join-Path $PSScriptRoot '..\..\exercise-files\course-04-rbac-admission\setup-contexts.sh')).Path

    # Clear the CONTENTS, never the directory itself. `rm -rf ~/m01` yanks the
    # working directory out from under any SSH session Tim already has open
    # there, and his next `./lab.sh` fails with a cryptic "No such file or
    # directory" for the cwd rather than for the script.
    [void](Invoke-Node -Command "mkdir -p '$RemoteBase' ~/certs && rm -f '$RemoteBase'/*")

    # BOM TRAP. lib\CkaLab.ps1 sets $global:OutputEncoding to
    # [System.Text.Encoding]::UTF8, whose .NET preamble is EF BB BF. Piping a
    # string to a native command uses $OutputEncoding, so every file we `cat >`
    # onto the node lands with a BOM in front of byte 0. For a shell script that
    # means the shebang is no longer at the start of the file and `./lab.sh`
    # dies with a bad-interpreter error that looks nothing like its cause.
    # Swap in a BOM-less encoder for the duration of the copy, then restore.
    $savedEncoding = $global:OutputEncoding
    $global:OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    try {
        $files = Get-ChildItem -Path $srcDir -File | Where-Object { $_.Name -ne '.gitkeep' }
        foreach ($f in $files) {
            $body = (Get-Content -Raw -LiteralPath $f.FullName) -replace "`r`n", "`n"
            $body | vagrant ssh $Node -c "cat > '$RemoteBase/$($f.Name)'"
        }

        $ctxBody = (Get-Content -Raw -LiteralPath $ctxSrc) -replace "`r`n", "`n"
        $ctxBody | vagrant ssh $Node -c 'cat > ~/setup-contexts.sh'
    }
    finally {
        $global:OutputEncoding = $savedEncoding
    }

    # `cat >` creates files 0644. The runbook types `./reset.sh` on camera,
    # and "Permission denied" is a rotten thing to meet mid-take -- so set
    # the execute bit on every .sh we just pushed. Cheap, and idempotent.
    [void](Invoke-Node -Command "chmod +x '$RemoteBase'/*.sh ~/setup-contexts.sh 2>/dev/null; true")

    # Verify rather than assume: a runbook that says ./reset.sh must have a
    # reset.sh that actually executes.
    # Verify BOTH the execute bit AND that byte 0 is '#' -- if a BOM slipped
    # through, the shebang is broken and ./lab.sh fails on camera with an error
    # that points nowhere useful. `head -c1` is the cheapest possible proof.
    $execCheck = Invoke-Node -Command "test -x '$RemoteBase/lab.sh' && [ `"`$(head -c1 '$RemoteBase/lab.sh')`" = '#' ] && echo __EXEC_OK__ || echo __EXEC_BAD__"
    if ($execCheck -match '__EXEC_OK__') {
        Write-Success "Staged $($files.Count) file(s) in $RemoteBase (lab.sh executable), plus ~/setup-contexts.sh"
    }
    else {
        Write-ErrorMsg "$RemoteBase/lab.sh is not executable -- './lab.sh mint' will fail on camera."
        $Failures.Add('lab.sh missing the execute bit')
    }
}

#endregion

#region Banner ------------------------------------------------------------------

Clear-Host
Write-Host ""
Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
Write-Host "$($Script:NeonGreen)  CKA COURSE 4 / MODULE 1  --  RBAC FUNDAMENTALS$($Script:AnsiReset)"
Write-Host "$($Script:NeonGreen)  Lab bring-up, health check, fact gate, and clean starting frame$($Script:AnsiReset)"
Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
Write-Host ""
Write-Host "  Nodes      : $($AllVMs -join ', ')"
Write-Host "  Driving    : $Node"
Write-Host "  Kubernetes : v$ExpectMinor expected"
Write-Host "  Checkpoint : $(if ($SkipSnapshot) { '<skipped>' } else { $SnapshotName })"
Write-Host ""
Write-HostMemory

#endregion

#region 1. Boot -----------------------------------------------------------------

if ($SkipBoot) {
    Write-Warn '-SkipBoot set: assuming the VMs are already running.'
}
elseif ($PSCmdlet.ShouldProcess(($AllVMs -join ', '), 'vagrant up --no-provision')) {
    Write-Step 'Booting the lab VMs (no re-provision)'
    # --no-provision matters: a plain `vagrant up` would re-run the whole prereq
    # shell provisioner on every boot, which is 6+ minutes you never need again.
    vagrant up --no-provision
    Wait-NodeSsh
}

#endregion

#region 2. Bootstrap the cluster (first run only) -------------------------------

Write-Step 'Checking whether a cluster already exists'
$apiProbe = Invoke-Node -Command 'kubectl get --raw=/readyz 2>/dev/null || echo __NOCLUSTER__'

if ($apiProbe -match '__NOCLUSTER__' -or $apiProbe -notmatch 'ok') {
    if (-not $Bootstrap) {
        Write-ErrorMsg 'No cluster is answering on this lab, and -Bootstrap was not set.'
        Write-Info     'Re-run with:  .\Initialize-C04M01Lab.ps1 -Bootstrap'
        Pop-Location
        exit 1
    }

    # DELIBERATELY NOT bootstrap_cp.sh. That script installs Flannel on
    # 10.244.0.0/16, which is a Course 1 leftover -- the course has taught
    # CALICO via the Tigera operator since Course 2 Module 3, on pod CIDR
    # 192.168.0.0/16 (Calico's default Installation CR ships that exact
    # range, and C02 M03 Step 1.0 proves the alignment on camera). Booting
    # this lab on Flannel/10.244 would silently contradict three recorded
    # modules. Versions pinned to match c02-m03-demo-runbook.md exactly.
    Write-Step 'No cluster found -- kubeadm init on the control plane (Calico, pod CIDR 192.168.0.0/16)'
    vagrant ssh $Node -c @'
set -euo pipefail
sudo kubeadm init \
  --apiserver-advertise-address=192.168.50.10 \
  --pod-network-cidr=192.168.0.0/16
mkdir -p "$HOME/.kube"
sudo cp -f /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
'@ 2>&1 | ForEach-Object { Write-Host "    $_" }

    Write-Step 'Installing Calico via the Tigera operator (pinned v3.29.1 -- same as C02 M03)'
    vagrant ssh $Node -c @'
set -euo pipefail
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/custom-resources.yaml
'@ 2>&1 | ForEach-Object { Write-Host "    $_" }

    foreach ($w in ($LabNodes | Where-Object { $_.Name -ne $Node })) {
        Write-Step "Joining $($w.Name) to the cluster"
        vagrant ssh $w.Name -c 'bash /vagrant/join_worker.sh' 2>&1 | ForEach-Object { Write-Host "    $_" }
    }

    Write-Warn 'FYI: src/cka-lab/bootstrap_cp.sh still installs Flannel on 10.244.0.0/16.'
    Write-Warn '     It is a Course 1 leftover and disagrees with C02 M03. Worth deleting or updating.'
}
else {
    Write-Success 'A cluster is already answering -- skipping kubeadm init'
}

#endregion

#region 3. Verify cluster health ------------------------------------------------

Write-Step 'Verifying the cluster the deck promises on slide 19'

# The API server can answer /readyz seconds before the CNI settles, so wait on
# node readiness rather than trusting the first probe.
$nodesReady = $false
foreach ($attempt in 1..40) {
    $ready = Invoke-Node -Command "kubectl get nodes --no-headers 2>/dev/null | grep -cw Ready"
    if ($ready -match '^\s*3\s*$') { $nodesReady = $true; break }
    Start-Sleep -Seconds 5
}

if ($nodesReady) {
    Write-Success 'All 3 nodes report Ready'
}
else {
    # KNOWN LAB GOTCHA (same one Invoke-M03Lab.ps1 handles): restoring a
    # Hyper-V checkpoint invalidates Calico's CNI token, so new pods fail with
    # "calico ... ClusterInformation: Unauthorized" and nodes sit NotReady
    # until calico-node is bounced. This course runs CALICO via the Tigera
    # operator (calico-system/calico-node) -- that is the C02 M03 standard.
    # The awk still matches generically so a future CNI swap degrades to a
    # warning instead of a silent no-op.
    Write-Warn 'Nodes not all Ready -- bouncing calico-node (known checkpoint-restore gotcha)'
    # NOTE ON QUOTING: an earlier version wrote  print `$1\" \"`$2  inside a
    # double-quoted PowerShell string. The \" does NOT escape a quote in
    # PowerShell -- it ends the string -- so the argument silently split and the
    # awk program reached the node malformed. Single-quoted here-strings avoid
    # the whole class of bug: nothing is interpolated, so $1 and $2 arrive intact.
    $cniAwk = @'
kubectl get ds -A --no-headers 2>/dev/null | awk '/calico-node/{print $1" "$2; exit}'
'@
    $cniLine = Invoke-Node -Command $cniAwk
    if (-not ($cniLine -match '^\S+\s+\S+$')) {
        Write-Warn 'calico-node daemonset not found -- falling back to any CNI daemonset'
        $cniFallback = @'
kubectl get ds -A --no-headers 2>/dev/null | awk '/cilium|flannel|weave/{print $1" "$2; exit}'
'@
        $cniLine = Invoke-Node -Command $cniFallback
    }
    if ($cniLine -match '^(\S+)\s+(\S+)$') {
        $cniNs = $Matches[1]; $cniDs = $Matches[2]
        [void](Invoke-Node -Command "kubectl -n $cniNs rollout restart daemonset/$cniDs")
        Invoke-Node -Command "kubectl -n $cniNs rollout status daemonset/$cniDs --timeout=150s" | ForEach-Object { Write-Host "    $_" }
        $ready = Invoke-Node -Command "kubectl get nodes --no-headers 2>/dev/null | grep -cw Ready"
        if ($ready -match '^\s*3\s*$') { Write-Success 'CNI healed -- all 3 nodes Ready'; $nodesReady = $true }
    }
    if (-not $nodesReady) { $Failures.Add('Cluster never reached 3 Ready nodes') }
}

# `sort -u` collapses to ONE line only when every node agrees. A substring
# -match would happily pass a mixed 1.34/1.35 cluster because "v1.35" appears
# somewhere in the blob -- which is exactly the cluster you must not record on.
# So: require exactly one distinct version, and require it to start with v1.35.
$version = (Invoke-Node -Command "kubectl get nodes --no-headers -o custom-columns=V:.status.nodeInfo.kubeletVersion | sort -u | tr -d ' '")
$versions = @($version -split "`n" | Where-Object { $_ -match '\S' } | ForEach-Object { $_.Trim() })
if ($versions.Count -eq 1 -and $versions[0].StartsWith("v$ExpectMinor.")) {
    Write-Success "Kubelet version is $($versions[0]) on all 3 nodes"
}
elseif ($versions.Count -gt 1) {
    Write-ErrorMsg "MIXED versions across nodes: $($versions -join ', ') -- do not record on this cluster"
    $Failures.Add("Mixed Kubernetes versions: $($versions -join ', ')")
}
else {
    Write-ErrorMsg "Expected v$ExpectMinor.x on every node, found: $version"
    $Failures.Add("Wrong Kubernetes version: $version")
}

$runtime = Invoke-Node -Command "kubectl get nodes --no-headers -o custom-columns=R:.status.nodeInfo.containerRuntimeVersion | sort -u"
if ($runtime -match 'containerd') { Write-Success "Container runtime is containerd" }
else { Write-Warn "Runtime reads '$runtime' -- the deck says containerd on camera" }

#endregion

#region 4. Stage exercise files + contexts --------------------------------------

Write-Step 'Staging the module exercise files on the control plane'
Push-ModuleAssets

Write-Step 'Ensuring the cka-vagrant admin context exists'
# kubeadm writes 'kubernetes-admin@kubernetes', which is long and looks identical
# to every other kubeadm cluster on screen. Rename once so the on-camera context
# name is unambiguous. Idempotent.
$ctxOut = Invoke-Node -Command @'
if kubectl config get-contexts -o name | grep -qx cka-vagrant; then
  echo "__EXISTS__"
else
  kubectl config rename-context kubernetes-admin@kubernetes cka-vagrant && echo "__RENAMED__"
fi
kubectl config use-context cka-vagrant >/dev/null
'@
if ($ctxOut -match '__EXISTS__')      { Write-Success 'Context cka-vagrant already present' }
elseif ($ctxOut -match '__RENAMED__') { Write-Success 'Renamed kubernetes-admin@kubernetes -> cka-vagrant' }
else { Write-Warn "Could not confirm the cka-vagrant context: $ctxOut"; $Failures.Add('cka-vagrant context missing') }

#endregion

#region 5. The fact gate --------------------------------------------------------

Write-Step 'Fact gate -- the five claims this module makes out loud'

# CLAIM 1. A user with zero grants can still call `kubectl auth whoami`, because
# system:basic-user is bound to the system:authenticated group. This is what makes
# Beat 1 land: identity is free, authorization is not.
Test-Gate -Name 'system:basic-user is bound to system:authenticated' `
          -Command "kubectl get clusterrolebinding system:basic-user -o jsonpath='{.subjects}'" `
          -Match   'system:authenticated'

# CLAIM 2. view never reads Secrets. Deck slides 14, 15, and 25 all say so.
# Deliberately jsonpath and NOT `describe | grep`: grep exits 1 when it finds
# nothing, which is indistinguishable from the whole command failing. jsonpath
# exits 0 and prints the full resource list, so "no match" is real evidence.
Test-Gate -Name 'view has NO rule mentioning Secrets' `
          -Command "kubectl get clusterrole view -o jsonpath='{range .rules[*]}{.resources}{`"|`"}{end}'" `
          -Match   'secrets' -ShouldNotMatch

# CLAIM 3. edit reads AND writes Secrets -- the most-missed fact on the exam.
Test-Gate -Name 'edit can write Secrets (create/delete/patch/update)' `
          -Command "kubectl get clusterrole edit -o jsonpath='{range .rules[*]}{.resources}{`" `"}{.verbs}{`"\n`"}{end}' | grep secrets" `
          -Match   'update|patch|create'

# CLAIM 4. view covers Namespaces. This is precisely why Beat 3's
# ClusterRoleBinding lets frontend-dev run `kubectl get namespaces` and the
# RoleBinding never can. If this drifts, Beat 3 breaks on camera.
Test-Gate -Name 'view covers Namespaces (cluster-scoped reach for Beat 3)' `
          -Command "kubectl get clusterrole view -o jsonpath='{range .rules[*]}{.resources}{`"\n`"}{end}' | grep namespaces" `
          -Match   'namespaces'

# CLAIM 5. edit is aggregated by label selector, not hand-written. Beat 4 shows
# the aggregationRule block on screen.
Test-Gate -Name 'edit is composed via aggregationRule, not hand-written rules' `
          -Command "kubectl get clusterrole edit -o jsonpath='{.aggregationRule}'" `
          -Match   'aggregate-to-edit'

#endregion

#region 6. Scrub to the starting frame ------------------------------------------

Write-Step 'Scrubbing anything a prior take left behind'
# Delegate to `./lab.sh reset` rather than duplicating the delete list here.
# ONE definition of "frame zero", used by the host bring-up and by Tim between
# takes -- so the two can never drift apart. lab.sh guards against a false
# green (it refuses to report clean when it cannot reach the API server), and
# its nonzero exit is what we key on.
$scrub = Invoke-Node -Command "cd $RemoteBase && ./lab.sh reset 2>&1; echo __RC__=`$?"
$scrub -split "`n" | Where-Object { $_ -match '\S' } | ForEach-Object { Write-Host "    $_" }
if ($scrub -match '__RC__=0') {
    Write-Success 'Starting frame is clean -- no dev-team, no frontend-dev'
}
else {
    Write-ErrorMsg 'lab.sh reset did not report a clean starting frame.'
    $Failures.Add('Reset to frame zero failed')
}

#endregion

#region 7. Checkpoint -----------------------------------------------------------

if ($SkipSnapshot) {
    Write-Warn '-SkipSnapshot set: no checkpoint written.'
}
elseif ($Failures.Count -gt 0) {
    Write-Warn 'Gates failed -- refusing to checkpoint a lab that is not recording-ready.'
}
elseif ($PSCmdlet.ShouldProcess(($AllVMs -join ', '), "Save checkpoint '$SnapshotName'")) {
    Write-Step "Checkpointing all 3 VMs as '$SnapshotName'"
    & (Join-Path $PSScriptRoot 'Save-CkaSnapshot.ps1') $SnapshotName
}

#endregion

#region 8. Verdict --------------------------------------------------------------

Write-Host ""
Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"

if ($Failures.Count -eq 0) {
    Write-Success 'Lab is recording-ready for C04 M01'
    Write-Host ""
    Write-Host "  Next:  ssh vagrant@$(($LabNodes | Where-Object Name -eq $Node).IP)"
    Write-Host "         cd ~/m01                            # every script and manifest lives here"
    Write-Host "         ./lab.sh                            # reset + verify, writes ~/dry-run.txt"
    Write-Host "         kubectl config current-context      # cka-vagrant"
    Write-Host ""
    Write-Host "  Runbook: exercise-files\course-04-rbac-admission\m01-rbac-fundamentals\c04-m01-demo-runbook.md"
    Write-Host "           Demo 1 opens at [1.0] -- the context command, not [1.1]"
    Write-Host "  Safety net if the live mint goes sideways:  ./lab.sh mint"
    Write-Host ""
    Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
    Pop-Location
    exit 0
}

Write-ErrorMsg "NOT recording-ready -- $($Failures.Count) problem(s):"
$Failures | ForEach-Object { Write-Host "    - $_" }
Write-Host ""
Write-Info 'A failed GATE means the cluster disagrees with the deck. Do not record.'
Write-Info 'Re-ground the affected slide against kubernetes.io before the take.'
Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
Pop-Location
exit 1

#endregion
