#!/bin/bash

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

echo "Installing CNI (Flannel ${FLANNEL_VERSION})..."
kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/${FLANNEL_VERSION}/Documentation/kube-flannel.yml"

echo ""
echo "Get join command (copy this to each worker):"
kubeadm token create --print-join-command
