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

if [ "$EUID" -eq 0 ]; then
    echo "❌ This script MUST NOT be run as root. Run it as a normal user."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -d "${SCRIPT_DIR}/playbooks" ]; then
    cd "$SCRIPT_DIR"
fi

echo "🔑 Ensuring sudo permissions for pacman and installing dependencies..."
REAL_USER=$(whoami)
sudo sh -c "echo '${REAL_USER} ALL=(ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/10-${REAL_USER}-pacman && chmod 0440 /etc/sudoers.d/10-${REAL_USER}-pacman"

echo "📦 Installing official dependencies via pacman..."
sudo pacman -S --needed --noconfirm mpv libsixel libxpresent mujs

echo "📦 Running Wallpaper Engine setup playbook..."
ansible-playbook playbooks/setup_wallpaper_engine.yml
