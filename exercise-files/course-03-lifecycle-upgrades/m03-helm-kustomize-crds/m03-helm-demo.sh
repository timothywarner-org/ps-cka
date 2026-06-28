#!/bin/bash
#
# m03-helm-demo.sh
# ================
# CKA Course 3, Module 3: Installing Cluster Components with Helm
#
# Runs the full Helm lifecycle against the Vagrant VM cluster using the
# OFFICIAL metrics-server chart repo (verified 2026-06-15). Bitnami is NOT
# used -- the legacy charts.bitnami.com path is deprecated.
#
#   1. helm repo add / update         [add the official metrics-server repo]
#   2. helm install (chart 3.12.2)    [create the release at revision 1]
#   3. helm status / kubectl top      [prove the component works]
#   4. helm upgrade (chart 3.13.0)    [revision 2]
#   5. helm history                   [the revision timeline]
#   6. helm rollback 1                [revert -> new revision 3]
#
# KEY CONCEPTS:
#   - chart:      Helm's package, a bundle of templated Kubernetes manifests
#   - repository: a catalog of charts you add with helm repo add
#   - release:    one installed instance of a chart, with its own name + history
#   - revision:   each install/upgrade/rollback creates a new revision
#
# EXAM TIP:
#   - helm install fails if the release name already exists (use helm upgrade)
#   - helm rollback creates a NEW revision; it never deletes old ones
#   - helm.sh/docs is allowed during the exam; learn the workflow, not flags
#
# USAGE:
#   ./m03-helm-demo.sh [--skip-cleanup]
#
set -euo pipefail

NAMESPACE="kube-system"
RELEASE_NAME="metrics-server"
REPO_NAME="metrics-server"
REPO_URL="https://kubernetes-sigs.github.io/metrics-server/"
CHART="metrics-server/metrics-server"
VER_OLD="3.12.2"
VER_NEW="3.13.0"
SKIP_CLEANUP="${1:-}"

echo "== [1] Add the official metrics-server repo and refresh =="
helm repo add "$REPO_NAME" "$REPO_URL"
helm repo update
helm repo list
helm search repo "$CHART"

echo "== [2] Install chart $VER_OLD as release '$RELEASE_NAME' (revision 1) =="
helm install "$RELEASE_NAME" "$CHART" \
  --namespace "$NAMESPACE" \
  --version "$VER_OLD" \
  --set args="{--kubelet-insecure-tls}"

echo "== [3] Confirm the release and that metrics flow =="
helm list -n "$NAMESPACE"
helm status "$RELEASE_NAME" -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" | grep "$RELEASE_NAME" || true
echo "Waiting ~45s for metrics-server to start scraping..."
sleep 45
kubectl top nodes || echo "(metrics may need another moment; retry kubectl top nodes)"

echo "== [4] Upgrade to chart $VER_NEW (revision 2) =="
helm upgrade "$RELEASE_NAME" "$CHART" \
  --namespace "$NAMESPACE" \
  --version "$VER_NEW" \
  --reuse-values

echo "== [5] Review the revision history =="
helm history "$RELEASE_NAME" -n "$NAMESPACE"

echo "== [6] Roll back to revision 1 (writes a new revision 3) =="
helm rollback "$RELEASE_NAME" 1 -n "$NAMESPACE"
helm history "$RELEASE_NAME" -n "$NAMESPACE"
helm status "$RELEASE_NAME" -n "$NAMESPACE"

echo "== Helm lifecycle demo complete =="

if [[ "$SKIP_CLEANUP" != "--skip-cleanup" ]]; then
  echo "== Cleanup: uninstalling release =="
  helm uninstall "$RELEASE_NAME" -n "$NAMESPACE"
else
  echo "Skipping cleanup. To remove later: helm uninstall $RELEASE_NAME -n $NAMESPACE"
fi
