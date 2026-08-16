#!/usr/bin/env bash
# =====================================================================
# CKA Course 4 / Module 2 -- Service Accounts and Least-Privilege Access
# Substrate: Hyper-V Vagrant real-VM cluster (1 CP + 2 workers).
# Run these ON control1, reached over standard SSH from any terminal:
#     ssh vagrant@192.168.50.10   (password: vagrant)
#
# PREREQUISITE: ../setup-contexts.sh has run once.
#
# Module 1 authenticated a HUMAN with an X.509 certificate. This module
# authenticates a WORKLOAD with a bearer token, and beat 2 builds that
# third context on camera. Same API server, two credential types --
# that contrast is the whole module.
#
# These commands are byte-identical to the deck code slides + runbook.
# =====================================================================
set -euo pipefail

SA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Beat 1: Create deploy-bot and bind it to a deployer Role ---------
kubectl config use-context cka-vagrant

kubectl create namespace staging

kubectl create sa deploy-bot \
  -n staging

kubectl create role deployer \
  --verb=create,update,get,list \
  --resource=deployments,services \
  -n staging

kubectl create rolebinding \
  deploy-bot-deployer \
  --role=deployer \
  -n staging \
  --serviceaccount=staging:deploy-bot

kubectl describe rolebinding deploy-bot-deployer -n staging

# --- Beat 2: Prove the grant, then read the token inside the Pod ------
kubectl config use-context cka-vagrant

# A ServiceAccount is just a username with a long prefix.
kubectl auth can-i create deployments -n staging \
  --as system:serviceaccount:staging:deploy-bot
kubectl auth can-i --list -n staging \
  --as system:serviceaccount:staging:deploy-bot

kubectl apply -f "${SA_DIR}/deploy-runner.yaml" -n staging
kubectl wait --for=condition=Ready pod/deploy-runner -n staging --timeout=90s

# Three files, projected in by the kubelet. No Secret object involved.
kubectl exec -n staging deploy-runner -- \
  ls -l /var/run/secrets/kubernetes.io/serviceaccount/
kubectl exec -n staging deploy-runner -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/namespace; echo

# Now BECOME the workload. Impersonation shows you the answer; a real
# token makes the API server give it to you. Note the credential type:
# a bearer token, where frontend-dev used a client certificate.
TOKEN=$(kubectl create token deploy-bot -n staging --duration=30m)
kubectl config set-credentials deploy-bot --token="${TOKEN}" >/dev/null
kubectl config set-context deploy-bot \
  --cluster=kubernetes \
  --user=deploy-bot \
  --namespace=staging >/dev/null

kubectl config use-context deploy-bot
kubectl auth whoami                        # system:serviceaccount:staging:deploy-bot
kubectl get deployments                    # allowed by the deployer Role
kubectl get secrets || true                # Forbidden: no rule covers Secrets
kubectl config use-context cka-vagrant     # always switch back

# --- Beat 3: Decode the claims and mint a token on demand ------------
kubectl config use-context cka-vagrant

# The payload is the middle segment of the JWT. It is base64url, which
# uses a different alphabet than base64 and drops its padding, so let
# Python handle both rather than fighting it in shell.
kubectl exec -n staging deploy-runner -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token \
  | python3 -c "import sys,base64,json; p=sys.stdin.read().strip().split('.')[1]; print(json.dumps(json.loads(base64.urlsafe_b64decode(p + '=' * (-len(p) % 4))), indent=2))"

# Read aloud: iss, sub, aud, exp, and the kubernetes.io bound-object
# claim naming this Pod. That binding is why deleting the Pod kills
# the credential about a minute later.

# A short-lived token for testing or automation, printed and not stored.
kubectl create token deploy-bot -n staging --duration=10m

# --- Beat 4: Break it with a missing ServiceAccount, then opt out -----
kubectl config use-context cka-vagrant

# Rejected at admission. No Pod appears, so there is nothing to describe.
kubectl apply -f "${SA_DIR}/ghost-sa.yaml" || true
kubectl get pods -n staging                # ghost-runner is absent

# Same failure through a controller: the object exists, the Pods do not,
# and the message is waiting one level down on the ReplicaSet.
kubectl create deployment ghost-deploy --image=nginx:1.27 -n staging
kubectl patch deployment ghost-deploy -n staging \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"does-not-exist"}}}}'
kubectl describe rs -n staging | tail -20

# Take the credential away from a workload that never calls the API.
kubectl apply -f "${SA_DIR}/no-automount.yaml"
kubectl wait --for=condition=Ready pod/quiet-runner -n staging --timeout=90s
kubectl exec -n staging quiet-runner -- \
  ls /var/run/secrets/kubernetes.io/ || echo "no token mounted -- exactly the point"

# --- Reset to zero for the next take ----------------------------------
# kubectl delete namespace staging
# kubectl config delete-context deploy-bot
# kubectl config delete-user deploy-bot
