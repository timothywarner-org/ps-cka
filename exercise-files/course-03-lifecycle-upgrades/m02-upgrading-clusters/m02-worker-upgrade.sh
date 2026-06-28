#!/bin/bash
#
# m02-worker-upgrade.sh
# ====================
# CKA Course 3, Module 2: Upgrading Kubernetes Clusters with kubeadm
#
# This script demonstrates how to upgrade a worker node from one Kubernetes
# version to another. Worker node upgrade follows the pattern:
#
# DRAIN → UPGRADE → UNCORDON
#
# SETUP: Run this script ON a worker VM (worker1 or worker2) using:
#   ssh vagrant@192.168.50.11   (worker1, password: vagrant)
#   cd /tmp  # or your working directory
#   bash m02-worker-upgrade.sh <target-version>
#
# WORKFLOW (from control plane, then on worker):
#   1. kubectl drain <worker-node>  [Evict all pods]
#   2. SSH into the worker and upgrade            [kubeadm, kubelet, kubectl]
#   3. kubectl uncordon <node>      [Re-enable scheduling]
#
# The drain step is critical:
#   - It evicts all Pods from the worker (respecting PDBs)
#   - It marks the node as unschedulable (SchedulingDisabled)
#   - Running Pods are rescheduled to other nodes
#   - DaemonSet Pods cannot be evicted (must use --ignore-daemonsets)
#
# This script runs ON THE WORKER NODE during the upgrade phase.
#
# KEY CONCEPTS:
#   - kubectl drain: Evict pods and cordon the node (must be run from control plane)
#   - kubeadm upgrade node: Update worker configuration (different from 'upgrade apply')
#   - Worker upgrades happen one at a time (maintain cluster capacity)
#   - Control plane must be upgraded first
#
# EXAM TIP:
#   - Worker upgrades are the same as control plane except:
#     - Use 'kubeadm upgrade node' instead of 'kubeadm upgrade apply'
#     - No static pod components to upgrade (they're on control plane)
#   - Always drain before upgrading
#   - Always uncordon after upgrading
#
# USAGE:
#   [From the control plane VM: control1]
#   kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data
#
#   [From the worker VM via standard SSH]
#   ssh vagrant@192.168.50.11   (worker1, password: vagrant)
#   ./m02-worker-upgrade.sh <target-version>
#   Example: ./m02-worker-upgrade.sh 1.35.0
#
#   [Back on the control plane VM: control1]
#   kubectl uncordon worker1
#
# PREREQUISITES:
#   - Must run as root or with sudo
#   - Node must be drained (from control plane first)
#   - Control plane must already be upgraded
#   - Internet connectivity to package repositories
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
APT_VERSION_SUFFIX="-1.1"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Worker Node Upgrade${NC}"
echo -e "${YELLOW}(Running inside $CURRENT_HOSTNAME)${NC}"
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

echo -e "${YELLOW}[Step 1] Verifying node is drained...${NC}"
echo "  Node: $CURRENT_HOSTNAME"
echo "  Target Version: v$TARGET_VERSION"
echo ""

# We are on the worker node, so kubectl is not used here to check cordon state.
# The drain must be performed from the control plane (control1) BEFORE this runs.
# kubelet status is informational only: kubelet stays running on a drained node,
# so a "running" result does NOT mean the node was skipped for draining.
# This check stays non-blocking on purpose to keep copy-paste and unattended
# dry-runs working. The control plane drain is the real gate, not a prompt here.
if systemctl is-active --quiet kubelet; then
    echo "  kubelet is currently running (expected: drain does not stop kubelet)"
else
    echo "  kubelet is stopped"
fi
echo -e "${YELLOW}[WARNING]${NC} This node must already be drained from the control plane."
echo "  Run this command from control1 BEFORE upgrading (if not done already):"
echo "    kubectl drain $CURRENT_HOSTNAME --ignore-daemonsets --delete-emptydir-data"
echo ""

# Step 2: Unlock kubeadm
echo -e "${YELLOW}[Step 2] Unlocking kubeadm package for upgrade...${NC}"

if apt-mark showhold 2>/dev/null | grep -q "^kubeadm$"; then
    apt-mark unhold kubeadm
    echo -e "${GREEN}✓${NC} kubeadm unlocked"
else
    echo "  kubeadm is already unlocked"
fi
echo ""

# Step 3: Update package index
echo -e "${YELLOW}[Step 3] Updating apt package index...${NC}"

apt-get update

echo -e "${GREEN}✓${NC} Package index updated"
echo ""

# Step 4: Upgrade kubeadm
echo -e "${YELLOW}[Step 4] Upgrading kubeadm package...${NC}"

KUBEADM_PKG="kubeadm=${TARGET_VERSION}${APT_VERSION_SUFFIX}"
echo "  Installing: $KUBEADM_PKG"

apt-get install -y "$KUBEADM_PKG"

KUBEADM_VERSION=$(kubeadm version -o short)
echo "  kubeadm version: $KUBEADM_VERSION"
echo -e "${GREEN}✓${NC} kubeadm upgraded"

# Re-lock kubeadm
apt-mark hold kubeadm
echo -e "${GREEN}✓${NC} kubeadm locked"
echo ""

# Step 5: Run kubeadm upgrade node
echo -e "${YELLOW}[Step 5] Running kubeadm upgrade node...${NC}"
echo ""
echo "Note: 'kubeadm upgrade node' is the worker-node variant."
echo "It does NOT upgrade static pod components (those are on control plane)."
echo "It updates the node's kubelet configuration and certificates."
echo ""

kubeadm upgrade node

echo ""
echo -e "${GREEN}✓${NC} Node configuration upgraded"
echo ""

# Step 6: Unlock kubelet and kubectl
echo -e "${YELLOW}[Step 6] Upgrading kubelet and kubectl packages...${NC}"

apt-mark unhold kubelet kubectl
echo "  Unlocked kubelet and kubectl"

# Upgrade packages
KUBELET_PKG="kubelet=${TARGET_VERSION}${APT_VERSION_SUFFIX}"
KUBECTL_PKG="kubectl=${TARGET_VERSION}${APT_VERSION_SUFFIX}"
echo "  Installing: $KUBELET_PKG"
echo "  Installing: $KUBECTL_PKG"

apt-get install -y "$KUBELET_PKG" "$KUBECTL_PKG"

# Re-lock
apt-mark hold kubelet kubectl
echo "  Locked kubelet and kubectl"
echo -e "${GREEN}✓${NC} kubelet and kubectl upgraded"
echo ""

# Step 7: Reload systemd and restart kubelet
echo -e "${YELLOW}[Step 7] Restarting kubelet service...${NC}"

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
    echo "           journalctl -u kubelet -n 50"
    exit 1
fi
echo ""

# Step 8: Verify kubelet version
echo -e "${YELLOW}[Step 8] Verifying upgrade...${NC}"

KUBELET_VERSION=$(kubelet --version 2>/dev/null | cut -d' ' -f2 || echo "unknown")
echo "  kubelet version: $KUBELET_VERSION"

KUBECTL_VERSION=$(kubectl version --client 2>/dev/null || echo "unknown")
echo "  kubectl version: $KUBECTL_VERSION"

echo ""

# Summary
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✓ Worker Node Upgrade Complete${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Summary:"
echo "  Node: $CURRENT_HOSTNAME"
echo "  Target Version: v$TARGET_VERSION"
echo "  kubelet Status: running"
echo ""
echo "NEXT STEP (from control plane):"
echo "  kubectl uncordon $CURRENT_HOSTNAME"
echo ""
echo "This will:"
echo "  1. Remove the SchedulingDisabled flag"
echo "  2. Allow new pods to schedule on this node"
echo "  3. Trigger the Deployment controller to rebalance pods"
echo ""
