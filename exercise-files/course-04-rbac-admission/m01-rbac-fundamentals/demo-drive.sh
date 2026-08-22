#!/usr/bin/env bash
# =====================================================================
#  demo-drive.sh -- a presenter engine for recorded terminal demos
#  Tim Warner / ps-cka -- CKA v1.35 Skill Path
# =====================================================================
#
#  WHAT THIS IS
#  ------------
#  A teleprompter for your hands. You share ONE terminal, press ENTER,
#  and read. The command types itself, waits for you, then runs for
#  real against the real cluster. Your talk track never appears on the
#  shared screen -- it goes to a SECOND terminal only you can see.
#
#  WHY NOT demo-magic
#  ------------------
#  demo-magic is good and this borrows its `pe` idea outright. Three
#  things it does not do that this course needs:
#
#    1. Talk track. demo-magic has no notion of narration, so your SAY
#       lines live in a different file than your commands and the two
#       drift. Here they are the same file, and `beat` routes them to a
#       private tty.
#    2. Expected failures. Half these demos exist to produce a 403 or a
#       Forbidden. This engine never aborts on a non-zero exit and
#       never needs `|| true`, so nothing camera-ugly gets typed.
#    3. Zero dependencies. No clone, no pv, no network on the node
#       during a take. One file you vendor and pin.
#
#  THE TWO-TERMINAL SETUP (this is the whole trick)
#  ------------------------------------------------
#  Terminal A -- SHARED / RECORDED. Runs the demo.
#  Terminal B -- PRIVATE, monitor 2. Shows your talk track only.
#
#  In terminal B (a second SSH session to the same node):
#
#      tty                      # prints e.g. /dev/pts/2 -- note it
#      clear
#
#  In terminal A:
#
#      PROMPTER_TTY=/dev/pts/2 ./m01.demo.sh
#
#  Now every `beat` line prints to terminal B, and terminal A shows
#  nothing but a prompt, a command, and real output. If you omit
#  PROMPTER_TTY the talk track is silently suppressed -- so a take can
#  never leak your notes onto the recording by accident. That default
#  is deliberate: the failure mode has to be "I lost my notes," never
#  "my notes went out to a million learners."
#
#  KEYS, DURING A TAKE
#  -------------------
#    ENTER        run the command that is sitting on screen
#    !  + ENTER   drop to an interactive subshell (improvise, then
#                 `exit` to return to the script, same beat)
#    s  + ENTER   skip this command without running it
#    q  + ENTER   quit the demo cleanly
#    Ctrl+C       interrupt a long-running command, stay in the demo
#
#  ENVIRONMENT
#  -----------
#    PROMPTER_TTY   tty of your private terminal. Unset = notes hidden.
#    TYPE_SPEED     characters per second. Default 55, tuned for
#                   recorded content. demo-magic's 20 is a live-room
#                   speed and will cost you real runtime -- M03 is
#                   already at 19.9 min against a 25 min budget.
#    DEMO_PROMPT    prompt string. Default mimics the real node prompt
#                   so the recording does not look staged.
#    NO_TYPE=1      paste instantly instead of animating. Use this when
#                   you are over budget or doing pickup shots.
#    CACHE_MODE     off (default) | record | replay
#    DEMO_CACHE     cache root, default ~/.cka-demo-cache
#
#  THE TWO-PASS RECORDING WORKFLOW
#  -------------------------------
#  Pass 1, off camera, proves the module is green AND captures real output:
#
#      ./lab.sh                                  # reset + verify, expect exit 0
#      CACHE_MODE=record ./m01.demo.sh           # walk it once for real
#
#  Pass 2, on camera, cannot fail:
#
#      ./lab.sh reset
#      CACHE_MODE=replay PROMPTER_TTY=/dev/pts/N ./m01.demo.sh
#
#  In replay NOTHING executes -- each command prints the output pass 1
#  captured off the live cluster. Retakes are byte-identical, a flaky
#  node cannot ruin a take, and the output is still genuine because it
#  came off your real cluster minutes earlier. If a command has no cache
#  entry, replay runs it live rather than showing a blank screen, and
#  tells you on the private terminal so you can re-record the cache.
#
# =====================================================================
#  DELIBERATELY NO `set -e`. These demos are supposed to fail on
#  camera: the 403 in M01 Demo 1, ghost-sa in M02 Beat 4, the oversized
#  Pod and the privileged Deployment in M03. A driver that aborts on a
#  non-zero exit would end the take at exactly the teaching moment.
# =====================================================================

set -uo pipefail   # -u and pipefail are safe here. -e is NOT. See above.

# ---------------------------------------------------------------------
# Configuration with sane, override-able defaults
# ---------------------------------------------------------------------
TYPE_SPEED="${TYPE_SPEED:-55}"
# Content-addressed output cache. Three modes:
#   off     always execute live (default)
#   record  execute live AND save each command's output, keyed by its text
#   replay  print the saved output, execute NOTHING
# The point of replay: do one real run to prove the module is green, then
# record the take against captured output so no command can fail on camera.
# The output is still real -- it came off the real cluster minutes earlier.
CACHE_MODE="${CACHE_MODE:-off}"
DEMO_CACHE="${DEMO_CACHE:-${HOME}/.cka-demo-cache}"
NO_TYPE="${NO_TYPE:-0}"
PROMPTER_TTY="${PROMPTER_TTY:-}"
DEMO_PROMPT="${DEMO_PROMPT:-\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ }"

# Validate TYPE_SPEED early rather than dividing by a word later.
if ! [[ "${TYPE_SPEED}" =~ ^[0-9]+$ ]] || [ "${TYPE_SPEED}" -lt 1 ]; then
    printf 'demo-drive: TYPE_SPEED must be a positive integer (got "%s")\n' \
        "${TYPE_SPEED}" >&2
    exit 2
fi

# Per-character delay. bash has no floats, so compute in awk once and
# reuse -- calling awk per character would dominate the typing time.
CHAR_DELAY="$(awk -v s="${TYPE_SPEED}" 'BEGIN { printf "%.4f", 1.0 / s }')"

case "${CACHE_MODE}" in
    off|record|replay) : ;;
    *) printf 'demo-drive: CACHE_MODE must be off, record or replay (got "%s")\n' \
           "${CACHE_MODE}" >&2; exit 2 ;;
esac

# Cache is namespaced per demo script, so m01 and m03 never collide.
_DD_CACHE_DIR="${DEMO_CACHE}/$(basename "${0%.sh}")"
if [ "${CACHE_MODE}" != "off" ]; then
    mkdir -p "${_DD_CACHE_DIR}" 2>/dev/null || {
        printf 'demo-drive: cannot create cache dir %s -- falling back to live\n' \
            "${_DD_CACHE_DIR}" >&2
        CACHE_MODE=off
    }
fi
_DD_CACHE_HITS=0
_DD_CACHE_MISSES=0
_DD_CACHE_WRITES=0

# ---------------------------------------------------------------------
# Colours. Cyan and yellow only -- NO red/green pairs anywhere, and
# every state also carries a word or a symbol. Never encode meaning in
# hue alone.
# ---------------------------------------------------------------------
if [ -t 1 ]; then
    C_DIM=$'\e[2m'; C_CYAN=$'\e[36m'; C_YELLOW=$'\e[33m'
    C_BOLD=$'\e[1m'; C_OFF=$'\e[0m'
else
    C_DIM=''; C_CYAN=''; C_YELLOW=''; C_BOLD=''; C_OFF=''
fi

# ---------------------------------------------------------------------
# State
# ---------------------------------------------------------------------
_DD_BEAT=''          # current beat id, e.g. "1.4"
_DD_CMD_COUNT=0
_DD_START_EPOCH="$(date +%s)"
_DD_QUIT=0

# =====================================================================
# note -- write to the private prompter tty, or nowhere at all.
#
# Everything narration-related funnels through here, which is why a
# missing PROMPTER_TTY can only ever cost you notes, never leak them.
# =====================================================================
note() {
    [ -n "${PROMPTER_TTY}" ] || return 0
    [ -w "${PROMPTER_TTY}" ] || return 0
    printf '%b\n' "$*" >> "${PROMPTER_TTY}" 2>/dev/null || true
}

# =====================================================================
# beat -- announce a beat and put its talk track on the prompter.
#
#   beat <id> <headline> [say-line ...]
#
# The id is echoed into the SHARED terminal as a plain shell comment,
# because a numbered comment reads as deliberate structure on camera
# and gives you an anchor when you edit. The headline and say-lines go
# to the PRIVATE terminal only.
# =====================================================================
beat() {
    [ "${_DD_QUIT}" = "1" ] && return 0
    local id="${1:?beat: need an id}"; shift
    local headline="${1:-}"; shift || true

    _DD_BEAT="${id}"

    # Shared terminal: just the tag. Looks like a comment, is a comment.
    printf '\n%s# [%s]%s\n' "${C_DIM}" "${id}" "${C_OFF}"

    # Private terminal: the whole card.
    note ""
    note "${C_BOLD}${C_CYAN}────────────────────────────────────────────────────────${C_OFF}"
    note "${C_BOLD}${C_CYAN}  [${id}]  ${headline}${C_OFF}"
    note "${C_BOLD}${C_CYAN}────────────────────────────────────────────────────────${C_OFF}"
    local line
    for line in "$@"; do
        note ""
        note "  ${line}"
    done
    note ""
}

# =====================================================================
# say -- add narration to the current beat without starting a new one.
# Use for the "then, after it returns --" half of a two-part line.
# =====================================================================
say() {
    note ""
    note "  ${C_YELLOW}▸${C_OFF} $*"
}

# =====================================================================
# expect -- what the output should look like. Prompter only.
# Read this BEFORE you press ENTER so a wrong result cannot surprise
# you on camera.
# =====================================================================
expect() {
    note ""
    note "  ${C_DIM}EXPECT:${C_OFF} $*"
}

# =====================================================================
# recover -- the if-it-breaks line for this beat. Prompter only.
# =====================================================================
recover() {
    note ""
    note "  ${C_DIM}IF IT BREAKS:${C_OFF} $*"
}

# =====================================================================
# render_prompt -- expand DEMO_PROMPT the way bash would for PS1.
#
# Done once per command rather than once per run because \w changes if
# a demo cd's somewhere. Escapes handled: \u \h \H \w \W \$ and the
# \[ \] non-printing markers, which we simply strip.
# =====================================================================
render_prompt() {
    local p="${DEMO_PROMPT}"
    p="${p//\\u/${USER:-$(id -un)}}"
    p="${p//\\H/$(hostname -f 2>/dev/null || hostname)}"
    p="${p//\\h/$(hostname -s 2>/dev/null || hostname)}"
    p="${p//\\W/${PWD##*/}}"
    p="${p//\\w/${PWD/#$HOME/\~}}"
    p="${p//\\\$/\$}"
    p="${p//\\[/}"
    p="${p//\\]/}"
    printf '%b' "${p}"
}

# =====================================================================
# type_out -- render a command character by character.
#
# A single bash loop with one sleep per char. No pv, no external typing
# tool. NO_TYPE=1 short-circuits to an instant paste for pickup shots.
# =====================================================================
type_out() {
    local text="$1"
    if [ "${NO_TYPE}" = "1" ]; then
        printf '%s' "${text}"
        return 0
    fi
    local i char
    for (( i = 0; i < ${#text}; i++ )); do
        char="${text:i:1}"
        printf '%s' "${char}"
        sleep "${CHAR_DELAY}"
    done
}

# =====================================================================
# _DD_TTY -- where keypresses come from.
#
# /dev/tty when there is a terminal, which is the correct source for an
# interactive presenter and survives the demo script being piped in.
# Falls back to stdin so the whole engine stays testable in CI, where
# there is no controlling terminal at all.
# =====================================================================
if ( : < /dev/tty ) 2>/dev/null; then
    _DD_TTY=/dev/tty
else
    # No controlling terminal (CI, a piped harness, some cron contexts).
    # Fall back to stdin so the engine stays exercisable off-camera.
    _DD_TTY=/dev/stdin
fi

# =====================================================================
# _await -- wait for a keypress-plus-ENTER and interpret it.
#
# Returns: 0 run it, 1 skip it, 2 quit, 3 caller should re-offer the
# same command (used after an interactive escape).
# =====================================================================
_await() {
    local key=''
    IFS= read -r -s key < "${_DD_TTY}" || { _DD_QUIT=1; return 2; }
    case "${key}" in
        '!')
            note ""
            note "  ${C_YELLOW}▸ interactive escape -- \`exit\` returns to the script${C_OFF}"
            printf '\n%s-- interactive --%s\n' "${C_DIM}" "${C_OFF}"
            # A real subshell so he can improvise. Context changes made
            # here DO persist for kubectl (kubeconfig is on disk), but
            # shell variables set here do not -- worth knowing if you
            # improvise a TOKEN=.
            "${SHELL:-/bin/bash}" -i < "${_DD_TTY}" || true
            printf '%s-- back in the demo --%s\n' "${C_DIM}" "${C_OFF}"
            return 3
            ;;
        's'|'S'|'skip')  return 1 ;;
        'q'|'Q'|'quit')  _DD_QUIT=1; return 2 ;;
        *)               return 0 ;;
    esac
}

# =====================================================================
# _cache_path -- content-addressed path for one command's output.
#
# Keyed on beat id + command text, so the same command appearing in two
# beats caches separately (they can legitimately produce different
# output -- [1.4] and [2.3] are literally the same command with a
# RoleBinding created in between, and that contrast IS the lesson).
# =====================================================================
_cache_path() {
    local key
    if command -v sha256sum >/dev/null 2>&1; then
        key="$(printf '%s\n%s' "${_DD_BEAT}" "$1" | sha256sum | cut -c1-16)"
    else
        key="$(printf '%s\n%s' "${_DD_BEAT}" "$1" | cksum | tr -d ' ' | cut -c1-16)"
    fi
    printf '%s/%s-%s.out' "${_DD_CACHE_DIR}" "${_DD_BEAT:-none}" "${key}"
}

# =====================================================================
# pe -- print and execute. The workhorse.
#
#   pe 'kubectl get pods -n dev-team'
#
# Flow, and it is exactly two ENTERs so the rhythm never varies:
#
#   1. prompt appears, command types itself
#   2. >>> YOU READ YOUR SETUP LINE <<<  then ENTER
#   3. the real command runs against the real cluster
#   4. >>> YOU READ YOUR PAYOFF LINE <<<  then ENTER
#   5. next beat
#
# Step 4's pause is what makes this different from a script that
# scrolls output past you. The output sits on screen while you talk
# about it, then you decide when to move.
#
# Non-zero exits are reported to the PROMPTER only, never to the shared
# terminal, and never abort the run.
# =====================================================================
pe() {
    [ "${_DD_QUIT}" = "1" ] && return 0
    local cmd="$1"
    local rc=0
    local verdict

    while :; do
        # -- 1. prompt + typed command -----------------------------------
        printf '%s' "$(render_prompt)"
        type_out "${cmd}"

        # -- 2. hold for narration ---------------------------------------
        _await; verdict=$?
        case "${verdict}" in
            1) printf '\n   %s# skipped%s\n' "${C_DIM}" "${C_OFF}"
               note "  ${C_DIM}(skipped)${C_OFF}"
               return 0 ;;
            2) printf '\n%s# demo ended%s\n' "${C_DIM}" "${C_OFF}"
               return 0 ;;
            3) continue ;;   # came back from a subshell -- re-offer
        esac

        break
    done

    # `read -s` ate the echoed newline, so supply exactly one. Doing it here
    # rather than relying on terminal echo means the transcript looks the
    # same whether a human or a test harness drove it.
    printf '\n'

    # -- 3. run it, or replay it ----------------------------------------
    # eval stays in the CURRENT shell, on purpose: `kubectl config
    # use-context`, `TOKEN=$(kubectl create token ...)`, and `cd` all have
    # to persist into later beats. A subshell would silently break them.
    # Note that a plain redirection does NOT create a subshell, which is
    # why record mode can capture output without breaking that.
    local cf; cf="$(_cache_path "${cmd}")"

    if [ "${CACHE_MODE}" = "replay" ] && [ -s "${cf}" ]; then
        # Print the captured output verbatim. Nothing executes.
        cat "${cf}"
        rc="$(head -1 "${cf}.rc" 2>/dev/null || echo 0)"
        _DD_CACHE_HITS=$(( _DD_CACHE_HITS + 1 ))
        note "  ${C_DIM}(replayed from cache)${C_OFF}"
    elif [ "${CACHE_MODE}" = "record" ]; then
        eval "${cmd}" > "${cf}.tmp" 2>&1
        rc=$?
        cat "${cf}.tmp"
        mv "${cf}.tmp" "${cf}"
        printf '%s\n' "${rc}" > "${cf}.rc"
        _DD_CACHE_WRITES=$(( _DD_CACHE_WRITES + 1 ))
        note "  ${C_DIM}(recorded to cache, exit ${rc})${C_OFF}"
    else
        if [ "${CACHE_MODE}" = "replay" ]; then
            # Cache miss during a take. Run live rather than show a blank
            # screen, and tell the presenter on the private terminal only.
            _DD_CACHE_MISSES=$(( _DD_CACHE_MISSES + 1 ))
            note "  ${C_YELLOW}▸ CACHE MISS -- ran live instead. Re-record the cache.${C_OFF}"
        fi
        eval "${cmd}"
        rc=$?
    fi
    _DD_CMD_COUNT=$(( _DD_CMD_COUNT + 1 ))

    if [ "${rc}" -ne 0 ]; then
        # Expected, most of the time. Tell the presenter, not the camera.
        note "  ${C_DIM}(exit ${rc} -- expected on the refusal beats)${C_OFF}"
    fi

    # -- 4. hold on the output ------------------------------------------
    _await >/dev/null 2>&1 || true
    [ "${_DD_QUIT}" = "1" ] && return 0

    return 0
}

# =====================================================================
# pq -- print and execute QUIETLY: run it, show nothing.
#
# For the plumbing a viewer should never see -- staging a variable,
# a `sleep 5`, resolving a directory. Keeps `M3_DIR="$(cd ...)"` and
# `|| true` off the recording, which is the single biggest reason a
# raw commands.sh should not be driven straight onto camera.
# =====================================================================
pq() {
    [ "${_DD_QUIT}" = "1" ] && return 0
    local cmd="$1"
    note "  ${C_DIM}(silent: ${cmd})${C_OFF}"
    eval "${cmd}" >/dev/null 2>&1 || true
}

# =====================================================================
# pause_point -- end of a clip. Stop recording here.
# =====================================================================
pause_point() {
    [ "${_DD_QUIT}" = "1" ] && return 0
    local label="${1:-}"
    printf '\n%s%s# ---- pause point ----%s\n' "${C_BOLD}" "${C_CYAN}" "${C_OFF}"
    note ""
    note "${C_BOLD}${C_YELLOW}  ■ PAUSE POINT -- STOP THE CLIP.  ${label}${C_OFF}"
    note "  ${C_DIM}ENTER to continue when you are rolling again.${C_OFF}"
    _await >/dev/null 2>&1 || true
}

# =====================================================================
# demo_header / demo_footer -- bookends, prompter only.
# =====================================================================
demo_header() {
    local title="$1"
    note ""
    note "${C_BOLD}${C_CYAN}══════════════════════════════════════════════════════════${C_OFF}"
    note "${C_BOLD}${C_CYAN}  ${title}${C_OFF}"
    note "${C_BOLD}${C_CYAN}══════════════════════════════════════════════════════════${C_OFF}"
    note ""
    if [ -z "${PROMPTER_TTY}" ]; then
        printf '%s# talk track hidden (PROMPTER_TTY unset)%s\n' \
            "${C_DIM}" "${C_OFF}" >&2
    fi
    note "  ${C_DIM}ENTER = advance   !  = improvise   s = skip   q = quit${C_OFF}"
    case "${CACHE_MODE}" in
        record) note "  ${C_YELLOW}▸ CACHE: record -- running live and capturing every output.${C_OFF}" ;;
        replay) note "  ${C_YELLOW}▸ CACHE: replay -- printing captured output, executing nothing.${C_OFF}" ;;
        off)    note "  ${C_DIM}CACHE: off -- every command runs live.${C_OFF}" ;;
    esac
    note ""
}

demo_footer() {
    local elapsed=$(( $(date +%s) - _DD_START_EPOCH ))
    note ""
    note "${C_BOLD}${C_CYAN}  ✔ demo complete -- ${_DD_CMD_COUNT} commands, $(( elapsed / 60 ))m $(( elapsed % 60 ))s wall clock${C_OFF}"
    if [ "${CACHE_MODE}" != "off" ]; then
        note "  ${C_DIM}cache: ${_DD_CACHE_HITS} replayed, ${_DD_CACHE_WRITES} recorded, ${_DD_CACHE_MISSES} missed${C_OFF}"
        [ "${_DD_CACHE_MISSES}" -gt 0 ] && \
            note "  ${C_YELLOW}▸ ${_DD_CACHE_MISSES} command(s) had no cache entry. Re-run in record mode.${C_OFF}"
    fi
    note "  ${C_DIM}Wall clock includes your narration, so treat it as an${C_OFF}"
    note "  ${C_DIM}upper bound on clip length, not the finished runtime.${C_OFF}"
    note ""
}

# =====================================================================
# Self-check: sourced, not executed?
# =====================================================================
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    cat <<'USAGE'
demo-drive.sh is a library. Source it from a demo script:

    #!/usr/bin/env bash
    source "$(dirname "$0")/demo-drive.sh"

    demo_header "CKA C04 M01 -- RBAC Fundamentals"

    beat "1.0" "Look before you touch" \
        "Every demo in this course opens exactly like this..."
    expect "Two rows, star on cka-vagrant"
    pe 'kubectl config get-contexts'

    pause_point "You have a user who can prove who they are and do nothing."
    demo_footer

Then, in a PRIVATE second terminal:   tty     (note the /dev/pts/N)
And in the SHARED terminal:           PROMPTER_TTY=/dev/pts/N ./m01.demo.sh
USAGE
    exit 0
fi
