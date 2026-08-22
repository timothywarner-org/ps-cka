#!/usr/bin/env bash
# =====================================================================
#  m01.demo.sh -- presenter script for
#  CKA Course 4 / Module 1 -- Authentication, Authorization, and RBAC
#  Fundamentals. Four demos, 39 commands, ~12 min on camera.
#
#  WHAT THIS IS
#  ------------
#  A driver for demo-drive.sh. It types every command onto the SHARED
#  terminal and puts your talk track on a PRIVATE second terminal. You
#  press ENTER and read. Nothing here is a mock -- every command runs
#  for real against the live cluster, including the ones that 403.
#
#  HOW TO RUN IT -- TWO TERMINALS
#  ------------------------------
#  In the PRIVATE terminal (second SSH session, monitor 2):
#
#      tty            # prints e.g. /dev/pts/2 -- note it
#      clear
#
#  In the SHARED / RECORDED terminal:
#
#      PROMPTER_TTY=/dev/pts/2 ./m01.demo.sh
#
#  Omit PROMPTER_TTY and the talk track is silently suppressed, so a
#  take can never leak your notes onto the recording.
#
#  WHERE TO RUN IT
#  ---------------
#  On the node, as the vagrant user:  vagrant ssh control1  then  cd ~/m01
#  It must run on control1 in ~/m01 -- Demo 1 calls ./lab.sh mint, which
#  lives in that folder.
#
#  BETWEEN TAKES
#  -------------
#      ./lab.sh reset          # 8 sec, prints READY FOR TAKE
#
#  PROVENANCE -- READ THIS BEFORE YOU EDIT
#  ---------------------------------------
#  The talk track in this file is GENERATED from
#  c04-m01-demo-runbook.md and is verbatim from that file's `Say --`
#  blocks. Edit the runbook, then regenerate this file. NEVER edit this
#  file by hand -- a hand edit silently forks the script from the
#  runbook, and the runbook is what the deck, lab.sh, and the fact gate
#  are all vetted against.
# =====================================================================

source "$(dirname "$0")/demo-drive.sh"

demo_header "CKA C04 M01 -- Authentication, Authorization, and RBAC Fundamentals"

# ---------------------------------------------------------------------
# Open -- slide 19 (~30 sec). Pure narration, no command.
# ---------------------------------------------------------------------
beat "0.0" "Open — slide 19" \
    'Every engineer at Globomantics holds cluster-admin, and last Friday one of them deleted the production namespace.' \
    "Priya's fixing that today, and so are we, live." \
    "Here's the plan." \
    "I'll build a real user out of a certificate and the cluster's going to refuse them." \
    "Then I'll grant one narrow permission and watch that same command start working." \
    "Then I'll try to write, and get refused again, which is the point." \
    'Three-node kubeadm cluster, Ubuntu 22.04, containerd, Kubernetes v1.35.' \
    'The error messages are the lesson.' \
    "Let's go."

# ===== DEMO 1 — Identity is free, authorization is not (~2:00) =====

beat "1.0" "Look before you touch. Six clusters on the real exam." \
    'Every demo in this course opens exactly like this.' \
    'A context is three things at once: a cluster, a user, and a default namespace.' \
    'The real CKA exam runs **six clusters**, and every task starts by telling you to run `use-context` something.' \
    "Skip that line and you'll do perfect work on the wrong cluster and score zero." \
    'Look before you touch.'
pe 'kubectl config get-contexts'

beat "1.1" "Namespace first -- a Role is namespaced, so the order is tested."
recover '`AlreadyExists` on the namespace or CSR means a prior take left state — narrate it ("already there from my last run, clearing it"), run `./lab.sh reset`, resume.'
pe 'kubectl create namespace dev-team'

beat "1.2" "Mint a real user: key -> CSR -> cluster CA signs -> kubeconfig context." \
    "Here's what trips everybody up." \
    '**There is no User object in Kubernetes.**' \
    'Try `kubectl get users`.' \
    'Nothing comes back.' \
    "A user is whatever the authentication layer decides your credential means, and for an X.509 cert that's two fields: CN becomes the username, O becomes a group." \
    "That's the entire user model." \
    'The script generated a key, submitted a CertificateSigningRequest, approved it with `kubectl certificate approve` — itself an exam command — and wired the signed cert into a context.'
pe './lab.sh mint'

beat "1.3" "Two contexts now. Creating one does NOT switch you into it." \
    "Two contexts now, and notice creating one didn't switch me into it." \
    'So I switch, out loud, because from here every command runs as somebody else.' \
    'Username frontend-dev.' \
    'Group globomantics, straight out of the O field.' \
    'And system:authenticated, added because the cert checked out against the cluster CA.' \
    '**The cluster knows precisely who this is** — and that worked with zero permissions granted, because `system:basic-user` is bound to `system:authenticated`.' \
    'Asking about yourself is free.'
expect 'two rows with the star still on `cka-vagrant`, then `Switched to context "frontend-dev".`, then Username `frontend-dev` / Groups `[globomantics system:authenticated]`.'
pe 'kubectl config get-contexts'
pe 'kubectl config use-context frontend-dev'
pe 'kubectl auth whoami'

beat "1.4" "Now let them look at something." \
    'And it still says no.' \
    'Read the status code, not the sentence: **403 Forbidden.**' \
    "That's not a 401." \
    "A 401 would mean the cluster couldn't work out who you are." \
    "A 403 means it knows exactly who you are and it's refusing anyway." \
    'Authentication passed.' \
    'Authorization failed.' \
    '**That gap is the entire subject of this module.**' \
    'And the error names four things — the user, the verb, the resource, and the namespace.' \
    'Kubernetes hands you most of the diagnosis for free.' \
    "RBAC is **deny by default**; there's nothing for me to take away here, because nothing was ever granted."
expect 'Error from server (Forbidden): pods is forbidden: User "frontend-dev" cannot list resource "pods" in API group "" in the namespace "dev-team"'
recover 'A 401 instead of a 403 means the cert is bad: `./lab.sh mint` and resume at `[1.3]`.'
pe 'kubectl get pods -n dev-team'
say "EXAM TIP:" \
    "The CKA hands you a user who can't do something and asks you to fix it." \
    '**First thing you type is `kubectl auth whoami`.**' \
    "Identity comes back? Authentication's fine, go find the missing Role or binding." \
    'Unauthorized? Stop looking at RBAC — your credential is wrong, and no Role you write will help.'

beat "1.5" "Borrow an identity, do the one thing, hand it back."
pe 'kubectl config use-context cka-vagrant'

pause_point "Stop the clip. You have a user who can prove who they are and do nothing."

# ===== DEMO 2 — Two objects, never one (~3:00) =====

beat "2.0" "Confirm the context before creating anything."
pe 'kubectl config current-context'

beat "2.1" "A Role is a permission set attached to nobody yet." \
    'Three flags is the whole command: verbs, resource, namespace.' \
    "Type it until it's muscle memory, because you'll type it under a timer." \
    'And look at that empty Resource Names column — blank means all Pods here.' \
    'Pass `--resource-name=web-1` and the rule reaches exactly one Pod.'
expect 'PolicyRule table, Resource Names **blank**, Verbs `[get list watch]`.'
pe 'kubectl create role pod-reader --verb=get,list,watch --resource=pods -n dev-team'
pe 'kubectl describe role pod-reader -n dev-team'

beat "2.2" "The binding is the half that actually grants." \
    'Then the binding, which is the half that actually grants.' \
    'Two objects, never one.' \
    "The Role says **what**, the binding says **who**, and 'I created the Role and it still doesn't work' is the number one RBAC ticket on earth."
pe 'kubectl create rolebinding frontend-dev-reads --role=pod-reader --user=frontend-dev -n dev-team'

beat "2.3" "Same command that failed in [1.4]. Nothing about the user changed." \
    'Watch.' \
    "I haven't touched the certificate." \
    'Same user, same command, and this is the exact thing that threw a 403 ninety seconds ago.'
expect '`No resources found in dev-team namespace.` — a success.'
recover 'still Forbidden means the binding landed in the wrong namespace — `kubectl get rolebinding -A | grep frontend-dev`.'
pe 'kubectl config use-context frontend-dev'
pe 'kubectl get pods -n dev-team'
say '**No resources found is a success.**'
say "That's the API server saying *yes, you're allowed, and the namespace is empty*."
say 'A 403 looks nothing like this.'
say 'One RoleBinding turned a refusal into an answer.'

beat "2.4" 'Write wall. get/list/watch was the whole grant. Note the NAMED pod: `delete pod --all` would list (allowed), find nothing, and exit 0 without ever asking about delete.' \
    "And here's the other half of the lesson." \
    'I granted get, list, and watch.' \
    "I didn't grant delete." \
    "So the write comes back Forbidden — and that isn't a bug to go fix, that's the grant being **exactly as narrow as I designed it.**" \
    "Now look closely at that first error, because there's a free lesson in it." \
    'There is no Pod called `web-1` in this namespace.' \
    'I still got a **403, not a 404.**' \
    'The API server authorizes your request *before* it ever goes looking for the object, which means a Forbidden tells you nothing about whether the thing exists.' \
    'Handy on the exam, and handy at 2am.' \
    'Secrets, same 403, different reason: nothing in pod-reader mentions Secrets at all.'
expect '**three** Forbiddens — and note the first one is a 403, not a 404, even though `web-1` does not exist.'
pe 'kubectl delete pod web-1 -n dev-team'
pe 'kubectl create deployment nginx --image=nginx -n dev-team'
pe 'kubectl get secrets -n dev-team'

beat "2.5" "Hand it back, then ask the admin's version." \
    "Then the version you'll actually use at work." \
    '`can-i --as` is your RBAC unit test, and you run it **before** a developer hits a 403 and files a ticket.' \
    "\`--list\` is the one to memorize — it dumps every rule that applies to that subject, which turns 'why can't they do the thing' from guesswork into reading."
expect '`yes`, `no`, then a rules table.'
pe 'kubectl config use-context cka-vagrant'
pe 'kubectl auth can-i list   pods -n dev-team --as frontend-dev'
pe 'kubectl auth can-i delete pods -n dev-team --as frontend-dev'
pe 'kubectl auth can-i --list      -n dev-team --as frontend-dev'
say "EXAM TIP:" \
    'Classic trap.' \
    'Binding to a ServiceAccount is `--serviceaccount=namespace:name`, **never** `--user`.' \
    "Pass \`--user=my-sa\` and the command succeeds, the binding gets created, and the grant does nothing — because a ServiceAccount's real username is \`system:serviceaccount:namespace:name\`." \
    'Green output, zero permission.'

pause_point "Strongest beat in the module. Give it room."

# ===== DEMO 3 — The binding sets the scope (~2:45) =====

beat "3.0" "Admin again?"
pe 'kubectl config current-context'

beat "3.1" 'Attach the built-in `view` with a NAMESPACED RoleBinding.' \
    "I'm changing exactly one variable." \
    'Same user, same ClusterRole, same three questions.' \
    'The only difference is the kind of binding object.' \
    'And note the flag — `--clusterrole`, not `--role`.' \
    "I'm reaching for a ClusterRole that already ships with Kubernetes and attaching it with a namespaced binding." \
    "That combination is the most useful pattern in RBAC: reuse one ClusterRole across many teams, let each team's RoleBinding decide where it applies."
pe 'kubectl create rolebinding view-in-dev-team --clusterrole=view --user=frontend-dev -n dev-team'

beat "3.2" "Three questions. Remember the answers." \
    'ConfigMaps, not Pods — pod-reader never mentioned ConfigMaps, so that first result came from `view`.' \
    'Then two refusals.' \
    "**A RoleBinding is a fence,** and it doesn't care that \`view\` is a ClusterRole." \
    'The binding lives in dev-team, so the grant stops there.' \
    "And a namespaced binding can't reach a cluster-scoped object like Namespaces with any role, ever."
expect 'allow, **deny**, **deny**.'
pe 'kubectl config use-context frontend-dev'
pe 'kubectl get configmaps -n dev-team'
pe 'kubectl get configmaps -n kube-system'
pe 'kubectl get namespaces'
pe 'kubectl config use-context cka-vagrant'

beat "3.3" "SAME ClusterRole. Different binding kind. No -n -- it has no namespace." \
    'Same ClusterRole by name.' \
    "I'm not editing it, I'm not copying it, I haven't written a single rule." \
    'One new binding object — and no `-n` flag, because a ClusterRoleBinding has no namespace of its own.'
pe 'kubectl create clusterrolebinding frontend-dev-views-all --clusterrole=view --user=frontend-dev'

beat "3.4" "The identical three questions." \
    'Now the identical three questions.' \
    'Nothing about the permissions changed.' \
    'The **reach** changed.' \
    'Say it with me: **the role says what, the binding says where.**'
expect 'allow, allow, allow — `get namespaces` lists every namespace on the cluster.'
recover "\`get namespaces\` still denied — RBAC propagation lag. Wait two seconds and re-run. Don't debug on camera."
pe 'kubectl config use-context frontend-dev'
pe 'kubectl get configmaps -n dev-team'
pe 'kubectl get configmaps -n kube-system'
pe 'kubectl get namespaces'
pe 'kubectl config use-context cka-vagrant'
say "EXAM TIP:" \
    'This is the decision tree for basically every RBAC question on the exam.' \
    'Does the task name a namespace? RoleBinding.' \
    "Does it say 'in all namespaces,' or name a cluster-scoped object like Nodes or PersistentVolumes? ClusterRoleBinding." \
    "One question, and you've picked the right object." \
    'And a ClusterRoleBinding is the one you get wrong at two in the morning — it applies in every namespace that exists today **and** every one anybody creates next year, and nothing about the object reminds you.' \
    'Reach for a RoleBinding first, every time.'

pause_point

# ===== DEMO 4 — Built-ins, then let kubectl write the YAML (~1:50) =====

beat "4.0" "Context check, one last time. No switch needed -- this is all admin reading."
pe 'kubectl config current-context'

beat "4.1" "The four that matter."
pe 'kubectl get clusterrole view edit admin cluster-admin'

beat "4.2" "Prove the claim instead of asserting it." \
    'Here it is, the fact people miss.' \
    '`view` never reads Secrets — no rule, nothing.' \
    '`edit` reads them **and writes them.**' \
    "So 'read-only' and 'safe' are not the same sentence." \
    "If an exam question hands you a user who shouldn't see credentials and offers \`edit\`, that's the trap."
expect 'prints `NO secrets rule in view` — `grep` matches nothing, so the `||` branch fires and echoes that line. Then a `secrets` row for `edit` listing the write verbs.'
pe 'kubectl describe clusterrole view | grep -i secret || echo "NO secrets rule in view"'
pe "kubectl describe clusterrole edit | grep -i '^  secrets'"
say "And \`edit\` doesn't own most of those rules."
say 'It carries a **label selector**, and a controller merges in every ClusterRole wearing that label.'
say 'You compose permissions, you never copy them — and you never hand-write rules onto an aggregated ClusterRole, because the controller overwrites you.'

beat "4.3" "Generate, don't memorize. --dry-run=client never hits the API server." \
    'That command created nothing.' \
    '`--dry-run=client` means kubectl built the object in memory, printed it, and never touched the API server.' \
    'Built-ins first, and remember `edit` reads Secrets.' \
    "When they don't fit, don't write YAML from memory — run the imperative command with \`--dry-run=client -o yaml\`, redirect it to a file, edit the two lines that matter." \
    'That habit is worth minutes on the exam.'
expect 'prints a Role manifest with the same rules as `pod-reader.yaml`. It is **not** byte-identical: the dry-run adds `creationTimestamp: null` and omits `namespace:` (there is no `-n` on the command).'
expect "Say \"same rules, and I'd add the namespace\" rather than claiming they match exactly."
pe 'kubectl create role pod-reader --verb=get,list,watch --resource=pods --dry-run=client -o yaml'
say "EXAM TIP:" \
    '`can-i --list` and `--dry-run=client -o yaml` are the two to have loaded before you sit down.' \
    "One tells you what a subject can already do, the other writes the object you're about to create." \
    "Between them you'll answer most RBAC tasks without opening the docs — and that saved time goes to the questions that are actually hard."

pause_point 'Demos done. Stop recording, then `./lab.sh reset`.'

demo_footer
