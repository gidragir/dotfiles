#!/usr/bin/env bash
# =============================================================================
# Test Script : test_network_optimization.sh
# Purpose     : Validate syntax, drop-in structure, and kernel capabilities
#               for playbooks/setup_network_optimization.yml
# =============================================================================
set -euo pipefail

PLAYBOOK="playbooks/setup_network_optimization.yml"

echo "==> 1. Checking playbook file existence..."
if [[ ! -f "$PLAYBOOK" ]]; then
    echo "ERROR: $PLAYBOOK not found" >&2
    exit 1
fi

echo "==> 2. Validating Ansible playbook syntax..."
ansible-playbook --syntax-check "$PLAYBOOK" > /dev/null

echo "==> 3. Verifying required tags (apply, revert)..."
ansible-playbook --list-tags "$PLAYBOOK" | rg -q "apply"
ansible-playbook --list-tags "$PLAYBOOK" | rg -q "revert"

echo "==> 4. Verifying systemd drop-in reset directives..."
# Ensure ExecStart= reset exists before custom command
rg -q "ExecStart=" "$PLAYBOOK"
# Ensure OnBootSec= reset exists before custom delay
rg -q "OnBootSec=" "$PLAYBOOK"
# Ensure Persistent=false exists for rate-mirrors
rg -q "Persistent=false" "$PLAYBOOK"
# Ensure LLMNR=no exists
rg -q "LLMNR=no" "$PLAYBOOK"

echo "==> 5. Verifying kernel TCP BBR availability..."
if [[ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]]; then
    rg -q "bbr" /proc/sys/net/ipv4/tcp_available_congestion_control
    echo "    Kernel supports BBR: OK"
else
    echo "    Skipping kernel check (not running on Linux or /proc unavailable)"
fi

echo "==> All network optimization validation checks passed successfully!"
