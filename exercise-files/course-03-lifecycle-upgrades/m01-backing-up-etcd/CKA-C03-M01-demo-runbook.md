# CKA Course 3 / Module 1 -- Backing Up etcd  (Demo Runbook, final cut)

**Target runtime:** 12-13 min on camera (4 demo beats, one per learning objective)
**Environment:** your host terminal for **standard SSH**; everything else runs on `control1`. kubectl v1.35.
**Lab:** the **Hyper-V Vagrant real-VM cluster** = **1 control plane + 2 workers**, K8s v1.35. VMs: `control1` (192.168.50.10), `worker1` (192.168.50.11), `worker2` (192.168.50.12). Boot it with the Course 3 controls (`.\Start-CkaLab.ps1` from `src\cka-lab\course-03-lifecycle-upgrades`), then SSH in from any terminal: `ssh vagrant@192.168.50.10` (password `vagrant`).
**Authoritative demo commands:** `commands.sh` (this folder) -- copy-paste, in demo order, byte-identical to the deck code slides.
**Last verified: 2026-06-21**

**The one fact that runs this whole module (etcd 3.6, kubeadm 1.34+ default):** `snapshot save` is an online call against the live cluster, so it stays in **etcdctl**. `snapshot status` and `snapshot restore` work on the file offline, so as of etcd 3.6 they moved to **etcdutl**. Say it once: **save = etcdctl, status + restore = etcdutl.** That single line is an exam-grade nugget.

**The story (matches the deck):** Globomantics admin **Kai** gets the 2 a.m. page. We stage real production state, snapshot etcd, blow the whole namespace away, then bring it all back from the snapshot. The four beats below are the four framing questions from the slides, in order.

---

## Bash-to-Windows quick reference (glance, don't read aloud)

For PowerShell learners crossing over. The talk track drops these analogies inline as each command runs.

| Linux / bash here | Windows analogue | What it does |
| --- | --- | --- |
| `ls`, `kubectl get all` | `dir` / `Get-ChildItem` | list what is there |
| `cat file` | `type` / `Get-Content` | print a file |
| `mv a b` | `Move-Item` / `move` | move or rename |
| `rm -f` | `Remove-Item` / `del` | delete |
| `sudo <cmd>` | "Run as administrator" / elevation | run with admin rights |
| `curl -L ... \| tar xz` | `Invoke-WebRequest` + `Expand-Archive` | download and unpack |
| `sed -i 's#old#new#' f` | `(Get-Content f) -replace ... \| Set-Content` | find-and-replace in a file |
| `ssh vagrant@192.168.50.10` | `Enter-PSSession` / SSH into a box | open a shell on control1 |

---

## Setup -- pre-flight bookend (run BEFORE you record, off camera)

```bash
# 0) Boot the lab with the Course 3 controls (admin PowerShell 7), from
#    src\cka-lab\course-03-lifecycle-upgrades:
#      .\Start-CkaLab.ps1                       # powers on control1 + worker1 + worker2
#      .\Save-CkaSnapshot.ps1 m01-cluster-ready # clean restore point for re-records

# 1) SSH into control1 with standard SSH (from any terminal), confirm three nodes Ready.
ssh vagrant@192.168.50.10               # password: vagrant
kubectl get nodes                       # expect control1 + worker1 + worker2, all Ready

# 2) Stage etcdctl + etcdutl on control1 so the demo matches the deck.
#    A fresh kubeadm VM doesn't ship them; they live in the etcd release tarball.
#    Auto-match the version to YOUR cluster so the on-screen version never drifts:
ETCD_VER=v$(sudo grep -m1 'image:.*etcd' /etc/kubernetes/manifests/etcd.yaml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
echo "staging etcd $ETCD_VER"
cd /tmp && curl -sL \
  https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  | tar xz
sudo cp etcd-${ETCD_VER}-linux-amd64/etcdctl etcd-${ETCD_VER}-linux-amd64/etcdutl /usr/local/bin/
etcdctl version && etcdutl version      # both resolve, so you're ready

# 3) Clean slate: no leftover demo namespace, no stale snapshot.
kubectl delete ns globomantics-shop --ignore-not-found
sudo rm -f /tmp/etcd-backup.db && sudo rm -rf /var/lib/etcd-restored

# 4) Dry-run the whole demo path once, off camera, then reset to zero for the take.
bash commands.sh
```

**Camera checklist:** terminal font 16pt+ / 140 cols, short prompt (`PS1='$ '`), 1080p scaling, kube context on the Vagrant cluster, nothing stale in `/tmp`. Tim's rule: test-run the whole path once off camera and re-run until nothing surprises you, then reset to zero for the take.

---

## Open (30 sec)

> Welcome back to training. Tim Warner here, and in this one we're gonna protect the single most important pile of data in the entire cluster, and that's etcd. Here's the plan. I'll stand up some real production state, snapshot etcd, then delete the whole namespace to play out a true 2 a.m. disaster for our Globomantics admin Kai, and we'll bring every last bit of it back from that one snapshot. Pop quiz at the end: I'll make you tell me which binary owns restore now, because that one moved and the exam absolutely loves it. Let's get rolling.

---

## Beat 1 -- Stage the production data (LO 1: what etcd stores)

**Goal:** create the state we're about to lose, so the recovery is visible later.

```bash
kubectl create namespace globomantics-shop
kubectl create deployment catalog-api --image=nginx --replicas=3 -n globomantics-shop
kubectl create configmap catalog-config --from-literal=env=production -n globomantics-shop
kubectl get all -n globomantics-shop
```

> First, let's create something worth protecting. I'm spinning up the Globomantics shop namespace, a catalog API Deployment with three replicas, and a ConfigMap for its settings. Now watch the mental model, because this is the heart of the module. The instant I create any of these, the API server writes them as rows into etcd. etcd is the cluster's single source of truth, so if it's in your cluster, it's stored in etcd, and one snapshot of that one database backs up all of it. And that last command, kubectl get all, is just your dir or your ls; it's listing everything we've got in this namespace.

**Point at:** the namespace, a Deployment with 3 ready replicas, its ReplicaSet, 3 Pods, and the ConfigMap.

**If it breaks:** if Pods sit Pending, the workers are still joining. Run `kubectl get nodes`, wait for Ready, and re-run the get. It doesn't touch the etcd steps.

**Pause point** -- stop the clip once `kubectl get all -n globomantics-shop` shows everything Running.

---

## Beat 2 -- Back up etcd, then verify it (LO 2: snapshot, and which binary)

**Goal:** take a live snapshot with etcdctl, then prove it with etcdutl.

```bash
sudo etcdctl snapshot save /tmp/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
sudo etcdutl snapshot status /tmp/etcd-backup.db --write-out=table
```

> Now the backup itself. The command is etcdctl snapshot save, and notice I'm running it with sudo, because the etcd server key is root-only; without it you get permission denied, not a backup. I'm pointing it at the live database over the network. Because it's a network call, etcd demands mutual TLS, so I hand it the endpoint plus three certificate files: the CA, the client cert, and the key. Miss one and you get a handshake error, not a friendly hint, so treat those three flags as a single unit. Think of etcdctl as the network client here, the same way you'd reach for Invoke-WebRequest in PowerShell to talk to a live service.

> Then I verify the file with etcdutl snapshot status, and notice the binary just changed on me. Reading the file is an offline job, so as of etcd 3.6 that work moved off etcdctl and onto etcdutl. One thing worth knowing: neither etcdctl nor etcdutl ships with kubeadm, so I staged them off camera from the official etcd release. If etcdutl isn't on your cluster, that's why. And I'm still using sudo, because the snapshot file we just wrote is owned by root. And I'm using etcdutl right here on a low-stakes verify on purpose, so it's already familiar by the time we rely on it for the whole cluster one beat from now. It takes no certificate flags at all, because we're reading a local file instead of the live cluster. And here's the exam trap people copy-paste straight into a failure: those certificate flags from the save command, the cacert, cert, and key, don't belong on etcdutl. It works right off the snapshot file offline, so paste them in and it errors out with an unknown flag. Drop them, point at the file, and you'll get a clean status table.

**Point at:** the status table with the snapshot's hash, revision, total keys, and total size. That's a verified backup.

**If it breaks:** `etcdctl snapshot status` errors on 3.6; that's the lesson, switch to etcdutl. If save throws a TLS error, re-check the three cert paths under `/etc/kubernetes/pki/etcd`. Both commands need `sudo`: the etcd `server.key` is root-only (0600), so a bare save returns `permission denied`, and the saved snapshot is root-owned so the etcdutl verify needs `sudo` too. Don't prefix `ETCDCTL_API=3` on etcd 3.6 -- it prints an `unrecognized environment variable` warning on screen.

**Pause point** -- stop the clip on the status table.

---

## Beat 3 -- Simulate the disaster, then restore (LO 3: the full restore workflow)

**Goal:** delete the namespace, then bring the cluster back from the snapshot with etcdutl. This is the five-step restore the exam will test.

```bash
kubectl delete namespace globomantics-shop                  # the 2 a.m. disaster

sudo mv /etc/kubernetes/manifests/kube-apiserver.yaml /tmp/  # 1) stop the API server
sudo etcdutl snapshot restore /tmp/etcd-backup.db \
  --data-dir=/var/lib/etcd-restored                         # 2) restore to a NEW dir
sudo sed -i 's#/var/lib/etcd$#/var/lib/etcd-restored#' \
  /etc/kubernetes/manifests/etcd.yaml                       # 3) repoint etcd at it
sudo mv /tmp/kube-apiserver.yaml /etc/kubernetes/manifests/ # 4) bring the API server back

kubectl get nodes                                           # 5) verify
kubectl get all -n globomantics-shop
```

> Okay, here's our 2 a.m. disaster. I delete the Globomantics namespace, and just like that the Deployment, the ReplicaSet, the Pods, and the ConfigMap are gone. This is Kai's pager going off. Now we earn the paycheck and bring it all back, and restore is a five-step dance you want in muscle memory.

> Step one, stop the API server. I move its static Pod manifest out of the manifests folder, and on Linux mv is exactly PowerShell's Move-Item. The kubelet watches that directory, so the moment the file is gone, it stops the API server Pod. Step two, etcdutl snapshot restore, and notice it's etcdutl again with no certificate flags, because we're rebuilding from the file. I restore into a brand-new data directory, never on top of the live one. Because this is a single stacked etcd member, the restore defaults are enough. For a multi-member etcd, that's when you add the name, initial-cluster, and peer-url flags so each member comes back with the right identity. Step three is the one everybody forgets: I repoint etcd at that new directory. That sed one-liner is just a find-and-replace inside the etcd manifest, the same idea as Get-Content piped to a replace in PowerShell, or Notepad's Find and Replace, swapping the old data path for the new one. Step four, I slide the API server manifest back, and the kubelet restarts both etcd and the API server. Step five, verify.

> Give it a few seconds, and there we go. Nodes Ready, and the Globomantics shop is back with its catalog API and its config, exactly as it stood at snapshot time. That's the payoff: total loss to healthy in a couple of minutes, all from one file.

**Point at:** after a few seconds, nodes Ready, and `globomantics-shop` restored with catalog-api and catalog-config.

**If it breaks:** if kubectl hangs right after, the API server is still coming up; wait and retry. On the VM you're the `vagrant` user, so keep `sudo` on the privileged steps. If etcdutl isn't found, you skipped the pre-flight staging step.

**Pause point** -- stop the clip once the recovered objects are listed.

---

## Beat 4 -- Stacked vs external etcd (LO 4: topology comparison)

**Goal:** show the topology we just recovered, and contrast it with external etcd.

```bash
kubectl get pods -n kube-system -l component=etcd -o wide
```

> Last thing, and this closes the loop on the restore we just pulled off. Remember how every restore step -- moving the API server manifest, editing etcd.yaml -- happened right here on one node? That only worked because of our topology. Let me list the etcd Pod, and you can see it's named etcd-control1, running on the control plane node. That's stacked etcd, kubeadm's default: etcd runs on the same VM as the API server. It's dead simple to run, but if that node dies, you lose a control-plane member and an etcd member at the same moment. The alternative is external etcd, where etcd runs on its own dedicated VMs. You get more resilience, but more to manage. And here's the precise exam point: you don't flip external etcd on with a command-line flag, because there isn't one. You declare it in the kubeadm config file, under ClusterConfiguration etcd external, then run kubeadm init with that config.

**Point at:** the etcd Pod named `etcd-control1`, running on the control-plane node.

**If it breaks:** if the label selector returns nothing, the etcd Pod may still be restarting from Beat 3. Give it a moment and re-run.

**Pause point** -- stop the clip after the topology explanation.

---

## Outro (30-60 sec)

> So that's etcd backup and restore, start to finish. Remember the pop quiz from the top -- which binary owns restore now? It's etcdutl. Snapshot save stays in etcdctl with the endpoint and the three certificate flags, but status and restore moved to etcdutl back in etcd 3.6, and they take no certificate flags, because they read the file offline. Restore is that five-step dance: stop the API server, restore to a new directory, repoint etcd, bring the API server back, and verify. Drill it until it's automatic, because the exam hands you a snapshot and a ticking clock. Next module, we use this exact backup as our safety net while we upgrade the cluster with kubeadm. I hope you found this one helpful. Give it a like if you did, and I'll see you in the next one.

---

## Teardown -- bookend (run AFTER the take)

```bash
# Reset to zero between takes (run on control1 over SSH)
kubectl delete ns globomantics-shop --ignore-not-found
sudo rm -f /tmp/etcd-backup.db && sudo rm -rf /var/lib/etcd-restored
# If you ran a restore take, point etcd.yaml back at the LIVE data dir:
sudo sed -i 's#/var/lib/etcd-restored#/var/lib/etcd#' /etc/kubernetes/manifests/etcd.yaml
exit            # close the SSH session back to your host

# Cleanest re-record (admin PowerShell 7): rewind all 3 VMs to the setup snapshot
#   .\Restore-CkaSnapshot.ps1 m01-cluster-ready
# Done for the day? Park the VMs (M02 reuses this cluster, so halt, never destroy):
#   .\Stop-CkaLab.ps1
```

---

## Exam pocket card

| Operation | Binary (etcd 3.6+) | Command |
| --- | --- | --- |
| Snapshot (online) | **etcdctl** | `etcdctl snapshot save <file>` + `--endpoints --cacert --cert --key` |
| Verify (offline) | **etcdutl** | `etcdutl snapshot status <file> --write-out=table` |
| Restore (offline) | **etcdutl** | `etcdutl snapshot restore <file> --data-dir=<newdir>` |
| Cert paths | -- | `/etc/kubernetes/pki/etcd/{ca.crt,server.crt,server.key}`, endpoint `https://127.0.0.1:2379` |
| Restore order | -- | stop API server, restore to NEW dir, repoint `etcd.yaml`, restart, verify |
| External etcd | -- | kubeadm **config file** (`ClusterConfiguration.etcd.external`), not a flag |

**Exam tip -- Distractor Watch:** on a current cluster, `etcdctl snapshot status` and `etcdctl snapshot restore` are the trap. Since etcd 3.6 they live in **etcdutl**; only `save` stayed in etcdctl. And etcdutl takes no TLS flags, because it reads the file offline.

---

## Sources (verified 2026-06-21)

- etcd v3.6 announcement -- status/restore moved to etcdutl: <https://etcd.io/blog/2025/announcing-etcd-3.6/>
- Announcing etcd v3.6.0 (Kubernetes blog): <https://kubernetes.io/blog/2025/05/15/announcing-etcd-3.6/>
- Operating etcd clusters for Kubernetes (etcdctl vs etcdutl; restore): <https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/>
- etcd disaster recovery (etcdutl snapshot restore / status): <https://etcd.io/docs/v3.6/op-guide/recovery/>
- etcdutl README (offline data-file tool; no TLS flags): <https://github.com/etcd-io/etcd/blob/main/etcdutl/README.md>
- Use etcdutl instead of etcdctl for restore (k8s website issue #44216): <https://github.com/kubernetes/website/issues/44216>
- kubeadm default etcd 3.5.x to 3.6: <https://github.com/kubernetes/kubeadm/issues/3247>
- kubeadm config API (external etcd via ClusterConfiguration): <https://kubernetes.io/docs/reference/config-api/kubeadm-config.v1beta4/>
- CKA program (Feb 2025 revision): <https://training.linuxfoundation.org/certified-kubernetes-administrator-cka-program-changes/>
