#!/bin/bash
#
# m01-etcd-backup.sh
# ==================
# CKA Course 3, Module 1: Backing Up and Restoring etcd for Disaster Recovery
#
# This script demonstrates how to take a snapshot backup of the etcd database
# using etcdctl with certificate-based authentication.
#
# SETUP: Run this script ON the control-plane VM using:
#   vagrant ssh control1
#   cd /tmp  # or your working directory
#   bash m01-etcd-backup.sh
#
# KEY CONCEPTS:
#   - ETCDCTL_API=3 enables the v3 API (required for modern Kubernetes etcd)
#   - Four certificate flags are mandatory: --endpoints, --cacert, --cert, --key
#   - The backup file is a point-in-time snapshot of the entire cluster state
#   - Each backup should be timestamped for easy identification and rotation
#   - etcd certificates live at /etc/kubernetes/pki/etcd/ on the control-plane VM
#
# EXAM TIP:
#   - Missing any certificate flag causes silent failure (no error message)
#   - This is the single most common mistake on the CKA exam
#   - Verify the backup with etcdutl snapshot status <file> (etcd 3.6 moved it off etcdctl)
#
# USAGE:
#   vagrant ssh control1
#   ./m01-etcd-backup.sh
#
# OUTPUT:
#   Timestamp-based backup file in /tmp/ (e.g., etcd-backup-20260328-103015.db)
#   Snapshot status verification showing revision, key count, and size
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'  # No Color

# Configuration
ETCD_ENDPOINTS="https://127.0.0.1:2379"
ETCD_CACERT="/etc/kubernetes/pki/etcd/ca.crt"
ETCD_CERT="/etc/kubernetes/pki/etcd/server.crt"
ETCD_KEY="/etc/kubernetes/pki/etcd/server.key"
BACKUP_DIR="/tmp"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/etcd-backup-${TIMESTAMP}.db"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}etcd Backup Demonstration${NC}"
echo -e "${YELLOW}(Running on the control-plane VM)${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Step 1: Verify prerequisites
echo -e "${YELLOW}[Step 1] Verifying etcd certificate paths...${NC}"
for cert_file in "$ETCD_CACERT" "$ETCD_CERT" "$ETCD_KEY"; do
    if [[ ! -f "$cert_file" ]]; then
        echo -e "${RED}ERROR: Certificate file not found: $cert_file${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Found: $cert_file"
done
echo ""

# Step 2: Verify etcd is reachable
echo -e "${YELLOW}[Step 2] Verifying etcd connectivity...${NC}"
if ! ETCDCTL_API=3 etcdctl \
    --endpoints="$ETCD_ENDPOINTS" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY" \
    endpoint health &>/dev/null; then
    echo -e "${RED}ERROR: Cannot reach etcd at $ETCD_ENDPOINTS${NC}"
    echo "Verify that:"
    echo "  - You are running on the control-plane VM (vagrant ssh control1)"
    echo "  - etcd Pod is running: kubectl get pods -n kube-system | grep etcd"
    echo "  - Certificate flags are correct"
    exit 1
fi
echo -e "${GREEN}✓${NC} etcd is healthy and reachable"
echo ""

# Step 3: Take the snapshot backup
echo -e "${YELLOW}[Step 3] Taking etcd snapshot backup...${NC}"
echo "  Backup file: $BACKUP_FILE"
echo "  Endpoint:    $ETCD_ENDPOINTS"
echo ""

# The critical command: snapshot save with all four certificate flags
# ETCDCTL_API=3 is required (enables etcd v3 API)
# --endpoints: Address of etcd server (port 2379 is standard)
# --cacert: CA certificate for mTLS verification
# --cert: Client certificate for authentication
# --key: Client private key for authentication
ETCDCTL_API=3 etcdctl \
    --endpoints="$ETCD_ENDPOINTS" \
    --cacert="$ETCD_CACERT" \
    --cert="$ETCD_CERT" \
    --key="$ETCD_KEY" \
    snapshot save "$BACKUP_FILE"

# Verify the backup file was created
if [[ ! -f "$BACKUP_FILE" ]]; then
    echo -e "${RED}ERROR: Backup file was not created${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Snapshot saved successfully"
echo ""

# Step 4: Display backup file info
echo -e "${YELLOW}[Step 4] Backup file details...${NC}"
ls -lh "$BACKUP_FILE"
echo ""

# Step 5: Verify backup integrity with snapshot status
echo -e "${YELLOW}[Step 5] Verifying backup integrity...${NC}"
echo "Running: etcdutl snapshot status $BACKUP_FILE"
echo ""

# etcd 3.6 moved snapshot status to etcdutl (OFFLINE op -- reads the file, no TLS flags)
etcdutl snapshot status "$BACKUP_FILE" --write-out=table

echo ""
echo -e "${GREEN}✓${NC} Backup integrity verified"
echo ""

# Step 6: Summary
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Backup Summary${NC}"
echo -e "${YELLOW}========================================${NC}"
echo "Backup file: $BACKUP_FILE"
echo "Timestamp: $TIMESTAMP"
echo ""
echo "IMPORTANT: Keep this backup safe!"
echo "  - Store it on external storage"
echo "  - Rotate old backups monthly"
echo "  - Test restore procedures regularly"
echo ""
echo "Next: Use etcdutl snapshot restore to recover from this backup"
echo ""
