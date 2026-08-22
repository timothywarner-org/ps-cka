#!/usr/bin/env bash
# =====================================================================
#  m03.demo.sh -- presenter driver for
#  CKA Course 4 / Module 3 -- Admission Controls, Resource Limits,
#  and Governance
#
#  Tim Warner / ps-cka -- CKA v1.35 Skill Path
# =====================================================================
#
#  #####################################################################
#  ##  THE TALK TRACK IN THIS FILE IS INCOMPLETE. READ THIS FIRST.   ##
#  #####################################################################
#
#  Modules 1 and 2 each have a demo runbook with a verbatim talk track.
#  M03 DOES NOT. There is no c04-m03-demo-runbook.md, and none of the
#  six manifests the commands reference are in the exercise-files tree
#  either (see "MISSING ASSETS" below). So there was no narration to
#  carry over.
#
#  Every `say` line in this file is either
#    (a) Tim's own words, lifted from a comment in commands.sh and
#        trimmed to a spoken sentence, or
#    (b) the literal string
#          TODO TALK TRACK -- no runbook exists for M03. Write this beat.
#
#  Nothing here was ghost-written in Tim's voice. If a beat reads TODO,
#  that beat has no narration yet -- write it before you roll. Seven of
#  the twenty-three beats are TODO (1.0, 1.1, 2.0, 2.6, 3.0, 3.1, 4.0).
#  Four of the seven are the short `use-context` openers. Only [2.6]
#  has no source text anywhere -- the other six each have a reusable
#  deck-notes quote called out in the talk-track document.
#
#  ALL SIX MANIFESTS EXIST -- an earlier draft of this header said they
#  did not. That was wrong: they are present in
#  exercise-files/course-04-rbac-admission/m03-admission-controls/
#  (limitrange, limitrange-ceiling, oversized-pod, resourcequota,
#  privileged-deployment, hardened-pod). Disregard any note below that
#  says otherwise.
#
#  ####  THE REAL HAZARD: BEAT 2 EATS BEAT 3'S QUOTA  ##################
#
#  Verified by arithmetic against the actual manifests, not guessed:
#
#    LimitRange defaults        requests 100m / limits 500m per container
#    ResourceQuota production-cap    requests.cpu 2   limits.cpu 2
#
#    Beat 1  web-1 lands                  limits.cpu used = 500m
#    Beat 2  filler --replicas=6, each 500m limit. Only THREE fit
#            (500 + 1500 = 2000m = the hard cap exactly), so the
#            Deployment sits at 3/6 ready and
#                                          limits.cpu used = 2000m / 2000m
#
#  limits.cpu is now FULL. Then Beat 3 applies hardened-pod.yaml, which
#  declares requests but no limits, so LimitRanger fills in a 500m limit
#  -- and ResourceQuota refuses it:
#
#      Error from server (Forbidden): error when creating "hardened-pod.yaml":
#      pods "hardened" is forbidden: exceeded quota: production-cap,
#      requested: limits.cpu=500m, used: limits.cpu=2, limited: limits.cpu=2
#
#  Consequences on camera, in order:
#    - the hardened Pod is never created
#    - `kubectl wait --timeout=90s` then burns NINETY SECONDS of silence
#    - Beat 3.2 and 3.3 have no Pod to exec into
#
#  Beat 3 is dead as written. THE FIX IS ONE LINE and it is added below
#  as beat [2.6]: delete the filler Deployment before Beat 3. It also
#  happens to teach well -- a quota is a live ledger, and watching the
#  same Pod go from Forbidden to Running once you free the budget is a
#  better beat than never hitting the wall at all.
#
#  ==> APPLY THE SAME ONE-LINE FIX TO commands.sh AND THE DECK, or the
#      three artifacts drift apart.
#
#  Beat 4 SURVIVES this, and the reason is worth knowing: ResourceQuota
#  is ordered LAST among the validating admission plugins, so PodSecurity
#  rejects the privileged Pod first and the message you get on camera is
#  the PSS violation, not a quota error. That ordering is why Beat 4 is
#  safe and Beat 3 is not -- the hardened Pod violates no policy, so it
#  falls all the way through to the quota check.
#
#  WHERE THIS FILE HAS TO LIVE
#  ---------------------------
#  M3_DIR resolves to THIS SCRIPT'S OWN DIRECTORY. Put m03.demo.sh and
#  demo-drive.sh in the m03-admission-controls directory next to the
#  manifests, or the six applies will not resolve even once the
#  manifests exist.
#
#  WHERE IT RUNS
#  -------------
#  On control1, over standard SSH from any terminal:
#      ssh vagrant@192.168.50.10        (password: vagrant)
#
#  PREREQUISITE: ../setup-contexts.sh has run once.
#
#  TWO-TERMINAL INVOCATION
#  -----------------------
#  Terminal B -- PRIVATE, monitor 2, your talk track:
#      tty                          # prints e.g. /dev/pts/2 -- note it
#      clear
#
#  Terminal A -- SHARED / RECORDED:
#      PROMPTER_TTY=/dev/pts/2 ./m03.demo.sh
#
#  Omit PROMPTER_TTY and the notes are suppressed rather than leaked.
#
#  KEYS: ENTER = run   ! = improvise   s = skip   q = quit
#
#  #####################################################################
#  ##  RUNTIME WARNING -- DO NOT RUN THIS AT THE DEFAULT TYPE SPEED   ##
#  #####################################################################
#
#  M03 narration was measured at 19.9 min against a 25 min budget
#  BEFORE any typing animation is added. The 30 typed commands in this
#  module put the default TYPE_SPEED=55 straight through the ceiling.
#  Run this module as:
#
#      PROMPTER_TTY=/dev/pts/2 TYPE_SPEED=80 ./m03.demo.sh
#   or PROMPTER_TTY=/dev/pts/2 NO_TYPE=1     ./m03.demo.sh   # pickups
#
#  If it still will not fit, the trim candidates are SLIDES 6, 9,
#  and 10 -- cut slide time, not demo beats.
#
#  RESET TO ZERO FOR THE NEXT TAKE (run this after you stop recording):
#      kubectl delete namespace production
#
# =====================================================================

source "$(dirname "$0")/demo-drive.sh"

demo_header "CKA C04 M03 -- Admission Controls, Resource Limits, and Governance"

# ---------------------------------------------------------------------
# Plumbing. Never on camera: resolve the manifest directory.
# ---------------------------------------------------------------------
pq 'M3_DIR="$(cd "$(dirname "$0")" && pwd)"'


# =====================================================================
# Beat 1: Create the namespace and watch LimitRanger work
# =====================================================================

beat "1.0" "Pin the context before you touch anything" \
    "TODO TALK TRACK -- no runbook exists for M03. Write this beat."
expect "Switched to context \"cka-vagrant\"."
recover "No cka-vagrant context means ../setup-contexts.sh has not been run on this node. Stop, run it, start the take over."
pe 'kubectl config use-context cka-vagrant'

beat "1.1" "The namespace, then the LimitRange that governs it" \
    "TODO TALK TRACK -- no runbook exists for M03. Write this beat."
recover "If this apply fails with 'the path does not exist', you are not running from the m03-admission-controls directory -- m03.demo.sh and demo-drive.sh both have to sit next to the manifests."
pe 'kubectl create namespace production'
pe 'kubectl apply -f "${M3_DIR}/limitrange.yaml"'

beat "1.2" "A Pod that names no resources at all" \
    "A Pod that names no resources at all."
expect "pod/web-1 created, then condition met from the wait."
recover "If the wait times out, kubectl describe pod web-1 -n production and read the events -- an image pull on a cold node is the usual cause, not admission."
pe 'kubectl run web-1 --image=nginx:1.27 -n production'
pe 'kubectl wait --for=condition=Ready pod/web-1 -n production --timeout=90s'

beat "1.3" "The object you get is not the object you sent" \
    "The object you get is not the object you sent: the mutating pass wrote the numbers in before anything was stored."
expect "A resources map with requests and limits in it, on a Pod whose YAML never mentioned either."
pe "kubectl get pod web-1 -n production -o jsonpath='{.spec.containers[0].resources}'; echo"
pe "kubectl describe pod web-1 -n production | grep -A6 -i 'limits\|requests'"

pause_point "End of Beat 1 -- LimitRanger mutated an object nobody asked it to."


# =====================================================================
# Beat 2: Break the ceiling, then fill the quota
# =====================================================================

beat "2.0" "Pin the context" \
    "TODO TALK TRACK -- no runbook exists for M03. Write this beat."
pe 'kubectl config use-context cka-vagrant'

beat "2.1" "Add min and max so there is a ceiling to push against" \
    "Add min and max so there is a ceiling to push against."
recover "Applying this REPLACES production-defaults with the same defaults plus min 50m and max 800m. The deck code slide only shows the defaults half, which is deliberate -- do not say the slide is incomplete, say you are adding a ceiling."
pe 'kubectl apply -f "${M3_DIR}/limitrange-ceiling.yaml"'
pe 'kubectl describe limitrange production-defaults -n production'

beat "2.2" "Half one: the PER-CONTAINER maximum" \
    "Half one: the per-container maximum. Rejected on the validating pass."
expect "A refusal, not a created Pod. This beat is SUPPOSED to fail -- the engine will not abort."
recover "A missing-file error is NOT the admission refusal this beat teaches. If you see 'the path does not exist' you are in the wrong directory -- the demo did not work, it only looked like it did. The real refusal names the constraint AND your value: maximum cpu usage per Container is 800m, but limit is 1500m."
pe 'kubectl apply -f "${M3_DIR}/oversized-pod.yaml"'

beat "2.3" "Half two: the NAMESPACE total" \
    "Half two: the namespace total. Add the quota, then fill it."
recover "Watch the used column, not just the hard column. If used is already non-zero the moment the quota lands, that is correct -- a quota counts the Pods that were already there."
pe 'kubectl apply -f "${M3_DIR}/resourcequota.yaml"'
pe 'kubectl describe resourcequota production-cap -n production'

beat "2.4" "Fill it -- six replicas against a two-core cap" \
    "Each replica requests 500m by LimitRange default; the cap is 2 cores."
say "PRESENTER NOTE, not narration -- do not read aloud: web-1 already holds 500m of the 2000m limits.cpu cap, so exactly THREE filler Pods land, not six. 500 + 1500 = 2000m, the hard cap to the millicore. Expect 3/6 ready and say that number out loud -- it is the whole point of the beat."
expect "The Deployment reports fewer ready replicas than desired. Deployment and ReplicaSet exist; the missing Pods never do."
pe 'kubectl create deployment filler --image=nginx:1.27 --replicas=6 -n production'
pq 'sleep 5'
pe 'kubectl get deployment,replicaset -n production'

beat "2.5" "The Forbidden lives here" \
    "The Forbidden lives here -- on the ReplicaSet, not on a Pod, because the Pod was never created."
say "PRODUCTION NOTE, from the top of commands.sh: the deck's diagnostic slide shows the quota error taken from the Kubernetes docs, which names mem-cpu-demo. Live output on this cluster names production-cap. Say the SHAPE of the message -- exceeded quota, requested, used, limited -- and do NOT read the object name off the slide."
expect "A FailedCreate event quoting 'exceeded quota', naming production-cap. Then the quota's Used line sitting flush against its Hard line."
recover "If tail -25 cuts the Forbidden off, describe the filler ReplicaSet by name instead of the whole namespace -- by Beat 4 there are two ReplicaSets in here and the tail window gets crowded."
pe 'kubectl describe rs -n production | tail -25'
pe 'kubectl describe resourcequota production-cap -n production'

pause_point "End of Beat 2 -- a per-container ceiling and a namespace total, refused in two different places."


# =====================================================================
# Beat 3: Harden a Pod and prove which user it runs as
# =====================================================================

# ---------------------------------------------------------------------
# [2.6] ADDED BEAT -- NOT IN commands.sh. This is the fix for the quota
# collision documented in the header. Without it, Beat 3 is dead: the
# filler Deployment is holding all 2000m of limits.cpu, so the hardened
# Pod gets Forbidden and the 90-second wait runs out on camera.
#
# Add the same line to commands.sh and to the deck so the three
# artifacts do not drift.
# ---------------------------------------------------------------------
beat "2.6" "Give the budget back" \
    "TODO TALK TRACK -- no runbook exists for M03. Write this beat." \
    "Suggested angle, in your words, NOT ghost-written: a quota is a live ledger, not a one-time gate. Free the budget and the very next Pod is admitted. That is worth saying out loud because it is the difference between thinking of a quota as a wall and thinking of it as an account balance."
expect "deployment.apps \"filler\" deleted, then the used column on production-cap drops back toward 500m."
recover "If used does not drop, give the ReplicaSet a few seconds to finish deleting the Pods -- quota accounting follows the Pods, not the Deployment."
pe 'kubectl delete deployment filler -n production'
pe 'kubectl describe resourcequota production-cap -n production'

beat "3.0" "Pin the context" \
    "TODO TALK TRACK -- no runbook exists for M03. Write this beat."
pe 'kubectl config use-context cka-vagrant'

beat "3.1" "The hardened Pod" \
    "TODO TALK TRACK -- no runbook exists for M03. Write this beat."
say "PRODUCTION NOTE, verified against hardened-pod.yaml -- do not read aloud verbatim: nginx:1.27 runs as root, so runAsNonRoot alone would fail at the KUBELET, not at admission. That is why the manifest pairs runAsNonRoot with runAsUser 101 and swaps in nginxinc/nginx-unprivileged, which listens on 8080. A kubelet-stage failure is a different failure in a different place than an admission refusal -- keep the two straight on camera."
expect "pod/hardened created, then condition met."
recover "If this returns Forbidden exceeded quota, beat 2.6 did not run -- the filler Deployment is still holding the limits.cpu budget. Ctrl+C out of the wait, run kubectl delete deployment filler -n production, and re-apply. Do not sit through the 90 second timeout on camera."
pe 'kubectl apply -f "${M3_DIR}/hardened-pod.yaml"'
pe 'kubectl wait --for=condition=Ready pod/hardened -n production --timeout=90s'

beat "3.2" "Check the answer yourself" \
    "Go inside and check the answer yourself rather than trusting the spec."
expect "A uid and gid that are not 0."
pe 'kubectl exec -n production hardened -- id'

beat "3.3" "What readOnlyRootFilesystem actually buys you" \
    "Read-only root filesystem -- exactly what readOnlyRootFilesystem buys you."
say "PRESENTER NOTE, not narration -- do not read aloud: the trailing echo is deliberate on-camera teaching output, kept from commands.sh. It fires BECAUSE the touch fails. Do not read it as an error."
expect "touch refused, then the echo line."
pe 'kubectl exec -n production hardened -- touch /root-test 2>&1 || \
  echo "read-only root filesystem -- exactly what readOnlyRootFilesystem buys you"'

pause_point "End of Beat 3 -- the spec claimed it, the container proved it."


# =====================================================================
# Beat 4: Trace a Pod Security Admission refusal
# =====================================================================

beat "4.0" "Pin the context" \
    "TODO TALK TRACK -- no runbook exists for M03. Write this beat."
pe 'kubectl config use-context cka-vagrant'

beat "4.1" "Turn PSA on for this namespace" \
    "Turn PSA on for this namespace. enforce rejects, warn tells you now."
expect "namespace/production labeled."
pe 'kubectl label namespace production \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=baseline --overwrite'

beat "4.2" "Ladder rung 1 -- which policy is this namespace under?" \
    "Rung one. Which policy is this namespace under?"
expect "Both pod-security labels visible in the LABELS column."
pe 'kubectl get ns production --show-labels'

beat "4.3" "The Deployment is created. Watch for zero Pods." \
    "The Deployment is created. Watch for zero Pods."
recover "If the ReplicaSet message names the QUOTA instead of the Pod Security Standard, beat 2.6 did not run. ResourceQuota is ordered last among validating plugins, so a policy violation should win -- but a full quota plus a compliant Pod would still surface as a quota error."
expect "deployment created, plus a PSA warn line on stdout from the warn label."
pe 'kubectl apply -f "${M3_DIR}/privileged-deployment.yaml"'
pq 'sleep 5'

beat "4.4" "Ladder rung 2 -- did the object get created at all?" \
    "Rung two. Did the object get created at all?"
expect "Deployment and ReplicaSet present, 0 Pods."
pe 'kubectl get deploy,rs,pods -n production -l app=legacy-agent'

beat "4.5" "Ladder rung 3 -- object there, no Pods? Ask its owner." \
    "Rung three. Object there, no Pods? Ask its owner."
expect "A FailedCreate event on the ReplicaSet naming the violated policy."
pe 'kubectl describe rs -n production -l app=legacy-agent | tail -20'

beat "4.6" "Ladder rung 4 -- which guardrail said no?" \
    "Rung four. Which guardrail said no?"
expect "The quota and the LimitRange side by side, so you can rule each one in or out."
pe 'kubectl describe quota,limitrange -n production'

beat "4.7" "Ladder rung 5 -- kubelet, not admission" \
    "Rung five. Pod exists but will not start? That one is the kubelet, not admission."
recover "HEADS UP: web-1 has been happily Running since Beat 1, so the last 15 lines will show a healthy Pod, not a kubelet failure. This rung demonstrates WHERE to look, not a broken Pod. If you want a real kubelet-stage failure on screen, that has to be staged -- and it is not in commands.sh."
pe 'kubectl describe pod web-1 -n production | tail -15'

pause_point "End of Beat 4 -- five rungs, and the evidence moved every time. Stop recording."

demo_footer

# =====================================================================
#  Reset to zero for the next take:
#      kubectl delete namespace production
# =====================================================================
