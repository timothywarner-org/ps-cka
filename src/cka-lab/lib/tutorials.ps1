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
# ---------------------------------------------------------------
function Write-TutorialSection {
    param(
        [string]$Title,
        [string]$Explanation,
        [string]$Command,
        [string]$CommandBreakdown,
        [string]$OutputFields,
        [switch]$NoRun
    )
    Write-Output ""
    Write-Output "  ================================================================"
    Write-Output "  $Title"
    Write-Output "  ================================================================"
    Write-Output ""
    Write-Output ("  " + $Explanation)
    Write-Output ""
    # Command line in bright yellow so it pops on camera. Write-Host bypasses
    # the success stream, which is fine — tutorials are interactive-only and
    # nothing in the repo captures or pipes this output.
    Write-Host "  Command:  $($Script:BrightYellow)$Command$($Script:AnsiReset)"
    if ($CommandBreakdown) {
        Write-Output "  ---- What each part does -----------------------------------"
        Write-Output ("  " + $CommandBreakdown)
    }
    Write-Output "  ----------------------------------------------------------------"
    if (-not $NoRun) {
        Write-Output ""
        # Output in Wong sky blue so cause (yellow Command:) → effect (blue
        # output) reads instantly on camera. Write-Host so the ANSI escapes
        # are honored. Tutorial output is interactive-only; nothing captures
        # this stream (same rationale as the Command: line above).
        Invoke-Expression $Command 2>&1 | ForEach-Object {
            Write-Host "  $($Script:SkyBlue)$_$($Script:AnsiReset)"
        }
    }
    if ($OutputFields) {
        Write-Output ""
        Write-Output "  ---- What you just saw -------------------------------------"
        Write-Output ("  " + $OutputFields)
    }
    Write-Output ""
    Read-Host "  Press Enter to continue"
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
        "imperative creation, dry-run YAML, kubectl explain,"
        "resource querying, and context switching."
    )

    # Wrap the body in try/finally so Ctrl-C (or any mid-tutorial exit) still
    # cleans up demo resources. Without this, a learner re-running the tutorial
    # would collide on existing pod/deployment/service names.
    try {

    # --- Demo 1: Imperative Speed Run ---
    Write-TutorialSection `
        -Title "1/16  IMPERATIVE: CREATE A POD" `
        -Explanation "Pods are the atomic unit. This is the fastest way to get a container running.`n  No YAML, no files -- just one command." `
        -Command "kubectl run nginx --image=nginx" `
        -CommandBreakdown "kubectl run    = imperative pod creation (fastest path to a running container)`n  nginx          = pod name (also becomes the default container name)`n  --image=nginx  = container image; no tag means :latest from Docker Hub" `
        -OutputFields "pod/nginx created = confirmation the API server persisted the object`n  Next: the scheduler picks a node, kubelet pulls the image, container starts`n  Check progress with: kubectl get pods   (STATUS cycles Pending -> ContainerCreating -> Running)"

    Write-TutorialSection `
        -Title "2/16  IMPERATIVE: CREATE A DEPLOYMENT" `
        -Explanation "Deployments manage rollouts. Three things just happened:`n  a Deployment, a ReplicaSet, and 3 Pods. All from one command." `
        -Command "kubectl create deployment web --image=nginx --replicas=3" `
        -CommandBreakdown "kubectl create  = imperative create (vs apply, which is declarative from YAML)`n  deployment      = resource kind (short: deploy)`n  web             = Deployment name; becomes the label selector app=web`n  --image=nginx   = container image used in the pod template`n  --replicas=3    = desired pod count; ReplicaSet enforces this continuously" `
        -OutputFields "deployment.apps/web created = Deployment object persisted`n  Chain spawned: Deployment -> ReplicaSet -> 3 Pods (all labeled app=web)`n  Pod names follow <deploy>-<rs-hash>-<pod-hash> (e.g. web-7d4b9c8f-xkl2m)`n  Verify the chain with: kubectl get deploy,rs,pods"

    Write-TutorialSection `
        -Title "3/16  IMPERATIVE: EXPOSE AS A SERVICE" `
        -Explanation "Services give Pods a stable network endpoint. DNS is auto-created:`n  web.default.svc.cluster.local now resolves to the ClusterIP." `
        -Command "kubectl expose deployment web --port=80 --type=ClusterIP" `
        -CommandBreakdown "kubectl expose  = imperative Service creation from an existing workload`n  deployment web  = source resource (Service inherits its selector: app=web)`n  --port=80       = Service port (what clients connect to)`n  --type=ClusterIP = internal-only virtual IP (default; other options: NodePort, LoadBalancer)" `
        -OutputFields "service/web exposed = Service object created with a ClusterIP`n  Selector = app=web (Service tracks pods with this label)`n  DNS auto-created: web.default.svc.cluster.local`n  Endpoints object populated with backend pod IPs (check: kubectl get endpoints web)"

    Write-TutorialSection `
        -Title "4/16  IMPERATIVE: CONFIGMAP + SECRET + RBAC" `
        -Explanation "Three more resources in three commands. That's 7 resources total`n  with zero YAML files. Speed wins on the exam." `
        -Command "kubectl create configmap app-config --from-literal=env=prod; kubectl create secret generic db-pass --from-literal=password=s3cret; kubectl create role pod-reader --verb=get,list,watch --resource=pods; kubectl create rolebinding pod-reader-binding --role=pod-reader --user=jane" `
        -CommandBreakdown "create configmap     = non-secret key/value config (--from-literal for inline, --from-file for files)`n  create secret generic = base64-encoded secret (generic = opaque; other types: tls, docker-registry)`n  --from-literal=K=V   = inline key/value data (repeat for multiple)`n  create role          = namespaced permissions (--verb=what, --resource=on-what)`n  create rolebinding   = binds a Role to a subject (--user, --group, or --serviceaccount)`n  ; (semicolon)        = PowerShell command separator; runs four commands in sequence" `
        -OutputFields "Four 'created' confirmations -- one per resource`n  configmap/app-config       = plain config (not encrypted at rest without KMS)`n  secret/db-pass             = base64-encoded (NOT encrypted -- use kubectl get secret -o yaml to see)`n  role.rbac.../pod-reader    = allows get/list/watch pods in current namespace only`n  rolebinding/...-binding    = grants that Role to user 'jane'"

    Write-TutorialSection `
        -Title "5/16  SEE EVERYTHING" `
        -Explanation "Let's see the full picture -- Pods, Services, Deployments, ReplicaSets." `
        -Command "kubectl get all" `
        -CommandBreakdown "kubectl get   = list resources from the API server`n  all           = shortcut alias for pods,services,deployments,replicasets,statefulsets,daemonsets,jobs,cronjobs`n  (note: 'all' does NOT include configmaps, secrets, ingresses, PVCs, RBAC -- misleading name)" `
        -OutputFields "NAME          = <kind>/<name> (e.g. pod/nginx, service/web, deployment.apps/web)`n  READY         = pods: containers ready/total; deploys/rs: ready-replicas/desired`n  STATUS        = pod phase (Running, Pending, CrashLoopBackOff)`n  RESTARTS      = container restart count`n  AGE           = time since creation`n  For Services: TYPE, CLUSTER-IP, EXTERNAL-IP, PORT(S) columns appear"

    # --- Demo 2: Dry-Run YAML Pipeline ---
    Write-TutorialSection `
        -Title "6/16  DRY-RUN: GENERATE YAML WITHOUT CREATING" `
        -Explanation "--dry-run=client validates and generates a manifest WITHOUT persisting.`n  This is the professional way: generate, edit, apply. GitOps-ready." `
        -Command "kubectl run temp --image=busybox --restart=Never --dry-run=client -o yaml" `
        -CommandBreakdown "kubectl run        = imperative pod creation (same as before)`n  temp               = pod name`n  --image=busybox    = tiny image useful for scratch pods / debug`n  --restart=Never    = sets spec.restartPolicy (Never = bare pod, not managed by a controller)`n  --dry-run=client   = render the object locally; do NOT send to the API server`n  -o yaml            = output format; perfect for redirecting to a file with > pod.yaml" `
        -OutputFields "apiVersion: v1       = API group+version the resource belongs to (core group for Pod)`n  kind: Pod            = resource type`n  metadata:            = name, labels, annotations, namespace (object identity)`n  spec:                = desired state (containers, image, restartPolicy, resources)`n  status:              = omitted in dry-run output (populated by the cluster at runtime)`n  Pipe this to kubectl apply -f - to actually create it, or save with > pod.yaml and edit"

    Write-TutorialSection `
        -Title "7/16  DRY-RUN: DEPLOYMENT YAML" `
        -Explanation "Works for any resource type. Notice the nested structure:`n  spec.replicas, spec.selector.matchLabels, spec.template.spec.containers." `
        -Command "kubectl create deployment limited --image=nginx --replicas=2 --dry-run=client -o yaml | Select-Object -First 25" `
        -CommandBreakdown "kubectl create deployment = imperative Deployment generator`n  limited                   = Deployment name (and default label: app=limited)`n  --image=nginx             = container image for the pod template`n  --replicas=2              = desired pod count`n  --dry-run=client          = generate locally; do NOT hit the API`n  -o yaml                   = emit as YAML`n  | Select-Object -First 25 = PowerShell pipeline: keep first 25 lines (trim output for display)" `
        -OutputFields "apiVersion: apps/v1         = Deployments live in the 'apps' API group`n  kind: Deployment`n  spec.replicas: 2            = desired pod count`n  spec.selector.matchLabels   = which pods this Deployment manages (app=limited)`n  spec.template               = the pod template; everything under this = one pod`n  spec.template.spec.containers = the container list (image, ports, resources, probes)`n  strategy, revisionHistoryLimit, progressDeadlineSeconds = rollout behavior (cut off by -First 25)"

    # --- Demo 3: kubectl explain ---
    Write-TutorialSection `
        -Title "8/16  EXPLAIN: POD CONTAINER SPEC" `
        -Explanation "kubectl explain is your in-terminal API reference. You don't need to`n  memorize field names -- just ask Kubernetes what's available." `
        -Command "kubectl explain pod.spec.containers.resources" `
        -CommandBreakdown "kubectl explain   = pull OpenAPI schema from the live cluster (no internet needed)`n  pod               = starting resource`n  .spec.containers  = walk into the containers array (dot-path into the schema)`n  .resources        = land on the resources field (requests / limits)" `
        -OutputFields "KIND         = resource kind (Pod)`n  VERSION      = API group/version (v1 for core Pod)`n  FIELD        = the field you asked about (resources)`n  DESCRIPTION  = human-readable docs for the field`n  FIELDS:      = sub-fields available (claims, limits, requests) -- walk deeper with a longer dot-path`n  Exam tip: use 'kubectl explain pod.spec --recursive' to dump the whole tree"

    Write-TutorialSection `
        -Title "9/16  EXPLAIN: DEPLOYMENT STRATEGY (RECURSIVE)" `
        -Explanation "--recursive shows the entire tree. This is gold for complex resources`n  like Deployment rollout strategies (RollingUpdate, maxSurge, maxUnavailable)." `
        -Command "kubectl explain deployment.spec.strategy --recursive" `
        -CommandBreakdown "kubectl explain           = OpenAPI schema lookup`n  deployment.spec.strategy  = dot-path into the Deployment rollout strategy field`n  --recursive               = expand every nested sub-field (no need to keep re-running explain)" `
        -OutputFields "KIND / VERSION / FIELD   = same headers as before (Deployment, apps/v1, strategy)`n  FIELDS (tree):`n    rollingUpdate          = struct for rolling rollout tuning`n      maxSurge             = extra pods allowed above replicas during rollout (int or %)`n      maxUnavailable       = pods allowed to be down during rollout (int or %)`n    type                   = 'RollingUpdate' (default) or 'Recreate' (kill-all-then-create)`n  Exam tip: know the defaults -- maxSurge=25%, maxUnavailable=25%"

    Write-TutorialSection `
        -Title "10/16  API RESOURCES: SHORTNAMES" `
        -Explanation "Can't remember if it's 'svc' or 'service'? This is the source of truth.`n  Shortnames save real time: po, svc, deploy, cm, ns, sa, pv, pvc." `
        -Command "kubectl api-resources | Select-String -Pattern '(^NAME|\bpods?\b|\bservices?\b|\bdeploy\w*|\bconfigmap\w*|\bsecrets?\b|\broles?\b|\brolebindings?\b)' | Select-Object -First 10" `
        -CommandBreakdown "kubectl api-resources = lists every resource kind the API server knows`n  | Select-String       = PowerShell grep (filters matching lines)`n  -Pattern '(...)'      = regex: header line + pod/service/deploy/configmap/secret/role/rolebinding rows`n  \b...\b               = word boundaries so 'role' doesn't match 'rolebinding' etc.`n  | Select-Object -First 10 = keep first 10 lines for a clean view" `
        -OutputFields "NAME         = canonical resource name (pods, services, deployments, configmaps, secrets, roles, rolebindings)`n  SHORTNAMES   = the gold column -- po, svc, deploy, cm, (none), (none), (none)`n  APIVERSION   = group/version (v1 for core; apps/v1 for deployments; rbac.authorization.k8s.io/v1 for roles)`n  NAMESPACED   = true (scoped to a namespace) or false (cluster-scoped)`n  KIND         = CamelCase kind name used in YAML (Pod, Service, Deployment, ...)"

    # --- Demo 4: Querying ---
    Write-TutorialSection `
        -Title "11/16  QUERY: LABEL SELECTOR" `
        -Explanation "Labels are how Kubernetes organizes resources. This returns only`n  Pods with the label app=web -- filtering out everything else." `
        -Command "kubectl get pods -l app=web" `
        -CommandBreakdown "kubectl get pods = list Pod resources`n  -l app=web       = label selector (short for --selector); matches pods labeled app=web`n  (other syntax: -l 'env in (prod,staging)', -l '!disabled', -l app=web,tier=frontend)" `
        -OutputFields "NAME      = pod name (Deployment-owned pods carry the <deploy>-<rs>-<pod> suffix pattern)`n  READY     = ready containers / total containers`n  STATUS    = phase (Running / Pending / CrashLoopBackOff / ...)`n  RESTARTS  = container restart count`n  AGE       = pod uptime`n  No matching pods = empty result (not an error); selector excluded everything"

    Write-TutorialSection `
        -Title "12/16  QUERY: FIELD SELECTOR" `
        -Explanation "Field selectors filter by built-in fields (not labels).`n  status.phase=Running shows only active pods, hiding Pending or Failed." `
        -Command "kubectl get pods --field-selector status.phase=Running" `
        -CommandBreakdown "kubectl get pods      = list Pods`n  --field-selector K=V  = server-side filter on built-in object FIELDS (not labels)`n  status.phase=Running  = match only pods whose .status.phase == Running`n  (supported fields are resource-specific; Pod supports status.phase, spec.nodeName, metadata.name/namespace)" `
        -OutputFields "Same columns as 'kubectl get pods' (NAME, READY, STATUS, RESTARTS, AGE)`n  But every row's STATUS column will be 'Running'`n  Pending, Failed, Succeeded, Unknown pods are hidden`n  Exam tip: combine with -l for label + field filtering in one call"

    Write-TutorialSection `
        -Title "13/16  QUERY: JSONPATH EXTRACTION" `
        -Explanation "JSONPath pulls out exactly the data you need for scripting.`n  No wasted columns -- just pod names, ready for piping to xargs." `
        -Command "kubectl get pods -o jsonpath='{.items[*].metadata.name}'" `
        -CommandBreakdown "kubectl get pods   = list pods (returns a List object with an .items array)`n  -o jsonpath='...'  = extract fields using JSONPath expressions`n  {.items[*]}        = iterate over every element of the items array`n  [*]                = wildcard index (all elements)`n  .metadata.name     = pick the metadata.name field from each`n  Result: space-separated pod names (NOT a table, no headers)" `
        -OutputFields "Space-separated list: nginx web-xxxx-aaa web-xxxx-bbb web-xxxx-ccc`n  No column headers, no STATUS, no AGE -- just the raw strings you asked for`n  Perfect for: for p in `$(...); do kubectl logs `$p; done`n  Related: -o jsonpath-as-json='{...}' emits JSON; -o go-template= for Go templates"

    Write-TutorialSection `
        -Title "14/16  QUERY: CUSTOM COLUMNS" `
        -Explanation "Custom columns let you see Pod name, which Node it's on, and status`n  in one clean view. Super useful for debugging scheduling issues." `
        -Command "kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase" `
        -CommandBreakdown "kubectl get pods          = list pods`n  -o custom-columns=...     = render as a table you design`n  Format: HEADER:jsonpath,HEADER:jsonpath,...`n  NAME:.metadata.name       = column 1 header=NAME, value=pod name`n  NODE:.spec.nodeName       = column 2 header=NODE, value=which node the scheduler placed it on`n  STATUS:.status.phase      = column 3 header=STATUS, value=pod phase`n  (variant: -o custom-columns-file=cols.txt to load from a file)" `
        -OutputFields "NAME     = pod name`n  NODE     = the node the scheduler picked (empty if still Pending / unscheduled)`n  STATUS   = Pod phase (Running, Pending, Succeeded, Failed, Unknown)`n  Only these three columns -- no AGE, no READY, no RESTARTS`n  Exam tip: use this to quickly spot scheduling failures (NODE column empty)"

    Write-TutorialSection `
        -Title "15/16  QUERY: SORTED EVENTS" `
        -Explanation "Events are notifications -- Pod created, image pulled, container restarted.`n  Sorting by timestamp shows WHEN things happened. Debugging gold." `
        -Command "kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 10" `
        -CommandBreakdown "kubectl get events                     = list Event objects (default sort is unstable)`n  --sort-by=.metadata.creationTimestamp  = sort ascending by when the event was created`n  | Select-Object -Last 10               = PowerShell: keep the most recent 10 rows`n  (default behavior shows events from current namespace; add -A for all namespaces)" `
        -OutputFields "LAST SEEN  = how long ago the event last fired (events can repeat; count tracks repetitions)`n  TYPE       = Normal (informational) or Warning (trouble -- ImagePullBackOff, FailedScheduling, etc.)`n  REASON     = short code (Scheduled, Pulled, Created, Started, Killing, BackOff, Failed)`n  OBJECT     = what the event is about (pod/nginx, deployment.apps/web, ...)`n  MESSAGE    = human-readable detail (the actual story)`n  Exam tip: Warning events at the bottom = your most recent problem"

    # --- Demo 5: Context Switching ---
    Write-TutorialSection `
        -Title "16/16  CONTEXT: VERIFY CURRENT CONTEXT" `
        -Explanation "The CKA exam has 17 questions across 4 clusters. One wrong context`n  = zero points. Always verify before ANY destructive command.`n  The asterisk (*) marks your current context." `
        -Command "kubectl config get-contexts" `
        -CommandBreakdown "kubectl config = read/write the active kubeconfig file (~/.kube/config by default)`n  get-contexts   = list every context defined in kubeconfig`n  (A 'context' = named triple of CLUSTER + USER + NAMESPACE -- switches all three at once)`n  (Related: 'use-context <name>' switches; 'current-context' prints just the active one)" `
        -OutputFields "CURRENT    = asterisk (*) marks the active context`n  NAME       = context name (e.g. kind-cka-lab) -- this is what 'use-context' takes`n  CLUSTER    = cluster identity (API server endpoint + CA cert)`n  AUTHINFO   = credentials (user/token/cert used to authenticate)`n  NAMESPACE  = default namespace for this context (blank = 'default')`n  Exam tip: on exam, always 'kubectl config use-context <target>' before each question -- wrong cluster = 0 pts"

    Write-Output ""
    Write-Output "  Module 2 walkthrough complete."
    Write-Output "  You practiced: imperative commands, dry-run YAML, kubectl explain,"
    Write-Output "  resource querying, and context switching."
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
        "self-healing, services, namespaces, DNS, and the"
        "diagnostic ladder (30% of the CKA exam)."
    )

    # Wrap the body in try/finally so Ctrl-C (or any mid-tutorial exit) still
    # cleans up demo resources (standalone pod, managed deployment, service,
    # staging namespace, broken pod). Without this, a re-run collides.
    try {

    # ==========================================================
    # Demo 1: Bare Pod vs. Managed Deployment
    # ==========================================================
    Write-TutorialSection `
        -Title "1/18  CREATE A BARE POD" `
        -Explanation "This pod has no controller. If it dies, nobody brings it back.`n  That's what 'bare pod' means -- ephemeral, unmanaged, alone." `
        -Command "kubectl run standalone --image=nginx --restart=Never" `
        -CommandBreakdown "kubectl run       = imperative create of a single Pod`n  standalone        = pod name (metadata.name)`n  --image=nginx     = container image (defaults to :latest tag)`n  --restart=Never   = makes it a bare Pod (Always=default for 'run', OnFailure=Job-like)" `
        -OutputFields "'pod/standalone created' = API server accepted the object and wrote it to etcd`n  No controller owns it -- nothing will recreate it if it dies or is deleted"

    Write-TutorialSection `
        -Title "2/18  CREATE A MANAGED DEPLOYMENT" `
        -Explanation "A Deployment owns a ReplicaSet, which owns the Pods.`n  This chain enables self-healing: desired=2, so the controller`n  will always maintain 2 running Pods." `
        -Command "kubectl create deployment managed --image=nginx --replicas=2" `
        -CommandBreakdown "kubectl create deployment = imperative Deployment creation`n  managed                   = Deployment name (also seeds app=managed label)`n  --image=nginx             = container image for the Pod template`n  --replicas=2              = desired replica count -- the reconciliation target" `
        -OutputFields "'deployment.apps/managed created' = 3 objects actually exist now:`n    Deployment (you) -> ReplicaSet (auto) -> 2 Pods (auto)`n  Ownership is visible via metadata.ownerReferences on each child"

    Write-TutorialSection `
        -Title "3/18  SEE BOTH SIDE BY SIDE" `
        -Explanation "Notice the standalone pod and the two managed pods.`n  The managed pods have a hash suffix -- that's the ReplicaSet's fingerprint." `
        -Command "kubectl get pods -o wide" `
        -CommandBreakdown "kubectl get  = LIST (first rung of the diagnostic ladder)`n  pods         = resource type (short: po)`n  -o wide      = add NODE, IP, NOMINATED NODE, READINESS GATES columns" `
        -OutputFields "NAME     = 'standalone' vs 'managed-<rs-hash>-<pod-hash>' reveals ownership`n  READY    = containers ready / total (e.g. 1/1)`n  STATUS   = Running / Pending / ContainerCreating / Error / CrashLoopBackOff`n  RESTARTS = restart count -- non-zero is a clue worth chasing`n  IP       = Pod IP on the CNI overlay (not the Service IP)`n  NODE     = which worker the scheduler placed it on"

    Write-TutorialSection `
        -Title "4/18  DELETE THE BARE POD" `
        -Explanation "Gone forever. No controller, no comeback. This is why you almost never`n  use bare pods in production -- they're fire-and-forget." `
        -Command "kubectl delete pod standalone --grace-period=1; Start-Sleep 3; kubectl get pods" `
        -CommandBreakdown "kubectl delete pod = remove a Pod object`n  standalone         = target name`n  --grace-period=1   = override default 30s SIGTERM window (speeds the demo)`n  Start-Sleep 3      = let the API server finish tombstoning`n  kubectl get pods   = confirm it's gone (no resurrection)" `
        -OutputFields "'pod standalone deleted' = tombstoned; finalizers cleared; object removed`n  Post-delete list shows ONLY managed-<hash> pods -- bare pod is history"

    Write-TutorialSection `
        -Title "5/18  SELF-HEALING: DELETE A MANAGED POD" `
        -Explanation "Watch the magic. We'll delete one managed pod and the ReplicaSet will`n  immediately create a replacement. The name changes but the count stays at 2.`n  This IS the reconciliation loop." `
        -Command "`$pod = (kubectl get pods -l app=managed -o jsonpath='{.items[0].metadata.name}'); kubectl delete pod `$pod --grace-period=1; Start-Sleep 5; kubectl get pods -l app=managed" `
        -CommandBreakdown "`$pod = ...                           = capture the first managed Pod name into a PS var`n  -l app=managed                        = label selector (only Pods labeled app=managed)`n  jsonpath='{.items[0].metadata.name}'  = pick first result's name`n  kubectl delete pod `$pod             = kill the captured Pod`n  --grace-period=1                      = fast SIGTERM for the demo`n  Start-Sleep 5                         = give the ReplicaSet controller time to reconcile`n  kubectl get pods -l app=managed       = confirm replica count bounced back to 2" `
        -OutputFields "One Pod name DIFFERS from before -- the replacement has a new <pod-hash> suffix`n  Count stays at desired=2 -- the ReplicaSet controller reconciled`n  AGE column: one Pod is seconds old (the replacement), the other is minutes old"

    Write-TutorialSection `
        -Title "6/18  THE REPLICASET" `
        -Explanation "The ReplicaSet is the controller that owns these pods.`n  Desired=2, Current=2, Ready=2. The reconciliation loop is satisfied." `
        -Command "kubectl get replicasets" `
        -CommandBreakdown "kubectl get    = list resources`n  replicasets    = resource type (short: rs) -- the controller that enforces replica count" `
        -OutputFields "NAME     = managed-<hash>  (hash = pod-template-hash; new one appears on rolling update)`n  DESIRED  = replicas field from the Deployment spec`n  CURRENT  = Pods the RS actually created`n  READY    = Pods passing readiness probes (what Service endpoints use)`n  AGE      = time since the ReplicaSet was created"

    # ==========================================================
    # Demo 2: Services & the Selector-Label Contract
    # ==========================================================
    Write-TutorialSection `
        -Title "7/18  CREATE A CLUSTERIP SERVICE" `
        -Explanation "Services are Kubernetes' internal load balancer. This Service targets`n  pods with the label app=managed and gives them a stable ClusterIP." `
        -Command "kubectl expose deployment managed --port=80 --type=ClusterIP --name=managed-svc" `
        -CommandBreakdown "kubectl expose deployment = create a Service from a Deployment's selector`n  managed                   = source Deployment (copies its selector: app=managed)`n  --port=80                 = Service port (what clients connect to)`n  --type=ClusterIP          = in-cluster only (NodePort adds host port 30000-32767; LoadBalancer adds cloud LB)`n  --name=managed-svc        = Service name (deterministic for the demo)" `
        -OutputFields "'service/managed-svc exposed' = Service object created`n  A ClusterIP is allocated from the service CIDR (e.g. 10.96.x.x)`n  DNS entry managed-svc.default.svc.cluster.local is auto-registered in CoreDNS`n  An Endpoints object with the same name is auto-created from pod IPs"

    Write-TutorialSection `
        -Title "8/18  ENDPOINTS: THE SELECTOR-LABEL CONTRACT" `
        -Explanation "Endpoints are the glue. The Service selector finds pods with app=managed`n  and populates this list with their IPs. When a pod disappears, its IP is removed.`n  When a new pod appears with the right label, its IP is added. Real-time." `
        -Command "kubectl get endpoints managed-svc" `
        -CommandBreakdown "kubectl get    = list resources`n  endpoints      = resource type (short: ep) -- Pod IPs behind a Service`n  managed-svc    = filter to the single Endpoints object we care about" `
        -OutputFields "NAME       = managed-svc (matches the Service name 1:1)`n  ENDPOINTS  = comma-separated <podIP>:<port> list (e.g. 10.244.1.5:80,10.244.2.7:80)`n  AGE        = when the Endpoints object was created`n  Empty ENDPOINTS = selector matches NO ready Pods -- classic 'Service is broken' clue"

    Write-TutorialSection `
        -Title "9/18  SCALE UP AND WATCH ENDPOINTS GROW" `
        -Explanation "Scaling to 4 replicas creates 2 new pods. The Service controller`n  watches them appear and auto-adds their IPs to Endpoints." `
        -Command "kubectl scale deployment managed --replicas=4; Start-Sleep 8; kubectl get endpoints managed-svc" `
        -CommandBreakdown "kubectl scale deployment = imperative replica count change`n  managed                  = target Deployment`n  --replicas=4             = new desired count (edits spec.replicas in-place)`n  Start-Sleep 8            = let new Pods reach Ready and get added to Endpoints`n  kubectl get endpoints    = verify the Endpoints list grew" `
        -OutputFields "ENDPOINTS column now lists 4 <podIP>:<port> entries (was 2)`n  Only READY Pods are included -- Pods stuck in Pending/ContainerCreating won't appear yet`n  This happens automatically -- no manual Endpoints editing ever"

    Write-TutorialSection `
        -Title "10/18  TEST THE SERVICE FROM INSIDE THE CLUSTER" `
        -Explanation "ClusterIPs are NOT routable from your laptop -- you must test from inside.`n  We'll spin up a debug pod and wget the Service name. If you see the nginx`n  welcome page, the Service is working." `
        -Command "kubectl run debug --image=busybox:1.36 --rm --restart=Never --attach -- wget -qO- managed-svc | Select-Object -First 5" `
        -CommandBreakdown "kubectl run debug          = create a throwaway Pod named 'debug'`n  --image=busybox:1.36       = tiny image with wget/nslookup (pinned tag = reproducible)`n  --rm                       = delete the Pod after it exits`n  --restart=Never            = run-once Pod (no controller, no retries)`n  --attach                   = stream stdout back to your terminal (no -it = no TTY, CI-safe)`n  -- wget -qO- managed-svc   = command run in the container (quiet, write to stdout)`n  Select-Object -First 5     = PS-side trim so we don't flood with the full nginx page" `
        -OutputFields "'<html>' / '<title>Welcome to nginx!</title>' = Service routing works end-to-end`n  DNS 'managed-svc' resolved (CoreDNS), ClusterIP answered, kube-proxy DNATed to a Pod IP`n  'wget: bad address' = DNS broken; 'connection refused' = Endpoints list was empty`n  --attach vs kubectl exec: attach streams the FIRST process in a freshly-created pod;`n    exec -it opens a NEW process inside an existing running pod (different use case)"

    # ==========================================================
    # Demo 3: Namespaces & Labels
    # ==========================================================
    Write-TutorialSection `
        -Title "11/18  CREATE A NAMESPACE" `
        -Explanation "Namespaces partition cluster resources. Resources in one namespace`n  are invisible from another by default. Let's create 'staging'." `
        -Command "kubectl create namespace staging" `
        -CommandBreakdown "kubectl create   = imperative creation of a cluster-scoped object`n  namespace        = resource type (short: ns)`n  staging          = name of the new namespace" `
        -OutputFields "'namespace/staging created' = API server accepted the object`n  Namespace is cluster-scoped (no -n flag used when creating it)`n  Most resources (Pods, Deployments, Services) are namespace-scoped`n  Cluster-scoped examples: Nodes, PersistentVolumes, ClusterRoles, StorageClasses"

    Write-TutorialSection `
        -Title "12/18  DEPLOY INTO THE NAMESPACE" `
        -Explanation "Use -n staging to target the namespace. These pods won't show up in`n  'kubectl get pods' (which defaults to the 'default' namespace)." `
        -Command "kubectl -n staging create deployment catalog --image=nginx --replicas=2; Start-Sleep 5; kubectl get pods -A | Select-String -Pattern '(NAMESPACE|default|staging)'" `
        -CommandBreakdown "kubectl -n staging       = target namespace for THIS command (overrides current context)`n  create deployment catalog = new Deployment named 'catalog' in staging`n  --image=nginx            = container image`n  --replicas=2             = desired replica count`n  Start-Sleep 5            = let Pods spin up before listing`n  kubectl get pods -A      = list ALL namespaces (-A == --all-namespaces)`n  Select-String -Pattern   = PS filter to show header + relevant namespaces" `
        -OutputFields "NAMESPACE = first column when -A is used (tells you which namespace each Pod lives in)`n  NAME      = pod name; catalog-<hash> Pods appear in 'staging' only`n  managed-* Pods show in 'default'; catalog-* Pods show in 'staging' -- proof of isolation`n  Without -A, 'kubectl get pods' would ONLY show default namespace (invisible != nonexistent)"

    # ==========================================================
    # Demo 4: DNS
    # ==========================================================
    Write-TutorialSection `
        -Title "13/18  DNS: SHORT NAME RESOLUTION" `
        -Explanation "Pods can reach Services by name within the same namespace.`n  'managed-svc' resolves to the ClusterIP because both are in 'default'.`n  NOTE: busybox's nslookup skips the search list, so we use 'getent hosts'`n  which drives the full resolver -- that's the honest proof ndots+search work." `
        -Command "kubectl run dns-short --image=busybox:1.36 --rm --restart=Never --attach -- getent hosts managed-svc" `
        -CommandBreakdown "kubectl run dns-short     = throwaway Pod named 'dns-short'`n  --image=busybox:1.36      = ships getent, nslookup, wget, sh`n  --rm --restart=Never      = run-once, auto-delete when done`n  --attach                  = stream stdout back (no TTY -- safe in CI / recordings)`n  -- getent hosts managed-svc = NSS resolver lookup; honors /etc/resolv.conf`n                                search list + ndots (unlike busybox nslookup)" `
        -OutputFields "Single output line: '<ClusterIP>  managed-svc' -- IP first, then the name queried`n  Short-name resolution works because /etc/resolv.conf has 'search default.svc.cluster.local ...'`n  getent returns exit 0 on success, 2 on NXDOMAIN -- scriptable in exam break/fix work`n  From another namespace, 'managed-svc' alone would FAIL to resolve"

    Write-TutorialSection `
        -Title "14/18  DNS: FQDN FOR CROSS-NAMESPACE" `
        -Explanation "The Fully Qualified Domain Name works from ANY namespace:`n  <service>.<namespace>.svc.cluster.local`n  Use this when crossing namespace boundaries. FQDN is unambiguous,`n  so busybox's nslookup handles it fine here -- no search list needed." `
        -Command "kubectl run dns-fqdn --image=busybox:1.36 --rm --restart=Never --attach -- nslookup managed-svc.default.svc.cluster.local" `
        -CommandBreakdown "kubectl run dns-fqdn          = throwaway Pod named 'dns-fqdn'`n  --image=busybox:1.36          = includes nslookup`n  --rm --restart=Never --attach = run-once, auto-delete, stream stdout`n  -- nslookup <fqdn>            = lookup the fully qualified name:`n    managed-svc                 = service name`n    default                     = namespace`n    svc                         = type marker (services)`n    cluster.local               = cluster DNS suffix (default)" `
        -OutputFields "Server:    = CoreDNS Service IP (10.96.0.10)`n  Address:   = same ClusterIP returned by the getent lookup above -- proves FQDN == short+search`n  FQDN is unambiguous from ANY namespace -- short names only work within same NS`n  Pod-to-Pod DNS also exists: <pod-ip-with-dashes>.<ns>.pod.cluster.local"

    # ==========================================================
    # Demo 5: The Diagnostic Ladder
    # ==========================================================
    Write-TutorialSection `
        -Title "15/18  DIAGNOSTIC LADDER: CREATE A BROKEN POD" `
        -Explanation "This pod uses an image tag that doesn't exist: nginx:doesnotexist.`n  The container runtime will fail to pull it. Let's watch the diagnostic`n  ladder solve it." `
        -Command "kubectl run broken --image=nginx:doesnotexist --restart=Never; Start-Sleep 8; kubectl get pods broken" `
        -CommandBreakdown "kubectl run broken          = create a Pod named 'broken'`n  --image=nginx:doesnotexist  = intentionally bad tag (triggers ErrImagePull)`n  --restart=Never             = bare Pod; no controller will retry or replace it`n  Start-Sleep 8               = let kubelet try to pull, fail, and enter backoff`n  kubectl get pods broken     = RUNG 1 of the diagnostic ladder -- see STATUS`n`n  Note: imagePullPolicy defaults to IfNotPresent for pinned tags, Always for :latest.`n  The 3 policies: Always (pull every time), IfNotPresent (use cache), Never (cache only)." `
        -OutputFields "STATUS will be one of: ErrImagePull -> ImagePullBackOff (after retries)`n  READY = 0/1 -- the container never started`n  RESTARTS = 0 (kubelet's backoff isn't counted as restarts)`n  The STATUS column is your FIRST CLUE -- don't describe yet, just read the status"

    Write-TutorialSection `
        -Title "16/18  STEP 1: GET (status clue) + STEP 2: DESCRIBE (events)" `
        -Explanation "GET shows ImagePullBackOff -- the image couldn't be pulled.`n  DESCRIBE shows the Events timeline: Scheduled, then 'Failed to pull image'.`n  The events tell the story. Read them top to bottom." `
        -Command "kubectl describe pod broken | Select-String -Pattern '(Status:|Events:|Normal|Warning|Failed|Back-off)' -Context 0,1" `
        -CommandBreakdown "kubectl describe pod    = RUNG 2 of the diagnostic ladder -- human-readable deep-dive`n  broken                  = Pod name`n  | Select-String ...     = PS filter to surface the high-signal lines only`n  -Pattern '(Status:|Events:|Normal|Warning|Failed|Back-off)' = regex of interesting fields`n  -Context 0,1            = include 1 line AFTER each match for readability" `
        -OutputFields "THE DIAGNOSTIC LADDER -- rung 2 of 4 (get > DESCRIBE > logs > events).`n  Status:       = current phase (Pending while waiting on image)`n  Containers:   = per-container State, LastState, Ready, Restart Count`n  State:        = what's happening NOW (Waiting: ImagePullBackOff)`n  LastState:    = what happened PREVIOUSLY (Terminated/Error with exit code + reason)`n  Conditions:   = PodScheduled / Initialized / ContainersReady / Ready booleans`n  Events:       = chronological timeline at the BOTTOM -- ALWAYS read this first`n    Warning 'Failed to pull image' = the smoking gun for this scenario"

    Write-TutorialSection `
        -Title "17/18  STEP 3: LOGS + STEP 4: CLUSTER EVENTS" `
        -Explanation "No logs -- the container never started (the image pull failed first).`n  That absence IS a clue: the problem is image-related, not app-related.`n  Cluster events confirm the timeline." `
        -Command "kubectl logs broken 2>&1; Write-Output '---'; kubectl get events --sort-by=.metadata.creationTimestamp --field-selector involvedObject.name=broken" `
        -CommandBreakdown "kubectl logs broken                 = RUNG 3 of the ladder -- container stdout/stderr`n  2>&1                                = merge stderr so the error message is captured`n  ---                                 = visual divider between rung 3 and rung 4`n  kubectl get events                  = RUNG 4 -- cluster-wide event stream`n  --sort-by=.metadata.creationTimestamp = oldest first, newest at the bottom (timeline)`n  --field-selector involvedObject.name=broken = only events about our Pod`n`n  Why sort? Events default to unsorted. Why age-off? Events have a TTL (default 1h) --`n  if a problem happened hours ago, the events may already be gone. Act fast." `
        -OutputFields "THE DIAGNOSTIC LADDER -- rungs 3 and 4 of 4.`n  LOGS output: 'Error from server (BadRequest): container broken is waiting to start'`n    -- absence of app logs MEANS the app never ran; narrows cause to image/scheduling`n  EVENTS columns:`n    TYPE    = Normal (informational) or Warning (something is wrong)`n    REASON  = short code: Scheduled, Pulling, Pulled, Failed, BackOff, Killing`n    AGE     = how long ago; events older than ~1h may be garbage-collected`n    MESSAGE = human-readable detail (e.g. 'Failed to pull image nginx:doesnotexist')"

    Write-TutorialSection `
        -Title "18/18  THE DIAGNOSTIC LADDER SUMMARY" `
        -Explanation "GET -> DESCRIBE -> LOGS -> EVENTS. Every time. This pattern solves`n  95% of Kubernetes troubleshooting. The status is your first clue, the`n  events tell the story, logs show what the app said, and cluster events`n  give the global timeline.`n`n  On the CKA, you'll be given broken pods and asked what's wrong.`n  Follow the ladder. Don't guess -- diagnose." `
        -Command "echo 'The diagnostic ladder: GET -> DESCRIBE -> LOGS -> EVENTS'" -NoRun `
        -CommandBreakdown "echo                  = print the summary string (no cluster interaction)`n  -NoRun on the helper  = skip execution; this slide is a flashcard, not a demo" `
        -OutputFields "MEMORIZE THIS LADDER for the CKA exam (30% troubleshooting weight):`n  1. GET       = fast status snapshot (STATUS, READY, RESTARTS columns)`n  2. DESCRIBE  = deep-dive; read EVENTS section first, then State/LastState`n  3. LOGS      = what the container itself said (use -p for previous container on crash)`n  4. EVENTS    = cluster-wide timeline; sort by creationTimestamp; age off after ~1h`n  Add --previous to logs after a crash. Add kubectl debug for advanced scenarios (Course 10)."

    Write-Output ""
    Write-Output "  Module 3 walkthrough complete."
    Write-Output "  You practiced: self-healing, services, namespaces, DNS,"
    Write-Output "  and the diagnostic ladder (GET -> DESCRIBE -> LOGS -> EVENTS)."
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
        Write-Output "  Done."
    }
}
