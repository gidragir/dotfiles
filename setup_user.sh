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

echo "📦 1. Installing utilities and applications (via paru)..."
# --needed prevents reinstalling packages that are already up to date
paru -S --needed --noconfirm \
    vivaldi \
    visual-studio-code-bin \
    rustup \
    mise \
    zoxide \
    television \
    neovim \
    lefthook \
    biome \
    turbo \
    obsidian \
    ferdium-bin \
    tor-browser-bin \
    starship \
    openrgb \
    piper \
    libratbag \
    helm \
    jq \
    yq \
    chromium \
    android-studio \
    stow \
    git \
    ghostty \
    warp-terminal \
    superfile \
    zellij \
    ripgrep \
    fd \
    bat \
    eza \
    lazygit \
    lazydocker \
    kubectl \
    kubectx \
    k3d \
    k9s \
    sops \
    age \
    argocd \
    rofi

# ──────────────────────────────────────────────────────────────────────────────
# 2. Projects symlink & GNU Stow (Dotfiles)
# ──────────────────────────────────────────────────────────────────────────────
echo "📁 2. Configuring Projects symlink & GNU Stow..."
ln -sfn /data/projects ~/projects

DOTFILES="/data/projects/dotfiles"
if [ ! -d "$DOTFILES" ]; then
    echo "   Cloning dotfiles repository to $DOTFILES..."
    git clone https://github.com/gidragir/dotfiles.git "$DOTFILES"
fi

cd "$DOTFILES"

# Ensure target parent directories exist
mkdir -p "$HOME/.cargo" "$HOME/.config"

# Clean up existing configurations to prevent stow conflicts
echo "   Removing existing configurations to avoid stow conflicts..."
rm -f "$HOME/.zshrc"
rm -f "$HOME/.cargo/config.toml"

for dir in */; do
    pkg="${dir%/}"
    if [ "$pkg" != "zsh" ] && [ "$pkg" != "cargo" ]; then
        rm -rf "$HOME/.config/$pkg"
        rm -f "$HOME/.config/${pkg}.toml"
    fi
done

# Stow all configurations
stow -t "$HOME" */
echo "   🔗 All configurations stowed successfully!"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Rust & Cargo (Optimized Layout)
# ──────────────────────────────────────────────────────────────────────────────
echo "🦀 3. Configuring Rust & Cargo Storage..."

# 3.1. Create base directories for caches on NVMe 1
mkdir -p "$HOME/.cargo"
mkdir -p /data/projects/.cargo-cache/{registry,git}
mkdir -p /data/projects/.sccache

# 3.2. Create symlinks BEFORE installing anything via Cargo
echo "   Linking Cargo caches to NVMe 1..."
for dir in registry git; do
    if [ -d "$HOME/.cargo/$dir" ] && [ ! -L "$HOME/.cargo/$dir" ]; then
        echo "   Moving existing $dir to NVMe 1..."
        cp -a "$HOME/.cargo/$dir/." "/data/projects/.cargo-cache/$dir/" 2>/dev/null || true
        rm -rf "$HOME/.cargo/$dir"
    fi
    ln -sfn "/data/projects/.cargo-cache/$dir" "$HOME/.cargo/$dir"
done

# 3.3. Install/Configure Rust toolchain
if ! command -v rustup &>/dev/null; then
    rustup default stable
fi

# Source cargo env safely for the current script session
if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi

# 3.4. Idempotent installation of cargo utilities
if ! command -v cargo-ramdisk &>/dev/null; then
    cargo install cargo-ramdisk
else
    echo "   cargo-ramdisk already installed, skipping."
fi

echo "   Installing cargo DX utilities..."
for tool in cargo-nextest bacon cargo-machete; do
    if ! command -v "$tool" &>/dev/null; then
        cargo install "$tool"
    else
        echo "   $tool already installed, skipping."
    fi
done

# ──────────────────────────────────────────────────────────────────────────────
# 4. Dev Tools via mise & pnpm
# ──────────────────────────────────────────────────────────────────────────────
echo "🛠️  4. Installing Dev Tools via mise..."
# mise install will read ~/.config/mise/config.toml stowed from dotfiles
mise install

echo "📦 Configuring pnpm via corepack..."
mkdir -p "$HOME/.local/bin"
# Run corepack enable for pnpm using the node version installed by mise
mise exec node -- corepack enable --install-directory "$HOME/.local/bin" pnpm

# Set pnpm store to XDG-compliant location
mkdir -p "$HOME/.local/share/pnpm-store"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Python & uv
# ──────────────────────────────────────────────────────────────────────────────
echo "🐍 5. Python is managed entirely via uv (installed by mise)."
echo "   uv is XDG-compliant, no extra config needed."

# ──────────────────────────────────────────────────────────────────────────────
# 6. rclone systemd units
# ──────────────────────────────────────────────────────────────────────────────
echo "☁️  6. Configuring rclone systemd units..."
SYSTEMD_USER="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER"

cat > "$SYSTEMD_USER/rclone-mount.service" << 'EOF'
[Unit]
Description=Rclone – Mount Google Drive
After=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount gdrive: /data/gdrive \
    --vfs-cache-mode full \
    --dir-cache-time 72h \
    --vfs-cache-max-size 10G \
    --log-level INFO \
    --log-file=%h/.cache/rclone/gdrive-mount.log
ExecStop=/bin/fusermount -u /data/gdrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

cat > "$SYSTEMD_USER/rclone-sync.service" << 'EOF'
[Unit]
Description=Rclone – Sync /data/sync → Google Drive

[Service]
Type=oneshot
ExecStart=/usr/bin/rclone sync /data/sync gdrive:MySyncBackup \
    --fast-list \
    --log-level INFO \
    --log-file=%h/.cache/rclone/sync.log
EOF

cat > "$SYSTEMD_USER/rclone-sync.timer" << 'EOF'
[Unit]
Description=Run rclone sync every hour

[Timer]
OnBootSec=5m
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
EOF

mkdir -p "$HOME/.cache/rclone"

systemctl --user daemon-reload
systemctl --user enable rclone-mount.service 2>/dev/null || true
systemctl --user enable rclone-sync.timer 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# 7. ratbagd (mouse daemon)
# ──────────────────────────────────────────────────────────────────────────────
echo "🖱️  7. Enabling ratbagd (mouse daemon)..."
if ! systemctl is-enabled ratbagd &>/dev/null; then
    sudo systemctl enable --now ratbagd
else
    echo "   ratbagd is already enabled."
fi

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