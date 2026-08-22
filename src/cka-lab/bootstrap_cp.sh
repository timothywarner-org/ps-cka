#!/bin/bash

set -euo pipefail

#================================================================
# CNI choice - Calico via the Tigera operator (pinned)
#
# This lab standardized on Calico in Course 2 Module 3, and every
# recorded module since assumes it. Calico is also the realistic
# choice: NetworkPolicy actually enforces, which Course 8 needs.
#
# Pod CIDR is 192.168.0.0/16 because that is what Calico's default
# Installation CR ships with. C02 M03 proves that alignment on
# camera, so changing it here would silently contradict a recorded
# module. If you swap in another CNI, change POD_CIDR to match that
# CNI's expected range (Flannel: 10.244.0.0/16, Cilium: configurable).
#
# CALICO_VERSION is pinned to a release tag - NOT 'master' - so
# re-provisioning a year from now installs the same manifests you
# taught against. Bump deliberately, not accidentally.
#
# NOTE: the Course 4 Initialize-C04M0*Lab.ps1 scripts do their own
# bootstrap and do not call this file. Keep the kubeadm flags and the
# pinned Calico version here in sync with those scripts.
#================================================================
CALICO_VERSION="v3.29.1"
POD_CIDR="192.168.0.0/16"

# Detect the node's IP on the default interface (DHCP from Hyper-V Default Switch)
CP_IP=$(hostname -I | awk '{print $1}')
echo "Control plane IP detected: $CP_IP"
echo "Workers will need this IP to join the cluster."
echo ""

echo "Initializing control plane..."
sudo kubeadm init \
  --apiserver-advertise-address="$CP_IP" \
  --pod-network-cidr="$POD_CIDR"

echo "Setting up kubeconfig..."
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $USER:$USER $HOME/.kube/config

echo "Installing CNI (Calico ${CALICO_VERSION} via Tigera operator)..."
# Two manifests, in order: the operator, then the Installation CR it watches.
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/tigera-operator.yaml"
kubectl create -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/custom-resources.yaml"

echo ""
echo "Waiting for Calico to come up (calico-system/calico-node)..."
kubectl -n calico-system rollout status ds/calico-node --timeout=180s || \
  echo "WARN: calico-node not ready yet. Check 'kubectl -n calico-system get pods'."

echo ""
echo "Get join command (copy this to each worker):"
kubeadm token create --print-join-command
