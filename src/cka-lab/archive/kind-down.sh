#!/usr/bin/env bash
#
# ⚠️  STALE — The PowerShell version (kind-down.ps1) is the canonical script.
# This Bash version still uses the old Stop/Restart menu and -SkipDdStop flag.
# The PS1 version uses -StopDockerDesktop with a "cluster only / full shutdown" menu.
# Use kind-down.ps1 from PowerShell 7+ instead, or update this script to match.
#
# kind-down.sh — Destroys the CKA KIND cluster with options to stop or restart Docker Desktop.
#
# Full lifecycle shutdown script for Tim's CKA certification lab environment.
# Presents an interactive menu to choose shutdown mode:
#   - Stop:    Destroy cluster, stop Docker Desktop, shut down WSL2
#   - Restart: Destroy cluster, restart Docker Desktop (keep WSL2 running)
#
# Performs a clean teardown in order:
#   1. Deletes the KIND cluster (removes containers and network)
#   2. Optionally prunes unused Docker images to reclaim disk space
#   3. Stops or restarts Docker Desktop based on menu selection
#   4. Shuts down WSL2 to release vmmem memory (stop mode only)
#   5. Verifies all processes are stopped
#
# Idempotent — safe to run even if the cluster is already gone or DD is already stopped.
#
# Usage:
#   ./kind-down.sh                        # Interactive shutdown menu
#   ./kind-down.sh --prune                # Also prune unused Docker images
#   ./kind-down.sh --skip-dd-stop         # Leave Docker Desktop running (skip menu)
#   ./kind-down.sh --cluster-name my-lab  # Custom cluster name
#
# Author:  Tim Warner
# Version: 1.1
# Requires: Docker Desktop (WSL2 backend), KIND
# Tested:  Bash 5.x, Ubuntu 22.04 on WSL2

# Use +e so we attempt all cleanup steps even if one fails
set -uo pipefail

# ---------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------
CLUSTER_NAME="cka-lab"
PRUNE=false
SKIP_DD_STOP=false

# ---------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --cluster-name)
            CLUSTER_NAME="$2"; shift 2 ;;
        --prune)
            PRUNE=true; shift ;;
        --skip-dd-stop)
            SKIP_DD_STOP=true; shift ;;
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

stop_docker_desktop() {
    # Stop Docker Desktop via Windows interop
    # Docker Desktop runs as a Windows process, so we kill it from WSL
    local dd_exe="/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe"

    # Graceful shutdown — ask Docker Desktop to quit via CLI
    if command -v docker &>/dev/null; then
        write_info "Sending Docker Desktop quit signal..."
        # Use the Windows taskkill via interop for graceful shutdown
        /mnt/c/Windows/System32/cmd.exe /c "taskkill /IM \"Docker Desktop.exe\" /F" &>/dev/null || true
        sleep 3
    fi

    # Force-kill any remaining Docker processes
    /mnt/c/Windows/System32/cmd.exe /c "taskkill /IM \"com.docker.backend.exe\" /F" &>/dev/null || true
    /mnt/c/Windows/System32/cmd.exe /c "taskkill /IM \"com.docker.proxy.exe\" /F" &>/dev/null || true
    sleep 2
}

# ---------------------------------------------------------------
# Banner
# ---------------------------------------------------------------
echo ""
echo "============================================================"
echo "  KIND Cluster Shutdown - CKA Lab Environment"
echo "  Cluster: $CLUSTER_NAME"
echo "============================================================"
echo ""

# ---------------------------------------------------------------
# Shutdown mode menu (skip if --skip-dd-stop was passed)
# ---------------------------------------------------------------
restart_docker=false
if [[ "$SKIP_DD_STOP" == false ]]; then
    echo "Select shutdown mode:"
    echo "  [1] Destroy environment and stop Docker Desktop"
    echo "  [2] Destroy environment and restart Docker Desktop"
    echo ""
    read -rp "Enter choice [1]: " choice
    choice="${choice:-1}"
    case "$choice" in
        1)
            echo ""
            echo "  >> Will stop Docker Desktop after teardown"
            ;;
        2)
            restart_docker=true
            echo ""
            echo "  >> Will restart Docker Desktop after teardown"
            ;;
        *)
            echo "[ERROR] Invalid choice '$choice'. Please enter 1 or 2."
            exit 1
            ;;
    esac
    echo ""
fi

# ---------------------------------------------------------------
# Step 1: Delete the KIND cluster
# ---------------------------------------------------------------
write_step "Step 1: Deleting KIND cluster"

# Check if Docker is even running before trying kind commands
docker_running=false
if docker info &>/dev/null; then
    docker_running=true
fi

if [[ "$docker_running" == false ]]; then
    write_info "Docker is not running - cluster containers are already gone"
else
    # Check if the cluster exists before trying to delete it
    cluster_list=$(kind get clusters 2>&1 || true)
    if echo "$cluster_list" | grep -qx "$CLUSTER_NAME"; then
        write_info "Deleting cluster '$CLUSTER_NAME'..."
        if kind delete cluster --name "$CLUSTER_NAME"; then
            write_success "Cluster '$CLUSTER_NAME' deleted"
        else
            write_error "KIND delete returned non-zero exit code"
            write_info "Attempting to force-remove Docker containers..."
            # Fallback: force-remove containers by label
            containers=$(docker ps -aq --filter "label=io.x-k8s.kind.cluster=$CLUSTER_NAME" 2>&1 || true)
            if [[ -n "$containers" ]]; then
                echo "$containers" | xargs docker rm -f &>/dev/null || true
                write_info "Force-removed cluster containers"
            fi
        fi
    else
        write_info "Cluster '$CLUSTER_NAME' does not exist - nothing to delete"
    fi
fi

# ---------------------------------------------------------------
# Step 2: Prune Docker resources (optional)
# ---------------------------------------------------------------
if [[ "$PRUNE" == true ]]; then
    write_step "Step 2: Pruning unused Docker resources"

    if [[ "$docker_running" == true ]]; then
        write_info "Removing unused images, networks, and build cache..."
        docker system prune -af --volumes 2>&1 | grep -i "total reclaimed space" || true
    else
        write_info "Docker is not running - skipping prune"
    fi
else
    write_step "Step 2: Skipping Docker prune (use --prune to reclaim disk space)"
fi

# ---------------------------------------------------------------
# Step 3: Stop Docker Desktop
# ---------------------------------------------------------------
if [[ "$SKIP_DD_STOP" == true ]]; then
    write_step "Step 3: Skipping Docker Desktop shutdown (--skip-dd-stop specified)"
elif [[ "$restart_docker" == true ]]; then
    write_step "Step 3: Restarting Docker Desktop"

    stop_docker_desktop

    # Restart Docker Desktop
    dd_exe="/mnt/c/Program Files/Docker/Docker/Docker Desktop.exe"
    if [[ -f "$dd_exe" ]]; then
        write_info "Restarting Docker Desktop..."
        "$dd_exe" &>/dev/null &
        disown
        write_success "Docker Desktop restart initiated"
    else
        write_error "Docker Desktop.exe not found - please restart manually"
    fi
else
    write_step "Step 3: Stopping Docker Desktop"

    stop_docker_desktop
    write_success "Docker Desktop stopped"
fi

# ---------------------------------------------------------------
# Step 4: Shut down WSL2 to release vmmem memory
# ---------------------------------------------------------------
if [[ "$SKIP_DD_STOP" == true ]]; then
    write_step "Step 4: Skipping WSL2 shutdown (Docker Desktop left running)"
elif [[ "$restart_docker" == true ]]; then
    write_step "Step 4: Skipping WSL2 shutdown (Docker Desktop restarting)"
else
    write_step "Step 4: Shutting down WSL2"

    write_info "Sending WSL shutdown signal..."
    # Note: wsl.exe --shutdown from inside WSL will terminate THIS session.
    # We warn the user and let them decide, or run it as the last action.
    write_info "WSL shutdown will terminate this terminal session."
    write_info "Run from PowerShell if needed: wsl --shutdown"

    # We can still try — the command will execute but this shell will die
    # So we do it as the very last step after the final banner
    WSL_SHUTDOWN_PENDING=true
fi

# ---------------------------------------------------------------
# Step 5: Final verification
# ---------------------------------------------------------------
write_step "Step 5: Verification"

if [[ "$restart_docker" == true ]]; then
    write_info "Docker Desktop is restarting - cluster destroyed, Docker available for new work"
else
    # Check for Docker daemon status
    if docker info &>/dev/null; then
        write_info "Docker daemon is still responding (may take a moment to stop)"
    else
        write_success "Docker daemon is not responding (stopped)"
    fi
fi

# Show memory info
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
if [[ "$restart_docker" == true ]]; then
    echo "  CKA Lab Torn Down (Docker restarting)"
else
    echo "  CKA Lab Shut Down"
fi
echo "  Cluster '$CLUSTER_NAME' deleted"
echo ""
if [[ "$restart_docker" == true ]]; then
    echo "  Docker Desktop: restarting (ready for new work)"
    echo "  To recreate:  ./kind-up.sh"
else
    echo "  Docker Desktop: stopped"
    echo "  To restart:   ./kind-up.sh"
fi
echo "============================================================"
echo ""

# Execute WSL shutdown as the very last action (if pending)
if [[ "${WSL_SHUTDOWN_PENDING:-false}" == true ]]; then
    write_info "Executing WSL shutdown in 3 seconds (this terminal will close)..."
    sleep 3
    /mnt/c/Windows/System32/wsl.exe --shutdown &>/dev/null || true
fi
