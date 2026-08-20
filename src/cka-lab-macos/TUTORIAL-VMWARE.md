# CKA Lab Tutorial — macOS / VMware Fusion

Hands-on walkthrough for the exam-shaped Vagrant lab. Work through the sections in order
the first time; use the **Quick Reference Card** at the bottom for day-to-day use.

---

## A. First build

**What you need installed first:**

1. VMware Fusion 13+ (or Pro 13+)
2. Vagrant 2.4+: `brew install vagrant` or [vagrantup.com/downloads](https://www.vagrantup.com/downloads)
3. VMware Vagrant Utility — download the `.pkg` from HashiCorp and install it:
   [developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility](https://developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility)
4. The Vagrant plugin (after the utility is installed):
   ```zsh
   vagrant plugin install vagrant-vmware-desktop
   ```

**Build the lab:**

```zsh
cd src/cka-lab-macos
./cka-lab.sh up
```

On first run `./cka-lab.sh up` runs `vagrant up`, which:

1. Downloads the `generic/ubuntu2204` box if not already cached (~700 MB, once only).
2. Creates 3 VMware Fusion VMs: `control1`, `worker1`, `worker2`.
3. Attaches a private host-only vmnet on `192.168.50.0/24` and assigns static IPs.
4. Runs the `hosts-file` provisioner on each node (writes `/etc/hosts`).
5. Runs the `cka-prereqs` provisioner on each node (~5-10 min per node):
   - Disables swap
   - Loads `overlay` and `br_netfilter` kernel modules
   - Configures sysctl for bridged traffic
   - Installs containerd with SystemdCgroup
   - Installs kubelet/kubeadm/kubectl at v1.35.0 (pinned) + `apt-mark hold`
   - Configures crictl
   - Adds bash aliases (`alias k=kubectl`)
6. Prints the connection guide.

After `up` completes, the cluster is **NOT yet initialized** — prereqs only. This is correct:
the exam tests whether you can bootstrap a cluster from scratch.

---

## B. Node topology

Three Ubuntu 22.04 VMs on a dedicated host-only vmnet:

| Node | Static IP | Role |
|------|-----------|------|
| control1 | 192.168.50.10 | Control plane — runs `kubeadm init` |
| worker1 | 192.168.50.11 | Worker — runs `join_worker.sh` |
| worker2 | 192.168.50.12 | Worker — runs `join_worker.sh` |

The vmnet host-only interface gives all three nodes a shared private network. They can reach
each other by hostname (`control1`, `worker1`, `worker2`) via `/etc/hosts`.

**Two ways to SSH in:**

```zsh
vagrant ssh control1              # Vagrant-managed SSH (uses the insecure key)
ssh vagrant@192.168.50.10         # Direct SSH (password: vagrant)
```

**Verify nodes are reachable:**

```zsh
./cka-lab.sh info
```

---

## C. Bootstrap the cluster

After `./cka-lab.sh validate` shows all nodes PASS, bootstrap the cluster:

**Step 1: Initialize the control plane**

```zsh
vagrant ssh control1
bash /vagrant/bootstrap_cp.sh
```

`bootstrap_cp.sh` runs `kubeadm init` using `192.168.50.10` as the API server address
and installs Flannel (v0.24.4, pod CIDR `10.244.0.0/16`). Copy the join command it prints.

**Step 2: Set up kubeconfig on your Mac (optional)**

```zsh
# From control1:
cat $HOME/.kube/config
# Copy the content to your Mac:
mkdir -p ~/.kube
vagrant ssh control1 -c 'cat /home/vagrant/.kube/config' > ~/.kube/cka-vagrant.yaml
export KUBECONFIG=~/.kube/cka-vagrant.yaml
# Then adjust the server IP from 192.168.50.10 if needed (it should already be correct)
kubectl get nodes
```

**Step 3: Join the workers**

```zsh
# In separate terminals:
vagrant ssh worker1
bash /vagrant/join_worker.sh

vagrant ssh worker2
bash /vagrant/join_worker.sh
```

`join_worker.sh` SSHes to `control1`, generates a fresh bootstrap token, and runs the join
locally. Tokens expire after 24 hours — `join_worker.sh` always fetches a fresh one.

**Step 4: Verify**

```zsh
vagrant ssh control1 -c 'kubectl get nodes'
```

All three nodes should show `Ready` within ~60 seconds.

---

## D. Swap the CNI

`bootstrap_cp.sh` ships **Flannel** (simple, no config, `10.244.0.0/16`). For exam practice
with Calico or Cilium, substitute the CNI install step:

| CNI | Pod CIDR | Install command |
|-----|----------|-----------------|
| Flannel v0.24.4 | `10.244.0.0/16` | `kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/v0.24.4/Documentation/kube-flannel.yml` |
| Calico v3.29.1 (Tigera) | `192.168.0.0/16` | `kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.1/manifests/tigera-operator.yaml` then custom-resources |
| Cilium | configurable | `helm install cilium cilium/cilium ...` |

Change `--pod-network-cidr` in `bootstrap_cp.sh` to match your chosen CNI.

> **Note:** The shipped Course 2+ lab uses **Calico via the Tigera operator** on pod CIDR
> `192.168.0.0/16`. If you follow the course runbooks, use Calico — not Flannel.

---

## E. The practice loop

This is the core workflow. Do it ten times and you'll be faster than the exam clock:

```zsh
# 1. Save a clean baseline once
./cka-lab.sh save pre-cluster

# 2. Practice — break things, fix them, explore
vagrant ssh control1
# ... kubeadm init, join workers, deploy workloads, break RBAC, fix it ...

# 3. Rewind to the exact same starting state
./cka-lab.sh restore pre-cluster
# Lab is back to pre-kubeadm-init state in ~60-90 s

# 4. Repeat from step 2
```

You can save multiple named checkpoints at different stages:

```zsh
./cka-lab.sh save pre-cluster       # after prereqs, before kubeadm init
./cka-lab.sh save cluster-ready     # after kubeadm init + workers joined + Calico up
./cka-lab.sh save m02-pre-upgrade   # cluster at v1.34, before upgrade demo
```

---

## F. Snapshots

`vagrant snapshot` is the engine; `cka-lab.sh save/restore/snapshots` wraps it with
atomic all-or-nothing semantics (all 3 VMs must have the snapshot before any restore runs).

```zsh
./cka-lab.sh save   <name>    # Create snapshot on all 3 VMs atomically
./cka-lab.sh restore <name>   # Restore all 3 VMs atomically, then boot them
./cka-lab.sh snapshots        # List all snapshots per VM (read-only)
```

**Snapshot naming conventions used in the course:**

| Snapshot name | When to save |
|--------------|--------------|
| `pre-cluster` | After `./cka-lab.sh up` and `./cka-lab.sh validate` PASS — before kubeadm init |
| `cluster-ready` | After cluster bootstrapped, workers joined, CNI up, all nodes Ready |
| `m02-pre-upgrade` | v1.34 cluster, before the upgrade demo |
| `m02-after-control1` | After control plane upgraded to v1.35 |

**Atomicity guarantee:**

- `save` checks all 3 VMs exist before snapshotting any of them.
- `restore` checks all 3 VMs have the snapshot before restoring any of them.

If a preflight fails, nothing is touched and a per-VM report shows what was found vs. expected.

---

## G. Validator

`./cka-lab.sh validate` SSHes into each VM and runs 9 checks:

1. **Static IP** — the expected IP (`192.168.50.10`, `.11`, `.12`) is assigned.
2. **`/etc/hosts`** — all three hostnames present.
3. **Binaries** — `kubeadm`, `kubelet`, `kubectl`, `crictl`, `containerd` on PATH.
4. **Services** — `containerd` enabled and active; `kubelet` enabled.
5. **Swap** — `swapon --show` is empty (kubeadm refuses to init otherwise).
6. **Kernel modules** — `overlay` and `br_netfilter` loaded.
7. **Sysctl** — bridge iptables and IP forwarding = 1.
8. **containerd cgroup** — `SystemdCgroup = true` in `/etc/containerd/config.toml`.
9. **crictl** — `/etc/crictl.yaml` points to `containerd.sock`.

Exit semantics: `[FAIL]` sets exit 1 (blocks); `[WARN]` is printed but does not block. Only
`[FAIL]` prevents you from snapshotting a clean baseline.

Run it **before every snapshot** to confirm the baseline is clean.

---

## H. Day-to-day workflow

**Morning (start a session):**

```zsh
./cka-lab.sh up        # boots VMs (already provisioned — ~30 s)
./cka-lab.sh status    # verify all RUNNING and pinging
./cka-lab.sh restore pre-cluster   # rewind to known-good state if needed
```

**During (practice):**

```zsh
vagrant ssh control1
# practice exam tasks...
```

**End of session:**

```zsh
./cka-lab.sh down      # graceful halt (ACPI shutdown — kubelet/etcd/containerd stop in order)
```

Prefer `halt` over suspend for long-term VMs. Hyper-V `Save` state is not used here —
VMware snapshots serve the rewind function.

---

## I. Troubleshooting

### Plugin / utility not installed

```
The provider 'vmware_desktop' could not be found...
```

Run:
```zsh
vagrant plugin install vagrant-vmware-desktop
```
If the plugin is installed but the utility is missing, the error is:
```
vagrant-vmware-desktop: Failed to connect to utility process
```
Install the [VMware Vagrant Utility](https://developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility) `.pkg` and reboot.

### VM stuck at "Waiting for machine to boot"

The VM is running in VMware Fusion but Vagrant can't SSH in. Check:
1. **VMware Fusion → Virtual Machine → Settings → Network** — confirm the private_network adapter is up.
2. Try `vagrant ssh control1` manually; if it hangs, the vmnet may be misrouted.
3. Run `ifconfig vmnet<N>` on the host to verify the `192.168.50.x` subnet is assigned to a vmnet.

### vmnet subnet collision

```
Error: No vmnet with an adequate IP range for private network ...
```

Another vmnet on your Mac already owns `192.168.50.0/24`. Fix:
- VMware Fusion → Preferences → Network → change the colliding vmnet's subnet, OR
- Edit `NODES` in `Vagrantfile` and `EXPECTED_IPS` in `lib/validate-node.sh` to a free subnet.

### Nodes NotReady after snapshot restore (Calico/CNI issue)

```
vagrant ssh control1 -c 'kubectl get nodes'
# Shows NotReady
```

CNI auth tokens are invalidated on checkpoint restore. Bounce the DaemonSet:
```zsh
vagrant ssh control1 -c 'kubectl -n calico-system rollout restart ds/calico-node'
```

### SSH host key changed (after `vagrant destroy && vagrant up`)

```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
REMOTE HOST IDENTIFICATION HAS CHANGED!
```

`join_worker.sh` already uses `StrictHostKeyChecking=no`. For your local `ssh` commands:
```zsh
ssh-keygen -R 192.168.50.10   # and .11, .12
```

### kubelet crashloop after upgrade (stale flag)

If a node shows `NotReady` after a manual kubelet upgrade:
```zsh
vagrant ssh control1 -c 'sudo journalctl -u kubelet -n 30'
```
Look for `--pod-infra-container-image` or other removed flags in `/var/lib/kubelet/kubeadm-flags.env`. Remove them and restart: `sudo systemctl restart kubelet`.

---

## J. Nuclear option

When something is deeply broken and restoration isn't practical:

```zsh
vagrant destroy -f   # delete all 3 VMs completely
./cka-lab.sh up      # rebuild from scratch (~10-15 min)
./cka-lab.sh validate
./cka-lab.sh save pre-cluster
```

---

## K. What is NOT done for you

The lab stops before `kubeadm init` — deliberately. The CKA exam starts you at bare Ubuntu nodes.
These are NOT pre-configured:

| Not included | Why |
|-------------|-----|
| Kubernetes cluster | You bootstrap it — that's the exam skill |
| CNI plugin | You choose and install it |
| Helm, Kustomize | You install them when the course calls for it |
| Ingress controller | Not on the exam as a prerequisite |
| Metrics Server | Install it yourself for HPA practice |
| Storage provisioner | You provision PVs manually |
| Any namespaced workloads | Starting with a clean cluster is more realistic |

---

## Quick Reference Card

| Task | Command |
|------|---------|
| Build lab | `./cka-lab.sh up` |
| Halt lab | `./cka-lab.sh down` |
| Status | `./cka-lab.sh status` |
| Connection info | `./cka-lab.sh info` |
| Validate nodes | `./cka-lab.sh validate` |
| Save snapshot | `./cka-lab.sh save <name>` |
| Restore snapshot | `./cka-lab.sh restore <name>` |
| List snapshots | `./cka-lab.sh snapshots` |
| SSH to control1 | `vagrant ssh control1` |
| SSH to worker1 | `vagrant ssh worker1` |
| Bootstrap cluster | `vagrant ssh control1 -c 'bash /vagrant/bootstrap_cp.sh'` |
| Join worker1 | `vagrant ssh worker1 -c 'bash /vagrant/join_worker.sh'` |
| Rebuild from scratch | `vagrant destroy -f && ./cka-lab.sh up` |

**Node IPs:** control1 `192.168.50.10`, worker1 `.11`, worker2 `.12`
**Credentials:** vagrant / vagrant
**Kubernetes version:** v1.35 (pinned: `kubelet=1.35.0-1.1`)
**CNI (default):** Flannel v0.24.4 on `10.244.0.0/16`
