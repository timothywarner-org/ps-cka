#!/usr/bin/env bash
# =====================================================================
# CKA Course 4 / Module 1 -- the ONLY script you run on the node.
#
#     ./lab.sh            reset, then verify the whole demo   (do this first)
#     ./lab.sh reset      back to frame zero, ~8 sec          (between takes)
#     ./lab.sh mint       mint the frontend-dev user          (ON CAMERA, Demo 1)
#     ./lab.sh verify     walk the whole module, exit 0 or 1  (off camera)
#
# Everything is idempotent. Run any subcommand any number of times.
#
# Substrate: Hyper-V Vagrant cluster (control1 + worker1 + worker2),
#            Ubuntu 22.04, Kubernetes v1.35, containerd, Calico.
#            ssh vagrant@192.168.50.10   (password: vagrant)
#
# EXIT CONTRACT for `verify`: 0 means every expected ALLOW succeeded AND
# every expected DENY came back specifically 403 Forbidden. Both halves
# are asserted. A command that unexpectedly succeeds, unexpectedly fails,
# or fails for the WRONG REASON (401, connection refused, NotFound) all
# fail the run -- because on camera each of those looks different and
# only one of them is the lesson.
# =====================================================================
set -uo pipefail

ADMIN_CTX="cka-vagrant"
USER_CN="frontend-dev"
USER_ORG="globomantics"
CLUSTER="kubernetes"          # the name kubeadm writes into admin.conf
NS="dev-team"
CERT_DIR="${HOME}/certs"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEL_TIMEOUT="90s"             # kubectl delete --wait defaults to 168h if unset

G=$'\e[38;2;57;255;20m'; Y=$'\e[38;2;255;234;0m'; B=$'\e[38;2;86;180;233m'; R=$'\e[0m'
ok()   { echo "${G}[OK]${R}   $*"; }
info() { echo "${G}[INFO]${R} $*"; }
warn() { echo "${Y}[WARN]${R} $*"; }
err()  { echo "${Y}[FAIL]${R} $*"; }
step() { echo; echo "${G}>>> $*${R}"; }
tag()  { echo; echo "${G}[$1]${R} $2"; }

FAILURES=0
trap 'kubectl config use-context "$ADMIN_CTX" >/dev/null 2>&1' EXIT

# ctx -- switch context and PROVE it took. A silently failed switch would
# run the rest of a demo as the wrong identity, which is the single most
# confusing thing that can happen in an RBAC module.
ctx() {
  if ! kubectl config use-context "$1" >/dev/null 2>&1; then
    err "could not switch to context '$1' -- does it exist? (kubectl config get-contexts)"
    FAILURES=$((FAILURES + 1))
    return 1
  fi
  local now; now="$(kubectl config current-context 2>/dev/null)"
  if [[ "$now" != "$1" ]]; then
    err "asked for context '$1' but current-context reads '$now'"
    FAILURES=$((FAILURES + 1))
    return 1
  fi
  echo "${G}[CTX]${R}  now: $1"
}

# ---------------------------------------------------------------------
# Assertion helpers
#
# expect_deny used to accept ANY nonzero exit as "denied as expected".
# That is wrong and it hid real breakage: a missing kubectl, a refused
# connection, a 401 from an expired cert, and a genuine 403 all exit
# nonzero. Only one of them is the lesson. Both helpers below assert on
# the OUTPUT, not merely the exit code.
# ---------------------------------------------------------------------
expect_deny() {
  local label="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    err "$label -- expected 403 Forbidden, the command SUCCEEDED."
    echo "    A stale grant is probably live. Run: ./lab.sh reset"
    FAILURES=$((FAILURES + 1))
  elif grep -qiE 'forbidden|is not allowed' <<<"$out"; then
    echo "${G}[DENIED as expected]${R} $label"
    echo "    $(head -1 <<<"$out")"
  elif grep -qi 'Unauthorized' <<<"$out"; then
    err "$label -- got 401 Unauthorized, not 403 Forbidden. The credential is broken, not the RBAC."
    echo "    Fix: ./lab.sh mint"
    FAILURES=$((FAILURES + 1))
  else
    err "$label -- failed, but NOT with a Forbidden. This is not the lesson."
    echo "    $(head -2 <<<"$out")"
    FAILURES=$((FAILURES + 1))
  fi
}

expect_allow() {
  # The half that was missing entirely. Without it, `verify` could print
  # "every expected allow allowed" while an allow step was 403-ing, which
  # is a false green -- the worst outcome this script can produce.
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

# ---------------------------------------------------------------------
# reset -- back to frame zero
# ---------------------------------------------------------------------
do_reset() {
  info "Resetting C04 M01 to frame zero..."

  # GUARD. Without it, an unreachable API server makes every delete fail
  # silently AND makes the final "is dev-team gone?" check succeed, so the
  # script prints READY FOR TAKE over a cluster it never touched. /version
  # is served to everyone, so this needs no RBAC grant.
  if ! kubectl get --raw=/version >/dev/null 2>&1; then
    err "kubectl cannot reach the API server. Nothing was reset, and this is NOT green."
    echo "     Boot the lab first, from an admin pwsh on the host:"
    echo "       cd C:\\github\\ps-cka\\src\\cka-lab ; .\\Initialize-C04M01Lab.ps1"
    return 1
  fi

  kubectl config use-context "$ADMIN_CTX" >/dev/null 2>&1 \
    || warn "context $ADMIN_CTX not found -- run Initialize-C04M01Lab.ps1 from the host"

  # --timeout is NOT optional: kubectl substitutes 168 HOURS when --wait is
  # set and --timeout is omitted (pkg/cmd/delete/delete.go). A namespace stuck
  # on a finalizer would hang this script for a week with output suppressed.
  kubectl delete namespace "$NS" --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT" >/dev/null 2>&1
  kubectl delete clusterrolebinding "${USER_CN}-views-all" --ignore-not-found >/dev/null 2>&1
  # A spent CSR can never be re-approved, so it must go or mint fails.
  kubectl delete csr "$USER_CN" --ignore-not-found >/dev/null 2>&1
  kubectl config delete-context "$USER_CN" >/dev/null 2>&1
  kubectl config delete-user    "$USER_CN" >/dev/null 2>&1
  rm -rf "${CERT_DIR:?}" && mkdir -p "$CERT_DIR"

  # Assert on OUTPUT, not exit code: `get namespace` exits nonzero both when
  # the namespace is absent (good) and when the cluster is unreachable (bad).
  local left
  left="$(kubectl get namespace "$NS" --ignore-not-found -o name 2>/dev/null)" || {
    err "Lost contact with the API server mid-reset. NOT green."
    return 1
  }
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
# mint -- build frontend-dev from a real client certificate
#
# There is no User object in Kubernetes. For X.509: CN -> username,
# O -> group. That is the entire user model.
# ---------------------------------------------------------------------
do_mint() {
  kubectl config use-context "$ADMIN_CTX" >/dev/null || {
    err "cannot select $ADMIN_CTX"; return 1; }
  mkdir -p "$CERT_DIR"
  # Run in a subshell so this cd cannot leak into whatever calls do_mint.
  (
    cd "$CERT_DIR" || exit 1

    step "1/4  Key + CSR   (CN=${USER_CN} -> username,  O=${USER_ORG} -> group)"
    [[ -f "${USER_CN}.key" ]] || openssl genrsa -out "${USER_CN}.key" 2048 2>/dev/null
    openssl req -new -key "${USER_CN}.key" -out "${USER_CN}.csr" \
      -subj "/CN=${USER_CN}/O=${USER_ORG}" 2>/dev/null || { err "openssl req failed"; exit 1; }
    echo "${B}     $(openssl req -in "${USER_CN}.csr" -noout -subject)${R}"

    step "2/4  Submit to the cluster CA"
    # This delete is what makes the whole script re-runnable.
    kubectl delete csr "$USER_CN" --ignore-not-found >/dev/null 2>&1
    # base64 -w0 emits only [A-Za-z0-9+/=], none of which are special to sed's
    # | delimiter, so the substitution is safe. Exit status IS checked now --
    # a failed apply used to surface 20 seconds later as a confusing timeout.
    if ! sed "s|REQUEST_B64|$(base64 -w0 < "${USER_CN}.csr")|" "${HERE}/frontend-dev-csr.yaml" \
         | kubectl apply -f - >/dev/null; then
      err "kubectl apply of the CSR failed"; exit 1
    fi
    echo "${B}     $(kubectl get csr "$USER_CN" --no-headers)${R}"

    step "3/4  Approve   (kubectl certificate approve -- an exam command)"
    kubectl certificate approve "$USER_CN" >/dev/null || { err "certificate approve failed"; exit 1; }
    echo "${B}     $(kubectl get csr "$USER_CN" --no-headers)${R}"

    # The controller-manager signs asynchronously. Poll, do not sleep blind.
    local cert=""
    for _ in $(seq 1 20); do
      cert="$(kubectl get csr "$USER_CN" -o jsonpath='{.status.certificate}' 2>/dev/null || true)"
      [[ -n "$cert" ]] && break
      sleep 1
    done
    if [[ -z "$cert" ]]; then
      err "CSR approved but never signed after 20s."
      echo "     Check: kubectl -n kube-system get pods | grep controller-manager"
      exit 1
    fi
    echo "$cert" | base64 -d > "${USER_CN}.crt" || { err "could not decode the signed cert"; exit 1; }

    step "4/4  Write the kubeconfig context"
    # --embed-certs bakes the PEM in, so the context survives a wipe of ~/certs.
    kubectl config set-credentials "$USER_CN" \
      --client-certificate="${CERT_DIR}/${USER_CN}.crt" \
      --client-key="${CERT_DIR}/${USER_CN}.key" --embed-certs=true >/dev/null \
      || { err "set-credentials failed"; exit 1; }
    kubectl config set-context "$USER_CN" \
      --cluster="$CLUSTER" --user="$USER_CN" --namespace="$NS" >/dev/null \
      || { err "set-context failed"; exit 1; }
  ) || { kubectl config use-context "$ADMIN_CTX" >/dev/null 2>&1; return 1; }

  kubectl config use-context "$ADMIN_CTX" >/dev/null

  # Prove it before claiming it.
  if ! kubectl --context "$USER_CN" auth whoami >/dev/null 2>&1; then
    err "context $USER_CN was written but cannot authenticate."
    return 1
  fi

  echo
  echo "${G}================================================${R}"
  echo "${G}  USER MINTED -- and granted absolutely nothing${R}"
  echo "${G}================================================${R}"
  echo
}

# ---------------------------------------------------------------------
# verify -- walk the whole module non-interactively, off camera
# Step tags [N.M] match the runbook exactly.
# ---------------------------------------------------------------------
do_verify() {
  # --- Demo 1: identity is free, authorization is not ----------------
  tag 1.0 "Show every context  (six clusters on the real exam -- look before you touch)"
  ctx "$ADMIN_CTX" || return 1
  kubectl config get-contexts
  tag 1.1 "Namespace first (a Role is namespaced, so the order is tested)"
  expect_allow "create namespace $NS" kubectl create namespace "$NS"
  tag 1.2 "Mint a real user from an X.509 client certificate"
  do_mint || return 1
  tag 1.3 "Switch identity, then ask who you are (system:basic-user makes this free)"
  kubectl config get-contexts
  ctx "$USER_CN" || return 1
  expect_allow "auth whoami as $USER_CN" kubectl auth whoami
  tag 1.4 "Try to read -- expect 403, NOT 401"
  expect_deny "get pods as $USER_CN" kubectl get pods -n "$NS"
  tag 1.5 "Hand the identity back"
  ctx "$ADMIN_CTX" || return 1

  # --- Demo 2: two objects, never one --------------------------------
  tag 2.0 "Confirm the context before creating anything"
  kubectl config current-context
  tag 2.1 "Create the Role  (empty Resource Names = all Pods in this namespace)"
  expect_allow "create role pod-reader" \
    kubectl create role pod-reader --verb=get,list,watch --resource=pods -n "$NS"
  kubectl describe role pod-reader -n "$NS"
  tag 2.2 "Bind it -- Role says WHAT, binding says WHO"
  expect_allow "create rolebinding ${USER_CN}-reads" \
    kubectl create rolebinding "${USER_CN}-reads" --role=pod-reader --user="$USER_CN" -n "$NS"
  tag 2.3 "Switch in. Same command as [1.4] -- 'No resources found' IS the success"
  ctx "$USER_CN" || return 1
  expect_allow "get pods as $USER_CN (now granted)" kubectl get pods -n "$NS"

  # THE WRITE WALL. `kubectl delete pod --all` is NOT usable here: with an
  # empty namespace kubectl LISTs (which pod-reader allows), finds nothing,
  # deletes nothing, and exits 0 -- authorization for delete is never
  # consulted, so no 403 ever appears. A NAMED delete sends a real DELETE
  # request, and the API server authorizes BEFORE it looks for the object,
  # so a nonexistent pod still returns 403 and not 404. That is both the
  # correct assertion and a better teaching beat.
  tag 2.4 "Write wall -- get/list/watch was the whole grant"
  expect_deny "delete a named pod as $USER_CN" kubectl delete pod web-1 -n "$NS"
  expect_deny "create deployment as $USER_CN" \
    kubectl create deployment nginx --image=nginx -n "$NS"
  expect_deny "get secrets as $USER_CN" kubectl get secrets -n "$NS"
  tag 2.5 "Switch back, then verify by impersonation (the version you use at work)"
  ctx "$ADMIN_CTX" || return 1
  expect_allow "can-i list pods --as $USER_CN" \
    kubectl auth can-i list pods -n "$NS" --as "$USER_CN"
  kubectl auth can-i delete pods -n "$NS" --as "$USER_CN"   # prints 'no', exits 1 by design
  kubectl auth can-i --list -n "$NS" --as "$USER_CN"

  # --- Demo 3: the binding sets the scope ----------------------------
  # CONTROLLED EXPERIMENT. Same user, same `view` ClusterRole, the same
  # three questions before and after. The ONLY variable is binding KIND.
  tag 3.0 "Confirm you are the admin again"
  kubectl config current-context
  tag 3.1 "Attach view with a NAMESPACED RoleBinding"
  expect_allow "create rolebinding view-in-$NS" \
    kubectl create rolebinding "view-in-$NS" --clusterrole=view --user="$USER_CN" -n "$NS"
  tag 3.2 "Three questions -- expect allow, deny, deny"
  ctx "$USER_CN" || return 1
  expect_allow "get configmaps -n $NS"        kubectl get configmaps -n "$NS"
  expect_deny  "get configmaps -n kube-system" kubectl get configmaps -n kube-system
  expect_deny  "get namespaces (cluster-scoped)" kubectl get namespaces
  ctx "$ADMIN_CTX" || return 1
  tag 3.3 "SAME ClusterRole, ClusterRoleBinding this time (no -n: it has no namespace)"
  expect_allow "create clusterrolebinding ${USER_CN}-views-all" \
    kubectl create clusterrolebinding "${USER_CN}-views-all" --clusterrole=view --user="$USER_CN"
  tag 3.4 "The identical three questions -- expect allow, allow, allow"
  ctx "$USER_CN" || return 1
  expect_allow "get configmaps -n $NS"         kubectl get configmaps -n "$NS"
  expect_allow "get configmaps -n kube-system" kubectl get configmaps -n kube-system
  expect_allow "get namespaces"                kubectl get namespaces
  ctx "$ADMIN_CTX" || return 1

  # --- Demo 4: built-ins, then generate the YAML ---------------------
  tag 4.0 "Context check, one last time"
  kubectl config current-context
  tag 4.1 "The four that matter"
  expect_allow "get the four built-in ClusterRoles" \
    kubectl get clusterrole view edit admin cluster-admin
  tag 4.2 "view never reads Secrets. edit reads AND writes them. (THE missed fact)"
  # Separate "describe worked and found nothing" from "describe itself failed".
  # The old `|| echo "NO secrets rule in view"` printed the teaching conclusion
  # even when the describe blew up, which would have put a false statement on
  # screen. Capture first, then decide.
  if view_desc="$(kubectl describe clusterrole view 2>&1)"; then
    if grep -qi 'secret' <<<"$view_desc"; then
      err "view DOES mention secrets -- the deck is wrong for this cluster. DO NOT RECORD."
      FAILURES=$((FAILURES + 1))
    else
      ok "NO secrets rule in view  (confirmed by a describe that actually ran)"
    fi
  else
    err "describe clusterrole view failed -- cannot confirm the Secrets claim"
    FAILURES=$((FAILURES + 1))
  fi
  expect_allow "edit has a secrets rule" \
    bash -c "kubectl describe clusterrole edit | grep -i '^  secrets'"
  # Aggregation is a 15-second VERBAL callout on camera (slides 16-17 own it,
  # and the budget is 12 min). Checked here so nothing goes unverified.
  tag "4.2b" "Aggregation: edit has a label selector, not rules  [off-camera check]"
  expect_allow "edit carries an aggregationRule" \
    bash -c "kubectl get clusterrole edit -o yaml | grep -A6 aggregationRule"
  tag 4.3 "Generate, do not memorize -- --dry-run=client renders locally, no object is created"
  expect_allow "dry-run render of a Role" \
    kubectl create role pod-reader --verb=get,list,watch --resource=pods --dry-run=client -o yaml

  echo; echo "${G}=== verdict ===${R}"
  echo "Final context: $(kubectl config current-context)"
  if [[ $FAILURES -eq 0 ]]; then
    ok "Every expected ALLOW succeeded and every expected DENY returned 403."
    echo "     Run  ./lab.sh reset  then roll."
    return 0
  fi
  err "$FAILURES check(s) drifted from the runbook."
  echo "       Usual cause: a ClusterRoleBinding survived a prior take."
  echo "       Fix: ./lab.sh reset   then re-run."
  return 1
}

# ---------------------------------------------------------------------
SUB="${1:-all}"

# SELF-LOGGING. `verify` and the bare run write a transcript to ~/dry-run.txt
# themselves, so you never have to pipe.
#
# WHY: `./lab.sh | tee log` looks harmless and is not -- in a pipeline $? is
# TEE's status, not this script's, so a run that failed a check and exited 1
# would report success. Process substitution keeps stdout and stderr flowing
# to both places while the exit code and the EXIT trap stay in this shell.
TEE_PID=""
case "$SUB" in
  verify|all)
    LOG="${HOME}/dry-run.txt"
    exec > >(tee "$LOG"); TEE_PID=$!
    exec 2>&1
    info "Transcript: $LOG"
    ;;
esac

case "$SUB" in
  reset)  do_reset ;;
  mint)   do_mint ;;
  verify) do_verify ;;
  all)    do_reset && do_verify ;;
  *)      echo "usage: ./lab.sh [reset|mint|verify]   (no arg = reset + verify)"
          echo "       reset   frame zero, ~8 sec, between takes"
          echo "       mint    build the frontend-dev user (ON CAMERA, Demo 1)"
          echo "       verify  walk all four demos, exit 0 or 1"
          echo "       (bare)  reset then verify -- the one you want"
          exit 2 ;;
esac
RC=$?

# Close our end of the pipe and WAIT for tee to drain, rather than sleeping and
# hoping. A fixed sleep is a race that can drop exactly the verdict line you
# needed to read.
if [[ -n "$TEE_PID" ]]; then
  exec 1>&- 2>&-
  wait "$TEE_PID" 2>/dev/null
fi
exit "$RC"
