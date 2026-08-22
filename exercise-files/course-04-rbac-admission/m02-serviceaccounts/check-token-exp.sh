#!/usr/bin/env bash
# =====================================================================
#  check-token-exp.sh -- settle the M02 token-lifetime claim, correctly.
#
#  WHY THIS EXISTS
#  ---------------
#  Initialize-C04M02Lab.ps1's eighth gate fails with LIFETIME_DAYS=0.
#  That gate mints a token with `kubectl create token` and expects the
#  ~1 year extension. It will never pass, because the extension does not
#  apply to that kind of token:
#
#    --service-account-extend-token-expiration (default true) "enables
#     PROJECTED service account expiration extension during token
#     generation ... extending ADMISSION-INJECTED tokens up to one year"
#     -- kube-apiserver command-line reference
#
#  So there are TWO different tokens and they have two different answers:
#
#    A. MINTED   `kubectl create token sa`      -> ~1 hour  (no extension)
#    B. INJECTED the Pod's projected volume     -> ~1 year  (extended,
#                                                  plus a warnafter claim)
#
#  The deck's on-camera claim is about B. The gate tested A. This script
#  tests BOTH and prints them side by side, so you know which sentence
#  you can safely say.
#
#  RUN:  on control1, from ~/m02, after Demo 2's Pod exists -- or let it
#        create its own throwaway Pod with -p.
#
#        ./check-token-exp.sh            # use deploy-runner if present
#        ./check-token-exp.sh -p         # create a probe Pod, then clean up
# =====================================================================
set -uo pipefail   # NOT -e: a missing Pod is a reportable condition, not a crash

NS="${NS:-staging}"
POD="${POD:-deploy-runner}"
PROBE=0
[ "${1:-}" = "-p" ] && PROBE=1

# --- decode a JWT payload with coreutils only (no jq on this box) -----
payload() {
    local p; p="$(printf '%s' "$1" | cut -d. -f2 | tr '_-' '/+')"
    case $(( ${#p} % 4 )) in 2) p="${p}==" ;; 3) p="${p}=" ;; esac
    printf '%s' "$p" | base64 -d 2>/dev/null
}
claim() { echo "$1" | grep -o "\"$2\":[0-9]*" | head -1 | cut -d: -f2; }

report() {  # report <label> <jwt>
    local label="$1" jwt="$2" pay exp iat warn secs days
    pay="$(payload "$jwt")"
    exp="$(claim "$pay" exp)"; iat="$(claim "$pay" iat)"
    warn="$(echo "$pay" | grep -o '"warnafter":[0-9]*' | head -1 | cut -d: -f2)"
    if [ -z "${exp:-}" ] || [ -z "${iat:-}" ]; then
        echo "  [FAIL] $label -- could not read exp/iat from the token"
        return 1
    fi
    secs=$(( exp - iat )); days=$(( secs / 86400 ))
    printf '  %-34s lifetime = %8s sec  (%s days)\n' "$label" "$secs" "$days"
    if [ -n "${warn:-}" ]; then
        printf '  %-34s warnafter is %s sec after iat\n' "" "$(( warn - iat ))"
    else
        printf '  %-34s no warnafter claim\n' ""
    fi
    echo "$secs"
}

echo "================================================================"
echo "  M02 token lifetime -- minted vs injected"
echo "================================================================"

# --- A. MINTED -------------------------------------------------------
echo
echo "A. MINTED with kubectl create token (no --duration)"
kubectl create serviceaccount probe-sa -n "$NS" >/dev/null 2>&1
MINTED="$(kubectl create token probe-sa -n "$NS" 2>/dev/null)"
if [ -z "$MINTED" ]; then
    echo "  [FAIL] could not mint a token in namespace $NS"
    A_SECS=""
else
    A_SECS="$(report 'minted token' "$MINTED" | tail -1)"
    report 'minted token' "$MINTED" >/dev/null
fi

# --- B. INJECTED -----------------------------------------------------
echo
echo "B. INJECTED into a Pod by admission (this is the deck's claim)"
CLEANUP=0
if [ "$PROBE" = "1" ] || ! kubectl get pod "$POD" -n "$NS" >/dev/null 2>&1; then
    echo "  (no $POD in $NS -- creating a throwaway probe Pod)"
    POD=tokenprobe; CLEANUP=1
    kubectl run "$POD" -n "$NS" --image=nginx:1.27 \
        --overrides='{"spec":{"serviceAccountName":"probe-sa"}}' >/dev/null 2>&1
    kubectl wait --for=condition=Ready "pod/$POD" -n "$NS" --timeout=120s >/dev/null 2>&1 \
        || echo "  [WARN] probe Pod never went Ready -- check image pull"
fi
INJ="$(kubectl exec -n "$NS" "$POD" -- \
        cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)"
if [ -z "$INJ" ]; then
    echo "  [FAIL] could not read the projected token from $POD"
else
    report 'injected (projected) token' "$INJ" >/dev/null
    report 'injected (projected) token' "$INJ" | head -2
fi

# --- verdict ---------------------------------------------------------
echo
echo "----------------------------------------------------------------"
INJ_SECS=""
[ -n "$INJ" ] && INJ_SECS="$(( $(claim "$(payload "$INJ")" exp) - $(claim "$(payload "$INJ")" iat) ))"
if [ -n "$INJ_SECS" ] && [ "$INJ_SECS" -gt 25000000 ]; then
    echo "  [OK] The INJECTED token is extended past 289 days."
    echo "       The deck is right. Say it on camera."
elif [ -n "$INJ_SECS" ]; then
    echo "  [DRIFT] The injected token is only $(( INJ_SECS / 3600 )) hours."
    echo "          --service-account-extend-token-expiration may be false"
    echo "          on this API server. Re-ground slide 12 before the take."
fi
if [ -n "${A_SECS:-}" ] && [ "$A_SECS" -le 3700 ] 2>/dev/null; then
    echo "  [OK] The MINTED token is ~1 hour, which is correct and expected."
    echo "       Gate 8 asserting a year against THIS token is the bug."
fi
echo "----------------------------------------------------------------"

# --- tidy ------------------------------------------------------------
[ "$CLEANUP" = "1" ] && kubectl delete pod "$POD" -n "$NS" --now >/dev/null 2>&1
kubectl delete serviceaccount probe-sa -n "$NS" >/dev/null 2>&1
echo "Probe objects removed. Run ./lab.sh reset before your take."
