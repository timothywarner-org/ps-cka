#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Interactive walkthrough of kubectl context management against the
    cka-dev / cka-prod clusters created by kind-multi-up.ps1.

.DESCRIPTION
    Eight drills, each one runs a real kubectl command against your local
    kubeconfig and explains what just happened. Press ENTER to advance, or
    Ctrl-C to bail out (the script restores your starting context on exit).

.EXAMPLE
    .\Start-ContextPractice.ps1
    Walks the eight drills.

.NOTES
    Requires both kind-cka-dev and kind-cka-prod contexts to exist.
    Run .\kind-multi-up.ps1 first.
#>

#Requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"

. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

Initialize-LabEncoding
Initialize-LabPath

$expectedContexts = @("kind-cka-dev", "kind-cka-prod")
$present = (kubectl config get-contexts -o name 2>$null) -split "`n" | ForEach-Object { $_.Trim() }

foreach ($ctx in $expectedContexts) {
    if ($ctx -notin $present) {
        Write-ErrorMsg "Required context '$ctx' is missing. Run .\kind-multi-up.ps1 first."
        exit 1
    }
}

# Remember where the user started so we can put them back if they Ctrl-C or
# the script falls off the end on a drill that switched contexts.
$startContext = (kubectl config current-context 2>$null).Trim()

function Write-Drill {
    param(
        [string]$Title,
        [string]$Why,
        [string]$Command,
        [string]$Notice
    )
    Write-Output ""
    Write-Output "------------------------------------------------------------"
    Write-Host "$($Script:NeonGreen)$Title$($Script:AnsiReset)"
    Write-Output "------------------------------------------------------------"
    Write-Output ""
    Write-Output "  WHY: $Why"
    Write-Output ""
    Write-Output "  COMMAND:"
    Write-Output "    $Command"
    Write-Output ""
    if ($Notice) {
        Write-Output "  NOTE: $Notice"
        Write-Output ""
    }
    Read-Host "  Press ENTER to run"
    Write-Output ""
    Invoke-Expression $Command
    Write-Output ""
}

try {
    Write-Output ""
    Write-Output "============================================================"
    Write-Output "  Kubectl Context Practice -- 8 drills"
    Write-Output "  Starting context: $startContext"
    Write-Output "============================================================"

    # Drill 1: see all contexts
    Write-Drill `
        -Title  "1/8  LIST EVERY CONTEXT IN YOUR KUBECONFIG" `
        -Why    "First reflex on any unfamiliar workstation. * marks the active context. The CLUSTER and AUTHINFO columns show what each context binds to under the hood." `
        -Command "kubectl config get-contexts"

    # Drill 2: just the active one
    Write-Drill `
        -Title  "2/8  CHECK WHICH CONTEXT IS ACTIVE RIGHT NOW" `
        -Why    "Scriptable answer to 'where will my next kubectl command land?'. Use this in shell prompts, CI guards, and anywhere `kubectl get-contexts` is too verbose." `
        -Command "kubectl config current-context"

    # Drill 3: switch and prove it
    Write-Drill `
        -Title  "3/8  SWITCH CONTEXTS AND PROVE THE SWITCH" `
        -Why    "use-context updates the 'current-context' field in kubeconfig. The node count differs (dev=2, prod=3) so the switch is visually obvious." `
        -Command "kubectl config use-context kind-cka-dev; kubectl get nodes"

    Write-Drill `
        -Title  "3b/8 SWITCH TO PROD AND PROVE THE SWITCH" `
        -Why    "Same operation against the other cluster. Notice how the node names change from cka-dev-* to cka-prod-* and the count goes from 2 to 3." `
        -Command "kubectl config use-context kind-cka-prod; kubectl get nodes"

    # Drill 4: one-shot --context override
    Write-Drill `
        -Title  "4/8  ONE-SHOT --context OVERRIDE (no permanent switch)" `
        -Why    "Run a single command against another cluster without changing your default. Critical when you're doing a long task in PROD and need to peek at DEV without fat-fingering yourself back." `
        -Command "kubectl --context kind-cka-dev get nodes; kubectl config current-context" `
        -Notice  "current-context didn't change -- the --context flag was scoped to that one command."

    # Drill 5: rename for ergonomics
    Write-Drill `
        -Title  "5/8  RENAME CONTEXTS FOR ERGONOMICS" `
        -Why    "'kind-cka-dev' is too long to type 50 times a day. rename-context only touches the context name -- the underlying cluster and user references are unchanged." `
        -Command "kubectl config rename-context kind-cka-dev dev; kubectl config rename-context kind-cka-prod prod; kubectl config get-contexts"

    # Drill 6: per-context default namespace
    Write-Drill `
        -Title  "6/8  SET A DEFAULT NAMESPACE ON A CONTEXT" `
        -Why    "Every kubectl command takes -n <ns>. Set it once on the context and stop typing it. The namespace is stored in the context, not globally, so each cluster can have its own default." `
        -Command "kubectl config use-context dev; kubectl config set-context --current --namespace=kube-system; kubectl get pods" `
        -Notice  "Notice: no -n flag, but you got kube-system pods. The context's namespace field did the work."

    # Drill 7: inspect kubeconfig with --minify
    Write-Drill `
        -Title  "7/8  INSPECT JUST THE ACTIVE CONTEXT" `
        -Why    "kubectl config view dumps your ENTIRE kubeconfig. --minify trims it to only the active context's cluster + user + namespace. Perfect for sanity-checking server URLs and cert paths." `
        -Command "kubectl config view --minify"

    # Drill 8: undo (put it back the way we found it)
    Write-Drill `
        -Title  "8/8  RESTORE: rename back, clear namespace, re-select start context" `
        -Why    "Practice habit -- always put the kubeconfig back the way you found it. The next person (or cron job) on this workstation will thank you." `
        -Command "kubectl config set-context dev --namespace=default; kubectl config rename-context dev kind-cka-dev; kubectl config rename-context prod kind-cka-prod; kubectl config use-context $startContext; kubectl config get-contexts"

    Write-Output ""
    Write-Output "============================================================"
    Write-Success "Practice complete."
    Write-Info "Restored to starting context: $startContext"
    Write-Output "============================================================"
    Write-Output ""
}
finally {
    # Always try to restore the starting context, even on Ctrl-C mid-drill.
    # Swallow errors -- if the starting context was the one we deleted, this
    # is best-effort and the user will see the actual state in get-contexts.
    if ($startContext) {
        kubectl config use-context $startContext 2>$null | Out-Null
    }
}
