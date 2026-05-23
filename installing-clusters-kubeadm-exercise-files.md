# Installing Clusters with kubeadm - Exercise Files

**Course 2 of 11** in Tim Warner's **Certified Kubernetes Administrator (CKA) v1.35 Skill Path** on Pluralsight.
Aligned to the **CKA v1.35 (February 2025) curriculum** revision.

[![Author](https://img.shields.io/badge/Author-Tim%20Warner-0078D4?style=for-the-badge&logo=pluralsight&logoColor=white)](https://TechTrainerTim.com)
[![Website](https://img.shields.io/badge/Website-TechTrainerTim.com-1F6FEB?style=for-the-badge&logo=googlechrome&logoColor=white)](https://TechTrainerTim.com)
[![Email](https://img.shields.io/badge/Email-tim%40techtrainertim.com-EA4335?style=for-the-badge&logo=gmail&logoColor=white)](mailto:tim@techtrainertim.com)

> Pluralsight author, Microsoft MVP, 200+ courses published.

---

## The exercise files live on GitHub - not in this download

> **Heads up:** This file is a **pointer**. Every manifest, Vagrantfile, provisioning script, demo runbook, and validation script for this course lives in the public GitHub repo below. Bookmark it, clone it, and keep it open while you watch the videos.

<p align="center">
  <a href="https://github.com/timothywarner/ps-cka">
    <img src="https://img.shields.io/badge/GO%20TO%20THE%20REPO-timothywarner%2Fps--cka-2EA043?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117" alt="Go to the course repository on GitHub" height="60">
  </a>
</p>

<p align="center">
  <a href="https://github.com/timothywarner/ps-cka/stargazers"><img src="https://img.shields.io/github/stars/timothywarner/ps-cka?style=flat-square&logo=github&color=FFD33D" alt="GitHub stars"></a>
  <a href="https://github.com/timothywarner/ps-cka"><img src="https://img.shields.io/badge/Kubernetes-v1.35-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="Kubernetes v1.35"></a>
  <a href="https://github.com/timothywarner/ps-cka"><img src="https://img.shields.io/badge/CKA-Feb%202025%20Curriculum-1F6FEB?style=flat-square" alt="CKA Feb 2025 curriculum"></a>
  <a href="https://github.com/timothywarner/ps-cka"><img src="https://img.shields.io/badge/kubeadm-v1.35-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="kubeadm v1.35"></a>
  <a href="https://github.com/timothywarner/ps-cka"><img src="https://img.shields.io/badge/containerd-CRI-575757?style=flat-square&logo=containerd&logoColor=white" alt="containerd as CRI"></a>
  <a href="https://github.com/timothywarner/ps-cka"><img src="https://img.shields.io/badge/Calico-CNI-FF8C00?style=flat-square" alt="Calico as CNI"></a>
  <a href="https://github.com/timothywarner/ps-cka"><img src="https://img.shields.io/badge/License-See%20Repo-lightgrey?style=flat-square" alt="License: see repo"></a>
  <a href="https://TechTrainerTim.com"><img src="https://img.shields.io/badge/Maintained%20by-Tim%20Warner-0078D4?style=flat-square&logo=microsoft&logoColor=white" alt="Maintained by Tim Warner"></a>
</p>

---

## What this course covers

Course 2 is where you graduate from **kind containers** to **real Linux VMs**. `kubeadm init` and `kubeadm join` need systemd, a real kubelet process, and kernel-level networking that Docker containers cannot provide. The CKA exam tests this directly, so this course is built around the actual binaries and config files you will be asked to operate under a timer.

Three modules, ~90 minutes total:

1. **Module 1** - Preparing Linux Hosts and Container Runtime Dependencies
2. **Module 2** - Bootstrapping a Cluster with kubeadm init and join
3. **Module 3** - Installing a CNI Plugin and Validating Cluster Health

**Primary exam domain:** Cluster Architecture, Installation and Configuration (25%). Reinforced patterns from Troubleshooting (30%).

---

## What's in the repo

Welcome - I'm Tim, and here's the lay of the land when you arrive at [github.com/timothywarner/ps-cka](https://github.com/timothywarner/ps-cka):

- **`m01-linux-host-prep/`** - Module 1 demo runbook, Vagrantfile, provisioning scripts. Kernel modules, sysctl, swap, containerd install, kubeadm/kubelet/kubectl install from `pkgs.k8s.io`, version pinning with `apt-mark hold`.
- **`m02-kubeadm-init-join/`** - Module 2 demo runbook. `kubeadm init` on the control plane, walkthrough of the static pod manifests in `/etc/kubernetes/manifests/`, admin kubeconfig setup, `kubeadm join` on the workers, bootstrap token refresh with `kubeadm token create --print-join-command`.
- **`m03-cni-cluster-validation/`** - Module 3 demo runbook. Calico install, transition from `NotReady` to `Ready`, CoreDNS health check, cross-node pod connectivity test, intentional kubelet break/fix drill with `journalctl -u kubelet`, NodePort smoke test with nginx.
- **`src/cka-lab/`** - Both lab paths in one place:
  - **KIND path** (carried over from Course 1) - for quick kubectl practice between kubeadm drills.
  - **Hyper-V Vagrant lab** - three Ubuntu 22.04 VMs (`control1`, `worker1`, `worker2`), 2 GB / 2 vCPU each, static IPs on the `CKA-NAT` Hyper-V switch, kubeadm v1.35 prereqs pre-installed. Stops **before** `kubeadm init` so you bootstrap from scratch, the same way the exam does.
- **`src/cka-lab/TUTORIAL-HYPERV.md`** - The full learner walkthrough for the Vagrant lab, including the native Hyper-V checkpoint snapshot/restore loop.

> **Cross-platform note:** The repo defaults to Hyper-V because that's my recording rig (Windows 11, 128 GB RAM, i9-11900). The Vagrantfile pattern is identical on **VirtualBox 7.x** for macOS and Linux learners - same three VMs, same provisioning, same commands.

---

## Quick start (three commands)

```powershell
git clone https://github.com/timothywarner/ps-cka.git
cd ps-cka
./src/cka-lab/Start-HyperVLab.ps1     # provisions 3 VMs, stops before kubeadm init
```

That's it. Open the Module 1 runbook, follow along with the video, and the cluster you build will carry forward into Modules 2 and 3.

---

## What makes this course different

Most kubeadm tutorials skip the prerequisites and assume the host is already prepared. That's exactly where exam candidates lose points. This course does the opposite:

- **Every prerequisite is justified.** Why does `br_netfilter` need to be loaded? Why does `net.bridge.bridge-nf-call-iptables` matter? Why does swap have to be off? You get the answer **before** you run the command.
- **The kubeadm output gets walked line by line.** Certificates, static pod manifests, kubeconfig files, join command - nothing is a black box.
- **The CNI decision is defended, not just executed.** Calico is chosen because it supports NetworkPolicies (tested in Courses 7 and 8) and because its default pod CIDR aligns with the kubeadm init flag you set.
- **Break/fix is built into the demos.** Module 3 intentionally stops the kubelet so you watch `NotReady` happen in real time, then recover with the same `journalctl` workflow you will use on the exam.

---

## Resource library - verified May 2026

Every link below was verified live. Grouped by module so you can read alongside each video.

### Module 1 - Linux host prep and container runtime

**Kubernetes official docs**

- [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/) - Canonical reference for the prereq stack: `overlay` and `br_netfilter` kernel modules, `net.ipv4.ip_forward`, `net.bridge.bridge-nf-call-iptables`, swap guidance, and per-runtime install steps.
- [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) - The authoritative kubeadm prereq page. RAM, CPU, MAC and product\_uuid uniqueness, required ports, swap, and the install flow for `kubeadm`, `kubelet`, `kubectl`.
- [Container Runtimes - containerd section](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd) - The `/etc/containerd/config.toml` settings, including the **`SystemdCgroup = true`** flag the Module 1 demo flips.
- [Container Runtime Interface (CRI)](https://kubernetes.io/docs/concepts/architecture/cri/) - Concept page explaining the kubelet to runtime gRPC contract. The "why containerd, not Docker" lecture beat.
- [Installing kubeadm, kubelet and kubectl](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-kubeadm-kubelet-and-kubectl) - The `pkgs.k8s.io` apt setup plus `apt-mark hold` version-pin steps used in the demo.
- [Debugging Kubernetes nodes with crictl](https://kubernetes.io/docs/tasks/debug/debug-cluster/crictl/) - Official `crictl` user guide. Module 1 uses `crictl info` and `crictl ps` to prove containerd is healthy before kubeadm touches it.

**containerd project**

- [Getting started with containerd](https://containerd.io/docs/getting-started/) - Official getting-started for containerd 2.3 (binaries, apt, dnf, build-from-source).
- [CRI Plugin Config Guide](https://github.com/containerd/containerd/blob/main/docs/cri/config.md) - Live CRI integration doc covering cgroup drivers, snapshotters, runtime classes, and registry config.
- [containerd releases](https://github.com/containerd/containerd/releases) - Release feed. Use it to confirm which release your distro is pulling.

**Linux kernel and system tooling**

- [modprobe(8)](https://man7.org/linux/man-pages/man8/modprobe.8.html) - Canonical kmod docs behind the `modprobe overlay` and `modprobe br_netfilter` steps.
- [sysctl(8)](https://man7.org/linux/man-pages/man8/sysctl.8.html) - Canonical procps-ng docs behind `sysctl --system` after writing `/etc/sysctl.d/k8s.conf`.
- [journalctl(1)](https://man7.org/linux/man-pages/man1/journalctl.1.html) - Backs `journalctl -u kubelet -f` and `journalctl -u containerd` throughout the course.

**Kubernetes apt repository**

- [Introducing Kubernetes Community-Owned Package Repositories (pkgs.k8s.io)](https://kubernetes.io/blog/2023/08/15/pkgs-k8s-io-introduction/) - The canonical setup instructions page. The legacy `apt.kubernetes.io` host was retired March 4, 2024.

**Vagrant and VirtualBox (for non-Hyper-V learners)**

- [Vagrant - Development Environments Made Easy](https://developer.hashicorp.com/vagrant) - Official Vagrant landing on HashiCorp Developer.
- [ubuntu/jammy64 - HCP Vagrant Registry](https://portal.cloud.hashicorp.com/vagrant/discover/ubuntu/jammy64) - Canonical Ubuntu 22.04 box used by the Vagrantfile.
- [Oracle VirtualBox Downloads](https://www.virtualbox.org/wiki/Downloads) - Official download page. Current GA: VirtualBox 7.2.8.

**crictl**

- [kubernetes-sigs/cri-tools](https://github.com/kubernetes-sigs/cri-tools) - Upstream repo for `crictl` and `critest`.

---

### Module 2 - kubeadm init and join

**kubeadm command reference**

- [Kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/) - Landing page for the kubeadm tool. Start here before any `init` or `join` keystroke.
- [kubeadm init](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/) - Authoritative flag reference for control-plane bootstrap: `--pod-network-cidr`, `--apiserver-advertise-address`, `--control-plane-endpoint`, and friends.
- [kubeadm join](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/) - Worker-join flag reference covering token, discovery CA hash, and certificate-key flows.
- [kubeadm token](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-token/) - Bootstrap-token lifecycle: `create`, `list`, `delete`, and the demo-critical `--print-join-command`.
- [kubeadm certs](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-certs/) - `check-expiration` and `renew` subcommands plus `certificate-key` for HA certificate uploads.
- [kubeadm reset](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-reset/) - Best-effort revert path so you can rerun the demos cleanly between takes.
- [kubeadm config](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-config/) - `print init-defaults` and `print join-defaults` for the declarative ClusterConfiguration workflow.

**kubeadm setup guides**

- [Creating a cluster with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/) - End-to-end walkthrough that mirrors the Module 2 demo arc.
- [Customizing components with the kubeadm API](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/control-plane-flags/) - How `ClusterConfiguration`, `InitConfiguration`, and `JoinConfiguration` patch the static-pod manifests.
- [Creating Highly Available Clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/) - Stacked vs external etcd. Preview reading for Course 3. Explains why `--control-plane-endpoint` matters even at single-control-plane init time.
- [Configuring each kubelet in your cluster using kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/) - KubeletConfiguration propagation, `/var/lib/kubelet/config.yaml`, and the kubelet systemd drop-in.

**Certificates and PKI**

- [PKI certificates and requirements](https://kubernetes.io/docs/setup/best-practices/certificates/) - Canonical map of every cert kubeadm generates in `/etc/kubernetes/pki` and which component consumes it.
- [Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/) - Renewal cadence, external-CA mode, and the `/etc/kubernetes/pki` directory contract.

**Static pods**

- [Create static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/) - Explains the `/etc/kubernetes/manifests` watcher pattern that makes the kubeadm control plane self-hosting.

**kubeconfig**

- [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/) - Why you copy `admin.conf` to `~/.kube/config` post-init.
- [kubectl config](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_config/) - Subcommand reference for `view`, `use-context`, `set-context` against the kubeconfig kubeadm produces.

**Bootstrap tokens and TLS bootstrapping**

- [TLS bootstrapping](https://kubernetes.io/docs/reference/access-authn-authz/kubelet-tls-bootstrapping/) - How a joining kubelet exchanges a bootstrap token for a signed client certificate.
- [Authenticating with Bootstrap Tokens](https://kubernetes.io/docs/reference/access-authn-authz/bootstrap-tokens/) - Token format (`[a-z0-9]{6}.[a-z0-9]{16}`), TTL, and the `system:bootstrappers` group binding.

**Control plane components**

- [kube-apiserver](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/) - Flag reference, useful when you crack open `/etc/kubernetes/manifests/kube-apiserver.yaml`.
- [kube-controller-manager](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/) - Flag reference, explains `--cluster-cidr` and the controller loops that materialize after init.
- [kube-scheduler](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/) - Flag reference for the third static-pod manifest kubeadm drops.
- [etcd](https://etcd.io/) - Official etcd project home. etcd is an independent CNCF project even when stacked on the control plane.

**Adjacent v1.35 reference**

- [CHANGELOG-1.35.md](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.35.md) - Authoritative v1.35 release notes for the version this course pins to.

---

### Module 3 - CNI install and cluster validation

**CNI specification**

- [containernetworking/cni](https://github.com/containernetworking/cni) - Official CNI spec repo (CNCF-maintained, current v1.3.0).
- [CNI Specification (SPEC.md)](https://github.com/containernetworking/cni/blob/main/SPEC.md) - The 5-minute "this is what kubelet hands the plugin" reference that justifies the plugin model.
- [containernetworking/plugins](https://github.com/containernetworking/plugins) - Reference plugins (bridge, host-local IPAM, loopback). Useful for seeing what a minimal CNI looks like before adopting Calico.

**Calico (Project Calico / Tigera)**

- [About Calico](https://docs.tigera.io/calico/latest/about/) - Official docs landing for Calico v3.32. Single source of truth for the install workflow used in the demo.
- [Calico quickstart](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart) - The kind-based 5-minute install path. Useful comparison for the on-prem Vagrant install.
- [Install Calico for on-premises deployments](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises) - Tigera operator vs raw manifest install paths. Directly applicable to the Vagrant kubeadm lab.
- [projectcalico/calico](https://github.com/projectcalico/calico) - Source repo, release artifacts, issue tracker.
- [Calico v3.32.0 release](https://github.com/projectcalico/calico/releases/tag/v3.32.0) - Current stable release notes. Version-pin reference for module manifests.
- [Configure the Calico CNI plugins](https://docs.tigera.io/calico/latest/reference/configure-cni-plugins) - IPAM, logging, and Kubernetes-specific knobs. Required reading when you hit the "why isn't my pod getting an IP" failure mode.

**CNI comparison reading (so you can defend the choice)**

- [flannel-io/flannel](https://github.com/flannel-io/flannel) - The simplest possible CNI baseline. Defend NOT picking Flannel for production NetworkPolicy work.
- [Cilium documentation](https://docs.cilium.io/en/stable/) - Cilium docs landing. The eBPF alternative you must be able to articulate vs Calico.
- [cilium/cilium](https://github.com/cilium/cilium) - eBPF networking source.
- [Cluster Networking](https://kubernetes.io/docs/concepts/cluster-administration/networking/) - Canonical concept page for the four networking problems Kubernetes solves.
- [Installing Addons - Networking and Network Policy](https://kubernetes.io/docs/concepts/cluster-administration/addons/) - Official kubernetes.io list of supported CNI providers.

**Cluster validation and the diagnostic ladder**

- [kubectl get](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_get/) - Rung 1 of the diagnostic ladder.
- [kubectl describe](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_describe/) - Rung 2 of the diagnostic ladder. Events live here.
- [kubectl logs](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/) - Rung 3, including `--previous` for CrashLoopBackOff post-mortems.
- [kubectl exec](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_exec/) - Required for the busybox cross-node ping and wget validation demo.
- [kubectl cluster-info](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_cluster-info/) - Control plane endpoint sanity check used in the module open.
- [Debug Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/) - Pending, Waiting, Terminating, CrashLoopBackOff triage tree.
- [Debug Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/) - DNS, EndpointSlices, kube-proxy verification path. Used in the NodePort validation demo.
- [Determine the Reason for Pod Failure](https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/) - Termination-message and exit-code analysis.
- [Debug Running Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/) - Ephemeral containers and `kubectl debug`. Preview reading for Course 10.

**CoreDNS and DNS**

- [Customizing DNS Service](https://kubernetes.io/docs/tasks/administer-cluster/dns-custom-nameservers/) - Corefile, ConfigMap, stub domains.
- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) - Naming rules (`svc.namespace.svc.cluster.local`) needed to interpret `nslookup` output in the validation demo.
- [CoreDNS: DNS and Service Discovery](https://coredns.io/) - Project home (CNCF graduated).

**kubelet diagnostics**

- [kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/) - Flag reference for the node agent.
- [Troubleshooting Clusters](https://kubernetes.io/docs/tasks/debug/debug-cluster/) - Control-plane and worker log locations. Required reading for the intentional-break recovery drill.
- [Troubleshooting kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/) - Includes the "CoreDNS Pending until CNI installed" gotcha that explains the demo's pre-Calico cluster state.

**Conformance and production validation**

- [vmware-tanzu/sonobuoy](https://github.com/vmware-tanzu/sonobuoy) - Official CNCF conformance tool. Use it to self-certify your cluster post-CNI install.
- [Certified Kubernetes Software Conformance](https://www.cncf.io/training/certification/software-conformance/) - CNCF program page. Explains why conformance matters for production.
- [Validate node setup](https://kubernetes.io/docs/setup/best-practices/node-conformance/) - Node Conformance Test reference.

**Adjacent quality reads**

- [Deep Dive: CNI - Bryan Boreham and Dan Williams (KubeCon)](https://www.youtube.com/watch?v=zChkx-AB5Xc) - Canonical KubeCon CNI deep-dive on the CNCF YouTube channel.
- [Securing Kubernetes Traffic with Calico Ingress Gateway (CNCF blog)](https://www.cncf.io/blog/2025/06/06/securing-kubernetes-traffic-with-calico-ingress-gateway/) - Ties the Module 3 Calico choice forward to the Gateway API content in Course 7.

---

## CKA exam and curriculum references

- [Certified Kubernetes Administrator (CKA) - Linux Foundation](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/) - Official exam page. Pricing, format, the five domains, validity.
- [Certified Kubernetes Administrator (CKA) - CNCF](https://www.cncf.io/training/certification/cka/) - CNCF mirror of the exam page with the same domain weights.
- [cncf/curriculum](https://github.com/cncf/curriculum) - Source of the `CKA_Curriculum_v1.35.pdf` (the February 2025 revision). Clone this to your study folder.

---

## One more time - go to the repo

<p align="center">
  <a href="https://github.com/timothywarner/ps-cka">
    <img src="https://img.shields.io/badge/CLONE%20THE%20REPO-github.com%2Ftimothywarner%2Fps--cka-2EA043?style=for-the-badge&logo=github&logoColor=white&labelColor=0D1117" alt="Clone the course repository" height="60">
  </a>
</p>

---

## Stay in touch

Thanks for taking this course - it genuinely means a lot. If you hit a snag, spot a bug, or just want to say hello, reach out:

- **Website:** [TechTrainerTim.com](https://TechTrainerTim.com)
- **Email:** [tim@techtrainertim.com](mailto:tim@techtrainertim.com)
- **YouTube:** [youtube.com/c/TechTrainerTim](https://www.youtube.com/c/TechTrainerTim)
- **LinkedIn:** [linkedin.com/in/timothywarner](https://www.linkedin.com/in/timothywarner)
- **Microsoft MVP profile:** [mvp.microsoft.com/timothywarner](https://mvp.microsoft.com/en-US/mvp/profile/e9a13bca-2798-4247-be56-f116f780869d)
- **Repo issues:** [github.com/timothywarner/ps-cka/issues](https://github.com/timothywarner/ps-cka/issues)

Now go pass that exam.

- **Tim Warner**
