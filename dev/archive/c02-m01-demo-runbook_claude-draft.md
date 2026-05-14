# CKA Course 2 / Module 1 — Preparing Linux Hosts and Container Runtime Dependencies

**Target runtime:** 12-14 min on camera
**Environment:** Admin pwsh 7 in Windows Terminal (Hyper-V cmdlets require elevation; every lab script declares `#Requires -RunAsAdministrator`)
**Lab:** Vagrant + Hyper-V — three Ubuntu 22.04 VMs (`control1`, `worker1`, `worker2`) on the `CKA-NAT` switch (192.168.50.0/24)
**Authoritative entry points:** `src/cka-lab/Vagrantfile` (provisioner), `src/cka-lab/cka-validate.ps1` (9 checks × 3 nodes), `src/cka-lab/lib/validate-node.sh` (the bash that runs inside each VM), `src/cka-lab/cka-snapshot.ps1` (atomic checkpoint)
**Cleanup:** none required mid-take — `cka-snapshot.ps1 "pre-cluster"` is the only state change, and it's the goal

**This is the lecture-heavy module of Course 2.** The single capstone demo (Vagrant `up` → `cka-validate` → `cka-snapshot`) is the bridge from theory to Module 2's `kubeadm init`. Don't rush it — the snapshot at the end is the save game every subsequent module restores to.

---

## Pre-flight (run these BEFORE hitting record)

```powershell
cd C:\github\ps-cka\src\cka-lab

# 1. Toolchain alive + elevated
$PSVersionTable.PSVersion                                       # 7.x
vagrant --version                                               # 2.4.x or later
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select-Object State   # Enabled
([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)   # True

# 2. Off-camera dress rehearsal — destroy any prior run so the demo is reproducible
vagrant destroy -f                                              # wipes any leftover VMs (CKA-NAT switch survives)
vagrant up --provider=hyperv                                    # ~10-15 min first time, ~5 min on box cache
./cka-validate.ps1                                              # MUST end with "ALL NODES READY — safe to snapshot"
./cka-snapshot.ps1 "pre-cluster"                                # baseline save point

# 3. Reset to ZERO for the real take
vagrant destroy -f                                              # back to nothing on disk
```

**Camera checklist:**

- [ ] PowerShell title bar reads "Administrator" — if not, close it and re-launch elevated
- [ ] Terminal width 140+ cols, font 16pt+, scrollback cleared
- [ ] Hyper-V Manager open in a second window (you'll show the three VMs appearing during `vagrant up` — visual proof, no narration needed)
- [ ] `~/.ssh/known_hosts` does NOT contain stale fingerprints for 192.168.50.10/.11/.12 (run `ssh-keygen -R` on each if present — see Recovery cheat sheet)
- [ ] No other Vagrant environment owns 192.168.50.0/24 (Docker bridge, WSL2, VPN client are the usual suspects — see Recovery)
- [ ] Globomantics framing handy — the slide-3 "Checking in" quote is the cold open for the demo segment

---

## Slide-to-demo mapping (the spine of this module)

The deck is the spine. Lecture covers slides 1-17 and 20; the live demo lives between slides 18 and 19.

| Slides | Block | What you're teaching | On-camera time |
|--------|-------|---------------------|----------------|
| 1-3 | **Open + Globomantics frame** | Course 2 reset (KIND → real VMs), four framing questions, Ravi P. hands you three bare Ubuntu hosts | ~90 sec |
| 4-7 | **LO 1: Kernel modules + sysctl** | `overlay` + `br_netfilter`, three sysctl values, persistence under `/etc/modules-load.d/` and `/etc/sysctl.d/` | ~2 min |
| 8-13 | **LO 2: containerd as CRI runtime** | CRI as the gRPC contract, dockershim removed in 1.24, `SystemdCgroup = true` (the #1 cause of `kubeadm init` failures), pre-configuring `crictl` | ~3 min |
| 14-15 | **LO 3: Install + pin kubeadm/kubelet/kubectl** | pkgs.k8s.io repo + GPG key, `apt-mark hold` on all three nodes, kubelet crash-loops until `kubeadm init` (this is normal) | ~1.5 min |
| 16-17 | **LO 4: Verify before bootstrapping** | Per-node verification script — every preflight kubeadm runs, run by hand first | ~1 min |
| **18** | **DEMO transition** | "Time to put it into practice" — one capstone demo on real Hyper-V VMs | — |
| **DEMO** | **Capstone: `vagrant up` → validate → snapshot** | The whole module compressed into one workflow on three real VMs | **~4-5 min** |
| 19 | **Globomantics checkout** | Ravi P. signs off — every prerequisite confirmed across all three nodes | ~30 sec |
| 20 | **From Globomantics to you** | Four takeaways the learner carries into Module 2 (`kubeadm init`) | ~45 sec |

---

## Open (60 sec on camera, anchored to slide 1)

> "Welcome to Course 2 of the CKA skill path. In Course 1 we used kind — Kubernetes nodes running as Docker containers — and kind hid the bootstrap process from you. That was a gift while you were learning the architecture, but the CKA exam tests the real workflow on real Linux VMs. So in this course we throw kind away and stand up a kubeadm cluster from scratch on three Ubuntu hosts. Module 1 is everything that has to be true BEFORE `kubeadm init` will succeed — kernel modules, sysctls, a CRI-compliant container runtime, the right packages pinned at the right version, and a verification pass across all three nodes. Skip any one of these and `kubeadm init` fails with errors that are very hard to interpret on exam day. Let's go."

**Cue to advance to slide 2 (four framing questions):** end the open by reading the four framing questions off the slide, one beat each. Each one maps to one learning objective. Don't pre-answer them — that's what the next 18 slides do.

**Cue to advance to slide 3 (Globomantics check-in):** read Ravi's quote in character. He's the Infrastructure Lead. The framing is "infrastructure provisioned three bare Ubuntu VMs, control plane up by end of day, skip any prereq and `kubeadm init` fails with cryptic errors." That framing carries the entire module.

---

## Lecture beats — narrate the deck (slides 4-17)

This module is **lecture-heavy on purpose**. The deck does the teaching; the demo proves it works. Per-slide narration cues below — keep them tight, the speaker notes in the PPTX have the full FRAMER + bracketed-echo expansions.

### Slide 4 — LO 1 hub (kernel modules + sysctl)

One-line transition: "Our first learning objective answers the question on the slide. Two kernel modules and three sysctl values, all disabled on a stock Ubuntu image."

### Slide 5 — The networking foundation (FRAMER content)

Walk the table top-down. **Beat the cause/effect:**

- `overlay` → containerd needs OverlayFS to stack image layers. Without it, containerd can't start a single container.
- `br_netfilter` → wires Linux bridge traffic into iptables/netfilter so kube-proxy and CNI plugins can enforce service rules across pods.
- `net.ipv4.ip_forward=1` → turns the host into a Layer 3 forwarder. Pod-to-pod traffic across nodes depends on this.
- `net.bridge.bridge-nf-call-iptables=1` → makes bridged Layer 2 traffic visible to iptables. **Kubeadm docs list this as a hard requirement.**
- Persistence: `/etc/modules-load.d/k8s.conf` for modules, `/etc/sysctl.d/k8s.conf` for sysctls. Both survive reboot.

**Warning callout (the slide labels this):** "Without these, kubeadm preflight checks fail or cluster networking breaks later in ways that are much harder to diagnose."

### Slide 6 — kubeadm prerequisites checklist

Four conditions kubeadm preflight verifies. Read them off the slide and add the gotcha:

- Swap disabled → `swapoff -a` AND remove the entry from `/etc/fstab` so it doesn't come back after reboot. Swap is the Linux pagefile equivalent; kubelet refuses to run with it on because the scheduler needs accurate memory accounting.
- All nodes run identical kubeadm/kubelet/kubectl versions → version skew breaks the join.
- Kernel modules + sysctl configured → covered on slide 5.
- **kubeadm does NOT install containerd or CNI.** This surprises everyone. kubeadm is a bootstrapper, not an installer.

### Slide 7 — The verbatim shell sequence

This is a **code slide**. Don't read every line — point at the structure:

1. `sudo modprobe overlay` + `sudo modprobe br_netfilter` → load now, in the running kernel
2. `cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf` → persist across reboot
3. `cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf` → drop-in file for the three sysctl values
4. `sudo sysctl --system` → apply every drop-in immediately, no reboot required
5. Verification one-liner: `lsmod | grep -E 'overlay|br_netfilter'` AND `sysctl net.ipv4.ip_forward`

**Exam-day callout:** "On the exam, you will type this exact sequence from memory. The Vagrantfile in our lab runs it as a provisioner — but you should be able to drive it by hand on a fresh VM."

### Slides 8-10 — LO 2 hub + CRI infographic

One-line transition into LO 2: "Our second learning objective is to install and configure containerd as the CRI-compliant runtime."

Slide 9 + 10 hold the CRI infographic (kubelet ↔ CRI socket ↔ runtime). Narrate it as: "kubelet is the node agent that runs every pod. CRI is the gRPC contract between kubelet and runtime. containerd is the implementation of that contract on each node."

### Slide 11 — containerd and CRI (the framer slide)

- **CRI is the abstraction. containerd is one implementation; CRI-O is another.** Both are production-grade; both can be on your exam VM.
- containerd replaced Docker as the default in v1.24 — dockershim, the kubelet's built-in Docker adapter, was removed.
- Generate baseline config with `containerd config default`, edit, restart.
- **Cgroup driver alignment** → containerd and kubelet must agree. Modern Linux = systemd cgroup driver.
- Verify with `systemctl status containerd` (service running) AND `crictl info` (CRI socket reachable).

### Slide 12 — Install + configure containerd (code slide)

Point at the `sed` line and **slow down**:

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
  /etc/containerd/config.toml
```

> "This single edit is the most important line in the entire file. The kubeadm documentation requires that containerd's cgroup driver match the kubelet's, and a mismatch here is the **number one cause of `kubeadm init` failures** in the field. If you remember nothing else from this slide, remember `SystemdCgroup = true`."

Wrap with `systemctl restart containerd` + `systemctl enable containerd`, verify with `crictl info` (same surface kubeadm preflight probes).

### Slide 13 — Configure crictl before you need it (exam-day lifesaver)

> "crictl is the command-line client for the CRI socket. It's how you debug containerd directly when kubectl — the cluster-level CLI — can't help you. On a broken kubelet, kubectl returns errors that point you in the wrong direction. crictl talks to the runtime, not the API server."

The fix: `sudo crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock` writes `/etc/crictl.yaml` so crictl stops guessing the socket and stops printing deprecation warnings on every call.

> "On a fresh exam VM, an unconfigured crictl wastes minutes. Configure it BEFORE you need it."

### Slide 14 — LO 3 hub (install + pin packages)

One-line transition: "Three packages, one version, pinned on every node."

### Slide 15 — Installing and pinning the Kubernetes packages

- Add the official Kubernetes apt repository with the signed GPG key (pkgs.k8s.io). GPG plays the role Authenticode plays on Windows.
- `apt-get install -y kubeadm kubelet kubectl` at v1.35 — same minor on all three.
- **`apt-mark hold kubeadm kubelet kubectl` on ALL THREE NODES immediately after install.** This is the documented protection against an unattended `apt-get upgrade` silently breaking your cluster.
- Verify with `dpkg -l kubeadm kubelet kubectl` — same version on every node, `hi` status flag confirms the hold is active.
- **kubelet starts but crashes until `kubeadm init` configures it.** This is correct behavior. kubelet has no config yet, so systemd restarts it in a tight loop until `kubeadm init` writes `/var/lib/kubelet/config.yaml`. Don't panic-fix it.

### Slide 16 — LO 4 hub (verify across all nodes)

One-line transition: "A cluster is only as strong as its weakest node. One missing kernel module on one worker derails the entire bootstrap with a preflight error that doesn't always tell you what's wrong."

### Slide 17 — Per-node verification

The four checks the verification script runs on every host:

1. `swapon --show` → must return empty
2. `systemctl status containerd` AND `crictl info` → service active AND CRI socket reachable
3. `dpkg -l kubeadm kubelet kubectl` → identical version on all three, hold flag set
4. Kernel modules + sysctl from slide 5 → still loaded after reboot

> "Cheap exam tip: don't manually run four commands on three nodes. Wrap them in a bash script. On the exam VM you can do this in 30 seconds and the time you save shows up later in the workload-scheduling questions."

---

## Demo — Capstone: Vagrant up → validate → snapshot (4-5 min)

**Goal:** Compress the entire module into one live workflow. Three real Hyper-V VMs come up, the provisioner runs everything from slides 4-15 automatically, the 9-check validator proves every prerequisite, the snapshot creates the save game Module 2 will restore to.

**Slide 18 transition (10 sec):** "Time to put everything we just covered into practice. Three Ubuntu VMs, Vagrant drives the provisioner, and at the end we run the validator that checks every prerequisite — every single kubeadm preflight — across all three nodes."

### Demo step 1 — `vagrant up` (no narration once it starts)

```powershell
cd C:\github\ps-cka\src\cka-lab
vagrant up --provider=hyperv
```

**Before you press Enter, narrate the four-line summary:**

> "Vagrantfile defines three VMs — `control1`, `worker1`, `worker2`. Each one boots from `generic/ubuntu2204`, gets a static IP on the `CKA-NAT` Hyper-V switch, and runs the same provisioner script — the verbatim sequence from slides 7, 12, and 15. **Notably, provisioning stops before `kubeadm init`. That's your job in Module 2, and it's the whole point.**"

**Press Enter.** Output streams for ~5-10 minutes on a cold box cache, ~3-5 min on warm. **Don't fill the silence.** Cut to Hyper-V Manager and let the viewer watch three VMs appear in the inventory. Then cut to the slide deck and re-narrate slides 5, 12, and 15 over the streaming output — match the visual to the lecture point that's executing.

**Watch for the trigger line:** when the last VM logs `Machine 'worker2' is up`, you're done. Cut back to the terminal.

**Recovery cue (only if needed):**

- "Subnet 192.168.50.0/24 already routed" → see Recovery cheat sheet. Stop the take, fix, restart.
- "netplan try timed out" → interface picker grabbed the wrong NIC. See Recovery.
- One VM hangs in provisioning → `vagrant ssh <vm> -c "cat /var/log/cka-provision.log"` then `vagrant provision <vm>` to re-run just that one.

### Demo step 2 — Validate (this is the teaching beat)

```powershell
./cka-validate.ps1
```

**Money shot — narrate as the output streams:**

> "This script SSHes into all three VMs and runs `lib/validate-node.sh` on each one. **Nine checks per node**: static IP and hostname resolution, the four binaries on `$PATH`, containerd running and enabled, swap off, `overlay` and `br_netfilter` loaded, all three sysctl values set, `SystemdCgroup = true` in `/etc/containerd/config.toml`, `/etc/crictl.yaml` pointing at the right socket, and `apt-mark hold` set on kubeadm, kubelet, and kubectl. Watch the PASS column."

When the aggregate summary lands, point at it:

```
========================================
  Summary across all nodes:
    PASS: 48
    WARN: 0
    FAIL: 0
========================================
  ALL NODES READY — safe to snapshot
  or run: kubeadm init on control1
========================================
```

> "Forty-eight passes, zero fails. **Every preflight check `kubeadm init` runs at start, we just ran ourselves first.** That's the discipline this module teaches. Verify before you bootstrap. Catch the misconfigured node before kubeadm tells you about it under exam time pressure."

**If you see a FAIL (rare in a clean run):** stop, point at it, narrate the fix. The validator output names the exact node and the exact check. This is GOOD teaching content — show the recovery on camera if it happens.

### Demo step 3 — Snapshot the save game

```powershell
./cka-snapshot.ps1 "pre-cluster"
```

**Narrate the atomicity:**

> "This is a native Hyper-V checkpoint on all three VMs, named `pre-cluster`. It's **atomic** — the script preflights every VM before touching one, so a partial snapshot state is impossible. In Module 2 we'll run `kubeadm init` and break things on purpose, then `cka-restore.ps1 \"pre-cluster\"` puts us back here in about 60 seconds. This is the practice loop the entire course depends on."

Expected output: three `Creating checkpoint pre-cluster on control1/worker1/worker2 ... Done.` lines.

### Slide 19 — Globomantics checkout (cut back to the deck, 30 sec)

Read Ravi's checkout quote in character. He's confirming what your terminal just proved: kernel modules loaded, sysctl configured, containerd running with the right cgroup driver, packages pinned. **Now he's confident these hosts will not surprise us during `kubeadm init`.**

### Slide 20 — From Globomantics to you (close, 45 sec)

Four takeaways. Read them off the slide, but **add the exam framing** on each:

1. **Kernel modules are non-negotiable.** On the exam, this is one `modprobe` + one `tee` away from passing. Don't skip it.
2. **Systemd cgroup alignment prevents silent failures.** `SystemdCgroup = true`. Number one cause of `kubeadm init` failures. Memorize the path: `/etc/containerd/config.toml`.
3. **Version pinning protects cluster stability.** `apt-mark hold kubeadm kubelet kubectl` — three packages, one command, every node.
4. **Verify every node before bootstrapping.** A bash script that runs slides 7/12/15 verification one-liners turns a manual pass into 30 seconds of typing.

---

## Close (30 sec)

> "Three bare Ubuntu hosts walked in. Three production-ready kubeadm nodes walked out — kernel modules loaded, sysctls applied, containerd running with the right cgroup driver, packages pinned at v1.35, and a snapshot captured so we can return here as many times as we want. In Module 2 we run `kubeadm init` on `control1`, install a CNI, and join the workers. That's the cluster bootstrap the CKA exam tests on you. See you there."

---

## Reset between takes

The full module rebuild loop:

```powershell
cd C:\github\ps-cka\src\cka-lab

# Full nuclear reset (use between full-module retakes only — ~10-15 min)
vagrant destroy -f
vagrant up --provider=hyperv
./cka-validate.ps1
./cka-snapshot.ps1 "pre-cluster"

# Demo-only retake (the VMs survived the previous take — ~60 sec)
./cka-restore.ps1 "pre-cluster"
./cka-validate.ps1                              # confirm the restore lands clean
```

**Don't destroy mid-day if you can avoid it.** `vagrant destroy` followed by `vagrant up` is 10-15 min on warm box cache. `cka-restore.ps1 "pre-cluster"` is ~60 seconds and lands at an identical state. Snapshot once at the start of recording, restore between every demo take.

**End-of-day teardown:**

```powershell
./cka-down.ps1                                  # graceful halt — VMs are preserved on disk
# Tomorrow morning:
./cka-up.ps1                                    # ~30 sec to bring all 3 back up
```

---

## Recovery cheat sheet

- **"Subnet 192.168.50.0/24 already routed via interface …"** → `create-nat-switch.ps1` refuses to clobber an existing route. Usual culprits: another Vagrant environment, a Docker bridge, a WSL2 distro with a custom network, a VPN client. Either free the subnet or edit `$Subnet`/`$GatewayIP` at the top of `src/cka-lab/create-nat-switch.ps1` to a free /24 (and update matching IPs in `Vagrantfile` + `/etc/hosts` blocks).
- **"Found N adapters named 'vEthernet (CKA-NAT)' — ambiguous"** → leftover adapter from a prior attempt. `Get-NetAdapter | Where Name -like "*CKA-NAT*"` to inventory; `Remove-VMSwitch -Name "CKA-NAT-Legacy" -Force` on the stale one. Then re-run `vagrant up`.
- **"netplan try timed out after 30 seconds"** → the interface picker chose a Docker/CNI/veth bridge instead of `eth0`. `vagrant ssh control1 -c "cat /var/log/cka-provision.log | grep IFACE"` — should print `Using interface: eth0`. If not, that's a bug. Re-run `vagrant provision <vm>`; the picker excludes `docker*`, `cni*`, `veth*`, `virbr*`, `br-*`, `flannel*`, `cali*` so re-running usually picks correctly the second time.
- **"Host key verification failed" on SSH** → fresh VMs from `vagrant destroy` + `vagrant up` get new host keys; your `~/.ssh/known_hosts` has the stale fingerprints. `ssh-keygen -R 192.168.50.10` + `.11` + `.12`. `join_worker.sh` itself uses `UserKnownHostsFile=/dev/null` so joins survive destroy/up cycles automatically.
- **Provisioning failed halfway through one VM** → `vagrant ssh <vm> -c "cat /var/log/cka-provision.log"`, find the last `>>>` line (timestamped per step), fix the root cause (usually DNS to `pkgs.k8s.io` or `github.com`), then `vagrant provision <vm>` to re-run just that VM. **Do NOT `vagrant destroy` — you'd retry all three.**
- **`cka-validate.ps1` fails on `net.bridge.bridge-nf-call-iptables`** → `br_netfilter` didn't load. Re-run `vagrant provision <vm>` — the sysctl step is idempotent and reloads the module.
- **`cka-validate.ps1` fails on `SystemdCgroup = true`** → the `sed` edit didn't take. SSH in, `sudo grep SystemdCgroup /etc/containerd/config.toml`, fix manually if needed, `sudo systemctl restart containerd`, re-validate.
- **`cka-snapshot.ps1` errors with "VM not found"** → you're not in admin pwsh, or one of the three VMs is halted. Run `./cka-info.ps1` to check live status; bring any DOWN VM up with `vagrant up <vm>` and re-snapshot. The script is atomic — if any VM fails the preflight, NO checkpoints are taken (better to fail loud than leave you with a half-saved state).
- **"Access denied" / "Cmdlet not found" on any lab script** → you're not in admin PowerShell. Every Hyper-V script declares `#Requires -RunAsAdministrator`. Close the shell, right-click → Run as administrator.
- **kubelet logs scream `CrashLoopBackOff` after `vagrant up`** → **this is normal** at this stage. kubelet has no config until `kubeadm init` writes `/var/lib/kubelet/config.yaml`. Validate-node treats kubelet as `enabled but may be crashlooping pre-init` (check 3). Don't try to fix it in Module 1 — Module 2 fixes it by running `kubeadm init`.

---

## Source mapping

- **Slide deck:** `m02-linux-host-prep_TimEdits-WindowsFriendly.pptx` (20 slides; markdown extract at `m02-linux-host-prep_TimEdits-WindowsFriendly.md` for ingestion-friendly review)
- **Provisioner (the script that runs everything in slides 7, 12, 15):** `src/cka-lab/Vagrantfile` inline shell provisioner — slide 7 sequence around the kernel-modules block, slide 12 sequence around the containerd block (note the `sed SystemdCgroup` line), slide 15 sequence around the pkgs.k8s.io repo + `apt-mark hold` block. Pinned at `kubelet/kubeadm/kubectl=1.35.0-1.1`.
- **Validator (the 9 checks demo step 2 runs):** `src/cka-lab/cka-validate.ps1` (PowerShell wrapper, SSHes to each VM and pipes the script over stdin via `bash -s` — argv-length-safe and exit-code-honest) → `src/cka-lab/lib/validate-node.sh` (the actual checks). The PASS/WARN/FAIL semantics: PASS = expected state confirmed, WARN = non-blocking (e.g. missing `crictl.yaml`), FAIL = blocks the summary and the wrapper exits non-zero.
- **Snapshot (the save game demo step 3 creates):** `src/cka-lab/cka-snapshot.ps1` — atomic all-or-nothing. Preflights every VM before touching one. Restore counterpart is `src/cka-lab/cka-restore.ps1`.
- **Reference walkthrough for learners (NOT recording):** `src/cka-lab/TUTORIAL-HYPERV.md` Section A (First Build) covers the same workflow as this demo, plus Sections D-G expand on CNI swaps, the practice loop, snapshot naming conventions, and the validator's 9 checks in table form. Point learners at it during the close as their hands-on companion.

The four learning objectives in this module map forward to Course 2 Module 2 (`kubeadm init` on `control1`, install CNI, `kubeadm join` on workers — built on top of the prereqs this module guarantees) and Course 9 (troubleshoot clusters — the SystemdCgroup-mismatch failure mode from slide 12 is a recurring exam scenario). Keep the narration around `SystemdCgroup = true` and `apt-mark hold` **identical** across this module and Course 9 — learners should recognize the same diagnostic on the second encounter.
