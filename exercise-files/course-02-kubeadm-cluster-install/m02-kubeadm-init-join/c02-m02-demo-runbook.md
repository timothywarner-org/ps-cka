# CKA Course 2 / Module 2 — Bootstrapping a Cluster with kubeadm init and join

**Target runtime:** 12-14 min on camera
**Environment:** Admin pwsh 7 on Windows 11 → `vagrant ssh control1` (Ubuntu 22.04)
**Lab:** **Hyper-V + Vagrant** — `src/cka-lab` with control1, worker1, worker2 on `192.168.50.10/.11/.12`
**Starting state:** `m02-start` snapshot from Module 1 (every prerequisite verified, zero cluster state).
**Authoritative command source:** Deck slides 9 (declarative `init.yaml`), 13 (`kubeadm token create --print-join-command`), 15 (`mkdir/cp/chown` for kubectl).
**Validator:** Module 2 ends with the cluster validation built into the kubeadm output plus `kubectl get nodes` / `kubectl get pods -n kube-system`. The cross-node CNI validation lives in Module 3.
**Cleanup between takes:** `cka-restore.ps1 m02-start` rewinds in 60-90 sec. Snapshot to `post-init-join` at the end so Module 3 starts from a known-good baseline.

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
.\cka-restore.ps1 m02-start
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
2. `sudo -i` → ENTER → root prompt (kubeadm init needs root)
3. **Demo 1** — `kubeadm config print init-defaults > init.yaml`, then `vim init.yaml` to make the four edits (see cheat card in Demo 1), `:wq`, then verify with the grep
4. **Demo 2** — `kubeadm init --config init.yaml --upload-certs` (watch output); `ls /etc/kubernetes/{pki,manifests}/`; `cat /etc/kubernetes/manifests/kube-apiserver.yaml | head -30`
5. `exit` → ENTER → **leave sudo -i**, back to `vagrant@control1:~$`
6. **Demo 4 first half** — `mkdir/cp/chown` as **vagrant** (sudo on `cp`/`chown` only); `kubectl get nodes` works as vagrant, kubeconfig lives at `/home/vagrant/.kube/config`
7. **Demo 3a** — `sudo kubeadm token create --print-join-command | tee /tmp/join-cmd.txt` → highlight the full join line on screen and **copy to clipboard**
8. `exit` → ENTER → back to admin pwsh on Windows
9. `vagrant ssh worker1` → paste the join command, **prepend `sudo`** before pressing Enter → wait for success banner → `exit`
10. `vagrant ssh worker2` → paste the join command, **prepend `sudo`** before pressing Enter → wait for success banner → `exit`
11. `vagrant ssh control1` → `kubectl get nodes -o wide` (three nodes, all NotReady — works as vagrant) → `kubectl get pods -n kube-system`
12. `exit` → ENTER → back to admin pwsh
13. `.\cka-snapshot.ps1 post-init-join` → ENTER

**Total ENTERs:** ~30 across the whole module. Slow is smooth, smooth is fast.

**Why root only for Demo 1 and Demo 2, then we exit:** `kubeadm init` writes to `/etc/kubernetes/` and reads `/etc/containerd/config.toml` — root pays off there. **After init succeeds, we deliberately `exit` out of `sudo -i`** so the `~/.kube/config` setup writes to `/home/vagrant/.kube/config` (where every later `kubectl` will look). **Running everything as root is the #1 kubeadm beginner mistake** — the kubeconfig lands in `/root/.kube/config` and `kubectl` then silently fails for the regular user. Then `sudo kubeadm token create` (sudo on the single command, not a full root login) is enough for the join command. Open with: **"We're root for `kubeadm init` and then we exit root — that's the standard kubeadm flow, and getting it backwards is why most people's first cluster ends with `kubectl` errors."**

**Pedagogical frame for the open:** "Module 1 verified every prerequisite. The VMs are exam-clean. Now we bootstrap. The CKA exam tests `kubeadm init` and `kubeadm join` directly — under time pressure — and the difference between a calm three-minute exercise and a panicked twenty-minute scramble is which lines you have memorized."

---

## Open — slides 1-3 (~75 sec)

**Verbatim talk track:**

> "Three Ubuntu VMs, every prerequisite verified, the kubelet crashlooping on every node — which is correct, because there's no `kubeadm init` yet to give it a config to read. Diana from Globomantics has the warning that costs more candidates their question on this domain than any other: **`--pod-network-cidr` has to match the CNI you'll install later.** We're installing Calico in Module 3, and Calico's default range is `192.168.0.0/16` — so that's exactly the value we'll put in `init.yaml` today. The classic trap is to copy a Flannel-flavored example off the internet, type `10.244.0.0/16` here, then install Calico in Module 3 anyway. Pods get IPs, none of them route across nodes, and the remediation is `kubeadm reset` on every node and start over. So let's get it right the first time."

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

### Step 1.2 — Emit the kubeadm defaults

```bash
kubeadm config print init-defaults > init.yaml
```

You now have a v1beta4 InitConfiguration + ClusterConfiguration template. **This is the exam-day pattern** — emit defaults, edit four lines, save. No flag-soup.

### Step 1.3 — Open in vim and make four edits

```bash
vim init.yaml
```

**Optional, viewer-friendly:** `:set number` ⏎ to show line numbers.

**Cheat card — keep this visible on second monitor:**

| # | Find with `/...` | Vim action | What you'll type |
|---|---|---|---|
| 1 | `1.2.3.4` | `C` (change to end of line) | `192.168.50.10` |
| 2 | `serviceSubnet:` | `o` (open new line below) | `␣␣podSubnet: 192.168.0.0/16` (2 leading spaces) |
| 3 | `clusterName:` | `o` (open new line below) | `controlPlaneEndpoint: 192.168.50.10:6443` (no indent) |
| 4 | `apiServer: {}` | `cc` (change whole line) | 4 lines (see Edit 4) |

#### Edit 1 — `advertiseAddress`

```text
/1.2.3.4   ⏎
C
192.168.50.10
Esc
```

#### Edit 2 — `podSubnet` (under `networking:`)

```text
/serviceSubnet   ⏎
o
  podSubnet: 192.168.0.0/16
Esc
```

The two leading spaces matter — they put `podSubnet` at the same indent level as `serviceSubnet`.

#### Edit 3 — `controlPlaneEndpoint` (top-level in `ClusterConfiguration`)

```text
/clusterName   ⏎
o
controlPlaneEndpoint: 192.168.50.10:6443
Esc
```

No leading spaces — `controlPlaneEndpoint` is a top-level key, sibling of `clusterName`.

#### Edit 4 — Replace `apiServer: {}` with the SAN block

Toggle paste mode first so vim doesn't auto-indent your four lines into a parser error:

```text
:set paste   ⏎
/apiServer:   ⏎
cc
apiServer:
  certSANs:
    - 192.168.50.10
    - 10.96.0.1
Esc
:set nopaste   ⏎
```

**Save and exit:** `:wq` ⏎

If a single edit went sideways, `vim init.yaml` and fix the one line. If multiple edits broke, faster to `rm init.yaml` and re-run Step 1.2 cleanly.

### Step 1.4 — Verify all four edits landed (one grep)

```bash
grep -E "advertiseAddress|podSubnet|controlPlaneEndpoint|certSANs" init.yaml
```

**Expected (four matching lines, in this order):**

```text
  advertiseAddress: 192.168.50.10
  podSubnet: 192.168.0.0/16
controlPlaneEndpoint: 192.168.50.10:6443
  certSANs:
```

If a line is missing or wrong, re-open vim and fix the specific edit.

---

**Vim exam-survival kit (6 keystrokes, tattoo these):** `i` insert · `Esc` command · `/` search · `o` open line below · `:wq` save+quit · `:q!` abandon ship. The demo also uses `C` (change to end of line) and `cc` (change whole line) — speed boosters, not required.

**Narrate, slow down on `controlPlaneEndpoint`:** "**This is the most important line.** Today it's an IP — `192.168.50.10`, control1's address — because that's the honest representation of a single-CP cluster. Tomorrow in Course 3, we swap it for a DNS name pointing at HAProxy in front of three control-plane nodes. Setting `controlPlaneEndpoint` now, even just as the IP, writes it into every certificate's SAN list AND bakes it into the kubeconfig. **Skipping it now and adding HA later is a five-hour certificate reissue.** Ten seconds today saves you thirty minutes in Course 3."

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

## Demo 4 first half — Set up kubectl (1-2 min)

We deliberately do kubectl access BEFORE joining workers, so we can use kubectl to verify the join.

### Step 4.0 — Exit `sudo -i` so kubectl setup lands in the right home directory

```bash
exit
```

You're back at `vagrant@control1:~$` (the `$` prompt instead of `#` is your visual cue). **This matters.** Inside `sudo -i`, `$HOME` was `/root`. Now `$HOME` is `/home/vagrant`. The three lines in Step 4.1 will write `~/.kube/config` into `/home/vagrant/.kube/config` — the exact path every later `kubectl` command (including the post-join verification in Step 4.3) will look at.

**Narrate:** "**Watch this carefully — this is where every kubeadm beginner faceplants.** If we ran the next three lines while still inside `sudo -i`, the kubeconfig would land in `/root/.kube/config` and we could never use `kubectl` as a regular user. Standard kubeadm flow: bootstrap as root, then **exit root** before configuring `~/.kube/config`. The kubeconfig lives with the user, not with root."

### Step 4.1 — Copy `admin.conf` into the vagrant user's home (sudo only where needed)

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
ls -l $HOME/.kube/config
```

**Windows lens:** `chown` rewrites file ownership, the Linux equivalent of `icacls /setowner` on Windows. `$(id -u):$(id -g)` is shell substitution for "current user's UID:GID" — for `vagrant` that's `1000:1000`. **Why `sudo` only on `cp` and `chown`, not `mkdir`:** `mkdir` writes inside our own `$HOME`, no privilege needed. `cp` reads `/etc/kubernetes/admin.conf` which is `0600 root:root` — needs root to read. `chown` then *transfers ownership* of that root-owned file to vagrant — also needs root. **Three commands, two need sudo, one doesn't.** Knowing which is which is exam muscle memory.

**Expected `ls -l` output:**

```text
-rw------- 1 vagrant vagrant <bytes> <date> /home/vagrant/.kube/config
```

The `vagrant vagrant` columns are the proof — file owner and group are both `vagrant`, **not `root`**. That's what makes `kubectl` work without `sudo` from here on.

**Narrate, drop into a slower cadence here:** "Three lines, every kubeadm tutorial in the world ships them together. **Make the directory** so `~/.kube/config` has a parent — no sudo, we own our own home. **Copy the admin kubeconfig** with sudo because `/etc/kubernetes/admin.conf` is `0600 root:root` — only root can read it. **Fix the ownership** so the vagrant user owns the file, not root. **Look at the `ls -l`: `vagrant vagrant`, not `root root`.** That's the entire point — and that's the line that makes `kubectl` work as a non-root user. **Skip the chown and kubectl returns 'permission denied' on the client certificate.** Burn the triplet in: `mkdir`, `sudo cp -i`, `sudo chown`."

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
kubeadm join 192.168.50.10:6443 --token <TOKEN> --discovery-token-ca-cert-hash sha256:<HEX>
```

**Windows lens:** a kubeadm bootstrap token is a short-lived shared secret with a 24-hour default TTL, the same model as a Kerberos TGT's lifetime or a `New-PSSession` credential cached for a session. The CA-cert hash that travels with the join command is a SHA-256 pin of the cluster's root CA, conceptually equivalent to thumbprint-pinning a cert in `Cert:\LocalMachine\Root`. Both ends mutually authenticate, neither is optional.

**Narrate, slow down here:** "**This is the single most important command in this module.** Picture exam day. You ran init fifteen minutes ago. The terminal scrolled. The question now says 'join two workers to this cluster.' Where is the join command? Gone. **`kubeadm token create --print-join-command`** rebuilds it in two seconds, fresh token, correct CA hash, ready to paste. **The rule is: never scroll backward for the original. Always regenerate.** Memorize this command. Tattoo it."

### Step 3.1b — Save the join command to a scratch file for clean on-camera copy

You should still be at the `vagrant@control1:~$` prompt from Step 4.1 (not in `sudo -i`). Run the token command with `sudo` and tee the output:

```bash
sudo kubeadm token create --print-join-command | tee /tmp/join-cmd.txt
```

**Why `tee` to a file (no `chmod`, no script, no shebang):** scrollback is one Ctrl-L away from gone, and a SHA-256 hash is not something you want to retype. `tee` writes the join command to `/tmp/join-cmd.txt` AND echoes it to your terminal in one step, so the full command stays visible on camera AND is safely on disk. **It's a one-line text file**, not a script — we'll paste the contents directly into each worker SSH session in Steps 3.3 and 3.4.

**Why not `scp` it across to the workers:** the Vagrantfile doesn't distribute SSH keys between VMs, so `scp vagrant@worker1:...` would prompt for a password on camera. The clipboard-and-paste path uses the Vagrant SSH keys the Windows host already has, no cross-VM trust required.

**Security note (say this on camera):** "**The bootstrap token in this output is short-lived — 24-hour default — and burned the second a worker joins. Don't scrub it from the recording. By the time anyone watches this, the token is dead.**"

**On camera now:** highlight the full `kubeadm join ...` line (the one with `--token` and `--discovery-token-ca-cert-hash`), right-click → Copy (or Ctrl+Shift+C in Windows Terminal). That's the clipboard contents we'll paste twice.

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

Inside worker1, type **`sudo`** followed by a space, then paste the join command from your clipboard:

```bash
sudo kubeadm join 192.168.50.10:6443 --token <pasted> --discovery-token-ca-cert-hash sha256:<pasted>
```

**Expected output ends with:** `This node has joined the cluster: ...`

**Narrate:** "Two-way verification. The token authenticates the worker — proves it has permission to join. The CA-cert hash authenticates the API server — proves the worker is talking to the real cluster, not a man-in-the-middle. **Belt and suspenders, by design.** **Notice I typed `sudo` first, then pasted the join line** — kubeadm writes `/etc/kubernetes/kubelet.conf` and needs root to do it. Same command we captured on control1, same SHA-256 hash, zero retyping risk."

### Step 3.4 — Join worker2

```bash
exit   # leave worker1
```

```powershell
vagrant ssh worker2
```

Inside worker2, same drill — type **`sudo`** + space, then paste (the join command is still valid for the 24-hour TTL):

```bash
sudo kubeadm join 192.168.50.10:6443 --token <pasted> --discovery-token-ca-cert-hash sha256:<pasted>
```

**Expected:** same success banner. ~20-30 sec.

**Narrate:** "Same paste, second worker. Two `sudo`s, two pastes, two `This node has joined the cluster` banners — that's the whole worker-join workflow."

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

Inside control1 (no `sudo -i` needed — `~/.kube/config` was set up for the vagrant user back in Step 4.1, so `kubectl` works directly):

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

~60-90 sec. Back to the pre-record baseline (m02-start from Module 1).

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
| `kubeadm init` fails at preflight | Module 1 work drifted (e.g., swap re-enabled) | `.\cka-restore.ps1 m02-start` and start over |
| `kubeadm init` hangs at "waiting for the kubelet" | containerd not running or wrong cgroup driver | `sudo systemctl status containerd`; if down, `sudo systemctl restart containerd` |
| `kubeadm init` exits with "controlPlaneEndpoint not reachable" | Wrong IP in `controlPlaneEndpoint` or NIC down | `ip -4 addr show eth0` on control1 — must show `192.168.50.10/24` |
| `kubeadm join` returns "invalid token" | Token expired (>24h) | Regenerate with `sudo kubeadm token create --print-join-command` on control1 |
| `kubeadm join` returns "x509: certificate signed by unknown authority" | CA-cert hash typo in paste | Regenerate the full join command — never type the hash by hand |
| `kubeadm join` returns "Unable to connect to the server: dial tcp 192.168.50.10:6443" | Worker can't reach control1's API server | `ping -c1 192.168.50.10` from the worker; check `CKA-NAT` switch + control1's firewall |
| `kubectl` returns "permission denied" on admin.conf | Skipped the `chown` step | `sudo chown $(id -u):$(id -g) ~/.kube/config` |
| `kubectl get nodes` shows control1 only after join | Workers crashlooped during join | `vagrant ssh worker1; sudo journalctl -u kubelet -n 50` |
| CoreDNS stuck Pending after Module 3 CNI install (later) | Pod CIDR mismatch | `kubectl cluster-info dump \| grep -i podSubnet` vs Calico's CIDR — must match `192.168.0.0/16` |
| Control-plane static pod fails to start | Malformed kubeadm flags wrote a bad manifest | `sudo cat /etc/kubernetes/manifests/kube-apiserver.yaml \| grep '\\-\\-'` to inspect the args |

---

## Source mapping

- **Live commands:** Deck slides 9 (declarative init.yaml + kubeadm init + kubectl setup + join), 13 (kubeadm token create --print-join-command). One-to-one with what you type on camera.
- **Lab setup from Module 1:** `src/cka-lab/Vagrantfile` provisioner already ran prereqs at `vagrant up`. Module 2 picks up at `m02-start` snapshot.
- **Snapshot helpers:** `src/cka-lab/cka-snapshot.ps1` and `src/cka-lab/cka-restore.ps1` — atomic, all-or-nothing across the three VMs.

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
