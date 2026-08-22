<#
.SYNOPSIS
    Get the 3-node Hyper-V lab recording-ready for CKA Course 4 / Module 3
    (Admission Controls, Resource Limits, and Governance).

.DESCRIPTION
    One command between "my VMs are off" and "I can hit record." It boots the
    lab, proves the cluster is actually healthy, stages the module's exercise
    files on the control plane, GATES the seven admission facts the deck asserts
    out loud, scrubs the cluster back to frame zero for Demo 1, and checkpoints
    the result.

    WHY A FACT GATE. This module says seven specific things on camera -- for
    example "LimitRanger writes requests.cpu 100m and limits.cpu 500m into a Pod
    that named neither", "bare cpu in a ResourceQuota means requests, never
    limits", and "ResourceQuota validates LAST, so Pod Security speaks first".
    Every one of those is a property of THIS API server's admission chain, not a
    property of the deck. If a future Kubernetes release reorders a plugin,
    renames a message, or tightens a Pod Security Standard, the deck becomes
    wrong and the only place you would find out is mid-take. So the gate asks
    the live cluster all seven and refuses a green light on any drift. An
    assertion about your own content proves nothing; the cluster's answer proves
    something.

    AND EVERY GATE USES THE RIGHT INSTRUMENT. A gate that measures the claim
    with the wrong tool is worse than no gate, because it fails forever and you
    learn to ignore it. So: plugin enablement is proven by BEHAVIOUR (a mutation
    that appears, a refusal that arrives), never by grepping a --enable-admission-plugins
    flag string. Quota semantics are read off a LIVE quota object's status.used,
    not inferred from the YAML you submitted. Plugin ORDER is proven by which of
    two simultaneous violations is the one reported. And the restricted-vs-baseline
    question is answered by submitting the real manifest into a namespace labeled
    enforce=restricted and letting Pod Security Admission itself rule on it.

    WHAT IT DOES NOT DO. It never drives the demo. Module 3 is typed live on
    camera, because watching a human trip an admission controller is the
    pedagogy. This script only guarantees the starting frame is identical every
    take -- and Demo 1 opens on a cluster with NO production namespace, so the
    scrub is part of the contract, not housekeeping.

    ACCESSIBILITY. Every status line is labeled in WORDS -- [OK], [FAIL],
    [WARN], GATE PASS, GATE FAIL -- because colour alone is not a signal this
    author can read. Never encode a result in colour only.

    IDEMPOTENT. Safe to re-run between takes. A warm re-run is about 3 minutes:
    boot and bootstrap no-op, and the gate spends most of its time waiting for
    one image pull and one Ready condition.

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
    Checkpoint name written at the end. Default 'c04-m03-rbac-ready'.

.PARAMETER Node
    The control-plane node to drive. Default 'control1'.

.EXAMPLE
    .\Initialize-C04M03Lab.ps1
    The normal path. Boot, verify, stage, gate, scrub, checkpoint.

.EXAMPLE
    .\Initialize-C04M03Lab.ps1 -Bootstrap
    First run on freshly provisioned VMs -- also does kubeadm init and the joins.

.EXAMPLE
    .\Initialize-C04M03Lab.ps1 -SkipBoot -SkipSnapshot
    Fast reset between takes on an already-running lab.

.NOTES
    Author:  Tim Warner | CKA lab (control1, worker1, worker2)
    Run as:  Administrator PowerShell 7+, from C:\github\ps-cka\src\cka-lab
             (Hyper-V cmdlets require elevation, every time, no exceptions)
    Pairs with: exercise-files\course-04-rbac-admission\m03-admission-controls\
    Exit codes: 0 = recording-ready, 1 = a gate failed (read the [ERROR] lines)

    WHAT GATE 7 IS ACTUALLY ASSERTING. As shipped, hardened-pod.yaml sets
    runAsNonRoot/runAsUser/readOnlyRootFilesystem/allowPrivilegeEscalation=false
    but NOT seccompProfile and NOT capabilities.drop=["ALL"]. That makes it a
    BASELINE pod, not a restricted one -- and that is CORRECT, because
    CKA-C04-M03-RUNBOOK.md step 24 says "This Pod satisfies baseline". Manifest
    and narration agree, so gate 7 PASSES on baseline and only raises a warning
    if the manifest ever drifts up to restricted without the runbook following.
    Do not "fix" this by failing on baseline; a gate that red-lights a settled
    decision is a gate you learn to ignore.
#>

#Requires -Version 7.0
#Requires -RunAsAdministrator

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Bootstrap,
    [switch]$SkipBoot,
    [switch]$SkipSnapshot,

    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName = 'c04-m03-rbac-ready',

    [ValidateNotNullOrEmpty()]
    [string]$Node = 'control1'
)

$ErrorActionPreference = 'Stop'
# Most probes below are EXPECTED to exit nonzero. A Forbidden is a PASSING
# result in an admission-control course, so native exit codes must not abort
# the script.
$PSNativeCommandUseErrorActionPreference = $false

. (Join-Path -Path $PSScriptRoot -ChildPath 'lib\CkaLab.ps1')
Initialize-LabEncoding
Initialize-LabPath

$AllVMs      = Get-CkaLabVMs
$LabNodes    = Get-CkaLabNodes
$RemoteBase  = '/home/vagrant/m03'
$ExpectMinor = '1.35'
$Failures    = [System.Collections.Generic.List[string]]::new()
$Script:LastNodeRC = -1

# Four throwaway namespaces, all labeled cka-gate=probe so the teardown is one
# label selector instead of four names that can drift out of sync. NONE of them
# is 'production' -- the gate must never touch the namespace Demo 1 creates on
# camera, or the scrub would be deleting the gate's own mess and calling the
# cluster clean.
$ProbeNs           = 'gateprobe'             # LimitRange + enforce=baseline
$ProbeQuotaNs      = 'gateprobe-quota'       # bare cpu/memory ResourceQuota
$ProbeOrderNs      = 'gateprobe-order'       # exhausted quota + enforce=baseline
$ProbeRestrictedNs = 'gateprobe-restricted'  # enforce=restricted
$ProbeNamespaces   = @($ProbeNs, $ProbeQuotaNs, $ProbeOrderNs, $ProbeRestrictedNs)

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
        a failure means -- in this module a Forbidden is frequently the pass
        condition.
    #>
    param([Parameter(Mandatory)][string]$Command)
    # Capture the REMOTE exit status too. Without it, a gate phrased as a
    # negative assertion ("this output must NOT contain 'exceeded quota'")
    # passes whenever the command fails outright and prints nothing -- a false
    # pass on the exact check that is supposed to stop a bad recording.
    # NEWLINE, not "; ". Every gate command below is a multi-line script, and a
    # semicolon appended after a trailing newline produces a line that STARTS
    # with ';' -- a bash syntax error.
    $out = vagrant ssh $Node -c "$Command`necho __RC__=`$?" 2>&1
    $text = ($out | Out-String)
    if ($text -match '__RC__=(\d+)') { $Script:LastNodeRC = [int]$Matches[1] }
    else { $Script:LastNodeRC = -1 }   # sentinel never arrived: ssh itself failed
    return (($text -replace '__RC__=\d+\s*', '').Trim())
}

function Expand-RemoteScript {
    <#
    .SYNOPSIS
        Fill the placeholders in a single-quoted here-string command.
    .DESCRIPTION
        Every remote command in this script is a SINGLE-quoted here-string, so
        nothing PowerShell-ish can happen to the $VAR references and "quotes"
        that bash needs. But some of them still have to know a host-side value
        (the staging directory, the probe namespace names). Interpolating would
        mean switching to a double-quoted here-string, and in a double-quoted
        PowerShell string \" does NOT escape a quote -- it ENDS the string, so
        every embedded JSON override would silently split and reach the remote
        shell malformed.

        So: literal placeholders, replaced with String.Replace (ordinal, not
        regex -- no metacharacter surprises) after the here-string is closed.
    #>
    param([Parameter(Mandatory)][string]$Template)
    return $Template.
        Replace('__BASE__', $RemoteBase).
        Replace('__NSR__',  $ProbeRestrictedNs).
        Replace('__NSQ__',  $ProbeQuotaNs).
        Replace('__NSO__',  $ProbeOrderNs).
        Replace('__NS__',   $ProbeNs)
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
    $out = Invoke-Node -Command $Command
    $rc  = $Script:LastNodeRC

    # A negative assertion is only meaningful if the command actually RAN.
    # "output does not contain 'exceeded quota'" is trivially true of an error,
    # so require exit 0 before believing a ShouldNotMatch gate.
    if ($ShouldNotMatch -and $rc -ne 0) {
        Write-ErrorMsg "GATE FAIL  $Name"
        Write-Host  "           the command itself failed (remote exit $rc), so the"
        Write-Host  "           'must not match' result proves nothing."
        Write-Host  "           command : $(($Command -split "`n")[0]) ..."
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
        Write-Host  "           expected: $(if ($ShouldNotMatch) { 'NO match for' } else { 'match for' }) /$Match/"
        Write-Host  "           got     : $(if ($out) { ($out -split "`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 1) } else { '<empty>' })"
        Write-Host  "           command : $(($Command -split "`n" | Where-Object { $_ -match '\S' })[0]) ..."
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

function Copy-StringToNode {
    <#
    .SYNOPSIS
        Copy an in-memory string to a file on the node WITHOUT piping to
        `vagrant ssh`. Returns $true only when SHA256 matches on both sides.
    .DESCRIPTION
        THE DEADLOCK WARNING, and it is not theoretical -- it cost a whole
        evening. The obvious way,

            $body | vagrant ssh $Node -c "cat > file"

        DEADLOCKS. vagrant ssh wraps ssh in a Ruby process, and the remote `cat`
        sits waiting for an EOF on stdin that never propagates through that
        wrapper, so the whole script hangs at the staging step with no output
        and no timeout. (Observed live: the ruby and vagrant processes stay
        resident, burning a few CPU-seconds, forever.) There is no timeout to
        rescue you and no message to tell you why.

        So: no stdin at all. Base64 the content and carry it INSIDE the command
        string, appended in chunks because a Windows command line caps out
        around 32767 characters and these files are bigger than that once
        encoded.

        Three bugs die with one change:
          * the stdin deadlock above;
          * BOM corruption -- we choose the exact bytes here, so $OutputEncoding
            can never prepend EF BB BF ahead of a shebang;
          * CRLF -- normalized before encoding, so line endings cannot depend on
            how git checked the file out on Windows.

        Then it VERIFIES by comparing SHA256 on both sides, because "the command
        did not error" is not the same as "the bytes arrived".
    #>
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$RemotePath,
        [Parameter(Mandatory)][string]$Label
    )

    $body  = $Content -replace "`r`n", "`n"
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($body)
    $b64   = [Convert]::ToBase64String($bytes)

    # Local hash of exactly the bytes we are about to send.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $localHash = ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLower()
    $sha.Dispose()

    [void](Invoke-Node -Command ": > '$RemotePath.b64'")

    # 6000 chars leaves generous headroom under the command-line cap once the
    # ssh/vagrant wrapper and the __RC__ sentinel are added around it.
    $chunkSize = 6000
    for ($i = 0; $i -lt $b64.Length; $i += $chunkSize) {
        $part = $b64.Substring($i, [Math]::Min($chunkSize, $b64.Length - $i))
        # printf '%s', not echo: echo mangles backslashes on some shells and
        # base64 is backslash-free anyway, but printf is the portable choice.
        [void](Invoke-Node -Command "printf '%s' '$part' >> '$RemotePath.b64'")
    }

    [void](Invoke-Node -Command "base64 -d < '$RemotePath.b64' > '$RemotePath' && rm -f '$RemotePath.b64'")

    $remoteHash = (Invoke-Node -Command "sha256sum '$RemotePath' | cut -d' ' -f1").Trim()
    if ($remoteHash -ne $localHash) {
        Write-ErrorMsg "checksum mismatch copying $Label"
        Write-Host    "           local  : $localHash"
        Write-Host    "           remote : $remoteHash"
        $Failures.Add("Corrupt transfer: $Label")
        return $false
    }
    return $true
}

function Copy-TextToNode {
    <#
    .SYNOPSIS
        Copy one local text file to the node, LF-normalized and sha256-verified.
    .DESCRIPTION
        Thin wrapper over Copy-StringToNode -- see that function's deadlock
        warning for why this never pipes to `vagrant ssh`.
    #>
    param(
        [Parameter(Mandatory)][string]$LocalPath,
        [Parameter(Mandatory)][string]$RemotePath
    )
    return (Copy-StringToNode -Content (Get-Content -Raw -LiteralPath $LocalPath) `
                              -RemotePath $RemotePath `
                              -Label (Split-Path -Leaf $LocalPath))
}

function Push-ModuleAssets {
    <#
    .SYNOPSIS
        Copy the M03 exercise files onto the node as LF-normalized text.
    .DESCRIPTION
        STAGE EVERYTHING. The M02 initializer filtered staging through an
        explicit filename allowlist -- `$wanted -contains $_.Name` -- and the
        two helper scripts that were not on that four-name list silently never
        reached the node. The miss surfaced mid-session as "No such file or
        directory" for a file that was sitting right there in the repo. A
        transfer is a few seconds; a mid-take mystery is not.

        So the rule here is extension-based, not name-based: every *.yaml, *.sh
        and *.md in the module folder goes to the node. Anything NOT staged is
        printed by name with the reason, so a miss is visible on screen instead
        of silent. A REQUIRED set is still checked -- that catches a file that
        is missing from the repo, which is a different failure from a file this
        function chose to skip.
    #>
    # Test-Path before Resolve-Path. $ErrorActionPreference is 'Stop', so a bare
    # Resolve-Path on a missing folder terminates the whole run with a raw
    # .NET-flavoured error instead of a sentence that says what to fix.
    $srcDir = Join-Path $PSScriptRoot '..\..\exercise-files\course-04-rbac-admission\m03-admission-controls'
    if (-not (Test-Path -LiteralPath $srcDir)) {
        Write-ErrorMsg "Module folder not found: $srcDir"
        Write-Info     'Run this from src\cka-lab inside the ps-cka repo.'
        $Failures.Add('m03-admission-controls folder not found on the host')
        return
    }
    $srcDir = (Resolve-Path -LiteralPath $srcDir).Path
    $ctxSrc = Join-Path $PSScriptRoot '..\..\exercise-files\course-04-rbac-admission\setup-contexts.sh'

    # Clear the CONTENTS, never the directory itself. `rm -rf ~/m03` yanks the
    # working directory out from under any SSH session Tim already has open
    # there, and his next `./lab.sh` fails with a cryptic "No such file or
    # directory" for the cwd rather than for the script. The glob also leaves
    # the dot-prefixed .gate/ probe directory alone, which is deleted by name
    # during the scrub.
    [void](Invoke-Node -Command "mkdir -p '$RemoteBase' && rm -f '$RemoteBase'/*")

    $all     = @(Get-ChildItem -Path $srcDir -File)
    $stageMe = @($all | Where-Object { $_.Extension.ToLower() -in @('.yaml', '.yml', '.sh', '.md') })
    $skipped = @($all | Where-Object { $_.Extension.ToLower() -notin @('.yaml', '.yml', '.sh', '.md') })

    foreach ($s in $skipped) {
        # Never silent. If this line ever names something Tim needs, the fix is
        # one extension in the filter above -- but he can only fix what he sees.
        Write-Warn "  NOT staged: $($s.Name) (extension '$($s.Extension)' is not yaml/sh/md)"
    }

    # Each chunk is its own `vagrant ssh` round trip and those take a few
    # seconds apiece, so a silent staging step reads as a hang. Announce every
    # file and its size BEFORE the transfer starts.
    $n = 0
    $ok = 0
    foreach ($f in $stageMe) {
        $n++
        Write-Info "  [$n/$($stageMe.Count)] $($f.Name) ($([math]::Ceiling($f.Length / 1KB)) KB) -- transferring in chunks, this takes a few seconds"
        if (Copy-TextToNode -LocalPath $f.FullName -RemotePath "$RemoteBase/$($f.Name)") {
            Write-Success "  staged $($f.Name) (sha256 verified)"
            $ok++
        }
    }

    if (Test-Path -LiteralPath $ctxSrc) {
        Write-Info '  [extra] setup-contexts.sh (fallback identity builder)'
        [void](Copy-TextToNode -LocalPath (Resolve-Path -LiteralPath $ctxSrc).Path -RemotePath '/home/vagrant/setup-contexts.sh')
    }
    else {
        Write-Warn "  setup-contexts.sh not found at $ctxSrc -- commands.sh names it as a prerequisite"
        $Failures.Add('setup-contexts.sh missing from course-04-rbac-admission')
    }

    # `base64 -d >` creates files 0644. The runbook types `./lab.sh` on camera,
    # and "Permission denied" is a rotten thing to meet mid-take.
    [void](Invoke-Node -Command "chmod +x '$RemoteBase'/*.sh ~/setup-contexts.sh 2>/dev/null; true")

    # The REQUIRED set. Every one of these is named by the runbook or by
    # commands.sh, so a missing one is a broken take, not a preference.
    $required = @(
        'commands.sh', 'lab.sh',
        'limitrange.yaml', 'limitrange-ceiling.yaml', 'oversized-pod.yaml',
        'resourcequota.yaml', 'privileged-deployment.yaml', 'hardened-pod.yaml'
    )
    $missing = @($required | Where-Object { $_ -notin $stageMe.Name })
    if ($missing.Count -gt 0) {
        Write-ErrorMsg "Missing from the module folder: $($missing -join ', ')"
        $Failures.Add("Module folder is incomplete: $($missing -join ', ')")
    }

    # Verify BOTH the execute bit AND that byte 0 is '#' -- if a BOM slipped
    # through, the shebang is broken and ./lab.sh fails on camera with an error
    # that points nowhere useful. `head -c1` is the cheapest possible proof.
    # Checked for EVERY staged .sh, because commands.sh is also sourced by hand.
    foreach ($sh in @($stageMe | Where-Object { $_.Extension.ToLower() -eq '.sh' })) {
        $chk = Invoke-Node -Command "test -x '$RemoteBase/$($sh.Name)' && [ `"`$(head -c1 '$RemoteBase/$($sh.Name)')`" = '#' ] && echo __EXEC_OK__ || echo __EXEC_BAD__"
        if ($chk -match '__EXEC_OK__') {
            Write-Success "  $($sh.Name) is executable and starts with '#' (no BOM)"
        }
        else {
            Write-ErrorMsg "  $RemoteBase/$($sh.Name) is not executable, or byte 0 is not '#'"
            $Failures.Add("$($sh.Name) missing the execute bit or carrying a BOM")
        }
    }

    Write-Success "Staged $ok file(s) in $RemoteBase, plus ~/setup-contexts.sh"
}

function Push-GateProbeManifests {
    <#
    .SYNOPSIS
        Stage namespace-rewritten copies of the real manifests into
        $RemoteBase/.gate for the fact gate to use.
    .DESCRIPTION
        ONE source of truth for the numbers. The gate asserts 100m/500m/800m and
        1500m, and those numbers live in the module's manifests -- so the gate
        submits THOSE FILES rather than a hand-typed copy that can drift away
        from what the deck shows.

        The only edit is the namespace: every manifest says
        `namespace: production`, and the gate must never create anything in
        production (Demo 1 creates that namespace on camera, and the scrub must
        be able to prove the cluster is clean without deleting the gate's own
        droppings). So the namespace is rewritten to a throwaway probe
        namespace, and the rewrite is VERIFIED -- if a manifest ever stops
        saying `namespace: production`, this refuses to stage it rather than
        risk writing into production.
    #>
    $srcDir = Join-Path $PSScriptRoot '..\..\exercise-files\course-04-rbac-admission\m03-admission-controls'
    if (-not (Test-Path -LiteralPath $srcDir)) {
        Write-ErrorMsg "Module folder not found: $srcDir -- the fact gate cannot run"
        $Failures.Add('Gate probes cannot be built: module folder not found')
        return
    }
    $srcDir = (Resolve-Path -LiteralPath $srcDir).Path

    $map = @(
        @{ File = 'limitrange.yaml';            Ns = $ProbeNs;           As = 'limitrange.yaml' }
        @{ File = 'limitrange-ceiling.yaml';    Ns = $ProbeNs;           As = 'limitrange-ceiling.yaml' }
        @{ File = 'oversized-pod.yaml';         Ns = $ProbeNs;           As = 'oversized-pod.yaml' }
        @{ File = 'privileged-deployment.yaml'; Ns = $ProbeNs;           As = 'privileged-deployment.yaml' }
        @{ File = 'hardened-pod.yaml';          Ns = $ProbeNs;           As = 'hardened-pod.yaml' }
        @{ File = 'hardened-pod.yaml';          Ns = $ProbeRestrictedNs; As = 'hardened-pod-restricted.yaml' }
    )

    [void](Invoke-Node -Command "mkdir -p '$RemoteBase/.gate' && rm -f '$RemoteBase/.gate'/*")

    foreach ($m in $map) {
        $p = Join-Path $srcDir $m.File
        if (-not (Test-Path -LiteralPath $p)) {
            Write-ErrorMsg "  cannot build the probe copy: $($m.File) is not in the module folder"
            $Failures.Add("Gate probe cannot be built: $($m.File) missing")
            continue
        }

        $text = (Get-Content -Raw -LiteralPath $p) -replace "`r`n", "`n"
        if ($text -notmatch 'namespace:\s*production') {
            Write-ErrorMsg "  $($m.File) no longer targets 'namespace: production' -- refusing to guess"
            $Failures.Add("$($m.File) namespace changed; gate probe rewrite is unsafe")
            continue
        }

        $text = $text -replace 'namespace:\s*production', "namespace: $($m.Ns)"
        if ($text -match 'namespace:\s*production') {
            Write-ErrorMsg "  rewrite of $($m.File) left a reference to production -- refusing to stage"
            $Failures.Add("$($m.File) probe rewrite incomplete")
            continue
        }

        if (Copy-StringToNode -Content $text -RemotePath "$RemoteBase/.gate/$($m.As)" -Label "probe/$($m.As)") {
            Write-Success "  probe manifest $($m.As) -> namespace $($m.Ns) (sha256 verified)"
        }
    }
}

function Remove-GateProbes {
    <#
    .SYNOPSIS
        Delete every probe namespace and the staged probe manifests, and WAIT
        for the namespaces to actually go away.
    .DESCRIPTION
        --wait=false and move on would leave four Terminating namespaces inside
        the checkpoint, which means the next restore starts on a cluster that is
        mid-delete. `kubectl get ns` on camera would show them. So: fire the
        deletes without waiting (fast), then poll until they are gone.
    #>
    [void](Invoke-Node -Command 'kubectl delete ns -l cka-gate=probe --ignore-not-found --wait=false >/dev/null 2>&1; true')

    $gone = $false
    foreach ($attempt in 1..40) {
        $left = Invoke-Node -Command 'kubectl get ns -l cka-gate=probe --no-headers 2>/dev/null | wc -l | tr -d " "'
        if ($left -match '^\s*0\s*$') { $gone = $true; break }
        Start-Sleep -Seconds 3
    }

    [void](Invoke-Node -Command "rm -rf '$RemoteBase/.gate'; true")

    if ($gone) { Write-Success 'Probe namespaces are fully deleted and .gate is removed' }
    else {
        Write-Warn 'Probe namespaces are still Terminating after 120s -- do not checkpoint yet.'
        $Failures.Add('Gate probe namespaces did not finish terminating')
    }
}

#endregion

#region Banner ------------------------------------------------------------------

Clear-Host
Write-Host ""
Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
Write-Host "$($Script:NeonGreen)  CKA COURSE 4 / MODULE 3  --  ADMISSION CONTROLS, RESOURCE$($Script:AnsiReset)"
Write-Host "$($Script:NeonGreen)                             LIMITS, AND GOVERNANCE$($Script:AnsiReset)"
Write-Host "$($Script:NeonGreen)  Lab bring-up, health check, fact gate, and clean starting frame$($Script:AnsiReset)"
Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
Write-Host ""
Write-Host "  Nodes      : $($AllVMs -join ', ')"
Write-Host "  Driving    : $Node"
Write-Host "  Kubernetes : v$ExpectMinor expected"
Write-Host "  Staging to : $RemoteBase"
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
        Write-Info     'Re-run with:  .\Initialize-C04M03Lab.ps1 -Bootstrap'
        Pop-Location
        exit 1
    }

    # DELIBERATELY NOT bootstrap_cp.sh. That script installs Flannel on
    # 10.244.0.0/16, which is a Course 1 leftover -- the course has taught
    # CALICO via the Tigera operator since Course 2 Module 3, on pod CIDR
    # 192.168.0.0/16. Booting this lab on Flannel/10.244 would silently
    # contradict recorded modules. Versions pinned to match c02-m03.
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
}
else {
    Write-Success 'A cluster is already answering -- skipping kubeadm init'
}

#endregion

#region 3. Verify cluster health ------------------------------------------------

Write-Step 'Verifying the cluster the deck promises'

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
    # KNOWN LAB GOTCHA: restoring a Hyper-V checkpoint invalidates Calico's CNI
    # token, so new pods fail with "calico ... ClusterInformation: Unauthorized"
    # and nodes sit NotReady until calico-node is bounced. That matters double
    # in this module: gate 7 needs a Pod to actually reach Ready.
    Write-Warn 'Nodes not all Ready -- bouncing calico-node (known checkpoint-restore gotcha)'
    # NOTE ON QUOTING: single-quoted here-strings only. In a double-quoted
    # PowerShell string \" does NOT escape a quote -- it ends the string -- so
    # an awk program written that way reaches the node malformed.
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

Write-Step 'Staging the module exercise files on the control plane (every yaml, sh, and md)'
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

Write-Step 'Building the throwaway probe namespaces (nothing here touches production)'
Push-GateProbeManifests

# EVERY remote command below is a SINGLE-QUOTED here-string run through
# Expand-RemoteScript. That is not style. In a double-quoted PowerShell string
# \" does NOT escape a quote -- it ENDS the string, so the argument silently
# splits and reaches the remote shell malformed. These commands are full of
# embedded quotes (jsonpath, --overrides JSON, case patterns), so here-strings
# are the only safe carrier: $VAR and "quotes" arrive on the node as written,
# and only the __PLACEHOLDER__ tokens are substituted afterwards.

$ProbeSetup = @'
for ns in __NS__ __NSQ__ __NSO__ __NSR__; do
  kubectl create ns $ns --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  kubectl label ns $ns cka-gate=probe --overwrite >/dev/null
done
kubectl label ns __NS__ pod-security.kubernetes.io/enforce=baseline pod-security.kubernetes.io/warn=baseline --overwrite >/dev/null
kubectl label ns __NSO__ pod-security.kubernetes.io/enforce=baseline --overwrite >/dev/null
kubectl label ns __NSR__ pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null
kubectl apply -f __BASE__/.gate/limitrange.yaml >/dev/null
kubectl -n __NSQ__ create quota bare --hard=cpu=2,memory=2Gi --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n __NSO__ create quota zero --hard=pods=0 --dry-run=client -o yaml | kubectl apply -f - >/dev/null
sleep 2
echo "PROBE_NAMESPACES=[$(kubectl get ns -l cka-gate=probe --no-headers 2>/dev/null | wc -l | tr -d ' ')]"
'@

$setupOut = Invoke-Node -Command (Expand-RemoteScript $ProbeSetup)
if ($setupOut -match 'PROBE_NAMESPACES=\[4\]') {
    Write-Success "Probe namespaces ready: $($ProbeNamespaces -join ', ')"
}
else {
    Write-ErrorMsg "Could not build all four probe namespaces -- the gate results below cannot be trusted."
    Write-Host    "           got: $(($setupOut -split "`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 1))"
    $Failures.Add('Gate probe namespaces were not created')
}

Write-Step 'Fact gate -- the seven claims this module makes out loud'

# ---------------------------------------------------------------------------
# CLAIM 1. LimitRanger, ResourceQuota, and PodSecurity are all enabled on THIS
# API server.
#
# Asserted by BEHAVIOUR, three ways, in one round trip:
#   LimitRanger  -- a Pod that named no resources comes back carrying some.
#   ResourceQuota-- a Pod into a namespace whose quota is full is refused with
#                   "exceeded quota".
#   PodSecurity  -- a privileged Pod into an enforce=baseline namespace is
#                   refused with "violates PodSecurity".
#
# NOT by grepping --enable-admission-plugins out of the static pod manifest.
# That string proves the flag was typed, not that the plugin runs; the default
# plugin set is compiled in and can be enabled without ever appearing in that
# flag, so a grep both false-negatives AND tells you nothing about behaviour.
# ---------------------------------------------------------------------------
$GatePluginsActive = @'
LR=INACTIVE; RQ=INACTIVE; PS=INACTIVE
kubectl -n __NS__ run lrprobe --image=registry.k8s.io/pause:3.10 --restart=Never >/dev/null 2>&1
C=
for i in $(seq 1 20); do
  C=$(kubectl -n __NS__ get pod lrprobe -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  [ -n "$C" ] && break
  sleep 1
done
[ -n "$C" ] && LR=ACTIVE
QMSG=$(kubectl -n __NSO__ run rqprobe --image=registry.k8s.io/pause:3.10 --restart=Never 2>&1 | tr '\n' ' ')
case "$QMSG" in *'exceeded quota'*) RQ=ACTIVE ;; esac
PMSG=$(kubectl -n __NS__ run psprobe --image=registry.k8s.io/pause:3.10 --restart=Never --overrides='{"spec":{"containers":[{"name":"psprobe","image":"registry.k8s.io/pause:3.10","securityContext":{"privileged":true}}]}}' 2>&1 | tr '\n' ' ')
case "$PMSG" in *'violates PodSecurity'*) PS=ACTIVE ;; esac
echo "PLUGINS=[LimitRanger:$LR ResourceQuota:$RQ PodSecurity:$PS]"
'@

Test-Gate -Name 'LimitRanger, ResourceQuota, and PodSecurity all actually run on this API server' `
          -Command (Expand-RemoteScript $GatePluginsActive) `
          -Match 'PLUGINS=\[LimitRanger:ACTIVE ResourceQuota:ACTIVE PodSecurity:ACTIVE\]'

# ---------------------------------------------------------------------------
# CLAIM 2. LimitRanger MUTATES. A Pod that named no resources at all comes back
# out of the API server carrying requests.cpu=100m and limits.cpu=500m, because
# the mutating pass wrote them in before anything was stored. Those two exact
# numbers are on the deck's code slide and read aloud in Demo 1, so the gate
# asserts the numbers, not merely "some resources appeared".
# ---------------------------------------------------------------------------
$GateLimitRangerMutates = @'
kubectl -n __NS__ run lrprobe --image=registry.k8s.io/pause:3.10 --restart=Never >/dev/null 2>&1
REQ=
for i in $(seq 1 20); do
  REQ=$(kubectl -n __NS__ get pod lrprobe -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
  [ -n "$REQ" ] && break
  sleep 1
done
LIM=$(kubectl -n __NS__ get pod lrprobe -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null)
echo "INJECTED=[requests.cpu=$REQ limits.cpu=$LIM] SUBMITTED=[no resources at all]"
'@

Test-Gate -Name 'a Pod with no resources comes back with requests.cpu=100m and limits.cpu=500m' `
          -Command (Expand-RemoteScript $GateLimitRangerMutates) `
          -Match 'INJECTED=\[requests\.cpu=100m limits\.cpu=500m\]'

# ---------------------------------------------------------------------------
# CLAIM 3. LimitRanger also VALIDATES, and its refusal names both the
# constraint and the value you submitted:
#     maximum cpu usage per Container is 800m, but limit is 1500m
# The gate applies the real limitrange-ceiling.yaml (so 800m comes from the
# manifest, not from this script) and then the real oversized-pod.yaml (so
# 1500m does too). The regex demands both numbers in the message, because
# "it was rejected" is a much weaker claim than the one the deck makes.
# ---------------------------------------------------------------------------
$GateLimitRangerValidates = @'
kubectl apply -f __BASE__/.gate/limitrange-ceiling.yaml >/dev/null
sleep 1
MSG=$(kubectl apply -f __BASE__/.gate/oversized-pod.yaml 2>&1 | tr '\n' ' ')
echo "REFUSAL=[$MSG]"
'@

Test-Gate -Name 'the over-max container is refused, and the message names 800m AND 1500m' `
          -Command (Expand-RemoteScript $GateLimitRangerValidates) `
          -Match 'maximum cpu usage per Container is 800m, but limit is 1500m'

# ---------------------------------------------------------------------------
# CLAIM 4. Bare `cpu` and `memory` in a ResourceQuota mean REQUESTS, never
# limits. That is the trap comment in resourcequota.yaml and the sentence Tim
# says out loud.
#
# THE INSTRUMENT MATTERS HERE. You cannot prove this by reading the YAML you
# submitted -- that only shows what you typed. So: a quota with bare cpu and
# memory, then a Pod whose requests and limits DIFFER (requests 100m/64Mi,
# limits 900m/512Mi), then read .status.used off the live quota object. If bare
# cpu meant limits, used.cpu would read 900m. It reads 100m.
# ---------------------------------------------------------------------------
$GateBareQuotaMeansRequests = @'
kubectl -n __NSQ__ create quota bare --hard=cpu=2,memory=2Gi --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n __NSQ__ run qprobe --image=registry.k8s.io/pause:3.10 --restart=Never --overrides='{"spec":{"containers":[{"name":"qprobe","image":"registry.k8s.io/pause:3.10","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"900m","memory":"512Mi"}}}]}}' >/dev/null 2>&1
U=; M=
for i in $(seq 1 30); do
  U=$(kubectl -n __NSQ__ get quota bare -o jsonpath='{.status.used.cpu}' 2>/dev/null)
  M=$(kubectl -n __NSQ__ get quota bare -o jsonpath='{.status.used.memory}' 2>/dev/null)
  case "$U" in ''|0) sleep 1 ;; *) break ;; esac
done
echo "QUOTA_USED=[cpu=$U memory=$M] SUBMITTED=[requests 100m/64Mi limits 900m/512Mi]"
'@

Test-Gate -Name 'bare cpu/memory in a live quota count the REQUESTS (100m/64Mi), not the limits' `
          -Command (Expand-RemoteScript $GateBareQuotaMeansRequests) `
          -Match 'QUOTA_USED=\[cpu=100m memory=64Mi\]'

# ---------------------------------------------------------------------------
# CLAIM 5. ResourceQuota is ordered LAST among the validating plugins, so when
# a single Pod would violate BOTH Pod Security and the quota, the message you
# get back is the Pod Security one -- the quota never gets to speak.
#
# The observable consequence is the whole point, so that is what is measured: a
# namespace with enforce=baseline AND a quota of pods=0, and one privileged Pod
# that trips both. Whichever plugin's message comes back is the one that ran
# first. The node computes the verdict so the gate output names a WINNER rather
# than making a regex guess about a long error string.
# ---------------------------------------------------------------------------
$GateQuotaIsLast = @'
kubectl -n __NSO__ create quota zero --hard=pods=0 --dry-run=client -o yaml | kubectl apply -f - >/dev/null
sleep 2
kubectl -n __NSO__ delete pod orderprobe --ignore-not-found --wait=false >/dev/null 2>&1
MSG=$(kubectl -n __NSO__ run orderprobe --image=registry.k8s.io/pause:3.10 --restart=Never --overrides='{"spec":{"containers":[{"name":"orderprobe","image":"registry.k8s.io/pause:3.10","securityContext":{"privileged":true}}]}}' 2>&1 | tr '\n' ' ')
case "$MSG" in
  *'violates PodSecurity'*) echo "WINNER=[PodSecurity] MSG=[$MSG]" ;;
  *'exceeded quota'*)       echo "WINNER=[ResourceQuota] MSG=[$MSG]" ;;
  *)                        echo "WINNER=[neither] MSG=[$MSG]" ;;
esac
'@

Test-Gate -Name 'a Pod violating BOTH is refused by Pod Security first (ResourceQuota validates last)' `
          -Command (Expand-RemoteScript $GateQuotaIsLast) `
          -Match 'WINNER=\[PodSecurity\]'

# The other half of the same sentence, stated as a negative: the operator does
# NOT see a quota error. Safe as a ShouldNotMatch because the command's last
# statement is an echo, so remote exit 0 proves the probe really ran.
Test-Gate -Name 'and the operator never sees the quota error for that Pod' `
          -Command (Expand-RemoteScript $GateQuotaIsLast) `
          -Match 'exceeded quota' -ShouldNotMatch

# ---------------------------------------------------------------------------
# CLAIM 6. A `privileged: true` container violates the BASELINE Pod Security
# Standard -- and the shape of the failure is the lesson: the Deployment is
# created, the ReplicaSet is created, and ZERO Pods appear. The refusal is
# waiting one level down.
# ---------------------------------------------------------------------------
$GatePrivilegedShape = @'
kubectl apply -f __BASE__/.gate/privileged-deployment.yaml >/dev/null 2>&1
RS=0
for i in $(seq 1 20); do
  RS=$(kubectl -n __NS__ get rs -l app=legacy-agent --no-headers 2>/dev/null | wc -l | tr -d ' ')
  [ "$RS" -gt 0 ] && break
  sleep 1
done
sleep 4
D=$(kubectl -n __NS__ get deploy legacy-agent --no-headers 2>/dev/null | wc -l | tr -d ' ')
P=$(kubectl -n __NS__ get pods -l app=legacy-agent --no-headers 2>/dev/null | wc -l | tr -d ' ')
echo "DEPLOY=[$D] REPLICASET=[$RS] PODS=[$P]"
'@

Test-Gate -Name 'the privileged Deployment and its ReplicaSet exist, and ZERO Pods appear' `
          -Command (Expand-RemoteScript $GatePrivilegedShape) `
          -Match 'DEPLOY=\[1\] REPLICASET=\[1\] PODS=\[0\]'

# And the refusal really is readable on the ReplicaSet -- that is step 3 of the
# diagnostic ladder Tim teaches, and `describe rs | tail` is the exact command
# he types. If the message ever moves, the ladder loses a rung on camera.
$GateRsCarriesRefusal = @'
E=
for i in $(seq 1 20); do
  E=$(kubectl -n __NS__ describe rs -l app=legacy-agent 2>&1 | tr '\n' ' ')
  case "$E" in *'violates PodSecurity'*) break ;; esac
  sleep 2
done
TAIL=$(printf '%s' "$E" | tail -c 200)
case "$E" in
  *'violates PodSecurity'*) echo "RS_EVENT=[violates PodSecurity]" ;;
  *)                        echo "RS_EVENT=[not found] TAIL=[$TAIL]" ;;
esac
'@

Test-Gate -Name 'describe rs is where the baseline refusal is legible (rung 3 of the ladder)' `
          -Command (Expand-RemoteScript $GateRsCarriesRefusal) `
          -Match 'RS_EVENT=\[violates PodSecurity\]'

# ---------------------------------------------------------------------------
# CLAIM 7. Does hardened-pod.yaml satisfy RESTRICTED, or only BASELINE?
#
# This gate exists because it is the easiest sentence in the module to overclaim
# on camera. It is answered with the only authority that counts: submit the real
# manifest into a namespace labeled enforce=restricted and let Pod Security
# Admission rule on it. The local field check below is the EXPLANATION of the
# verdict, never the verdict itself.
#
# Handled outside Test-Gate on purpose, because a generic "expected /X/, got /Y/"
# is not a loud enough failure for this one. If the answer is baseline, the
# narration has to change, and the script says so in those words.
# ---------------------------------------------------------------------------
$hardenedPath = Join-Path $PSScriptRoot '..\..\exercise-files\course-04-rbac-admission\m03-admission-controls\hardened-pod.yaml'
$hardenedText = if (Test-Path -LiteralPath $hardenedPath) { Get-Content -Raw -LiteralPath $hardenedPath } else { '' }
# The two fields restricted adds on top of baseline. Reported in WORDS, because
# True/False in a colour is two ways of failing the same reader.
$seccompState = if ($hardenedText -match 'seccompProfile') { 'present' } else { 'ABSENT' }
$dropAllState = if (($hardenedText -match 'capabilities') -and ($hardenedText -match '(?m)^\s*(-\s*)?"?ALL"?\s*$')) { 'present' } else { 'ABSENT' }

$GateRestrictedOrBaseline = @'
kubectl label ns __NSR__ pod-security.kubernetes.io/enforce=restricted --overwrite >/dev/null
kubectl -n __NSR__ delete pod hardened --ignore-not-found --wait=false >/dev/null 2>&1
sleep 1
MSG=$(kubectl apply -f __BASE__/.gate/hardened-pod-restricted.yaml 2>&1 | tr '\n' ' ')
case "$MSG" in
  *'violates PodSecurity'*)                  echo "PSA_LEVEL=[baseline] MSG=[$MSG]" ;;
  *created*|*configured*|*unchanged*)        echo "PSA_LEVEL=[restricted] MSG=[$MSG]" ;;
  *)                                         echo "PSA_LEVEL=[unknown] MSG=[$MSG]" ;;
esac
'@

$psaOut  = Invoke-Node -Command (Expand-RemoteScript $GateRestrictedOrBaseline)
$psaLine = ($psaOut -split "`n" | Where-Object { $_ -match 'PSA_LEVEL=' } | Select-Object -Last 1)
$gate7   = 'hardened-pod.yaml Pod Security level matches what the runbook says'

# WHY BASELINE IS A PASS, NOT A FAILURE.
# An earlier draft of this gate failed on baseline. That was wrong. The manifest
# is baseline, CKA-C04-M03-RUNBOOK.md step 24 says "This Pod satisfies baseline",
# and the two agree -- so the cluster and the deck are in sync, which is the only
# thing a fact gate is entitled to care about. Failing here would red-light a
# take over a question that is already settled, and a gate you learn to ignore
# is worse than no gate at all.
#
# The gate still fails on UNDETERMINED, because an undecided answer is exactly
# the state that lets a wrong sentence reach the recording.
if ($psaLine -match 'PSA_LEVEL=\[baseline\]') {
    Write-Success "GATE PASS  $gate7 -- BASELINE, as the runbook states"
    Write-Host    "           manifest seccompProfile        : $seccompState"
    Write-Host    "           manifest capabilities.drop ALL : $dropAllState"
    Write-Host    "           Restricted needs BOTH of those. This manifest sets neither,"
    Write-Host    "           so step 24 says 'baseline'. SAY BASELINE ON CAMERA."
    Write-Host    "           To make it genuinely restricted instead, add:"
    Write-Host    "             spec.securityContext.seccompProfile.type: RuntimeDefault"
    Write-Host    "             spec.containers[0].securityContext.capabilities.drop: [ALL]"
    Write-Host    "           then update step 24's narration and re-run this script."
}
elseif ($psaLine -match 'PSA_LEVEL=\[restricted\]') {
    Write-Warn    "GATE PASS with DRIFT  hardened-pod.yaml now satisfies RESTRICTED"
    Write-Host    "           enforce=restricted admitted it. In the manifest:"
    Write-Host    "           seccompProfile: $seccompState | capabilities.drop ALL: $dropAllState"
    Write-Host    "           The manifest was upgraded since the runbook was written."
    Write-Host    "           Step 24 still says 'baseline' -- UPDATE THE RUNBOOK or you will"
    Write-Host    "           understate what you just demonstrated. Not a blocker."
}
else {
    Write-ErrorMsg "GATE FAIL  could not determine whether hardened-pod.yaml is restricted or baseline"
    Write-Host    "           Treat this as a failure, not a pass: an undecided answer is exactly"
    Write-Host    "           the state that lets a wrong sentence reach the recording."
    Write-Host    "           got: $(if ($psaLine) { $psaLine } else { '<empty>' })"
    $Failures.Add('Pod Security level of hardened-pod.yaml is undetermined')
}

# The other half of Demo 3, and a real recording risk rather than a deck claim:
# nginxinc/nginx-unprivileged must actually PULL, start under
# readOnlyRootFilesystem with only the emptyDir at /tmp writable, and answer
# `id -u` with 101 -- which is the number Tim reads off the screen. Both facts
# in one regex so the probe's 150-second Ready wait is paid once.
$GateHardenedRuns = @'
kubectl apply -f __BASE__/.gate/hardened-pod.yaml >/dev/null 2>&1
kubectl -n __NS__ wait --for=condition=Ready pod/hardened --timeout=150s >/dev/null 2>&1
U=$(kubectl -n __NS__ exec hardened -- id -u 2>&1 | tr -d ' \r\n')
T=$(kubectl -n __NS__ exec hardened -- touch /root-test 2>&1 | tr '\n' ' ')
echo "UID=[$U] TOUCH=[$T]"
'@

Test-Gate -Name 'the hardened Pod runs under baseline as uid 101 with a read-only root' `
          -Command (Expand-RemoteScript $GateHardenedRuns) `
          -Match 'UID=\[101\].*[Rr]ead-only file system'

Write-Step 'Tearing down the probe namespaces'
Remove-GateProbes

#endregion

#region 6. Scrub to the starting frame ------------------------------------------

Write-Step 'Scrubbing to frame zero -- Demo 1 opens on a cluster with NO production namespace'

# Prefer ./lab.sh reset when it is on the node: ONE definition of "frame zero",
# used by this host-side bring-up and by Tim between takes, so the two cannot
# drift apart. But do not DEPEND on it -- if lab.sh is missing, or its verbs
# change, the explicit delete list below still runs and the verification gate
# after it is the authority either way.
# DO NOT append your own __RC__ sentinel to a command. Invoke-Node already
# appends one AND strips every `__RC__=<n>` from the text it returns, so a
# second sentinel gets stripped too, the match never succeeds, and a perfectly
# clean reset is reported as a failure. Read the status from $Script:LastNodeRC.
$labPresent = Invoke-Node -Command "test -x '$RemoteBase/lab.sh' && echo __YES__ || echo __NO__"
if ($labPresent -match '__YES__') {
    $scrub   = Invoke-Node -Command "cd '$RemoteBase' && ./lab.sh reset"
    $scrubRC = $Script:LastNodeRC
    $scrub -split "`n" | Where-Object { $_ -match '\S' } | ForEach-Object { Write-Host "    $_" }
    if ($scrubRC -eq 0) { Write-Success './lab.sh reset reported a clean frame zero' }
    else { Write-Warn "./lab.sh reset exited $scrubRC -- falling through to the explicit delete list" }
}
else {
    Write-Warn 'lab.sh is not executable on the node yet -- using the explicit delete list only'
}

# Belt and braces. Deleting the namespace takes every object in it, but a prior
# take can also have dropped `kubectl run web-1` into default without -n.
$ScrubExplicit = @'
kubectl delete ns production --ignore-not-found --wait=false >/dev/null 2>&1
kubectl -n default delete deploy filler legacy-agent --ignore-not-found >/dev/null 2>&1
kubectl -n default delete pod web-1 greedy hardened --ignore-not-found --wait=false >/dev/null 2>&1
kubectl -n default delete quota production-cap --ignore-not-found >/dev/null 2>&1
kubectl -n default delete limitrange production-defaults --ignore-not-found >/dev/null 2>&1
echo "SCRUB_ISSUED"
'@
[void](Invoke-Node -Command $ScrubExplicit)

# The confirmation, printed. A namespace can sit in Terminating for a while, so
# poll rather than snapshotting a half-deleted cluster. This is a Test-Gate for
# the same reason the deck claims are: it is a fact about the live cluster that
# has to be true before the red light goes on.
$GateFrameZero = @'
N=x
for i in $(seq 1 40); do
  N=$(kubectl get ns production --ignore-not-found -o name 2>/dev/null | tr -d ' \r\n')
  [ -z "$N" ] && break
  sleep 3
done
LEFT=$(kubectl get deploy,rs,pods,quota,limitrange -A --no-headers 2>/dev/null | grep -E 'filler|legacy-agent|hardened|greedy|web-1|production-cap|production-defaults' | awk '{print $1"/"$2}' | tr '\n' ' ' | sed 's/ *$//')
echo "FRAME_ZERO PRODUCTION_NS=[$N] LEFTOVERS=[$LEFT]"
'@

Test-Gate -Name 'frame zero: no production namespace, no filler/legacy-agent/hardened/greedy/web-1' `
          -Command $GateFrameZero `
          -Match 'FRAME_ZERO PRODUCTION_NS=\[\] LEFTOVERS=\[\]'

# Print the starting frame Tim will see, in words, whatever the verdict was.
Write-Info 'Namespaces the first `kubectl get ns` will show on camera:'
# tr+cut, not awk: an awk program needs quotes around it, and quoting is the one
# thing that has repeatedly reached this node malformed. No quotes, no problem.
(Invoke-Node -Command 'kubectl get ns --no-headers 2>/dev/null | tr -s " " | cut -d" " -f1,2') -split "`n" |
    Where-Object { $_ -match '\S' } | ForEach-Object { Write-Host "    $_" }

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
    Write-Success 'Lab is recording-ready for C04 M03'
    Write-Host ""
    Write-Host "  Next:  ssh vagrant@$(($LabNodes | Where-Object Name -eq $Node).IP)"
    Write-Host "         cd ~/m03                            # every script and manifest lives here"
    Write-Host "         ./lab.sh                            # reset + verify off camera"
    Write-Host "         kubectl config current-context      # cka-vagrant"
    Write-Host ""
    Write-Host "  Demo 1 opens on 'kubectl create namespace production' -- the namespace"
    Write-Host "  does not exist yet, and this run just proved it."
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
