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

# ──────────────────────────────────────────────────────────────────────────────
# TOOLCHAIN STORAGE STRATEGY (XDG & Dedicated NVMe partitions)
#
# /data/projects/.pnpm-store/     → pnpm store            (NVMe 2 - same FS as projects)
# /data/projects/.uv-cache/       → uv package cache       (NVMe 2 - Btrfs zstd compression)
# ~/.local/share/uv/              → uv tools/venvs        (UV_DATA_DIR)
#
# Rationale:
#   - Cargo and Zsh configurations are managed via dotfiles (GNU Stow)
#   - pnpm store is on the same drive as projects to allow hardlinks (NVMe 2)
#   - uv cache is on the Btrfs partition to utilize disk compression
TARGET_DIR="${HOME}/projects/dotfiles"

# Locate dotfiles directory or clone if executed via curl
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo "")"
if [ -n "$SCRIPT_DIR" ] && [ -d "${SCRIPT_DIR}/playbooks" ]; then
    cd "$SCRIPT_DIR"
elif [ -d "./playbooks" ]; then
    :
else
    echo "📦 Playbooks directory not found locally. Preparing repository at $TARGET_DIR..."
    if ! command -v git &>/dev/null; then
        echo "❌ git is required. Please install git first."
        exit 1
    fi
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$(dirname "$TARGET_DIR")"
        git clone https://github.com/gidragir/dotfiles.git "$TARGET_DIR"
    fi
    cd "$TARGET_DIR"
fi

echo "🔑 Pre-authenticating sudo to allow AUR package installation..."
sudo -v

echo "📦 Installing required Ansible Galaxy collections..."
ansible-galaxy collection install kewlfft.aur

echo "📦 Running consolidated user setup playbook..."
ansible-playbook playbooks/packages.yml --tags user,aur,cargo
ansible-playbook playbooks/setup_user.yml

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ User setup complete!                                           ║"
echo "║                                                                    ║"
echo "║  TOOLCHAIN STORAGE LAYOUT:                                         ║"
echo "║  /data/projects/.pnpm-store/ → pnpm content store (optimized)     ║"
echo "║  /data/projects/.uv-cache/   → uv package cache (optimized Btrfs) ║"
echo "║  ~/.local/share/uv/          → uv tools & pythons (XDG, auto)     ║"
echo "║  ~/.config/mise/config.toml → Global mise tools configuration      ║"
echo "║  ~/.zshrc           → Managed via dotfiles (Stow)               ║"
echo "║                                                                    ║"
echo "║  NATIVE DOCKER:                                                    ║"
echo "║  Docker is installed natively and uses /var/lib/docker             ║"
echo "║  with XFS, overlay2, and prjquota enabled.                         ║"
echo "║                                                                    ║"
echo "║  SANDBOX USAGE:                                                    ║"
echo "║  niri-sandbox        → nested Wayland session for GUI tools       ║"
echo "║  sandbox-box ubuntu  → throwaway distrobox container              ║"
echo "║  sandbox-rm          → destroy the sandbox container              ║"
echo "║                                                                    ║"
echo "║  NEXT STEPS:                                                       ║"
echo "║  1. Run 'rclone config' → create remote named 'gdrive'            ║"
echo "║  2. systemctl --user start rclone-mount.service                   ║"
echo "║  3. Open a new terminal to apply shell config                     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"