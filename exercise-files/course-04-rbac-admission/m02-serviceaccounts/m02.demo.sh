#!/usr/bin/env bash
# =====================================================================
#  m02.demo.sh -- presenter script for
#  CKA Course 4 / Module 2 -- Service Accounts and Least-Privilege Access
#  Tim Warner / ps-cka -- CKA v1.35 Skill Path
# =====================================================================
#
#  WHAT THIS IS
#  ------------
#  A driven, two-terminal presenter script for the M02 demo block. The
#  commands are the deck's commands (byte-identical to commands.sh, same
#  order, nothing added or dropped). The talk track is the runbook's
#  talk track, verbatim, and it goes to a PRIVATE terminal only.
#
#  HOW TO RUN IT (the two-terminal trick)
#  --------------------------------------
#  Terminal B -- PRIVATE, second monitor, a second SSH session to the
#  same node. This is where your talk track appears:
#
#      tty            # prints e.g. /dev/pts/2 -- note it
#      clear
#
#  Terminal A -- SHARED / RECORDED:
#
#      PROMPTER_TTY=/dev/pts/2 ./m02.demo.sh
#
#  Omit PROMPTER_TTY and the notes are silently suppressed, so a take
#  can never leak narration onto the recording.
#
#  Keys during a take:  ENTER = run/advance   ! = improvise (then
#  `exit`)   s = skip this command   q = quit cleanly
#
#  WHERE IT RUNS
#  -------------
#  ON control1, over standard SSH from any terminal:
#      ssh vagrant@192.168.50.10        (password: vagrant)
#  Keep this file, demo-drive.sh, and the module's YAML manifests
#  (deploy-runner.yaml, ghost-sa.yaml, no-automount.yaml) in the same
#  directory -- SA_DIR is resolved from this script's own location.
#
#  PREREQUISITE
#  ------------
#  ../setup-contexts.sh has run once. This module needs the
#  cka-vagrant context; it does NOT depend on M01's objects.
#
#  RESET TO ZERO FOR THE NEXT TAKE (from the bottom of commands.sh)
#  ----------------------------------------------------------------
#      kubectl delete namespace staging
#      kubectl config delete-context deploy-bot
#      kubectl config delete-user deploy-bot
#
#  TALK TRACK PROVENANCE -- READ THIS BEFORE YOU EDIT
#  --------------------------------------------------
#  Every say/beat line here is generated VERBATIM from
#  c04-m02-demo-runbook.md. Do not hand-edit narration in this file --
#  edit the runbook and regenerate, or the two drift and the runbook
#  stops being the source of truth.
#
#  KNOWN RUNBOOK / commands.sh DRIFT (flagged, not silently fixed):
#    * Runbook [1.2] has a Say block for "no token Secret" but
#      commands.sh has no `get sa -o jsonpath={.secrets}` /
#      `get secrets -n staging` pair. Beat 1.2 is narration-only.
#    * Runbook [2.1] also runs `can-i create secrets` (the "no").
#      commands.sh does not. EXPECT text trimmed accordingly.
#    * Runbook [2.4] narrates the 3607 `expirationSeconds` jsonpath.
#      commands.sh has no such command. Beat 2.4 is narration-only.
#    * Runbook Demo 3 uses `./lab.sh jwt`; commands.sh decodes with the
#      inline python3 one-liner. Same output, different vehicle.
#    * Runbook [3.3] runs `--duration=5m` for the 10-minute-floor
#      rejection. commands.sh does not, so the "-- after the rejection
#      --" stage direction in 3.2's talk track has nothing to land on.
#    * commands.sh Beat 2's "become the workload" sequence (TOKEN,
#      set-credentials, set-context, whoami, get secrets) and Beat 4's
#      ghost-deploy Deployment sequence have no runbook Say blocks, so
#      those beats carry headlines only -- nothing invented.
#    * The Pod naming a missing ServiceAccount is rejected at ADMISSION.
#      No Pod, no container, and therefore NO CreateContainerConfigError.
#      The deck is right and the outline is wrong; beat 4.1's talk track
#      is preserved exactly as the runbook wrote it.
# =====================================================================

source "$(dirname "$0")/demo-drive.sh"

# ---------------------------------------------------------------------
# Two commands whose quoting is too fragile to inline in a pe call.
# Quoted heredocs, so the text survives byte-for-byte from commands.sh.
# ---------------------------------------------------------------------
JWT_DECODE=$(cat <<'JWTCMD'
kubectl exec -n staging deploy-runner -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/token \
  | python3 -c "import sys,base64,json; p=sys.stdin.read().strip().split('.')[1]; print(json.dumps(json.loads(base64.urlsafe_b64decode(p + '=' * (-len(p) % 4))), indent=2))"
JWTCMD
)

GHOST_PATCH=$(cat <<'GHOSTPATCH'
kubectl patch deployment ghost-deploy -n staging \
  -p '{"spec":{"template":{"spec":{"serviceAccountName":"does-not-exist"}}}}'
GHOSTPATCH
)

demo_header "CKA C04 M02 -- Service Accounts and Least-Privilege Access"

# Plumbing: resolve this script's own directory. Never on camera.
pq 'SA_DIR="$(cd "$(dirname "$0")" && pwd)"'

# =====================================================================
#  Open -- slide 18 (30 sec). No commands, just the framer.
# =====================================================================
beat "0" "Demo framer -- slide 18" \
    "Priya's staging pipeline has deployed as cluster-admin since day one, and the auditor found it before she did." \
    "So here's the fix, live." \
    "I'll create a ServiceAccount with a Role narrow enough to defend, prove the grant before a single Pod exists, then run a Pod as that account and read the credential it's carrying — three files the kubelet put there." \
    "I'll decode the token and show you the one field everybody gets wrong." \
    "Then I'll break a Pod with a ServiceAccount that doesn't exist, because that failure looks nothing like people expect." \
    "Three-node kubeadm cluster, Ubuntu 22.04, containerd, Kubernetes v1.35." \
    "Let's go."

# =====================================================================
#  Demo 1 -- An account of its own (~2:15)
#  commands.sh: --- Beat 1: Create deploy-bot and bind it to a deployer Role
# =====================================================================
beat "1.0" "Look before you touch. Six clusters on the real exam."
pe 'kubectl config use-context cka-vagrant'

beat "1.1" "Namespace, then the account. sa is the abbreviation that saves you time."
pe 'kubectl create namespace staging'
pe 'kubectl create sa deploy-bot \
  -n staging'

# DRIFT: the two commands that prove this (jsonpath .secrets + get
# secrets -n staging) are in the runbook, not in commands.sh. Narration
# only -- do not improvise commands the deck does not show.
beat "1.2" "Where's the token Secret? There isn't one. That stopped in v1.24." \
    "Look at that." \
    "Empty, and no Secrets in the namespace at all." \
    "Before Kubernetes 1.24, creating a ServiceAccount got you a Secret holding a token that never expired — and read access on that Secret was a working credential, forever." \
    "That auto-generation stopped in 1.24, and no switch brings it back." \
    "So where does the token come from now?" \
    "That's Demo 2."

beat "1.3" "A Role narrow enough to defend every verb in it."
pe 'kubectl create role deployer \
  --verb=create,update,get,list \
  --resource=deployments,services \
  -n staging'

beat "1.4" "The binding. The flag is --serviceaccount, and it takes namespace:name." \
    "This is the flag worth memorizing: \`--serviceaccount\`, and it takes **namespace colon name**, not the bare name." \
    "And here's the trap — if you reach for \`--user=deploy-bot\` instead, the command succeeds, the binding gets created, and the grant does absolutely nothing." \
    "Green output, zero permission." \
    "Because the real username of a ServiceAccount is \`system:serviceaccount:staging:deploy-bot\`, and \`--user\` takes you literally."
pe 'kubectl create rolebinding \
  deploy-bot-deployer \
  --role=deployer \
  -n staging \
  --serviceaccount=staging:deploy-bot'
expect 'describe shows Kind: ServiceAccount, Name: deploy-bot, Namespace: staging'
pe 'kubectl describe rolebinding deploy-bot-deployer -n staging'

# Exam tip (verbatim) -- runbook, end of Demo 1.
say "Order of operations, and the tasks leave one out on purpose."
say "ServiceAccount, then Role, then RoleBinding, then the Pod."
say "Submit the Pod first and the API server refuses it outright — unlike a RoleBinding aimed at a Role that doesn't exist yet, which is accepted and simply grants nothing until the Role shows up."

pause_point "End of Demo 1 -- an account of its own."

# =====================================================================
#  Demo 2 -- Prove the grant, then read the credential (~2:45)
#  commands.sh: --- Beat 2: Prove the grant, then read the token inside the Pod
# =====================================================================
beat "2.0" "Confirm the context."
pe 'kubectl config use-context cka-vagrant'

beat "2.1" "A ServiceAccount is just a username with a long prefix." \
    "I'm testing the grant before a Pod exists, and that's the habit worth building." \
    "The subject is \`system:serviceaccount:staging:deploy-bot\` — namespace and name, with a prefix." \
    "Deployments, yes." \
    "Secrets, no, because the Role never mentioned them." \
    "And \`--list\` dumps everything that subject can do in there, which turns 'why is my pipeline Forbidden' from guesswork into reading."
expect 'yes, then a rules table (commands.sh omits the runbook can-i create secrets line)'
pe 'kubectl auth can-i create deployments -n staging \
  --as system:serviceaccount:staging:deploy-bot'
pe 'kubectl auth can-i --list -n staging \
  --as system:serviceaccount:staging:deploy-bot'

beat "2.2" "Now the Pod that names it. One line does the work."
recover 'if the Pod never goes Ready: kubectl describe pod deploy-runner -n staging and read the events -- an image pull on a fresh node is the usual cause, not RBAC.'
pe 'kubectl apply -f "${SA_DIR}/deploy-runner.yaml" -n staging'
pe 'kubectl wait --for=condition=Ready pod/deploy-runner -n staging --timeout=90s'

beat "2.3" "Three files, projected in by the kubelet. No Secret object involved." \
    "Three files." \
    "**token is who I am, ca.crt is who I trust, namespace is where I live.**" \
    "And notice what's missing — there's no Secret object anywhere in this namespace." \
    "The kubelet asked the TokenRequest API for this token and wrote it straight into the Pod." \
    "Nothing to read, nothing to leak, nothing sitting in etcd waiting to be found."
expect 'exactly three names -- ca.crt, namespace, token -- then staging'
pe 'kubectl exec -n staging deploy-runner -- \
  ls -l /var/run/secrets/kubernetes.io/serviceaccount/'
pe 'kubectl exec -n staging deploy-runner -- \
  cat /var/run/secrets/kubernetes.io/serviceaccount/namespace; echo'

# DRIFT: the 3607 expirationSeconds jsonpath lives in the runbook only.
# commands.sh has no command here. Narration only.
beat "2.4" "The volume is NOT in my YAML. Admission wrote it. Note the 3607." \
    "Now open \`deploy-runner.yaml\` in your head." \
    "Did I declare a volume?" \
    "No." \
    "I set one line, \`serviceAccountName\`." \
    "That projected volume was added by the **ServiceAccount admission controller** in the API server, and the kubelet is what fills it." \
    "Two different components, and people blur them." \
    "And look at the number — **3607** seconds." \
    "Everybody expects thirty-six hundred." \
    "You can't tune it, so if you need a different lifetime you write your own projection."

beat "2.5" "Now BECOME the workload -- a bearer token, where frontend-dev used a client certificate."
pe 'TOKEN=$(kubectl create token deploy-bot -n staging --duration=30m)'
pq 'kubectl config set-credentials deploy-bot --token="${TOKEN}" >/dev/null'
pq 'kubectl config set-context deploy-bot \
  --cluster=kubernetes \
  --user=deploy-bot \
  --namespace=staging >/dev/null'
pe 'kubectl config use-context deploy-bot'
expect 'system:serviceaccount:staging:deploy-bot'
pe 'kubectl auth whoami'
expect 'the Deployments list -- allowed by the deployer Role'
pe 'kubectl get deployments'
expect 'Forbidden: no rule covers Secrets'
pe 'kubectl get secrets'
pe 'kubectl config use-context cka-vagrant'

# Exam tip (verbatim) -- runbook, end of Demo 2.
say "An empty \`apiGroups\` value means the **core** group, so Pods and Services and ConfigMaps live there — but Deployments do not."
say "Deployments are in \`apps\`, and \`kubectl create role --resource=deployments\` fills that in for you."
say "Hand-write the YAML and forget it, and you get a Role that looks right and grants nothing."

pause_point "This is the strongest beat in the module."

# =====================================================================
#  Demo 3 -- Decode the claims, mint on demand (~2:15)
#  commands.sh: --- Beat 3: Decode the claims and mint a token on demand
# =====================================================================
beat "3.0" "Confirm the context."
pe 'kubectl config use-context cka-vagrant'

beat "3.1" "The payload is the middle segment of the JWT -- base64url, so let Python do it." \
    "There's the \`sub\` claim, and that string is the username on the wire — the exact thing you hand to \`--as\`." \
    "Now look at \`exp\`." \
    "Everybody expects an hour, because the volume asked for 3607 seconds." \
    "It's about a **year** out." \
    "The API server extends injected tokens by default, and \`warnafter\` is the claim sitting at the hour mark." \
    "So what actually limits your exposure is not \`exp\` — it's **rotation**." \
    "The kubelet rewrites that file once the token passes eighty percent of its lifetime, or at twenty-four hours, whichever comes first." \
    "Which means your application has to reread the file." \
    "Cache it once at startup and you have written a time bomb."
expect 'sub = system:serviceaccount:staging:deploy-bot, the aud, the iss, an exp roughly 365 days out, a warnafter about 60 minutes out, and the kubernetes.io block naming the namespace, serviceaccount, pod, and node'
expect 'read aloud: iss, sub, aud, exp, and the kubernetes.io bound-object claim naming this Pod -- that binding is why deleting the Pod kills the credential about a minute later'
recover 'if the decode says it cannot read the token, the Pod from Demo 2 is not running -- kubectl get pod -n staging.'
pe "${JWT_DECODE}"

# DRIFT: the runbook's [3.3] --duration=5m rejection is not in
# commands.sh, so the "after the rejection" stage direction below has
# nothing on screen to land on. Deck order wins; do not add the command.
beat "3.2" "A short-lived token for testing or automation, printed and not stored." \
    "\`kubectl create token\` hits the same TokenRequest API the kubelet uses, and prints a credential that stops working in ten minutes." \
    "And notice I said ten, not five — watch." \
    "— after the rejection —" \
    "Ten minutes is the server's floor." \
    "There are two other flags worth knowing: \`--audience\` names who the token is for, and unset means this API server." \
    "\`--bound-object-kind\` takes Node, Pod, or Secret, and ties the token's life to that object — bind it to a Pod and the token dies with the Pod." \
    "Small heads-up: the published API reference still lists only Pod and Secret." \
    "It's stale; the server takes Node."
pe 'kubectl create token deploy-bot -n staging --duration=10m'

# Exam tip (verbatim) -- Distractor Watch, runbook end of Demo 3.
say "A task asks you to get a token to test a ServiceAccount, and one of the answers walks you through creating a Secret and reading the token out of it."
say "That was the right answer before 1.24."
say "The scored answer now is \`kubectl create token\`."
say "If you find yourself hand-writing a Secret of type \`kubernetes.io/service-account-token\`, you are on the legacy path, and the docs call it the last resort."

pause_point "End of Demo 3 -- claims decoded, token minted."

# =====================================================================
#  Demo 4 -- Break it, then take the credential away (~2:00)
#  commands.sh: --- Beat 4: Break it with a missing ServiceAccount, then opt out
# =====================================================================
beat "4.0" "Confirm the context."
pe 'kubectl config use-context cka-vagrant'

# THE TRAP, PRESERVED: rejected at admission means no Pod and no
# container, so there is NO CreateContainerConfigError here. The deck is
# right, the outline is wrong. This narration is the runbook's, verbatim.
beat "4.1" "Rejected at admission. No Pod appears, so there is nothing to describe." \
    "Read that carefully." \
    "**Forbidden**, and the phrase that matters is *error looking up service account*." \
    "This happened at the API server during admission — before scheduling, and long before any kubelet was involved." \
    "So watch what happens when I go looking for the Pod." \
    "Nothing." \
    "No Pending Pod, no container error, nothing to describe, because **no Pod object was ever created.**" \
    "Now here's why that's worth a slide of its own: people expect \`CreateContainerConfigError\`." \
    "That error is real, but it belongs to a missing ConfigMap or a missing Secret — it's a kubelet-stage failure, and the kubelet never saw this." \
    "If a Deployment owned the Pod, the evidence moves up to the owner: a \`FailedCreate\` event on the ReplicaSet and a \`ReplicaFailure\` condition on the Deployment."
expect 'Error from server (Forbidden) ... pods "ghost-runner" is forbidden: error looking up service account staging/does-not-exist: serviceaccount "does-not-exist" not found'
pe 'kubectl apply -f "${SA_DIR}/ghost-sa.yaml"'
expect 'ghost-runner is absent from the list'
pe 'kubectl get pods -n staging'

beat "4.2" "Same failure through a controller -- the message waits one level down on the ReplicaSet."
pe 'kubectl create deployment ghost-deploy --image=nginx:1.27 -n staging'
pe "${GHOST_PATCH}"
expect 'a FailedCreate event on the ReplicaSet and a ReplicaFailure condition on the Deployment'
pe 'kubectl describe rs -n staging | tail -20'

beat "4.3" "Take the credential away from a workload that never calls the API." \
    "Least privilege has a floor below one narrow Role, and that floor is no credential at all." \
    "\`automountServiceAccountToken: false\`, and the whole projected volume is gone — that path doesn't exist inside the container." \
    "Watch where the field goes, because it moves: a ServiceAccount has no \`spec\` block, so on the account it sits at the top level beside \`metadata\`." \
    "On a Pod it lives under \`spec\`." \
    "And if they disagree, **the Pod wins.**"
pe 'kubectl apply -f "${SA_DIR}/no-automount.yaml"'
pe 'kubectl wait --for=condition=Ready pod/quiet-runner -n staging --timeout=90s'
expect 'the Pod goes Ready, then ls fails -- no such file or directory'
pe 'kubectl exec -n staging quiet-runner -- \
  ls /var/run/secrets/kubernetes.io/ || echo "no token mounted -- exactly the point"'

# Exam tip (verbatim) -- Decision Tree, runbook end of Demo 4.
say "If the workload never talks to the API server, the branch is \`automount false\`, and you set it on the ServiceAccount so every Pod inherits it."
say "If most Pods on that account shouldn't get a token but one has to, set false on the account and true on that one Pod."
say "The Pod spec takes precedence, and that is documented, not folklore."

pause_point "Demos done. Stop recording, then ./lab.sh reset."

# =====================================================================
#  Close -- slides 23-24 (~1:15). No commands.
# =====================================================================
beat "close" "Slides 23-24 -- Globomantics checkout and key takeaways" \
    "One ServiceAccount, one narrow Role, one binding that names it, and one line on the Pod template." \
    "We proved the grant before the Pod existed, read the three files the kubelet projected in, and found an \`exp\` a year out where everybody expects an hour — which is why rotation, not expiry, is what protects you." \
    "Then a missing ServiceAccount got refused at admission with no Pod to go looking for, and a quiet workload got no credential at all." \
    "There's one gap left, though." \
    "Nothing we did stops an engineer submitting a Pod that runs as root or claims every core on the node." \
    "Authorization said yes; nobody inspected the object." \
    "That's admission control, and that's where we're going next."

demo_footer
