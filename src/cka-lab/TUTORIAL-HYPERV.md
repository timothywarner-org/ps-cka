# TUTORIAL — Hyper-V + Vagrant CKA Lab

> Build a real kubeadm cluster from three empty Ubuntu VMs. Break it. Restore it.
> Do it again tomorrow. That's the whole pedagogy.

---

## What You'll Learn

By the end of this tutorial you will have:

1. Provisioned three Ubuntu 22.04 VMs on an isolated Hyper-V NAT switch
2. Run `kubeadm init` and joined two workers with a fresh bootstrap token
3. Installed a CNI (Flannel by default; Cilium and Calico are one line away)
4. Deployed a workload, deliberately broken the cluster, and rolled back with a named Hyper-V checkpoint
5. Established a 5-minute practice loop you can repeat dozens of times before exam day

**Time budget:**

- **First build:** ~15 min (box download + provisioning on all 3 VMs)
- **Practice loop:** ~5 min (restore → `kubeadm init` → CNI → join → done)
- **Nuclear rebuild:** ~10 min (`vagrant destroy -f` → `vagrant up`)

This tutorial goes deeper than `README.md`. The README is the reference card.
This is the hands-on first-time-through walkthrough — with the guardrails that
keep you out of the ditch.

---

## Prereqs

You need all of these. Non-negotiable:

| Thing | Why |
|-------|-----|
| Windows 11 Pro or Enterprise | Home edition doesn't ship Hyper-V |
| Hyper-V feature enabled | `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All` |
| [Vagrant](https://developer.hashicorp.com/vagrant/install) installed | 2.4.x or later |
| PowerShell 7+, **running as Administrator** | Hyper-V cmdlets require elevation. Every script in this lab starts with `#Requires -RunAsAdministrator`. There is no non-admin path. |
| ~10 GB free disk | Ubuntu box + three VM differencing disks |
| ~8 GB free RAM | Three VMs at 2 GB each, plus overhead |

### First-time install (copy-paste)

Run these once in an **elevated** PowerShell 7. Reboot after enabling Hyper-V.

```powershell
# Hyper-V feature — reboot after this line
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# PowerShell 7 (required — every lab script declares #Requires -Version 7.0)
winget install --id Microsoft.PowerShell --source winget

# Vagrant
winget install --id Hashicorp.Vagrant --source winget
```

Verify after the reboot, from an **admin PowerShell 7 (`pwsh`)** prompt:

```powershell
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V | Select FeatureName,State
vagrant --version
$PSVersionTable.PSVersion
```

Expect: Hyper-V `State: Enabled`, Vagrant 2.4.x or later, PowerShell 7.x.

> **Admin PowerShell is not optional.** If you try any script from a regular
> shell, it fails immediately at the `#Requires` header. Right-click PowerShell
> → Run as administrator. Pin a shortcut with the admin flag if you forget.

---

## Section A — First Build

Open an admin PowerShell and get to the lab directory:

```powershell
cd C:\github\ps-cka\src\cka-lab
```

### A.1 Stand up the VMs

```powershell
vagrant up --provider=hyperv
```

What happens, in order:

1. **Vagrant trigger fires `create-nat-switch.ps1`** — creates the `CKA-NAT`
   Hyper-V internal switch (192.168.50.0/24), assigns `192.168.50.1` to the
   host adapter, and wires up a Windows NAT so the VMs reach the internet.
   Idempotent — re-running it on a lab that's already set up is a no-op.
2. **Each VM boots** off the `generic/ubuntu2204` box (first run downloads
   ~1.5 GB; cached after that).
3. **Netplan writes a static IP** on the CKA-NAT interface. The Vagrantfile
   uses `netplan try` with a 30-second auto-revert — if the new config kills
   connectivity, the VM rolls back automatically rather than leaving you
   locked out mid-provision.
4. **Main prereq provisioner** installs containerd (with `SystemdCgroup = true`),
   kubelet, kubeadm, and kubectl **pinned to `1.35.0-1.1`**, holds those
   packages against accidental `apt upgrade`, loads kernel modules, sets
   sysctls, disables swap.
5. **Provisioning stops before `kubeadm init`.** That's your job, and it's the
   whole point.

Expect ~10-15 min on the first run, ~5 min on rebuilds (box cached).

### A.2 Validate

```powershell
.\cka-validate.ps1
```

This SSHes into all three VMs and runs 9 categories of checks. You want to
see `ALL NODES READY — safe to snapshot`. Details in Section G.

### A.3 Snapshot

```powershell
.\cka-snapshot.ps1
```

Takes a Hyper-V checkpoint named `pre-cluster` on all three VMs. This is the
state you'll restore to every time you want a clean canvas. Don't skip this
step — without it, your practice loop is a ~15-minute rebuild instead of a
~60-second restore.

---

## Section B — Meet the VMs

| Node | IP | vCPU / RAM | Role |
|------|-----|-----------|------|
| `control1` | 192.168.50.10 | 2 / 2 GB | Control plane — where `kubeadm init` happens |
| `worker1` | 192.168.50.11 | 2 / 2 GB | Worker — joins the cluster |
| `worker2` | 192.168.50.12 | 2 / 2 GB | Worker — joins the cluster |

All three run Ubuntu 22.04 headless, sit on the `CKA-NAT` switch, and have
each other plus themselves in `/etc/hosts` (so you can `ping worker1` without
fiddling with DNS).

### How to connect

**The Vagrant way** — Vagrant manages SSH keys for you:

```powershell
vagrant ssh control1
vagrant ssh worker1
vagrant ssh worker2
```

**The direct way** — same as the CKA exam, no safety net:

```powershell
ssh vagrant@192.168.50.10   # control1
ssh vagrant@192.168.50.11   # worker1
ssh vagrant@192.168.50.12   # worker2
```

Direct-SSH credentials:

- Username: `vagrant`
- Password: `vagrant` (yes, really — this is a lab)
- Key: auto-generated at `src/cka-lab/.vagrant/machines/<node>/hyperv/private_key`

> **Pro tip:** the direct-SSH path is better practice for the exam, because
> the exam drops you into a bastion host with plain SSH, not a magic wrapper.
> Use `vagrant ssh` on day one, switch to direct SSH once you're comfortable.

Live connection status any time:

```powershell
.\cka-info.ps1
```

Output looks like:

```
  NODE         IP                 STATUS   SSH COMMAND
  ----------------------------------------------------------------
  control1     192.168.50.10      UP       ssh vagrant@192.168.50.10
  worker1      192.168.50.11      UP       ssh vagrant@192.168.50.11
  worker2      192.168.50.12      UP       ssh vagrant@192.168.50.12
```

Ping-based — a `DOWN` here means the VM is halted or unreachable on the NAT.

---

## Section C — Bootstrap the Cluster

You now have three pristine nodes with all prereqs installed but **zero cluster
state**. Time to change that.

### C.1 On control1 — run `bootstrap_cp.sh`

```powershell
vagrant ssh control1
```

Inside the VM:

```bash
cd /vagrant
./bootstrap_cp.sh
```

`src/cka-lab/bootstrap_cp.sh` does three things:

1. Detects the control plane IP via `hostname -I` and passes it to
   `kubeadm init --apiserver-advertise-address` with `--pod-network-cidr=10.244.0.0/16`
2. Copies `/etc/kubernetes/admin.conf` to `$HOME/.kube/config` and chowns it
3. Applies the Flannel v0.24.4 manifest as the CNI
4. Prints a fresh `kubeadm join` command you *could* copy — but you won't
   need to (see C.2)

Expected output tail:

```
kubeadm join 192.168.50.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>

Get join command (copy this to each worker):
kubeadm join 192.168.50.10:6443 --token ...
```

Verify the control plane:

```bash
kubectl get nodes
# control1   Ready   control-plane   90s   v1.35.0

kubectl get pods -A
# flannel, coredns, etcd, apiserver, controller-manager, scheduler — all Running
```

If `coredns` is stuck in `Pending`, the CNI isn't up yet. Wait 30 seconds.
Still stuck? Check `kubectl -n kube-flannel get pods` — Flannel has to be
`Running` before CoreDNS can get an IP.

### C.2 On each worker — run `join_worker.sh`

Open two more admin PowerShell windows (one per worker) or run sequentially:

```powershell
vagrant ssh worker1
```

Inside worker1:

```bash
cd /vagrant
./join_worker.sh
```

Repeat for worker2.

**Why is `join_worker.sh` self-sufficient?** Because kubeadm bootstrap tokens
expire after 24 hours. Rather than caching a token that goes stale between
practice sessions, the script SSHes to control1 and asks for a fresh one
every time:

```bash
JOIN_CMD=$(ssh -o StrictHostKeyChecking=no ... vagrant@192.168.50.10 \
  "sudo kubeadm token create --print-join-command")
sudo $JOIN_CMD
```

You never have to copy-paste a token. That's deliberate — the CKA exam won't
give you a cheat sheet of working tokens either; you'll generate fresh ones.

### C.3 Verify

Back on control1:

```bash
kubectl get nodes
```

After ~60 seconds all three should show `Ready`:

```
NAME       STATUS   ROLES           AGE     VERSION
control1   Ready    control-plane   5m      v1.35.0
worker1    Ready    <none>          90s     v1.35.0
worker2    Ready    <none>          60s     v1.35.0
```

Deploy something to prove it works:

```bash
kubectl create deployment nginx --image=nginx --replicas=3
kubectl expose deployment nginx --port=80 --type=NodePort
kubectl get pods -o wide
```

You should see pods landing on both workers. That's a real Kubernetes cluster.
Go take a snapshot (see Section F).

---

## Section D — Swap the CNI

`bootstrap_cp.sh` defaults to **Flannel v0.24.4** because Flannel is a single
manifest with zero config and works out of the box. But CKA v1.35 covers
Cilium and Calico too, and you should practice all three.

Open `src/cka-lab/bootstrap_cp.sh` and look at the CNI block:

```bash
FLANNEL_VERSION="v0.24.4"
POD_CIDR="10.244.0.0/16"
...
kubectl apply -f "https://raw.githubusercontent.com/flannel-io/flannel/${FLANNEL_VERSION}/Documentation/kube-flannel.yml"
```

### Swap to Cilium

```bash
# Replace the Flannel apply with:
CILIUM_VERSION="1.16.3"
POD_CIDR="10.0.0.0/16"   # Cilium's default; change --pod-network-cidr above to match

helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --version $CILIUM_VERSION \
  --namespace kube-system \
  --set ipam.mode=kubernetes
```

(Cilium via Helm means you also need `helm` installed on control1 — not a
default prereq. `apt install helm` or use the shell install.)

### Swap to Calico

```bash
CALICO_VERSION="v3.28.1"
POD_CIDR="192.168.0.0/16"   # Calico default
kubectl apply -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
```

### The pod-CIDR caveat

**Every CNI has an opinionated default pod CIDR.** If the `--pod-network-cidr`
you passed to `kubeadm init` doesn't match what the CNI expects, pods get IPs
from the kubeadm range but the CNI routes traffic on a different network.
Result: pods can't talk to each other and CoreDNS never becomes ready.

Defaults:

| CNI | Expected pod CIDR |
|-----|-------------------|
| Flannel | `10.244.0.0/16` |
| Calico | `192.168.0.0/16` |
| Cilium | Configurable; no kubeadm CIDR required if you set `ipam.mode=kubernetes` |

**Rule:** always update `POD_CIDR` at the top of `bootstrap_cp.sh` when you
swap CNIs, and re-run `kubeadm reset` + `kubeadm init` from scratch. Do
**not** try to change the pod CIDR of a running cluster.

---

## Section E — The Practice Loop

This is the whole game. The reason to use VMs instead of a cloud cluster is
that you can do this loop over and over for $0:

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│   1.  .\cka-restore.ps1           Reset VMs to baseline    │
│                                                            │
│   2.  .\cka-validate.ps1          Confirm 9 checks PASS    │
│                                                            │
│   3.  vagrant ssh control1 -c "./bootstrap_cp.sh"          │
│                                                                │
│   4.  (optional) swap CNI in step 3                        │
│                                                            │
│   5.  vagrant ssh worker1 -c "./join_worker.sh"            │
│       vagrant ssh worker2 -c "./join_worker.sh"            │
│                                                            │
│   6.  kubectl get nodes           All three Ready          │
│                                                            │
│   7.  Deploy something real                                │
│                                                            │
│   8.  Break something on purpose                           │
│                                                            │
│   9.  Diagnose and fix it (or give up — both teach you)    │
│                                                            │
│  10.  .\cka-restore.ps1           Back to baseline — again │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Why the loop matters

The CKA exam gives you **2 hours for ~17 tasks**. If `kubeadm init` + CNI +
two joins takes you 15 minutes of fumbling, you've already lost ~12% of your
exam clock on setup. The goal of this loop is to compress that to 5 minutes
of reflex — type `bootstrap_cp.sh`, type `join_worker.sh` twice, verify, move
on.

### Good things to break on purpose

Once the cluster is green, break one of these before the next restore:

- `sudo systemctl stop kubelet` on a worker — how do you find it? (`kubectl get nodes`)
- Corrupt `/etc/kubernetes/manifests/etcd.yaml` on control1 — how do you recover?
- Delete `/etc/cni/net.d/*` and watch pods stop scheduling
- Flip `SystemdCgroup` back to `false` in containerd and restart it
- `kubectl drain worker1 --ignore-daemonsets` and practice uncordoning

Every one of these is a CKA-domain troubleshooting scenario. The restore
button is your safety net — use it aggressively.

---

## Section F — Snapshots

### Atomic all-or-nothing

Both `cka-snapshot.ps1` and `cka-restore.ps1` run a **pre-flight check
before touching any VM**. Snapshot aborts if any of the three VMs doesn't
exist. Restore aborts if any VM is missing the named checkpoint. This is
deliberate: a partial snapshot state — where `control1` has `post-init`
but `worker1` and `worker2` don't — is worse than no snapshot at all.
Better to fail loud than leave you with a corrupted save game.

### Named checkpoints for stage-specific states

Build a library of checkpoints, one per milestone:

```powershell
# After first vagrant up + validate
.\cka-snapshot.ps1                   # default name: "pre-cluster"

# After kubeadm init + CNI (cluster is green, no workloads)
.\cka-snapshot.ps1 "post-init"

# After swapping to Cilium
.\cka-snapshot.ps1 "with-cilium"

# After deploying nginx + some services
.\cka-snapshot.ps1 "with-workloads"
```

Now your practice-loop entry point is a choice:

```powershell
.\cka-restore.ps1                    # back to "pre-cluster" — do it all yourself
.\cka-restore.ps1 "post-init"        # skip init, go straight to scheduling practice
.\cka-restore.ps1 "with-workloads"   # practice break/fix on a populated cluster
```

### Seeing what checkpoints exist

```powershell
Get-VMCheckpoint -VMName control1 | Format-Table Name, CreationTime
```

Checkpoints are native Hyper-V — they show up in Hyper-V Manager too.

---

## Section G — The Validator

`cka-validate.ps1` SSHes into all 3 VMs and runs `lib/validate-node.sh` against
each. **Implementation detail:** the script is piped via stdin to `bash -s`
rather than passed as a `vagrant ssh -c "long heredoc"` argument. Windows
OpenSSH truncates long inline commands, and `$LASTEXITCODE` only reflects
the outer `vagrant` process, not the inner script. Stdin delivery avoids
both problems.

### The 9 checks

| # | Check | What it confirms |
|---|-------|------------------|
| 1 | **Static IP** | Node has its expected 192.168.50.x IP, and all three hostnames resolve via `/etc/hosts` |
| 2 | **Binaries** | `kubeadm`, `kubelet`, `kubectl`, `containerd` all on `$PATH` |
| 3 | **Services** | `containerd` running + enabled, `kubelet` enabled (may be crashlooping pre-init — that's fine) |
| 4 | **Swap** | `swapon --show` is empty — kubelet refuses to start with swap on |
| 5 | **Kernel modules** | `overlay` and `br_netfilter` both in `lsmod` |
| 6 | **Sysctl** | `net.bridge.bridge-nf-call-iptables`, `net.bridge.bridge-nf-call-ip6tables`, `net.ipv4.ip_forward` all = 1 |
| 7 | **Containerd config** | `SystemdCgroup = true` in `/etc/containerd/config.toml` (K8s 1.35 requires systemd cgroup driver) |
| 8 | **crictl** | `/etc/crictl.yaml` exists and points at containerd socket |
| 9 | **Package holds** | `kubelet`, `kubeadm`, `kubectl` are all in `apt-mark showhold` (so `apt upgrade` can't silently jump you to 1.36) |

### PASS / WARN / FAIL semantics

The validator emits tagged findings that the PowerShell wrapper counts:

- **[PASS]** — expected state confirmed
- **[WARN]** — non-blocking. Example: `crictl.yaml missing` (you can still
  `kubeadm init`, but `crictl ps` will be annoying). Package holds missing
  are also WARN — holds are a hygiene concern, not a correctness gate.
- **[FAIL]** — **blocks the summary**. The wrapper exits non-zero.

Aggregate summary at the end looks like:

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

WARNs don't fail the run. Any FAIL and the wrapper exits 1.

---

## Section H — Day to Day

### Morning

```powershell
cd C:\github\ps-cka\src\cka-lab
.\cka-up.ps1             # wraps 'vagrant up --no-provision' + shows info
```

`--no-provision` is important: you do **not** want to re-run the provisioner
every morning. The VMs already have everything installed; you just want them
booted.

### During the day

```powershell
.\cka-info.ps1           # live status + SSH commands
.\cka-validate.ps1       # sanity check after suspicious behavior
.\cka-snapshot.ps1 "foo" # save a good state
.\cka-restore.ps1 "foo"  # return to it
```

### Evening

```powershell
.\cka-down.ps1           # graceful 'vagrant halt' on all 3 VMs
```

VMs power off cleanly. Tomorrow morning `.\cka-up.ps1` brings them back in
~30 seconds.

---

## Section I — Troubleshooting

### "Access denied" / "Cmdlet not found" / scripts refuse to run

**You're not in admin PowerShell.** Every script in this lab declares
`#Requires -RunAsAdministrator`. Hyper-V cmdlets need elevation. Close the
shell, right-click PowerShell, Run as administrator.

### "Subnet 192.168.50.0/24 already routed via interface ..."

`create-nat-switch.ps1` refuses to run if something else on your machine
already owns the CKA-NAT subnet. Common culprits:

- A different Vagrant environment
- A Docker bridge network
- A WSL2 distro with a custom network
- A VPN client (Cisco AnyConnect, etc.)

Either free the subnet, or edit `$Subnet` and `$GatewayIP` at the top of
`src/cka-lab/create-nat-switch.ps1` to a /24 that's actually free (and
update the matching IPs in the Vagrantfile + `/etc/hosts` entries).

### "Found N adapters named 'vEthernet (CKA-NAT)' — ambiguous"

You have a leftover adapter from a previous attempt. `Get-NetAdapter | Where
Name -like "*CKA-NAT*"` to see them, remove the stale one:

```powershell
Remove-VMSwitch -Name "CKA-NAT-Legacy" -Force
```

Then re-run `vagrant up`.

### "kubelet is crashlooping before `kubeadm init`"

**This is normal.** Kubelet starts, finds no cluster config, crashes,
systemd restarts it, it crashes again. It will keep doing this until you
run `kubeadm init` (on control1) or `kubeadm join` (on workers). If
`cka-validate.ps1` passes, ignore the crashloop — it'll settle the moment
the cluster exists.

Post-init, any crashloop is a real problem:

```bash
sudo journalctl -xeu kubelet --no-pager | tail -50
sudo crictl ps -a
```

### "Host key verification failed" after `vagrant destroy` + `vagrant up`

Fresh VMs get new SSH host keys, but your `~/.ssh/known_hosts` still has the
old fingerprints for `192.168.50.10`, `.11`, `.12`. Two options:

```powershell
# Nuke the stale entries
ssh-keygen -R 192.168.50.10
ssh-keygen -R 192.168.50.11
ssh-keygen -R 192.168.50.12
```

Or just delete `~/.ssh/known_hosts` entirely — it's a lab, you'll regenerate
it next time you SSH. `join_worker.sh` already uses
`UserKnownHostsFile=/dev/null` for exactly this reason, so joins keep
working through destroy/up cycles.

### "Provisioning failed halfway through"

Check the log inside the VM:

```powershell
vagrant ssh control1 -c "cat /var/log/cka-provision.log"
```

The log is timestamped by step. Find the last `>>>` line — that's the step
that failed. Fix the root cause (usually DNS to `pkgs.k8s.io` or
`github.com`), then:

```powershell
vagrant provision control1   # re-run provisioner only on the failed VM
```

### "Validation fails on `net.bridge.bridge-nf-call-iptables`"

The `br_netfilter` module didn't load. Re-run `vagrant provision <vm>` — the
sysctl step is idempotent.

### "netplan try timed out after 30 seconds"

The Vagrantfile uses `netplan try` with a 30s auto-revert — if the new
static config breaks connectivity, netplan reverts and the provisioner
falls back to `netplan apply`. If you see the revert message, it means the
interface picker chose the wrong NIC. Check the log:

```powershell
vagrant ssh control1 -c "cat /var/log/cka-provision.log | grep IFACE"
```

Expected: `Using interface: eth0`. If you see a Docker or CNI bridge there,
that's a bug — file an issue.

---

## Section J — The Nuclear Option

When the cluster is unrecoverable, a snapshot is too old, or you just want
to prove to yourself that the whole pipeline works end-to-end:

```powershell
vagrant destroy -f                   # wipe all 3 VMs (NAT switch survives)
vagrant up --provider=hyperv         # rebuild from scratch
.\cka-validate.ps1                   # 9 checks, all PASS
.\cka-snapshot.ps1                   # new "pre-cluster" save point
```

Total time: ~10 min if the Ubuntu box is already cached, ~15-20 min on a
brand-new machine.

**Note:** `vagrant destroy -f` only removes the VMs. The `CKA-NAT` Hyper-V
switch and its NAT rule stay put — which is what you want, because a new
`vagrant up` can reuse them instantly. If you ever need to remove those too:

```powershell
Remove-NetNat -Name "CKA-NAT-Network" -Confirm:$false
Remove-VMSwitch -Name "CKA-NAT" -Force
```

---

## Section K — What's NOT Done For You

Everything in this lab stops *exactly* where the CKA exam expects you to
pick up. That's not laziness; it's the entire pedagogical bet. If a script
ran `kubeadm init` for you, the exam would catch you with your pants down.

### Not installed, on purpose

| Missing | Why |
|---------|-----|
| **The cluster itself** — no `kubeadm init` has run | Exam objective #1. Do it yourself. |
| **A CNI** — no pod network is applied by default | `bootstrap_cp.sh` installs Flannel, but only if *you* run it. The exam expects you to pick and install a CNI. |
| **Helm** | Install when a practice scenario needs it. CKA v1.35 covers Helm for installing cluster components (Course 3), so practice `curl | bash` Helm installs by hand. |
| **Kustomize** | Comes with kubectl 1.14+ as `kubectl kustomize` — that's installed. Standalone `kustomize` binary? Install if needed. |
| **An ingress controller** | NodePort is enough for most practice. Install nginx-ingress or Traefik when the scenario calls for it. |
| **Metrics Server** | HPA/VPA practice needs this. Install by hand when you get there. |
| **Storage provisioner** | PV/PVC practice is cleaner with a real provisioner. `rancher/local-path-provisioner` is one line. Install when needed. |

### What IS done for you (and why that's fine)

The prereqs on each node — containerd, kubelet/kubeadm/kubectl, kernel
modules, sysctls, swap-off, package holds, cgroup driver — are "the boring
part." In the real world, a node-prep Ansible role or Packer image handles
this. The exam tests whether you can *bootstrap a cluster on prepared
nodes*, not whether you can write an Ansible role under time pressure.

If you want to practice the node-prep side too, destroy the VMs and re-do
the Vagrantfile provisioner steps by hand on a fresh Ubuntu VM.
Productive for understanding, not productive for exam speed.

---

## Quick Reference Card

Pin this to your monitor. Print it. Tattoo it.

### Scripts

```powershell
# First build (once per clean environment)
vagrant up --provider=hyperv

# Daily on/off
.\cka-up.ps1           # morning — boot VMs, show status
.\cka-down.ps1         # evening — graceful halt

# Status + info
.\cka-info.ps1         # connection table with live UP/DOWN

# Save / load
.\cka-snapshot.ps1                  # save "pre-cluster"
.\cka-snapshot.ps1 "post-init"      # save with custom name
.\cka-restore.ps1                   # load "pre-cluster"
.\cka-restore.ps1 "post-init"       # load custom name

# Verify node health (9 checks × 3 VMs)
.\cka-validate.ps1

# Nuclear
vagrant destroy -f
vagrant up --provider=hyperv
```

### SSH

```powershell
vagrant ssh control1                 # easy mode
ssh vagrant@192.168.50.10            # exam mode (password: vagrant)
```

### Cluster bootstrap (inside the VMs)

```bash
# On control1
cd /vagrant && ./bootstrap_cp.sh

# On worker1 and worker2
cd /vagrant && ./join_worker.sh

# Verify (on control1)
kubectl get nodes
kubectl get pods -A
```

### Node IPs

| Host | IP |
|------|-----|
| `control1` | `192.168.50.10` |
| `worker1` | `192.168.50.11` |
| `worker2` | `192.168.50.12` |
| Host gateway | `192.168.50.1` |
| Subnet | `192.168.50.0/24` |

### Credentials

- User: `vagrant`
- Password: `vagrant`
- Key: `src/cka-lab/.vagrant/machines/<node>/hyperv/private_key`

### Pinned versions

- Kubernetes: **v1.35.0-1.1** (apt pin + `apt-mark hold`)
- Flannel (default CNI): **v0.24.4**
- Ubuntu box: `generic/ubuntu2204`
- Container runtime: `containerd` (Ubuntu-packaged, `SystemdCgroup = true`)

### File map

| File | Purpose |
|------|---------|
| `src/cka-lab/Vagrantfile` | VM definitions + provisioner |
| `src/cka-lab/create-nat-switch.ps1` | Creates `CKA-NAT` switch (called by Vagrantfile trigger) |
| `src/cka-lab/bootstrap_cp.sh` | `kubeadm init` + CNI on control1 |
| `src/cka-lab/join_worker.sh` | Self-sufficient worker join (fetches fresh token) |
| `src/cka-lab/cka-up.ps1` | Boot VMs (no re-provisioning) |
| `src/cka-lab/cka-down.ps1` | Graceful halt |
| `src/cka-lab/cka-info.ps1` | Connection table + live status |
| `src/cka-lab/cka-validate.ps1` | 9-check health verification |
| `src/cka-lab/cka-snapshot.ps1` | Atomic all-or-nothing checkpoint |
| `src/cka-lab/cka-restore.ps1` | Atomic all-or-nothing restore |
| `src/cka-lab/lib/validate-node.sh` | The 9 checks (runs inside VMs via stdin) |

---

*The cluster is the exam. The prereqs are homework. Do the homework once
with `vagrant up`, then drill the cluster until `kubeadm init` is muscle
memory. See you on the other side of the CKA.*
