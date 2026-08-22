# CKA C04 M02 -- Service Accounts and Least-Privilege Access

**28 commands, four demos, about 9:15 on camera.**

Read the italic setup line, run the command, look at the output, then read the **Say**.

---

## Before you roll

```bash
ssh vagrant@192.168.50.10        # password: vagrant
cd ~/m02
./lab.sh reset                   # wait for READY FOR TAKE
```

**Between takes:** `./lab.sh reset`
**Steps 22, 24, 25 and 28 are supposed to error.** Those refusals are the lesson.

---

# Demo 1 -- An account of its own

### 1
*Before I create anything, I want to see which cluster I'm on and which identity I'm about to create it as.*
```bash
kubectl config get-contexts
```
Star on `cka-vagrant`.

**Say:** "Every demo opens here. A context is a cluster, a user, and a default namespace, and on the exam every task starts by telling you which cluster to be on."

### 2
*A ServiceAccount and a Role both live inside a namespace, so the namespace has to exist before either one can.*
```bash
kubectl create namespace staging
```
`namespace/staging created`

**Say:** "Module 1 built a human out of a certificate. This one builds a workload identity, and it starts the same way."

### 3
*Now the identity itself, and watch how little there is to it. No password, no key, just a name in a namespace.*
```bash
kubectl create sa deploy-bot -n staging
```
`serviceaccount/deploy-bot created`

**Say:** "That's the whole creation step. A namespaced object with a name, and the name is what RBAC binds to."

### 4
*Here's the question anybody who learned this before 1.24 will ask -- where's the token Secret? Let me ask the account itself.*
```bash
kubectl get sa deploy-bot -n staging -o jsonpath='{.secrets}'; echo "  <- empty"
```
An empty value, then `  <- empty`

**Say:** "Look at that. Empty."

### 5
*And let me prove it isn't hiding somewhere else in the namespace either.*
```bash
kubectl get secrets -n staging
```
`No resources found in staging namespace.`

**Say:** "Empty, and no Secrets in the namespace at all. Before Kubernetes 1.24, creating a ServiceAccount got you a Secret holding a token that never expired -- and read access on that Secret was a working credential, forever. That auto-generation stopped in 1.24, and no switch brings it back. So where does the token come from now? That's Demo 2."

### 6
*A binding needs something to bind, so first a Role, and I'm keeping it narrow enough that I can justify every verb in it.*
```bash
kubectl create role deployer \
  --verb=create,update,get,list \
  --resource=deployments,services -n staging
```
`role.rbac.authorization.k8s.io/deployer created`

**Say:** "Four verbs, two resources, one namespace. No delete, no Secrets, and I can tell you why each one is missing."

**Exam tip:** "An empty `apiGroups` value means the **core** group, so Pods and Services and ConfigMaps live there -- but Deployments don't. Deployments are in `apps`, and `kubectl create role --resource=deployments` fills that in for you. Hand-write the YAML and forget it, and you get a Role that looks right and grants nothing."

### 7
*Now the half that actually grants, because that Role has been sitting there doing nothing for a minute.*
```bash
kubectl create rolebinding deploy-bot-deployer \
  --role=deployer \
  --serviceaccount=staging:deploy-bot -n staging
```
`rolebinding.rbac.authorization.k8s.io/deploy-bot-deployer created`

**Say:** "This is the flag worth memorizing: `--serviceaccount`, and it takes **namespace colon name**, not the bare name. And here's the trap -- if you reach for `--user=deploy-bot` instead, the command succeeds, the binding gets created, and the grant does absolutely nothing. Green output, zero permission. Because the real username of a ServiceAccount is `system:serviceaccount:staging:deploy-bot`, and `--user` takes you literally."

### 8
*Let me read the binding back, because how the subject gets stored is what explains the trap I'm about to show you.*
```bash
kubectl describe rolebinding deploy-bot-deployer -n staging
```
`Kind: ServiceAccount`, `Name: deploy-bot`, `Namespace: staging`

**Say:** "Three fields. The API server reassembles them into that `system:serviceaccount` username when it authorizes a request."

**Exam tip:** "Order of operations, and the tasks leave one out on purpose. ServiceAccount, then Role, then RoleBinding, then the Pod. Submit the Pod first and the API server refuses it outright -- unlike a RoleBinding aimed at a Role that doesn't exist yet, which is accepted and simply grants nothing until the Role shows up."

> **Pause point.**

---

# Demo 2 -- Prove the grant, then read the credential

### 9
*New demo, same first keystroke. I'm about to impersonate a ServiceAccount, and impersonation is itself a permission, so I need to be somebody who holds it.*
```bash
kubectl config current-context
```
`cka-vagrant`

**Say:** "Still the admin, and I have to be."

### 10
*Let me test this grant before any Pod exists at all. You want to find a missing permission before a developer does.*
```bash
kubectl auth can-i create deployments -n staging \
  --as system:serviceaccount:staging:deploy-bot
```
`yes`

**Say:** "I'm testing the grant before a Pod exists, and that's the habit worth building. The subject is `system:serviceaccount:staging:deploy-bot` -- namespace and name, with a prefix."

### 11
*Now the direction people skip. Over-permission is the failure nobody files a ticket about.*
```bash
kubectl auth can-i create secrets -n staging \
  --as system:serviceaccount:staging:deploy-bot
```
`no`

**Say:** "Deployments, yes. Secrets, no, because the Role never mentioned them."

### 12
*And here's the one command that replaces all the guessing.*
```bash
kubectl auth can-i --list -n staging \
  --as system:serviceaccount:staging:deploy-bot
```
A rules table.

**Say:** "`--list` dumps everything that subject can do in there, which turns 'why is my pipeline Forbidden' from guesswork into reading."

### 13
*Now the Pod that claims this identity, and I want you to notice how little I had to write to do it.*
```bash
kubectl apply -f deploy-runner.yaml -n staging
```
`pod/deploy-runner created`

**Say:** "One line in that spec, `serviceAccountName`. That's the whole handshake between a workload and an identity."

### 14
*Give it a second. The next three commands run inside that container, so it has to actually be up.*
```bash
kubectl wait --for=condition=Ready pod/deploy-runner -n staging --timeout=90s
```
`pod/deploy-runner condition met`

**If it breaks:** `kubectl describe pod deploy-runner -n staging` and read the events. An image pull on a fresh node is the usual cause, not RBAC.

### 15
*Let's go inside and see what the kubelet actually handed this container.*
```bash
kubectl exec -n staging deploy-runner -- ls -1 /var/run/secrets/kubernetes.io/serviceaccount/
```
Exactly three names: `ca.crt`, `namespace`, `token`

**Say:** "Three files. **token is who I am, ca.crt is who I trust, namespace is where I live.** And notice what's missing -- there's no Secret object anywhere in this namespace. The kubelet asked the TokenRequest API for this token and wrote it straight into the Pod. Nothing to read, nothing to leak, nothing sitting in etcd waiting to be found."

### 16
*One of those three files is plain text, so let's just read it.*
```bash
kubectl exec -n staging deploy-runner -- cat /var/run/secrets/kubernetes.io/serviceaccount/namespace; echo
```
`staging`

**Say:** "That's how a well-written client knows which namespace it's in without being told."

### 17
*Here's the sleight of hand. I never declared a volume in that YAML, so let's find out who did, and read the number carefully.*
```bash
kubectl get pod deploy-runner -n staging \
  -o jsonpath='{range .spec.volumes[*]}{.projected.sources[*].serviceAccountToken.expirationSeconds}{end}'; echo
```
`3607`

**Say:** "Now open `deploy-runner.yaml` in your head. Did I declare a volume? No. I set one line, `serviceAccountName`. That projected volume was added by the **ServiceAccount admission controller** in the API server, and the kubelet is what fills it. Two different components, and people blur them. And look at the number -- **3607** seconds. Everybody expects thirty-six hundred. You can't tune it, so if you need a different lifetime you write your own projection."

> **Pause point.** Strongest beat in the module.

---

# Demo 3 -- Decode the claims, mint on demand

### 18
*Third demo, and this one only reads. I still pin the context, because a read against the wrong cluster burns the same exam clock as a write.*
```bash
kubectl config current-context
```
`cka-vagrant`

### 19
*One filename here is mine, not Kubernetes. Before I use it, let me show you exactly what `lab.sh` is.*
```bash
head -n 8 lab.sh
```
The header lists the `reset`, `jwt`, and `verify` modes.

**Say:** "`lab.sh` is my course helper. It isn't a Kubernetes command, and it won't be on the exam. `reset` restores frame zero, `verify` checks the expected allows and denies, and `jwt` uses `kubectl exec` plus coreutils to decode the mounted token. Convenience, not magic."

### 20
*We've proved the token file exists. Now the helper reads it from the running Pod and prints the claims the API server checks.*
```bash
./lab.sh jwt
```
`sub` = `system:serviceaccount:staging:deploy-bot`, plus `aud`, `iss`, `exp`, a `warnafter` about 60 minutes out, and a `kubernetes.io` block naming the namespace, ServiceAccount, Pod, and node

**Say:** "`sub` is the username on the wire -- the exact string we tested with `--as`. Now look at `exp`. The volume asked for 3607 seconds, but expiry is roughly a year out. The API server extends injected tokens, while `warnafter` marks roughly one hour. **Rotation**, not that distant expiry, limits the exposure. The kubelet refreshes the file after eighty percent of the requested lifetime, or twenty-four hours, whichever comes first. Your application must reread the file. Cache it once at startup and you've built a time bomb."

**If it breaks:** the Demo 2 Pod isn't running. `kubectl get pod -n staging`

### 21
*That token belongs to a Pod. When there is no Pod -- a CI job, a test, or you at a terminal -- mint one on demand.*
```bash
kubectl create token deploy-bot -n staging --duration=10m
```
A JWT printed to stdout. Nothing stored.

**Say:** "`kubectl create token` calls the same TokenRequest API and prints a short-lived credential. Nothing is stored as a Secret. I asked for ten minutes, not five. Watch."

### 22
*Now I ask for five minutes and let the API server show us the floor.*
```bash
kubectl create token deploy-bot -n staging --duration=5m
```
Fails: `may not specify a duration less than 10 minutes`

**Say:** "Ten minutes is this API server's floor. `--audience` limits who may accept the token. `--bound-object-kind` ties it to a Pod, Node, or Secret, so deleting that object invalidates the token with it."

**Exam tip:** "After Kubernetes 1.24, the answer is `kubectl create token`, not creating a legacy token Secret. If you're hand-writing a Secret of type `kubernetes.io/service-account-token`, you're on the last-resort path."

> **Pause point.**

---

# Demo 4 -- Break it, then take the credential away

### 23
*Last demo. Things break on purpose, so I pin the context before I blame Kubernetes.*
```bash
kubectl config current-context
```
`cka-vagrant`

### 24
*This Pod names a ServiceAccount that doesn't exist. The error tells us exactly how far the request got.*
```bash
kubectl apply -f ghost-sa.yaml
```
```
Error from server (Forbidden): error when creating "ghost-sa.yaml": pods "ghost-runner" is forbidden: error looking up service account staging/does-not-exist: serviceaccount "does-not-exist" not found
```

**Say:** "Read the reason: **error looking up service account**. Admission rejected the request inside the API server -- before scheduling, and before any kubelet was involved."

### 25
*Now let's prove admission never persisted the Pod.*
```bash
kubectl get pod ghost-runner -n staging
```
`Error from server (NotFound)`

**Say:** "No Pod exists to describe. `CreateContainerConfigError` is a kubelet-stage failure for a missing dependency such as a ConfigMap or Secret. This request died earlier at admission. If a Deployment submitted it, look for `FailedCreate` on the ReplicaSet."

### 26
*One last idea. This workload never calls the API server, so it has no business carrying a credential.*
```bash
kubectl apply -f no-automount.yaml
```
`pod/quiet-runner created`

### 27
*The Pod still runs. Removing the credential does not remove the workload.*
```bash
kubectl wait --for=condition=Ready pod/quiet-runner -n staging --timeout=90s
```
`pod/quiet-runner condition met`

### 28
*Same path as before. This time it should not exist.*
```bash
kubectl exec -n staging quiet-runner -- ls /var/run/secrets/kubernetes.io/serviceaccount/
```
Fails: **no such file or directory**

**Say:** "Least privilege has a floor below a narrow Role: **no credential at all**. `automountServiceAccountToken: false` removes the projected volume, so the path is gone. Field placement is exam bait: top level on a ServiceAccount, under `spec` on a Pod. If both set it, **the Pod wins.**"

**Exam tip:** "If a workload never calls the API server, set false on the ServiceAccount so every Pod inherits it. Override only the Pod that needs a token. The Pod setting wins."

> **Pause point.** Demos done. Cut back to slides 23 and 24.

---

# Close -- slides 23 and 24

Deliver the module takeaways, then hand off to admission control:

**Say:** "Checking out with Globomantics. Priya's pipeline no longer runs as cluster-admin. One ServiceAccount, one narrow Role, one binding, and one line on the Pod. We proved the grant before the Pod existed, read the projected credential, and saw why rotation matters. A missing ServiceAccount died at admission, and a quiet workload got no token at all. One gap remains: RBAC can authorize a Pod that runs as root or claims every core. Authorization said yes; nobody inspected the object. That's admission control, and that's where we're going next."

---

# Wrap

**28 commands.** Reset for the next take:

```bash
./lab.sh reset
```
