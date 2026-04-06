# CKA Command Guide

Comprehensive reference for every command tested on the Certified Kubernetes Administrator (CKA) v1.35 exam. Organized by CKA exam domain. All commands are verified against Kubernetes v1.35.

**Exam environment pre-configured tools:** `k` alias for kubectl, bash autocompletion, `yq`, `curl`, `wget`, `man`.

**Allowed documentation during the exam:** kubernetes.io/docs, kubernetes.io/blog, helm.sh/docs, gateway-api.sigs.k8s.io.

---

## Table of contents

1. [Essential kubectl operations](#essential-kubectl-operations)
2. [Cluster Architecture, Installation and Configuration (25%)](#cluster-architecture-installation-and-configuration-25)
3. [Workloads and Scheduling (15%)](#workloads-and-scheduling-15)
4. [Services and Networking (20%)](#services-and-networking-20)
5. [Storage (10%)](#storage-10)
6. [Troubleshooting (30%)](#troubleshooting-30)
7. [Helm commands](#helm-commands)
8. [Kustomize commands](#kustomize-commands)
9. [Resource shortnames](#resource-shortnames)
10. [Output formatting](#output-formatting)
11. [Exam speed techniques](#exam-speed-techniques)

---

## Essential kubectl operations

These commands are used across every CKA domain. Master them first.

### Context and configuration

Every exam task starts with a context switch. Forgetting this is the most common silent error.

```bash
# Switch to a specific cluster context (REQUIRED at the start of every task)
kubectl config use-context <cluster-name>

# View current context
kubectl config current-context

# List all available contexts
kubectl config get-contexts

# Set default namespace for current context
kubectl config set-context --current --namespace=<namespace>

# View merged kubeconfig
kubectl config view
```

### Viewing resources

```bash
# List resources in the current namespace
kubectl get pods
kubectl get deployments
kubectl get services
kubectl get nodes

# List resources across all namespaces
kubectl get pods -A
kubectl get pods --all-namespaces

# Get detailed output with additional columns
kubectl get pods -o wide

# Get resource as YAML (useful for editing or copying)
kubectl get pod <pod-name> -o yaml
kubectl get pod <pod-name> -o yaml > pod.yaml

# Get resource as JSON
kubectl get pod <pod-name> -o json

# List resources with label selectors
kubectl get pods -l app=nginx
kubectl get pods --selector=app=nginx,tier=frontend

# List resources with field selectors
kubectl get pods --field-selector=status.phase=Running

# Sort output
kubectl get pods --sort-by='.metadata.creationTimestamp'
kubectl get pods --sort-by='.status.containerStatuses[0].restartCount'
kubectl get pv --sort-by=.spec.capacity.storage

# Show labels
kubectl get pods --show-labels
```

### Describing resources

The `describe` command provides detailed information including events, which is critical for troubleshooting.

```bash
# Describe a specific resource
kubectl describe pod <pod-name>
kubectl describe node <node-name>
kubectl describe deployment <deployment-name>
kubectl describe service <service-name>

# Describe with namespace
kubectl describe pod <pod-name> -n <namespace>
```

### Creating resources imperatively

Imperative commands are faster than writing YAML on the exam. Use them whenever possible.

```bash
# Create a Pod
kubectl run <pod-name> --image=<image> --restart=Never
kubectl run nginx --image=nginx:1.25 --port=80

# Create a Pod with labels
kubectl run nginx --image=nginx --labels="app=web,tier=frontend"

# Create a Pod with a command
kubectl run busybox --image=busybox:1.28 --restart=Never -- sleep 3600
kubectl run busybox --image=busybox:1.28 --restart=Never -- /bin/sh -c "echo hello"

# Create a Pod with environment variables
kubectl run nginx --image=nginx --env="DB_HOST=mysql" --env="DB_PORT=3306"

# Create a Pod with resource requests and limits
kubectl run nginx --image=nginx --requests='cpu=100m,memory=128Mi' --limits='cpu=200m,memory=256Mi'

# Create a Deployment
kubectl create deployment <name> --image=<image> --replicas=<count>
kubectl create deployment web --image=nginx:1.25 --replicas=3

# Create a Namespace
kubectl create namespace <name>
kubectl create ns production

# Create a ConfigMap
kubectl create configmap <name> --from-literal=<key>=<value>
kubectl create configmap app-config --from-literal=DB_HOST=mysql --from-literal=DB_PORT=3306
kubectl create configmap app-config --from-file=config.properties
kubectl create configmap app-config --from-file=<directory>
kubectl create configmap app-config --from-env-file=.env

# Create a Secret
kubectl create secret generic <name> --from-literal=<key>=<value>
kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password=secret
kubectl create secret generic tls-secret --from-file=tls.crt=cert.pem --from-file=tls.key=key.pem
kubectl create secret tls <name> --cert=<cert-file> --key=<key-file>
kubectl create secret docker-registry <name> --docker-server=<server> --docker-username=<user> --docker-password=<pass>

# Create a Service
kubectl expose pod <pod-name> --port=<port> --target-port=<target-port> --type=<type>
kubectl expose deployment <name> --port=80 --target-port=8080 --type=ClusterIP
kubectl expose deployment <name> --port=80 --type=NodePort
kubectl expose deployment <name> --port=80 --type=LoadBalancer

# Create a Service imperatively by type
kubectl create service clusterip <name> --tcp=<port>:<target-port>
kubectl create service nodeport <name> --tcp=<port>:<target-port>
kubectl create service loadbalancer <name> --tcp=<port>:<target-port>

# Create a Job
kubectl create job <name> --image=<image> -- <command>
kubectl create job backup --image=busybox:1.28 -- /bin/sh -c "echo backup complete"

# Create a CronJob
kubectl create cronjob <name> --image=<image> --schedule="<cron-expression>" -- <command>
kubectl create cronjob cleanup --image=busybox:1.28 --schedule="0 */6 * * *" -- /bin/sh -c "echo cleanup"

# Create an Ingress
kubectl create ingress <name> --rule="<host>/<path>=<service>:<port>"
kubectl create ingress web-ingress --rule="app.example.com/=web-svc:80"

# Create a ServiceAccount
kubectl create serviceaccount <name>
kubectl create sa monitoring-sa -n monitoring

# Create a PodDisruptionBudget
kubectl create poddisruptionbudget <name> --selector=<label-selector> --min-available=<count>
kubectl create pdb web-pdb --selector=app=web --min-available=2

# Create a PriorityClass
kubectl create priorityclass <name> --value=<priority-value>
```

### Generating YAML from imperative commands

The `--dry-run=client -o yaml` pipeline is the fastest way to generate YAML manifests on the exam.

```bash
# Generate Pod YAML
kubectl run nginx --image=nginx:1.25 --port=80 --dry-run=client -o yaml > pod.yaml

# Generate Deployment YAML
kubectl create deployment web --image=nginx:1.25 --replicas=3 --dry-run=client -o yaml > deployment.yaml

# Generate Service YAML
kubectl expose deployment web --port=80 --target-port=8080 --type=ClusterIP --dry-run=client -o yaml > service.yaml

# Generate Job YAML
kubectl create job backup --image=busybox:1.28 --dry-run=client -o yaml -- echo "done" > job.yaml

# Generate CronJob YAML
kubectl create cronjob cleanup --image=busybox:1.28 --schedule="*/5 * * * *" --dry-run=client -o yaml -- echo "done" > cronjob.yaml

# Generate RBAC YAML
kubectl create role pod-reader --verb=get,list,watch --resource=pods --dry-run=client -o yaml > role.yaml
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=default:mysa --dry-run=client -o yaml > rolebinding.yaml
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes --dry-run=client -o yaml > clusterrole.yaml
kubectl create clusterrolebinding node-reader-binding --clusterrole=node-reader --serviceaccount=default:mysa --dry-run=client -o yaml > clusterrolebinding.yaml
```

### Modifying resources

```bash
# Edit a resource in-place (opens in vi/vim)
kubectl edit deployment <name>
kubectl edit deployment <name> -n <namespace>

# Apply changes from a file
kubectl apply -f <file.yaml>
kubectl apply -f <directory>/

# Replace a resource entirely
kubectl replace -f <file.yaml>
kubectl replace --force -f <file.yaml>

# Patch a resource (JSON merge patch)
kubectl patch deployment <name> -p '{"spec":{"replicas":5}}'
kubectl patch pod <name> -p '{"spec":{"containers":[{"name":"web","image":"nginx:1.26"}]}}'

# Set image on a Deployment
kubectl set image deployment/<name> <container>=<image>
kubectl set image deployment/web nginx=nginx:1.26

# Set environment variable on a Deployment
kubectl set env deployment/<name> <KEY>=<VALUE>
kubectl set env deployment/web DB_HOST=mysql

# Set service account on a Deployment
kubectl set serviceaccount deployment/<name> <service-account-name>

# Set resources on a Deployment
kubectl set resources deployment/<name> --requests='cpu=100m,memory=128Mi' --limits='cpu=200m,memory=256Mi'

# Add or update labels
kubectl label pod <name> <key>=<value>
kubectl label pod <name> <key>=<value> --overwrite
kubectl label nodes <node-name> disktype=ssd

# Remove a label
kubectl label pod <name> <key>-

# Add or update annotations
kubectl annotate pod <name> <key>=<value>

# Remove an annotation
kubectl annotate pod <name> <key>-
```

### Deleting resources

```bash
# Delete a resource by name
kubectl delete pod <name>
kubectl delete deployment <name> -n <namespace>

# Delete by file
kubectl delete -f <file.yaml>

# Delete by label selector
kubectl delete pods -l app=nginx

# Delete all resources of a type in a namespace
kubectl delete pods --all -n <namespace>
kubectl delete all --all -n <namespace>

# Force delete a stuck Pod
kubectl delete pod <name> --grace-period=0 --force
```

### Explaining resources

The `explain` command is invaluable during the exam for looking up YAML field names and nesting.

```bash
# Get documentation for a resource kind
kubectl explain pod
kubectl explain deployment
kubectl explain service

# Get documentation for a specific field
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy
kubectl explain pod.spec.volumes

# Recursive explain (show all nested fields)
kubectl explain pod.spec --recursive
kubectl explain deployment.spec.template.spec.containers --recursive
```

---

## Cluster Architecture, Installation and Configuration (25%)

### RBAC (Role-Based Access Control)

```bash
# Create a Role (namespace-scoped)
kubectl create role <name> --verb=<verbs> --resource=<resources> -n <namespace>
kubectl create role pod-reader --verb=get,list,watch --resource=pods -n production
kubectl create role pod-admin --verb=get,list,watch,create,update,delete --resource=pods,pods/log -n production

# Create a ClusterRole (cluster-scoped)
kubectl create clusterrole <name> --verb=<verbs> --resource=<resources>
kubectl create clusterrole node-reader --verb=get,list,watch --resource=nodes
kubectl create clusterrole secret-admin --verb=get,list,watch,create,update,delete --resource=secrets

# Create a RoleBinding (bind Role or ClusterRole to a user/group/SA in a namespace)
kubectl create rolebinding <name> --role=<role-name> --user=<username> -n <namespace>
kubectl create rolebinding <name> --role=<role-name> --serviceaccount=<namespace>:<sa-name> -n <namespace>
kubectl create rolebinding <name> --clusterrole=<clusterrole-name> --user=<username> -n <namespace>

# Create a ClusterRoleBinding (cluster-wide binding)
kubectl create clusterrolebinding <name> --clusterrole=<clusterrole-name> --user=<username>
kubectl create clusterrolebinding <name> --clusterrole=<clusterrole-name> --serviceaccount=<namespace>:<sa-name>

# Check authorization (can-i)
kubectl auth can-i <verb> <resource>
kubectl auth can-i create pods
kubectl auth can-i get pods --as=system:serviceaccount:default:mysa
kubectl auth can-i list secrets --as=jane --namespace=production
kubectl auth can-i '*' '*'

# List all RBAC resources
kubectl get roles -A
kubectl get clusterroles
kubectl get rolebindings -A
kubectl get clusterrolebindings

# Create a ServiceAccount
kubectl create serviceaccount <name> -n <namespace>

# Create a token for a ServiceAccount
kubectl create token <sa-name> -n <namespace>
```

### kubeadm cluster management

```bash
# Initialize a control plane node
sudo kubeadm init --pod-network-cidr=<cidr> --apiserver-advertise-address=<ip>
sudo kubeadm init --config=kubeadm-config.yaml

# Generate a join command for worker nodes
kubeadm token create --print-join-command

# Join a worker node to the cluster
sudo kubeadm join <control-plane-host>:<port> --token <token> --discovery-token-ca-cert-hash sha256:<hash>

# Join a control plane node (for HA)
sudo kubeadm join <control-plane-host>:<port> --token <token> --discovery-token-ca-cert-hash sha256:<hash> --control-plane

# Upgrade a cluster (control plane)
# Step 1: Check available versions
sudo apt-cache madison kubeadm

# Step 2: Upgrade kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=<version>

# Step 3: Verify the upgrade plan
sudo kubeadm upgrade plan

# Step 4: Apply the upgrade
sudo kubeadm upgrade apply v<version>

# Step 5: Upgrade kubelet and kubectl
sudo apt-get install -y kubelet=<version> kubectl=<version>
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Upgrade a worker node
# Step 1: Drain the node (run from control plane)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Step 2: Upgrade kubeadm on the worker
sudo apt-get update && sudo apt-get install -y kubeadm=<version>

# Step 3: Upgrade the node configuration
sudo kubeadm upgrade node

# Step 4: Upgrade kubelet and kubectl
sudo apt-get install -y kubelet=<version> kubectl=<version>
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Step 5: Uncordon the node (run from control plane)
kubectl uncordon <node-name>

# Token management
kubeadm token list
kubeadm token create
kubeadm token create --print-join-command
kubeadm token delete <token>

# Certificate management
kubeadm certs check-expiration
kubeadm certs renew all

# Reset a node (remove from cluster)
sudo kubeadm reset
```

### etcd backup and restore

etcd backup and restore appears on virtually every CKA exam. Know these commands by heart.

```bash
# Backup etcd (snapshot save)
ETCDCTL_API=3 etcdctl snapshot save <backup-file> \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Example with explicit path
ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify a snapshot
ETCDCTL_API=3 etcdctl snapshot status <backup-file> --write-table

# Restore etcd from backup (uses etcdutl in v1.35)
etcdutl snapshot restore <backup-file> --data-dir=<new-data-dir>
etcdutl snapshot restore /opt/etcd-backup.db --data-dir=/var/lib/etcd-restored

# After restore: update the etcd Pod manifest to use the new data directory
# Edit /etc/kubernetes/manifests/etcd.yaml:
#   - Change --data-dir flag to the new directory
#   - Update the hostPath volume to point to the new directory

# Check etcd cluster health
ETCDCTL_API=3 etcdctl endpoint health \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# List etcd members
ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Node management

```bash
# Cordon a node (mark as unschedulable)
kubectl cordon <node-name>

# Uncordon a node (mark as schedulable)
kubectl uncordon <node-name>

# Drain a node (evict all workloads for maintenance)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --force

# Add a taint to a node
kubectl taint nodes <node-name> <key>=<value>:<effect>
kubectl taint nodes node1 dedicated=gpu:NoSchedule

# Remove a taint from a node
kubectl taint nodes <node-name> <key>=<value>:<effect>-
kubectl taint nodes node1 dedicated=gpu:NoSchedule-

# Label a node
kubectl label nodes <node-name> <key>=<value>
kubectl label nodes node1 disktype=ssd

# Remove a node label
kubectl label nodes <node-name> <key>-
```

### CRDs and operators

```bash
# List Custom Resource Definitions
kubectl get crd
kubectl get customresourcedefinitions

# Describe a CRD
kubectl describe crd <crd-name>

# Get custom resources defined by a CRD
kubectl get <custom-resource-plural>
kubectl get <custom-resource-plural>.<group>

# Explain a CRD (view its schema)
kubectl explain <custom-resource-plural>

# Apply a CRD definition
kubectl apply -f crd-definition.yaml

# Delete a CRD (also deletes all custom resources of that type)
kubectl delete crd <crd-name>
```

### Extension interfaces (CNI, CSI, CRI)

```bash
# Check which CNI plugin is installed
ls /etc/cni/net.d/
cat /etc/cni/net.d/*.conflist

# Check the container runtime (CRI)
kubectl get nodes -o wide    # CONTAINER-RUNTIME column

# Check the container runtime endpoint
crictl info

# List CSI drivers installed
kubectl get csidrivers

# List CSI nodes
kubectl get csinodes
```

---

## Workloads and Scheduling (15%)

### Deployments

```bash
# Create a Deployment
kubectl create deployment web --image=nginx:1.25 --replicas=3

# Scale a Deployment
kubectl scale deployment <name> --replicas=<count>
kubectl scale deployment web --replicas=5

# Update the image (rolling update)
kubectl set image deployment/<name> <container>=<new-image>
kubectl set image deployment/web nginx=nginx:1.26

# Check rollout status
kubectl rollout status deployment/<name>

# View rollout history
kubectl rollout history deployment/<name>
kubectl rollout history deployment/<name> --revision=<number>

# Rollback to previous revision
kubectl rollout undo deployment/<name>

# Rollback to a specific revision
kubectl rollout undo deployment/<name> --to-revision=<number>

# Restart a Deployment (rolling restart of all Pods)
kubectl rollout restart deployment/<name>

# Pause a rollout
kubectl rollout pause deployment/<name>

# Resume a paused rollout
kubectl rollout resume deployment/<name>
```

### Autoscaling (HPA and VPA)

New in the February 2025 curriculum.

```bash
# Create a Horizontal Pod Autoscaler
kubectl autoscale deployment <name> --min=<min> --max=<max> --cpu-percent=<target>
kubectl autoscale deployment web --min=2 --max=10 --cpu-percent=80

# Get HPA status
kubectl get hpa
kubectl describe hpa <name>

# Delete an HPA
kubectl delete hpa <name>

# Apply HPA from YAML (for custom metrics or memory-based scaling)
kubectl apply -f hpa.yaml
```

**HPA YAML example (autoscaling/v2):**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

### ConfigMaps and Secrets

```bash
# Create ConfigMap from literals
kubectl create configmap <name> --from-literal=<key>=<value>

# Create ConfigMap from file
kubectl create configmap <name> --from-file=<filename>
kubectl create configmap <name> --from-file=<key>=<filename>

# Create ConfigMap from env file
kubectl create configmap <name> --from-env-file=<filename>

# Create Secret from literals
kubectl create secret generic <name> --from-literal=<key>=<value>

# Create Secret from file
kubectl create secret generic <name> --from-file=<filename>

# View ConfigMap data
kubectl get configmap <name> -o yaml
kubectl describe configmap <name>

# Decode a Secret value
kubectl get secret <name> -o jsonpath='{.data.<key>}' | base64 -d
```

### Pod scheduling and admission

```bash
# Add a taint to a node
kubectl taint nodes <node-name> <key>=<value>:<effect>
# Effects: NoSchedule, PreferNoSchedule, NoExecute

# Remove a taint
kubectl taint nodes <node-name> <key>=<value>:<effect>-

# Label a node (for nodeSelector and node affinity)
kubectl label nodes <node-name> <key>=<value>
```

**Pod with nodeSelector:**

```yaml
spec:
  nodeSelector:
    disktype: ssd
```

**Pod with node affinity:**

```yaml
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: disktype
            operator: In
            values:
            - ssd
```

**Pod with tolerations:**

```yaml
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "gpu"
    effect: "NoSchedule"
```

### Native sidecar containers

New in the February 2025 curriculum. Init containers with `restartPolicy: Always` run alongside the main container.

```yaml
spec:
  initContainers:
  - name: log-shipper
    image: fluent/fluent-bit:latest
    restartPolicy: Always
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  containers:
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
  volumes:
  - name: logs
    emptyDir: {}
```

---

## Services and Networking (20%)

### Services

```bash
# Expose a Deployment as a ClusterIP Service
kubectl expose deployment <name> --port=80 --target-port=8080 --type=ClusterIP

# Expose as NodePort
kubectl expose deployment <name> --port=80 --target-port=8080 --type=NodePort

# Expose as LoadBalancer
kubectl expose deployment <name> --port=80 --target-port=8080 --type=LoadBalancer

# Create a Service imperatively
kubectl create service clusterip <name> --tcp=80:8080
kubectl create service nodeport <name> --tcp=80:8080

# Get endpoints for a Service
kubectl get endpoints <service-name>
kubectl get endpointslices -l kubernetes.io/service-name=<service-name>

# Test Service connectivity from within the cluster
kubectl run test --image=busybox:1.28 --restart=Never --rm -it -- wget -qO- http://<service-name>.<namespace>.svc.cluster.local
kubectl run test --image=busybox:1.28 --restart=Never --rm -it -- nslookup <service-name>.<namespace>.svc.cluster.local
```

### NetworkPolicies

NetworkPolicies control traffic flow between Pods. They are heavily tested on the CKA exam.

```bash
# Apply a NetworkPolicy from YAML
kubectl apply -f networkpolicy.yaml

# List NetworkPolicies
kubectl get networkpolicies -n <namespace>
kubectl get netpol -n <namespace>

# Describe a NetworkPolicy
kubectl describe networkpolicy <name> -n <namespace>
```

**Deny all ingress traffic to a namespace:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

**Allow ingress from specific Pods:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 8080
```

**Allow egress to specific CIDR and DNS:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8
    ports:
    - protocol: TCP
      port: 3306
  - to:
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
```

### Gateway API

New in the February 2025 curriculum. Gateway API replaces legacy Ingress with a role-oriented model: GatewayClass > Gateway > HTTPRoute.

```bash
# List Gateway API resources
kubectl get gatewayclasses
kubectl get gateways -A
kubectl get httproutes -A

# Describe Gateway resources
kubectl describe gateway <name> -n <namespace>
kubectl describe httproute <name> -n <namespace>
```

**GatewayClass (defines which controller manages gateways):**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: example-class
spec:
  controllerName: example.com/gateway-controller
```

**Gateway (defines a load balancer that listens for traffic):**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: example-gateway
  namespace: production
spec:
  gatewayClassName: example-class
  listeners:
  - name: http
    protocol: HTTP
    port: 80
    hostname: "www.example.com"
    allowedRoutes:
      namespaces:
        from: Same
```

**HTTPRoute (defines routing rules to backend Services):**

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: example-route
  namespace: production
spec:
  parentRefs:
  - name: example-gateway
  hostnames:
  - "www.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /api
    backendRefs:
    - name: api-service
      port: 8080
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: web-service
      port: 80
```

### Ingress (legacy, still tested)

```bash
# Create an Ingress imperatively
kubectl create ingress <name> --rule="<host>/<path>=<service>:<port>"
kubectl create ingress web-ingress --rule="app.example.com/=web-svc:80"
kubectl create ingress web-ingress --rule="app.example.com/api*=api-svc:8080"

# List Ingress resources
kubectl get ingress -A

# Describe an Ingress
kubectl describe ingress <name> -n <namespace>
```

**Ingress YAML with path-based routing:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
  namespace: production
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8080
      - path: /
        pathType: Prefix
        backend:
          service:
            name: web-service
            port:
              number: 80
```

### CoreDNS

```bash
# Check CoreDNS Pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# View CoreDNS ConfigMap (Corefile)
kubectl get configmap coredns -n kube-system -o yaml

# Edit CoreDNS configuration
kubectl edit configmap coredns -n kube-system

# Restart CoreDNS after config changes
kubectl rollout restart deployment coredns -n kube-system

# Test DNS resolution from a Pod
kubectl run dns-test --image=busybox:1.28 --restart=Never --rm -it -- nslookup <service-name>
kubectl run dns-test --image=busybox:1.28 --restart=Never --rm -it -- nslookup <service-name>.<namespace>.svc.cluster.local
kubectl run dns-test --image=busybox:1.28 --restart=Never --rm -it -- nslookup kubernetes.default
```

**DNS record format:** `<service-name>.<namespace>.svc.cluster.local`

---

## Storage (10%)

### PersistentVolumes and PersistentVolumeClaims

```bash
# List PersistentVolumes (cluster-scoped)
kubectl get pv
kubectl get pv --sort-by=.spec.capacity.storage

# List PersistentVolumeClaims (namespace-scoped)
kubectl get pvc -n <namespace>

# Describe PV/PVC
kubectl describe pv <pv-name>
kubectl describe pvc <pvc-name> -n <namespace>

# Delete a PVC
kubectl delete pvc <name> -n <namespace>

# List StorageClasses
kubectl get storageclass
kubectl get sc
kubectl describe sc <name>
```

**PersistentVolume YAML:**

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: manual
  hostPath:
    path: /mnt/data
```

**PersistentVolumeClaim YAML:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-data
  namespace: production
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: manual
```

**StorageClass YAML (dynamic provisioning):**

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-storage
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
```

**Access modes:** ReadWriteOnce (RWO), ReadOnlyMany (ROX), ReadWriteMany (RWX), ReadWriteOncePod (RWOP)

**Reclaim policies:** Retain, Delete, Recycle (deprecated)

---

## Troubleshooting (30%)

This is the highest-weighted domain. Master the diagnostic ladder: `get > describe > logs > events`.

### The diagnostic ladder

```bash
# Step 1: GET -- overview of resource state
kubectl get pods -n <namespace>
kubectl get pods -n <namespace> -o wide
kubectl get nodes

# Step 2: DESCRIBE -- detailed info and events
kubectl describe pod <pod-name> -n <namespace>
kubectl describe node <node-name>

# Step 3: LOGS -- container output
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -c <container-name> -n <namespace>
kubectl logs <pod-name> --previous -n <namespace>
kubectl logs <pod-name> -f -n <namespace>
kubectl logs <pod-name> --all-containers=true -n <namespace>
kubectl logs <pod-name> --tail=100 -n <namespace>
kubectl logs <pod-name> --since=1h -n <namespace>

# Step 4: EVENTS -- cluster-level events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
kubectl get events -n <namespace> --field-selector=reason=Failed
kubectl events -n <namespace>
```

### Node troubleshooting

```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check kubelet status (SSH to the node first)
sudo systemctl status kubelet
sudo journalctl -u kubelet -f
sudo journalctl -u kubelet --no-pager | tail -50

# Restart kubelet
sudo systemctl restart kubelet
sudo systemctl enable kubelet

# Check kubelet configuration
cat /var/lib/kubelet/config.yaml
cat /etc/kubernetes/kubelet.conf

# Check container runtime
sudo systemctl status containerd
sudo crictl ps
sudo crictl pods
```

### Control plane troubleshooting

```bash
# Check control plane Pods (static Pods)
kubectl get pods -n kube-system

# Check static Pod manifests (on the control plane node)
ls /etc/kubernetes/manifests/
cat /etc/kubernetes/manifests/kube-apiserver.yaml
cat /etc/kubernetes/manifests/kube-controller-manager.yaml
cat /etc/kubernetes/manifests/kube-scheduler.yaml
cat /etc/kubernetes/manifests/etcd.yaml

# Check control plane component logs
kubectl logs -n kube-system kube-apiserver-<node-name>
kubectl logs -n kube-system kube-controller-manager-<node-name>
kubectl logs -n kube-system kube-scheduler-<node-name>
kubectl logs -n kube-system etcd-<node-name>

# If API server is down, check logs via container runtime
sudo crictl ps -a | grep kube-apiserver
sudo crictl logs <container-id>
```

### Pod troubleshooting

```bash
# Check Pod status and reason
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>

# Check container logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -c <container-name> -n <namespace>
kubectl logs <pod-name> --previous -n <namespace>

# Execute a command in a running container
kubectl exec <pod-name> -n <namespace> -- <command>
kubectl exec <pod-name> -n <namespace> -- cat /etc/resolv.conf
kubectl exec <pod-name> -n <namespace> -- env
kubectl exec <pod-name> -n <namespace> -- ls -la /app

# Interactive shell
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

### Ephemeral debug containers

New in the February 2025 curriculum. Essential for debugging distroless or minimal images.

```bash
# Add an ephemeral debug container to a running Pod
kubectl debug -it <pod-name> --image=busybox:1.28 --target=<container-name>
kubectl debug -it <pod-name> -n <namespace> --image=busybox:1.28

# Create a copy of a Pod with a debug container
kubectl debug <pod-name> -it --copy-to=<debug-pod-name> --image=busybox:1.28
kubectl debug <pod-name> -it --copy-to=debug-pod --container=debugger --image=busybox:1.28

# Create a copy with all images replaced
kubectl debug <pod-name> --copy-to=debug-pod --set-image=*=busybox:1.28

# Debug a Node (creates a Pod with host namespaces and filesystem at /host)
kubectl debug node/<node-name> -it --image=busybox:1.28
# Inside the debug Pod:
#   chroot /host    (to access the host filesystem)
#   systemctl status kubelet
#   journalctl -u kubelet
```

### Service and networking troubleshooting

```bash
# Check if Service has endpoints
kubectl get endpoints <service-name> -n <namespace>
kubectl get endpointslices -l kubernetes.io/service-name=<service-name> -n <namespace>

# Check Service selector matches Pod labels
kubectl get svc <service-name> -n <namespace> -o yaml | grep -A5 selector
kubectl get pods -n <namespace> --show-labels

# Test connectivity from within the cluster
kubectl run test --image=busybox:1.28 --restart=Never --rm -it -- wget -qO- http://<service>:<port>
kubectl run test --image=busybox:1.28 --restart=Never --rm -it -- nc -zv <service> <port>

# Test DNS resolution
kubectl run test --image=busybox:1.28 --restart=Never --rm -it -- nslookup <service>.<namespace>.svc.cluster.local

# Check kube-proxy
kubectl get pods -n kube-system -l k8s-app=kube-proxy
kubectl logs -n kube-system <kube-proxy-pod>

# Check NetworkPolicies that might block traffic
kubectl get networkpolicies -n <namespace>
kubectl describe networkpolicy <name> -n <namespace>

# Port forward for testing
kubectl port-forward pod/<pod-name> <local-port>:<pod-port> -n <namespace>
kubectl port-forward svc/<service-name> <local-port>:<service-port> -n <namespace>
```

### Resource monitoring

```bash
# Show node resource usage (requires metrics-server)
kubectl top nodes
kubectl top node <node-name>

# Show Pod resource usage
kubectl top pods -n <namespace>
kubectl top pods -n <namespace> --sort-by=cpu
kubectl top pods -n <namespace> --sort-by=memory
kubectl top pod <pod-name> -n <namespace> --containers

# Check cluster info
kubectl cluster-info
kubectl cluster-info dump

# List API resources and versions
kubectl api-resources
kubectl api-versions

# Check component statuses
kubectl get componentstatuses
```

---

## Helm commands

New in the February 2025 curriculum. Helm manages Kubernetes applications as charts.

```bash
# Add a chart repository
helm repo add <name> <url>
helm repo add bitnami https://charts.bitnami.com/bitnami

# Update repository index
helm repo update

# List configured repositories
helm repo list

# Search for charts in repositories
helm search repo <keyword>
helm search repo nginx

# Search for charts on Artifact Hub
helm search hub <keyword>

# Show chart information
helm show chart <chart>
helm show values <chart>
helm show all <chart>
helm show readme <chart>

# Install a chart (create a release)
helm install <release-name> <chart>
helm install my-nginx bitnami/nginx
helm install my-nginx bitnami/nginx --namespace production --create-namespace
helm install my-nginx bitnami/nginx --set replicaCount=3
helm install my-nginx bitnami/nginx -f values.yaml

# List releases
helm list
helm list -A
helm list -n <namespace>

# Get release status
helm status <release-name>

# Get release history
helm history <release-name>

# Upgrade a release
helm upgrade <release-name> <chart>
helm upgrade my-nginx bitnami/nginx --set replicaCount=5
helm upgrade my-nginx bitnami/nginx -f values.yaml

# Rollback a release
helm rollback <release-name> <revision>
helm rollback my-nginx 1

# Uninstall a release
helm uninstall <release-name>
helm uninstall my-nginx -n production

# Get release manifest (what was deployed)
helm get manifest <release-name>

# Get release values
helm get values <release-name>
helm get values <release-name> --all

# Template a chart locally (preview without installing)
helm template <release-name> <chart>
helm template my-nginx bitnami/nginx --set replicaCount=3

# Pull a chart for local inspection
helm pull <chart>
helm pull <chart> --untar
```

---

## Kustomize commands

New in the February 2025 curriculum. Kustomize customizes Kubernetes manifests without templates.

```bash
# Preview kustomized output (does not apply)
kubectl kustomize <directory>
kubectl kustomize ./overlays/production/

# Apply kustomized resources
kubectl apply -k <directory>
kubectl apply -k ./overlays/production/

# Delete kustomized resources
kubectl delete -k <directory>

# View what would be applied
kubectl diff -k <directory>
```

**kustomization.yaml structure:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# Include base resources
resources:
- deployment.yaml
- service.yaml

# Set common namespace
namespace: production

# Add common labels
commonLabels:
  app: web
  environment: production

# Set name prefix/suffix
namePrefix: prod-
nameSuffix: -v1

# Image overrides
images:
- name: nginx
  newName: nginx
  newTag: "1.25"

# Patches (strategic merge)
patches:
- path: replica-patch.yaml

# ConfigMap generator
configMapGenerator:
- name: app-config
  literals:
  - DB_HOST=mysql
  - DB_PORT=3306

# Secret generator
secretGenerator:
- name: db-creds
  literals:
  - username=admin
  - password=secret
```

**Overlay structure (base + environment-specific):**

```
myapp/
  base/
    deployment.yaml
    service.yaml
    kustomization.yaml
  overlays/
    dev/
      kustomization.yaml      # references: ../../base
      replica-patch.yaml
    production/
      kustomization.yaml      # references: ../../base
      replica-patch.yaml
```

---

## Resource shortnames

Use shortnames to save time on the exam.

| Resource | Shortname |
| --- | --- |
| pods | po |
| services | svc |
| deployments | deploy |
| replicasets | rs |
| daemonsets | ds |
| statefulsets | sts |
| jobs | job |
| cronjobs | cj |
| configmaps | cm |
| secrets | secret |
| persistentvolumes | pv |
| persistentvolumeclaims | pvc |
| nodes | no |
| namespaces | ns |
| ingresses | ing |
| networkpolicies | netpol |
| serviceaccounts | sa |
| storageclasses | sc |
| horizontalpodautoscalers | hpa |
| poddisruptionbudgets | pdb |
| roles | role |
| rolebindings | rolebinding |
| clusterroles | clusterrole |
| clusterrolebindings | clusterrolebinding |
| events | ev |
| endpoints | ep |
| endpointslices | es |
| customresourcedefinitions | crd |
| priorityclasses | pc |

List all available shortnames: `kubectl api-resources`

---

## Output formatting

```bash
# YAML output
kubectl get pod <name> -o yaml

# JSON output
kubectl get pod <name> -o json

# Wide output (additional columns)
kubectl get pods -o wide

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName

# Resource name only
kubectl get pods -o name

# JSONPath (extract specific fields)
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Sort by field
kubectl get pods --sort-by='.metadata.creationTimestamp'
kubectl get pv --sort-by='.spec.capacity.storage'
```

---

## Exam speed techniques

### Aliases and shortcuts (pre-configured in exam)

```bash
# The k alias is pre-configured
k get pods    # same as kubectl get pods

# Bash autocompletion is pre-configured
k get d<TAB>  # autocompletes to deployments
```

### Time-saving patterns

```bash
# Generate YAML, edit, then apply (the imperative-to-declarative pipeline)
kubectl create deployment web --image=nginx --dry-run=client -o yaml > deploy.yaml
vim deploy.yaml   # make edits
kubectl apply -f deploy.yaml

# Quick Pod for testing
kubectl run test --image=busybox:1.28 --restart=Never --rm -it -- <command>

# Quick DNS test
kubectl run dns-test --image=busybox:1.28 --restart=Never --rm -it -- nslookup <service>

# Quick connectivity test
kubectl run curl-test --image=curlimages/curl --restart=Never --rm -it -- curl -s http://<service>:<port>

# Redirect output to file
kubectl get pod <name> -o yaml > pod.yaml

# Find what fields are available
kubectl explain pod.spec --recursive | grep -i <search-term>

# Copy/paste in exam terminal
# Ctrl+Shift+C to copy
# Ctrl+Shift+V to paste
```

### Bookmark these documentation pages

- kubernetes.io/docs/reference/kubectl/quick-reference/
- kubernetes.io/docs/concepts/configuration/configmap/
- kubernetes.io/docs/concepts/configuration/secret/
- kubernetes.io/docs/concepts/services-networking/network-policies/
- kubernetes.io/docs/concepts/services-networking/gateway/
- kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/
- kubernetes.io/docs/tasks/debug/debug-application/
- kubernetes.io/docs/reference/access-authn-authz/rbac/
- helm.sh/docs/helm/
- gateway-api.sigs.k8s.io/guides/http-routing/
