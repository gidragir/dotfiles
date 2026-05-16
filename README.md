# 🚀 CachyOS Niri: Ultimate Developer Setup

Scripts for automatic configuration of a clean **CachyOS (Niri)** installation. Transforms a bare system into an ideal development environment for Rust, TypeScript, and Python — with Neovim terminal workflow, dotfiles via GNU Stow, Docker Desktop, and optimized dual-NVMe partitioning.

## ⚡ Quick Start

### 1. System Setup (root required)

Partitions the second NVMe drive and installs system-level dependencies.  
**The script will ask for confirmation before formatting anything.**

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/gidragir/dotfiles/main/setup_system.sh)"
```

After this, **log out and back in** (or reboot) to apply new group memberships (`docker`, `libvirt`, `kvm`).

### 2. User Setup

Configures the dev environment, shell, tools, and dotfiles. Run **as a normal user**.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gidragir/dotfiles/main/setup_user.sh)"
```

## 💽 Disk Layout (2× NVMe 1 TB)

### NVMe 0 — System (installed by CachyOS installer)

| Partition | Size | Purpose |
|-----------|------|---------|
| `/boot/efi` | 1 GB | EFI, FAT32 |
| `/` | ~100 GB | System root |
| `swap` | 8 GB | Suspend support (no hibernation needed) |
| `/home` | ~891 GB | User data, toolchains, configs |

### NVMe 1 — Data (`setup_system.sh` partitions this automatically)

| LABEL | Mount Point | Size | Purpose |
|-------|-------------|------|---------|
| `DOCKER` | `/data/docker` → `~/.docker` | ~150 GB | Docker Desktop VM image |
| `LIBVIRT` | `/var/lib/libvirt/images` | ~150 GB | QEMU/KVM virtual machine disks |
| `PROJECTS` | `/data/projects` → `~/projects` | ~220 GB | Code + Rust/sccache caches |
| `GAMES` | `/data/games` | ~450 GB | Steam game libraries |
| `SYNC` | `/data/sync` | ~30 GB | Obsidian vault, Zotero library |

All partitions use `ext4` with `noatime` to reduce unnecessary writes and extend SSD lifespan.

## 🛠 Architecture and Tools

### 1. Terminal and Shell (Zsh + Neovim workflow)

- **Vi-mode:** Full `vi` keybindings in Zsh. Text deleted via `dw`, `dd` etc. does **not** pollute the Wayland clipboard.
- **Starship Prompt:** Mode-aware prompt — `❯` (green, Insert), `[N]` (yellow, Normal), `[V]` (cyan, Visual).
- **LazyVim integration:** Press `v` in Normal mode to open the current command buffer in Neovim for advanced editing.
- **Terminals:** Ghostty and Warp — both handle Cyrillic paste natively with no extra configuration needed.

### 2. Development Stack

**Rust**
- `rustup` — toolchain management, installed to `~/.cargo` (default `CARGO_HOME`)
- `mold` — fast linker (~2–5× faster than `ld` at link step)
- `sccache` — compilation cache shared across projects, stored on NVMe 1: `/data/projects/.sccache`
- `cargo-ramdisk` — mounts `target/` into `/dev/shm` (RAM) for maximum build speed on heavy projects
- Crate registry cache redirected to `/data/projects/.cargo-cache` — keeps NVMe 0 clean

**TypeScript / JavaScript**
- `bun` — runtime and bundler
- `nodejs` — LTS via system package
- `pnpm` — managed via `corepack` (Node.js native standard), installed to `~/.local/bin`
- pnpm store at `~/.local/share/pnpm-store` (XDG-compliant, no `~/` root pollution)

**Python**
- `uv` — ultra-fast package and environment manager
- Follows XDG automatically: cache → `~/.cache/uv`, tools → `~/.local/share/uv`

**CLI Utilities**
- `zoxide` — smart `cd` with frecency ranking
- `mise` — language version management (replaces `nvm`, `pyenv`, `rbenv`)
- `television` — blazing fast fuzzy search
- `lefthook` — Git hooks manager
- `biome` — linter and formatter for JS/TS
- `turbo` — Turborepo for monorepos
- `jq`, `yq` — JSON/YAML processing

### 3. Containers and Virtualization

**Docker Desktop**
- Installed via AUR (`docker-desktop`) — ships its own Docker CLI and Compose, no conflict with system packages
- `~/.docker` is symlinked to `/data/docker` (NVMe 1, 150 GB) — VM image stays off NVMe 0
- After first launch, also set: Settings → Resources → Advanced → Disk image location → `/data/docker/desktop-vm`

**Sandbox environments**
- `niri-sandbox` alias — nested Wayland compositor session for testing bars, applets, and compositor settings. Close the window → everything gone, no cleanup needed.
- `sandbox-box <distro>` — throwaway Distrobox container for CLI tool testing (`sandbox-rm` to destroy it)

**Distrobox** — lightweight containers with full Wayland and audio passthrough, for running apps from other distributions without affecting the host.

**Libvirt / QEMU/KVM** — full virtual machines when needed (1–2 VMs). VM disk images stored on NVMe 1 at `/var/lib/libvirt/images`.

**DevOps:** `pulumi`, `helm`, `hadolint`

### 4. Synchronization (Rclone)

Two automated `systemd` user services:

- **`rclone-mount.service`** — mounts Google Drive as FUSE filesystem at `/data/gdrive` with up to 10 GB local VFS cache. Obsidian and Zotero work against **local copies** in `/data/sync`, not the mount directly.
- **`rclone-sync.timer`** — syncs `/data/sync` → `gdrive:MySyncBackup` once per hour (5 min after boot, then every hour). Logs to `~/.cache/rclone/`.

This architecture means apps never depend on network availability — syncing is a background process.

### 5. Applications and Hardware

**Applications:** Yaak (API client), Obsidian, Zotero, Ferdium, Tor Browser, Chromium, Android Studio, Neovim (LazyVim), Ghostty, Warp

**Government services (Kazakhstan):** NCALayer — ЭЦП client for egov.kz and other KZ state services. Installed automatically. Run via `~/NCALayer/ncalayer.sh --run`.

**ASUS peripherals:**
- `OpenRGB` — RGB control
- `Piper` + `ratbagd` — mouse/keyboard macro and profile configuration

### 6. Config Management (GNU Stow)

Dotfiles live in `/data/projects/dotfiles` (on NVMe 1, included in rclone backup via `~/projects` symlink).

Structure mirrors `$HOME`:

```
dotfiles/
├── zsh/
├── nvim/.config/nvim/
├── starship/.config/
├── niri/.config/niri/
├── ghostty/.config/ghostty/
└── git/
```

The setup script moves the Starship config to Stow automatically as a working example.  
To add any other app:
```bash
mv ~/.config/nvim ~/projects/dotfiles/nvim/.config/
cd ~/projects/dotfiles && stow nvim
```

## 🏁 What to do after installation

**1. Configure rclone remote**
```bash
rclone config
# Create remote: name = gdrive, type = Google Drive, authenticate in browser
```

**2. Start cloud mount**
```bash
systemctl --user start rclone-mount.service
```

**3. Restart the terminal**  
Close the current window and open a new one to apply all shell config (aliases, `zoxide`, `mise`, Starship).

**4. Configure Docker Desktop disk image location**  
Launch Docker Desktop → Settings → Resources → Advanced → Disk image location  
Set to: `/data/docker/desktop-vm`

**5. Add Obsidian and Zotero data to `/data/sync`**  
Point both apps to their respective folders inside `/data/sync/`.

## 🗂 Toolchain Storage Reference

| Tool | Binary / Toolchain | Cache / Data |
|------|--------------------|-------------|
| Rust | `~/.cargo/` (NVMe 0) | `/data/projects/.cargo-cache/` (NVMe 1) |
| sccache | — | `/data/projects/.sccache/` (NVMe 1) |
| pnpm | `~/.local/bin/` | `~/.local/share/pnpm-store/` (XDG) |
| uv | `~/.local/share/uv/` | `~/.cache/uv/` (XDG) |
| Docker Desktop | — | `/data/docker/` via `~/.docker` symlink |
| Libvirt VMs | — | `/var/lib/libvirt/images/` (NVMe 1) |