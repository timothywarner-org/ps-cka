#!/usr/bin/env bash
# =====================================================================
#  capture-m02.sh -- run M02's demo commands off camera and record
#  exactly what the cluster says, so the runbook's expected-output
#  blocks stop being predictions.
#
#  WHERE:  on control1, in ~/m02, beside lab.sh and the manifests
#  RUN:    ./capture-m02.sh          then send me capture-m02.txt
#
#  NOT `set -e`. Steps 21, 23, 24 and 27 are SUPPOSED to fail -- those
#  refusals are the teaching moments, and aborting on them would defeat
#  the whole point of running this.
# =====================================================================
set -uo pipefail
OUT="${1:-capture-m02.txt}"
: > "$OUT"

run() {  # run <step-number> <description> <command...>
    local n="$1"; shift
    local desc="$1"; shift
    {
        printf '\n===== STEP %s -- %s\n' "$n" "$desc"
        printf '$ %s\n' "$*"
    } >> "$OUT"
    "$@" >> "$OUT" 2>&1
    printf '[exit %s]\n' "$?" >> "$OUT"
}

{ echo "capture-m02 -- $(date -u +%FT%TZ)"
  echo "node: $(hostname)  kubectl: $(kubectl version --client -o json 2>/dev/null | head -c 200)"
} >> "$OUT"

echo "[1/3] Resetting to frame zero..."
./lab.sh reset >> "$OUT" 2>&1

echo "[2/3] Walking all 27 steps and capturing output..."
SA=system:serviceaccount:staging:deploy-bot

run 1  "context list"            kubectl config get-contexts
run 2  "create namespace"        kubectl create namespace staging
run 3  "create serviceaccount"   kubectl create sa deploy-bot -n staging
run 4  "sa .secrets is empty"    bash -c "kubectl get sa deploy-bot -n staging -o jsonpath='{.secrets}'; echo '  <- empty'"
run 5  "no Secrets in namespace" kubectl get secrets -n staging
run 6  "create Role"             kubectl create role deployer --verb=create,update,get,list --resource=deployments,services -n staging
run 7  "create RoleBinding"      kubectl create rolebinding deploy-bot-deployer --role=deployer --serviceaccount=staging:deploy-bot -n staging
run 8  "describe RoleBinding"    kubectl describe rolebinding deploy-bot-deployer -n staging
run 9  "current context"         kubectl config current-context
run 10 "can-i create deploy"     kubectl auth can-i create deployments -n staging --as "$SA"
run 11 "can-i create secrets"    kubectl auth can-i create secrets -n staging --as "$SA"
run 12 "can-i --list"            kubectl auth can-i --list -n staging --as "$SA"
run 13 "apply deploy-runner"     kubectl apply -f deploy-runner.yaml -n staging
run 14 "wait Ready"              kubectl wait --for=condition=Ready pod/deploy-runner -n staging --timeout=90s
run 15 "list projected files"    kubectl exec -n staging deploy-runner -- ls -1 /var/run/secrets/kubernetes.io/serviceaccount/
run 16 "cat namespace file"      bash -c "kubectl exec -n staging deploy-runner -- cat /var/run/secrets/kubernetes.io/serviceaccount/namespace; echo"
run 17 "expirationSeconds"       bash -c "kubectl get pod deploy-runner -n staging -o jsonpath='{range .spec.volumes[*]}{.projected.sources[*].serviceAccountToken.expirationSeconds}{end}'; echo"
run 18 "current context"         kubectl config current-context
run 19 "decode the JWT"          ./lab.sh jwt
run 20 "mint 10m token"          kubectl create token deploy-bot -n staging --duration=10m
run 21 "mint 5m -- EXPECT FAIL"  kubectl create token deploy-bot -n staging --duration=5m
run 22 "current context"         kubectl config current-context
run 23 "ghost SA -- EXPECT FAIL" kubectl apply -f ghost-sa.yaml
run 24 "ghost Pod -- EXPECT 404" kubectl get pod ghost-runner -n staging
run 25 "apply no-automount"      kubectl apply -f no-automount.yaml
run 26 "wait Ready"              kubectl wait --for=condition=Ready pod/quiet-runner -n staging --timeout=90s
run 27 "no token -- EXPECT FAIL" kubectl exec -n staging quiet-runner -- ls /var/run/secrets/kubernetes.io/serviceaccount/

echo "[3/3] Done. Resetting again so you are at frame zero for the take."
./lab.sh reset >> "$OUT" 2>&1

echo
echo "Captured to $OUT ($(wc -l < "$OUT") lines)."
echo "Steps 21, 23, 24 and 27 are EXPECTED to show errors -- that is correct."
