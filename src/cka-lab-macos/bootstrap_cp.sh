#!/bin/bash
#================================================================
# bootstrap_cp.sh — Run on control1 to initialize the kubeadm cluster
#
# This is a MANUAL step — run it AFTER `./cka-lab.sh up` and AFTER
# you've snapshotted the clean prereq baseline. It intentionally
# stops BEFORE setting up a CNI so you can choose one.
#
# Usage (from your Mac):
#   vagrant ssh control1
#   bash /vagrant/bootstrap_cp.sh
#
# Or push and run in one command:
#   vagrant ssh control1 -c 'bash /vagrant/bootstrap_cp.sh'
#
# CNI choice (Flannel shown — see comment block below to swap):
#================================================================

set -euo pipefail

#================================================================
# CNI choice — Flannel (pinned)
#
# This lab uses Flannel for simplicity: single manifest, zero config,
# works out of the box for Course 1. CKA v1.35 also covers Cilium,
# Calico, and others — swap the CNI install command below to practice
# alternatives.
#
# Pod CIDR (10.244.0.0/16) is the Flannel default. If you swap in
# another CNI, change --pod-network-cidr to match that CNI's expected
# range (Calico: 192.168.0.0/16, Cilium: configurable, etc.).
#
# FLANNEL_VERSION is pinned to a release tag — NOT 'master' — so
# re-provisioning a year from now installs the same manifest you
# taught against. Bump deliberately, not accidentally.
#================================================================
FLANNEL_VERSION="v0.24.4"
POD_CIDR="10.244.0.0/16"

# On VMware Fusion with private_network, the static IP (192.168.50.10)
# is on eth1. Use that as the advertise address so workers reach the
# API server on the lab network, not on the NAT interface (eth0).
CP_IP=$(ip -4 addr show eth1 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
if [ -z "${CP_IP:-}" ]; then
  # Fallback: use the known static IP if eth1 detection fails
  CP_IP="192.168.50.10"
fi
echo "Control plane IP (private_network): $CP_IP"
echo "Workers will need this IP to join the cluster."
echo ""

echo "Initializing control plane..."
sudo kubeadm init \
  --apiserver-advertise-address="$CP_IP" \
  --pod-network-cidr="$POD_CIDR"

echo "Setting up kubeconfig..."
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$USER:$USER" "$HOME/.kube/config"

echo "Installing CNI (Flannel ${FLANNEL_VERSION})..."
kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/${FLANNEL_VERSION}/Documentation/kube-flannel.yml"

echo ""
echo "Get join command (copy this to each worker):"
kubeadm token create --print-join-command
