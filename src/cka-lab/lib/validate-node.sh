#!/usr/bin/env bash
#================================================================
# validate-node.sh — Runs inside each Vagrant VM to verify CKA
# prereqs are intact. Invoked from cka-validate.ps1 via:
#   Get-Content lib/validate-node.sh | vagrant ssh <vm> -c "bash -s"
# Piping via stdin avoids the Windows OpenSSH truncation of long
# multi-line scripts passed inline to `vagrant ssh -c`.
#================================================================
set -uo pipefail

NODE=$(hostname)
FAIL=0
WARN=0

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAIL=1; }
warn() { echo "  [WARN] $1"; WARN=1; }

echo "=== Validating $NODE ==="

# --- 1. Static IP ---
echo "-- Network --"
declare -A EXPECTED_IPS=(
  ["control1"]="192.168.50.10"
  ["worker1"]="192.168.50.11"
  ["worker2"]="192.168.50.12"
)
EXPECTED="${EXPECTED_IPS[$NODE]:-unknown}"
if ip addr | grep -q "$EXPECTED"; then
  pass "static IP $EXPECTED assigned"
else
  fail "expected IP $EXPECTED not found"
fi

# Verify all nodes are in /etc/hosts
for h in control1 worker1 worker2; do
  if grep -q "$h" /etc/hosts; then
    pass "/etc/hosts has $h"
  else
    fail "/etc/hosts missing $h"
  fi
done

# --- 2. Required binaries ---
echo "-- Binaries --"
for cmd in kubeadm kubelet kubectl containerd; do
  if command -v "$cmd" &>/dev/null; then
    ver=$($cmd version 2>/dev/null | head -1 || echo "present")
    pass "$cmd: $ver"
  else
    fail "$cmd: NOT FOUND"
  fi
done

# --- 3. Services ---
echo "-- Services --"
for svc in containerd kubelet; do
  if systemctl is-enabled "$svc" &>/dev/null; then
    pass "$svc enabled"
  else
    fail "$svc NOT enabled"
  fi
done
if systemctl is-active containerd &>/dev/null; then
  pass "containerd running"
else
  fail "containerd NOT running"
fi

# --- 4. Swap must be off ---
echo "-- Swap --"
if [ "$(swapon --show | wc -l)" -eq 0 ]; then
  pass "swap disabled"
else
  fail "swap is ACTIVE — kubeadm will refuse to init"
fi

# --- 5. Kernel modules loaded ---
echo "-- Kernel modules --"
for mod in overlay br_netfilter; do
  if lsmod | grep -q "^$mod"; then
    pass "$mod loaded"
  else
    fail "$mod NOT loaded"
  fi
done

# --- 6. Sysctl params ---
echo "-- Sysctl --"
for param in net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward; do
  val=$(sysctl -n "$param" 2>/dev/null)
  if [ "$val" = "1" ]; then
    pass "$param = 1"
  else
    fail "$param = $val (expected 1)"
  fi
done

# --- 7. Containerd cgroup driver ---
echo "-- Containerd config --"
if grep -q 'SystemdCgroup = true' /etc/containerd/config.toml 2>/dev/null; then
  pass "SystemdCgroup = true"
else
  fail "SystemdCgroup NOT set to true"
fi

# --- 8. crictl config ---
echo "-- crictl --"
if [ -f /etc/crictl.yaml ] && grep -q 'containerd.sock' /etc/crictl.yaml; then
  pass "crictl.yaml points to containerd"
else
  warn "crictl.yaml missing or misconfigured (non-fatal)"
fi

# --- 9. Packages held ---
echo "-- Package holds --"
held=$(apt-mark showhold 2>/dev/null)
for pkg in kubelet kubeadm kubectl; do
  if echo "$held" | grep -q "^$pkg$"; then
    pass "$pkg held"
  else
    warn "$pkg NOT held — apt upgrade could break it"
  fi
done

# --- Summary ---
echo ""
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
  echo "=== $NODE: ALL CHECKS PASSED ==="
elif [ "$FAIL" -eq 0 ]; then
  echo "=== $NODE: PASSED with warnings ==="
else
  echo "=== $NODE: FAILED — fix before kubeadm ==="
fi
exit $FAIL
