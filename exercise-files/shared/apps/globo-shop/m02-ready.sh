#!/usr/bin/env bash
# M02 pre-flight. Run on control1. Cleans up AND verifies. Green = roll.
FAIL=0
kubectl config set-context --current --namespace=default >/dev/null 2>&1

# Wipe anything a prior take left behind (silent, idempotent).
kubectl delete pod nginx temp --ignore-not-found >/dev/null 2>&1
kubectl delete deployment web limited --ignore-not-found >/dev/null 2>&1
kubectl delete svc web --ignore-not-found >/dev/null 2>&1
kubectl delete configmap app-config --ignore-not-found >/dev/null 2>&1
kubectl delete secret db-pass --ignore-not-found >/dev/null 2>&1
kubectl delete role pod-reader --ignore-not-found >/dev/null 2>&1
kubectl delete rolebinding pod-reader-binding --ignore-not-found >/dev/null 2>&1
rm -f ~/pod.yaml ~/deploy.yaml pod.yaml deploy.yaml 2>/dev/null

ok(){ echo "  OK    $*"; }; no(){ echo "  FAIL  $*"; FAIL=1; }

[ "$(kubectl get nodes --no-headers | awk '$2=="Ready"' | wc -l)" -eq 3 ] && ok "3 nodes Ready" || no "nodes not Ready"
[ "$(kubectl get pods -n default --no-headers 2>/dev/null | wc -l)" -eq 0 ] && ok "default is clean" || no "default has leftovers"
[ "$(kubectl get pods -n globo-dev  --no-headers 2>/dev/null | wc -l)" -eq 2 ] && ok "globo-dev  2 pods" || no "globo-dev down"
[ "$(kubectl get pods -n globo-prod --no-headers 2>/dev/null | wc -l)" -eq 3 ] && ok "globo-prod 3 pods" || no "globo-prod down"
curl -sf --max-time 5 http://192.168.50.10:30080/healthz >/dev/null && ok "dev  :30080 serving" || no "dev not serving"
curl -sf --max-time 5 http://192.168.50.10:30081/healthz >/dev/null && ok "prod :30081 serving" || no "prod not serving"

echo
[ $FAIL -eq 0 ] && echo "READY -- roll." || echo "NOT READY -- fix: cd ~/globo && kubectl apply -k overlays/dev && kubectl apply -k overlays/prod"
exit $FAIL
