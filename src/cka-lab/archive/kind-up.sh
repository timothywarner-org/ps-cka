#!/usr/bin/env bash
#
# ⚠️  STALE — The PowerShell version (kind-up.ps1) is the canonical script.
# This Bash version is missing: 4-topology menu, -ShowKubeadm, -Tutorial mode,
# workloads topology with labels/taints, and HA topology support.
# Use kind-up.ps1 from PowerShell 7+ instead, or update this script to match.
#
# kind-up.sh — Starts Docker, waits for readiness, and creates a KIND cluster for CKA training.
#
# Full lifecycle startup script for Tim's CKA certification lab environment.
# Presents an interactive menu to choose cluster topology:
#   - Simple: 1 control-plane + 1 worker (faster, lighter)
#   - Full:   1 control-plane + 2 workers (CKA exam topology)
#
# Handles all prerequisites automatically:
#   - Launches Docker Desktop if not already running (via WSL interop)
#   - Polls the Docker daemon until it responds (DD can take 30-60 seconds)
#   - Creates the KIND cluster with the chosen topology
#   - Verifies all nodes reach Ready status
#   - Displays resource usage summary
#
# The cluster config includes CKA-relevant settings:
#   - PodSecurity and NodeRestriction admission plugins
#   - NodePort mappings on 30000, 30080, 30443
#   - containerd runtime (matches CKA exam environment)
#
# Usage:
#   ./kind-up.sh                        # Interactive topology menu
#   ./kind-up.sh --skip-dd-start        # Skip Docker Desktop startup
#   ./kind-up.sh --config ./cka-3node.yaml  # Skip menu, use config directly
#   ./kind-up.sh --cluster-name my-lab  # Custom cluster name
#   ./kind-up.sh --dd-timeout 180       # Custom Docker Desktop timeout
#
# Author:  Tim Warner
# Version: 1.1
# Requires: Docker Desktop (WSL2 backend), KIND, kubectl
# Tested:  Bash 5.x, Ubuntu 22.04 on WSL2

set -euo pipefail

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------
CLUSTER_NAME="cka-lab"
CONFIG_PATH=""
CONFIG_PATH_EXPLICIT=false
DD_TIMEOUT_SECONDS=120
SKIP_DD_START=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster-name)
            CLUSTER_NAME="$2"; shift 2 ;;
        --config)
            CONFIG_PATH="$2"; CONFIG_PATH_EXPLICIT=true; shift 2 ;;
        --dd-timeout)
            DD_TIMEOUT_SECONDS="$2"; shift 2 ;;
        --skip-dd-start)
            SKIP_DD_START=true; shift ;;
        -h|--help)
            sed -n '2,/^$/{ s/^# \?//; p }' "$0"
            exit 0 ;;
        *)
            echo "[ERROR] Unknown argument: $1"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------
write_step()    { echo ""; echo ">>> $1"; echo ""; }
write_success() { echo "[SUCCESS] $1"; }
write_info()    { echo "[INFO] $1"; }
write_error()   { echo "[ERROR] $1"; }

# ---------------------------------------------------------------
# Banner
# ---------------------------------------------------------------
echo ""
echo "============================================================"
echo "  KIND Cluster Startup - CKA Lab Environment"
echo "============================================================"
echo ""

# ---------------------------------------------------------------
# Topology menu (skip if --config was explicitly passed)
# ---------------------------------------------------------------
if [[ "$CONFIG_PATH_EXPLICIT" == false ]]; then
    echo "Select cluster topology:"
    echo "  [1] Simple  - 1 control-plane + 1 worker  (faster, lighter)"
    echo "  [2] Full    - 1 control-plane + 2 workers  (CKA exam topology)"
    echo ""
    read -rp "Enter choice [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
        1)
            CONFIG_PATH="${SCRIPT_DIR}/cka-simple.yaml"
            node_description="1 control-plane + 1 worker"
            node_count=2
            ;;
        2)
            CONFIG_PATH="${SCRIPT_DIR}/cka-3node.yaml"
            node_description="1 control-plane + 2 workers"
            node_count=3
            ;;
        *)
            echo "[ERROR] Invalid choice '$choice'. Please enter 1 or 2."
            exit 1
            ;;
    esac
    echo ""
    echo "  >> $node_description selected"
    echo ""
else
    # Custom config path passed — infer node count from config file
    if [[ -f "$CONFIG_PATH" ]]; then
        node_count=$(grep -cE '^\s*- role:\s+(control-plane|worker)' "$CONFIG_PATH" || true)
        node_description="${node_count} nodes (custom config)"
    else
        node_description="custom config"
        node_count=0
    fi
fi

# ---------------------------------------------------------------
# Step 1: Validate prerequisites are installed
# ---------------------------------------------------------------
write_step "Step 1: Validating prerequisites"

missing_tools=()

# Check Docker CLI
if ! command -v docker &>/dev/null; then
    missing_tools+=("docker (Docker Desktop WSL2 integration not enabled, or docker-ce not installed)")
fi

# Check KIND
if ! command -v kind &>/dev/null; then
    missing_tools+=("kind (install from: https://kind.sigs.k8s.io/docs/user/quick-start/#installation)")
fi

# Check kubectl
if ! command -v kubectl &>/dev/null; then
    missing_tools+=("kubectl (install from: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)")
fi

# Bail out if anything critical is missing
if [[ ${#missing_tools[@]} -gt 0 ]]; then
    write_error "Missing prerequisites:"
    for tool in "${missing_tools[@]}"; do
        echo "  - $tool"
    done
    exit 1
fi

# Validate the cluster config file exists
if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "[ERROR] KIND cluster config not found: $CONFIG_PATH"
    exit 1
fi

write_success "All prerequisites verified"
write_info "KIND version: $(kind version)"
write_info "Config: $CONFIG_PATH"

# ---------------------------------------------------------------
# Step 2: Start Docker Desktop and wait for daemon readiness
# ---------------------------------------------------------------
write_step "Step 2: Starting Docker Desktop"

if [[ "$SKIP_DD_START" == true ]]; then
    write_info "Skipping Docker Desktop startup (--skip-dd-start specified)"
else
    # Check if Docker daemon is already responding
    dd_already_running=false
    if docker info &>/dev/null; then
        dd_already_running=true
    fi

    if [[ "$dd_already_running" == true ]]; then
        write_info "Docker Desktop is already running"
    else
        # Launch Docker Desktop via WSL interop (calls the Windows exe)
        dd_exe="/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe"
        if [[ -f "$dd_exe" ]]; then
            write_info "Launching Docker Desktop via WSL interop..."
            "$dd_exe" &>/dev/null &
            disown
        else
            write_info "Docker Desktop.exe not found at expected path — assuming it will be started manually"
        fi
        write_info "Waiting for Docker daemon to become ready (timeout: ${DD_TIMEOUT_SECONDS}s)..."
    fi
fi

# Poll Docker daemon until it responds or we hit the timeout
poll_interval=5
elapsed=0
docker_ready=false

while [[ $elapsed -lt $DD_TIMEOUT_SECONDS ]]; do
    if docker info &>/dev/null; then
        docker_ready=true
        break
    fi

    remaining=$(( DD_TIMEOUT_SECONDS - elapsed ))
    echo "  ... Docker not ready yet (${remaining}s remaining)"
    sleep "$poll_interval"
    elapsed=$(( elapsed + poll_interval ))
done

if [[ "$docker_ready" == false ]]; then
    write_error "Docker Desktop failed to start within ${DD_TIMEOUT_SECONDS} seconds. Check Docker Desktop for errors."
    exit 1
fi

write_success "Docker daemon is ready (took ~${elapsed}s)"

# ---------------------------------------------------------------
# Step 3: Create the KIND cluster (idempotent)
# ---------------------------------------------------------------
write_step "Step 3: Creating KIND cluster"

# Check if cluster already exists — safe to re-run
cluster_list=$(kind get clusters 2>&1 || true)
if echo "$cluster_list" | grep -qx "$CLUSTER_NAME"; then
    write_info "Cluster '$CLUSTER_NAME' already exists - skipping creation"
    write_info "To rebuild, run kind-down.sh first, then kind-up.sh"
else
    write_info "Creating ${node_count}-node cluster '$CLUSTER_NAME'..."
    write_info "This pulls node images and runs kubeadm - expect 2-4 minutes on first run."
    echo ""

    # Create the cluster — this is the long-running operation
    if ! kind create cluster --name "$CLUSTER_NAME" --config "$CONFIG_PATH" --wait 120s; then
        write_error "KIND cluster creation failed. Check Docker Desktop logs and available disk space."
        exit 1
    fi

    write_success "Cluster '$CLUSTER_NAME' created successfully"
fi

# ---------------------------------------------------------------
# Step 4: Verify cluster health
# ---------------------------------------------------------------
write_step "Step 4: Verifying cluster health"

# Confirm kubeconfig context is set
current_context=$(kubectl config current-context 2>&1 || echo "unknown")
write_info "Kubeconfig context: $current_context"

# Wait for all nodes to reach Ready status
write_info "Waiting for all nodes to reach Ready status..."
max_node_wait=60
node_elapsed=0

while [[ $node_elapsed -lt $max_node_wait ]]; do
    if ! kubectl get nodes --no-headers 2>&1 | grep -q "NotReady"; then
        break
    fi
    sleep 5
    node_elapsed=$(( node_elapsed + 5 ))
done

if [[ $node_elapsed -ge $max_node_wait ]]; then
    write_error "Some nodes did not reach Ready status within ${max_node_wait}s"
    write_info "Check node conditions: kubectl describe nodes"
fi

# Display node status
echo ""
kubectl get nodes -o wide
echo ""

# Display system pods
write_info "System pods:"
kubectl get pods -n kube-system --no-headers 2>&1 | while IFS= read -r line; do
    echo "  $line"
done

# ---------------------------------------------------------------
# Step 5: Resource usage summary
# ---------------------------------------------------------------
write_step "Step 5: Resource usage summary"

# Show Docker container resource consumption
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" 2>&1 || true

# Show host memory impact
echo ""
if [[ -f /proc/meminfo ]]; then
    total_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
    avail_kb=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
    used_kb=$(( total_kb - avail_kb ))
    total_gb=$(awk "BEGIN { printf \"%.1f\", $total_kb / 1048576 }")
    used_gb=$(awk "BEGIN { printf \"%.1f\", $used_kb / 1048576 }")
    free_gb=$(awk "BEGIN { printf \"%.1f\", $avail_kb / 1048576 }")
    write_info "Host memory: ${used_gb}GB used / ${total_gb}GB total (${free_gb}GB free)"
fi

# Final banner
echo ""
echo "============================================================"
echo "  CKA Lab Ready"
echo "  Cluster: $CLUSTER_NAME | Nodes: $node_count | Context: $current_context"
echo ""
echo "  Quick reference:"
echo "    kubectl get nodes              - Check node status"
echo "    kubectl get pods -A             - All pods across namespaces"
echo "    kubectl run test --image=nginx  - Quick smoke test"
echo "    ./kind-down.sh                 - Tear it all down"
echo "============================================================"
echo ""
