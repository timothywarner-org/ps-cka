# Vagrant snapshot cheat sheet for CKA Course 2.
# Read this file. Don't run it. Copy the line you need.
#
# All commands run from the lab dir (where the Vagrantfile lives):
#   cd C:\github\ps-cka\src\cka-lab
#
# `vagrant snapshot` applies to every VM in the Vagrantfile atomically
# (control1, worker1, worker2). On Hyper-V each one becomes a per-VM checkpoint.


# --- SAVE ----------------------------------------------------------------

# After Module 1 finishes (host prereqs done, NO kubeadm init yet).
# This is your clean baseline for re-running Modules 2 + 3.
vagrant snapshot save pre-cluster-install

# After Module 3 finishes (cluster bootstrapped, Calico installed, validated).
# This is Course 3's starting point.
vagrant snapshot save post-install


# --- RESTORE -------------------------------------------------------------

# Rewind to the M1 finish line. ~60-90 sec across all 3 VMs.
vagrant snapshot restore pre-cluster-install

# Rewind to the M3 finish line.
vagrant snapshot restore post-install


# --- HOUSEKEEPING --------------------------------------------------------

# See what snapshots exist right now.
vagrant snapshot list

# Delete a snapshot by name (needed before re-saving with the same name;
# `vagrant snapshot save` errors if the name is already taken).
vagrant snapshot delete pre-cluster-install
