<#
.SYNOPSIS
    On-rails tutorial functions for CKA Course 1 modules.
    Sourced by kind-up.ps1 when tutorial mode is selected.
#>

# ---------------------------------------------------------------
# Helper: Run a command, show it, explain output, pause
#
# Optional params layer instructional value without touching commands:
#   -CommandBreakdown: multi-line string shown BEFORE the run,
#                      dissecting each flag/arg of the command.
#   -OutputFields:     multi-line string shown AFTER the run,
#                      explaining the columns/fields the learner just saw.
# Both accept `n for newlines (same convention as -Explanation).
#
# Multi-beat sections:
#   -Steps  hashtable array. When present, the section header (title +
#           explanation) renders once, then each beat fires its own
#           Command/Breakdown/run/OutputFields/Press-Enter cycle. Use when
#           a section teaches a cause/effect arc that needs an Enter press
#           between cause and effect (e.g. delete -> watch resurrect, scale
#           -> watch slice grow). Beat hashtable keys: Beat, Command,
#           Breakdown, OutputFields. OutputFields may be empty for silent-
#           setup beats — the "What you just saw" block is then skipped.
#           When -Steps is provided, the legacy -Command/-CommandBreakdown/
#           -OutputFields params are ignored.
# ---------------------------------------------------------------
function Write-TutorialSection {
    param(
        [string]$Title,
        [string]$Explanation,
        [string]$Command,
        [string]$CommandBreakdown,
        [string]$OutputFields,
        [hashtable[]]$Steps,
        [switch]$NoRun
    )
    Write-Output ""
    Write-Output "  ================================================================"
    Write-Output "  $Title"
    Write-Output "  ================================================================"
    Write-Output ""
    Write-Output ("  " + $Explanation)

    if ($Steps -and $Steps.Count -gt 0) {
        # Multi-beat path: each beat is a self-contained cause/effect cycle.
        # Section header already printed; loop over the beats.
        foreach ($step in $Steps) {
            Write-TutorialBeatBody `
                -Beat $step.Beat `
                -Command $step.Command `
                -Breakdown $step.Breakdown `
                -OutputFields $step.OutputFields `
                -NoRun:$NoRun
        }
        return
    }

    # Single-command path: render as one unnamed beat so the visual rhythm
    # (command -> output -> output-fields -> prompt) stays identical to the
    # multi-beat path. Pre-refactor sections (M01/M02/Component-Walkthrough)
    # render unchanged because they didn't have a beat header anyway.
    Write-TutorialBeatBody `
        -Command $Command `
        -Breakdown $CommandBreakdown `
        -OutputFields $OutputFields `
        -NoRun:$NoRun
}

# ---------------------------------------------------------------
# Helper for the inner-loop render. Both -Steps and the legacy single-
# command path go through here so visual rhythm stays identical:
#
#   <blank>
#   ---- Beat N.M: TITLE ----        (multi-beat only)
#   <blank>
#   Command:  <yellow>
#   <blank>
#   ---- What each part does ----    (only if Breakdown set)
#   <breakdown>                      (only if Breakdown set)
#   <blank>                          (only if Breakdown set)
#   ---- Output ----                 (the run separator)
#   <blank>
#   <command output, sky blue>
#   <blank>
#   ---- What you just saw ----      (only if OutputFields set)
#   <output fields>                  (only if OutputFields set)
#   <blank>                          (only if OutputFields set)
#   ---- (terminator) ----
#   <blank>
#   Press Enter to continue
#   <blank>
#
# The blank lines around each visual block are the breathing room. The
# terminator dashes after OutputFields (or after command output if no
# OutputFields) close the beat visually before the prompt.
# ---------------------------------------------------------------
function Write-TutorialBeatBody {
    param(
        [string]$Beat,
        [string]$Command,
        [string]$Breakdown,
        [string]$OutputFields,
        [switch]$NoRun
    )
    Write-Output ""
    if ($Beat) {
        # Beat header: "  ---- Beat 3.2: SCALE TO 4 ---..." padded so dashes
        # align consistently across beats regardless of label length.
        $beatHeader = "---- Beat $Beat "
        $beatHeader = $beatHeader + ('-' * [Math]::Max(4, 60 - $beatHeader.Length))
        Write-Output ("  " + $beatHeader)
        Write-Output ""
    }
    # Command line in bright yellow so it pops on camera. Write-Host bypasses
    # the success stream, which is fine -- tutorials are interactive-only and
    # nothing in the repo captures or pipes this output.
    Write-Host "  Command:  $($Script:BrightYellow)$Command$($Script:AnsiReset)"
    Write-Output ""
    if ($Breakdown) {
        Write-Output "  ---- What each part does -----------------------------------"
        Write-Output ("  " + $Breakdown)
        Write-Output ""
    }
    Write-Output "  ---- Output -------------------------------------------------"
    if (-not $NoRun) {
        Write-Output ""
        # Output in Wong sky blue so cause (yellow Command:) -> effect (blue
        # output) reads instantly on camera. Write-Host so the ANSI escapes
        # are honored. Tutorial output is interactive-only; nothing captures
        # this stream (same rationale as the Command: line above).
        Invoke-Expression $Command 2>&1 | ForEach-Object {
            Write-Host "  $($Script:SkyBlue)$_$($Script:AnsiReset)"
        }
        Write-Output ""
    }
    if ($OutputFields) {
        Write-Output "  ---- What you just saw -------------------------------------"
        Write-Output ("  " + $OutputFields)
        Write-Output ""
    }
    Write-Output "  -------------------------------------------------------------"
    Write-Output ""
    Read-Host "  Press Enter to continue"
    Write-Output ""
}

function Write-TutorialBanner {
    param([string]$Title, [string[]]$Lines)
    Write-Output ""
    # Border has 65 dashes between the corner '+' chars. Content lines render
    # as '|' + 2 spaces + PadRight(N) + '|'. To make the right '|' line up
    # with the right '+', N must be 65 - 2 = 63. PadRight(62) was off by one
    # and rendered the right edge one column inside the border.
    Write-Output "  +-----------------------------------------------------------------+"
    Write-Output "  |  $($Title.PadRight(63))|"
    Write-Output "  |                                                                 |"
    foreach ($line in $Lines) {
        Write-Output "  |  $($line.PadRight(63))|"
    }
    Write-Output "  +-----------------------------------------------------------------+"
    Write-Output ""
    Read-Host "  Press Enter to begin"
}

# ---------------------------------------------------------------
# Component Walkthrough (the original tutorial)
# ---------------------------------------------------------------
function Start-ComponentWalkthrough {
    param([string]$ClusterName)

    Write-TutorialBanner -Title "CKA COMPONENT WALKTHROUGH" -Lines @(
        "We'll verify every Kubernetes component in your cluster."
        "Each section shows a command, runs it, and explains the"
        "output. Press Enter to advance between sections."
    )

    # Query live topology so narration adapts to whichever config the learner picked
    # (simple=2, standard=3, HA=5, workloads=4). Hardcoding "3 nodes" would lie on
    # every topology except cka-3node.yaml.
    $nodeCount = (kubectl get nodes --no-headers 2>$null | Measure-Object).Count
    $workerNames = (kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}' 2>$null)
    if ([string]::IsNullOrWhiteSpace($workerNames)) { $workerNames = '(none)' }

    Write-TutorialSection `
        -Title "1/12  CLUSTER INFO" `
        -Explanation "kubectl cluster-info shows the API server endpoint and CoreDNS.`n  The API server is the front door to your cluster -- every kubectl command hits it." `
        -Command "kubectl cluster-info" `
        -CommandBreakdown "kubectl        = CLI that talks to the API server via kubeconfig`n  cluster-info   = subcommand; dumps master + core addons endpoints" `
        -OutputFields "Kubernetes control plane = API server URL (https://127.0.0.1:<port> for kind)`n  CoreDNS                  = in-cluster DNS Service endpoint`n  'To further debug...'    = hint to run 'kubectl cluster-info dump' for deep diag"

    Write-TutorialSection `
        -Title "2/12  NODES" `
        -Explanation "Your cluster has $nodeCount nodes. Control plane: ${ClusterName}-control-plane (and more if HA).`n  Workers: $workerNames -- these run your workloads.`n  STATUS=Ready means the kubelet on each node is healthy and reporting to the API server." `
        -Command "kubectl get nodes -o wide" `
        -CommandBreakdown "kubectl get    = list resources from the API server`n  nodes          = resource type (short: no)`n  -o wide        = output format; adds IP, OS, kernel, runtime columns" `
        -OutputFields "NAME        = node name (control-plane or worker)`n  STATUS      = Ready means kubelet is healthy and heartbeating`n  ROLES       = control-plane / worker / <none>`n  AGE         = time since the node joined`n  VERSION     = kubelet version (matches cluster version for v1.35)`n  INTERNAL-IP = node's IP on the kind Docker bridge`n  OS-IMAGE / KERNEL / RUNTIME = node OS details (containerd is the CKA-exam runtime)"

    Write-TutorialSection `
        -Title "3/12  NAMESPACES" `
        -Explanation "Namespaces partition cluster resources. You'll see:`n  - default:            where your pods go if you don't specify one`n  - kube-system:        control plane components`n  - kube-public:        cluster-wide readable resources`n  - kube-node-lease:    node heartbeat leases`n  - local-path-storage: KIND's storage provisioner" `
        -Command "kubectl get namespaces" `
        -CommandBreakdown "kubectl get    = list resources`n  namespaces     = resource type (short: ns) -- cluster-scoped partitions" `
        -OutputFields "NAME     = namespace name (default, kube-system, kube-public, kube-node-lease, local-path-storage)`n  STATUS   = Active (usable) or Terminating (being deleted)`n  AGE      = time since the namespace was created"

    Write-TutorialSection `
        -Title "4/12  CONTROL PLANE PODS (Static Pods)" `
        -Explanation "The 4 core control plane components run as static pods:`n  - kube-apiserver:          REST API front-end`n  - etcd:                    key-value store for all cluster state`n  - kube-scheduler:          assigns pods to nodes`n  - kube-controller-manager: runs reconciliation loops`n`n  They're 'static' because kubelet manages them from manifest files,`n  not through the API server. CKA tests this distinction." `
        -Command "kubectl get pods -n kube-system -l tier=control-plane -o wide" `
        -CommandBreakdown "kubectl get pods       = list Pod resources`n  -n kube-system         = namespace scope (where control plane lives)`n  -l tier=control-plane  = label selector; filters to pods labeled tier=control-plane`n  -o wide                = adds IP and NODE columns so you can see which host runs each pod" `
        -OutputFields "NAME              = static pod name (suffixed with node name, e.g. kube-apiserver-<node>)`n  READY             = containers ready / total (1/1 is healthy)`n  STATUS            = Running, Pending, CrashLoopBackOff, etc.`n  RESTARTS          = container restart count (non-zero may signal flapping)`n  AGE               = pod uptime`n  IP                = pod IP (static pods use host network, so this = node IP)`n  NODE              = which node runs this static pod (always a control-plane node)"

    Write-TutorialSection `
        -Title "5/12  ETCD -- THE CLUSTER DATABASE" `
        -Explanation "etcd stores ALL cluster state. If etcd dies, the cluster is brain-dead.`n  CKA covers backup/restore: etcdctl snapshot save / restore.`n  Let's see how etcd is configured:" `
        -Command "kubectl get pod etcd-${ClusterName}-control-plane -n kube-system -o jsonpath='{.spec.containers[0].command}' | ForEach-Object { `$_ -replace ',',`"``n  `" }" `
        -CommandBreakdown "kubectl get pod etcd-<node>   = fetch the etcd static pod object`n  -n kube-system                = namespace scope (control plane lives here)`n  -o jsonpath='{...}'           = output format; extract fields via JSONPath`n    .spec.containers[0]         = first container in the pod spec`n    .command                    = argv list launching etcd (flags end up here)`n  | ForEach-Object { ... }      = PowerShell pipe stage; processes the single string`n    `$_ -replace ',', `"`n  `"   = split comma-joined argv onto separate lines for reading" `
        -OutputFields "etcd                      = the binary being launched`n  --advertise-client-urls   = URL that clients use to reach this etcd member`n  --cert-file / --key-file  = TLS server cert + key for encrypted peer/client traffic`n  --data-dir                = on-disk state dir (/var/lib/etcd) -- the backup target`n  --listen-client-urls      = where etcd accepts kube-apiserver connections`n  --listen-peer-urls        = peer-to-peer quorum channel (matters in HA)`n  --trusted-ca-file         = CA that signs client certs (mTLS enforcement)"

    Write-TutorialSection `
        -Title "6/12  NETWORKING -- KUBE-PROXY" `
        -Explanation "kube-proxy runs as a DaemonSet (one pod per node). It programs iptables`n  rules so that Service ClusterIPs route to the right pods.`n  You should see exactly $nodeCount pods -- one on each node:" `
        -Command "kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide" `
        -CommandBreakdown "kubectl get pods         = list Pod resources`n  -n kube-system           = namespace scope (kube-proxy lives here)`n  -l k8s-app=kube-proxy    = label selector; 'k8s-app=<name>' is the convention core addons use`n  -o wide                  = adds IP and NODE columns so you can verify one-per-node placement" `
        -OutputFields "NAME     = kube-proxy pod name (one per node, suffixed with a hash)`n  READY    = 1/1 when the iptables/IPVS sync loop is healthy`n  STATUS   = Running on every node (DaemonSet guarantee)`n  AGE      = pod uptime`n  IP       = pod IP (host network, so matches node IP)`n  NODE     = which node the pod is pinned to (DaemonSet => one per node)"

    Write-TutorialSection `
        -Title "7/12  DNS -- COREDNS" `
        -Explanation "CoreDNS provides in-cluster DNS. When a pod calls 'my-service.default.svc.cluster.local',`n  CoreDNS resolves it to the Service's ClusterIP. Runs as a Deployment with 2 replicas." `
        -Command "kubectl get deploy,svc -n kube-system -l k8s-app=kube-dns" `
        -CommandBreakdown "kubectl get deploy,svc   = list TWO resource types in one call (comma-separated)`n  -n kube-system           = namespace scope`n  -l k8s-app=kube-dns      = label selector; note the service/deployment label is 'kube-dns' even though the binary is CoreDNS (legacy naming)" `
        -OutputFields "deployment.apps/coredns   = the CoreDNS Deployment (manages the 2 replica pods)`n    READY                   = replicas ready / desired (e.g. 2/2)`n    UP-TO-DATE / AVAILABLE  = rollout progress counters`n  service/kube-dns          = the Service that pods hit via /etc/resolv.conf`n    TYPE = ClusterIP         = internal-only virtual IP`n    CLUSTER-IP               = typically 10.96.0.10 (the cluster DNS IP)`n    PORT(S) = 53/UDP,53/TCP,9153/TCP (DNS + metrics)"

    Write-TutorialSection `
        -Title "8/12  NODE INTERNALS -- KUBELET + CONTAINER RUNTIME" `
        -Explanation "Each node runs a kubelet and containerd (the CKA exam runtime).`n  CKA asks: 'which container runtime is this cluster using?'" `
        -Command "kubectl get nodes -o custom-columns='NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion,INTERNAL-IP:.status.addresses[?(@.type==""InternalIP"")].address'" `
        -CommandBreakdown "kubectl get nodes                                 = list Node resources`n  -o custom-columns='HEADER:<jsonpath>,...'         = render a table YOU define:`n    NAME:.metadata.name                             = node name`n    KUBELET:.status.nodeInfo.kubeletVersion         = kubelet binary version`n    RUNTIME:.status.nodeInfo.containerRuntimeVersion = runtime + version (e.g. containerd://1.7)`n    INTERNAL-IP:.status.addresses[?(@.type=='InternalIP')].address = filter expression: pick the address whose type == InternalIP" `
        -OutputFields "NAME          = node name`n  KUBELET       = kubelet version (must match cluster version for v1.35)`n  RUNTIME       = container runtime URI -- 'containerd://...' is the CKA exam runtime (not Docker, not CRI-O here)`n  INTERNAL-IP   = the node's cluster-internal IP (what pods and kube-proxy use)"

    Write-TutorialSection `
        -Title "9/12  API RESOURCES" `
        -Explanation "The API server serves many resource types. SHORTNAMES save keystrokes:`n  po=pods, svc=services, deploy=deployments, cm=configmaps." `
        -Command "kubectl api-resources --verbs=list --namespaced=true -o wide | Select-Object -First 20" `
        -CommandBreakdown "kubectl api-resources       = dump every resource type the API server exposes`n  --verbs=list                = only resources that support the 'list' verb (filter out watch-only/subresources)`n  --namespaced=true           = only namespace-scoped types (hides cluster-scoped like Node, ClusterRole)`n  -o wide                     = includes the VERBS column (CKA-useful)`n  | Select-Object -First 20   = PowerShell pipe stage; cap output to first 20 rows so the screen stays readable" `
        -OutputFields "NAME         = plural resource name used in URLs (e.g. pods, services)`n  SHORTNAMES   = typing shortcuts (po, svc, deploy, cm, ns, sa) -- memorize these for the exam`n  APIVERSION   = group/version (e.g. v1, apps/v1, networking.k8s.io/v1)`n  NAMESPACED   = true here (filtered)`n  KIND         = CamelCase name used inside YAML 'kind:' field`n  VERBS        = allowed operations (get, list, watch, create, update, patch, delete, ...)"

    Write-TutorialSection `
        -Title "10/12  RBAC -- CLUSTER ROLES" `
        -Explanation "ClusterRoles define cluster-wide permissions. Key ones for CKA:`n  - cluster-admin: full access`n  - admin/edit/view: namespace-scoped progressive access" `
        -Command "kubectl get clusterroles | Select-String -Pattern '^(NAME|admin|edit|view|cluster-admin|system:node)'" `
        -CommandBreakdown "kubectl get clusterroles    = list ClusterRole resources (cluster-scoped RBAC)`n  | Select-String -Pattern '...' = PowerShell pipe stage; regex filter on output lines`n    ^(NAME|...)               = anchor at line start; match the header OR the named roles:`n      NAME                    = keeps the column header visible`n      admin / edit / view     = the 3 built-in user-facing ClusterRoles`n      cluster-admin           = superuser role`n      system:node             = the role the kubelet uses to talk to the API server" `
        -OutputFields "NAME          = ClusterRole name`n  CREATED AT    = timestamp the role was created (most are bootstrap-created at cluster init)`n  (The filtered rows show the RBAC roles the CKA exam calls out most often;`n  run 'kubectl get clusterroles' unfiltered to see 60+ bootstrap roles)"

    Write-TutorialSection `
        -Title "11/12  STORAGE -- STORAGE CLASSES" `
        -Explanation "StorageClasses define how PersistentVolumes are provisioned.`n  KIND ships with 'standard' (local-path-provisioner) as the default." `
        -Command "kubectl get storageclass" `
        -CommandBreakdown "kubectl get storageclass   = list StorageClass resources (short: sc; cluster-scoped)" `
        -OutputFields "NAME                  = storage class name; '(default)' tag marks the default used when PVCs omit storageClassName`n  PROVISIONER           = plugin that creates PVs (kind: rancher.io/local-path)`n  RECLAIMPOLICY         = Delete (default) or Retain -- what happens to the PV when the PVC is deleted`n  VOLUMEBINDINGMODE     = Immediate or WaitForFirstConsumer (kind uses the latter: bind only when a pod schedules)`n  ALLOWVOLUMEEXPANSION  = whether PVCs can be resized post-create`n  AGE                   = time since creation"

    Write-TutorialSection `
        -Title "12/12  ADMISSION CONTROLLERS" `
        -Explanation "Admission controllers intercept API requests after auth but before persistence.`n  Your cluster has NodeRestriction and PodSecurity enabled." `
        -Command "kubectl get pod kube-apiserver-${ClusterName}-control-plane -n kube-system -o jsonpath='{.spec.containers[0].command}' | ForEach-Object { `$_ -split ',' } | Select-String 'admission'" `
        -CommandBreakdown "kubectl get pod kube-apiserver-<node> = fetch the kube-apiserver static pod`n  -n kube-system                        = namespace scope`n  -o jsonpath='{.spec.containers[0].command}' = extract the apiserver argv list`n    .spec.containers[0]                 = first (only) container in the pod`n    .command                            = the launch arguments (where admission flags live)`n  | ForEach-Object { `$_ -split ',' }    = PowerShell pipe; split the comma-joined string into individual args`n  | Select-String 'admission'           = pipe stage; keep only lines that mention 'admission'" `
        -OutputFields "--enable-admission-plugins=...       = comma-list of plugins explicitly enabled (you should see NodeRestriction, PodSecurity here)`n  --disable-admission-plugins=...      = explicitly disabled plugins (if any)`n  --admission-control-config-file=...  = path to plugin config (e.g. PodSecurity enforce/audit/warn levels)`n  (Anything else matching 'admission' is supporting config;`n  CKA exam: know how to enable/disable plugins by editing /etc/kubernetes/manifests/kube-apiserver.yaml)"

    Write-Output ""
    Write-Output "  Component walkthrough complete. You've verified all major K8s components."
    Write-Output ""
}

# ---------------------------------------------------------------
# Course 1, Module 1: Architecture & Lab Setup
# ---------------------------------------------------------------
function Start-TutorialM01 {
    param([string]$ClusterName)

    Write-TutorialBanner -Title "COURSE 1 / MODULE 1: Architecture & Lab Setup" -Lines @(
        "We just created the cluster. Now let's verify the"
        "architecture actually exists -- nodes, system pods, DNS."
        "This is the health check you'd do on the CKA exam."
    )

    # Query live topology so narration adapts to the learner's chosen config.
    $nodeCount = (kubectl get nodes --no-headers 2>$null | Measure-Object).Count

    # --- Demo 1: Verify Nodes ---
    Write-TutorialSection `
        -Title "1/10  NODE STATUS" `
        -Explanation "Let's confirm all $nodeCount nodes are Ready. Look for containerd as the runtime`n  and unique IPs on the Docker bridge network." `
        -Command "kubectl get nodes -o wide" `
        -CommandBreakdown "kubectl get     = query the API server`n  nodes           = resource type (cluster-scoped, no namespace)`n  -o wide         = adds IP, OS, kernel, and container runtime columns" `
        -OutputFields "NAME              = node name (kind names them <cluster>-control-plane / -worker)`n  STATUS            = Ready means the kubelet is healthy and checked in`n  ROLES             = control-plane or <none> (workers show <none>)`n  AGE               = time since the node joined the cluster`n  VERSION           = kubelet version -- v1.35.x for this lab`n  INTERNAL-IP       = node's IP on the kind Docker bridge network`n  OS-IMAGE          = host OS the kubelet is running on`n  CONTAINER-RUNTIME = containerd://<ver> (the CKA exam runtime)"

    Write-TutorialSection `
        -Title "2/10  WHAT KIND BUILT (Docker containers as nodes)" `
        -Explanation "KIND runs each Kubernetes node as a Docker container. These aren't VMs --`n  they're lightweight containers running a full kubelet. Let's see them:" `
        -Command "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" `
        -CommandBreakdown "docker ps       = list RUNNING Docker containers (add -a for stopped too)`n  --format 'table ...' = custom output using Go template syntax`n    {{.Names}}    = container name column (kind uses <cluster>-control-plane, -worker)`n    \t            = tab separator between columns`n    {{.Status}}   = Up/Exited + uptime (e.g. 'Up 3 minutes')`n    {{.Ports}}    = host:container port mappings (kind's NodePort maps land here)" `
        -OutputFields "NAMES   = the kind node container (this is literally your k8s node)`n  STATUS  = 'Up X' -- if a node says Exited, the cluster is degraded`n  PORTS   = host port -> container port (e.g. 0.0.0.0:30080->30080/tcp for NodePort)`n  The kindest-registry or -external-load-balancer containers may also appear on HA configs."

    Write-TutorialSection `
        -Title "3/10  KUBECONFIG CONTEXT" `
        -Explanation "KIND auto-configured your kubeconfig. The context 'kind-${ClusterName}'`n  points to the cluster's API server. On the CKA exam, you'll switch contexts`n  constantly -- always verify which cluster you're talking to." `
        -Command "kubectl config current-context" `
        -CommandBreakdown "kubectl config  = kubeconfig subcommand group (reads ~/.kube/config)`n  current-context = prints the ACTIVE context name only (one line)`n  Related: 'kubectl config get-contexts' (list all), 'use-context <name>' (switch)" `
        -OutputFields "Output is one line -- the active context name.`n  Format: kind-<cluster> (e.g. kind-${ClusterName}).`n  A context bundles: cluster (API URL + CA), user (credentials), namespace default.`n  CKA rule: run this BEFORE any destructive command. Wrong context = zero points."

    # --- Demo 2: System Pods ---
    Write-TutorialSection `
        -Title "4/10  CONTROL PLANE STATIC PODS" `
        -Explanation "These are the 4 core components, managed as static pods by kubelet:`n  apiserver, etcd, scheduler, controller-manager.`n  They have names like kube-apiserver-${ClusterName}-control-plane.`n  Static pods live in /etc/kubernetes/manifests/ on the node." `
        -Command "kubectl get pods -n kube-system -o wide" `
        -CommandBreakdown "kubectl get pods  = list Pod resources`n  -n kube-system    = namespace scope (where control plane + addons live)`n  -o wide           = adds IP and NODE columns (no label selector -- show ALL system pods)" `
        -OutputFields "NAME      = pod name; static pods end in '-${ClusterName}-control-plane'`n  READY     = containers ready / total (1/1 is healthy)`n  STATUS    = Running / Pending / CrashLoopBackOff / Completed`n  RESTARTS  = non-zero on a control-plane pod is a warning sign`n  AGE       = pod uptime`n  IP        = pod IP (static pods use host network -> equals node IP)`n  NODE      = which node runs the pod (all static pods pin to a control-plane node)`n  You'll see etcd-, kube-apiserver-, kube-scheduler-, kube-controller-manager-, plus coredns, kube-proxy, kindnet."

    Write-TutorialSection `
        -Title "5/10  KUBE-PROXY DAEMONSET" `
        -Explanation "kube-proxy runs one pod per node (that's what a DaemonSet does).`n  It programs iptables/IPVS rules so Services can route traffic." `
        -Command "kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide" `
        -CommandBreakdown "kubectl get pods      = list Pod resources`n  -n kube-system        = kube-proxy lives in the system namespace`n  -l k8s-app=kube-proxy = label selector; 'k8s-app' is the canonical addon label`n  -o wide               = adds IP + NODE columns so you can confirm one-per-node" `
        -OutputFields "Expect exactly $nodeCount pods -- one per node (that's the DaemonSet contract).`n  NAME     = kube-proxy-<random-suffix>`n  READY    = 1/1 when healthy`n  STATUS   = Running`n  NODE     = each pod pins to a different node (DaemonSet spread)`n  If count != node count, a node is missing kube-proxy and Services will break on it."

    # --- Demo 3: DNS ---
    Write-TutorialSection `
        -Title "6/10  COREDNS SERVICE" `
        -Explanation "CoreDNS is the cluster's DNS server. Every pod's /etc/resolv.conf`n  points to the kube-dns Service IP (typically 10.96.0.10).`n  Let's see the Service and Deployment:" `
        -Command "kubectl -n kube-system get svc kube-dns" `
        -CommandBreakdown "kubectl        = CLI`n  -n kube-system = namespace scope (DNS lives here)`n  get svc        = list Services (svc = short name for services)`n  kube-dns       = Service name (legacy -- the pods are CoreDNS, but the Service kept the kube-dns name for backward compat)" `
        -OutputFields "NAME        = kube-dns (hardcoded -- every pod's resolv.conf targets this name)`n  TYPE        = ClusterIP (in-cluster only, no external exposure)`n  CLUSTER-IP  = typically 10.96.0.10 (baked into every pod's /etc/resolv.conf at creation)`n  EXTERNAL-IP = <none> (intentional -- DNS is internal-only)`n  PORT(S)     = 53/UDP, 53/TCP, 9153/TCP (UDP/TCP DNS + Prometheus metrics)`n  AGE         = time since the Service was created"

    Write-TutorialSection `
        -Title "7/10  COREDNS DEPLOYMENT" `
        -Explanation "CoreDNS runs as a Deployment with 2 replicas for redundancy.`n  The Deployment ensures DNS stays available even if a pod dies." `
        -Command "kubectl -n kube-system get deploy coredns" `
        -CommandBreakdown "kubectl         = CLI`n  -n kube-system  = namespace scope`n  get deploy      = list Deployments (deploy = short name for deployments)`n  coredns         = Deployment name (the controller managing CoreDNS pods)" `
        -OutputFields "NAME        = coredns`n  READY       = pods ready / desired (2/2 means both replicas are healthy)`n  UP-TO-DATE  = replicas updated to the latest pod template spec`n  AVAILABLE   = replicas that meet minReadySeconds and are serving traffic`n  AGE         = time since the Deployment was created`n  If READY shows 1/2 or 0/2 for long, DNS resolution in the cluster is degraded."

    Write-TutorialSection `
        -Title "8/10  DNS HEALTH CHECK" `
        -Explanation "Let's test DNS end-to-end. We'll spin up a temporary busybox pod`n  and resolve the API server's internal Service by its FQDN:`n  kubernetes.default.svc.cluster.local -> 10.96.0.1.`n  NOTE: busybox's nslookup does not walk /etc/resolv.conf search list,`n  so always query the FQDN here. If this resolves, CoreDNS is healthy." `
        -Command "kubectl run dns-test --image=busybox:1.36 --rm --restart=Never --attach -- nslookup kubernetes.default.svc.cluster.local" `
        -CommandBreakdown "kubectl run dns-test   = imperative pod creation; 'dns-test' is the pod name`n  --image=busybox:1.36   = pinned busybox image (ships nslookup, wget, sh)`n  --rm                   = auto-delete the pod after it exits (keeps the cluster clean)`n  --restart=Never        = pod restartPolicy=Never; makes this a one-shot, not a long-lived workload`n  --attach               = stream the container's stdout/stderr to your terminal`n  --                     = end-of-kubectl-flags separator; everything after goes to the CONTAINER`n  nslookup kubernetes.default.svc.cluster.local = FQDN lookup (busybox skips the search list)" `
        -OutputFields "Server:    10.96.0.10     = the CoreDNS Service IP (from /etc/resolv.conf inside the pod)`n  Address:   10.96.0.10#53  = DNS server + port`n  Name:      kubernetes.default.svc.cluster.local  = fully qualified Service DNS name`n  Address:   10.96.0.1                              = ClusterIP of the 'kubernetes' Service (the API)`n  'pod dns-test deleted' = --rm auto-cleanup confirmation`n  Any 'server can't find' or timeout = CoreDNS is broken; check section 6 + 7."

    # --- Demo 4: Cluster Info ---
    Write-TutorialSection `
        -Title "9/10  CLUSTER INFO" `
        -Explanation "Quick summary of your cluster endpoints. On the exam, if connectivity`n  is broken, this is your first command." `
        -Command "kubectl cluster-info" `
        -CommandBreakdown "kubectl        = CLI (reads kubeconfig to find the API server)`n  cluster-info   = subcommand; prints the endpoints of the control plane + core addons`n  Companion: 'kubectl cluster-info dump' emits deep diagnostic data (log-sized)" `
        -OutputFields "Kubernetes control plane is running at https://127.0.0.1:<port>`n    = API server URL. For kind, it's always localhost -- the port is random per-cluster.`n  CoreDNS is running at https://127.0.0.1:<port>/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy`n    = CoreDNS accessed via the API server proxy (not the pod IP directly).`n  'To further debug and diagnose...' = footer hint pointing you at cluster-info dump.`n  If the control-plane URL fails to respond, kubectl is broken -- check context + kubeconfig."

    Write-TutorialSection `
        -Title "10/10  API RESOURCES" `
        -Explanation "Every resource type the API server knows about. The SHORTNAMES column`n  is gold -- 'po' for pods, 'svc' for services, 'deploy' for deployments.`n  Memorize the ones you use most; they save real time on the exam." `
        -Command "kubectl api-resources | Select-Object -First 20" `
        -CommandBreakdown "kubectl api-resources  = asks the API server 'what resource kinds do you serve?'`n  |                      = PowerShell pipe -- hand stdout to the next cmdlet`n  Select-Object -First 20 = take only the first 20 lines (table is ~70+ rows)`n  Related: add '--api-group=apps' or '--namespaced=true' to filter" `
        -OutputFields "NAME         = plural resource name (use in kubectl commands: pods, services, deployments)`n  SHORTNAMES   = aliases -- exam speed (po, svc, deploy, cm, ns, sa, pv, pvc, ing, netpol)`n  APIVERSION   = group/version (v1 = core; apps/v1 = Deployment, DaemonSet, StatefulSet)`n  NAMESPACED   = true = per-namespace (pods, svc); false = cluster-wide (nodes, pv, ns)`n  KIND         = CamelCase type used in YAML's 'kind:' field (Pod, Service, Deployment)"

    Write-Output ""
    Write-Output "  Module 1 walkthrough complete."
    Write-Output "  You've verified: nodes, system pods, DNS, and cluster connectivity."
    Write-Output "  Your cluster is healthy and ready for Module 2."
    Write-Output ""
}

# ---------------------------------------------------------------
# Course 1, Module 2: kubectl Workflows
# ---------------------------------------------------------------
function Start-TutorialM02 {
    param([string]$ClusterName)

    Write-TutorialBanner -Title "COURSE 1 / MODULE 2: kubectl Workflows" -Lines @(
        "Five critical kubectl skills for CKA speed:"
        "imperative creation, dry-run YAML, declarative apply,"
        "kubectl explain, resource querying, and context awareness."
    )

    # Wrap the body in try/finally so Ctrl-C (or any mid-tutorial exit) still
    # cleans up demo resources. Without this, a learner re-running the tutorial
    # would collide on existing pod/deployment/service names.
    try {

    # --- Demo 1: Imperative Speed Run ---
    Write-TutorialSection `
        -Title "1/10  IMPERATIVE: CREATE A POD" `
        -Explanation "Pods are the atomic unit. This is the fastest way to get a container running.`n  No YAML, no files -- just one command." `
        -Command "kubectl run nginx --image=nginx" `
        -CommandBreakdown "kubectl run    = imperative pod creation (fastest path to a running container)`n  nginx          = pod name (also becomes the default container name)`n  --image=nginx  = container image; no tag means :latest from Docker Hub" `
        -OutputFields "pod/nginx created = confirmation the API server persisted the object`n  Next: the scheduler picks a node, kubelet pulls the image, container starts`n  Check progress with: kubectl get pods   (STATUS cycles Pending -> ContainerCreating -> Running)"

    Write-TutorialSection `
        -Title "2/10  IMPERATIVE: DEPLOYMENT + EXPOSE" `
        -Explanation "Two commands, five resources. Deployment spawns ReplicaSet + 3 Pods,`n  then expose adds a Service with auto-created DNS. The Service inherits`n  the selector app=web from the Deployment's labels." `
        -Command "kubectl create deployment web --image=nginx --replicas=3; kubectl expose deployment web --port=80 --type=ClusterIP" `
        -CommandBreakdown "--- Command 1: create the workload ----------------------------`n  kubectl create deployment = imperative create (vs apply, which is declarative from YAML)`n  web             = Deployment name; becomes the label app=web`n  --image=nginx   = container image used in the pod template`n  --replicas=3    = desired pod count; ReplicaSet enforces this continuously`n  --- Command 2: expose it on the network -----------------------`n  kubectl expose  = imperative Service creation from an existing workload`n  deployment web  = source resource (Service inherits its selector: app=web)`n  --port=80       = Service port (what clients connect to)`n  --type=ClusterIP = internal-only virtual IP (default; other options: NodePort, LoadBalancer)`n  ; (semicolon)   = PowerShell command separator; runs both commands in sequence" `
        -OutputFields "deployment.apps/web created = Deployment object persisted`n    Chain spawned: Deployment -> ReplicaSet -> 3 Pods (all labeled app=web)`n    Pod names follow <deploy>-<rs-hash>-<pod-hash> (e.g. web-7d4b9c8f-xkl2m)`n  service/web exposed         = Service object created with a ClusterIP`n    Selector app=web tracks the 3 pods above`n    DNS auto-created: web.default.svc.cluster.local`n    Endpoints object populated with backend pod IPs (kubectl get endpoints web)`n  Verify the whole chain: kubectl get deploy,rs,pods,svc"

    Write-TutorialSection `
        -Title "3/10  IMPERATIVE: CONFIGMAP + SECRET + RBAC" `
        -Explanation "Four more resources in four commands. That's 9 resources total`n  with zero YAML files. Speed wins on the exam." `
        -Command "kubectl create configmap app-config --from-literal=env=prod; kubectl create secret generic db-pass --from-literal=password=s3cret; kubectl create role pod-reader --verb=get,list,watch --resource=pods; kubectl create rolebinding pod-reader-binding --role=pod-reader --user=jane" `
        -CommandBreakdown "create configmap     = non-secret key/value config (--from-literal for inline, --from-file for files)`n  create secret generic = base64-encoded secret (generic = opaque; other types: tls, docker-registry)`n  --from-literal=K=V   = inline key/value data (repeat for multiple)`n  create role          = namespaced permissions (--verb=what, --resource=on-what)`n  create rolebinding   = binds a Role to a subject (--user, --group, or --serviceaccount)`n  ; (semicolon)        = PowerShell command separator; runs four commands in sequence" `
        -OutputFields "Four 'created' confirmations -- one per resource`n  configmap/app-config       = plain config (not encrypted at rest without KMS)`n  secret/db-pass             = base64-encoded (NOT encrypted -- use kubectl get secret -o yaml to see)`n  role.rbac.../pod-reader    = allows get/list/watch pods in current namespace only`n  rolebinding/...-binding    = grants that Role to user 'jane'"

    # --- Demo 2: Dry-Run YAML Pipeline ---
    Write-TutorialSection `
        -Title "4/10  DRY-RUN: GENERATE YAML WITHOUT CREATING" `
        -Explanation "--dry-run=client validates and generates a manifest WITHOUT persisting.`n  This is the professional way: generate, edit, apply. GitOps-ready.`n  Notice the nested structure -- spec.replicas, spec.selector.matchLabels,`n  spec.template.spec.containers." `
        -Command "kubectl create deployment limited --image=nginx --replicas=2 --dry-run=client -o yaml | Select-Object -First 25" `
        -CommandBreakdown "kubectl create deployment = imperative Deployment generator`n  limited                   = Deployment name (and default label app=limited)`n  --image=nginx             = container image for the pod template`n  --replicas=2              = desired pod count`n  --dry-run=client          = render the object locally; do NOT send to the API server`n  -o yaml                   = emit as YAML (perfect for redirecting with > deploy.yaml)`n  | Select-Object -First 25 = PowerShell pipeline: keep first 25 lines (trim output for display)`n  Same flag works for kubectl run -- swap 'create deployment' for 'run <pod>'" `
        -OutputFields "apiVersion: apps/v1         = Deployments live in the 'apps' API group`n  kind: Deployment`n  metadata.name: limited      = object identity (name, labels, annotations, namespace)`n  spec.replicas: 2            = desired pod count`n  spec.selector.matchLabels   = which pods this Deployment manages (app=limited)`n  spec.template               = the pod template; everything under this = one pod`n  spec.template.spec.containers = the container list (image, ports, resources, probes)`n  status: omitted in dry-run output (populated by the cluster at runtime)`n  strategy, revisionHistoryLimit, progressDeadlineSeconds = rollout behavior (cut off by -First 25)"

    # --- Demo 3: Declarative Apply (round-trip) + see everything ---
    Write-TutorialSection `
        -Title "5/10  APPLY: ROUND-TRIP + SEE EVERYTHING" `
        -Explanation "Close the loop: render -> save -> read back -> apply -> apply again -> get all.`n  Declarative apply is idempotent -- re-applying an unchanged manifest is a no-op.`n  Then 'kubectl get all' verifies the apply landed alongside everything else.`n  Watch out: 'all' is a misleading alias -- it does NOT include ConfigMaps,`n  Secrets, or RBAC objects you created in section 3." `
        -Command "kubectl create deployment apply-demo --image=nginx --replicas=2 --dry-run=client -o yaml | Set-Content `$HOME/web-apply.yaml; Get-Content `$HOME/web-apply.yaml | Select-Object -First 20; kubectl apply -f `$HOME/web-apply.yaml; kubectl apply -f `$HOME/web-apply.yaml; kubectl get all" `
        -CommandBreakdown "kubectl create deployment ... --dry-run=client -o yaml = render the manifest`n    apply-demo                = Deployment name (and default label app=apply-demo)`n    --replicas=2              = desired pod count`n  | Set-Content `$HOME/web-apply.yaml = PowerShell: write the YAML stream to a file in `$HOME`n    (`$HOME is always writable on Windows + WSL2; safe even if pwd is read-only)`n  Get-Content `$HOME/web-apply.yaml | Select-Object -First 20 = read the saved file back, trim to 20 lines`n  kubectl apply -f `$HOME/web-apply.yaml = first apply: server-side create from the manifest`n  kubectl apply -f `$HOME/web-apply.yaml = second apply: same manifest, no diff -> no-op`n  kubectl get all = list pods,services,deployments,replicasets,statefulsets,daemonsets,jobs,cronjobs`n    (NOT configmaps, secrets, ingresses, PVCs, RBAC -- 'all' is a misleading alias)" `
        -OutputFields "First chunk = the YAML preview (apiVersion, kind, metadata, spec.replicas, spec.selector, spec.template)`n  deployment.apps/apply-demo created   = first apply: API server persisted the Deployment`n  deployment.apps/apply-demo unchanged = second apply: server-side diff was empty -> idempotency`n    (this is the teaching point -- re-applying is safe; no rollout, no churn)`n  Then 'get all' shows: pod/nginx, pod/web-*, pod/apply-demo-*, service/web, service/kubernetes,`n    deployment.apps/web, deployment.apps/apply-demo, replicaset.apps/* for each Deployment`n  app-config, db-pass, pod-reader, pod-reader-binding are HIDDEN -- 'all' lies`n  Exam tip: when the question says 'apply this manifest', use 'kubectl apply -f' -- generated YAML is editable, versionable, idempotent"

    # --- Demo 4: kubectl explain ---
    Write-TutorialSection `
        -Title "6/10  EXPLAIN: RECURSIVE FIELD TREE" `
        -Explanation "kubectl explain is your in-terminal API reference -- pulled from the live`n  cluster's OpenAPI schema, no internet needed. --recursive expands the whole`n  subtree, perfect for finding nested fields like rollout strategy options.`n  Drop --recursive for a single-level view of one field." `
        -Command "kubectl explain deployment.spec.strategy --recursive" `
        -CommandBreakdown "kubectl explain           = OpenAPI schema lookup against the API server`n  deployment.spec.strategy  = dot-path into the Deployment rollout strategy field`n  --recursive               = expand every nested sub-field (no need to keep re-running explain)`n  Without --recursive: shows only the immediate sub-fields + their descriptions`n  Other useful paths: pod.spec.containers.resources, pod.spec.affinity, pod.spec.tolerations" `
        -OutputFields "KIND          = resource kind (Deployment)`n  VERSION       = API group/version (apps/v1)`n  FIELD         = the field you asked about (strategy)`n  DESCRIPTION   = human-readable docs for the field`n  FIELDS (tree):`n    rollingUpdate          = struct for rolling rollout tuning`n      maxSurge             = extra pods allowed above replicas during rollout (int or %)`n      maxUnavailable       = pods allowed to be down during rollout (int or %)`n    type                   = 'RollingUpdate' (default) or 'Recreate' (kill-all-then-create)`n  Exam tip: know the defaults -- maxSurge=25%, maxUnavailable=25%"

    # --- Demo 5: Querying ---
    Write-TutorialSection `
        -Title "7/10  QUERY: LABEL SELECTOR + SHOW LABELS" `
        -Explanation "Labels are how Kubernetes organizes resources. -l filters; --show-labels`n  reveals what you're filtering against. Together they're the full label loop." `
        -Command "kubectl get pods -l app=web --show-labels" `
        -CommandBreakdown "kubectl get pods = list Pod resources`n  -l app=web       = label selector (short for --selector); matches pods labeled app=web`n  --show-labels    = append a LABELS column listing every label on each pod`n  (other -l syntax: -l 'env in (prod,staging)', -l '!disabled', -l app=web,tier=frontend)`n  Field-side cousin: --field-selector status.phase=Running filters by built-in fields, not labels" `
        -OutputFields "NAME      = pod name (Deployment-owned pods carry the <deploy>-<rs>-<pod> suffix pattern)`n  READY     = ready containers / total containers`n  STATUS    = phase (Running / Pending / CrashLoopBackOff / ...)`n  RESTARTS  = container restart count`n  AGE       = pod uptime`n  LABELS    = the gold column -- every label key=value on the pod`n              (you'll see app=web, pod-template-hash=<rs-hash>, and any others)`n  No matching pods = empty result (not an error); selector excluded everything"

    Write-TutorialSection `
        -Title "8/10  QUERY: JSONPATH + CUSTOM COLUMNS" `
        -Explanation "Two output shapers, same JSONPath syntax under the hood. JSONPath gives`n  you raw extracted values; custom-columns wraps the same paths in a table.`n  The 'aha': .items[*].metadata.name and .metadata.name are the SAME path --`n  one is a list-context expression, one is a per-item expression." `
        -Command "kubectl get pods -o jsonpath='{.items[*].metadata.name}'; Write-Output ''; Write-Output '---'; kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase" `
        -CommandBreakdown "--- Part 1: raw JSONPath extraction ---------------------------`n  kubectl get pods   = list pods (returns a List object with an .items array)`n  -o jsonpath='...'  = extract fields using JSONPath expressions`n  {.items[*]}        = iterate over every element of the items array`n  [*]                = wildcard index (all elements)`n  .metadata.name     = pick the metadata.name field from each`n  Result: space-separated pod names (no headers, no columns -- raw strings)`n  --- Part 2: same paths, table form ----------------------------`n  -o custom-columns=HEADER:jsonpath,...   = render as a table you design`n  NAME:.metadata.name       = column 1 = pod name`n  NODE:.spec.nodeName       = column 2 = which node the scheduler placed it on`n  STATUS:.status.phase      = column 3 = pod phase`n  Notice: per-item paths in custom-columns; list-context [*] paths in jsonpath" `
        -OutputFields "Part 1 (jsonpath): nginx web-xxxx-aaa web-xxxx-bbb web-xxxx-ccc apply-demo-xxx`n    Space-separated, no headers -- perfect for: for p in `$(...); do kubectl logs `$p; done`n  Part 2 (custom-columns):`n    NAME     = pod name`n    NODE     = the node the scheduler picked (empty if Pending / unscheduled = instant debug signal)`n    STATUS   = Pod phase (Running, Pending, Succeeded, Failed, Unknown)`n    Only these three columns -- no AGE, no READY, no RESTARTS`n  Related: -o jsonpath-as-json='{...}' emits JSON; -o go-template= for Go templates"

    Write-TutorialSection `
        -Title "9/10  QUERY: SORTED EVENTS" `
        -Explanation "Events are notifications -- Pod created, image pulled, container restarted.`n  Sorting by timestamp shows WHEN things happened. Debugging gold." `
        -Command "kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 10" `
        -CommandBreakdown "kubectl get events                     = list Event objects (default sort is unstable)`n  --sort-by=.metadata.creationTimestamp  = sort ascending by when the event was created`n  | Select-Object -Last 10               = PowerShell: keep the most recent 10 rows`n  (default behavior shows events from current namespace; add -A for all namespaces)" `
        -OutputFields "LAST SEEN  = how long ago the event last fired (events can repeat; count tracks repetitions)`n  TYPE       = Normal (informational) or Warning (trouble -- ImagePullBackOff, FailedScheduling, etc.)`n  REASON     = short code (Scheduled, Pulled, Created, Started, Killing, BackOff, Failed)`n  OBJECT     = what the event is about (pod/nginx, deployment.apps/web, ...)`n  MESSAGE    = human-readable detail (the actual story)`n  Exam tip: Warning events at the bottom = your most recent problem"

    # --- Demo 6: Context Awareness ---
    Write-TutorialSection `
        -Title "10/10  CONTEXT: VERIFY CURRENT CONTEXT" `
        -Explanation "The CKA exam has 17 questions across multiple clusters. One wrong context`n  = zero points, no error, no warning. Always verify before ANY destructive`n  command. The asterisk (*) marks your current context. Module 3 drills`n  switching between live clusters; this is the single-cluster sanity check." `
        -Command "kubectl config get-contexts" `
        -CommandBreakdown "kubectl config = read/write the active kubeconfig file (~/.kube/config by default)`n  get-contexts   = list every context defined in kubeconfig`n  (A 'context' = named triple of CLUSTER + USER + NAMESPACE -- switches all three at once)`n  Companions: 'use-context <name>' switches; 'current-context' prints just the active one`n              'set-context --current --namespace=<ns>' changes the default namespace" `
        -OutputFields "CURRENT    = asterisk (*) marks the active context`n  NAME       = context name (e.g. kind-cka-lab) -- this is what 'use-context' takes`n  CLUSTER    = cluster identity (API server endpoint + CA cert)`n  AUTHINFO   = credentials (user/token/cert used to authenticate)`n  NAMESPACE  = default namespace for this context (blank = 'default')`n  Exam tip: on exam, always 'kubectl config use-context <target>' before each question -- wrong cluster = 0 pts"

    Write-Output ""
    Write-Output "  Module 2 walkthrough complete."
    Write-Output "  You practiced: imperative commands, dry-run YAML, declarative apply,"
    Write-Output "  kubectl explain, resource querying, and context awareness."
    Write-Output ""

    } finally {
        # Always cleanup, even on Ctrl-C mid-tutorial. --ignore-not-found
        # keeps this safe when some resources were never created.
        Write-Output ""
        Write-Output "  Cleaning up demo resources..."
        kubectl delete pod nginx --ignore-not-found 2>&1 | Out-Null
        kubectl delete deployment web --ignore-not-found 2>&1 | Out-Null
        kubectl delete svc web --ignore-not-found 2>&1 | Out-Null
        kubectl delete configmap app-config --ignore-not-found 2>&1 | Out-Null
        kubectl delete secret db-pass --ignore-not-found 2>&1 | Out-Null
        kubectl delete role pod-reader --ignore-not-found 2>&1 | Out-Null
        kubectl delete rolebinding pod-reader-binding --ignore-not-found 2>&1 | Out-Null
        kubectl delete deployment apply-demo --ignore-not-found 2>&1 | Out-Null
        Remove-Item $HOME/web-apply.yaml -ErrorAction SilentlyContinue
        Write-Output "  Done."
    }
}

# ---------------------------------------------------------------
# Course 1, Module 3: Core Resources & Diagnostic Ladder
# ---------------------------------------------------------------
function Start-TutorialM03 {
    param([string]$ClusterName)

    Write-TutorialBanner -Title "COURSE 1 / MODULE 3: Core Resources & Diagnostics" -Lines @(
        "Five demos covering the most important CKA patterns:"
        "self-healing, services + EndpointSlices, namespaces, DNS,"
        "and the diagnostic ladder (30% of the CKA exam)."
    )

    # Wrap the body in try/finally so Ctrl-C (or any mid-tutorial exit) still
    # cleans up demo resources (standalone pod, managed deployment, service,
    # staging namespace, broken pod). Without this, a re-run collides.
    try {

    # ==========================================================
    # Demo 1: Bare Pod vs. Managed Deployment (self-healing setup)
    # ==========================================================
    Write-TutorialSection `
        -Title "1/10  BARE POD vs MANAGED DEPLOYMENT" `
        -Explanation "Two ways to get pods running. 'standalone' is a bare Pod with no`n  controller -- ephemeral, fire-and-forget. 'managed' is a Deployment`n  that owns a ReplicaSet that owns 2 Pods. Side-by-side, ownership is`n  the only thing that matters: bare = unmanaged, managed = self-healing." `
        -Steps @(
            @{
                Beat = '1.1: CREATE BOTH'
                Command = "kubectl run standalone --image=nginx --restart=Never; kubectl create deployment managed --image=nginx --replicas=2; Start-Sleep 4"
                Breakdown = "--- Bare Pod ---------------------------------------------------`n  kubectl run standalone        = imperative single-Pod creation`n  --image=nginx                 = container image (defaults to :latest)`n  --restart=Never               = makes it BARE (no controller; Always=default for run)`n  --- Managed Deployment ----------------------------------------`n  kubectl create deployment managed = imperative Deployment creation`n  --replicas=2                  = desired replica count (the reconciliation target)`n  Auto-seeds label app=managed and ownerReferences chain`n  --- Pause for steady state ------------------------------------`n  Start-Sleep 4                 = let pods reach Running before we list them in beat 1.2"
                OutputFields = ''
            }
            @{
                Beat = '1.2: VERIFY OWNERSHIP'
                Command = "kubectl get pods -o wide"
                Breakdown = "kubectl get pods -o wide      = LIST + IP/NODE columns; ownership reads from NAME suffix`n  No label selector              = show ALL pods in default ns (standalone + 2 managed)`n  -o wide                        = adds IP and NODE columns (vs the default summary view)"
                OutputFields = "NAME      = 'standalone' vs 'managed-<rs-hash>-<pod-hash>' -- the suffix IS the ownership clue`n  READY     = 1/1 across all three`n  STATUS    = Running`n  IP        = Pod IP on the CNI overlay (NOT the Service IP)`n  NODE      = which worker the scheduler placed each Pod on`n  ownerReferences (visible via -o yaml) chain Pod -> ReplicaSet -> Deployment for managed only`n  Bare pod 'standalone' has NO ownerReferences -- it is parentless and will not self-heal"
            }
        )

    Write-TutorialSection `
        -Title "2/10  SELF-HEALING: BARE DIES, MANAGED RESURRECTS" `
        -Explanation "Delete both. Watch what comes back. The bare pod is gone forever.`n  The managed pod gets a new replacement with a different name --`n  ReplicaSet's reconciliation loop in action. Then we'll inspect the`n  ReplicaSet itself: desired=2, current=2, ready=2 -- the loop is satisfied." `
        -Steps @(
            @{
                Beat = '2.1: KILL BOTH'
                Command = "kubectl delete pod standalone --grace-period=1; `$pod = (kubectl get pods -l app=managed -o jsonpath='{.items[0].metadata.name}'); kubectl delete pod `$pod --grace-period=1; Start-Sleep 6"
                Breakdown = "--- Kill the bare pod (no comeback) ---------------------------`n  kubectl delete pod standalone = remove the bare Pod`n  --grace-period=1              = override default 30s SIGTERM (speeds the demo)`n  --- Kill one managed pod (watch it return) --------------------`n  `$pod = (kubectl get ... jsonpath ...) = capture first managed Pod's name`n  -l app=managed                = label selector (only Pods labeled app=managed)`n  jsonpath='{.items[0].metadata.name}' = pick first match`n  kubectl delete pod `$pod      = kill the captured Pod`n  --- Pause for the controller to reconcile ---------------------`n  Start-Sleep 6                 = give the ReplicaSet controller time to detect actual<desired and create a replacement"
                OutputFields = ''
            }
            @{
                Beat = '2.2: WATCH IT RESURRECT'
                Command = "kubectl get pods -l app=managed; Write-Output '---'; kubectl get replicasets"
                Breakdown = "--- Verify the replacement -------------------------------------`n  kubectl get pods -l app=managed = should show 2 Pods, one with brand-new AGE`n  -l app=managed                = label selector; only Pods carrying app=managed (skips system pods)`n  --- Inspect the controller that did it ------------------------`n  kubectl get replicasets       = the controller that did the resurrection (short: rs)`n  Compare DESIRED / CURRENT / READY columns -- when all three match, the loop is quiet"
                OutputFields = "pods -l app=managed shows 2 Pods, one with AGE in seconds (the replacement)`n  new Pod has a DIFFERENT <pod-hash> suffix from the deleted one -- proof the RS recreated it`n  --- (divider)`n  ReplicaSet output:`n    NAME      = managed-<rs-hash> (rs-hash = pod-template-hash; new RS on every rolling update)`n    DESIRED   = 2 (from spec.replicas)`n    CURRENT   = 2 (Pods the RS actually created)`n    READY     = 2 (Pods passing readiness probes -- what Service endpoints use)`n    AGE       = unchanged -- the RS itself wasn't touched, just one of its Pods`n  When DESIRED != CURRENT, the loop is in flight (or stuck). First diagnostic signal."
            }
        )

    # ==========================================================
    # Demo 2: Services & EndpointSlices (the v1.35 way)
    # ==========================================================
    Write-TutorialSection `
        -Title "3/10  SERVICE + ENDPOINTSLICE: SCALE AND WATCH IT GROW" `
        -Explanation "Services give Pods a stable ClusterIP and DNS. EndpointSlices are`n  the v1.35 mechanism that maps Service -> Pod IPs (the legacy Endpoints`n  object still exists for back-compat, but kube-proxy reads slices).`n  Expose, inspect the slice, scale to 4, watch the slice grow in real time." `
        -Steps @(
            @{
                Beat = '3.1: BASELINE SLICE (2 endpoints)'
                Command = "kubectl expose deployment managed --port=80 --type=ClusterIP --name=managed-svc; Start-Sleep 3; kubectl get endpointslices -l kubernetes.io/service-name=managed-svc -o wide"
                Breakdown = "--- Create the Service ----------------------------------------`n  kubectl expose deployment managed = create a Service from the Deployment's selector`n  --port=80                         = Service port (what clients connect to)`n  --type=ClusterIP                  = in-cluster only (NodePort/LoadBalancer = external)`n  --name=managed-svc                = explicit Service name (deterministic)`n  Auto-creates: ClusterIP, DNS entry managed-svc.default.svc.cluster.local, EndpointSlice(s)`n  --- Pause for slice registration ------------------------------`n  Start-Sleep 3                 = let the EndpointSlice controller observe and write the slice`n  --- Inspect the EndpointSlice ---------------------------------`n  kubectl get endpointslices    = v1.35 endpoint mechanism (replaces legacy Endpoints)`n  -l kubernetes.io/service-name=managed-svc = the canonical label slices carry`n  -o wide                       = adds ENDPOINTS, PORTS, NODE columns inline (vs default summary)"
                OutputFields = "service/managed-svc exposed = Service object; ClusterIP allocated from service CIDR`n  EndpointSlice initial state:`n    NAME        = managed-svc-<hash> (slice name; one or more per Service)`n    ADDRESSTYPE = IPv4 (or IPv6 / FQDN; slices are dual-stack-aware)`n    PORTS       = 80`n    ENDPOINTS   = comma-separated Pod IPs -- TWO entries, matches the Deployment's --replicas=2`n  Empty ENDPOINTS would mean: selector matches no Ready Pods = classic 'Service is broken' clue`n  Legacy: 'kubectl get endpoints managed-svc' still works for back-compat but slices is what you want"
            }
            @{
                Beat = '3.2: SCALE THE DEPLOYMENT TO 4'
                Command = "kubectl scale deployment managed --replicas=4"
                Breakdown = "kubectl scale deployment managed = edit spec.replicas in-place on the Deployment`n  --replicas=4                  = new desired count (was 2 from beat 1.1)`n  This patches the Deployment, which patches its ReplicaSet, which creates 2 new Pods.`n  The output you see is just the API ack -- the slice has NOT yet refreshed.`n  Beat 3.3 will wait for the new Pods to reach Ready and re-inspect the slice."
                OutputFields = ''
            }
            @{
                Beat = '3.3: GROWN SLICE (4 endpoints) -- the money shot'
                Command = "Start-Sleep 8; kubectl get endpointslices -l kubernetes.io/service-name=managed-svc -o wide"
                Breakdown = "--- Pause for new Pods to become Ready ------------------------`n  Start-Sleep 8                 = let kubelet pull image (cached) + container start + readiness pass`n  --- Re-inspect the SAME slice ---------------------------------`n  kubectl get endpointslices -l kubernetes.io/service-name=managed-svc -o wide`n  Same command as beat 3.1 -- the comparison IS the lesson.`n  Why slices? Endpoints API is frozen (no dual-stack, no topology hints).`n  EndpointSlices support up to 1000 endpoints per slice + topology-aware routing."
                OutputFields = "ENDPOINTS column now lists FOUR Pod IPs (was 2 in beat 3.1)`n  Only READY Pods appear -- Pending/ContainerCreating Pods are excluded automatically`n  This is the reconciliation loop running in the network plane:`n    Deployment spec changed -> ReplicaSet created Pods -> kubelet ran them ->`n    EndpointSlice controller observed Ready=True -> slice grew -> kube-proxy reprogrammed iptables`n  All without you touching the Service. THIS is what 'declarative' means in practice."
            }
        )

    Write-TutorialSection `
        -Title "4/10  TEST THE SERVICE END-TO-END" `
        -Explanation "ClusterIPs aren't routable from your laptop -- you must test from inside.`n  Spin up a debug pod and wget the Service NAME (not IP). If you see the`n  nginx welcome page, the full path works: DNS -> ClusterIP -> kube-proxy ->`n  Pod IP. One failure mode at every layer; this command exercises them all." `
        -Command "kubectl run debug --image=busybox:1.36 --rm --restart=Never --attach -- wget -qO- managed-svc | Select-Object -First 5" `
        -CommandBreakdown "kubectl run debug          = throwaway Pod named 'debug'`n  --image=busybox:1.36       = tiny image with wget/nslookup (pinned tag = reproducible)`n  --rm                       = delete the Pod after it exits (auto-cleanup)`n  --restart=Never            = run-once Pod (no controller, no retries)`n  --attach                   = stream stdout back (no -it = no TTY required, CI/recording-safe)`n  --                         = end-of-kubectl-flags; everything after goes to the CONTAINER`n  wget -qO- managed-svc      = quiet mode, write to stdout, target = Service short name`n  | Select-Object -First 5   = PS-side trim so we don't flood with the full nginx page`n  Why short name? /etc/resolv.conf has 'search default.svc.cluster.local ...' -- next demo proves it" `
        -OutputFields "'<html>' / '<title>Welcome to nginx!</title>' = full path works end-to-end:`n    1. DNS 'managed-svc' resolved by CoreDNS via the search list`n    2. ClusterIP answered (kube-proxy iptables/IPVS rules in place)`n    3. DNAT to a Pod IP from the EndpointSlice`n    4. Pod served the response`n  'wget: bad address'         = layer 1 broken; CoreDNS can't resolve the name`n  'connection refused'        = layer 3 broken; EndpointSlice was empty`n  'wget: server returned ...' = layer 4 broken; Pod was unhealthy`n  Different errors point at different rungs -- this command is a 4-in-1 diagnostic"

    # ==========================================================
    # Demo 3: Namespaces + Labels
    # ==========================================================
    Write-TutorialSection `
        -Title "5/10  NAMESPACES + COMPOUND LABEL SELECTORS" `
        -Explanation "Namespaces partition cluster resources. We'll create 'staging', deploy`n  catalog into it with TWO labels (app=catalog, env=staging), then use a`n  COMPOUND selector to filter on both. Compound selectors are exam-frequent --`n  the syntax is 'key1=value1,key2=value2' (comma = AND)." `
        -Steps @(
            @{
                Beat = '5.1: SET UP STAGING'
                Command = "kubectl create namespace staging; kubectl -n staging create deployment catalog --image=nginx --replicas=2; kubectl -n staging label deployment catalog env=staging --overwrite; Start-Sleep 5"
                Breakdown = "--- Create the namespace --------------------------------------`n  kubectl create namespace staging = cluster-scoped object (no -n flag when CREATING a ns)`n  --- Deploy + apply a second label -----------------------------`n  kubectl -n staging create deployment catalog = Deployment in staging (app=catalog default)`n  --replicas=2                  = desired replica count`n  kubectl -n staging label deployment catalog env=staging --overwrite = add second label`n  --overwrite                   = required if the key already exists (safe to repeat)`n  --- Pause for label propagation -------------------------------`n  Start-Sleep 5                 = let Pods inherit the new label and become Ready before beat 5.2 filters"
                OutputFields = ''
            }
            @{
                Beat = '5.2: ISOLATION + COMPOUND SELECTOR'
                Command = "kubectl get pods -A | Select-String -Pattern '(NAMESPACE|default|staging)'; Write-Output '---'; kubectl -n staging get pods -l app=catalog,env=staging"
                Breakdown = "--- Prove namespace isolation ---------------------------------`n  kubectl get pods -A           = -A == --all-namespaces (NAMESPACE column appears)`n  Select-String -Pattern '(NAMESPACE|default|staging)' = PS filter for clean output`n  --- Compound label selector -----------------------------------`n  kubectl -n staging get pods   = scoped to staging`n  -l app=catalog,env=staging    = COMPOUND selector; comma = AND (both must match)`n  Other syntax: -l 'env in (prod,staging)', -l '!disabled', -l 'key!=value'"
                OutputFields = "-A output:`n    NAMESPACE column shows where each Pod lives`n    managed-* Pods in 'default'; catalog-* Pods in 'staging' -- proof of isolation`n    Without -A, 'kubectl get pods' would ONLY show default (invisible != nonexistent)`n  --- (divider)`n  Compound selector output:`n    Lists exactly the 2 catalog Pods that carry BOTH app=catalog AND env=staging`n    Empty result = at least one label is missing on every pod (zero AND-matches)`n  Cluster-scoped objects (Namespaces, Nodes, PVs, ClusterRoles, StorageClasses) ignore -n entirely"
            }
        )

    # ==========================================================
    # Demo 4: DNS (short name + FQDN, same beat)
    # ==========================================================
    Write-TutorialSection `
        -Title "6/10  DNS: SHORT NAME + FQDN" `
        -Explanation "Two forms of the same query. SHORT name only resolves within the same`n  namespace -- relies on /etc/resolv.conf's search list. FQDN works from`n  ANY namespace -- unambiguous, no search list needed. Use short for in-ns,`n  FQDN when you cross namespace boundaries. Same query, two scopes." `
        -Command "kubectl run dns-test --image=busybox:1.36 --rm --restart=Never --attach -- sh -c 'getent hosts managed-svc; echo ---; nslookup managed-svc.default.svc.cluster.local'" `
        -CommandBreakdown "kubectl run dns-test          = throwaway Pod named 'dns-test'`n  --image=busybox:1.36          = ships getent, nslookup, sh, wget`n  --rm --restart=Never --attach = run-once, auto-delete, stream stdout (no TTY)`n  -- sh -c '<two commands>'     = run BOTH lookups in one Pod (vs two separate run calls)`n  --- Part 1: SHORT name via getent -----------------------------`n  getent hosts managed-svc      = NSS resolver lookup (drives /etc/resolv.conf search list)`n                                   We use getent NOT busybox-nslookup because nslookup`n                                   skips the search list -- getent is the honest test.`n  --- Part 2: FQDN via nslookup ---------------------------------`n  nslookup <fqdn>               = full name -- search list irrelevant, busybox handles it fine`n  managed-svc.default.svc.cluster.local breakdown:`n    managed-svc                 = service name`n    default                     = namespace`n    svc                         = type marker (Services)`n    cluster.local               = cluster DNS suffix (default; configurable on cluster install)" `
        -OutputFields "Part 1 (getent / SHORT):`n    Single line: '<ClusterIP>  managed-svc' -- IP first, then the queried name`n    Works because /etc/resolv.conf has 'search default.svc.cluster.local svc.cluster.local cluster.local'`n    From another namespace, 'managed-svc' alone would FAIL (no entry in search path)`n    getent returns exit 0 on success, 2 on NXDOMAIN -- scriptable`n  --- (divider)`n  Part 2 (nslookup / FQDN):`n    Server:    = CoreDNS Service IP (typically 10.96.0.10)`n    Address:   = same ClusterIP that getent returned (proves FQDN == short+search)`n    FQDN is unambiguous from ANY namespace -- safe default for cross-ns lookups`n  Pod-to-Pod DNS also exists: <pod-ip-with-dashes>.<ns>.pod.cluster.local"

    # ==========================================================
    # Demo 5: The Diagnostic Ladder (the headline -- 30% of the exam)
    # ==========================================================
    Write-TutorialSection `
        -Title "7/10  LADDER: BREAK IT ON PURPOSE" `
        -Explanation "30% of the CKA exam is troubleshooting. Now we break a pod and walk`n  the diagnostic ladder: GET -> DESCRIBE -> LOGS -> EVENTS. This pod uses`n  an image tag that doesn't exist. The container runtime will fail to`n  pull it. Status is your first clue -- read it, don't describe yet." `
        -Command "kubectl run broken --image=nginx:doesnotexist --restart=Never; Start-Sleep 8; kubectl get pods broken" `
        -CommandBreakdown "kubectl run broken            = create a Pod named 'broken'`n  --image=nginx:doesnotexist    = intentionally bad tag (triggers ErrImagePull)`n  --restart=Never               = bare Pod; no controller will retry or replace it`n  Start-Sleep 8                 = let kubelet try to pull, fail, and enter backoff`n  kubectl get pods broken       = RUNG 1 of the diagnostic ladder -- read STATUS`n`n  imagePullPolicy defaults: IfNotPresent for pinned tags, Always for :latest, Never = cache only`n  Why this fails fast: kubelet attempts pull, registry returns 404/manifest-not-found,`n  kubelet flips status to ErrImagePull -> ImagePullBackOff (exponential backoff up to 5 min)" `
        -OutputFields "STATUS column = ErrImagePull -> ImagePullBackOff (after retries)`n    ErrImagePull       = first attempt failed; kubelet will retry`n    ImagePullBackOff   = after retries failed; kubelet is backing off (5s -> 10s -> 20s -> ...)`n  READY = 0/1 -- the container never started`n  RESTARTS = 0 (the pull never produced a container, so 'restarts' doesn't apply)`n  AGE = pod uptime (the API object exists, the container does not)`n  THE STATUS COLUMN IS YOUR FIRST CLUE -- don't describe yet, just read it"

    Write-TutorialSection `
        -Title "8/10  LADDER: GET (status) + DESCRIBE (events)" `
        -Explanation "Rungs 1+2 of the ladder. GET gave you ImagePullBackOff. DESCRIBE shows`n  the Events timeline at the bottom of the output: Scheduled, then`n  'Failed to pull image'. The events tell the story. Read them top-to-bottom`n  -- chronological order is the cluster's narrative." `
        -Command "kubectl describe pod broken | Select-String -Pattern '(Status:|Events:|Normal|Warning|Failed|Back-off)' -Context 0,1" `
        -CommandBreakdown "kubectl describe pod          = RUNG 2 of the diagnostic ladder -- human-readable deep-dive`n  broken                        = Pod name`n  | Select-String -Pattern '...' = PS regex filter for high-signal lines only`n  Pattern matches: Status:, Events:, Normal, Warning, Failed, Back-off`n  -Context 0,1                  = include 1 line AFTER each match for readability`n  (Without the filter, describe output is ~80 lines; this surfaces ~10)" `
        -OutputFields "THE DIAGNOSTIC LADDER -- rung 2 of 4 (GET -> DESCRIBE -> LOGS -> EVENTS).`n  Status:       = current phase (Pending while waiting on image)`n  Containers:   = per-container State, LastState, Ready, Restart Count`n  State:        = what's happening NOW -- here: Waiting: ImagePullBackOff`n  LastState:    = what happened PREVIOUSLY (Terminated/Error with exit code + reason)`n                  This field is gold for crash debugging -- shows the LAST exit code`n  Conditions:   = PodScheduled / Initialized / ContainersReady / Ready booleans`n  Events:       = chronological timeline at the BOTTOM of describe -- ALWAYS read this first`n    Normal Scheduled       = pod assigned to a node (always first event)`n    Normal Pulling         = kubelet attempting image pull`n    Warning Failed         = the smoking gun: 'Failed to pull image nginx:doesnotexist'`n    Warning BackOff        = kubelet backing off retries"

    Write-TutorialSection `
        -Title "9/10  LADDER: LOGS + EVENTS" `
        -Explanation "Rungs 3+4. No app logs -- the container never started, so kubectl logs`n  fails with 'waiting to start'. That ABSENCE is itself a clue: the problem`n  is image-related, not app-related. Cluster events confirm the timeline.`n  After a CRASH (CrashLoopBackOff), use 'kubectl logs --previous' to read`n  the dead container's stdout -- only way to see what it said before dying." `
        -Steps @(
            @{
                Beat = '9.1: RUNG 3 -- LOGS (absence-as-clue)'
                Command = "kubectl logs broken 2>&1"
                Breakdown = "--- Rung 3: container logs ------------------------------------`n  kubectl logs broken           = RUNG 3 of the ladder -- container stdout/stderr`n  2>&1                          = merge stderr so the error message is captured to the same stream`n  Add --previous (or -p) to read the LAST terminated container's logs --`n  this is the ONLY way to debug CrashLoopBackOff after the container has restarted.`n  Pinned-tag never-started case: --previous won't help (no prior container existed)."
                OutputFields = "LOGS output: 'Error from server (BadRequest): container broken is waiting to start'`n  Absence of app logs MEANS the app never ran -- narrows cause to image/scheduling`n  For CrashLoopBackOff: kubectl logs --previous (or -p) reveals what the dead container said`n  EXAM TIP: when you see CrashLoopBackOff, your hand goes to --previous automatically"
            }
            @{
                Beat = '9.2: RUNG 4 -- EVENTS (the timeline)'
                Command = "kubectl get events --sort-by=.metadata.creationTimestamp --field-selector involvedObject.name=broken"
                Breakdown = "--- Rung 4: cluster-wide events -------------------------------`n  kubectl get events            = RUNG 4 -- cluster event stream`n  --sort-by=.metadata.creationTimestamp = oldest first; newest at the bottom`n  --field-selector involvedObject.name=broken = filter to events about THIS Pod`n  Events have a TTL (default 1h) -- if the problem happened hours ago, evidence may be gone"
                OutputFields = "EVENTS columns:`n    LAST SEEN = how long ago the event last fired (events can repeat; count tracks repetitions)`n    TYPE    = Normal (informational) or Warning (something is wrong)`n    REASON  = short code: Scheduled, Pulling, Pulled, Failed, BackOff, Killing, Created, Started`n    OBJECT  = pod/broken (matches the field-selector filter)`n    MESSAGE = human-readable detail (e.g. 'Failed to pull image nginx:doesnotexist')`n  THE LADDER LIVES IN MUSCLE MEMORY: GET -> DESCRIBE -> LOGS -> EVENTS, every time`n  Sections 7-9 just walked all four rungs. That sequence solves 95% of CKA troubleshooting."
            }
        )

    # ==========================================================
    # Demo 6: Same Ladder, Any Cluster (multi-cluster only, gated)
    # ==========================================================
    # Graceful-degrade guard: only run section 10/10 when both
    # cka-dev and cka-prod are up. Single-cluster runs print a hint and skip.
    $multiClusterReady = (Test-ClusterExists -ClusterName 'cka-dev') -and (Test-ClusterExists -ClusterName 'cka-prod')

    if ($multiClusterReady) {
        Write-TutorialSection `
            -Title "10/10  SAME LADDER, ANY CLUSTER" `
            -Explanation "The ladder is context-agnostic. Switch to cka-dev (sticky), break a pod,`n  re-prove rungs 1+2 there. Then read cka-prod nodes via --context (one-shot,`n  no state mutation). Finish back on kind-${ClusterName} -- session discipline.`n  EXAM RULE: every question starts with 'use-context <name>'. Skip = 0 points." `
            -Steps @(
                @{
                    Beat = '10.1: STICKY SWITCH + LADDER ON cka-dev'
                    Command = "kubectl config use-context kind-cka-dev; kubectl get nodes; kubectl run broken-dev --image=nginx:doesnotexist --restart=Never; Start-Sleep 8; kubectl get pod broken-dev; kubectl describe pod broken-dev | Select-String -Pattern '(Status:|Events:|Failed)' -Context 0,1"
                    Breakdown = "--- STICKY switch to cka-dev ----------------------------------`n  kubectl config use-context kind-cka-dev = STICKY switch; future commands target cka-dev`n  kubectl get nodes                       = different node count proves the switch landed`n  --- Re-prove the ladder on cka-dev ----------------------------`n  kubectl run broken-dev --image=nginx:doesnotexist --restart=Never = same break, new cluster`n  Start-Sleep 8                           = let kubelet enter ImagePullBackOff`n  kubectl get pod broken-dev              = RUNG 1 (status snapshot) on cka-dev`n  kubectl describe pod broken-dev | ...   = RUNG 2 (events deep-dive) on cka-dev`n  Same image, same break, same diagnostic ladder -- only the cluster changed."
                    OutputFields = "Switched to context kind-cka-dev = sticky; current-context now reads kind-cka-dev`n  NODES output (cka-dev)            = 1 CP + 1 worker -- different topology proves the switch`n  pod/broken-dev created            = same break pattern, different cluster`n  STATUS                            = ErrImagePull or ImagePullBackOff (identical to section 7)`n  Status: / Events: / Failed lines  = same diagnostic shape on a fresh cluster`n  THE LESSON: use-context is STICKY; the diagnostic ladder is UNIVERSAL."
                }
                @{
                    Beat = '10.2: ONE-SHOT --context (no state mutation)'
                    Command = "kubectl --context kind-cka-prod get nodes; kubectl config current-context"
                    Breakdown = "--- ONE-SHOT --context override -------------------------------`n  kubectl --context kind-cka-prod get nodes = read cka-prod WITHOUT switching to it`n  --context <name>              = per-command override; bypasses kubeconfig's current-context`n  kubectl config current-context = sanity check; should STILL print kind-cka-dev`n  Use --context for verification queries when you don't want to lose your place."
                    OutputFields = "cka-prod NODES                    = 1 CP + 2 workers (cka-prod topology) returned via one-shot`n  current-context                   = STILL kind-cka-dev -- proves --context did NOT mutate state`n  THE LESSON: --context is a ONE-SHOT override. Sticky context is unchanged.`n  Sticky (use-context) = working session. One-shot (--context) = quick read."
                }
                @{
                    Beat = '10.3: CLEANUP + RETURN HOME'
                    Command = "kubectl --context kind-cka-dev delete pod broken-dev --ignore-not-found; kubectl config use-context kind-${ClusterName}; kubectl config current-context"
                    Breakdown = "--- Cross-cluster cleanup -------------------------------------`n  kubectl --context kind-cka-dev delete pod broken-dev --ignore-not-found`n    --context kind-cka-dev      = one-shot delete on cka-dev`n    --ignore-not-found          = no error if the pod was already gone (idempotent)`n  --- Sticky switch home ----------------------------------------`n  kubectl config use-context kind-${ClusterName} = STICKY switch home to the recording cluster`n  kubectl config current-context = final sanity check"
                    OutputFields = "pod broken-dev deleted            = cross-cluster cleanup via --context override`n  Switched to context kind-${ClusterName} = sticky switch home`n  Final current-context             = kind-${ClusterName} -- session lands clean for the next run`n  THE LESSON: ALWAYS land back on the cluster you started on. Session discipline = exam discipline.`n  MONEY SHOT: the diagnostic ladder is universal; ONLY the context changes between clusters."
                }
            )
    } else {
        Write-Output ""
        Write-Output "  ----------------------------------------------------------------"
        Write-Output "  Section 10/10 (multi-cluster ladder) skipped."
        Write-Output "  Bring up cka-dev + cka-prod with: ./kind-multi-up.ps1"
        Write-Output "  Then re-run this tutorial to see the context-switching demo."
        Write-Output "  ----------------------------------------------------------------"
        Write-Output ""
    }

    Write-Output ""
    Write-Output "  Module 3 walkthrough complete."
    Write-Output "  You practiced: self-healing, services + EndpointSlices, namespaces,"
    Write-Output "  DNS, and the diagnostic ladder: GET -> DESCRIBE -> LOGS -> EVENTS."
    Write-Output "  That ladder is 30% of the CKA exam. Drill it until it's automatic."
    Write-Output ""

    } finally {
        # Always cleanup, even on Ctrl-C mid-tutorial. --ignore-not-found
        # keeps this safe when some resources were never created.
        Write-Output ""
        Write-Output "  Cleaning up demo resources..."
        kubectl delete pod standalone --ignore-not-found --wait=false 2>&1 | Out-Null
        kubectl delete pod broken --ignore-not-found --wait=false 2>&1 | Out-Null
        kubectl delete svc managed-svc --ignore-not-found 2>&1 | Out-Null
        kubectl delete deployment managed --ignore-not-found 2>&1 | Out-Null
        kubectl delete namespace staging --ignore-not-found --wait=false 2>&1 | Out-Null
        # Demo 6 leftover: broken-dev lives on cka-dev (NOT the default cluster).
        # Belt and suspenders -- the section 21/21 command chain already deletes it,
        # but a Ctrl-C mid-section-20 would leave it behind. Guarded so we only call
        # kubectl when cka-dev exists (avoids context errors on single-cluster runs).
        if (Test-ClusterExists -ClusterName 'cka-dev') {
            kubectl --context kind-cka-dev delete pod broken-dev --ignore-not-found 2>&1 | Out-Null
        }
        # If a Ctrl-C landed mid-section-20, the active context is kind-cka-dev.
        # Force the session back to the M03 default so the next tutorial run starts
        # on the correct cluster.
        kubectl config use-context "kind-$ClusterName" 2>&1 | Out-Null
        Write-Output "  Done."
    }
}
