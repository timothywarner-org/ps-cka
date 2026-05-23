# Vagrant lifecycle cheat sheet for the CKA Course 2 Hyper-V lab.
# Read this file. Don't run it. Copy the line you need.
#
# All commands run from the lab dir (where the Vagrantfile lives):
#   cd C:\github\ps-cka\src\cka-lab
#
# The lab is 3 VMs: control1, worker1, worker2. A bare `vagrant <cmd>`
# acts on all 3; append a VM name to act on just one.
#
# Run the PowerShell window AS ADMINISTRATOR -- Hyper-V cmdlets that
# Vagrant calls under the hood fail confusingly without elevation.
#
# Pairs with c02-snapshots.ps1 (the `vagrant snapshot` cheat sheet).


# --- SHUT DOWN (keep the VMs, just power them off) -----------------------

# Graceful shutdown of all 3 VMs. Sends a clean ACPI/OS shutdown, so
# kubelet, etcd, and containerd stop in order and the disks stay healthy.
# THIS is the one you want at the end of a work session.
vagrant halt

# Force power-off if a VM is wedged and `halt` hangs. Equivalent to
# yanking the cord -- only when graceful refuses. etcd recovers on next
# boot, but don't make a habit of it.
vagrant halt --force

# Shut down just one VM (e.g. to free RAM but leave the control plane up).
vagrant halt worker2


# --- RESTART / BRING BACK UP ---------------------------------------------

# Boot all 3 VMs again. Because the VMs already exist, `up` just powers
# them on -- it does NOT re-run provisioning. ~1-2 min to all-up.
# This is your normal "start the lab back up" command.
vagrant up

# Boot one VM only. Bring up control1 FIRST after a full shutdown so the
# API server and etcd are ready before the workers' kubelets reconnect.
vagrant up control1

# Reload = halt + up in one step. Use this after you EDIT the Vagrantfile
# (CPU, RAM, network) -- plain `up` ignores Vagrantfile changes on an
# existing VM; `reload` re-applies them.
vagrant reload

# Reload AND force a provisioning re-run (re-runs the shell provisioner).
vagrant reload --provision


# --- SUSPEND vs HALT (know the difference) -------------------------------

# Suspend = freeze RAM to disk. Resume is near-instant, BUT it writes a
# multi-GB save-state file per VM and the frozen clock can confuse
# kubelet/etcd cert + lease timers on resume.
# For VMs you keep LONG-TERM, prefer `vagrant halt` over suspend.
vagrant suspend

# Wake VMs that were suspended (not halted -- use `up` for halted VMs).
vagrant resume


# --- STATUS & INSPECTION (read-only, safe to run anytime) ----------------

# State of the 3 VMs in THIS lab (running / poweroff / saved).
vagrant status

# Every Vagrant environment on the whole machine, across all folders.
# Use this when you forget where a stray VM lives.
vagrant global-status

# Prune dead entries from the global-status list after a destroy.
vagrant global-status --prune

# SSH into a node. Workers join via control1, so it's the usual target.
vagrant ssh control1

# Print the SSH connection details (host, port, key) -- handy for
# wiring up VS Code Remote-SSH or scp.
vagrant ssh-config control1


# --- PROVISIONING --------------------------------------------------------

# Re-run the shell provisioner against running VMs WITHOUT rebooting.
# Use after you tweak the provisioning script in the Vagrantfile.
vagrant provision

# Boot freshly-created VMs but skip provisioning (rare -- debugging only).
vagrant up --no-provision


# --- DESTROY (nuke the VMs -- you lose the cluster) ----------------------

# Delete all 3 VMs and their disks. `-f` skips the y/n prompt.
# Snapshots go with them. Only when you're truly done with the lab.
vagrant destroy -f

# Destroy just one VM (e.g. rebuild a single broken worker).
vagrant destroy -f worker1
