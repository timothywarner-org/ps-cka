# CKA Lab — macOS / VMware Fusion

Three-node kubeadm cluster for the **Certified Kubernetes Administrator (CKA) v1.35** Pluralsight
skill path. This path runs on **macOS** using **VMware Fusion** as the hypervisor and
**Vagrant** as the VM lifecycle tool. It is the macOS twin of `../cka-lab/` (Windows / Hyper-V).

## Node topology

| Node | IP | Role |
|------|----|------|
| control1 | 192.168.50.10 | Control plane |
| worker1 | 192.168.50.11 | Worker |
| worker2 | 192.168.50.12 | Worker |

Kubernetes: **v1.35**. Ubuntu: **22.04 LTS**. CNI: your choice (see `bootstrap_cp.sh`). CPU / RAM per node: 2 vCPU / 2 GB.

Credentials: **vagrant / vagrant**.

## Prerequisites

| Tool | Minimum version | Install |
|------|----------------|---------|
| VMware Fusion | 13.x | [vmware.com/products/fusion](https://www.vmware.com/products/fusion.html) |
| Vagrant | 2.4+ | [vagrantup.com/downloads](https://www.vagrantup.com/downloads) |
| vagrant-vmware-desktop | latest | `vagrant plugin install vagrant-vmware-desktop` |
| VMware Vagrant Utility | latest | [hashicorp.com/vagrant-vmware-utility](https://developer.hashicorp.com/vagrant/docs/providers/vmware/vagrant-vmware-utility) |

The VMware Vagrant Utility is a separate daemon that the plugin requires — install it **before** the plugin.

## Quickstart

```zsh
# 1. Install the VMware Utility (download the pkg from HashiCorp, install it)
# 2. Install the plugin:
vagrant plugin install vagrant-vmware-desktop

# 3. Build the lab (first run provisions all prereqs — ~10-15 min):
./cka-lab.sh up

# 4. Verify all nodes are ready:
./cka-lab.sh validate

# 5. Snapshot the clean prereq baseline:
./cka-lab.sh save pre-cluster

# 6. SSH in and bootstrap your cluster:
vagrant ssh control1
bash /vagrant/bootstrap_cp.sh   # kubeadm init + Flannel CNI

# On each worker (separate terminals):
vagrant ssh worker1
bash /vagrant/join_worker.sh

# 7. Verify all nodes Ready:
vagrant ssh control1 -c 'kubectl get nodes'
```

## Subcommand reference

```
./cka-lab.sh up                  Provision and start all 3 VMs
./cka-lab.sh down                Gracefully halt all 3 VMs
./cka-lab.sh status              VM state table + ping  (default bare invocation)
./cka-lab.sh status --quiet      Exit 1 if any VM running (CI / pre-record check)
./cka-lab.sh info                Connection guide with live UP/DOWN
./cka-lab.sh validate            Run prereq checks on all 3 nodes
./cka-lab.sh save   [name]       Atomic snapshot — all 3 VMs (default: pre-cluster)
./cka-lab.sh restore [name]      Atomic restore  — all 3 VMs, then boot
./cka-lab.sh snapshots           List saved snapshots per VM
./cka-lab.sh help                Print this reference
```

Bare `./cka-lab.sh` runs `status`.

## Practice loop

```zsh
./cka-lab.sh save pre-cluster    # one-time save of clean state
# ... work / break / record ...
./cka-lab.sh restore pre-cluster # rewind to clean state in ~60-90 s
```

This is the core exam-prep loop. Save before each practice run, restore to repeat.

## Module 2 upgrade lab (build at v1.34)

```zsh
export CKA_K8S_MINOR=1.34
export CKA_K8S_PKG_VERSION=1.34.6-1.1
./cka-lab.sh up
./cka-lab.sh save m02-pre-upgrade
# Record the upgrade demo, then rewind with:
./cka-lab.sh restore m02-pre-upgrade
unset CKA_K8S_MINOR CKA_K8S_PKG_VERSION
```

## Troubleshooting

### Plugin not installed

```
Error: The provider 'vmware_desktop' could not be found...
```

Run `vagrant plugin install vagrant-vmware-desktop` and ensure the VMware Utility is installed and running (`sudo /opt/vagrant-vmware-desktop/bin/vagrant-vmware-utility --debug`).

### VMware Utility not running

```
Error: vagrant-vmware-desktop: Failed to connect to utility process
```

Install (or reinstall) the VMware Utility from the HashiCorp download page. On macOS it installs as a system daemon — reboot after install if needed.

### Subnet collision (`192.168.50.0/24` already in use)

VMware Fusion uses its own vmnet range. If another vmnet already owns `192.168.50.0/24`, you have two options:

1. In VMware Fusion → Preferences → Network, find the colliding vmnet and change its subnet.
2. Or change the IPs in the Vagrantfile (`NODES` hash) and in `lib/validate-node.sh` (`EXPECTED_IPS` array) to a free subnet.

### `generic/ubuntu2204` not available for vmware_desktop

Add to your Vagrantfile:

```ruby
config.vm.box = "bento/ubuntu-22.04"
```

`bento/ubuntu-22.04` has well-tested VMware support.

### Calico CNI token invalid after snapshot restore

A VM checkpoint restore invalidates CNI authentication state. After `./cka-lab.sh restore`, if nodes show NotReady, bounce the CNI DaemonSet:

```bash
# If you installed Calico (not Flannel):
kubectl -n calico-system rollout restart ds/calico-node
```

### Snapshot list parsing — name not found

`snapshot_exists` matches on `^\s+<name>\s*$`. If `vagrant snapshot list` emits the name
with a different indent or trailing characters (provider-specific), the preflight will fail.
Work around: run `vagrant snapshot list control1` manually to inspect the exact format,
and adjust `snapshot_exists` in `lib/common.sh` accordingly.

## What is NOT set up for you

This lab stops before `kubeadm init` by design — the exam requires you to bootstrap
the cluster yourself. Not pre-configured:

- Kubernetes cluster (no `kubeadm init`, no `join`)
- CNI (you choose: Flannel, Calico, Cilium)
- Helm, Kustomize
- Ingress controller, Metrics Server, storage provisioner
- Any namespaced workloads

That is correct — you learn by doing it, not by inheriting it.

## Quick reference card

| Action | Command |
|--------|---------|
| Build lab | `./cka-lab.sh up` |
| Status | `./cka-lab.sh status` |
| SSH to control1 | `vagrant ssh control1` |
| SSH to worker1 | `vagrant ssh worker1` |
| Halt lab | `./cka-lab.sh down` |
| Save snapshot | `./cka-lab.sh save <name>` |
| Restore snapshot | `./cka-lab.sh restore <name>` |
| List snapshots | `./cka-lab.sh snapshots` |
| Node validation | `./cka-lab.sh validate` |
| Bootstrap cluster | `vagrant ssh control1 -c 'bash /vagrant/bootstrap_cp.sh'` |
| Join worker | `vagrant ssh worker1 -c 'bash /vagrant/join_worker.sh'` |
| Destroy all VMs | `vagrant destroy -f` |

Node IPs: control1 `192.168.50.10`, worker1 `.11`, worker2 `.12`. Credentials: vagrant/vagrant.
