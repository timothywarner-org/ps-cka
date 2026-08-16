================================================================
  CKA C04 / M01 -- RBAC FUNDAMENTALS
  EVERYTHING IS IN THIS FOLDER. TWO SCRIPTS TOTAL.
================================================================

  exercise-files\course-04-rbac-admission\m01-rbac-fundamentals\

    c04-m01-demo-runbook.md    <-- READ THIS. Second monitor.
    lab.sh                         reset | mint | verify  (the ONLY node script)
    frontend-dev-csr.yaml          the CSR lab.sh mint fills in
    pod-reader.yaml                the manifest Demo 4 generates
    README.md                      learner-facing blurb
    START-HERE.md                  this file

  The one file outside this folder:

    src\cka-lab\Initialize-C04M01Lab.ps1

  It must sit beside the Vagrantfile -- it dot-sources
  lib\CkaLab.ps1 and walks ..\..\exercise-files\ to push this
  folder onto the node. Move it and it breaks.

----------------------------------------------------------------
  TWO COMMANDS, START TO RECORD
----------------------------------------------------------------

  1) Administrator PowerShell 7 on Windows:

       cd C:\github\ps-cka\src\cka-lab
       .\Initialize-C04M01Lab.ps1

     Boot, health-check, stage, chmod, fact-gate, reset, snapshot.
     Wait for:  [OK] Lab is recording-ready for C04 M01
     First time on new VMs, add:  -Bootstrap

  2) On the node:

       vagrant ssh control1
       cd ~/m01 && ./lab.sh

     Resets, then walks all four demos against the live cluster.
     Exit 0 = every expected allow allowed AND every expected 403
     denied. Exit 1 = it names the check that drifted.

  Then:  ./lab.sh reset      (8 sec, prints READY FOR TAKE)

----------------------------------------------------------------
  EVERY COMMAND THAT EXISTS. THERE ARE NINE.
----------------------------------------------------------------

  HOST  (admin pwsh, in C:\github\ps-cka\src\cka-lab)

    .\Initialize-C04M01Lab.ps1               start of a session
    .\Initialize-C04M01Lab.ps1 -Bootstrap    first run on fresh VMs
                                             (kubeadm init + Calico)
    .\Initialize-C04M01Lab.ps1 -SkipBoot     VMs already running
    .\Initialize-C04M01Lab.ps1 -SkipSnapshot keep your save point
    .\Restore-CkaSnapshot.ps1 c04-m01-rbac-ready   broke the CP

  NODE  (vagrant ssh control1, then cd ~/m01)

    ./lab.sh            reset + verify   <-- the one you want
    ./lab.sh verify     verify only, no reset first
    ./lab.sh reset      frame zero, 8 sec, between takes
    ./lab.sh mint       ON CAMERA in Demo 1

  The 90% path is two lines:
       .\Initialize-C04M01Lab.ps1     (host)
       cd ~/m01 && ./lab.sh           (node)

  Everything else is an exception. `reset` is enough between takes
  because deleting the dev-team namespace cascades to the Role and
  both RoleBindings -- only the ClusterRoleBinding, the CSR, and
  two kubeconfig entries are cluster-scoped, and reset names those.
  Save the 90-second VM restore for a broken control plane.

----------------------------------------------------------------
  THE LAB, IN FIVE FACTS
----------------------------------------------------------------

  control1 / worker1 / worker2   192.168.50.10 / .11 / .12
  Ubuntu 22.04, Kubernetes v1.35, containerd
  CNI: CALICO via the Tigera operator, pinned v3.29.1
  Pod CIDR: 192.168.0.0/16   Service CIDR: 10.96.0.0/12
  Admin context: cka-vagrant   (kubeadm's name gets renamed)

  Calico is the course standard, set in C02 M03 and used since.
  NOTE: src\cka-lab\bootstrap_cp.sh still installs FLANNEL on
  10.244.0.0/16 -- a Course 1 leftover. Initialize-C04M01Lab.ps1
  deliberately does NOT call it; -Bootstrap runs kubeadm init on
  192.168.0.0/16 and installs Calico with the same two pinned
  Tigera URLs as C02 M03. Delete or fix bootstrap_cp.sh when you
  get a spare five minutes.

  Node NotReady after a checkpoint restore is the known Calico
  token gotcha:
       kubectl -n calico-system rollout restart ds/calico-node

----------------------------------------------------------------
  READ THE VERIFICATION LEDGER BEFORE YOU TRUST ANY OF THIS
----------------------------------------------------------------

  Bottom of the runbook. It states plainly which claims are
  PROVEN (verbatim quotes from the Kubernetes release-1.35
  bootstrappolicy source) and which are UNVERIFIED (everything
  that needs a live cluster -- nothing has been executed).

  Short version: the RBAC facts are source-verified. The SCRIPTS
  are syntax-verified only. `./lab.sh` is what closes that gap,
  and it is step 2 above for exactly that reason.

----------------------------------------------------------------
  IF A FACT GATE FAILS, DO NOT RECORD
----------------------------------------------------------------

  Initialize-C04M01Lab.ps1 asks the LIVE cluster whether five
  sentences in the deck are still true:

    - system:basic-user bound to system:authenticated   (Demo 1)
    - view has no Secrets rule                          (Demo 4)
    - edit can write Secrets                            (Demo 4)
    - view covers Namespaces                            (Demo 3)
    - edit has an aggregationRule                       (Demo 4)

  A failure means the cluster disagrees with the deck. Fix the
  deck, not the gate.

----------------------------------------------------------------
  THE ARC  (~12 min including command execution)
----------------------------------------------------------------

  Every demo OPENS with a context command. Non-negotiable at any
  runtime -- the exam runs six clusters and every task starts
  with use-context.

  Demo 1  2:00   Mint a real user from a cert. The cluster names
                 them exactly -- and returns 403. 401 vs 403.
  Demo 2  3:00   Role + RoleBinding. Same command now works.
                 Then a WRITE gets 403: the grant is narrow.
  Demo 3  2:45   Same ClusterRole, two binding kinds. The binding
                 sets the scope. Highest-yield concept here.
  Demo 4  1:50   view vs edit on Secrets, aggregation callout,
                 --dry-run=client -o yaml.

  CUT ON PURPOSE: aggregation is a 15-second verbal callout, not
  a demo. It is a recognize-it objective already covered on
  slides 16-17. That cut is what keeps this at 12 minutes.

  RUNNING LONG? Trim ladder is in the runbook, ranked. Never cut
  an opening context line, the Demo 1 403, Demo 3's before/after
  pairs, or --dry-run=client.

----------------------------------------------------------------
  IF THE MINT MISBEHAVES ON CAMERA
----------------------------------------------------------------

       ./lab.sh mint         # idempotent, ~15 sec

  Then resume the runbook at [1.3]. Nobody watching will know.

================================================================
