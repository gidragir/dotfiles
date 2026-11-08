#!/usr/bin/env bash
set -euo pipefail

error_handler() {
    local exit_code=$1
    local line_no=$2
    echo "" >&2
    echo "❌ Error occurred in script at line $line_no (exit code: $exit_code)" >&2
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
#   - Toolchains and configs are declaratively managed via Yggdrasil
#   - pnpm store is on the same drive as projects to allow hardlinks (NVMe 2)
#   - uv cache is on the Btrfs partition to utilize disk compression

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd 2>/dev/null || echo "")"
if [ -z "$REPO_ROOT" ] || [ ! -f "${REPO_ROOT}/ygg.toml" ]; then
    TARGET_DIR="${HOME}/projects/dotfiles"
    if [ ! -d "$TARGET_DIR" ]; then
        echo "📦 Cloning dotfiles repository to $TARGET_DIR..."
        mkdir -p "$(dirname "$TARGET_DIR")"
        git clone https://github.com/gidragir/dotfiles.git "$TARGET_DIR"
    fi
    REPO_ROOT="$TARGET_DIR"
fi
cd "$REPO_ROOT"

# 1. Detect host chassis & configure ygg scope
HOST_CHASSIS="$(hostnamectl chassis 2>/dev/null || echo "desktop")"
case "$HOST_CHASSIS" in
    laptop|notebook|convertible) SCOPE="asus" ;;
    *) SCOPE="pc" ;;
esac
echo "🖥️  Host profile detected: $HOST_CHASSIS (ygg scope: $SCOPE)"

# 2. Ensure Yggdrasil engine is installed
if ! command -v ygg &>/dev/null; then
    if [ -x "$HOME/.local/bin/ygg" ]; then
        export PATH="$HOME/.local/bin:$PATH"
    elif [ -x "/data/projects/ygg/bin/ygg" ]; then
        mkdir -p "$HOME/.local/bin"
        ln -sf "/data/projects/ygg/bin/ygg" "$HOME/.local/bin/ygg"
        export PATH="$HOME/.local/bin:$PATH"
    else
        echo "📦 Installing Yggdrasil engine..."
        curl -fsSL https://raw.githubusercontent.com/gidragir/ygg/main/scripts/install.sh | bash
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

# 3. Ensure dotfiles module is linked in ~/.ygg/modules
YGG_DIR="${HOME}/.ygg"
mkdir -p "${YGG_DIR}/modules"
if [ ! -e "${YGG_DIR}/modules/dotfiles" ]; then
    ln -sfn "$REPO_ROOT" "${YGG_DIR}/modules/dotfiles"
fi

# 4. Pre-authenticate sudo for package installations
echo "🔑 Pre-authenticating sudo for package management..."
sudo -v

# 5. Apply dotfiles, links, packages, and setup hooks via Yggdrasil
echo "🌳 Applying configurations and packages via Yggdrasil..."
ygg apply

# 6. Supplementary Ansible tasks if available (system daemons like ratbagd)
if command -v ansible-playbook &>/dev/null && [ -f "${REPO_ROOT}/playbooks/setup_user.yml" ]; then
    echo "📦 Running supplementary user services..."
    ansible-playbook "${REPO_ROOT}/playbooks/setup_user.yml" --tags ratbagd,audio -e "host_profile=${HOST_CHASSIS}" || true
fi

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
echo "║  ~/.zshrc           → Managed via dotfiles (Yggdrasil)          ║"
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
echo "║  2. systemctl --user start rclone-obsidian-sync.timer              ║"
echo "║  3. Run health check: bash scripts/check_setup.sh                 ║"
echo "║  4. Open a new terminal to apply shell config                     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
