#!/usr/bin/env bash
# =====================================================================
# CKA Course 4 -- kubectl context setup (RUN ONCE before recording)
# Substrate: Hyper-V Vagrant real-VM cluster (1 CP + 2 workers).
# Run this ON control1, reached over standard SSH from any terminal:
#     ssh vagrant@192.168.50.10   (password: vagrant)
#
# This course is about RBAC and credentials, so the demos use REAL
# credentials, not just --as impersonation. When this finishes you have:
#
#   cka-vagrant   the cluster-admin context. Every demo beat opens by
#                 pinning to this, so a stray context from another lab
#                 can never leak into a take.
#   frontend-dev  a genuine X.509 client certificate, signed by the
#                 cluster CA through the CertificateSigningRequest API.
#                 This is how Kubernetes authenticates a HUMAN.
#
# Module 2 builds a third context (deploy-bot) on camera, because a
# ServiceAccount authenticates with a bearer TOKEN, not a certificate.
# That contrast is the lesson -- do not pre-bake it here.
#
# Idempotent: safe to re-run between takes.
# =====================================================================
set -euo pipefail

CERT_DIR="${HOME}/cka-c04-certs"
CLUSTER_NAME="kubernetes"          # the name kubeadm writes into admin.conf
USER_CN="frontend-dev"             # becomes the RBAC username
USER_ORG="globomantics"            # becomes an RBAC group, if you want one

# --- 1. Pin the admin context to a name that reads well on camera -----
# kubeadm names it kubernetes-admin@kubernetes, which is long and looks
# identical to every other kubeadm cluster on screen. Rename once.
if kubectl config get-contexts -o name | grep -qx 'cka-vagrant'; then
  echo "[=] context cka-vagrant already exists"
else
  kubectl config rename-context kubernetes-admin@kubernetes cka-vagrant
  echo "[+] renamed kubernetes-admin@kubernetes -> cka-vagrant"
fi
kubectl config use-context cka-vagrant

# --- 2. Mint a real client certificate for frontend-dev ---------------
# A CSR the cluster CA signs. No Secret, no token: this is the X.509
# path, and it is what "a user" means to the Kubernetes API server.
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

if [[ ! -f "${USER_CN}.key" ]]; then
  openssl genrsa -out "${USER_CN}.key" 2048 2>/dev/null
  echo "[+] generated ${USER_CN}.key"
fi

# CN becomes the username the API server sees. O becomes a group.
openssl req -new \
  -key "${USER_CN}.key" \
  -out "${USER_CN}.csr" \
  -subj "/CN=${USER_CN}/O=${USER_ORG}" 2>/dev/null

# Re-approving a spent CSR is not a thing, so clear any prior object.
kubectl delete csr "${USER_CN}" --ignore-not-found >/dev/null 2>&1

kubectl apply -f - << CSR_EOF >/dev/null
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER_CN}
spec:
  request: $(base64 -w0 < "${USER_CN}.csr")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 604800
  usages:
  - client auth
CSR_EOF

kubectl certificate approve "${USER_CN}" >/dev/null
echo "[+] CSR ${USER_CN} approved by the cluster CA"

# The controller signs asynchronously, so wait for the cert to appear.
for _ in $(seq 1 30); do
  CERT=$(kubectl get csr "${USER_CN}" -o jsonpath='{.status.certificate}' 2>/dev/null || true)
  [[ -n "$CERT" ]] && break
  sleep 1
done
if [[ -z "${CERT:-}" ]]; then
  echo "[!] CSR was approved but never signed. Check the controller-manager." >&2
  exit 1
fi
echo "$CERT" | base64 -d > "${USER_CN}.crt"

# --- 3. Wire the cert into a context ----------------------------------
# --embed-certs bakes the PEM into the kubeconfig, so the context keeps
# working even if this cert directory is deleted between takes.
kubectl config set-credentials "${USER_CN}" \
  --client-certificate="${CERT_DIR}/${USER_CN}.crt" \
  --client-key="${CERT_DIR}/${USER_CN}.key" \
  --embed-certs=true >/dev/null

kubectl config set-context "${USER_CN}" \
  --cluster="${CLUSTER_NAME}" \
  --user="${USER_CN}" \
  --namespace=dev-team >/dev/null

kubectl config use-context cka-vagrant

echo
echo "=== contexts now available ==="
kubectl config get-contexts
echo
echo "frontend-dev authenticates but is granted NOTHING yet."
echo "That is the point: Module 1 demo 2 is where the grant arrives."
echo "Verify with:  kubectl --context frontend-dev auth whoami"
