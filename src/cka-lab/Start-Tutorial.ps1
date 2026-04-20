<#
.SYNOPSIS
    Run a CKA tutorial against an already-running KIND cluster.

.DESCRIPTION
    Standalone tutorial runner — use this when your cluster is already up
    and you want to replay or try a different tutorial without tearing down.

.EXAMPLE
    .\Start-Tutorial.ps1
    Presents tutorial menu, runs selected tutorial against the running cluster.
#>

#Requires -Version 7.0

param(
    [Parameter(Mandatory = $false)]
    [string]$ClusterName = "cka-lab"
)

# Source shared library FIRST so we can use Test-ClusterExists / Get-KindClusters.
# (The hand-rolled "$clusterList -split `n" check below missed \r on Windows and
# duplicated logic already hardened in lib/CkaLab.ps1.)
. (Join-Path -Path $PSScriptRoot -ChildPath "lib\CkaLab.ps1")

# Verify the cluster is running
if (-not (Test-ClusterExists -ClusterName $ClusterName)) {
    Write-ErrorMsg "Cluster '$ClusterName' is not running. Start it with: .\kind-up.ps1"
    exit 1
}

# Verify kubectl can reach it
$ctx = kubectl config current-context 2>$null
if ($ctx -ne "kind-$ClusterName") {
    Write-Info "Switching context to kind-$ClusterName"
    kubectl config use-context "kind-$ClusterName" 2>$null
}

# Tutorial menu
Write-Output ""
Write-Output "============================================================"
Write-Output "  CKA Tutorial Runner"
Write-Output "  Cluster: $ClusterName"
Write-Output "============================================================"
Write-Output ""
Write-Output "Select a tutorial:"
Write-Output "  [1] Component Walkthrough    (12 steps — verify all K8s components)"
Write-Output "  [2] Course 1, Module 1       (10 steps — architecture & lab setup)"
Write-Output "  [3] Course 1, Module 2       (16 steps — kubectl workflows)"
Write-Output "  [4] Course 1, Module 3       (18 steps — core resources & diagnostics)"
Write-Output ""
$choice = Read-Host "Enter choice"

switch ($choice) {
    "1" { Start-ComponentWalkthrough -ClusterName $ClusterName }
    "2" { Start-TutorialM01 -ClusterName $ClusterName }
    "3" { Start-TutorialM02 -ClusterName $ClusterName }
    "4" { Start-TutorialM03 -ClusterName $ClusterName }
    default {
        Write-Output "[ERROR] Invalid choice '$choice'. Please enter 1, 2, 3, or 4."
        exit 1
    }
}
