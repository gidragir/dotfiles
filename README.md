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
| `/home` | ~891 GB | User data, toolchains, configs, and games (Steam, Epic, GOG via `~/Games`) |

### NVMe 1 — Data (`setup_system.sh` partitions this automatically)

| LABEL | Mount Point | Size | Filesystem | Purpose |
|-------|-------------|------|------------|---------|
| `DOCKER` | `/var/lib/docker` | ~250 GB | `xfs` | Native Docker data root (with prjquota) |
| `LIBVIRT` | `/var/lib/libvirt/images` | ~250 GB | `ext4` | QEMU/KVM virtual machine disks |
| `PROJECTS` | `/data/projects` → `~/projects` | ~450 GB | `btrfs` | Code + Rust/sccache caches (zstd:3 compression, reflink) |
| `SYNC` | `/data/sync` | ~50 GB | `btrfs` | Obsidian vault, Zotero library (zstd:3 compression) |

> [!NOTE]
> **Unified Games Folder**: All game clients (Steam, Lutris, Heroic/Epic Games Store) should be configured to install games to `~/Games` (which is located on the large NVMe 0 drive). The system script automatically creates a symlink at `/data/games` pointing to `~/Games` to keep a clean, unified path accessible from anywhere.

The BTRFS partitions use transparent `zstd:3` compression to save space and extend SSD lifespan. All mounts include `noatime` optimization.

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
- `nodejs` — LTS managed via `mise` (configured in `~/.config/mise/config.toml`)
- `bun` — installed and managed via `mise`
- `pnpm` — managed via `corepack` (enabled via Node.js from `mise`), shims installed to `~/.local/bin`
- pnpm store at `~/.local/share/pnpm-store` (XDG-compliant, no `~/` root pollution)

**Python**
- `uv` — installed and managed via `mise`
- `Python` — versioning and project environments managed entirely via `uv` (no global installation)
- Follows XDG automatically: cache → `~/.cache/uv`, tools → `~/.local/share/uv`

**CLI & DevOps Utilities**
- `zoxide` — smart `cd` with frecency ranking
- `mise` — tool and environment version manager (configured globally via `~/.config/mise/config.toml`)
- `television` — blazing fast fuzzy search
- `ripgrep` (`rg`), `fd`, `bat`, `eza` — modern Rust replacements for standard Unix tools
- `lazygit`, `lazydocker` — terminal UI for git and docker
- `direnv` — automatic directory-specific environment loader
- `sops`, `age` — GitOps secrets management
- `kubectl`, `kubectx`, `k3d`, `argocd` — Kubernetes development suite
- `lefthook` — Git hooks manager
- `biome` — linter and formatter for JS/TS
- `turbo` — Turborepo for monorepos
- `jq`, `yq` — JSON/YAML processing

### 3. Containers and Virtualization

**Native Docker**
- Installed natively and configured on a separate `XFS` partition mounted at `/var/lib/docker` (using `overlay2` storage driver and `prjquota`).
- Fully native, avoiding Docker Desktop VM overhead.
- **Automated Configuration (Ansible)**: You can configure the Docker storage partition (formatting to XFS with `ftype=1`, mounting via UUID with `prjquota`, and configuring `daemon.json` limits) using the provided `playbook.yml`. Run it locally with:
  ```bash
  ansible-playbook -i localhost, -c local playbook.yml --ask-become-pass
  ```

**Kubernetes & Local Registry (k3d)**
- **k3d** runs k3s in lightweight docker containers.
- **Local Nexus Registry**: Fully configured via `k3d/.config/k3d/registries.yaml`. Requests to `nexus.local:8082` are routed transparently to the host via host-gateway, allowing image pulls without editing k8s deployment YAMLs.
- `k3d-create [name]` — custom Zsh function to bootstrap a local cluster mapped to your host's Nexus.
- `k8s-install-argocd` — installs and waits for ArgoCD on the active cluster.

**Sandbox environments**
- `niri-sandbox` alias — nested Wayland compositor session for testing bars, applets, and compositor settings. Close the window → everything gone, no cleanup needed.
- `sandbox-box <distro>` — throwaway Distrobox container for CLI tool testing (`sandbox-rm` to destroy it)

**Distrobox** — lightweight containers with full Wayland and audio passthrough, for running apps from other distributions without affecting the host.

**Libvirt / QEMU/KVM** — full virtual machines when needed (1–2 VMs). VM disk images stored on NVMe 1 at `/var/lib/libvirt/images`.

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

## 🖥 Windows VM (QEMU/KVM) Setup

To deploy a Windows 11 VM with UEFI, Secure Boot, TPM 2.0, and VirtIO drivers (disk/network performance):

### 1. Download VirtIO Drivers
Fedora provides signed VirtIO drivers required by Windows to detect the virtio disk and network interface during setup:
```bash
sudo wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso \
  -O /var/lib/libvirt/images/virtio-win.iso
```

### 2. Copy the Windows 11 ISO to VM Storage
Place your Windows ISO into the allocated `/var/lib/libvirt/images` directory:
```bash
sudo cp /path/to/windows11.iso /var/lib/libvirt/images/win11.iso
```

### 3. Create the VM via CLI
Run the following command to bootstrap the VM:
```bash
sudo virt-install \
  --name win11 \
  --ram 8192 \
  --vcpus 4 \
  --cpu host-passthrough \
  --os-variant win11 \
  --disk path=/var/lib/libvirt/images/win11.qcow2,size=100,bus=virtio,format=qcow2,sparse=true \
  --disk path=/var/lib/libvirt/images/win11.iso,device=cdrom \
  --disk path=/var/lib/libvirt/images/virtio-win.iso,device=cdrom \
  --network network=default,model=virtio \
  --boot uefi,firmware.feature.name=secure-boot \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
  --graphics spice,listen=127.0.0.1 \
  --video qxl \
  --channel spicevmc \
  --noautoconsole
```

### 4. Install and configure
1. Open **`virt-manager`** from your launcher.
2. Open the `win11` console and start the VM.
3. When Windows asks "Where do you want to install Windows?" and shows no disks, click **Load driver** -> **Browse** -> Select the `virtio-win` CD-ROM drive -> `amd64` -> `w11` to load the SCSI controller driver.
4. After Windows boots, open the VirtIO CD-ROM drive in Windows Explorer and run `virtio-win-gt-x64.msi` to install all missing guest tools (network, display, clipboard sharing).

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
Close the current window and open a new one to apply all shell config (aliases, `zoxide`, `mise`, Starship, `k8s`).

**4. Add Obsidian and Zotero data to `/data/sync`**  
Point both apps to their respective folders inside `/data/sync/`.

## 🗂 Toolchain Storage Reference

| Tool | Binary / Toolchain | Cache / Data |
|------|--------------------|-------------|
| Rust | `~/.cargo/` (NVMe 0) | `/data/projects/.cargo-cache/` (NVMe 1) |
| sccache | — | `/data/projects/.sccache/` (NVMe 1) |
| pnpm | `~/.local/bin/` | `~/.local/share/pnpm-store/` (XDG) |
| uv | `~/.local/share/uv/` | `~/.cache/uv/` (XDG) |
| Native Docker | — | `/var/lib/docker/` (XFS, NVMe 1) |
| Libvirt VMs | — | `/var/lib/libvirt/images/` (NVMe 1) |