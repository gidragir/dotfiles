#!/usr/bin/env bash
set -euo pipefail

error_handler() {
    local exit_code=$1
    local line_no=$2
    echo "" >&2
    echo "❌ Error occurred in script at line $line_no (exit code: $exit_code)" >&2
    echo "   Ansible playbook execution failed. Please check the output above." >&2
}
trap 'error_handler $? $LINENO' ERR

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root (sudo ./setup_system.sh)"
    exit 1
fi

REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
TARGET_DIR="${REAL_HOME:-$HOME}/projects/dotfiles"

# Locate dotfiles directory or clone if executed via curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -d "${SCRIPT_DIR}/playbooks" ]; then
    cd "$SCRIPT_DIR"
elif [ -d "./playbooks" ]; then
    :
else
    echo "📦 Playbooks directory not found locally. Preparing repository at $TARGET_DIR..."
    if ! command -v git &>/dev/null; then
        echo "   Installing git via pacman..."
        pacman -Syu --needed --noconfirm git
    fi
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$(dirname "$TARGET_DIR")"
        git clone https://github.com/gidragir/dotfiles.git "$TARGET_DIR"
        chown -R "$REAL_USER:$REAL_USER" "$TARGET_DIR"
    fi
    cd "$TARGET_DIR"
fi

echo "📦 Running consolidated system setup playbook..."

# Ensure Ansible is installed
if ! command -v ansible-playbook &>/dev/null; then
    echo "   Installing Ansible first via pacman..."
    pacman -Syu --needed --noconfirm ansible
fi

ansible-playbook playbooks/packages.yml --tags system
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