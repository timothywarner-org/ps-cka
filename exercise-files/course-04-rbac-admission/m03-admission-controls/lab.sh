#!/usr/bin/env bash
# =====================================================================
# CKA Course 4 / Module 3 -- Admission Controls, Resource Limits, and
# Governance. The ONLY script you run on the node.
#
#     ./lab.sh            reset, then verify the whole demo   (do this first)
#     ./lab.sh reset      back to frame zero                  (between takes)
#     ./lab.sh verify     walk the whole module, exit 0 or 1   (off camera)
#
# There is no `jwt` verb here -- that was M02. M03 has three verbs.
#
# Everything is idempotent. Run any subcommand any number of times. A
# second `verify` with NO reset in between must come back green, and the
# script does real work to earn that (see clear_downstream).
#
# Substrate: Hyper-V Vagrant cluster (control1 + worker1 + worker2),
#            Ubuntu 22.04, Kubernetes v1.35, containerd, Calico.
#            ssh vagrant@192.168.50.10   (password: vagrant)
#
# NO jq ANYWHERE. jq is not installed on stock Ubuntu 22.04 and kubeadm
# does not pull it in. Every JSON read here is `kubectl -o jsonpath`, and
# the one bit of arithmetic uses awk, which IS in coreutils' company on
# every Ubuntu server image.
#
# NOT `set -e`. This module is MADE of deliberate refusals: an oversized
# Pod, a quota-exhausted Deployment, a privileged Pod. Under -e the first
# expected rejection would kill the script before it could assert that
# the rejection was the RIGHT one.
#
# EXIT CONTRACT for `verify`: 0 means every expected ALLOW succeeded, every
# expected DENY failed for the RIGHT REASON, and every number Tim says out
# loud (100m, 500m, 800m, 1500m, three replicas, 2 cores) matches the live
# cluster. Anything else exits 1 with a numbered fix list.
# =====================================================================
set -uo pipefail

ADMIN_CTX="cka-vagrant"
NS="production"
LR="production-defaults"        # LimitRange name, both manifests
QUOTA="production-cap"          # ResourceQuota name
POD="web-1"                     # Beat 1, the Pod that names no resources
GREEDY="greedy"                 # Beat 2, the Pod that breaks the ceiling
FILLER="filler"                 # Beat 2, the Deployment that fills the quota
HARDENED="hardened"             # Beat 3
LEGACY="legacy-agent"           # Beat 4, the privileged Deployment
TRAP_NS="quota-trap"            # scratch ns for the bare-cpu-key assertion
TRAP_POD="trap-probe"
PSS_NS="pss-probe"              # scratch ns for grading hardened-pod vs PSS
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEL_TIMEOUT="90s"               # kubectl delete --wait defaults to 168h if unset

# Numbers the narration says out loud. Assert against these, never against
# whatever the cluster happens to report, or a manifest edit silently
# rewrites the script's idea of "correct".
WANT_REQ_CPU="100m"; WANT_REQ_MEM="128Mi"
WANT_LIM_CPU="500m"; WANT_LIM_MEM="256Mi"
WANT_MAX_CPU="800m"                  # limitrange-ceiling.yaml
WANT_GREEDY_CPU="1500m"              # oversized-pod.yaml
WANT_FILLER_SPEC=6                   # what we ask for
WANT_FILLER_READY=3                  # what the quota actually permits
WANT_HARD_LIMITS_CPU_M=2000          # resourcequota.yaml limits.cpu: "2"
DEFAULTED_LIM_CPU_M=500              # what LimitRanger will charge the
                                     # hardened Pod, which declares no limits

G=$'\e[38;2;57;255;20m'; Y=$'\e[38;2;255;234;0m'; B=$'\e[38;2;86;180;233m'; R=$'\e[0m'
ok()   { echo "${G}[OK]${R}   $*"; }
info() { echo "${G}[INFO]${R} $*"; }
warn() { echo "${Y}[WARN]${R} $*"; }
err()  { echo "${Y}[FAIL]${R} $*"; }
step() { echo; echo "${G}>>> $*${R}"; }
tag()  { echo; echo "${G}[$1]${R} $2"; }

# Tim is red/green colourblind. Every verdict carries its meaning in the
# WORD, not the colour: [OK] [FAIL] [ALLOWED as expected] [DENIED as
# expected] [WARN]. Grep the transcript for FAIL and you have your answer
# with the colour stripped.

FAILURES=0
FIXES=()
add_fix() { FIXES+=("$1"); }
fail() { err "$1"; FAILURES=$((FAILURES + 1)); [[ $# -ge 2 ]] && add_fix "$2"; return 0; }

trap 'kubectl config use-context "$ADMIN_CTX" >/dev/null 2>&1' EXIT

# ctx -- switch context and PROVE it took. A silently failed switch runs the
# rest of the module against the wrong cluster, and admission errors from the
# wrong cluster look exactly like admission errors from the right one.
ctx() {
  if ! kubectl config use-context "$1" >/dev/null 2>&1; then
    fail "could not switch to context '$1' (kubectl config get-contexts)" \
         "Create or repair the '$1' context: run ../setup-contexts.sh once, then re-verify."
    return 1
  fi
  local now; now="$(kubectl config current-context 2>/dev/null)"
  if [[ "$now" != "$1" ]]; then
    fail "asked for '$1', current-context reads '$now'" \
         "Something else is rewriting ~/.kube/config mid-run. Close other shells and re-verify."
    return 1
  fi
  echo "${G}[CTX]${R}  now: $1"
}

# ---------------------------------------------------------------------
# Assertion helpers. Both halves assert on OUTPUT, not merely exit code:
# a missing kubectl, a refused connection, a 401, and a genuine 403 all
# exit nonzero and only one of them is the lesson.
# ---------------------------------------------------------------------
expect_deny() {
  local label="$1" pattern="$2"; shift 2
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    fail "$label -- expected failure, the command SUCCEEDED. Stale state? ./lab.sh reset" \
         "'$label' was admitted when it must be refused. Run ./lab.sh reset, then verify again."
  elif grep -qiE "$pattern" <<<"$out"; then
    echo "${G}[DENIED as expected]${R} $label"
    echo "    $(head -1 <<<"$out")"
  else
    fail "$label -- failed, but NOT with /$pattern/. This is not the lesson." \
         "'$label' failed for the wrong reason. Read the transcript line under it before you roll."
    echo "    $(head -2 <<<"$out")"
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
    fail "$label -- expected this to SUCCEED, it failed." \
         "'$label' must succeed. See the transcript line under it."
    echo "    $(head -2 <<<"$out")"
  fi
}

expect_eq() {
  local label="$1" want="$2" got="$3" hint="${4:-}"
  if [[ "$got" == "$want" ]]; then ok "$label  ($got)"
  else fail "$label -- expected '$want', got '$got'" \
            "${hint:-$label reads '$got' but the narration says '$want'. Reconcile before rolling.}"; fi
}

# ensure -- an idempotent create. Exit 0 passes. AlreadyExists passes AND
# SAYS SO OUT LOUD, so a second verify does not report a false failure and
# you can still see, in the transcript, that nothing was actually created.
# Anything else is still a failure: a quota rejection or a typo'd image must
# not be laundered into a green line.
ensure() {
  local label="$1"; shift
  local out rc
  out="$("$@" 2>&1)"; rc=$?
  if [[ $rc -eq 0 ]]; then
    ok "$label"
    [[ -n "$out" ]] && echo "${B}    $(head -1 <<<"$out")${R}"
    return 0
  fi
  if grep -qiE 'AlreadyExists|already exists' <<<"$out"; then
    ok "$label -- ALREADY PRESENT from an earlier run, reusing it. Not a failure."
    return 0
  fi
  fail "$label -- create failed, and NOT with AlreadyExists." \
       "'$label' could not be created. See the transcript line under it."
  echo "    $(head -2 <<<"$out")"
  return 1
}

# cpu_m -- a CPU quantity in millicores. "2" -> 2000, "1500m" -> 1500,
# "1.5" -> 1500, "" -> 0. The quota reports hard as "2" and used as "2",
# so comparing strings would make 2 cores look smaller than 500m.
cpu_m() {
  local v="${1:-}"
  [[ -z "$v" ]] && { echo 0; return 0; }
  if [[ "$v" == *m ]]; then echo "${v%m}"
  else awk -v x="$v" 'BEGIN{printf "%d", x*1000}'; fi
}

jp() { kubectl get "$1" "$2" -n "$3" -o jsonpath="$4" 2>/dev/null; }

# poll -- run a predicate until it succeeds or the clock runs out. Never
# `sleep 5 && hope`: on a real three-VM cluster the controller-manager is
# sometimes slower than five seconds and sometimes faster, and a blind sleep
# turns that into a coin flip on camera.
poll() {
  local secs="$1"; shift
  local i=0
  while (( i < secs )); do
    if "$@" >/dev/null 2>&1; then return 0; fi
    sleep 1; i=$((i + 1))
  done
  return 1
}

ns_gone() { ! kubectl get namespace "$1" -o name >/dev/null 2>&1; }

# ---------------------------------------------------------------------
# reset -- frame zero, and PROVE the namespace is really gone.
#
# `kubectl delete namespace` returns as soon as deletionTimestamp is set.
# The namespace then sits in Terminating for as long as its Pods take to
# die. The very next `kubectl create namespace production` fails with
# "object is being deleted", which on camera looks like the demo is broken
# when it is only early. So: fire the deletes, then WAIT, then say how long
# it took so Tim knows whether to expect that wait next take.
# ---------------------------------------------------------------------
do_reset() {
  info "Resetting C04 M03 to frame zero..."
  local t0 elapsed
  t0="$(date +%s)"

  # GUARD. Without it, an unreachable API server makes every delete fail
  # silently AND makes the "is it gone?" check succeed, so the script would
  # print READY FOR TAKE over a cluster it never touched.
  if ! kubectl get --raw=/version >/dev/null 2>&1; then
    err "kubectl cannot reach the API server. Nothing was reset, and this is NOT green."
    echo "     Boot the lab first, from an admin pwsh on the host:"
    echo "       cd C:\\github\\ps-cka\\src\\cka-lab ; .\\Initialize-C04M03Lab.ps1"
    return 1
  fi
  kubectl config use-context "$ADMIN_CTX" >/dev/null 2>&1 \
    || warn "context $ADMIN_CTX not found -- run ../setup-contexts.sh once"

  # Deleting the namespace takes the LimitRange, the ResourceQuota, web-1,
  # filler, hardened and legacy-agent with it. --wait=false so all three
  # namespaces terminate in parallel; the wait loop below is the real gate.
  # --timeout is set on the fallback delete because kubectl substitutes 168
  # HOURS when --wait is true and --timeout is omitted.
  local n
  for n in "$NS" "$TRAP_NS" "$PSS_NS"; do
    kubectl delete namespace "$n" --ignore-not-found --wait=false >/dev/null 2>&1
  done

  for n in "$NS" "$TRAP_NS" "$PSS_NS"; do
    if ! poll 120 ns_gone "$n"; then
      elapsed=$(( $(date +%s) - t0 ))
      err "namespace '$n' is STILL terminating after ${elapsed}s. NOT green."
      echo "     Look for a stuck Pod:   kubectl get pods -n $n"
      echo "     Then the finalizer:     kubectl get namespace $n -o jsonpath='{.spec.finalizers}'"
      return 1
    fi
    ok "namespace '$n' is gone (confirmed by a real GET, not by the delete returning)"
  done
  elapsed=$(( $(date +%s) - t0 ))

  # Nothing in M03 is cluster-scoped -- no ClusterRole, no CSR, no kubeconfig
  # user. The three namespaces ARE the whole footprint, which is why reset is
  # this short. Said out loud so nobody goes hunting for leftovers.
  info "M03 creates nothing cluster-scoped, so three namespace deletes IS the full reset."

  echo
  echo "${G}================================================${R}"
  echo "${G}  READY FOR TAKE${R}"
  echo "${G}================================================${R}"
  echo "  reset took : ${elapsed}s  (namespace termination, not network)"
  echo "  context    : $(kubectl config current-context 2>/dev/null)"
  echo "  Demo 1 opens with:  kubectl create namespace production"
  echo
}

# ---------------------------------------------------------------------
# clear_downstream -- THE TAKE-KILLER GATE, part one.
#
# Beat 2 asserts that EXACTLY THREE filler replicas land, and that number
# is arithmetic on the quota, not a property of the Deployment:
#
#   limits.cpu hard          = 2      = 2000m   (resourcequota.yaml)
#   web-1 limits.cpu         =          500m    (LimitRanger default)
#   each filler limits.cpu   =          500m    (LimitRanger default)
#   2000 - 500 = 1500 -> 1500/500 = 3 replicas, and the 4th is Forbidden.
#
# If `hardened` (another 500m, also defaulted) is still alive from a prior
# run, only TWO replicas fit and Tim's on-camera "three" is wrong. Same for
# legacy-agent. So before Beat 2 builds the ledger, tear down everything the
# LATER beats create and wait for the quota controller to hand the budget
# back. This one function is what makes a second `verify` with no reset
# green instead of confusingly, subtly wrong.
# ---------------------------------------------------------------------
used_limits_cpu_m() { cpu_m "$(jp resourcequota "$QUOTA" "$NS" '{.status.used.limits\.cpu}')"; }
quota_used_is() { [[ "$(used_limits_cpu_m)" == "$1" ]]; }

clear_downstream() {
  kubectl delete deployment "$FILLER" -n "$NS" --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT" >/dev/null 2>&1
  kubectl delete deployment "$LEGACY" -n "$NS" --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT" >/dev/null 2>&1
  kubectl delete pod "$HARDENED" -n "$NS" --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT" >/dev/null 2>&1
  kubectl delete pod "$GREEDY"   -n "$NS" --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT" >/dev/null 2>&1
  # Quota usage is released by the quota controller AFTER the Pods are gone,
  # not synchronously with the delete call. Poll the ledger, do not assume.
  #
  # Guarded on the quota EXISTING: on a first run Beat 2.1 fires before
  # resourcequota.yaml is applied, and polling a ledger that has not been
  # created yet would burn 60 seconds for nothing every single time.
  if kubectl get resourcequota "$QUOTA" -n "$NS" >/dev/null 2>&1; then
    poll 60 quota_used_is "$DEFAULTED_LIM_CPU_M"
    return 0
  fi
  return 2
}

# ---------------------------------------------------------------------
# verify
# ---------------------------------------------------------------------
do_verify() {

  # =================================================================
  # Beat 1 -- LimitRanger MUTATES. The object you get back is not the
  # object you sent.
  # =================================================================
  tag 1.0 "Confirm the context before touching anything"
  ctx "$ADMIN_CTX" || return 1

  tag 1.1 "Namespace, then the LimitRange that will do the defaulting"
  ensure "create namespace $NS" kubectl create namespace "$NS"
  # apply, not create -- apply is idempotent by design, so no ensure needed.
  expect_allow "apply limitrange.yaml" kubectl apply -f "${HERE}/limitrange.yaml"

  tag 1.2 "A Pod that names NO resources at all"
  ensure "run $POD (no resources block anywhere in the command)" \
    kubectl run "$POD" --image=nginx:1.27 -n "$NS"
  expect_allow "wait for $POD Ready" \
    kubectl wait --for=condition=Ready "pod/$POD" -n "$NS" --timeout=90s

  # ASSERTION 1 -- LimitRanger's MUTATING pass.
  # PROTECTS: "the object you get back is not the object you sent -- admission
  # wrote these four numbers in before etcd ever saw the Pod."
  # LimitRanger is admission plugin #6 of 39 in AllOrderedPlugins, long before
  # ResourceQuota at #38, which is why the defaults exist to be counted later.
  # https://v1-35.docs.kubernetes.io/docs/concepts/policy/limit-range/
  # https://v1-35.docs.kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#limitranger
  tag 1.3 "The four numbers admission wrote onto the LIVE object"
  expect_eq "$POD requests.cpu was defaulted"  "$WANT_REQ_CPU" \
    "$(jp pod "$POD" "$NS" '{.spec.containers[0].resources.requests.cpu}')" \
    "LimitRanger did not default requests.cpu. Is limitrange.yaml applied BEFORE web-1 is created? Order matters -- admission only runs on create."
  expect_eq "$POD requests.memory was defaulted" "$WANT_REQ_MEM" \
    "$(jp pod "$POD" "$NS" '{.spec.containers[0].resources.requests.memory}')" \
    "LimitRanger did not default requests.memory. Re-apply limitrange.yaml, delete web-1, re-run."
  expect_eq "$POD limits.cpu was defaulted"    "$WANT_LIM_CPU" \
    "$(jp pod "$POD" "$NS" '{.spec.containers[0].resources.limits.cpu}')" \
    "web-1 limits.cpu is not 500m, so the whole Beat 2 arithmetic (three replicas) is wrong. Fix the LimitRange first."
  expect_eq "$POD limits.memory was defaulted" "$WANT_LIM_MEM" \
    "$(jp pod "$POD" "$NS" '{.spec.containers[0].resources.limits.memory}')" \
    "web-1 limits.memory is not 256Mi. Re-apply limitrange.yaml, delete web-1, re-run."

  # Which plugin wrote them, in the plugin's own words. This annotation is the
  # receipt, and it is the difference between "Kubernetes did it" and being
  # able to NAME the admission controller on camera.
  local lrann
  lrann="$(jp pod "$POD" "$NS" '{.metadata.annotations.kubernetes\.io/limit-ranger}')"
  if grep -q 'LimitRanger' <<<"$lrann"; then
    ok "the Pod carries LimitRanger's own receipt: $lrann"
  else
    fail "no kubernetes.io/limit-ranger annotation on $POD" \
         "web-1 has no LimitRanger annotation. The numbers may have come from the manifest, not admission -- do not claim mutation on camera."
  fi

  # =================================================================
  # Beat 2 -- the ceiling, then the namespace total.
  # =================================================================
  tag 2.0 "Confirm the context"
  kubectl config current-context

  # THE TAKE-KILLER GATE, part one. Runs BEFORE the ledger is built so the
  # replica arithmetic starts from a known budget on every single run.
  tag 2.1 "Tear down anything the later beats left behind, and wait for the budget back"
  if clear_downstream; then
    expect_eq "limits.cpu used after the teardown (in millicores)" "$DEFAULTED_LIM_CPU_M" \
      "$(used_limits_cpu_m)" \
      "The quota still shows more than $POD's 500m after tearing down filler/hardened/legacy-agent. Something from a prior take is still holding budget: ./lab.sh reset."
  else
    info "no ResourceQuota in $NS yet on this run, so there is no ledger to release. Expected on a fresh reset."
  fi

  tag 2.2 "Add min and max so there is a ceiling to push against"
  expect_allow "apply limitrange-ceiling.yaml (same defaults, plus min and max)" \
    kubectl apply -f "${HERE}/limitrange-ceiling.yaml"
  # Assert the ceiling from the LIVE LimitRange. Tim says "800 milli" out loud;
  # if the manifest is ever edited this catches it before the microphone does.
  expect_eq "live LimitRange max cpu per container" "$WANT_MAX_CPU" \
    "$(jp limitrange "$LR" "$NS" '{.spec.limits[0].max.cpu}')" \
    "The LimitRange ceiling is not 800m, so the greedy-Pod rejection message will not read the way the deck slide reads."

  # ASSERTION 2 -- LimitRanger's VALIDATING pass.
  # PROTECTS: "the same plugin that quietly filled in your blanks will refuse
  # you outright, and it tells you BOTH the constraint and what you asked for."
  # The pattern demands both numbers, because a bare "Forbidden" would let a
  # generic quota or PSA error masquerade as the LimitRange lesson.
  tag 2.3 "The PER-CONTAINER maximum -- rejected, and the message does the teaching"
  expect_deny "apply oversized-pod.yaml (limits.cpu ${WANT_GREEDY_CPU} vs max ${WANT_MAX_CPU})" \
    "maximum cpu usage per Container is ${WANT_MAX_CPU}.*${WANT_GREEDY_CPU}" \
    kubectl apply -f "${HERE}/oversized-pod.yaml"
  # Admission rejects at the API SERVER, so nothing was persisted. There is no
  # Pending Pod to find and no kubelet involved -- that distinction is the
  # whole point of the module.
  expect_eq "no '$GREEDY' Pod object was persisted" "" \
    "$(kubectl get pod "$GREEDY" -n "$NS" --ignore-not-found -o name 2>/dev/null)" \
    "A '$GREEDY' Pod exists. Admission did NOT reject it -- the LimitRange max is missing or wrong."

  tag 2.4 "Now the NAMESPACE total"
  expect_allow "apply resourcequota.yaml" kubectl apply -f "${HERE}/resourcequota.yaml"
  expect_eq "live quota hard limits.cpu (in millicores)" "$WANT_HARD_LIMITS_CPU_M" \
    "$(cpu_m "$(jp resourcequota "$QUOTA" "$NS" '{.status.hard.limits\.cpu}')")" \
    "The quota's hard limits.cpu is not 2 cores, so 'only three fit' is arithmetic about a cap that no longer exists."

  # ASSERTION 3 -- the trap that resourcequota.yaml calls out in a comment:
  # bare `cpu` and `memory` in a quota mean REQUESTS, never limits.
  # PROTECTS: "if you write cpu: 2 you have capped requests, and every
  # container's LIMIT can still be four times that. The exam asks this."
  #
  # Asserted from live admission, not from belief. The probe quota caps bare
  # `cpu` at 200m. The probe Pod asks for requests 100m and limits 1000m:
  #   - if bare cpu meant LIMITS, 1000m > 200m and this Pod is Forbidden
  #   - because bare cpu means REQUESTS, 100m <= 200m and it is ADMITTED
  # An admitted Pod is therefore proof, not evidence. Then the ledger is read
  # back to show `used.cpu` tracking the 100m request and ignoring the 1000m.
  # https://v1-35.docs.kubernetes.io/docs/concepts/policy/resource-quotas/
  #   -- the table there reads, verbatim: cpu "Same as requests.cpu"
  tag 2.5 "Bare 'cpu' in a quota means REQUESTS -- proved by what admission does"
  ensure "create scratch namespace $TRAP_NS (no LimitRange in it, on purpose)" \
    kubectl create namespace "$TRAP_NS"
  expect_allow "apply the probe quota (hard: cpu: 200m -- the bare key)" bash -c "
    kubectl apply -f - <<'YAML'
apiVersion: v1
kind: ResourceQuota
metadata:
  name: bare-key-probe
  namespace: ${TRAP_NS}
spec:
  hard:
    cpu: 200m
YAML"
  # apply, so a second verify is a no-op update rather than an AlreadyExists.
  expect_allow "apply $TRAP_POD: requests.cpu=100m, limits.cpu=1000m -- ADMITTED, so bare cpu is requests" bash -c "
    kubectl apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: ${TRAP_POD}
  namespace: ${TRAP_NS}
spec:
  containers:
  - name: app
    image: nginx:1.27
    resources:
      requests: { cpu: 100m }
      limits:   { cpu: 1000m }
YAML"
  trap_used_is_100m() { [[ "$(cpu_m "$(jp resourcequota bare-key-probe "$TRAP_NS" '{.status.used.cpu}')")" == "100" ]]; }
  if poll 45 trap_used_is_100m; then
    ok "probe quota used.cpu reads 100m -- the REQUEST. The 1000m limit is not counted by a bare key."
  else
    fail "probe quota used.cpu is '$(jp resourcequota bare-key-probe "$TRAP_NS" '{.status.used.cpu}')', expected 100m" \
         "The bare-cpu-key probe did not settle on 100m. Do NOT say 'bare cpu means requests' on camera until this reads 100m."
  fi

  tag 2.6 "Fill the quota: ask for six, and let the cap answer"
  ensure "create deployment $FILLER --replicas=$WANT_FILLER_SPEC" \
    kubectl create deployment "$FILLER" --image=nginx:1.27 --replicas="$WANT_FILLER_SPEC" -n "$NS"
  # A Deployment asking for more than the quota allows still SUCCEEDS -- the
  # docs are explicit that "the creation of the Deployment ... succeeds, but
  # the Deployment may not be able to get all of the Pods it manages to
  # exist." The refusal lives one level down, on the ReplicaSet.
  # https://v1-35.docs.kubernetes.io/docs/concepts/policy/resource-quotas/
  filler_ready_is_three() { [[ "$(jp deployment "$FILLER" "$NS" '{.status.readyReplicas}')" == "$WANT_FILLER_READY" ]]; }
  poll 120 filler_ready_is_three

  # ASSERTION 4 -- exactly three, not six. Tim says "three" out loud.
  tag 2.7 "Exactly THREE landed, not six -- the number Tim says out loud"
  expect_eq "$FILLER spec.replicas (what we asked for)" "$WANT_FILLER_SPEC" \
    "$(jp deployment "$FILLER" "$NS" '{.spec.replicas}')" \
    "The filler Deployment is not asking for six. Recreate it with --replicas=6."
  expect_eq "$FILLER status.readyReplicas (what the quota permitted)" "$WANT_FILLER_READY" \
    "$(jp deployment "$FILLER" "$NS" '{.status.readyReplicas}')" \
    "Filler is not at exactly 3/6. Run ./lab.sh reset -- a leftover Pod from a prior take is eating the budget, and the on-camera 'three' will be wrong."
  expect_eq "$FILLER Pods actually created" "$WANT_FILLER_READY" \
    "$(kubectl get pods -n "$NS" -l app="$FILLER" --no-headers 2>/dev/null | wc -l | tr -d ' ')" \
    "The filler Pod count is not 3. Same cause as above: stale state. ./lab.sh reset."

  # The ReplicaSet is where the Forbidden lives, and it must be a QUOTA
  # Forbidden here. Beat 4 asserts the opposite for the same object shape,
  # and the contrast is the teaching.
  tag 2.8 "Where the refusal actually lives: the ReplicaSet, and it names the quota"
  local rstext=""
  rs_says_quota() {
    rstext="$(kubectl get rs -n "$NS" -l app="$FILLER" -o jsonpath='{range .items[*]}{.status.conditions[*].message}{end}' 2>/dev/null)
$(kubectl describe rs -n "$NS" -l app="$FILLER" 2>/dev/null | tail -30)"
    grep -qi 'exceeded quota' <<<"$rstext"
  }
  if poll 60 rs_says_quota; then
    ok "the ReplicaSet reports 'exceeded quota' -- the Deployment is fine, the Pods are refused"
    echo "${B}    $(grep -io 'exceeded quota.*' <<<"$rstext" | head -1 | cut -c1-160)${R}"
  else
    fail "no 'exceeded quota' anywhere on the $FILLER ReplicaSet" \
         "The filler ReplicaSet never reported a quota Forbidden. Check that resourcequota.yaml is applied BEFORE the Deployment."
  fi

  # ASSERTION 5 -- the ledger, and the gate that saves Beat 3.
  # PROTECTS Beat 3 entirely. hardened-pod.yaml declares REQUESTS and no
  # LIMITS, so LimitRanger defaults its limits.cpu to 500m -- and if the
  # budget is full, ResourceQuota refuses the Pod, `kubectl wait
  # --timeout=90s` burns 90 seconds of dead air, and Beats 3.2 and 3.3 have
  # no Pod to exec into. So: refuse a green light unless 500m is free.
  tag 2.9 "The ledger, read as arithmetic and not as a wall of text"
  local hard_m used_m free_m
  hard_m="$(cpu_m "$(jp resourcequota "$QUOTA" "$NS" '{.status.hard.limits\.cpu}')")"
  used_m="$(used_limits_cpu_m)"
  free_m=$(( hard_m - used_m ))
  echo "    limits.cpu   hard = ${hard_m}m"
  echo "    limits.cpu   used = ${used_m}m   ($POD 500m + ${WANT_FILLER_READY} x filler 500m)"
  echo "    limits.cpu   free = ${free_m}m"
  expect_eq "limits.cpu is FULL at this point in the demo" "$hard_m" "$used_m" \
    "The quota is not exactly full after filler lands, so 'the cap answered' is not what the screen shows."
  if (( free_m < DEFAULTED_LIM_CPU_M )); then
    warn "limits.cpu has only ${free_m}m free and the hardened Pod will be defaulted to ${DEFAULTED_LIM_CPU_M}m."
    warn "This is EXPECTED here -- Beat 3 deletes $FILLER first. That delete is not optional."
  fi

  # =================================================================
  # Beat 3 -- harden a Pod. THE TAKE-KILLER GATE, part two.
  # =================================================================
  tag 3.0 "Confirm the context"
  kubectl config current-context

  # THE FIX. Delete filler BEFORE applying hardened-pod.yaml. Without this
  # line the hardened Pod is Forbidden by the quota, `kubectl wait` sits for
  # 90 silent seconds, and the rest of Beat 3 has nothing to talk to.
  tag 3.1 "Give the budget back BEFORE asking for the hardened Pod"
  expect_allow "delete deployment $FILLER (the line that saves this beat)" \
    kubectl delete deployment "$FILLER" -n "$NS" --ignore-not-found --wait=true --timeout="$DEL_TIMEOUT"
  quota_has_room() { (( $(cpu_m "$(jp resourcequota "$QUOTA" "$NS" '{.status.hard.limits\.cpu}')") \
                      - $(used_limits_cpu_m) >= DEFAULTED_LIM_CPU_M )); }
  if poll 90 quota_has_room; then
    used_m="$(used_limits_cpu_m)"
    ok "limits.cpu used is back to ${used_m}m of ${hard_m}m -- $(( hard_m - used_m ))m free, and the hardened Pod needs ${DEFAULTED_LIM_CPU_M}m"
  else
    used_m="$(used_limits_cpu_m)"
    fail "quota did not release: ${used_m}m of ${hard_m}m still used, under ${DEFAULTED_LIM_CPU_M}m free" \
         "The quota never gave the budget back after deleting $FILLER. Do NOT roll Beat 3 -- kubectl wait will hang for 90 seconds on camera. Run ./lab.sh reset."
    # No point applying the hardened Pod into a full quota; that is the
    # failure this whole gate exists to prevent. Say so and skip ahead.
    warn "skipping the hardened-Pod beat: applying it now would reproduce the exact failure this gate is for."
  fi

  if quota_has_room; then
    tag 3.2 "Apply the hardened Pod (requests only -- LimitRanger supplies the limits)"
    expect_allow "apply hardened-pod.yaml" kubectl apply -f "${HERE}/hardened-pod.yaml"
    expect_allow "wait for $HARDENED Ready" \
      kubectl wait --for=condition=Ready "pod/$HARDENED" -n "$NS" --timeout=90s
    # It declared no limits; prove admission supplied them, and that they are
    # the 500m the ledger arithmetic assumed.
    expect_eq "$HARDENED limits.cpu, which the manifest never mentions" "$WANT_LIM_CPU" \
      "$(jp pod "$HARDENED" "$NS" '{.spec.containers[0].resources.limits.cpu}')" \
      "The hardened Pod's limits.cpu is not the defaulted 500m, so the quota arithmetic in this script is describing a different Pod."

    tag 3.3 "Check the answer from INSIDE, not from the spec"
    expect_allow "exec id (expect uid=101, not root)" kubectl exec -n "$NS" "$HARDENED" -- id
    expect_eq "the Pod really runs as UID 101" "101" \
      "$(kubectl exec -n "$NS" "$HARDENED" -- id -u 2>/dev/null | tr -d '\r')" \
      "The hardened Pod is not running as UID 101. runAsUser is not taking effect -- do not claim non-root on camera."
    # readOnlyRootFilesystem is a kubelet/runtime behaviour, NOT admission.
    # Saying that out loud is the point of putting it in an admission module.
    expect_deny "write to / inside $HARDENED" 'Read-only file system|cannot touch' \
      kubectl exec -n "$NS" "$HARDENED" -- touch /root-test
    expect_allow "write to /tmp (the emptyDir) still works" \
      kubectl exec -n "$NS" "$HARDENED" -- touch /tmp/ok
  fi

  # ASSERTION 7 -- restricted, or only baseline? Settled here, live.
  #
  # FINDING (this was the open question; it is now closed): hardened-pod.yaml
  # meets BASELINE. It does NOT meet RESTRICTED. Restricted additionally
  # REQUIRES, per the v1.35 Pod Security Standards control table:
  #   * seccompProfile.type in {RuntimeDefault, Localhost}  -- NOT SET here
  #   * capabilities.drop must contain "ALL"                 -- NOT SET here
  # The manifest DOES satisfy restricted's runAsNonRoot: true and
  # allowPrivilegeEscalation: false, and emptyDir is on restricted's allowed
  # volume list -- which is exactly why it LOOKS restricted at a glance and
  # why the narration is at risk of overclaiming.
  # https://v1-35.docs.kubernetes.io/docs/concepts/security/pod-security-standards/
  #
  # This block sits OUTSIDE the quota gate on purpose. It grades the MANIFEST,
  # which is what ships, so it must still run and still print its warning on a
  # run where the quota gate refused to bring the Pod up.
  tag 3.4 "Grade hardened-pod.yaml against the Pod Security Standards"
  local seccomp caps
  seccomp="$(grep -c 'seccompProfile' "${HERE}/hardened-pod.yaml")"
  caps="$(grep -cE 'capabilities|drop:' "${HERE}/hardened-pod.yaml")"
  echo "    'seccompProfile' lines in the manifest : ${seccomp}   (restricted requires RuntimeDefault or Localhost)"
  echo "    'capabilities'   lines in the manifest : ${caps}   (restricted requires a drop list containing ALL)"
  expect_eq "hardened-pod.yaml sets no seccompProfile (so it CANNOT be restricted)" "0" "$seccomp" \
    "hardened-pod.yaml now mentions seccompProfile. Re-grade it against restricted before narrating -- this script's BASELINE finding may be stale."
  expect_eq "hardened-pod.yaml drops no capabilities (so it CANNOT be restricted)" "0" "$caps" \
    "hardened-pod.yaml now mentions capabilities. Re-grade it against restricted before narrating -- this script's BASELINE finding may be stale."
  # Cross-check the LIVE object when there is one, so a Pod that somehow
  # acquired a seccomp profile from elsewhere cannot slip past a file grep.
  if kubectl get pod "$HARDENED" -n "$NS" >/dev/null 2>&1; then
    expect_eq "live Pod also carries no seccompProfile.type" "" \
      "$(jp pod "$HARDENED" "$NS" '{.spec.securityContext.seccompProfile.type}{.spec.containers[0].securityContext.seccompProfile.type}')" \
      "The live hardened Pod has a seccompProfile the manifest does not. Find out what set it before claiming a profile level."
  fi

  ensure "create scratch namespace $PSS_NS" kubectl create namespace "$PSS_NS"
  # Prove BASELINE admits it. --dry-run=server runs the full admission chain,
  # PodSecurity included, and persists nothing -- so this grades the manifest
  # against a real API server without leaving a Pod behind.
  expect_allow "label $PSS_NS enforce=baseline" \
    kubectl label namespace "$PSS_NS" pod-security.kubernetes.io/enforce=baseline --overwrite
  expect_allow "server-dry-run the hardened Pod under enforce=BASELINE -- admitted" bash -c "
    sed 's/namespace: ${NS}/namespace: ${PSS_NS}/' '${HERE}/hardened-pod.yaml' \
      | kubectl apply --dry-run=server -f -"
  # Now prove RESTRICTED refuses it, and that PSA names the two missing fields.
  expect_allow "re-label $PSS_NS enforce=restricted" \
    kubectl label namespace "$PSS_NS" pod-security.kubernetes.io/enforce=restricted --overwrite
  expect_deny "server-dry-run the same Pod under enforce=RESTRICTED -- REFUSED" \
    'violates PodSecurity.*restricted' bash -c "
    sed 's/namespace: ${NS}/namespace: ${PSS_NS}/' '${HERE}/hardened-pod.yaml' \
      | kubectl apply --dry-run=server -f -"
  local rout
  rout="$(sed "s/namespace: ${NS}/namespace: ${PSS_NS}/" "${HERE}/hardened-pod.yaml" \
          | kubectl apply --dry-run=server -f - 2>&1)"
  if grep -qi 'seccompProfile' <<<"$rout"; then
    ok "restricted's refusal names seccompProfile -- one of the two fields this manifest omits"
  else
    fail "restricted refused, but did not name seccompProfile" \
         "The restricted refusal did not mention seccompProfile. Re-read the message yourself before scripting narration around it."
  fi
  if grep -qiE 'capabilities.*drop|unrestricted capabilities' <<<"$rout"; then
    ok "restricted's refusal names capabilities.drop=[\"ALL\"] -- the other field this manifest omits"
  else
    fail "restricted refused, but did not name capabilities.drop" \
         "The restricted refusal did not mention capabilities. Re-read the message yourself before scripting narration around it."
  fi

  echo
  echo "${Y}=====================================================================${R}"
  echo "${Y}  WARNING -- NARRATION GUARD, READ THIS BEFORE YOU ROLL BEAT 3${R}"
  echo "${Y}=====================================================================${R}"
  echo "  hardened-pod.yaml satisfies ${G}BASELINE${R}. It does ${Y}NOT${R} satisfy RESTRICTED."
  echo "  Verified against a live API server just now: enforce=baseline admits it,"
  echo "  enforce=restricted refuses it and names seccompProfile and capabilities."
  echo
  echo "  Do NOT say \"this Pod is restricted\" or \"this meets the restricted"
  echo "  profile\". Say: \"this is a hardened Pod that clears BASELINE. To reach"
  echo "  restricted you would also set seccompProfile: RuntimeDefault and drop"
  echo "  ALL capabilities.\" That sentence is true, and it teaches the delta"
  echo "  instead of glossing over it."
  echo "${Y}=====================================================================${R}"
  echo

  # =================================================================
  # Beat 4 -- trace a Pod Security Admission refusal.
  # =================================================================
  tag 4.0 "Confirm the context"
  kubectl config current-context

  tag 4.1 "Turn PSA on for $NS: enforce rejects, warn tells you now"
  expect_allow "label namespace $NS enforce=baseline and warn=baseline" \
    kubectl label namespace "$NS" \
      pod-security.kubernetes.io/enforce=baseline \
      pod-security.kubernetes.io/warn=baseline --overwrite
  expect_eq "live enforce label on $NS" "baseline" \
    "$(kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)" \
    "The enforce label is not on $NS, so nothing will be refused and Beat 4 has no lesson."

  # ASSERTION 6a -- name the offending field, from the manifest itself.
  # PROTECTS: "one field. privileged: true. That is the entire violation."
  tag 4.2 "The field that violates baseline, named from the manifest"
  if grep -qE '^\s*privileged:\s*true\s*$' "${HERE}/privileged-deployment.yaml"; then
    ok "privileged-deployment.yaml sets spec.template.spec.containers[0].securityContext.privileged=true"
    echo "${B}    $(grep -nE 'privileged:' "${HERE}/privileged-deployment.yaml")${R}"
  else
    fail "privileged-deployment.yaml does not set privileged: true" \
         "The manifest no longer sets privileged: true, so baseline has nothing to refuse. Restore the manifest."
  fi

  tag 4.3 "Apply it. The Deployment is created -- enforce does not apply to workload resources"
  # PSA's enforce mode is "not applied to workload resources, only to the
  # resulting pod objects"; warn mode IS applied to workload resources, which
  # is why the apply prints a Warning and still succeeds.
  # https://v1-35.docs.kubernetes.io/docs/concepts/security/pod-security-admission/
  expect_allow "apply privileged-deployment.yaml (succeeds, with a warning)" \
    kubectl apply -f "${HERE}/privileged-deployment.yaml"

  # ASSERTION 6b -- Deployment and ReplicaSet exist, zero Pods do.
  tag 4.4 "Deployment yes, ReplicaSet yes, Pods zero"
  legacy_rs_exists() { [[ -n "$(kubectl get rs -n "$NS" -l app="$LEGACY" -o name 2>/dev/null)" ]]; }
  poll 30 legacy_rs_exists
  expect_eq "the Deployment exists" "deployment.apps/$LEGACY" \
    "$(kubectl get deployment "$LEGACY" -n "$NS" -o name 2>/dev/null)" \
    "The legacy-agent Deployment is missing. Re-apply privileged-deployment.yaml."
  if legacy_rs_exists; then
    ok "the ReplicaSet exists: $(kubectl get rs -n "$NS" -l app="$LEGACY" -o name 2>/dev/null | head -1)"
  else
    fail "no ReplicaSet for $LEGACY" \
         "No ReplicaSet was created for legacy-agent. The deployment controller may be down: kubectl -n kube-system get pods | grep controller-manager"
  fi
  expect_eq "Pods for $LEGACY" "0" \
    "$(kubectl get pods -n "$NS" -l app="$LEGACY" --no-headers 2>/dev/null | wc -l | tr -d ' ')" \
    "A privileged Pod EXISTS in $NS. PSA is not enforcing -- check the enforce label spelling on the namespace."

  # ASSERTION 6c -- the refusal names Pod Security, NOT the quota.
  # PROTECTS: "the guardrail that said no was PodSecurity, and you can tell
  # because the message says so."
  #
  # WHY this is safe to assert even with a quota in the namespace: in
  # AllOrderedPlugins, PodSecurity is #12 and ResourceQuota is #38, with the
  # source's own comment that "webhook, resourcequota, and deny plugins must
  # go at the end". PodSecurity therefore refuses first and the quota never
  # gets a vote. If a future release reorders that, THIS assertion is what
  # tells us before the microphone does.
  # https://v1-35.docs.kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#podsecurity
  tag 4.5 "The ReplicaSet event names the POD SECURITY violation, not the quota"
  local ltext=""
  legacy_says_pss() {
    ltext="$(kubectl get rs -n "$NS" -l app="$LEGACY" -o jsonpath='{range .items[*]}{.status.conditions[*].message}{end}' 2>/dev/null)
$(kubectl describe rs -n "$NS" -l app="$LEGACY" 2>/dev/null | tail -30)
$(kubectl get events -n "$NS" --field-selector reason=FailedCreate -o custom-columns=MSG:.message --no-headers 2>/dev/null)"
    grep -qiE 'violates PodSecurity|privileged \(container' <<<"$ltext"
  }
  if poll 90 legacy_says_pss; then
    ok "the refusal names the Pod Security Standard violation"
    echo "${B}    $(grep -io 'violates PodSecurity.*' <<<"$ltext" | head -1 | cut -c1-160)${R}"
  else
    fail "nothing on the $LEGACY ReplicaSet names a PodSecurity violation" \
         "The legacy-agent refusal does not mention PodSecurity. Confirm the enforce=baseline label landed, then re-verify."
  fi
  # The other half, and the one that actually protects the sentence: the
  # message must NOT be a quota error. If the quota answered first, Tim's
  # "PodSecurity said no" is wrong even though zero Pods exist either way --
  # the screen would show the same emptiness for the wrong reason.
  if grep -qi 'exceeded quota' <<<"$ltext"; then
    fail "the $LEGACY refusal mentions 'exceeded quota' -- the QUOTA answered, not PodSecurity" \
         "legacy-agent was refused by the QUOTA, not by PodSecurity. Free the budget (./lab.sh reset) or Beat 4's whole explanation is wrong on camera."
  else
    ok "no 'exceeded quota' in the $LEGACY refusal -- PodSecurity got there first, exactly as plugin ordering predicts"
  fi

  tag 4.6 "The last rung of the ladder: a Pod that EXISTS but will not start is the kubelet, not admission"
  expect_allow "describe $POD (still Running -- this is the contrast case)" \
    bash -c "kubectl describe pod '$POD' -n '$NS' | tail -5"

  # =================================================================
  echo; echo "${G}=== verdict ===${R}"
  echo "Final context: $(kubectl config current-context)"
  if [[ $FAILURES -eq 0 ]]; then
    ok "Every expected ALLOW succeeded, every expected DENY failed for the RIGHT reason,"
    ok "and every number in the narration matches the live cluster."
    echo
    echo "  Remember on camera:"
    echo "    * hardened-pod.yaml is BASELINE, not restricted."
    echo "    * delete the $FILLER Deployment before you apply hardened-pod.yaml."
    echo
    echo "${G}================================================${R}"
    echo "${G}  READY FOR TAKE${R}"
    echo "${G}================================================${R}"
    echo "  context : $(kubectl config current-context 2>/dev/null)"
    echo "  Run  ./lab.sh reset  (about 20s), then roll."
    echo "  Demo 1 opens with:  kubectl create namespace production"
    echo
    return 0
  fi

  err "$FAILURES check(s) drifted from the runbook. Do NOT roll."
  echo
  # Guarded: under `set -u` an empty array expansion is fatal on bash 4.3, and
  # a fail() called without a hint would leave FIXES empty. The verdict must
  # never die while printing the verdict.
  if (( ${#FIXES[@]} > 0 )); then
    echo "${Y}Fix these, in this order:${R}"
    local i=1 f
    for f in "${FIXES[@]}"; do
      echo "   $i. $f"
      i=$((i + 1))
    done
  else
    echo "${Y}Fix: re-read the [FAIL] lines above, in order.${R}"
  fi
  echo
  echo "  When in doubt the first move is always:  ./lab.sh reset   then  ./lab.sh verify"
  return 1
}

# ---------------------------------------------------------------------
SUB="${1:-all}"

# SELF-LOGGING. `./lab.sh | tee log` looks harmless and is not: in a pipeline
# $? is TEE's status, so a run that failed a check and exited 1 would report
# success. Process substitution keeps both streams flowing to both places
# while the exit code and the EXIT trap stay in this shell.
TEE_PID=""
case "$SUB" in
  verify|all)
    LOG="${HOME}/dry-run-m03.txt"
    exec > >(tee "$LOG"); TEE_PID=$!
    exec 2>&1
    info "Transcript: $LOG"
    ;;
esac

case "$SUB" in
  reset)  do_reset ;;
  verify) do_verify ;;
  all)    do_reset && do_verify ;;
  *)      echo "usage: ./lab.sh [reset|verify]   (no arg = reset + verify)"
          echo "       reset   frame zero: deletes production, $TRAP_NS, $PSS_NS and WAITS"
          echo "       verify  walk all four beats, exit 0 or 1"
          echo "       (bare)  reset then verify -- the one you want"
          echo "       (there is no 'jwt' verb in M03 -- that was Module 2)"
          exit 2 ;;
esac
RC=$?

# Close our end of the pipe and WAIT for tee to drain rather than sleeping and
# hoping. A fixed sleep is a race that can drop exactly the verdict line you
# needed to read.
if [[ -n "$TEE_PID" ]]; then
  exec 1>&- 2>&-
  wait "$TEE_PID" 2>/dev/null
fi
exit "$RC"
