#!/bin/bash
#================================================================
# join_worker.sh — Run on a worker VM (worker1, worker2) to join
# the kubeadm cluster bootstrapped on control1 (192.168.50.10).
#
# Fetches a fresh join command from control1 over SSH (kubeadm
# bootstrap tokens expire after 24h, so we never cache one) and
# executes it locally with sudo.
#
# Prereqs:
#   - bootstrap_cp.sh has already been run on control1
#   - SSH to control1 works as the vagrant user (Vagrant distributes
#     the insecure key, or use password 'vagrant' if prompted)
#================================================================

set -euo pipefail

CONTROL_PLANE_HOST="${CONTROL_PLANE_HOST:-192.168.50.10}"
CONTROL_PLANE_USER="${CONTROL_PLANE_USER:-vagrant}"

echo "[+] Fetching fresh join command from ${CONTROL_PLANE_USER}@${CONTROL_PLANE_HOST}..."

# StrictHostKeyChecking=no + UserKnownHostsFile=/dev/null keeps repeat
# runs clean after a `vagrant destroy` changes the host key.
JOIN_CMD=$(ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  "${CONTROL_PLANE_USER}@${CONTROL_PLANE_HOST}" \
  "sudo kubeadm token create --print-join-command")

if [ -z "$JOIN_CMD" ]; then
  echo "[ERROR] Empty join command returned from control1" >&2
  echo "        Has bootstrap_cp.sh been run on control1 yet?" >&2
  exit 1
fi

echo "[+] Running join on $(hostname)..."
sudo $JOIN_CMD

echo "[OK] Worker joined. Verify on control1 with: kubectl get nodes"
