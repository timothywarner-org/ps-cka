# CKA Course 2 / Module 2 — Bootstrapping a Cluster with kubeadm init and join

**Target runtime:** 12-14 min on camera
**Environment:** Admin pwsh 7 on Windows 11 → `vagrant ssh control1` (Ubuntu 22.04)
**Lab:** **Hyper-V + Vagrant** — `src/cka-lab` with control1, worker1, worker2 on `192.168.50.10/.11/.12`
**Starting state:** `post-prereqs` snapshot from Module 1 (every prerequisite verified, zero cluster state).
**Authoritative command source:** Deck slides 9 (declarative `init.yaml`), 13 (`kubeadm token create --print-join-command`), 15 (`mkdir/cp/chown` for kubectl).
**Validator:** Module 2 ends with the cluster validation built into the kubeadm output plus `kubectl get nodes` / `kubectl get pods -n kube-system`. The cross-node CNI validation lives in Module 3.
**Cleanup between takes:** `cka-restore.ps1 post-prereqs` rewinds in 60-90 sec. Snapshot to `post-init-join` at the end so Module 3 starts from a known-good baseline.

> **Declarative-first, not flag-soup.** Module 1 verified the host state; Module 2 generates an `init.yaml`, edits four lines, and runs `kubeadm init --config init.yaml`. Slide 9 is the canonical command source. Flag-based init still works, but the v1.35 CKA curriculum expects the declarative path, and so does HA later in Course 3.

> **Lab path reminder:** This module uses the **Vagrant / Hyper-V** lab. The `cka-*.ps1` scripts (`cka-up`, `cka-status`, `cka-validate`, `cka-snapshot`, `cka-restore`, `cka-info`) are the Vagrant entry points. The `kind-*.ps1` scripts are for Course 1 only.

> **Course 2 design principle:** No `Start-TutorialMXX` wrapper. You type every command on the real Linux shell. That is the pedagogical bet for this whole course.

---

## Slide-to-demo map (glance here mid-take to stay on pace)

| Slides | Block | What you're teaching | Time |
|---|---|---|---|
| 1-3 | Open + Globomantics frame | Module 1 recap, four framing questions, Diana's pod-network-cidr warning | ~75 sec |
| 4-6 | LO 1 → **Demo 1** (seed and edit `init.yaml`) | What kubeadm init will create, on a real config file | ~2 min |
| 7-10 | LO 2 → **Demo 2** (`kubeadm init --config` + read a manifest) | Four flags that matter, declarative config, HA-ready controlPlaneEndpoint, reading static pod manifests for troubleshooting | ~3-4 min |
| 11-13 | LO 3 → **Demo 3** (join workers) | Bootstrap token + CA-hash, regenerate the join command | ~2-3 min |
| 14-15 | LO 4 → **Demo 4** (kubectl + post-init state) | Copy admin.conf, verify NotReady is expected | ~2 min |
| 16 | Demo transition | "Time to put it into practice" | 10 sec |
| 17 | Globomantics checkout | Diana signs off — three nodes joined, NotReady is correct | ~30 sec |
| 18-20 | From Globomantics to you + next module | Four takeaways → Module 3 (CNI) | ~45 sec |

---

## Pre-flight (run these BEFORE hitting record)

**Run from admin pwsh 7 on Windows.** Every line is a literal command. Type or paste in order.

### Step 0 — Open admin pwsh and `cd` to the lab

```powershell
cd C:\github\ps-cka\src\cka-lab
```

### Step 1 — Restore the Module 1 finish line

```powershell
.\cka-restore.ps1 post-prereqs
```

Atomic restore across all three VMs. ~60-90 sec. **Every recording of M2 starts from this exact state.** No drift, no surprises.

### Step 2 — Confirm VM state + prereqs are still clean

```powershell
.\cka-status.ps1
.\cka-validate.ps1
```

**Must end with:** `ALL NODES READY — safe to snapshot or run kubeadm init on control1`. If it doesn't, the M1 snapshot is bad — rebuild before continuing.

### Step 3 — Snapshot the pre-record state

```powershell
.\cka-snapshot.ps1 pre-record-m2
```

Take this every recording session. A failed take = `.\cka-restore.ps1 pre-record-m2` in ~60-90 sec.

### Step 4 — Dry-run the demo OFF camera

```powershell
vagrant ssh control1
```

Inside the VM, walk Demos 1-4. Confirm muscle memory. Then `exit` twice to get back to admin pwsh, then `.\cka-restore.ps1 pre-record-m2` to rewind.

### Camera checklist (final scan before recording)

- [ ] Admin pwsh, font 16pt+, 140 cols wide, prompt trimmed
- [ ] `.\cka-info.ps1` shows all 3 nodes **UP** with their `.10/.11/.12` IPs
- [ ] No leftover Kubernetes state (`vagrant ssh control1` → `ls /etc/kubernetes/` should be empty or absent — if not, restore again)
- [ ] Only one terminal window visible — no chat apps, no notifications
- [ ] Screen recorder set to 1080p, no HiDPI blur, no taskbar
- [ ] Deck slide 9 (the declarative `init.yaml` walk) open on second monitor

---

## Click path (the exact ENTER sequence — high level)

1. `vagrant ssh control1` → ENTER → land at `vagrant@control1:~$`
2. `sudo -i` → ENTER → root prompt
3. **Demo 1** — seed and edit `init.yaml` (four lines)
4. **Demo 2** — `kubeadm init --config init.yaml --upload-certs` (watch output); `ls /etc/kubernetes/{pki,manifests}/`; `cat /etc/kubernetes/manifests/kube-apiserver.yaml | head -30`
5. **Demo 4 first half** — `mkdir/cp/chown` for `~/.kube/config`, run `kubectl get nodes` (NotReady, expected)
6. **Demo 3a** — `kubeadm token create --print-join-command` (regenerate join command for camera) → copy to clipboard
7. `exit` → `exit` → back to admin pwsh
8. `vagrant ssh worker1` → `sudo kubeadm join ...` → wait for success → `exit`
9. `vagrant ssh worker2` → `sudo kubeadm join ...` → wait for success → `exit`
10. `vagrant ssh control1` → `kubectl get nodes` (three nodes, all NotReady) → `kubectl get pods -n kube-system`
11. `exit` → `exit` → `.\cka-snapshot.ps1 post-init-join`

**Total ENTERs:** ~30 across the whole module. Slow is smooth, smooth is fast.

**Why root for the demo:** kubeadm init writes to `/etc/kubernetes/` and reads `/etc/containerd/config.toml`. Constantly prefixing `sudo` adds visual noise. Open with: **"I'm going to `sudo -i` to keep the commands clean — in production you'd `sudo` each step."**

**Pedagogical frame for the open:** "Module 1 verified every prerequisite. The VMs are exam-clean. Now we bootstrap. The CKA exam tests `kubeadm init` and `kubeadm join` directly — under time pressure — and the difference between a calm three-minute exercise and a panicked twenty-minute scramble is which lines you have memorized."

---

## Open — slides 1-3 (~75 sec)

**Verbatim talk track:**

> "Three Ubuntu VMs, every prerequisite verified, the kubelet crashlooping on every node — which is correct, because there's no `kubeadm init` yet to give it a config to read. Diana from Globomantics has the warning that costs more candidates their question on this domain than any other: **`--pod-network-cidr` has to match the CNI you'll install later.** Calico's default is `192.168.0.0/16`. Use `10.244.0.0/16` here — Flannel's default — and install Calico anyway, and pods get IPs but cannot route across nodes. The remediation is `kubeadm reset` on every node and start over. So let's get it right the first time."

**Slide 2 — Four framing questions:** read each beat-by-beat, don't pre-answer.
**Slide 3 — Globomantics check-in:** read Diana's quote in character. Senior SRE. The pod-network-cidr warning lands hardest.

---

## Demo 1 — Seed and edit `init.yaml` (2 min)

**Goal:** Generate the kubeadm v1beta4 InitConfiguration template, edit four lines, save. **The four lines are the entire game.**

### Step 1.1 — Confirm you're at the root prompt on control1

```bash
hostname && whoami
```

Expected: `control1` and `root`. If you see `vagrant`, you skipped `sudo -i`.

### Step 1.2 — Seed the declarative init config

```bash
kubeadm config print init-defaults > init.yaml
```

**Windows lens:** `init-defaults` emits a YAML template — the closest Windows analog is `Export-DscConfiguration` printing a DSC document, or `New-AzConfig` stubbing out an ARM template. You edit the template; you do not memorize nineteen command-line flags.

**Narrate:** "One command, one file. That file is `init.yaml` — kubeadm's declarative configuration. Every flag you'd pass on the command line has a YAML equivalent in here, and the exam-day move is editing the file rather than typing a thirty-character flag list."

### Step 1.3 — Edit the four lines that matter (vim on camera)

```bash
vim init.yaml
```

**Why vim:** it's the editor preinstalled on every CKA exam VM. No mouse, no menus, pure keyboard. If your muscle memory is solid, four edits take 30 seconds. If it isn't, you panic on exam day. **Teach the panic away here.**

**The four edits aren't all the same kind of edit.** That's the key insight. The defaults file already contains some of these keys and is missing others, so each edit has its own keystroke recipe.

| # | Key | In the defaults? | Vim move |
|---|---|---|---|
| 1 | `advertiseAddress` | Yes (placeholder `1.2.3.4`) | Search, `C`, retype |
| 2 | `podSubnet` | No | Search anchor, `o`, type new line |
| 3 | `controlPlaneEndpoint` | No | Search anchor, `o`, type new line |
| 4 | `apiServer` (empty `{}`) | Yes (as flow-style empty map) | Search, `cc`, type 5 lines |

**Optional cosmetic - turn on line numbers so viewers can follow:**

```text
:set number   ⏎
```

#### Edit 1 - Change `advertiseAddress` value

The defaults emit a placeholder `1.2.3.4`. Swap it for the lab's control-plane IP.

**Before:**

```yaml
  advertiseAddress: 1.2.3.4
```

**Keystrokes:**

```text
/1.2.3.4    ⏎     " jump cursor to the value
C                  " kill from cursor to end of line, enter insert mode
192.168.50.10      " type the new value
Esc                " back to command mode
```

**After:**

```yaml
  advertiseAddress: 192.168.50.10
```

#### Edit 2 - Add `podSubnet` under `networking:`

`podSubnet` is not in the defaults. Add it as a third key inside the existing `networking:` block.

**Before:**

```yaml
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
```

**Keystrokes:**

```text
/serviceSubnet    ⏎             " anchor inside the networking block
o                                " open new line BELOW, insert mode
  podSubnet: 192.168.0.0/16      " two-space indent - type the leading spaces literally
Esc
```

**After:**

```yaml
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 192.168.0.0/16
```

#### Edit 3 - Add `controlPlaneEndpoint` at top level

Also not in the defaults. Add as a sibling of `clusterName` in the **second** YAML document (the `ClusterConfiguration` block that follows the `---` separator).

**Before:**

```yaml
clusterName: kubernetes
```

**Keystrokes:**

```text
/clusterName    ⏎                                    " anchor in ClusterConfiguration
o                                                     " open new line BELOW
controlPlaneEndpoint: k8s.globomantics.local:6443     " top-level - NO leading spaces
Esc
```

**After:**

```yaml
clusterName: kubernetes
controlPlaneEndpoint: k8s.globomantics.local:6443
```

#### Edit 4 - Replace `apiServer: {}` with the SAN-pinning block

The defaults render `apiServer:` as the flow-style empty map `{}`. Replace that line with five lines that pin the certificate SANs.

**Before:**

```yaml
apiServer: {}
```

**Keystrokes (toggle paste mode first to suppress YAML autoindent surprises):**

```text
:set paste   ⏎                  " turn off autoindent for clean multi-line entry
/apiServer:   ⏎                  " jump to the empty-map line
cc                                " wipe the whole line, enter insert mode at column 0
apiServer:                        " type line 1, press ⏎
  certSANs:                       " line 2 - two leading spaces, press ⏎
    - k8s.globomantics.local      " line 3 - four leading spaces, press ⏎
    - 192.168.50.10               " line 4 - four leading spaces, press ⏎
    - 10.96.0.1                   " line 5 - four leading spaces
Esc
:set nopaste   ⏎                 " restore normal vim behavior
```

**After:**

```yaml
apiServer:
  certSANs:
    - k8s.globomantics.local
    - 192.168.50.10
    - 10.96.0.1
```

#### Save and verify

```text
:wq   ⏎
```

If anything went sideways, abandon and redo Step 1.2:

```text
:q!   ⏎
```

**Back at the shell, confirm all four edits landed in one grep:**

```bash
grep -E "advertiseAddress|podSubnet|controlPlaneEndpoint|certSANs" init.yaml
```

**Expected (four matching lines, in this order):**

```text
  advertiseAddress: 192.168.50.10
  podSubnet: 192.168.0.0/16
controlPlaneEndpoint: k8s.globomantics.local:6443
  certSANs:
```

If a line is missing or wrong, `vim init.yaml` and fix it. If multiple are wrong, faster to `rm init.yaml` and re-run Step 1.2 cleanly.

---

**Vim exam-survival kit:** `i` insert · `Esc` command · `/` search · `o` open line below · `:wq` save+quit · `:q!` abandon ship. Tattoo those six. The demo uses `C` (change to end of line) and `cc` (change whole line) as speed boosters - useful, not required.

**Windows lens:** YAML's indentation is the structure (the same way PowerShell's hashtables are structured by braces, but YAML uses whitespace). Two-space indents only, tabs break the parser silently.

**Narrate, slow down on `controlPlaneEndpoint`:** "**This is the most important line.** Today this DNS name resolves to `192.168.50.10`. Tomorrow in Course 3 it resolves to HAProxy fronting three control-plane nodes. Setting it now writes it into every certificate's SAN list. Skipping it now means HA later is a five-hour certificate reissue. Ten seconds today saves you thirty minutes in Course 3."

### Step 1.4 — Confirm `/etc/hosts` resolves the controlPlaneEndpoint

```bash
grep globomantics /etc/hosts
```

**Expected:** `192.168.50.10 k8s.globomantics.local control1` (the Vagrantfile's `hosts-file` provisioner already wrote this on all three VMs).

**Narrate:** "If `controlPlaneEndpoint` doesn't resolve on the workers, `kubeadm join` fails with 'connection refused.' The Vagrantfile pre-staged `/etc/hosts` entries on all three VMs so the DNS name resolves locally. In real production this is where you'd point at internal DNS or a managed load balancer."

### Demo 1 money shot (verbatim — say this)

> "Four lines in a YAML file. `localAPIEndpoint.advertiseAddress`, `networking.podSubnet`, `controlPlaneEndpoint`, `apiServer.certSANs`. That is the entire declarative bootstrap. If you can't write those four from memory, the exam will eat you alive on the cluster-creation question."

---

## Demo 2 — Run `kubeadm init` (3-4 min)

**Goal:** Bootstrap the control plane and walk the kubeadm output as it scrolls.

### Step 2.1 — Run `kubeadm init` with the declarative config

```bash
kubeadm init --config init.yaml --upload-certs
```

**Why `--upload-certs`:** stores the control-plane TLS material in the `kubeadm-certs` Secret in `kube-system` with a 2-hour TTL, so additional control-plane nodes can join later in Course 3 without you scp'ing certs by hand. Harmless on a single-CP bootstrap.

**Windows lens:** think of `--upload-certs` as pre-staging a PFX into a shared Group Policy distribution point rather than walking the .pfx to every domain controller over RDP. Same intent, automated key delivery.

**What to show on camera as it scrolls (30-60 sec total):**

- **Preflight checks** pass (this is where Module 1's work pays off — every check is green)
- **Certificate generation** — CA, then API server, then etcd, then kubelet, then scheduler, controller-manager
- **Static pod manifests written** to `/etc/kubernetes/manifests/`
- **Kubelet started** (the crashloop ends here — it finally has a config to read)
- **"Your Kubernetes control-plane has initialized successfully!"** banner
- **The join command** at the bottom — copy it to clipboard but **don't trust the scrollback to keep it**

**Narrate as it runs:** "Preflight checks pass instantly, that's Module 1's work. CA gets generated, then every other certificate signed by it. Static pod manifests go into `/etc/kubernetes/manifests/`, those are the YAML files that ARE the control plane. The kubelet was crashlooping waiting for `/var/lib/kubelet/config.yaml`. Kubeadm writes it now, the crashloop ends, and the kubelet starts the static pods. That's how Kubernetes bootstraps itself with no existing scheduler."

**Windows lens for the bootstrap moment:** the kubelet is acting as a local service controller, the way Windows' Service Control Manager spins up services from registry definitions at boot. Drop a YAML in `/etc/kubernetes/manifests/`, kubelet starts the pod. Same one-way coupling, no API server required.

### Step 2.2 — Confirm what landed on disk

```bash
ls /etc/kubernetes/pki/
ls /etc/kubernetes/manifests/
ls /etc/kubernetes/*.conf
```

**Expected:**

- `/etc/kubernetes/pki/` — about fifteen PEM files (CA, API server, etcd, kubelet, front-proxy, sa.key/pub)
- `/etc/kubernetes/manifests/` — exactly four YAML files: `kube-apiserver.yaml`, `etcd.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`
- `/etc/kubernetes/*.conf` — `admin.conf`, `super-admin.conf`, `controller-manager.conf`, `scheduler.conf`, `kubelet.conf`

**Windows lens:** `/etc/kubernetes/pki/` is the cluster's certificate store — closest Windows analog is the LocalMachine\My store, but flat PEM files rather than the MMC view. The four `.conf` files are kubeconfigs (cluster + cert + user bundled, conceptually similar to a saved `.rdp` file with credentials).

**Narrate:** "**Three folders, the entire control plane.** `pki/` is the certificate store. `manifests/` is the control plane itself — those four YAML files ARE the API server, etcd, scheduler, and controller-manager. The `.conf` files are kubeconfigs — bundled credentials for clients."

### Step 2.3 — Read one static pod manifest (the exam-tested skill)

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml | head -30
```

**Windows lens:** A static pod manifest is the YAML equivalent of a Windows service's registry definition under `HKLM\SYSTEM\CurrentControlSet\Services\<Name>` — edit the file, the controller (kubelet here, SCM there) detects the change and restarts the service. The difference is that kubelet picks up edits live, with no `sc.exe` equivalent needed.

**What to show on camera (focus on these lines as you scroll):**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=192.168.50.10
    - --etcd-servers=https://127.0.0.1:2379
    - --service-cluster-ip-range=10.96.0.0/12
    ...
```

**Narrate — slow down here:** "**Look at `--advertise-address=192.168.50.10`. That's the line kubeadm wrote from our `init.yaml` four-line edit.** Every flag we set declaratively shows up here as a literal command-line argument. **This is why troubleshooting matters:** if `kubeadm init` produced the wrong CIDR, this file is where you'd see the wrong value, and a one-character edit plus a kubelet pickup would fix it. On the exam, when a question says 'the API server is misconfigured,' this is where you go. **Read the manifest, find the bad flag, edit the manifest, watch kubelet auto-restart the pod.**"

### Demo 2 money shot (verbatim — say this)

> "Read the kubeadm init output like it's the exam roadmap. Where did the certificates land? `/etc/kubernetes/pki/`. Where are the static pod manifests? `/etc/kubernetes/manifests/`. Which kubeconfig does kubectl need? `/etc/kubernetes/admin.conf`. What's the join command? Right at the bottom. **Copy that block into a scratchpad the moment init succeeds.** Losing the scrollback costs you five minutes you don't have."

### Demo 2 exam tip (verbatim)

> "There is no in-place undo for a bad `kubeadm init`. Wrong pod CIDR, wrong advertise address, wrong control-plane endpoint — the only fix is `kubeadm reset --force` on every node and start over. **Two-minute lesson: edit `init.yaml`, read it twice, then run init.** Faster than rolling back."

---

## Demo 4 first half — Set up kubectl (1 min)

We deliberately do kubectl access BEFORE joining workers, so we can use kubectl to verify the join.

### Step 4.1 — Copy `admin.conf` into the user's home

```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

**Windows lens:** `chown` rewrites file ownership, the Linux equivalent of `icacls /setowner` on Windows. `$(id -u):$(id -g)` is shell substitution for "current user ID : current group ID", same idea as `%USERNAME%` expansion in cmd. In this demo we are `root` inside `sudo -i`, so the chown is a no-op for us, but in real production you would have run those three lines as your normal user, and the chown is what makes the kubeconfig usable. Teach it as muscle memory.

**Narrate, drop into a slower cadence here:** "Three lines, every kubeadm tutorial in the world ships them together. **Make the directory** so `~/.kube/config` has a parent. **Copy the admin kubeconfig** because that file embeds the cluster URL, the cluster CA, and an admin client cert. **Fix the ownership** so a non-root user owns the file, not root. **Skip the chown as a regular user and kubectl returns 'permission denied' on the client certificate.** That is the #1 day-one error in this course. Burn the triplet in: `mkdir -p`, `cp -i`, `chown`."

### Step 4.2 — Verify kubectl works AND the cluster is in the expected NotReady state

```bash
kubectl get nodes
kubectl get pods -n kube-system
```

**Expected:**

```
NAME       STATUS     ROLES           AGE   VERSION
control1   NotReady   control-plane   90s   v1.35.x

NAME                              READY   STATUS    RESTARTS   AGE
coredns-...                       0/1     Pending   0          80s
coredns-...                       0/1     Pending   0          80s
etcd-control1                     1/1     Running   0          90s
kube-apiserver-control1           1/1     Running   0          90s
kube-controller-manager-control1  1/1     Running   0          90s
kube-proxy-...                    1/1     Running   0          80s
kube-scheduler-control1           1/1     Running   0          90s
```

**Narrate, this is the exam trap to call out:** "control1 is **NotReady**. Both CoreDNS pods are **Pending**. **That is correct.** The kubelet refuses to mark a node Ready until a CNI plugin can assign pod IPs, and CoreDNS needs a pod IP to start. kube-proxy runs in hostNetwork so it comes up Running with no CNI, but CoreDNS is the canary. **On the exam, do not 'fix' this. It heals itself the moment we install Calico in Module 3.**"

> **STRESSED-TIM CALLOUT.** `NotReady` here is the right answer, not a bug. Do not run `kubeadm reset`. Do not edit static pod manifests. Do not reinstall containerd. Move on to joining workers, then to Module 3 (CNI). The node flips to `Ready` automatically.

**Windows lens on NotReady:** treat `NotReady` here like a Windows service stuck in `Start Pending` because a dependency service has not started yet. Nothing is broken, the dependency (CNI) just is not installed. You would not `sc.exe stop` a service in `Start Pending`. Don't kubeadm reset a NotReady node either.

---

## Demo 3 — Regenerate the join command and join the workers (2-3 min)

**Goal:** Show the lifesaver command, then join both workers.

### Step 3.1 — Regenerate the kubeadm join command (the exam lifesaver)

```bash
kubeadm token create --print-join-command
```

**Output (paste verbatim onto every worker):**

```
kubeadm join k8s.globomantics.local:6443 --token abcdef.0123456789abcdef --discovery-token-ca-cert-hash sha256:<HEX>
```

**Windows lens:** a kubeadm bootstrap token is a short-lived shared secret with a 24-hour default TTL, the same model as a Kerberos TGT's lifetime or a `New-PSSession` credential cached for a session. The CA-cert hash that travels with the join command is a SHA-256 pin of the cluster's root CA, conceptually equivalent to thumbprint-pinning a cert in `Cert:\LocalMachine\Root`. Both ends mutually authenticate, neither is optional.

**Narrate, slow down here:** "**This is the single most important command in this module.** Picture exam day. You ran init fifteen minutes ago. The terminal scrolled. The question now says 'join two workers to this cluster.' Where is the join command? Gone. **`kubeadm token create --print-join-command`** rebuilds it in two seconds, fresh token, correct CA hash, ready to paste. **The rule is: never scroll backward for the original. Always regenerate.** Memorize this command. Tattoo it."

### Step 3.2 — Copy the join command to clipboard, then exit to Windows

```bash
exit   # leave sudo -i
exit   # leave SSH, back to admin pwsh
```

You're back at admin pwsh on Windows. Paste the join command into a temporary file or just keep it in your clipboard.

### Step 3.3 — Join worker1

```powershell
vagrant ssh worker1
```

Inside worker1:

```bash
sudo kubeadm join k8s.globomantics.local:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:<HEX>
```

**Expected output ends with:** `This node has joined the cluster: ...`

**Narrate:** "Two-way verification. The token authenticates the worker — proves it has permission to join. The CA-cert hash authenticates the API server — proves the worker is talking to the real cluster, not a man-in-the-middle. **Belt and suspenders, by design.**"

### Step 3.4 — Join worker2

```bash
exit   # leave worker1
```

```powershell
vagrant ssh worker2
```

Inside worker2 — paste the same join command (within the 24-hour TTL it's still valid):

```bash
sudo kubeadm join k8s.globomantics.local:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:<HEX>
```

**Expected:** same success banner. ~20-30 sec.

```bash
exit   # leave worker2
```

### Demo 3 money shot (verbatim — say this)

> "Three rules for kubeadm join. **One:** the token is short-lived; assume 24 hours. **Two:** the CA-cert hash is non-negotiable; the worker uses it to verify the API server's TLS certificate. **Three:** lost join commands are regenerated with `kubeadm token create --print-join-command` — never scroll backward looking for the old one."

### Demo 3 exam tip (verbatim)

> "If a question says 'this worker fails to join with invalid token,' the answer is almost always one of two things. Either the token expired — regenerate. Or the CA-cert hash got typo'd in the paste — regenerate. Both fixes are the same command. Don't debug by reading the hex; just regenerate."

---

## Demo 4 second half — Verify all three nodes joined (1 min)

### Step 4.3 — SSH back to control1 and verify the full node list

```powershell
vagrant ssh control1
```

Inside control1 (no `sudo -i` needed — kubectl is owned by the vagrant user):

```bash
kubectl get nodes -o wide
```

**Expected:**

```
NAME       STATUS     ROLES           AGE     VERSION   INTERNAL-IP
control1   NotReady   control-plane   5m      v1.35.x   192.168.50.10
worker1    NotReady   <none>          90s     v1.35.x   192.168.50.11
worker2    NotReady   <none>          45s     v1.35.x   192.168.50.12
```

**Narrate:** "**Three nodes, all NotReady, all correct.** The control plane is up. Both workers joined on the first attempt. The CNI plugin install in Module 3 flips all three to Ready in about thirty seconds."

**Windows lens:** `kubectl get nodes -o wide` is your `Get-ADComputer -Filter *` for the cluster, the canonical inventory query. The `STATUS` column is the equivalent of an AD computer object's `Enabled` plus its last-logon health. `NotReady` here is normal pre-CNI, not a stale account.

### Step 4.4 — Quick health check on kube-system

```bash
kubectl get pods -n kube-system -o wide
```

**Expected:** four control-plane static pods (etcd, apiserver, controller-manager, scheduler) all **Running** on control1. Two CoreDNS pods **Pending**. Three kube-proxy DaemonSet pods (one per node) **Running** (kube-proxy uses hostNetwork, so it does not need a CNI).

**Narrate:** "Everything that can be Running is Running. The pods that need a real pod network, CoreDNS, are stuck Pending. kube-proxy uses hostNetwork so it is fine. **That's the cluster state Module 3 picks up.**"

### Demo 4 money shot (verbatim — say this)

> "Read the post-init state like a diagnostic snapshot. **Static pods Running on the control plane** = control plane is healthy. **CoreDNS Pending** = no CNI, expected. **kube-proxy Running** = hostNetwork, doesn't need a CNI. **Three nodes NotReady** = no CNI, expected. **None of this is a problem to fix at this stage.** On the exam, this is the correct answer to 'verify the cluster after init.'"

---

## Snapshot + slides 17-20 + close (~75 sec)

### Step 5.1 — Exit back to Windows and snapshot

```bash
exit   # leave control1
```

```powershell
.\cka-snapshot.ps1 post-init-join
```

**Snapshot narration (verbatim):**

> "Atomic Hyper-V checkpoint across all three VMs, named `post-init-join`. Module 3 starts from this exact state. Three nodes registered, all NotReady, control plane Running, CoreDNS Pending. **One `.\cka-restore.ps1 post-init-join` away from a clean dress rehearsal of CNI install.**"

### Slide 17 — Globomantics checkout (~30 sec)

Read Diana's quote in character. She's confirming what your terminal just proved: three nodes registered, all NotReady, all reporting NetworkPluginNotReady. The control plane is healthy and certificates are in place. **NotReady is not a failure — it's the correct state of a bootstrapped cluster waiting for its CNI.**

### Slide 18 — From Globomantics to you (~45 sec)

Read the four takeaways off the slide and **add the exam framing** on each:

1. **`--pod-network-cidr` must match your CNI.** Calico expects `192.168.0.0/16`. Mismatch = silent timeout, no cluster.
2. **`kubeadm init` output is your roadmap.** Certificates, kubeconfig, join command — all in that scroll. Copy it.
3. **NotReady after init is expected, not a failure.** Don't waste exam minutes debugging the correct state.
4. **All nodes must use identical versions.** kubeadm, kubelet, kubectl — same minor version everywhere. `apt-mark hold` is your shield.

### Slide 19-20 — Next module + bootstrap-flow diagram (~30 sec)

Slide 19 sets up Module 3 (CNI install + validation). Slide 20 is the diagram of what happened end-to-end — use it to recap the whole sequence: init → certs → manifests → kubelet starts → workers join → NotReady → (next module) CNI → Ready.

### Final close (~30 sec, verbatim)

> "Three Linux VMs walked through the kubeadm bootstrap workflow. Declarative `init.yaml` with the four lines that matter. `kubeadm init` writes the CA, the certificates, the static pod manifests, and the kubelet config. `admin.conf` copied into the user's home so kubectl works. `kubeadm token create --print-join-command` regenerates the lifesaver. Two workers joined with two-way verification. Three nodes registered, all NotReady, all correct. **Module 3 installs Calico and brings every node to Ready in under a minute.** See you there."

---

## Reset between takes

Every command in this module is idempotent against `kubeadm reset`, but the cleanest path is to restore the snapshot.

### Fast rewind (most common)

```powershell
.\cka-restore.ps1 pre-record-m2
```

~60-90 sec. Back to the pre-record baseline (post-prereqs from Module 1).

### Nuclear option — `kubeadm reset` and start over without snapshot

```powershell
# Run on each node, in order: control1, worker1, worker2
vagrant ssh control1
sudo kubeadm reset --force
sudo rm -rf /etc/kubernetes /var/lib/etcd ~/.kube
exit
```

Repeat on worker1 and worker2. Slower than restore but works if the snapshot is corrupt.

### Snapshot library to build during dry-runs

```powershell
.\cka-snapshot.ps1 pre-record-m2        # baseline before each M2 take
.\cka-snapshot.ps1 post-init-join       # after Demo 4 — Module 3's starting point
```

---

## Recovery cheat sheet

| Symptom | Likely cause | Fix |
|---|---|---|
| `kubeadm init` fails at preflight | Module 1 work drifted (e.g., swap re-enabled) | `.\cka-restore.ps1 post-prereqs` and start over |
| `kubeadm init` hangs at "waiting for the kubelet" | containerd not running or wrong cgroup driver | `sudo systemctl status containerd`; if down, `sudo systemctl restart containerd` |
| `kubeadm init` exits with "controlPlaneEndpoint not resolvable" | `/etc/hosts` entry missing on control1 | `grep globomantics /etc/hosts` — should show `192.168.50.10 k8s.globomantics.local` |
| `kubeadm join` returns "invalid token" | Token expired (>24h) | Regenerate with `kubeadm token create --print-join-command` |
| `kubeadm join` returns "x509: certificate signed by unknown authority" | CA-cert hash typo in paste | Regenerate the full join command — never type the hash by hand |
| `kubeadm join` returns "Unable to connect to the server" | controlPlaneEndpoint doesn't resolve on the worker | `grep globomantics /etc/hosts` on the worker — should show same line as control1 |
| `kubectl` returns "permission denied" on admin.conf | Skipped the `chown` step | `sudo chown $(id -u):$(id -g) ~/.kube/config` |
| `kubectl get nodes` shows control1 only after join | Workers crashlooped during join | `vagrant ssh worker1; sudo journalctl -u kubelet -n 50` |
| CoreDNS stuck Pending after Module 3 CNI install (later) | Pod CIDR mismatch | `kubectl cluster-info dump | grep -i podSubnet` vs Calico's CIDR — must match `192.168.0.0/16` |
| Control-plane static pod fails to start | Malformed kubeadm flags wrote a bad manifest | `sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep '\\-\\-'` to inspect the args |

---

## Source mapping

- **Live commands:** Deck slides 9 (declarative init.yaml + kubeadm init + kubectl setup + join), 13 (kubeadm token create --print-join-command). One-to-one with what you type on camera.
- **Lab setup from Module 1:** `src/cka-lab/Vagrantfile` provisioner already ran prereqs at `vagrant up`. Module 2 picks up at `post-prereqs` snapshot.
- **Snapshot helpers:** `src/cka-lab/cka-snapshot.ps1` and `src/cka-lab/cka-restore.ps1` — atomic, all-or-nothing across the three VMs.
- **Deck markdown extract:** `m02-kubeadm-init-join-TimEdits-WindowsFriendly.md` — every slide + full speaker notes (regenerated alongside this runbook).

---

## Appendix — The four `init.yaml` lines, with their flag equivalents

| YAML field | Flag-style equivalent | Why we prefer YAML |
|---|---|---|
| `localAPIEndpoint.advertiseAddress` | `--apiserver-advertise-address` | Documented, version-controlled, no shell escaping |
| `networking.podSubnet` | `--pod-network-cidr` | Same — and survives a kubeadm rerun cleanly |
| `controlPlaneEndpoint` | `--control-plane-endpoint` | Only the YAML form survives `kubeadm upgrade` reliably |
| `apiServer.certSANs` | (no clean flag — requires extra-args) | YAML is the only place to declare this declaratively |

**Why this matters:** the v1.35 CKA curriculum lists "Use declarative configuration for cluster setup" as an objective. Flags work; YAML is the right answer.

---

*Three NotReady nodes. One declarative config. The moment kubeadm bootstraps the cluster — and Module 3 brings every node to Ready.*
