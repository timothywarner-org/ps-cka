#!/bin/bash
#
# m01-etcd-restore.sh
# ===================
# CKA Course 3, Module 1: Backing Up and Restoring etcd for Disaster Recovery
#
# This script demonstrates the complete etcd restore workflow:
#   1. Stop the API server (by stopping kubelet)
#   2. Restore the snapshot to a new data directory
#   3. Update the etcd static Pod manifest to use the new directory
#   4. Restart kubelet to bring the cluster back online
#   5. Verify the restored data
#
# SETUP: Run this script ON the control-plane VM using:
#   vagrant ssh control1
#   cd /tmp  # or your working directory
#   bash m01-etcd-restore.sh <backup-file>
#
# KEY CONCEPTS:
#   - etcd must not be running during restore (prevents data corruption)
#   - The restore command creates a NEW data directory (old data is untouched)
#   - Static Pod manifests are updated in /etc/kubernetes/manifests/
#   - kubelet automatically restarts Pods when manifests change
#   - The restored data becomes active when etcd starts
#   - These restore procedures are the standard kubeadm flow on any real cluster
#
# EXAM TIP:
#   - Stop kubelet to stop the API server (kubelet supervises static Pods)
#   - Restore moved to etcdutl in etcd 3.6; --data-dir alone is the safe single-member form
#   - Test the restore in a non-production environment first
#
# USAGE:
#   vagrant ssh control1
#   ./m01-etcd-restore.sh <backup-file> [data-dir]
#   Example: ./m01-etcd-restore.sh /tmp/etcd-backup-20260328-103015.db /tmp/etcd-restore
#
# PREREQUISITES:
#   - Must run as root or with sudo
#   - etcd backup file must exist
#   - etcd certificates must be in /etc/kubernetes/pki/etcd/
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_FILE="${1:-}"
RESTORE_DIR="${2:-/tmp/etcd-restore}"
ETCD_MANIFEST="/etc/kubernetes/manifests/etcd.yaml"
ETCD_MANIFEST_BACKUP="${ETCD_MANIFEST}.pre-restore-backup"
ETCD_DATA_DIR="/var/lib/etcd"

# Helper function for confirmation prompts
confirm() {
    local prompt="$1"
    local response
    read -p "$(echo -e ${YELLOW}$prompt${NC}) [y/N] " -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}etcd Restore Workflow Demonstration${NC}"
echo -e "${YELLOW}(Running on the control-plane VM)${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Validation
if [[ -z "$BACKUP_FILE" ]]; then
    echo -e "${RED}ERROR: Backup file not specified${NC}"
    echo "Usage: $0 <backup-file> [data-dir]"
    echo "Example: $0 /tmp/etcd-backup.db /tmp/etcd-restore"
    exit 1
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo -e "${RED}ERROR: Backup file not found: $BACKUP_FILE${NC}"
    exit 1
fi

# Verify we're running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}ERROR: This script must be run as root${NC}"
    echo "Usage: sudo $0 <backup-file>"
    exit 1
fi

echo -e "${YELLOW}[Step 1] Verifying prerequisites...${NC}"
echo "  Backup file: $BACKUP_FILE"
echo "  Restore dir: $RESTORE_DIR"
echo "  etcd manifest: $ETCD_MANIFEST"
echo ""

if [[ ! -f "$ETCD_MANIFEST" ]]; then
    echo -e "${RED}ERROR: etcd manifest not found at $ETCD_MANIFEST${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} etcd manifest found"
echo ""

# Warning
echo -e "${RED}========== CRITICAL WARNING ==========${NC}"
echo "This procedure will:"
echo "  1. Stop the API server (cluster becomes unavailable)"
echo "  2. Restore etcd from backup (irreversible)"
echo "  3. Restart kubelet (cluster comes back online)"
echo ""
echo "Do NOT proceed unless you understand the implications."
echo -e "${RED}=====================================${NC}"
echo ""

if ! confirm "Do you want to proceed with etcd restore?"; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi
echo ""

# Step 2: Stop kubelet (stops API server)
echo -e "${YELLOW}[Step 2] Stopping kubelet to halt the API server...${NC}"
echo "  This will stop all static Pods (API server, etcd, controller-manager, scheduler)"
echo "  WARNING: Cluster will become unresponsive"
echo ""

if ! confirm "Ready to stop kubelet?"; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

systemctl stop kubelet
echo -e "${GREEN}✓${NC} kubelet stopped"

# Wait for API server to stop
echo "  Waiting 10 seconds for API server to stop..."
sleep 10

# Verify API server is down
if ! timeout 2 kubectl cluster-info &>/dev/null; then
    echo -e "${GREEN}✓${NC} API server is down"
else
    echo -e "${YELLOW}⚠${NC} API server still responding (may take longer to stop)"
fi
echo ""

# Step 3: Restore snapshot to new directory
echo -e "${YELLOW}[Step 3] Restoring etcd snapshot...${NC}"
echo "  Source: $BACKUP_FILE"
echo "  Target: $RESTORE_DIR"
echo ""

# Remove old restore directory if it exists
if [[ -d "$RESTORE_DIR" ]]; then
    echo "  Removing existing restore directory..."
    rm -rf "$RESTORE_DIR"
fi

mkdir -p "$RESTORE_DIR"

# The restore command
# --data-dir: New directory for restored data (old data is left untouched)
# --initial-cluster: Cluster composition (prevents etcd from thinking this is corrupted)
# --initial-cluster-token: Unique identifier for this cluster
# --initial-advertise-peer-urls: Peer URL for this node
# etcd 3.6 moved snapshot restore to etcdutl (OFFLINE op -- operates on the file).
# Single-member kubeadm restore needs only --data-dir; membership flags are for
# multi-node rebuilds and the stock --name 'default' here would mismatch the etcd member.
etcdutl snapshot restore "$BACKUP_FILE" \
    --data-dir="$RESTORE_DIR"

echo -e "${GREEN}✓${NC} Snapshot restored to $RESTORE_DIR"
echo ""

# Verify restored data directory
if [[ ! -d "$RESTORE_DIR/member" ]]; then
    echo -e "${RED}ERROR: Restored data directory structure is invalid${NC}"
    echo "Expected: $RESTORE_DIR/member/"
    exit 1
fi
echo -e "${GREEN}✓${NC} Restored data directory structure verified"
echo ""

# Step 4: Update etcd manifest
echo -e "${YELLOW}[Step 4] Updating etcd static Pod manifest...${NC}"
echo "  Original: $ETCD_MANIFEST"
echo "  Backup: $ETCD_MANIFEST_BACKUP"
echo "  Change: /var/lib/etcd → $RESTORE_DIR"
echo ""

# Backup the original manifest
cp "$ETCD_MANIFEST" "$ETCD_MANIFEST_BACKUP"
echo -e "${GREEN}✓${NC} Original manifest backed up to $ETCD_MANIFEST_BACKUP"

# Update the manifest to point to the restored data directory
# Find the "etcd-data" volume definition and change its path
sed -i "s|path: /var/lib/etcd|path: $RESTORE_DIR|g" "$ETCD_MANIFEST"

# Verify the change
if grep -q "path: $RESTORE_DIR" "$ETCD_MANIFEST"; then
    echo -e "${GREEN}✓${NC} Manifest updated successfully"
else
    echo -e "${RED}ERROR: Manifest update failed${NC}"
    echo "  Restoring backup..."
    cp "$ETCD_MANIFEST_BACKUP" "$ETCD_MANIFEST"
    exit 1
fi
echo ""

# Step 5: Restart kubelet
echo -e "${YELLOW}[Step 5] Restarting kubelet...${NC}"
echo "  kubelet will:"
echo "    1. Read the updated etcd.yaml manifest"
echo "    2. Start the etcd Pod with the new data directory"
echo "    3. Start the API server and other control plane components"
echo ""

systemctl start kubelet
echo -e "${GREEN}✓${NC} kubelet started"

# Wait for control plane to come online
echo "  Waiting 15 seconds for control plane to start..."
sleep 15

echo ""

# Step 6: Verify control plane is running
echo -e "${YELLOW}[Step 6] Verifying cluster is back online...${NC}"

# Test API server
max_retries=30
retry_count=0
while ! kubectl cluster-info &>/dev/null; do
    if [[ $retry_count -ge $max_retries ]]; then
        echo -e "${RED}ERROR: API server did not come back online${NC}"
        echo "Check logs: journalctl -u kubelet -n 50"
        echo "Restore may have failed. Investigate before attempting again."
        exit 1
    fi
    echo "  Waiting for API server... ($((retry_count + 1))/$max_retries)"
    sleep 2
    ((retry_count++))
done

echo -e "${GREEN}✓${NC} API server is responding"

# Verify nodes
kubectl get nodes
echo -e "${GREEN}✓${NC} Nodes are visible"

# Verify etcd and API server Pods
kubectl get pods -n kube-system | grep -E "(etcd|apiserver)"
echo -e "${GREEN}✓${NC} Control plane Pods are running"

echo ""

# Step 7: Verify restored data
echo -e "${YELLOW}[Step 7] Verifying restored cluster data...${NC}"

echo "Total resources in cluster:"
kubectl get all -A | wc -l

echo ""
echo "Deployments:"
kubectl get deploy -A

echo ""
echo "ConfigMaps:"
kubectl get configmap -A

echo ""

# Summary
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}✓ Restore Complete${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "IMPORTANT NEXT STEPS:"
echo "  1. Verify all resources are present and correct"
echo "  2. Test critical applications and services"
echo "  3. Monitor logs for errors: kubectl logs -n kube-system"
echo "  4. When confirmed stable, restore original etcd.yaml:"
echo "     sudo cp $ETCD_MANIFEST_BACKUP $ETCD_MANIFEST"
echo "     sudo systemctl restart kubelet"
echo ""
echo "Files created:"
echo "  - $ETCD_MANIFEST_BACKUP (original manifest backup)"
echo "  - $RESTORE_DIR (restored etcd data directory)"
echo ""
