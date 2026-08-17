#!/usr/bin/env bash
# =====================================================================
# CKA Course 4 / Module 2 -- the ONLY script you run on the node.
#
#     ./lab.sh            reset, then verify the whole demo   (do this first)
#     ./lab.sh reset      back to frame zero, ~10 sec         (between takes)
#     ./lab.sh jwt        decode the Pod's projected token    (ON CAMERA, Demo 3)
#     ./lab.sh verify     walk the whole module, exit 0 or 1  (off camera)
#
# Substrate: Hyper-V Vagrant cluster (control1 + worker1 + worker2),
#            Ubuntu 22.04, Kubernetes v1.35, containerd, Calico.
#            ssh vagrant@192.168.50.10   (password: vagrant)
#
# NO jq ANYWHERE. jq is NOT installed on a stock Ubuntu 22.04 server and
# kubeadm does not pull it in -- verified on all three nodes. Every JSON
# read here uses `kubectl -o jsonpath` and every JWT decode uses coreutils
# only. A demo that shells out to jq dies on camera.
#
# EXIT CONTRACT for `verify`: 0 means every expected ALLOW succeeded AND
# every expected DENY failed for the RIGHT REASON. A command that
# unexpectedly succeeds, or fails with the wrong error, fails the run.
# =====================================================================
set -uo pipefail

ADMIN_CTX="cka-vagrant"
NS="staging"
SA="deploy-bot"
ROLE="deployer"
BINDING="deploy-bot-deployer"
POD="deploy-runner"
GHOST="ghost-runner"
QUIET="quiet-runner"
SUBJECT="system:serviceaccount:${NS}:${SA}"
MOUNT="/var/run/secrets/kubernetes.io/serviceaccount"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEL_TIMEOUT="90s"

G=$'\e[38;2;57;255;20m'; Y=$'\e[38;2;255;234;0m'; B=$'\e[38;2;86;180;233m'; R=$'\e[0m'
ok()   { echo "${G}[OK]${R}   $*"; }
info() { echo "${G}[INFO]${R} $*"; }
warn() { echo "${Y}[WARN]${R} $*"; }
err()  { echo "${Y}[FAIL]${R} $*"; }
step() { echo; echo "${G}>>> $*${R}"; }
tag()  { echo; echo "${G}[$1]${R} $2"; }

FAILURES=0
trap 'kubectl config use-context "$ADMIN_CTX" >/dev/null 2>&1' EXIT

ctx() {
  if ! kubectl config use-context "$1" >/dev/null 2>&1; then
    err "could not switch to context '$1' (kubectl config get-contexts)"
    FAILURES=$((FAILURES + 1)); return 1
  fi
  local now; now="$(kubectl config current-context 2>/dev/null)"
  [[ "$now" == "$1" ]] || { err "asked for '$1', current-context reads '$now'"; FAILURES=$((FAILURES+1)); return 1; }
  echo "${G}[CTX]${R}  now: $1"
}

# ---------------------------------------------------------------------
# jwt_payload -- decode a JWT's payload with coreutils ONLY.
#
# A JWT is base64URL (alphabet uses - and _) with the '=' padding STRIPPED.
# `base64 -d` wants the standard alphabet AND correct padding, so you must
# translate _- to /+ AND re-add padding, or it prints "invalid input" and
# you get a truncated payload on camera. Residue 2 needs '==', residue 3
# needs '='; residue 0 needs none. (Residue 1 is impossible for base64.)
# ---------------------------------------------------------------------
jwt_payload() {
  local s
  s=$(printf '%s' "$1" | cut -d. -f2 | tr '_-' '/+')
  case $(( ${#s} % 4 )) in
    2) s="${s}==" ;;
    3) s="${s}="  ;;
  esac
  printf '%s' "$s" | base64 -d 2>/dev/null
}

# Pull one top-level numeric/string claim without jq.
claim() { grep -o "\"$2\":[^,}]*" <<<"$1" | head -1 | cut -d: -f2- | tr -d '"'; }

expect_deny() {
  local label="$1" pattern="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    err "$label -- expected failure, the command SUCCEEDED. Stale state? ./lab.sh reset"
    FAILURES=$((FAILURES + 1))
  elif grep -qiE "$pattern" <<<"$out"; then
    echo "${G}[DENIED as expected]${R} $label"
    echo "    $(head -1 <<<"$out")"
  else
    err "$label -- failed, but NOT with /$pattern/. This is not the lesson."
    echo "    $(head -2 <<<"$out")"
    FAILURES=$((FAILURES + 1))
  fi
}

expect_allow() {
  local label="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "${G}[ALLOWED as expected]${R} $label"
    [[ -n "$out" ]] && echo "${B}    $(head -2 <<<"$out")${R}"
  else
    err "$label -- expected this to SUCCEED, it failed."
    echo "    $(head -2 <<<"$out")"
    FAILURES=$((FAILURES + 1))
  fi
}

expect_eq() {
  local label="$1" want="$2" got="$3"
  if [[ "$got" == "$want" ]]; then ok "$label  ($got)"
  else err "$label -- expected '$want', got '$got'"; FAILURES=$((FAILURES + 1)); fi
}

# ---------------------------------------------------------------------
# reset
# ---------------------------------------------------------------------
do_reset() {
  info "Resetting C04 M02 to frame zero..."
  if ! kubectl get --raw=/version >/dev/null 2>&1; then
    err "kubectl cannot reach the API server. Nothing was reset, and this is NOT green."
    echo "     Boot the lab first:  cd C:\\github\\ps-cka\\src\\cka-lab ; .\\Initialize-C04M02Lab.ps1"
    return 1
  fi
  kubectl config use-context "$ADMIN_CTX" >/dev/null 2>&1 \
    || warn "context $ADMIN_CTX not found -- run Initialize-C04M02Lab.ps1 from the host"

  # One namespace delete takes the SA, Role, RoleBinding, and every Pod with it.
  # --timeout is mandatory: kubectl substitutes 168 HOURS when --wait is set and
  # --timeout is omitted, so a finalizer-stuck namespace hangs this for a week.
  kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT" >/dev/null 2>&1
  # The automount demo patches the SA; nothing cluster-scoped survives, but the
  # scratch namespace from the default-SA gate does.
  kubectl delete namespace sa-probe --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT" >/dev/null 2>&1

  local left
  left="$(kubectl get namespace "$NS" --ignore-not-found -o name 2>/dev/null)" || {
    err "Lost contact with the API server mid-reset. NOT green."; return 1; }
  if [[ -n "$left" ]]; then
    warn "$NS is still terminating. Give it 15 seconds before you roll."
    return 1
  fi
  echo
  echo "${G}================================================${R}"
  echo "${G}  READY FOR TAKE${R}"
  echo "${G}================================================${R}"
  echo "  context : $(kubectl config current-context 2>/dev/null)"
  echo "  Demo 1 opens with:  kubectl config get-contexts"
  echo
}

# ---------------------------------------------------------------------
# jwt -- ON CAMERA in Demo 3. Decodes the token the Pod is actually
# carrying and prints the claims that matter, in reading order.
# ---------------------------------------------------------------------
do_jwt() {
  local tok payload
  tok="$(kubectl exec -n "$NS" "$POD" -- cat "$MOUNT/token" 2>/dev/null)"
  if [[ -z "$tok" ]]; then
    err "could not read the token from $POD. Is the Pod running? kubectl get pod -n $NS"
    return 1
  fi
  payload="$(jwt_payload "$tok")"
  if [[ -z "$payload" ]]; then err "JWT payload did not decode"; return 1; fi

  local iat exp warn_after sub aud now
  iat="$(claim "$payload" iat)"; exp="$(claim "$payload" exp)"
  warn_after="$(claim "$payload" warnafter)"; sub="$(claim "$payload" sub)"
  aud="$(grep -o '"aud":\[[^]]*\]' <<<"$payload" | cut -d: -f2-)"
  now="$(date +%s)"

  echo
  echo "${G}--- claims from the token inside $POD --------------------${R}"
  echo "  sub        : ${B}${sub}${R}"
  echo "  aud        : ${B}${aud}${R}"
  echo "  iss        : ${B}$(claim "$payload" iss)${R}"
  [[ -n "$iat" && -n "$exp" ]] && \
  echo "  exp        : ${B}$(date -d "@$exp" '+%Y-%m-%d %H:%M:%S') ${R}  (~$(( (exp - now) / 86400 )) days out)"
  [[ -n "$warn_after" ]] && \
  echo "  warnafter  : ${B}$(date -d "@$warn_after" '+%Y-%m-%d %H:%M:%S') ${R}  (~$(( (warn_after - now) / 60 )) min out)"
  echo
  echo "${G}--- the kubernetes.io block ------------------------------${R}"
  grep -o '"kubernetes.io":{.*}' <<<"$payload" | head -c 400; echo
  echo
  echo "${G}  THE POINT:${R} exp is about a YEAR out, not an hour. The API server"
  echo "  extends injected tokens. 'warnafter' is the hour mark, and the kubelet"
  echo "  rotates the FILE long before exp -- rotation limits exposure, not exp."
  echo
}

# ---------------------------------------------------------------------
# verify
# ---------------------------------------------------------------------
do_verify() {
  # ===== Demo 1 -- an account of its own ============================
  tag 1.0 "Show every context (six clusters on the real exam -- look before you touch)"
  ctx "$ADMIN_CTX" || return 1
  kubectl config get-contexts

  tag 1.1 "Namespace, then the ServiceAccount"
  expect_allow "create namespace $NS" kubectl create namespace "$NS"
  expect_allow "create sa $SA"        kubectl create sa "$SA" -n "$NS"

  # v1.24+ : creating a ServiceAccount no longer auto-creates a token Secret.
  tag 1.2 "No Secret was auto-created -- that stopped in v1.24"
  expect_eq "sa .secrets field is empty" "" \
    "$(kubectl get sa "$SA" -n "$NS" -o jsonpath='{.secrets}')"
  expect_eq "no service-account-token Secrets in $NS" "" \
    "$(kubectl get secrets -n "$NS" --field-selector type=kubernetes.io/service-account-token -o name 2>/dev/null)"

  tag 1.3 "A narrow Role, and a binding that names the ServiceAccount"
  expect_allow "create role $ROLE" \
    kubectl create role "$ROLE" --verb=create,update,get,list \
      --resource=deployments,services -n "$NS"
  expect_allow "create rolebinding $BINDING (--serviceaccount, never --user)" \
    kubectl create rolebinding "$BINDING" --role="$ROLE" \
      --serviceaccount="${NS}:${SA}" -n "$NS"
  expect_allow "describe the binding" kubectl describe rolebinding "$BINDING" -n "$NS"

  # ===== Demo 2 -- prove the grant, read the credential =============
  tag 2.0 "Confirm the context"
  kubectl config current-context

  # A ServiceAccount is just a username with a long prefix.
  tag 2.1 "Prove the grant by impersonation -- BEFORE any Pod exists"
  expect_allow "can-i create deployments as $SUBJECT" \
    kubectl auth can-i create deployments -n "$NS" --as "$SUBJECT"
  expect_allow "can-i --list for the subject" \
    kubectl auth can-i --list -n "$NS" --as "$SUBJECT"
  # The Role never mentions secrets, so this must be 'no' (exit 1).
  expect_deny "can-i create secrets as $SUBJECT" 'no' \
    kubectl auth can-i create secrets -n "$NS" --as "$SUBJECT"

  tag 2.2 "Run a Pod that names the ServiceAccount"
  expect_allow "apply $POD" kubectl apply -f "${HERE}/deploy-runner.yaml" -n "$NS"
  expect_allow "wait for $POD Ready" \
    kubectl wait --for=condition=Ready "pod/$POD" -n "$NS" --timeout=90s
  expect_eq "the Pod runs as $SA" "$SA" \
    "$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.serviceAccountName}')"

  tag 2.3 "Three files, projected in. No Secret object involved."
  expect_allow "list the mount" kubectl exec -n "$NS" "$POD" -- ls -1 "$MOUNT"
  expect_eq "namespace file says $NS" "$NS" \
    "$(kubectl exec -n "$NS" "$POD" -- cat "$MOUNT/namespace" 2>/dev/null)"

  # The projected volume is NOT in deploy-runner.yaml -- the API server's
  # ServiceAccount ADMISSION plugin added it. The kubelet then acquires the
  # token via TokenRequest. Two different components; the deck compresses them.
  tag 2.4 "The volume admission wrote for you, and its 3607"
  expect_eq "expirationSeconds on the injected volume" "3607" \
    "$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{range .spec.volumes[*]}{.projected.sources[*].serviceAccountToken.expirationSeconds}{end}')"

  # ===== Demo 3 -- decode the claims, mint on demand =================
  tag 3.0 "Confirm the context"
  kubectl config current-context

  tag 3.1 "Decode the token the Pod is carrying (coreutils only, no jq)"
  local tok payload sub exp iat
  tok="$(kubectl exec -n "$NS" "$POD" -- cat "$MOUNT/token" 2>/dev/null)"
  payload="$(jwt_payload "$tok")"
  if [[ -z "$payload" ]]; then
    err "JWT payload did not decode -- the base64url padding path is broken"
    FAILURES=$((FAILURES + 1))
  else
    ok "payload decoded ($(wc -c <<<"$payload") bytes)"
    sub="$(claim "$payload" sub)"
    expect_eq "sub claim is the username on the wire" "$SUBJECT" "$sub"
    exp="$(claim "$payload" exp)"; iat="$(claim "$payload" iat)"
    if [[ -n "$exp" && -n "$iat" ]]; then
      local life=$(( exp - iat ))
      if (( life > 86400 * 300 )); then
        ok "exp is $(( life / 86400 )) days out, NOT 3607s -- injected tokens are extended"
      else
        err "expected an extended exp (~1 year); got $life seconds. Deck slide 10 narration needs a re-check."
        FAILURES=$((FAILURES + 1))
      fi
    fi
    grep -q '"warnafter"' <<<"$payload" \
      && ok "warnafter claim present (the real hour mark)" \
      || { err "no warnafter claim -- slide 10's narration depends on it"; FAILURES=$((FAILURES+1)); }
  fi

  tag 3.2 "Mint a token on demand -- the post-v1.24 answer"
  expect_allow "create token --duration=10m" \
    kubectl create token "$SA" -n "$NS" --duration=10m
  # The server floor is 10 minutes. Asking for less is refused outright, which
  # is why the deck says ten and not five.
  expect_deny "create token --duration=5m is refused" 'less than 10 minutes' \
    kubectl create token "$SA" -n "$NS" --duration=5m

  # ===== Demo 4 -- break it, then take the credential away ==========
  tag 4.0 "Confirm the context"
  kubectl config current-context

  # Admission rejects at the API SERVER. No Pod object is persisted, nothing is
  # scheduled, no kubelet ever sees it -- so there is no CreateContainerConfigError
  # to find. That error is the missing-ConfigMap/Secret signature.
  tag 4.1 "A Pod naming a ServiceAccount that doesn't exist"
  expect_deny "apply $GHOST is rejected at admission" 'error looking up service account' \
    kubectl apply -f "${HERE}/ghost-sa.yaml"
  expect_eq "no Pod object was persisted" "" \
    "$(kubectl get pod "$GHOST" -n "$NS" --ignore-not-found -o name 2>/dev/null)"

  tag 4.2 "Opt out: a workload that never calls the API server"
  expect_allow "apply $QUIET (automountServiceAccountToken: false)" \
    kubectl apply -f "${HERE}/no-automount.yaml"
  expect_allow "wait for $QUIET Ready" \
    kubectl wait --for=condition=Ready "pod/$QUIET" -n "$NS" --timeout=90s
  expect_deny "the mount does not exist inside $QUIET" 'No such file|cannot access' \
    kubectl exec -n "$NS" "$QUIET" -- ls "$MOUNT"

  echo; echo "${G}=== verdict ===${R}"
  echo "Final context: $(kubectl config current-context)"
  if [[ $FAILURES -eq 0 ]]; then
    ok "Every expected ALLOW succeeded and every expected DENY failed correctly."
    echo "     Run  ./lab.sh reset  then roll."
    return 0
  fi
  err "$FAILURES check(s) drifted from the runbook."
  echo "       Fix: ./lab.sh reset   then re-run."
  return 1
}

# ---------------------------------------------------------------------
SUB="${1:-all}"
TEE_PID=""
case "$SUB" in
  verify|all)
    LOG="${HOME}/dry-run-m02.txt"
    exec > >(tee "$LOG"); TEE_PID=$!
    exec 2>&1
    info "Transcript: $LOG"
    ;;
esac

case "$SUB" in
  reset)  do_reset ;;
  jwt)    do_jwt ;;
  verify) do_verify ;;
  all)    do_reset && do_verify ;;
  *)      echo "usage: ./lab.sh [reset|jwt|verify]   (no arg = reset + verify)"
          echo "       reset   frame zero, ~10 sec, between takes"
          echo "       jwt     decode the Pod's projected token (ON CAMERA, Demo 3)"
          echo "       verify  walk all four demos, exit 0 or 1"
          echo "       (bare)  reset then verify -- the one you want"
          exit 2 ;;
esac
RC=$?

if [[ -n "$TEE_PID" ]]; then
  exec 1>&- 2>&-
  wait "$TEE_PID" 2>/dev/null
fi
exit "$RC"
