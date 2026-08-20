#!/usr/bin/env zsh
#==============================================================================
# cka-lab.sh — CKA lab lifecycle dispatcher (macOS / VMware Fusion)
#
# One script with subcommands; bare invocation = status.
#
# Usage:
#   ./cka-lab.sh [up|down|status|info|validate|save|restore|snapshots|help]
#
# See ./cka-lab.sh help  or  the README for full subcommand reference.
#==============================================================================

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
export VAGRANT_CWD="${SCRIPT_DIR}"

source "${SCRIPT_DIR}/lib/common.sh"

# =============================================================================
# Subcommand implementations
# =============================================================================

print_usage() {
  print ""
  print "CKA Lab — macOS / VMware Fusion"
  print ""
  print "Usage: ./cka-lab.sh <subcommand> [args]"
  print ""
  print "Subcommands:"
  print "  up                  Provision and start all 3 VMs (idempotent)"
  print "  down                Gracefully halt all 3 VMs"
  print "  status [--quiet]    VM state table + ping  (default bare invocation)"
  print "  info                Connection guide (IP, SSH commands)"
  print "  validate            Run prereq checks on all 3 nodes"
  print "  save   [name]       Atomic snapshot — all 3 VMs (default: pre-cluster)"
  print "  restore [name]      Atomic restore  — all 3 VMs (default: pre-cluster)"
  print "  snapshots           List saved snapshots per VM"
  print "  help / -h / --help  Print this message"
  print ""
  print "Nodes:  control1 (192.168.50.10)  worker1 (.11)  worker2 (.12)"
  print "Creds:  vagrant / vagrant"
  print ""
}

# -----------------------------------------------------------------------------
cmd_up() {
  write_step "Bringing up CKA lab VMs (VMware Fusion)"
  write_info "First run provisions all prereqs. Subsequent runs are no-ops."
  vagrant up
  print ""
  cmd_info
}

# -----------------------------------------------------------------------------
cmd_down() {
  write_step "Halting CKA lab VMs (graceful ACPI shutdown)"
  vagrant halt
  write_success "All VMs halted."
  write_info "Resume with:  ./cka-lab.sh up"
}

# -----------------------------------------------------------------------------
cmd_status() {
  local quiet=0
  [[ "${1:-}" == "--quiet" ]] && quiet=1

  write_step "CKA lab — VM status"

  # Header
  printf "  %-10s %-18s %-10s %s\n" "NODE" "IP" "STATE" "PING"
  printf "  %s\n" "$(printf '─%.0s' {1..54})"

  local running=0 missing=0 off=0
  local running_vms=() missing_vms=()

  local name ip state ping_result
  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    ip="${entry##*:}"
    state=$(vm_state "${name}")

    if [[ "${state}" == "RUNNING" ]]; then
      if ping_host "${ip}"; then ping_result="OK"; else ping_result="NO"; fi
      (( running++ )) || true
      running_vms+=("${name}")
    else
      ping_result="-"
    fi

    [[ "${state}" == "MISSING" ]] && { (( missing++ )) || true; missing_vms+=("${name}"); }
    [[ "${state}" == "OFF" || "${state}" == "SAVED" ]] && (( off++ )) || true

    printf "  %-10s %-18s %-10s %s\n" "${name}" "${ip}" "${state}" "${ping_result}"
  done
  print ""

  # Aggregate messages
  if (( missing == ${#CKA_NODES[@]} )); then
    write_info "No VMs exist yet.  Create them with:  ./cka-lab.sh up"
    return 0
  fi

  if (( missing > 0 )); then
    write_warn "${missing} VM(s) missing: ${missing_vms[*]}"
    write_info "Run  ./cka-lab.sh up  to recreate."
  fi

  if (( running == 0 )); then
    write_success "All present VMs are stopped."
    (( off > 0 )) && write_info "Start them with:  ./cka-lab.sh up"
    return 0
  fi

  write_success "${running} VM(s) running: ${running_vms[*]}"

  if (( quiet )); then
    write_info "--quiet specified — skipping teardown prompt."
    return 1
  fi

  print ""
  print "  [0] Leave VMs running"
  print "  [1] Halt VMs gracefully   ./cka-lab.sh down"
  print ""
  printf "Enter choice [0]: "
  local choice
  read -r choice
  choice="${choice:-0}"

  case "${choice}" in
    0) write_info "Leaving VMs running." ;;
    1) cmd_down ;;
    *) write_error "Invalid choice '${choice}'. Aborted."; return 1 ;;
  esac
}

# -----------------------------------------------------------------------------
cmd_info() {
  write_step "CKA lab — connection guide"

  printf "  %-10s %-18s %-7s %s\n" "NODE" "IP" "STATUS" "SSH COMMAND"
  printf "  %s\n" "$(printf '─%.0s' {1..62})"

  local name ip status
  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    ip="${entry##*:}"
    if ping_host "${ip}"; then status="UP"; else status="DOWN"; fi
    printf "  %-10s %-18s %-7s vagrant ssh %s\n" "${name}" "${ip}" "${status}" "${name}"
  done

  print ""
  write_info "Direct SSH:   ssh vagrant@<ip>   (password: vagrant)"
  write_info "Vagrant SSH:  vagrant ssh <name>"
}

# -----------------------------------------------------------------------------
cmd_validate() {
  local script="${SCRIPT_DIR}/lib/validate-node.sh"
  if [[ ! -f "${script}" ]]; then
    write_error "validate-node.sh not found at ${script}"
    exit 1
  fi

  write_step "CKA lab — pre-cluster node validation"
  write_info "[WARN] findings are non-blocking — only [FAIL] blocks."
  print ""

  local all_passed=1
  local total_pass=0 total_warn=0 total_fail=0
  local output rc name

  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    print "--- ${name} ---"

    # Stdin delivery: propagates the inner bash exit code.
    # `vagrant ssh -c 'bash -s'` reads the script from stdin.
    set +e
    output=$(vagrant ssh "${name}" -c 'bash -s' < "${script}" 2>&1)
    rc=$?
    set -e

    print "${output}"

    local pass warn fail
    pass=$(print "${output}" | grep -c '\[PASS\]' || true)
    warn=$(print "${output}" | grep -c '\[WARN\]' || true)
    fail=$(print "${output}" | grep -c '\[FAIL\]' || true)
    (( total_pass += pass )) || true
    (( total_warn += warn )) || true
    (( total_fail += fail )) || true

    if (( rc != 0 )); then
      write_error ">>> ${name} FAILED validation <<<"
      all_passed=0
    fi
    print ""
  done

  write_step "Summary across all nodes"
  write_success "PASS: ${total_pass}"
  write_warn    "WARN: ${total_warn}"
  if (( total_fail > 0 )); then
    write_error "FAIL: ${total_fail}"
  else
    write_info  "FAIL: ${total_fail}"
  fi

  if (( all_passed )); then
    write_success "ALL NODES READY — safe to snapshot, or run: kubeadm init on control1"
    (( total_warn > 0 )) && write_warn "${total_warn} warning(s) present — non-blocking"
  else
    write_error "ONE OR MORE NODES FAILED"
    write_info  "Re-provision:  vagrant provision <name>"
    exit 1
  fi
}

# -----------------------------------------------------------------------------
cmd_save() {
  local snap="${1:-pre-cluster}"

  write_step "Saving snapshot '${snap}' across all 3 VMs"

  # Atomic preflight: every VM must exist (not MISSING)
  write_info "Pre-flight: verifying all VMs are created..."
  local missing_vms=() name state
  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    state=$(vm_state "${name}")
    if [[ "${state}" == "MISSING" ]]; then
      write_error "  ${name} — MISSING (run ./cka-lab.sh up first)"
      missing_vms+=("${name}")
    else
      write_success "  ${name} — ${state}"
    fi
  done

  if (( ${#missing_vms[@]} > 0 )); then
    write_error "Aborted — ${#missing_vms[@]} VM(s) not created: ${missing_vms[*]}"
    write_info  "Nothing was snapshotted."
    exit 1
  fi

  # All VMs present — snapshot each
  local failed_vms=()
  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    write_info "Snapshotting ${name}..."
    if vagrant snapshot save "${name}" "${snap}"; then
      write_success "  ${name} — saved"
    else
      write_error "  ${name} — FAILED"
      failed_vms+=("${name}")
    fi
  done

  if (( ${#failed_vms[@]} > 0 )); then
    write_error "One or more snapshots FAILED: ${failed_vms[*]}"
    exit 1
  fi

  write_step "Done.  Restore any time with:  ./cka-lab.sh restore ${snap}"
}

# -----------------------------------------------------------------------------
cmd_restore() {
  local snap="${1:-pre-cluster}"

  write_step "Restoring all CKA VMs to snapshot '${snap}'"

  # Atomic preflight: every VM must exist AND have the named snapshot
  write_info "Pre-flight: verifying every VM has snapshot '${snap}'..."
  local missing_vms=() name state
  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    state=$(vm_state "${name}")

    if [[ "${state}" == "MISSING" ]]; then
      write_error "  ${name} — VM not found"
      missing_vms+=("${name} (VM not found)")
      continue
    fi

    if snapshot_exists "${name}" "${snap}"; then
      write_success "  ${name} — has '${snap}'"
    else
      write_error "  ${name} — snapshot '${snap}' not found"
      missing_vms+=("${name} (no snapshot '${snap}')")
    fi
  done

  if (( ${#missing_vms[@]} > 0 )); then
    write_error "Aborted — nothing was restored:"
    for m in "${missing_vms[@]}"; do write_error "  - ${m}"; done
    write_info  "Create snapshots first with:  ./cka-lab.sh save ${snap}"
    exit 1
  fi

  # All checks passed — restore each VM
  local failed_vms=()
  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    write_info "Restoring ${name}..."
    if vagrant snapshot restore "${name}" "${snap}"; then
      write_success "  ${name} — restored"
    else
      write_error "  ${name} — FAILED"
      failed_vms+=("${name}")
    fi
  done

  if (( ${#failed_vms[@]} > 0 )); then
    write_error "Restore FAILED on: ${failed_vms[*]}.  NOT starting remaining VMs."
    exit 1
  fi

  # Ensure all VMs are running (snapshot restore may leave them off if snapshot
  # was taken from a powered-off state)
  write_info "Ensuring VMs are started..."
  vagrant up
  write_step "Lab restored and running.  SSH in with:  vagrant ssh control1"
}

# -----------------------------------------------------------------------------
cmd_snapshots() {
  write_step "CKA lab — saved snapshots"
  local name
  for entry in "${CKA_NODES[@]}"; do
    name="${entry%%:*}"
    write_info "--- ${name} ---"
    vagrant snapshot list "${name}" 2>/dev/null || write_warn "  (VM not created or no snapshots)"
    print ""
  done
}

# =============================================================================
# Dispatch
# =============================================================================

cmd="${1:-status}"
shift 2>/dev/null || true

case "${cmd}" in
  up)        cmd_up "$@" ;;
  down)      cmd_down "$@" ;;
  status)    cmd_status "$@" ;;
  info)      cmd_info "$@" ;;
  validate)  cmd_validate "$@" ;;
  save)      cmd_save "$@" ;;
  restore)   cmd_restore "$@" ;;
  snapshots) cmd_snapshots "$@" ;;
  help|-h|--help) print_usage ;;
  *)
    write_error "Unknown subcommand: '${cmd}'"
    print_usage
    exit 1
    ;;
esac
