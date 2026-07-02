#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root (sudo ./setup_system.sh)"
    exit 1
fi

REAL_USER=${SUDO_USER:-$(whoami)}

echo "📦 Running consolidated system setup playbook..."

# Ensure Ansible is installed
if ! command -v ansible-playbook &>/dev/null; then
    echo "   Installing Ansible first via pacman..."
    pacman -Syu --needed --noconfirm ansible
fi

ansible-playbook playbooks/setup_system.yml

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ System setup complete!                                    ║"
echo "║                                                               ║"
echo "║  IMPORTANT: Log out and back in (or reboot) to apply         ║"
echo "║  new group memberships: docker, libvirt, kvm                 ║"
echo "║                                                               ║"
echo "║  Then run: bash setup_user.sh                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"