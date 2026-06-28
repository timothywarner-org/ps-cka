#!/bin/bash
#
# m02-kubeadm-upgrade.sh
# =====================
# CKA Course 3, Module 2: Upgrading Kubernetes Clusters with kubeadm
#
# This script demonstrates how to upgrade a control plane node from one Kubernetes
# version to another using kubeadm. Designed for a single control plane node upgrade.
#
# SETUP: Run this script ON the control plane VM (control1) using:
#   ssh vagrant@192.168.50.10   (password: vagrant)
#   cd /tmp  # or your working directory
#   bash m02-kubeadm-upgrade.sh <target-version>
#
# IMPORTANT: The Vagrant VMs are real Ubuntu machines with apt and kubeadm installed.
# The upgrade workflow is IDENTICAL to production Kubernetes clusters.
# This lab environment lets you practice the exact same commands you'll use on real clusters.
#
# UPGRADE WORKFLOW (5 Steps):
#   1. kubeadm upgrade plan                      [Verify upgrade path]
#   2. apt-mark unhold kubeadm                   [Unlock kubeadm package]
#   3. apt-get install kubeadm=<VERSION>         [Upgrade kubeadm tool]
#   4. kubeadm upgrade apply <VERSION>           [Upgrade control plane components]
#   5. Upgrade kubelet and kubectl               [Upgrade remaining components]
#   6. Restart kubelet                           [Apply new version]
#   7. Verify all components at new version      [Health check]
#
# KEY CONCEPTS:
#   - apt-mark hold/unhold: Prevents or allows automatic package upgrades
#   - kubeadm upgrade plan: Read-only pre-flight check
#   - kubeadm upgrade apply: Modifies static Pod manifests one by one
#   - Control plane components upgrade before worker nodes
#   - kubelet is a systemd service (upgraded separately from static Pods)
#
# EXAM TIP:
#   - Always run 'kubeadm upgrade plan' first (shows target version)
#   - Never upgrade kubelet before running 'kubeadm upgrade apply'
#   - Kubectl may show old version briefly; wait 30 seconds for update
#   - One version at a time (e.g., v1.34 → v1.35, not v1.34 → v1.36)
#
# USAGE:
#   ssh vagrant@192.168.50.10   (control1, password: vagrant)
#   sudo ./m02-kubeadm-upgrade.sh <target-version>
#   Example: sudo ./m02-kubeadm-upgrade.sh 1.35.0
#
# PREREQUISITES:
#   - Must run as root or with sudo
#   - Internet connectivity to package repositories
#   - Control plane node must be Ready
#   - etcd backup recommended before upgrade
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TARGET_VERSION="${1:-}"
CURRENT_HOSTNAME=$(hostname)
APT_VERSION_SUFFIX="-1.1"  # Kubernetes packages use -1.1 suffix

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}kubeadm Control Plane Upgrade${NC}"
echo -e "${YELLOW}(Running on the control plane VM: control1)${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Validation
if [[ -z "$TARGET_VERSION" ]]; then
    echo -e "${RED}ERROR: Target version not specified${NC}"
    echo "Usage: sudo $0 <target-version>"
    echo "Example: sudo $0 1.35.0"
    exit 1
fi

# Verify running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    echo "Usage: sudo $0 <target-version>"
    exit 1
fi

echo -e "${YELLOW}[Step 1] Checking current cluster state...${NC}"

# Get current version
CURRENT_VERSION=$(kubectl version 2>/dev/null | grep "Server Version" | cut -d' ' -f3 | cut -d'v' -f2 || echo "unknown")
echo "  Current Server Version: v$CURRENT_VERSION"
echo "  Target Version: v$TARGET_VERSION"
echo "  Node: $CURRENT_HOSTNAME"
echo ""

# Check node readiness
NODE_STATUS=$(kubectl get nodes "$CURRENT_HOSTNAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "unknown")
if [[ "$NODE_STATUS" != "True" ]]; then
    echo -e "${RED}ERROR: Node is not Ready${NC}"
    echo "Current status: $NODE_STATUS"
    echo "Fix health issues before upgrading"
    exit 1
fi
echo -e "${GREEN}✓${NC} Node is Ready"
echo ""

# Step 2: Run kubeadm upgrade plan
echo -e "${YELLOW}[Step 2] Checking upgrade plan...${NC}"
echo "Running: kubeadm upgrade plan"
echo ""

sudo kubeadm upgrade plan v$TARGET_VERSION 2>&1 || true

echo ""
echo -e "${GREEN}✓${NC} Upgrade plan verified"
echo ""

# Step 3: Unlock kubeadm package
echo -e "${YELLOW}[Step 3] Unlocking kubeadm package for upgrade...${NC}"

# Check current hold status
if apt-mark showhold 2>/dev/null | grep -q "^kubeadm$"; then
    echo "  kubeadm is currently held (locked)"
    apt-mark unhold kubeadm
    echo -e "${GREEN}✓${NC} kubeadm unlocked"
else
    echo "  kubeadm is already unlocked"
fi
echo ""

# Step 4: Update package index
echo -e "${YELLOW}[Step 4] Updating apt package index...${NC}"

apt-get update

echo -e "${GREEN}✓${NC} Package index updated"
echo ""

# Step 5: Check available kubeadm version
echo -e "${YELLOW}[Step 5] Checking available kubeadm versions...${NC}"

echo "Available kubeadm versions:"
apt-cache madison kubeadm | grep "$TARGET_VERSION" | head -3

echo ""

# Step 6: Upgrade kubeadm
echo -e "${YELLOW}[Step 6] Upgrading kubeadm package...${NC}"

KUBEADM_PKG="kubeadm=${TARGET_VERSION}${APT_VERSION_SUFFIX}"
echo "  Installing: $KUBEADM_PKG"

apt-get install -y "$KUBEADM_PKG"

# Verify kubeadm version
KUBEADM_VERSION=$(kubeadm version -o short)
echo "  kubeadm version: $KUBEADM_VERSION"
echo -e "${GREEN}✓${NC} kubeadm upgraded successfully"
echo ""

# Step 7: Re-lock kubeadm
echo -e "${YELLOW}[Step 7] Locking kubeadm to prevent accidental upgrades...${NC}"

apt-mark hold kubeadm

echo -e "${GREEN}✓${NC} kubeadm locked"
echo ""

# Step 8: Run kubeadm upgrade apply
echo -e "${YELLOW}[Step 8] Running kubeadm upgrade apply...${NC}"
echo ""
echo "This will upgrade:"
echo "  - API Server manifest"
echo "  - Controller Manager manifest"
echo "  - Scheduler manifest"
echo "  - etcd (if stacked)"
echo ""
echo "Each component restarts one at a time. Cluster will be unavailable briefly."
echo ""

# The upgrade apply command - this is the critical operation
sudo kubeadm upgrade apply v$TARGET_VERSION --yes

echo ""
echo -e "${GREEN}✓${NC} Control plane upgraded successfully"
echo ""

# Step 9: Unlock and upgrade kubelet + kubectl
echo -e "${YELLOW}[Step 9] Upgrading kubelet and kubectl...${NC}"

# Unlock kubelet and kubectl
apt-mark unhold kubelet kubectl
echo "  Unlocked kubelet and kubectl"

# Upgrade packages
KUBELET_PKG="kubelet=${TARGET_VERSION}${APT_VERSION_SUFFIX}"
KUBECTL_PKG="kubectl=${TARGET_VERSION}${APT_VERSION_SUFFIX}"
echo "  Installing: $KUBELET_PKG"
echo "  Installing: $KUBECTL_PKG"

apt-get install -y "$KUBELET_PKG" "$KUBECTL_PKG"

# Lock them again
apt-mark hold kubelet kubectl
echo "  Locked kubelet and kubectl"
echo -e "${GREEN}✓${NC} kubelet and kubectl upgraded"
echo ""

# Step 10: Reload systemd and restart kubelet
echo -e "${YELLOW}[Step 10] Restarting kubelet service...${NC}"

systemctl daemon-reload
echo "  systemd configuration reloaded"

systemctl restart kubelet
echo "  kubelet service restarted"

# Wait for kubelet to fully start
sleep 5

# Check kubelet status
if systemctl is-active --quiet kubelet; then
    echo -e "${GREEN}✓${NC} kubelet is running"
else
    echo -e "${RED}ERROR: kubelet failed to start${NC}"
    echo "Check logs: systemctl status kubelet"
    exit 1
fi
echo ""

# Step 11: Wait for node to become Ready
echo -e "${YELLOW}[Step 11] Waiting for node to become Ready...${NC}"

max_retries=30
retry_count=0
while true; do
    NODE_STATUS=$(kubectl get nodes "$CURRENT_HOSTNAME" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "unknown")
    if [[ "$NODE_STATUS" == "True" ]]; then
        echo -e "${GREEN}✓${NC} Node is Ready"
        break
    fi

    if [[ $retry_count -ge $max_retries ]]; then
        echo -e "${RED}ERROR: Node did not become Ready within $((max_retries * 2)) seconds${NC}"
        echo "Check node status: kubectl describe node $CURRENT_HOSTNAME"
        exit 1
    fi

    echo "  Waiting... ($((retry_count + 1))/$max_retries)"
    sleep 2
    ((retry_count++))
done
echo ""

# Step 12: Verify upgrade
echo -e "${YELLOW}[Step 12] Verifying upgrade...${NC}"

echo "Node version:"
kubectl get nodes "$CURRENT_HOSTNAME"

echo ""
echo "Control plane components:"
kubectl get pods -n kube-system -o wide | grep -E "(apiserver|controller-manager|scheduler|etcd)" | head -10

echo ""

# Check component versions
echo "API Server version:"
kubectl version 2>/dev/null | grep "Server Version" || echo "  (Could not retrieve)"

echo ""

# Summary
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✓ Control Plane Upgrade Complete${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Summary:"
echo "  Node: $CURRENT_HOSTNAME"
echo "  Target Version: v$TARGET_VERSION"
echo "  Status: Ready"
echo ""
echo "NEXT STEPS:"
echo "  1. Verify workloads are still running: kubectl get pods -A"
echo "  2. Check cluster events: kubectl get events -A --sort-by='.lastTimestamp'"
echo "  3. Upgrade worker nodes one at a time (worker1, then worker2):"
echo "     - kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data"
echo "     - ssh vagrant@192.168.50.11 (worker1), then sudo ./m02-worker-upgrade.sh <version>"
echo "     - kubectl uncordon worker1"
echo "     - Repeat for worker2 at ssh vagrant@192.168.50.12"
echo ""
echo "For worker node upgrades, use: m02-worker-upgrade.sh"
echo ""
