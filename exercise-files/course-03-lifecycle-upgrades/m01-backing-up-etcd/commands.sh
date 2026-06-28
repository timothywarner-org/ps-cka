#!/usr/bin/env bash
# =====================================================================
# CKA Course 3 / Module 1 -- Backing Up etcd : canonical demo commands
# Substrate: Hyper-V Vagrant real-VM cluster (1 CP + 2 workers).
# Run these ON control1, reached over standard SSH from any terminal:
#     ssh vagrant@192.168.50.10   (password: vagrant)
# Verified live on control1 2026-06-21: etcd 3.6 keeps `snapshot save` in etcdctl, but
# `snapshot status` and `snapshot restore` moved to etcdutl.
# These commands are byte-identical to the deck code slides + runbook.
# =====================================================================
set -euo pipefail

# --- Beat 1: stage the production data we are going to lose -----------
kubectl create namespace globomantics-shop
kubectl create deployment catalog-api --image=nginx --replicas=3 -n globomantics-shop
kubectl create configmap catalog-config --from-literal=env=production -n globomantics-shop
kubectl get all -n globomantics-shop

# --- Beat 2: back up etcd (etcdctl, online) and verify (etcdutl, offline)
# sudo on BOTH: server.key is root-only (0600) so save needs it, and the saved
# snapshot is root-owned so the etcdutl verify needs it too. No ETCDCTL_API=3 on
# etcd 3.6 -- it now prints an "unrecognized environment variable" warning.
sudo etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
sudo etcdutl snapshot status /tmp/etcd-backup.db --write-out=table

# --- Beat 3: simulate disaster, then restore with etcdutl -------------
kubectl delete namespace globomantics-shop                 # the 2 a.m. disaster

sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/ # stop the API server
sudo etcdutl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored                        # restore to a NEW dir
sudo sed -i 's#/var/lib/etcd$#/var/lib/etcd-restored#' \
  /etc/kubernetes/manifests/etcd.yaml                      # repoint etcd at it
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/ # bring API server back

kubectl get nodes                                          # cluster healthy?
kubectl get all -n globomantics-shop                       # objects recovered?

# --- Beat 4: inspect the stacked etcd topology -----------------------
kubectl get pods -n kube-system -l component=etcd -o wide
