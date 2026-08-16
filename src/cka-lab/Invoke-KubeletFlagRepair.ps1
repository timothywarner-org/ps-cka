<#
.SYNOPSIS
    On-rails break/fix demo: repair a NotReady control plane whose upgraded
    kubelet crash-loops on a stale, removed startup flag
    (--pod-infra-container-image). Real commands, run live over SSH, phase by phase.

.DESCRIPTION
    This is the live save for the classic kubeadm-upgrade gotcha: you bump kubelet
    to v1.35, restart it, and it refuses to boot because kubeadm left an old flag
    in /var/lib/kubelet/kubeadm-flags.env that v1.35 removed. The kubelet fails
    fast -- one unknown flag and it exits -- so the node stops posting status and
    goes NotReady while the API server (an orphaned static-pod container under
    containerd) keeps answering.

    The script walks the diagnostic ladder on camera: read the kubelet's own words,
    find where the flag is set, strip just that flag (with a backup), restart, then
    prove the heartbeat returns. Each phase prints the talk track (the WHY), echoes
    the exact command in yellow, runs it for real on the node over `vagrant ssh`,
    shows the output, and waits for Enter.

    SAFE + RE-RUNNABLE. The fix is surgical and backed up. Once healed, the grep
    finds nothing, the sed is a no-op, and the restart is harmless -- so you can run
    it again for a clean re-record without rebuilding anything.

    ACCESSIBILITY. Output flows through the shared palette helpers in lib\CkaLab.ps1
    -- every status line is labeled ([OK]/[INFO]/[WARN]/[ERROR]) on the Wong
    colorblind-safe palette. Meaning never rides on color alone.

.PARAMETER Node
    The node to repair. Default 'control1'. Reusable against any NotReady node that
    hit the same stale-flag crash (e.g. a worker in a Course 10 troubleshooting drill).

.PARAMETER StaleFlag
    The removed kubelet flag to strip. Default '--pod-infra-container-image'.

.PARAMETER FlagsFile
    The kubeadm-managed kubelet env file. Default '/var/lib/kubelet/kubeadm-flags.env'.

.EXAMPLE
    .\Invoke-KubeletFlagRepair.ps1
    Walk the repair on control1, phase by phase, live.

.EXAMPLE
    .\Invoke-KubeletFlagRepair.ps1 -Node worker1
    Same repair against worker1 (Course 10 reuse).

.NOTES
    Author: Tim Warner | CKA Course 3 lab (control1, worker1, worker2)
    Run as: Administrator PowerShell 7+, from a window OTHER than your recording SSH
            session, in C:\github\ps-cka\src\cka-lab\course-03-lifecycle-upgrades
    Pairs with: Invoke-M02Upgrade.ps1 (the upgrade this rescues mid-flight)
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$Node = 'control1',

    [ValidateNotNullOrEmpty()]
    [string]$StaleFlag = '--pod-infra-container-image',

    [ValidateNotNullOrEmpty()]
    [string]$FlagsFile = '/var/lib/kubelet/kubeadm-flags.env'
)

$ErrorActionPreference = 'Stop'

# Reuse the shared engine: Write-* palette helpers, Initialize-LabEncoding,
# Get-CkaLabNodes. One definition of the lab, never duplicated here.
. (Join-Path -Path $PSScriptRoot -ChildPath '..\lib\CkaLab.ps1')
Initialize-LabEncoding

# Point Vagrant/SSH at the lab (Vagrantfile + .vagrant live one level up).
$env:VAGRANT_CWD = Split-Path -Parent $PSScriptRoot

#region On-rails render helpers (same rhythm as Invoke-M02Upgrade.ps1) ----------
function Write-PhaseBanner {
    param([int]$Number, [int]$Total, [string]$Title)
    Write-Host ""
    Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)  >>> PHASE $Number of $Total  --  $Title$($Script:AnsiReset)"
    Write-Host "$($Script:NeonGreen)===================================================================$($Script:AnsiReset)"
    Write-Host ""
}

function Write-Talk {
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
    # Run a command on the node over `vagrant ssh`, echoing it in yellow first,
    # then streaming the live output indented. Returns the remote exit code.
    param(
        [Parameter(Mandatory)][string]$Command,
        [string]$Label
    )
    if ($Label) { Write-Host "  $($Script:NeonGreen)# $Label$($Script:AnsiReset)" }
    Write-Host "  $($Script:BrightYellow)[$Node] `$ $Command$($Script:AnsiReset)"
    Write-Host ""
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
#endregion

$TOTAL = 6

#region Title -------------------------------------------------------------------
Clear-Host
Write-Host "$($Script:NeonGreen)"
Write-Host '  CKA COURSE 3 / MODULE 2  --  LIVE BREAK/FIX'
Write-Host "  Node NotReady: upgraded kubelet rejects a removed startup flag"
Write-Host "$($Script:AnsiReset)"
Write-Host "  Target node: $Node    Stale flag: $StaleFlag"
Write-Host ""
Wait-Enter -Prompt 'Press Enter to start the diagnosis'
#endregion

#region Phase 1 -- Name the symptom: API up, node down --------------------------
Write-PhaseBanner -Number 1 -Total $TOTAL -Title 'API answers, but the node is NotReady'
Write-Talk @(
    "Watch the distinction. kubectl still answers -- the API server container kept",
    "running under containerd even after the kubelet fell over. But the NODE is",
    "NotReady, because node readiness is not 'does the API server exist.' It is the",
    "kubelet posting a heartbeat. Let's confirm the node state, then ask the kubelet",
    "itself what's wrong."
)
[void](Invoke-OnNode -Label 'current node state -- expect NotReady' `
    -Command 'kubectl get nodes')
[void](Invoke-OnNode -Label "the kubelet's own words -- the last few log lines" `
    -Command 'sudo journalctl -u kubelet -n 4 --no-pager')
Write-Talk @(
    "There it is: 'unknown flag: $StaleFlag'. The upgraded v1.35 kubelet is being",
    "handed a flag that v1.35 removed, and the kubelet FAILS FAST -- one bad flag and",
    "it refuses to start. That's why the heartbeat stopped."
)
Wait-Enter
#endregion

#region Phase 2 -- Locate the flag (it's config, not the binary) ----------------
Write-PhaseBanner -Number 2 -Total $TOTAL -Title 'Find where the flag is set'
Write-Talk @(
    "Where's that flag coming from? Not the kubelet binary -- kubeadm writes the",
    "kubelet's startup args into a file on disk. Let's grep for the flag so the",
    "learner sees the source, not just my word for it."
)
[void](Invoke-OnNode -Label "search kubelet config dirs for the stale flag" `
    -Command "sudo grep -Rn -- '$StaleFlag' /var/lib/kubelet /etc/systemd/system /etc/default 2>/dev/null")
Write-Talk @(
    "$FlagsFile. That's kubeadm's kubelet env file. The pause -- or sandbox -- image",
    "is now owned by containerd, the container runtime, not the kubelet. So this flag",
    "is dead weight, and v1.35 dropped it entirely."
)
Wait-Enter
#endregion

#region Phase 3 -- Surgical fix, with a backup ----------------------------------
Write-PhaseBanner -Number 3 -Total $TOTAL -Title 'Back it up, then strip just that flag'
Write-Talk @(
    "Back the file up first -- always reversible -- then remove only the stale flag,",
    "nothing else. We'll print the file before and after so you can see the surgery."
)
[void](Invoke-OnNode -Label 'before: the offending line' `
    -Command "cat $FlagsFile")
# GNU sed \x22 = a double-quote char in the bracket class, so the value match stops
# at the line's closing quote without us putting a literal " in the command string
# (a literal " is fragile to pass through PowerShell -> vagrant.exe native argv).
[void](Invoke-OnNode -Label 'backup, then strip the flag in place' `
    -Command "sudo cp $FlagsFile $FlagsFile.bak && sudo sed -i 's|$StaleFlag=[^ \x22]*||g' $FlagsFile")
[void](Invoke-OnNode -Label 'after: flag gone, args clean' `
    -Command "cat $FlagsFile")
Write-Talk @(
    "Clean. The KUBELET_KUBEADM_ARGS line is empty now -- the only thing in it was the",
    "flag we just removed. The backup sits beside it as .bak if we ever want it back."
)
Wait-Enter
#endregion

#region Phase 4 -- Reload + restart the kubelet ---------------------------------
Write-PhaseBanner -Number 4 -Total $TOTAL -Title 'Reload systemd, restart the kubelet'
Write-Talk @(
    "We edited a unit-referenced env file, so reload systemd first, then restart the",
    "kubelet. Watch is-active: this time it should say 'active', not the 'activating'",
    "we'd see if it were still crash-looping."
)
[void](Invoke-OnNode -Label 'reload unit files, restart kubelet, report state' `
    -Command 'sudo systemctl daemon-reload && sudo systemctl restart kubelet && sleep 3 && systemctl is-active kubelet')
Wait-Enter
#endregion

#region Phase 5 -- Prove the heartbeat returned ---------------------------------
Write-PhaseBanner -Number 5 -Total $TOTAL -Title 'Prove the node heartbeat is back'
Write-Talk @(
    "Give the kubelet a few seconds to register, then read the node and its",
    "conditions. We want Ready=True and the NodeStatusUnknown rows gone -- the kubelet",
    "is posting status again, and it re-adopts its static pods on the way up."
)
[void](Invoke-OnNode -Label 'node should now be Ready' `
    -Command 'sleep 8; kubectl get nodes')
[void](Invoke-OnNode -Label 'conditions: Ready True, no more Unknown' `
    -Command "kubectl describe node $Node | sed -n '/Conditions:/,/Addresses:/p'")
Wait-Enter
#endregion

#region Phase 6 -- The lesson + the honest footnote ----------------------------
Write-PhaseBanner -Number 6 -Total $TOTAL -Title 'The takeaway'
Write-Talk @(
    "That's the lesson: NotReady is a kubelet heartbeat problem, not an API problem.",
    "The diagnostic ladder took us straight there -- journal, find the source, fix,",
    "verify. We hand-fixed the flag here because we hit it mid-upgrade. The canonical",
    "path is that 'kubeadm upgrade apply' regenerates this same file WITHOUT the dead",
    "flag, so when you run the real upgrade it overwrites our manual edit cleanly --",
    "no cleanup debt."
)
Write-ExamTip @(
    "kubelet fails fast on unknown flags. After an upgrade, NotReady + an 'unknown",
    "flag' journal line means a stale arg in $FlagsFile. Strip it or let",
    "kubeadm upgrade node/apply regenerate it."
)
Write-Host "$($Script:NeonGreen)  >>> Repair complete. $Node is Ready. Resume the upgrade.$($Script:AnsiReset)"
Write-Host ""
#endregion
