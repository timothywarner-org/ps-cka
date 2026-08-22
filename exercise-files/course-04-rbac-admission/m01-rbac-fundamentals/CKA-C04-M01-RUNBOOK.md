# CKA C04 M01 -- RBAC Fundamentals: Demo Runbook

**Authentication, Authorization, and RBAC Fundamentals** · Course 4 of 11 · CKA v1.35
**39 commands, four demos, about 10 minutes on camera.**

Run the command, read the Say, move to the next number. Every step has one.

---

## Before you roll

```powershell
# Windows host, Administrator PowerShell 7
cd C:\github\ps-cka\src\cka-lab
.\Initialize-C04M01Lab.ps1          # add -Bootstrap the first time on fresh VMs
```

```bash
# On the node
ssh vagrant@192.168.50.10           # password: vagrant
cd ~/m01
./lab.sh                            # reset + verify -- MUST exit 0 before you record
```

**Between takes:** `./lab.sh reset` (~8 seconds)
**If the mint misbehaves on camera:** `./lab.sh mint` is idempotent, ~15 seconds, then resume at step 4.

---

## Cold open -- slide 19

**Say:** "Checking in with Globomantics. Every engineer there holds cluster-admin, and last Friday one of them deleted the production namespace. Priya's fixing that today, and so are we, live. Here's the plan. I'll build a real user out of a certificate and the cluster's going to refuse them. Then I'll grant one narrow permission and watch that same command start working. Then I'll try to write, and get refused again, which is the point. Three-node kubeadm cluster, Ubuntu 22.04, containerd, Kubernetes v1.35. The error messages are the lesson. Let's go."

---

## Demo 1 -- Identity is free, authorization is not

### 1

```bash
kubectl config get-contexts
```

One row, star on `cka-vagrant`.

**Say:** "Every demo in this course opens exactly like this. A context is three things at once: a cluster, a user, and a default namespace. The real CKA exam runs **six clusters**, and every task starts by telling you to run `use-context` something. Skip that line and you'll do perfect work on the wrong cluster and score zero. Look before you touch."

### 2

```bash
kubectl create namespace dev-team
```

`namespace/dev-team created`

**Say:** "Namespace first, and that ordering isn't arbitrary. A Role is a namespaced object, so the namespace has to exist before the Role can live in it. The exam tests that, and it's a cheap point to lose."

### 3

```bash
./lab.sh mint
```

Four numbered banners. Watch for `CN=frontend-dev` and `O=globomantics`, then the CSR going Pending, then Approved,Issued.

**Say:** "Here's what trips everybody up. **There is no User object in Kubernetes.** Try `kubectl get users`. Nothing comes back. A user is whatever the authentication layer decides your credential means, and for an X.509 cert that's two fields: CN becomes the username, O becomes a group. That's the entire user model."

**Say, while the four banners are still on screen -- this matters:** "Now, one honest caveat. `lab.sh` is a helper I wrote for this course, and **you won't have it on the exam.** So let me tell you exactly what it just did, because every one of these is a command you could be asked to run by hand. It generated a private key with `openssl genrsa`. It built a signing request with `openssl req`, and that's where `/CN=frontend-dev/O=globomantics` gets set -- CN is the username, O is the group, and that one flag is the whole identity. It base64'd that request into the `spec.request` field of a CertificateSigningRequest and applied it. Then `kubectl certificate approve frontend-dev` -- **that's the exam command, memorize it.** It pulled the signed certificate back out of `.status.certificate`, decoded it, and finally wired it into a kubeconfig with `set-credentials` and `set-context`. Seven commands. The script is convenience, not magic, and none of it is hidden from you -- it's all in `lab.sh` in the repo."

**The seven commands, for reference.** You're not running these on camera -- the mint already did. Talk over them:

```bash
openssl genrsa -out frontend-dev.key 2048
openssl req -new -key frontend-dev.key -out frontend-dev.csr \
  -subj "/CN=frontend-dev/O=globomantics"
kubectl apply -f frontend-dev-csr.yaml          # spec.request = base64 of the .csr
kubectl certificate approve frontend-dev        # <-- THE exam command
kubectl get csr frontend-dev -o jsonpath='{.status.certificate}' | base64 -d > frontend-dev.crt
kubectl config set-credentials frontend-dev \
  --client-certificate=frontend-dev.crt --client-key=frontend-dev.key --embed-certs=true
kubectl config set-context frontend-dev --cluster=kubernetes --user=frontend-dev --namespace=dev-team
```

**Optional extra step, if you want the object on screen.** Read-only, safe to add, and `get csr` is itself exam-relevant:

```bash
kubectl get csr frontend-dev
```

`Approved,Issued`

**Say:** "And there's the object itself. Approved, Issued. On the exam, `kubectl get csr` is how you find a request waiting on you, and `kubectl certificate approve` is how you clear it."

### 4

```bash
kubectl config get-contexts
```

Two rows now. Star is **still** on `cka-vagrant`.

**Say:** "Two contexts now, and notice creating one didn't switch me into it."

### 5

```bash
kubectl config use-context frontend-dev
```

`Switched to context "frontend-dev".`

**Say:** "So I switch, out loud, because from here every command runs as somebody else."

### 6

```bash
kubectl auth whoami
```

Username `frontend-dev`, Groups `[globomantics system:authenticated]`

**Say:** "Username frontend-dev. Group globomantics, straight out of the O field. And system:authenticated, added because the cert checked out against the cluster CA. **The cluster knows precisely who this is** -- and that worked with zero permissions granted, because `system:basic-user` is bound to `system:authenticated`. Asking about yourself is free."

### 7

```bash
kubectl get pods -n dev-team
```

`Error from server (Forbidden): pods is forbidden: User "frontend-dev" cannot list resource "pods" in API group "" in the namespace "dev-team"`

**Say:** "And it still says no. Read the status code, not the sentence: **403 Forbidden.** That's not a 401. A 401 would mean the cluster couldn't work out who you are. A 403 means it knows exactly who you are and it's refusing anyway. Authentication passed. Authorization failed. **That gap is the entire subject of this module.** And the error names four things -- the user, the verb, the resource, and the namespace. Kubernetes hands you most of the diagnosis for free. RBAC is **deny by default**; there's nothing for me to take away here, because nothing was ever granted."

**Exam tip:** "The CKA hands you a user who can't do something and asks you to fix it. **First thing you type is `kubectl auth whoami`.** Identity comes back? Authentication's fine, go find the missing Role or binding. Unauthorized? Stop looking at RBAC -- your credential is wrong, and no Role you write will help."

### 8

```bash
kubectl config use-context cka-vagrant
```

`Switched to context "cka-vagrant".`

**Say:** "And I hand the identity back. Borrow it, do the one thing, give it back. Camping out in a test user's context is how you end up doing admin work as somebody who was never supposed to have it."

> **Pause point.** Stop the clip. You have a user who can prove who they are and do nothing.

---

## Demo 2 -- Two objects, never one

### 9

```bash
kubectl config current-context
```

`cka-vagrant`

**Say:** "Context check before I create anything. I'm the admin again, and I have to be, because frontend-dev can't create a Role. That's the whole reason this module exists."

### 10

```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n dev-team
```

`role.rbac.authorization.k8s.io/pod-reader created`

**Say:** "Three flags is the whole command: verbs, resource, namespace. Type it until it's muscle memory, because you'll type it under a timer."

### 11

```bash
kubectl describe role pod-reader -n dev-team
```

PolicyRule table. **Resource Names is blank.** Verbs `[get list watch]`.

**Say:** "And look at that empty Resource Names column -- blank means all Pods here. Pass `--resource-name=web-1` and the rule reaches exactly one Pod. Right now this Role is attached to nobody. It grants nothing to anyone."

### 12

```bash
kubectl create rolebinding frontend-dev-reads --role=pod-reader --user=frontend-dev -n dev-team
```

`rolebinding.rbac.authorization.k8s.io/frontend-dev-reads created`

**Say:** "Then the binding, which is the half that actually grants. Two objects, never one. The Role says **what**, the binding says **who**, and 'I created the Role and it still doesn't work' is the number one RBAC ticket on earth."

### 13

```bash
kubectl config use-context frontend-dev
```

`Switched to context "frontend-dev".`

**Say:** "Back to being frontend-dev. Same certificate, same user, nothing about the credential changed."

### 14

```bash
kubectl get pods -n dev-team
```

`No resources found in dev-team namespace.`

**Say:** "Watch. I haven't touched the certificate. Same user, same command, and this is the exact thing that threw a 403 ninety seconds ago. **No resources found is a success.** That's the API server saying yes, you're allowed, and the namespace is empty. A 403 looks nothing like this. One RoleBinding turned a refusal into an answer."

### 15

```bash
kubectl delete pod web-1 -n dev-team
```

Forbidden. **A 403, not a 404** -- and `web-1` doesn't exist.

**Say:** "And here's the other half of the lesson. I granted get, list, and watch. I didn't grant delete. So the write comes back Forbidden, and that isn't a bug to go fix, that's the grant being **exactly as narrow as I designed it.** Now look closely at that error, because there's a free lesson in it. There is no Pod called web-1 in this namespace. I still got a **403, not a 404.** The API server authorizes your request *before* it ever goes looking for the object, which means a Forbidden tells you nothing about whether the thing exists. Handy on the exam, and handy at 2am."

### 16

```bash
kubectl create deployment nginx --image=nginx -n dev-team
```

Forbidden, second of three.

**Say:** "Same wall, different verb. Create isn't in the grant either."

### 17

```bash
kubectl get secrets -n dev-team
```

Forbidden, third of three.

**Say:** "Secrets, same 403, different reason: nothing in pod-reader mentions Secrets at all."

### 18

```bash
kubectl config use-context cka-vagrant
```

`Switched to context "cka-vagrant".`

**Say:** "Hand it back, and now let me show you the version you'll actually use at work."

### 19

```bash
kubectl auth can-i list   pods -n dev-team --as frontend-dev
```

`yes`

**Say:** "`can-i --as` is your RBAC unit test. You run this **before** a developer hits a 403 and files a ticket, and you never have to become them to find out."

### 20

```bash
kubectl auth can-i delete pods -n dev-team --as frontend-dev
```

`no`

**Say:** "Same question, different verb, and the answer is no. Two commands and I've mapped the boundary of that grant without touching a certificate."

### 21

```bash
kubectl auth can-i --list      -n dev-team --as frontend-dev
```

A rules table.

**Say:** "`--list` is the one to memorize. It dumps every rule that applies to that subject, which turns 'why can't they do the thing' from guesswork into reading."

**Exam tip:** "Classic trap. Binding to a ServiceAccount is `--serviceaccount=namespace:name`, **never** `--user`. Pass `--user=my-sa` and the command succeeds, the binding gets created, and the grant does nothing -- because a ServiceAccount's real username is `system:serviceaccount:namespace:name`. Green output, zero permission."

> **Pause point.** Strongest beat in the module. Give it room.

---

## Demo 3 -- The binding sets the scope

### 22

```bash
kubectl config current-context
```

`cka-vagrant`

**Say:** "Admin again. Everything in this demo is a binding change, and only the admin gets to make one."

### 23

```bash
kubectl create rolebinding view-in-dev-team --clusterrole=view --user=frontend-dev -n dev-team
```

`rolebinding.rbac.authorization.k8s.io/view-in-dev-team created`

**Say:** "I'm changing exactly one variable. Same user, same ClusterRole, same three questions. The only difference is the kind of binding object. And note the flag -- `--clusterrole`, not `--role`. I'm reaching for a ClusterRole that already ships with Kubernetes and attaching it with a namespaced binding. That combination is the most useful pattern in RBAC: reuse one ClusterRole across many teams, let each team's RoleBinding decide where it applies."

### 24

```bash
kubectl config use-context frontend-dev
```

`Switched to context "frontend-dev".`

**Say:** "Become the user again. Three questions coming, and I want you to remember the answers, because I'm going to ask the identical three in a minute."

### 25

```bash
kubectl get configmaps -n dev-team
```

Allowed.

**Say:** "Question one. ConfigMaps in dev-team, and that works."

### 26

```bash
kubectl get configmaps -n kube-system
```

Forbidden.

**Say:** "Question two. Same resource, different namespace, and it's a no."

### 27

```bash
kubectl get namespaces
```

Forbidden.

**Say:** "Question three. A cluster-scoped object, and it's a no as well. Allow, deny, deny -- hold onto that."

### 28

```bash
kubectl config use-context cka-vagrant
```

`Switched to context "cka-vagrant".`

**Say:** "ConfigMaps, not Pods -- pod-reader never mentioned ConfigMaps, so that first result came from `view`. Then two refusals. **A RoleBinding is a fence,** and it doesn't care that `view` is a ClusterRole. The binding lives in dev-team, so the grant stops there. And a namespaced binding can't reach a cluster-scoped object like Namespaces with any role, ever."

### 29

```bash
kubectl create clusterrolebinding frontend-dev-views-all --clusterrole=view --user=frontend-dev
```

`clusterrolebinding.rbac.authorization.k8s.io/frontend-dev-views-all created`

**Say:** "Same ClusterRole by name. I'm not editing it, I'm not copying it, I haven't written a single rule. One new binding object -- and no `-n` flag, because a ClusterRoleBinding has no namespace of its own."

### 30

```bash
kubectl config use-context frontend-dev
```

`Switched to context "frontend-dev".`

**Say:** "Same user, one more time. Same certificate. Watch what moves."

### 31

```bash
kubectl get configmaps -n dev-team
```

Allowed.

**Say:** "Question one, again, and it still works."

### 32

```bash
kubectl get configmaps -n kube-system
```

**Allowed now.**

**Say:** "Question two, and here's the change. That was a Forbidden thirty seconds ago."

### 33

```bash
kubectl get namespaces
```

**Allowed now.**

**Say:** "Question three, and the cluster-scoped object answers too. Allow, allow, allow."

### 34

```bash
kubectl config use-context cka-vagrant
```

`Switched to context "cka-vagrant".`

**Say:** "Nothing about the permissions changed. The **reach** changed. Say it with me: **the role says what, the binding says where.**"

**Exam tip:** "This is the decision tree for basically every RBAC question on the exam. Does the task name a namespace? RoleBinding. Does it say 'in all namespaces,' or name a cluster-scoped object like Nodes or PersistentVolumes? ClusterRoleBinding. One question, and you've picked the right object. And a ClusterRoleBinding is the one you get wrong at two in the morning -- it applies in every namespace that exists today **and** every one anybody creates next year, and nothing about the object reminds you. Reach for a RoleBinding first, every time."

> **Pause point.** Highest-yield concept in the module.

---

## Demo 4 -- The built-ins, and generating instead of memorizing

### 35

```bash
kubectl config current-context
```

`cka-vagrant`

**Say:** "Admin, last time. And this demo is the one that saves you writing a Role you never needed."

### 36

```bash
kubectl get clusterrole view edit admin cluster-admin
```

Four rows.

**Say:** "Four ClusterRoles ship with every cluster and they cover most of what anybody asks you for. `view` reads. `edit` reads and writes workloads. `admin` does both plus manages RBAC inside a namespace. `cluster-admin` does everything, everywhere. Before you write a Role, check whether one of these already is the answer."

### 37

```bash
kubectl describe clusterrole view | grep -i secret || echo "NO secrets rule in view"
```

`NO secrets rule in view`

**Say:** "And this is the one I want to prove rather than assert. Grep `view` for Secrets and nothing comes back."

### 38

```bash
kubectl describe clusterrole edit | grep -i '^  secrets'
```

A `secrets` row with write verbs on it.

**Say:** "Here it is, the fact people miss. `view` never reads Secrets -- no rule, nothing. `edit` reads them **and writes them.** So 'read-only' and 'safe' aren't the same sentence. If an exam question hands you a user who shouldn't see credentials and offers `edit`, that's the trap."

**Also worth 15 seconds, no command:** "`edit` and `view` don't carry a hardcoded list of rules. They carry an aggregationRule, a label selector, and the control plane fills the rules in. That's how installing a CRD can silently widen what `edit` covers. You don't need to build one for the exam, you need to recognize it."

### 39

```bash
kubectl create role pod-reader --verb=get,list,watch --resource=pods --dry-run=client -o yaml
```

A Role manifest on stdout. **Nothing was created.**

**Say:** "That command created nothing. `--dry-run=client` means kubectl built the object in memory, printed it, and never touched the API server. So: built-ins first, and remember `edit` reads Secrets. When they don't fit, don't write YAML from memory -- run the imperative command with `--dry-run=client -o yaml`, redirect it to a file, edit the two lines that matter. That habit is worth minutes on the exam."

**Exam tip:** "`can-i --list` and `--dry-run=client -o yaml` are the two to have loaded before you sit down. One tells you what a subject can already do, the other writes the object you're about to create. Between them you'll answer most RBAC tasks without opening the docs -- and that saved time goes to the questions that are actually hard."

---

## Close -- slides 24 and 25

Deliver the module takeaways off the deck, then the bookend:

**Say:** "Checking out with Globomantics. Priya's engineers don't hold cluster-admin any more, and nobody's going to delete the production namespace by accident again. Two objects, never one. The role says what, the binding says where. And you prove it with `can-i --as` before anybody files a ticket."

---

## Wrap

**39 commands.** Reset for the next take:

```bash
./lab.sh reset
```
