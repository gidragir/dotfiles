#!/bin/bash
set -e

if [ "$EUID" -eq 0 ]; then
    echo "❌ This script MUST NOT be run as root. Run it as a normal user."
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# TOOLCHAIN STORAGE STRATEGY (XDG-based, nothing pollutes ~/ root)
#
# ~/.cargo/           → Rust toolchain, binaries  (CARGO_HOME)
# /data/projects/.cargo-registry/ → cargo package cache  (separate from toolchain)
# /data/projects/.sccache/        → compilation cache
# ~/.local/share/pnpm/            → pnpm store            (XDG_DATA_HOME)
# ~/.cache/uv/                    → uv package cache       (XDG_CACHE_HOME/uv)
# ~/.local/share/uv/              → uv tools/venvs        (UV_DATA_DIR)
#
# Rationale:
#   - Toolchains (cargo, rustup) stay in ~ because rustup expects CARGO_HOME
#   - Large caches (cargo registry, sccache) → /data/projects to save NVMe 0
#   - pnpm store uses XDG_DATA_HOME — no dotfiles in ~ root
#   - uv follows XDG by default, no config needed
# ──────────────────────────────────────────────────────────────────────────────

echo "📦 1. Installing utilities and applications (via paru)..."
paru -S --needed --noconfirm \
    rustup \
    bun \
    uv \
    mise \
    zoxide \
    television \
    neovim \
    lefthook \
    biome \
    turbo-bin \
    yaak-app-bin \
    obsidian \
    zotero-bin \
    ferdium-bin \
    tor-browser-bin \
    starship \
    openrgb \
    piper \
    libratbag \
    hadolint \
    helm \
    jq \
    yq \
    chromium \
    android-studio \
    stow \
    git \
    ghostty \
    warp-terminal \
    docker-desktop   # AUR: ships its own docker CLI + compose, no conflict with engine packages

# ──────────────────────────────────────────────────────────────────────────────
# Docker Desktop storage → /data/docker
#
# Docker Desktop stores its VM disk image in ~/.docker/desktop/
# We symlink ~/.docker → /data/docker so the VM image lives on NVMe 1.
#
# IMPORTANT: Do this BEFORE first launch of Docker Desktop.
# After first launch, also change the disk image location in:
#   Docker Desktop → Settings → Resources → Advanced → Disk image location
#   Set it to: /data/docker/desktop-vm
# ──────────────────────────────────────────────────────────────────────────────
echo "🐋 1.1. Redirecting Docker Desktop storage to NVMe 1..."
# If ~/.docker already exists and is NOT a symlink, back it up
if [ -d "$HOME/.docker" ] && [ ! -L "$HOME/.docker" ]; then
    echo "   Backing up existing ~/.docker to /data/docker-backup..."
    mv "$HOME/.docker" /data/docker-backup
fi
mkdir -p /data/docker
ln -sfn /data/docker "$HOME/.docker"
echo "   ~/.docker → /data/docker (NVMe 1)"

# Enable Docker Desktop to autostart
systemctl --user enable --now docker-desktop

# ──────────────────────────────────────────────────────────────────────────────
# 2. LazyVim
# ──────────────────────────────────────────────────────────────────────────────
echo "📦 2. Configuring LazyVim..."
if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
else
    echo "   ~/.config/nvim already exists, skipping."
fi

# ──────────────────────────────────────────────────────────────────────────────
# 3. Rust (rustup + cargo)
# ──────────────────────────────────────────────────────────────────────────────
echo "🦀 3. Configuring Rust..."
# Source cargo env in case rustup was just installed
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

if ! command -v cargo &>/dev/null; then
    rustup default stable
    source "$HOME/.cargo/env"
fi

cargo install cargo-ramdisk

# ~/.cargo/config.toml — mold linker + sccache + redirect registry cache
mkdir -p "$HOME/.cargo"
cat > "$HOME/.cargo/config.toml" << 'EOF'
# ── Build optimizations ──────────────────────────────────────────────────────
[build]
# sccache caches compiled artifacts between projects (huge speedup on rebuild)
rustc-wrapper = "sccache"

[target.x86_64-unknown-linux-gnu]
# mold is ~2–5× faster than ld at the link step
linker = "clang"
rustflags = ["-C", "link-arg=-fuse-ld=mold"]

# ── Redirect large caches off NVMe 0 (/home) → /data/projects ───────────────
# cargo registry = downloaded source tarballs of crates (~can grow to 5–15 GB)
# cargo git = git-based crate checkouts
[env]
CARGO_HOME         = { value = "/data/projects/.cargo-cache", force = false }
EOF

# Note: CARGO_HOME in env table only sets it for cargo subprocesses.
# For the toolchain itself (rustup/cargo binary), CARGO_HOME must be in shell env.
# We handle that in .zshrc below.

# ──────────────────────────────────────────────────────────────────────────────
# 4. Create cache directories on /data/projects
# ──────────────────────────────────────────────────────────────────────────────
echo "📁 4. Creating cache directories on NVMe 1..."
mkdir -p /data/projects/.sccache
mkdir -p /data/projects/.cargo-cache/{registry,git}

# Projects symlink
ln -sfn /data/projects ~/projects

# ──────────────────────────────────────────────────────────────────────────────
# 5. pnpm via corepack
# corepack is the Node.js-native way to manage package managers.
# pnpm store → XDG_DATA_HOME/pnpm (no ~/. pollution)
# ──────────────────────────────────────────────────────────────────────────────
echo "📦 5. Configuring pnpm via corepack..."
mkdir -p "$HOME/.local/bin"
# Enable corepack and install pnpm shim into ~/.local/bin
corepack enable --install-directory "$HOME/.local/bin" pnpm

# Set pnpm store to XDG-compliant location (inside ~/.local/share — stays on NVMe 0,
# but is inside XDG hierarchy, not ~/. root clutter)
mkdir -p "$HOME/.local/share/pnpm-store"
# This will be picked up by pnpm automatically via PNPM_HOME env var (set in .zshrc)

# ──────────────────────────────────────────────────────────────────────────────
# 6. uv (Python) — follows XDG by default, no extra config needed
#    Cache  → ~/.cache/uv
#    Data   → ~/.local/share/uv  (tools, managed pythons)
#    Config → ~/.config/uv
# ──────────────────────────────────────────────────────────────────────────────
echo "🐍 6. uv is XDG-compliant by default, no extra config needed."
# Optionally redirect uv cache to NVMe 1 if it grows large:
# export UV_CACHE_DIR=/data/projects/.uv-cache  (add to .zshrc if needed)

# ──────────────────────────────────────────────────────────────────────────────
# 7. Shell environment (.zshrc)
# ──────────────────────────────────────────────────────────────────────────────
echo "🌠 7. Configuring Zsh environment..."
ZSHRC="$HOME/.zshrc"

if [ ! -f "$ZSHRC" ]; then
    echo "⚠️  ~/.zshrc not found — creating a minimal one."
    touch "$ZSHRC"
fi

# Disable OMZ/p10k themes if present (we use starship for prompt)
sed -i 's/^ZSH_THEME=.*/ZSH_THEME=""/g' "$ZSHRC" 2>/dev/null || true
sed -i 's/^source.*powerlevel10k.zsh-theme/#&/g' "$ZSHRC" 2>/dev/null || true
sed -i 's/^\[\[ ! -f ~\/.p10k.zsh \]\]/#&/g' "$ZSHRC" 2>/dev/null || true
sed -i 's/^source ~\/.p10k.zsh/#&/g' "$ZSHRC" 2>/dev/null || true

# Append dev environment block (idempotent — only once)
if ! grep -q "# ── DEV ENVIRONMENT" "$ZSHRC"; then
    cat >> "$ZSHRC" << 'ZSHBLOCK'

# ── DEV ENVIRONMENT (added by setup_user.sh) ─────────────────────────────────

# XDG base dirs (explicit, prevents apps from writing to ~/.)
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# PATH
export PATH="$HOME/.local/bin:$PATH"

# ── Rust / Cargo ─────────────────────────────────────────────────────────────
# Toolchain (rustup, cargo binary) stays in ~/.cargo (default CARGO_HOME)
# Registry/git caches are redirected to NVMe 1 via ~/.cargo/config.toml [env]
export SCCACHE_DIR="/data/projects/.sccache"

# ── Node / pnpm ──────────────────────────────────────────────────────────────
# PNPM_HOME: where pnpm stores its global bins and content-addressable store
export PNPM_HOME="$HOME/.local/share/pnpm-store"
export PATH="$PNPM_HOME:$PATH"

# ── Python / uv ──────────────────────────────────────────────────────────────
# uv follows XDG automatically:
#   cache  → ~/.cache/uv
#   data   → ~/.local/share/uv
# Uncomment below to redirect uv cache to NVMe 1 if it grows large:
# export UV_CACHE_DIR="/data/projects/.uv-cache"

# ── Editors ──────────────────────────────────────────────────────────────────
export EDITOR='nvim'
export VISUAL='nvim'

# ── Vi-mode (Neovim muscle memory in terminal) ────────────────────────────────
bindkey -v

# Open command buffer in LazyVim with 'v' in Normal mode (after Esc)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# ── Paste fix ────────────────────────────────────────────────────────────────
# Ghostty and Warp handle bracketed paste correctly natively.
# The 'unset zle_bracketed_paste' fix was for Alacritty only — NOT needed here.
# OMZ safe-paste plugin keeps bracketed paste working safely:
# (add 'safe-paste' to plugins=() array in your OMZ config if desired)

# ── Sandbox: test Wayland GUI tools without polluting main session ─────────────
# Usage: niri-sandbox
#   - Starts a nested Niri compositor in a new window
#   - Install/test any bar, applet, or compositor setting inside it
#   - Close the window → everything is gone, no cleanup needed
alias niri-sandbox='WAYLAND_DISPLAY=wayland-sandbox niri --session'

# Distrobox: quickly spin up a throwaway container for CLI tool testing
# Usage: sandbox-box ubuntu  OR  sandbox-box archlinux
# After testing: distrobox rm sandbox (removes container + all installed packages)
sandbox-box() {
    local image="${1:-archlinux}"
    distrobox create --name sandbox --image "$image" --yes 2>/dev/null || true
    distrobox enter sandbox
}
alias sandbox-rm='distrobox rm sandbox --yes'

# ── Tool initializations (at end to avoid overriding above) ──────────────────
eval "$(mise activate zsh)"
eval "$(zoxide init zsh)"

# Starship prompt (must be last)
eval "$(starship init zsh)"

# ─────────────────────────────────────────────────────────────────────────────
ZSHBLOCK
fi

# Load cargo env for current session
[ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"

# ──────────────────────────────────────────────────────────────────────────────
# 8. Starship config (Vi-mode indicators)
# ──────────────────────────────────────────────────────────────────────────────
echo "🌠 8. Writing Starship config..."
mkdir -p "$HOME/.config"
# Only write if not already managed by Stow
if [ ! -L "$HOME/.config/starship.toml" ] && [ ! -f "$HOME/.config/starship.toml" ]; then
    cat > "$HOME/.config/starship.toml" << 'EOF'
[character]
success_symbol      = "[❯](bold green)"
error_symbol        = "[❯](bold red)"
vimcmd_symbol       = "[N](bold yellow)"
vimcmd_replace_one_symbol = "[R](bold purple)"
vimcmd_replace_symbol     = "[R](bold purple)"
vimcmd_visual_symbol      = "[V](bold cyan)"
EOF
fi

# ──────────────────────────────────────────────────────────────────────────────
# 9. rclone systemd units
# ──────────────────────────────────────────────────────────────────────────────
echo "☁️  9. Configuring rclone systemd units..."
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
systemctl --user enable rclone-mount.service
systemctl --user enable rclone-sync.timer

# ──────────────────────────────────────────────────────────────────────────────
# 10. ratbagd (mouse daemon) — requires root, must run as system service
# ──────────────────────────────────────────────────────────────────────────────
echo "🖱️  10. Enabling ratbagd (mouse daemon)..."
sudo systemctl enable --now ratbagd

# ──────────────────────────────────────────────────────────────────────────────
# 11. Dotfiles structure (GNU Stow)
# ──────────────────────────────────────────────────────────────────────────────
echo "🗃️  11. Preparing dotfiles structure (GNU Stow)..."
DOTFILES="/data/projects/dotfiles"
mkdir -p "$DOTFILES"/{zsh,nvim/.config/nvim,starship/.config,niri/.config/niri,ghostty/.config/ghostty,git}

if [ ! -d "$DOTFILES/.git" ]; then
    git -C "$DOTFILES" init
    echo ".DS_Store" > "$DOTFILES/.gitignore"
    echo "   Initialized Git in $DOTFILES"
fi

# Move Starship config into Stow and symlink back
if [ -f "$HOME/.config/starship.toml" ] && [ ! -L "$HOME/.config/starship.toml" ]; then
    mv "$HOME/.config/starship.toml" "$DOTFILES/starship/.config/"
    stow -d "$DOTFILES" -t "$HOME" starship
    echo "   🔗 Starship config → Stow"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ User setup complete!                                           ║"
echo "║                                                                    ║"
echo "║  TOOLCHAIN STORAGE LAYOUT:                                         ║"
echo "║  ~/.cargo/          → Rust toolchain (binaries, rustup)           ║"
echo "║  /data/projects/                                                   ║"
echo "║    .cargo-cache/    → crate registry & git cache (large)          ║"
echo "║    .sccache/        → compilation cache (sccache)                 ║"
echo "║  ~/.local/share/pnpm-store/  → pnpm content store (XDG)          ║"
echo "║  ~/.cache/uv/       → uv package cache (XDG, auto)               ║"
echo "║  ~/.local/share/uv/ → uv tools & pythons (XDG, auto)             ║"
echo "║  ~/.docker → /data/docker   → Docker Desktop VM image (NVMe 1)   ║"
echo "║                                                                    ║"
echo "║  DOCKER DESKTOP:                                                   ║"
echo "║  After first launch, go to:                                        ║"
echo "║  Settings → Resources → Advanced → Disk image location            ║"
echo "║  Set to: /data/docker/desktop-vm                                  ║"
echo "║  (moves the VM qcow2 image explicitly to NVMe 1)                  ║"
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
echo "║  4. Launch Docker Desktop and configure disk image location       ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"