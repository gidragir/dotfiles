#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "❌ This script MUST NOT be run as root. Run it as a normal user."
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# TOOLCHAIN STORAGE STRATEGY (XDG-based, nothing pollutes ~/ root)
#
# ~/.local/share/pnpm/            → pnpm store            (XDG_DATA_HOME)
# ~/.cache/uv/                    → uv package cache       (XDG_CACHE_HOME/uv)
# ~/.local/share/uv/              → uv tools/venvs        (UV_DATA_DIR)
#
# Rationale:
#   - Cargo and Zsh configurations are managed via dotfiles (GNU Stow)
#   - pnpm store uses XDG_DATA_HOME — no dotfiles in ~ root
#   - uv follows XDG by default, no config needed
# ──────────────────────────────────────────────────────────────────────────────

echo "📦 Running consolidated user setup playbook..."
ansible-playbook playbooks/setup_user.yml

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ User setup complete!                                           ║"
echo "║                                                                    ║"
echo "║  TOOLCHAIN STORAGE LAYOUT:                                         ║"
echo "║  ~/.local/share/pnpm-store/  → pnpm content store (XDG)          ║"
echo "║  ~/.cache/uv/       → uv package cache (XDG, auto)               ║"
echo "║  ~/.local/share/uv/ → uv tools & pythons (XDG, auto)             ║"
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