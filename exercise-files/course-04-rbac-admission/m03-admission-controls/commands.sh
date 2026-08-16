#!/usr/bin/env bash
# =====================================================================
# CKA Course 4 / Module 3 -- Admission Controls, Limits, and Governance
# Substrate: Hyper-V Vagrant real-VM cluster (1 CP + 2 workers).
# Run these ON control1, reached over standard SSH from any terminal:
#     ssh vagrant@192.168.50.10   (password: vagrant)
#
# PREREQUISITE: ../setup-contexts.sh has run once.
#
# NOTE FOR THE TAKE: the deck's diagnostic slide shows the quota error
# from the Kubernetes docs, which names mem-cpu-demo. Live output here
# names production-cap. Say the shape of the message, not the name.
#
# These commands are byte-identical to the deck code slides + runbook.
# =====================================================================
set -euo pipefail

M3_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Beat 1: Create the namespace and watch LimitRanger work ----------
kubectl config use-context cka-vagrant

kubectl create namespace production
kubectl apply -f "${M3_DIR}/limitrange.yaml"

# A Pod that names no resources at all.
kubectl run web-1 --image=nginx:1.27 -n production
kubectl wait --for=condition=Ready pod/web-1 -n production --timeout=90s

# The object you get is not the object you sent: the mutating pass wrote
# the numbers in before anything was stored.
kubectl get pod web-1 -n production -o jsonpath='{.spec.containers[0].resources}'; echo
kubectl describe pod web-1 -n production | grep -A6 -i 'limits\|requests'

# --- Beat 2: Break the ceiling, then fill the quota -------------------
kubectl config use-context cka-vagrant

# Add min and max so there is a ceiling to push against.
kubectl apply -f "${M3_DIR}/limitrange-ceiling.yaml"
kubectl describe limitrange production-defaults -n production

# Half one: the PER-CONTAINER maximum. Rejected on the validating pass.
kubectl apply -f "${M3_DIR}/oversized-pod.yaml" || true

# Half two: the NAMESPACE total. Add the quota, then fill it.
kubectl apply -f "${M3_DIR}/resourcequota.yaml"
kubectl describe resourcequota production-cap -n production

# Each replica requests 500m by LimitRange default; the cap is 2 cores.
kubectl create deployment filler --image=nginx:1.27 --replicas=6 -n production

sleep 5
kubectl get deployment,replicaset -n production
kubectl describe rs -n production | tail -25          # the Forbidden lives here
kubectl describe resourcequota production-cap -n production

# --- Beat 3: Harden a Pod and prove which user it runs as -------------
kubectl config use-context cka-vagrant

kubectl apply -f "${M3_DIR}/hardened-pod.yaml"
kubectl wait --for=condition=Ready pod/hardened -n production --timeout=90s

# Go inside and check the answer yourself rather than trusting the spec.
kubectl exec -n production hardened -- id
kubectl exec -n production hardened -- touch /root-test 2>&1 || \
  echo "read-only root filesystem -- exactly what readOnlyRootFilesystem buys you"

# --- Beat 4: Trace a Pod Security Admission refusal -------------------
kubectl config use-context cka-vagrant

# Turn PSA on for this namespace. enforce rejects, warn tells you now.
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=baseline --overwrite

# 1. Which policy is this namespace under?
kubectl get ns production --show-labels

# The Deployment is created. Watch for zero Pods.
kubectl apply -f "${M3_DIR}/privileged-deployment.yaml"
sleep 5

# 2. Did the object get created at all?
kubectl get deploy,rs,pods -n production -l app=legacy-agent

# 3. Object there, no Pods? Ask its owner.
kubectl describe rs -n production -l app=legacy-agent | tail -20

# 4. Which guardrail said no?
kubectl describe quota,limitrange -n production

# 5. Pod exists but will not start? That one is the kubelet, not admission.
kubectl describe pod web-1 -n production | tail -15

# --- Reset to zero for the next take ----------------------------------
# kubectl delete namespace production
