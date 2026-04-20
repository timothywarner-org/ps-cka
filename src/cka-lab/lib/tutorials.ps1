<#
.SYNOPSIS
    On-rails tutorial functions for CKA Course 1 modules.
    Sourced by kind-up.ps1 when tutorial mode is selected.
#>

# ---------------------------------------------------------------
# Helper: Run a command, show it, explain output, pause
# ---------------------------------------------------------------
function Write-TutorialSection {
    param(
        [string]$Title,
        [string]$Explanation,
        [string]$Command,
        [switch]$NoRun
    )
    Write-Output ""
    Write-Output "  ================================================================"
    Write-Output "  $Title"
    Write-Output "  ================================================================"
    Write-Output ""
    Write-Output ("  " + $Explanation)
    Write-Output ""
    Write-Output ("  Command:  " + $Command)
    Write-Output "  ----------------------------------------------------------------"
    if (-not $NoRun) {
        Write-Output ""
        Invoke-Expression $Command 2>&1 | ForEach-Object { Write-Output "  $_" }
    }
    Write-Output ""
    Read-Host "  Press Enter to continue"
}

function Write-TutorialBanner {
    param([string]$Title, [string[]]$Lines)
    Write-Output ""
    Write-Output "  +-----------------------------------------------------------------+"
    Write-Output "  |  $($Title.PadRight(62))|"
    Write-Output "  |                                                                 |"
    foreach ($line in $Lines) {
        Write-Output "  |  $($line.PadRight(62))|"
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
        -Command "kubectl cluster-info"

    Write-TutorialSection `
        -Title "2/12  NODES" `
        -Explanation "Your cluster has $nodeCount nodes. Control plane: ${ClusterName}-control-plane (and more if HA).`n  Workers: $workerNames -- these run your workloads.`n  STATUS=Ready means the kubelet on each node is healthy and reporting to the API server." `
        -Command "kubectl get nodes -o wide"

    Write-TutorialSection `
        -Title "3/12  NAMESPACES" `
        -Explanation "Namespaces partition cluster resources. You'll see:`n  - default:            where your pods go if you don't specify one`n  - kube-system:        control plane components`n  - kube-public:        cluster-wide readable resources`n  - kube-node-lease:    node heartbeat leases`n  - local-path-storage: KIND's storage provisioner" `
        -Command "kubectl get namespaces"

    Write-TutorialSection `
        -Title "4/12  CONTROL PLANE PODS (Static Pods)" `
        -Explanation "The 4 core control plane components run as static pods:`n  - kube-apiserver:          REST API front-end`n  - etcd:                    key-value store for all cluster state`n  - kube-scheduler:          assigns pods to nodes`n  - kube-controller-manager: runs reconciliation loops`n`n  They're 'static' because kubelet manages them from manifest files,`n  not through the API server. CKA tests this distinction." `
        -Command "kubectl get pods -n kube-system -l tier=control-plane -o wide"

    Write-TutorialSection `
        -Title "5/12  ETCD -- THE CLUSTER DATABASE" `
        -Explanation "etcd stores ALL cluster state. If etcd dies, the cluster is brain-dead.`n  CKA covers backup/restore: etcdctl snapshot save / restore.`n  Let's see how etcd is configured:" `
        -Command "kubectl get pod etcd-${ClusterName}-control-plane -n kube-system -o jsonpath='{.spec.containers[0].command}' | ForEach-Object { `$_ -replace ',',`"``n  `" }"

    Write-TutorialSection `
        -Title "6/12  NETWORKING -- KUBE-PROXY" `
        -Explanation "kube-proxy runs as a DaemonSet (one pod per node). It programs iptables`n  rules so that Service ClusterIPs route to the right pods.`n  You should see exactly $nodeCount pods -- one on each node:" `
        -Command "kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide"

    Write-TutorialSection `
        -Title "7/12  DNS -- COREDNS" `
        -Explanation "CoreDNS provides in-cluster DNS. When a pod calls 'my-service.default.svc.cluster.local',`n  CoreDNS resolves it to the Service's ClusterIP. Runs as a Deployment with 2 replicas." `
        -Command "kubectl get deploy,svc -n kube-system -l k8s-app=kube-dns"

    Write-TutorialSection `
        -Title "8/12  NODE INTERNALS -- KUBELET + CONTAINER RUNTIME" `
        -Explanation "Each node runs a kubelet and containerd (the CKA exam runtime).`n  CKA asks: 'which container runtime is this cluster using?'" `
        -Command "kubectl get nodes -o custom-columns='NAME:.metadata.name,KUBELET:.status.nodeInfo.kubeletVersion,RUNTIME:.status.nodeInfo.containerRuntimeVersion,INTERNAL-IP:.status.addresses[?(@.type==""InternalIP"")].address'"

    Write-TutorialSection `
        -Title "9/12  API RESOURCES" `
        -Explanation "The API server serves many resource types. SHORTNAMES save keystrokes:`n  po=pods, svc=services, deploy=deployments, cm=configmaps." `
        -Command "kubectl api-resources --verbs=list --namespaced=true -o wide | Select-Object -First 20"

    Write-TutorialSection `
        -Title "10/12  RBAC -- CLUSTER ROLES" `
        -Explanation "ClusterRoles define cluster-wide permissions. Key ones for CKA:`n  - cluster-admin: full access`n  - admin/edit/view: namespace-scoped progressive access" `
        -Command "kubectl get clusterroles | Select-String -Pattern '^(NAME|admin|edit|view|cluster-admin|system:node)'"

    Write-TutorialSection `
        -Title "11/12  STORAGE -- STORAGE CLASSES" `
        -Explanation "StorageClasses define how PersistentVolumes are provisioned.`n  KIND ships with 'standard' (local-path-provisioner) as the default." `
        -Command "kubectl get storageclass"

    Write-TutorialSection `
        -Title "12/12  ADMISSION CONTROLLERS" `
        -Explanation "Admission controllers intercept API requests after auth but before persistence.`n  Your cluster has NodeRestriction and PodSecurity enabled." `
        -Command "kubectl get pod kube-apiserver-${ClusterName}-control-plane -n kube-system -o jsonpath='{.spec.containers[0].command}' | ForEach-Object { `$_ -split ',' } | Select-String 'admission'"

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
        -Command "kubectl get nodes -o wide"

    Write-TutorialSection `
        -Title "2/10  WHAT KIND BUILT (Docker containers as nodes)" `
        -Explanation "KIND runs each Kubernetes node as a Docker container. These aren't VMs --`n  they're lightweight containers running a full kubelet. Let's see them:" `
        -Command "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

    Write-TutorialSection `
        -Title "3/10  KUBECONFIG CONTEXT" `
        -Explanation "KIND auto-configured your kubeconfig. The context 'kind-${ClusterName}'`n  points to the cluster's API server. On the CKA exam, you'll switch contexts`n  constantly -- always verify which cluster you're talking to." `
        -Command "kubectl config current-context"

    # --- Demo 2: System Pods ---
    Write-TutorialSection `
        -Title "4/10  CONTROL PLANE STATIC PODS" `
        -Explanation "These are the 4 core components, managed as static pods by kubelet:`n  apiserver, etcd, scheduler, controller-manager.`n  They have names like kube-apiserver-${ClusterName}-control-plane.`n  Static pods live in /etc/kubernetes/manifests/ on the node." `
        -Command "kubectl get pods -n kube-system -o wide"

    Write-TutorialSection `
        -Title "5/10  KUBE-PROXY DAEMONSET" `
        -Explanation "kube-proxy runs one pod per node (that's what a DaemonSet does).`n  It programs iptables/IPVS rules so Services can route traffic." `
        -Command "kubectl get pods -n kube-system -l k8s-app=kube-proxy -o wide"

    # --- Demo 3: DNS ---
    Write-TutorialSection `
        -Title "6/10  COREDNS SERVICE" `
        -Explanation "CoreDNS is the cluster's DNS server. Every pod's /etc/resolv.conf`n  points to the kube-dns Service IP (typically 10.96.0.10).`n  Let's see the Service and Deployment:" `
        -Command "kubectl -n kube-system get svc kube-dns"

    Write-TutorialSection `
        -Title "7/10  COREDNS DEPLOYMENT" `
        -Explanation "CoreDNS runs as a Deployment with 2 replicas for redundancy.`n  The Deployment ensures DNS stays available even if a pod dies." `
        -Command "kubectl -n kube-system get deploy coredns"

    Write-TutorialSection `
        -Title "8/10  DNS HEALTH CHECK" `
        -Explanation "Let's test DNS end-to-end. We'll spin up a temporary busybox pod`n  and resolve 'kubernetes.default' -- the API server's internal Service.`n  If this resolves, your cluster's DNS is healthy." `
        -Command "kubectl run dns-test --image=busybox:1.36 --rm --restart=Never --attach -- nslookup kubernetes.default"

    # --- Demo 4: Cluster Info ---
    Write-TutorialSection `
        -Title "9/10  CLUSTER INFO" `
        -Explanation "Quick summary of your cluster endpoints. On the exam, if connectivity`n  is broken, this is your first command." `
        -Command "kubectl cluster-info"

    Write-TutorialSection `
        -Title "10/10  API RESOURCES" `
        -Explanation "Every resource type the API server knows about. The SHORTNAMES column`n  is gold -- 'po' for pods, 'svc' for services, 'deploy' for deployments.`n  Memorize the ones you use most; they save real time on the exam." `
        -Command "kubectl api-resources | Select-Object -First 20"

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
        -Command "kubectl run nginx --image=nginx"

    Write-TutorialSection `
        -Title "2/16  IMPERATIVE: CREATE A DEPLOYMENT" `
        -Explanation "Deployments manage rollouts. Three things just happened:`n  a Deployment, a ReplicaSet, and 3 Pods. All from one command." `
        -Command "kubectl create deployment web --image=nginx --replicas=3"

    Write-TutorialSection `
        -Title "3/16  IMPERATIVE: EXPOSE AS A SERVICE" `
        -Explanation "Services give Pods a stable network endpoint. DNS is auto-created:`n  web.default.svc.cluster.local now resolves to the ClusterIP." `
        -Command "kubectl expose deployment web --port=80 --type=ClusterIP"

    Write-TutorialSection `
        -Title "4/16  IMPERATIVE: CONFIGMAP + SECRET + RBAC" `
        -Explanation "Three more resources in three commands. That's 7 resources total`n  with zero YAML files. Speed wins on the exam." `
        -Command "kubectl create configmap app-config --from-literal=env=prod; kubectl create secret generic db-pass --from-literal=password=s3cret; kubectl create role pod-reader --verb=get,list,watch --resource=pods; kubectl create rolebinding pod-reader-binding --role=pod-reader --user=jane"

    Write-TutorialSection `
        -Title "5/16  SEE EVERYTHING" `
        -Explanation "Let's see the full picture -- Pods, Services, Deployments, ReplicaSets." `
        -Command "kubectl get all"

    # --- Demo 2: Dry-Run YAML Pipeline ---
    Write-TutorialSection `
        -Title "6/16  DRY-RUN: GENERATE YAML WITHOUT CREATING" `
        -Explanation "--dry-run=client validates and generates a manifest WITHOUT persisting.`n  This is the professional way: generate, edit, apply. GitOps-ready." `
        -Command "kubectl run temp --image=busybox --restart=Never --dry-run=client -o yaml"

    Write-TutorialSection `
        -Title "7/16  DRY-RUN: DEPLOYMENT YAML" `
        -Explanation "Works for any resource type. Notice the nested structure:`n  spec.replicas, spec.selector.matchLabels, spec.template.spec.containers." `
        -Command "kubectl create deployment limited --image=nginx --replicas=2 --dry-run=client -o yaml | Select-Object -First 25"

    # --- Demo 3: kubectl explain ---
    Write-TutorialSection `
        -Title "8/16  EXPLAIN: POD CONTAINER SPEC" `
        -Explanation "kubectl explain is your in-terminal API reference. You don't need to`n  memorize field names -- just ask Kubernetes what's available." `
        -Command "kubectl explain pod.spec.containers.resources"

    Write-TutorialSection `
        -Title "9/16  EXPLAIN: DEPLOYMENT STRATEGY (RECURSIVE)" `
        -Explanation "--recursive shows the entire tree. This is gold for complex resources`n  like Deployment rollout strategies (RollingUpdate, maxSurge, maxUnavailable)." `
        -Command "kubectl explain deployment.spec.strategy --recursive"

    Write-TutorialSection `
        -Title "10/16  API RESOURCES: SHORTNAMES" `
        -Explanation "Can't remember if it's 'svc' or 'service'? This is the source of truth.`n  Shortnames save real time: po, svc, deploy, cm, ns, sa, pv, pvc." `
        -Command "kubectl api-resources | Select-String -Pattern '(^NAME|\bpods?\b|\bservices?\b|\bdeploy\w*|\bconfigmap\w*|\bsecrets?\b|\broles?\b|\brolebindings?\b)' | Select-Object -First 10"

    # --- Demo 4: Querying ---
    Write-TutorialSection `
        -Title "11/16  QUERY: LABEL SELECTOR" `
        -Explanation "Labels are how Kubernetes organizes resources. This returns only`n  Pods with the label app=web -- filtering out everything else." `
        -Command "kubectl get pods -l app=web"

    Write-TutorialSection `
        -Title "12/16  QUERY: FIELD SELECTOR" `
        -Explanation "Field selectors filter by built-in fields (not labels).`n  status.phase=Running shows only active pods, hiding Pending or Failed." `
        -Command "kubectl get pods --field-selector status.phase=Running"

    Write-TutorialSection `
        -Title "13/16  QUERY: JSONPATH EXTRACTION" `
        -Explanation "JSONPath pulls out exactly the data you need for scripting.`n  No wasted columns -- just pod names, ready for piping to xargs." `
        -Command "kubectl get pods -o jsonpath='{.items[*].metadata.name}'"

    Write-TutorialSection `
        -Title "14/16  QUERY: CUSTOM COLUMNS" `
        -Explanation "Custom columns let you see Pod name, which Node it's on, and status`n  in one clean view. Super useful for debugging scheduling issues." `
        -Command "kubectl get pods -o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase"

    Write-TutorialSection `
        -Title "15/16  QUERY: SORTED EVENTS" `
        -Explanation "Events are notifications -- Pod created, image pulled, container restarted.`n  Sorting by timestamp shows WHEN things happened. Debugging gold." `
        -Command "kubectl get events --sort-by=.metadata.creationTimestamp | Select-Object -Last 10"

    # --- Demo 5: Context Switching ---
    Write-TutorialSection `
        -Title "16/16  CONTEXT: VERIFY CURRENT CONTEXT" `
        -Explanation "The CKA exam has 17 questions across 4 clusters. One wrong context`n  = zero points. Always verify before ANY destructive command.`n  The asterisk (*) marks your current context." `
        -Command "kubectl config get-contexts"

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
        -Command "kubectl run standalone --image=nginx --restart=Never"

    Write-TutorialSection `
        -Title "2/18  CREATE A MANAGED DEPLOYMENT" `
        -Explanation "A Deployment owns a ReplicaSet, which owns the Pods.`n  This chain enables self-healing: desired=2, so the controller`n  will always maintain 2 running Pods." `
        -Command "kubectl create deployment managed --image=nginx --replicas=2"

    Write-TutorialSection `
        -Title "3/18  SEE BOTH SIDE BY SIDE" `
        -Explanation "Notice the standalone pod and the two managed pods.`n  The managed pods have a hash suffix -- that's the ReplicaSet's fingerprint." `
        -Command "kubectl get pods -o wide"

    Write-TutorialSection `
        -Title "4/18  DELETE THE BARE POD" `
        -Explanation "Gone forever. No controller, no comeback. This is why you almost never`n  use bare pods in production -- they're fire-and-forget." `
        -Command "kubectl delete pod standalone --grace-period=1; Start-Sleep 3; kubectl get pods"

    Write-TutorialSection `
        -Title "5/18  SELF-HEALING: DELETE A MANAGED POD" `
        -Explanation "Watch the magic. We'll delete one managed pod and the ReplicaSet will`n  immediately create a replacement. The name changes but the count stays at 2.`n  This IS the reconciliation loop." `
        -Command "`$pod = (kubectl get pods -l app=managed -o jsonpath='{.items[0].metadata.name}'); kubectl delete pod `$pod --grace-period=1; Start-Sleep 5; kubectl get pods -l app=managed"

    Write-TutorialSection `
        -Title "6/18  THE REPLICASET" `
        -Explanation "The ReplicaSet is the controller that owns these pods.`n  Desired=2, Current=2, Ready=2. The reconciliation loop is satisfied." `
        -Command "kubectl get replicasets"

    # ==========================================================
    # Demo 2: Services & the Selector-Label Contract
    # ==========================================================
    Write-TutorialSection `
        -Title "7/18  CREATE A CLUSTERIP SERVICE" `
        -Explanation "Services are Kubernetes' internal load balancer. This Service targets`n  pods with the label app=managed and gives them a stable ClusterIP." `
        -Command "kubectl expose deployment managed --port=80 --type=ClusterIP --name=managed-svc"

    Write-TutorialSection `
        -Title "8/18  ENDPOINTS: THE SELECTOR-LABEL CONTRACT" `
        -Explanation "Endpoints are the glue. The Service selector finds pods with app=managed`n  and populates this list with their IPs. When a pod disappears, its IP is removed.`n  When a new pod appears with the right label, its IP is added. Real-time." `
        -Command "kubectl get endpoints managed-svc"

    Write-TutorialSection `
        -Title "9/18  SCALE UP AND WATCH ENDPOINTS GROW" `
        -Explanation "Scaling to 4 replicas creates 2 new pods. The Service controller`n  watches them appear and auto-adds their IPs to Endpoints." `
        -Command "kubectl scale deployment managed --replicas=4; Start-Sleep 8; kubectl get endpoints managed-svc"

    Write-TutorialSection `
        -Title "10/18  TEST THE SERVICE FROM INSIDE THE CLUSTER" `
        -Explanation "ClusterIPs are NOT routable from your laptop -- you must test from inside.`n  We'll spin up a debug pod and wget the Service name. If you see the nginx`n  welcome page, the Service is working." `
        -Command "kubectl run debug --image=busybox:1.36 --rm --restart=Never --attach -- wget -qO- managed-svc | Select-Object -First 5"

    # ==========================================================
    # Demo 3: Namespaces & Labels
    # ==========================================================
    Write-TutorialSection `
        -Title "11/18  CREATE A NAMESPACE" `
        -Explanation "Namespaces partition cluster resources. Resources in one namespace`n  are invisible from another by default. Let's create 'staging'." `
        -Command "kubectl create namespace staging"

    Write-TutorialSection `
        -Title "12/18  DEPLOY INTO THE NAMESPACE" `
        -Explanation "Use -n staging to target the namespace. These pods won't show up in`n  'kubectl get pods' (which defaults to the 'default' namespace)." `
        -Command "kubectl -n staging create deployment catalog --image=nginx --replicas=2; Start-Sleep 5; kubectl get pods -A | Select-String -Pattern '(NAMESPACE|default|staging)'"

    # ==========================================================
    # Demo 4: DNS
    # ==========================================================
    Write-TutorialSection `
        -Title "13/18  DNS: SHORT NAME RESOLUTION" `
        -Explanation "Pods can reach Services by name within the same namespace.`n  'managed-svc' resolves to the ClusterIP because both are in 'default'." `
        -Command "kubectl run dns-short --image=busybox:1.36 --rm --restart=Never --attach -- nslookup managed-svc"

    Write-TutorialSection `
        -Title "14/18  DNS: FQDN FOR CROSS-NAMESPACE" `
        -Explanation "The Fully Qualified Domain Name works from ANY namespace:`n  <service>.<namespace>.svc.cluster.local`n  Use this when crossing namespace boundaries." `
        -Command "kubectl run dns-fqdn --image=busybox:1.36 --rm --restart=Never --attach -- nslookup managed-svc.default.svc.cluster.local"

    # ==========================================================
    # Demo 5: The Diagnostic Ladder
    # ==========================================================
    Write-TutorialSection `
        -Title "15/18  DIAGNOSTIC LADDER: CREATE A BROKEN POD" `
        -Explanation "This pod uses an image tag that doesn't exist: nginx:doesnotexist.`n  The container runtime will fail to pull it. Let's watch the diagnostic`n  ladder solve it." `
        -Command "kubectl run broken --image=nginx:doesnotexist --restart=Never; Start-Sleep 8; kubectl get pods broken"

    Write-TutorialSection `
        -Title "16/18  STEP 1: GET (status clue) + STEP 2: DESCRIBE (events)" `
        -Explanation "GET shows ImagePullBackOff -- the image couldn't be pulled.`n  DESCRIBE shows the Events timeline: Scheduled, then 'Failed to pull image'.`n  The events tell the story. Read them top to bottom." `
        -Command "kubectl describe pod broken | Select-String -Pattern '(Status:|Events:|Normal|Warning|Failed|Back-off)' -Context 0,1"

    Write-TutorialSection `
        -Title "17/18  STEP 3: LOGS + STEP 4: CLUSTER EVENTS" `
        -Explanation "No logs -- the container never started (the image pull failed first).`n  That absence IS a clue: the problem is image-related, not app-related.`n  Cluster events confirm the timeline." `
        -Command "kubectl logs broken 2>&1; Write-Output '---'; kubectl get events --sort-by=.metadata.creationTimestamp --field-selector involvedObject.name=broken"

    Write-TutorialSection `
        -Title "18/18  THE DIAGNOSTIC LADDER SUMMARY" `
        -Explanation "GET -> DESCRIBE -> LOGS -> EVENTS. Every time. This pattern solves`n  95% of Kubernetes troubleshooting. The status is your first clue, the`n  events tell the story, logs show what the app said, and cluster events`n  give the global timeline.`n`n  On the CKA, you'll be given broken pods and asked what's wrong.`n  Follow the ladder. Don't guess -- diagnose." `
        -Command "echo 'The diagnostic ladder: GET -> DESCRIBE -> LOGS -> EVENTS'" -NoRun

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
