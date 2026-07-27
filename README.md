# 🚀 CachyOS Niri: Ultimate Developer Setup

Scripts and Ansible playbooks for automatic configuration of a clean **CachyOS (Niri)** installation. Transforms a bare system into an ideal development environment for Rust, TypeScript, and Python — with Neovim/Zsh workflow, dotfiles via GNU Stow, native Docker, QEMU/KVM virtualization, and optimized dual-NVMe partitioning.

## ⚡ Quick Start

### 1. System Setup (root required)

Partitions the target NVMe drive, installs system-level packages via Pacman, configures mounts, and sets up Docker & libvirt services.  
**The script will ask for confirmation before formatting anything.**

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/gidragir/dotfiles/main/setup_system.sh)"
```

After completion, **log out and back in** (or reboot) to apply new group memberships (`docker`, `libvirt`, `kvm`).

### 2. User Setup

Configures the dev environment, shell, tools via [mise](https://mise.jdx.sh/), AUR packages via `paru`, Cargo tools, dotfiles via Stow, and background sync services. Run **as a normal user**.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gidragir/dotfiles/main/setup_user.sh)"
```

### 3. Dedicated Playbooks

You can run individual Ansible playbooks anytime for specific components:

- **Gaming & Steam Setup:**
  ```bash
  ansible-playbook -K playbooks/setup_gaming.yml
  # Optional GPU switch to NVIDIA during setup:
  ansible-playbook -K playbooks/setup_gaming.yml -e "switch_gpu_to_nvidia=true"
  ```
- **KVM/QEMU Virtualization Setup:**
  ```bash
  ansible-playbook -K playbooks/setup_virt.yml
  ```
- **Package Maintenance:**
  ```bash
  # Install/update system-level packages:
  ansible-playbook playbooks/packages.yml --tags system
  # Install/update user pacman, AUR, and cargo packages:
  ansible-playbook playbooks/packages.yml --tags user,aur,cargo
  ```

---

## 💽 Disk Layout (2× NVMe 1 TB)

### NVMe 0 — System (installed by CachyOS installer)

| Partition | Size | Purpose |
|-----------|------|---------|
| `/boot/efi` | 1 GB | EFI, FAT32 |
| `/` | ~100 GB | System root |
| `swap` | 8 GB | Suspend support |
| `/home` | ~891 GB | User data, toolchains, configs, and games (`~/Games`) |

### NVMe 1 — Data (`setup_system.sh` / `setup_system.yml` partitions this automatically)

| LABEL | Mount Point | Size | Filesystem | Mount Options | Purpose |
|-------|-------------|------|------------|---------------|---------|
| `DOCKER` | `/var/lib/docker` | ~250 GB (0–25%) | `xfs` | `defaults,noatime,pquota` | Native Docker data root (with prjquota) |
| `LIBVIRT` | `/var/lib/libvirt/images` | ~250 GB (25–50%) | `ext4` | `defaults,noatime` | QEMU/KVM virtual machine disk images |
| `PROJECTS` | `/data/projects` → `~/projects` | ~450 GB (50–95%) | `btrfs` | `defaults,noatime,compress=zstd:3,discard=async` | Code + pnpm store, uv cache, cargo cache & sccache |
| `SYNC` | `/data/sync` | ~50 GB (95–100%) | `btrfs` | `defaults,noatime,compress=zstd:3,discard=async` | Obsidian vault, Zotero library |

> [!NOTE]
> **Unified Games Folder**: All game clients (Steam, Lutris, Heroic/Epic Games Store) are configured to install games to `~/Games` (located on the large NVMe 0 drive). The system script automatically creates a symlink at `/data/games` pointing to `~/Games` for a clean, unified path.

---

## 🛠 Architecture and Tools

### 1. Terminal and Shell (Zsh + Neovim workflow)

- **Vi-mode:** Full `vi` keybindings in Zsh. Text deleted via `dw`, `dd` etc. does **not** pollute the Wayland clipboard (`cliphist` / `wtype` integration).
- **Starship Prompt:** Mode-aware prompt — `❯` (green, Insert), `[N]` (yellow, Normal), `[V]` (cyan, Visual).
- **LazyVim integration:** Press `v` in Normal mode to open the current command buffer in Neovim for advanced editing.
- **Terminals:** Ghostty and Warp — both handle Cyrillic paste natively with no extra configuration needed.
- **Multiplexer & File Manager:** `zellij` terminal multiplexer, `superfile` terminal file manager, `carapace-bin` for shell autocompletions.

### 2. Development Stack

**Rust**
- `rustup` — toolchain management (default `stable`), installed to `~/.cargo`
- `mold` — fast linker (~2–5× faster than `ld` at link step)
- `sccache` — compilation cache shared across projects, stored on NVMe 1: `/data/projects/.sccache`
- `cargo-ramdisk` — mounts `target/` into `/dev/shm` (RAM) for maximum build speed on heavy projects
- `cargo` utilities: `cargo-nextest`, `bacon`, `cargo-machete` installed via `cargo-binstall`
- Crate registry & git caches redirected to `/data/projects/.cargo-cache/` (`registry` and `git`)

**TypeScript / JavaScript**
- `nodejs` — LTS managed via `mise` (configured in `~/.config/mise/config.toml`)
- `bun` — installed and managed via `mise`
- `pnpm` — managed via `corepack` (enabled via Node.js from `mise`), shims installed to `~/.local/bin`
- `pnpm store` at `/data/projects/.pnpm-store` — located on the same Btrfs volume as projects to allow fast hardlinks

**Python**
- `uv` — installed and managed via `mise`
- `Python` — versioning and project environments managed entirely via `uv` (no global system python mutation)
- `uv cache` redirected to `/data/projects/.uv-cache` (Btrfs `zstd:3` compression); tools follow XDG standard at `~/.local/share/uv`

**CLI & DevOps Utilities**
- `zoxide` — smart `cd` with frecency ranking
- `mise` — tool and runtime version manager
- `television` — blazing fast fuzzy search
- `ripgrep` (`rg`), `fd`, `bat`, `eza` — modern Rust replacements for standard Unix tools
- `lazygit`, `lazydocker` — terminal UI for git and docker
- `superfile` — modern terminal file manager
- `zellij` — terminal workspace multiplexer
- `sops`, `age` — GitOps secrets management
- `kubectl`, `kubectx`, `k9s`, `k3d`, `helm`, `argocd` — Kubernetes development suite
- `lefthook` — Git hooks manager
- `biome` — linter and formatter for JS/TS
- `turbo` — Turborepo for monorepos
- `jq`, `yq` — JSON/YAML processing

**GUI Applications & Editors**
- **IDEs / Editors:** Neovim (LazyVim), Visual Studio Code (`visual-studio-code-bin`), Android Studio
- **Browsers:** Vivaldi, Chromium, Tor Browser
- **Communication & Productivity:** Ferdium, Obsidian, Zotero
- **Utilities & Peripherals:** IMV (image viewer), Rofi (launcher), OpenRGB, Piper + ratbagd (ASUS mouse/macro control)

### 3. Containers and Virtualization

**Native Docker**
- Installed natively via Pacman (`docker`, `docker-compose`, `docker-buildx`) and configured on a dedicated `XFS` partition mounted at `/var/lib/docker` (using `overlay2` storage driver with `prjquota` enabled).
- Fully native, avoiding Docker Desktop VM overhead.
- Storage configuration (`overlay2.size=20G`, `live-restore: true`) managed via Ansible in `playbooks/setup_system.yml`.

**Kubernetes & Local Registry (k3d)**
- **k3d** runs k3s in lightweight docker containers.
- **Local Nexus Registry**: Fully configured via `k3d/.config/k3d/registries.yaml`. Requests to `nexus.local:8082` are routed transparently to the host via host-gateway, allowing image pulls without editing k8s deployment YAMLs.
- `k3d-create [name]` — custom Zsh function to bootstrap a local cluster mapped to your host's Nexus.
- `k8s-install-argocd` — installs and waits for ArgoCD on the active cluster.

**Sandbox environments**
- `niri-sandbox` alias — nested Wayland compositor session for testing bars, applets, and compositor settings. Close the window → everything gone, no cleanup needed.
- `sandbox-box <distro>` — throwaway Distrobox container for CLI tool testing (`sandbox-rm` to destroy it).
- **Distrobox** — lightweight containers with full Wayland and audio passthrough.

**Libvirt / QEMU/KVM**
- Full virtual machines managed via `libvirt`, `qemu-desktop`, `virt-manager`, `edk2-ovmf`, `swtpm`, and `dnsmasq`.
- VM disk images stored on NVMe 1 at `/var/lib/libvirt/images` (`ext4` partition).
- Automated via `playbooks/setup_virt.yml` — configures `virbr0` iptables firewall forwarding rules and fixes `swtpm` permissions.

---

## 🎮 Gaming & Steam Setup (`setup_gaming.yml`)

The setup includes an automated gaming playbook ([playbooks/setup_gaming.yml](file:///data/projects/dotfiles/playbooks/setup_gaming.yml)):

### 1. Installed Packages
- `cachyos-gaming-meta`, `lutris`, `protontricks`, `wine-mono`
- `nvidia-prime`, `nvidia-utils`, `envycontrol` (AUR)

### 2. Automatic Steam Library Integration
- `~/.local/share/Steam/steamapps` is automatically symlinked to `/data/games/SteamLibrary` (on `~/Games`).
- All Steam games install straight to your main NVMe 0 gaming storage without manual path configuration.

### 3. Proton & Wayland Optimizations
Configured globally in `~/.config/environment.d/10-gaming.conf`:
- `PROTON_USE_NTSYNC=1` — NTSYNC support for lower CPU overhead
- `PROTON_LOCAL_SHADER_CACHE=0` — prevents duplicate shader caching
- `PROTON_ENABLE_WAYLAND=0` — ensures maximum stability with XWayland
- `PROTON_ENABLE_HDR=0`

### 4. GPU / Optimus Switching
- Run individual apps/Steam on NVIDIA GPU:
  ```bash
  prime-run steam
  ```
- Switch GPU globally to NVIDIA via `envycontrol`:
  ```bash
  sudo envycontrol -s nvidia --force-comp
  # Or via playbook:
  ansible-playbook -K playbooks/setup_gaming.yml -e "switch_gpu_to_nvidia=true"
  ```

---

## 🖥 Windows VM (QEMU/KVM) Setup

To deploy a Windows 11 VM with UEFI, Secure Boot, TPM 2.0, and VirtIO drivers (disk/network performance):

### 1. Run Virtualization Playbook
```bash
ansible-playbook -K playbooks/setup_virt.yml
```

### 2. Download VirtIO Drivers
```bash
sudo wget https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso \
  -O /var/lib/libvirt/images/virtio-win.iso
```

### 3. Copy the Windows 11 ISO to VM Storage
```bash
sudo cp /path/to/windows11.iso /var/lib/libvirt/images/win11.iso
```

### 4. Create the VM via CLI
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

### 5. Install and Configure
1. Open **`virt-manager`** from your launcher.
2. Open the `win11` console and start the VM.
3. When Windows asks "Where do you want to install Windows?" and shows no disks, click **Load driver** -> **Browse** -> Select the `virtio-win` CD-ROM drive -> `amd64` -> `w11` to load the SCSI controller driver.
4. After Windows boots, open the VirtIO CD-ROM drive in Windows Explorer and run `virtio-win-gt-x64.msi` to install all missing guest tools (network, display, clipboard sharing).

---

## ⚙ Config Management (GNU Stow)

Dotfiles live in `/data/projects/dotfiles` (on NVMe 1, symlinked to `~/projects/dotfiles`).

Structure mirrors `$HOME`:

```
dotfiles/
├── zsh/                      -> ~/.zshrc
├── nvim/.config/nvim/        -> ~/.config/nvim
├── starship/.config/         -> ~/.config/starship.toml
├── niri/.config/niri/        -> ~/.config/niri
├── ghostty/.config/ghostty/  -> ~/.config/ghostty
├── hypr/.config/hypr/        -> ~/.config/hypr
├── k3d/.config/k3d/          -> ~/.config/k3d
├── k9s/.config/k9s/          -> ~/.config/k9s
├── mise/.config/mise/        -> ~/.config/mise
├── rofi/.config/rofi/        -> ~/.config/rofi
├── superfile/.config/        -> ~/.config/superfile
├── television/.config/       -> ~/.config/television
├── zellij/.config/zellij/    -> ~/.config/zellij
├── cargo/.cargo/             -> ~/.cargo/config.toml
└── git/                      -> ~/.gitconfig
```

The [setup_user.yml](file:///data/projects/dotfiles/playbooks/setup_user.yml) playbook automatically removes conflicting default files and runs GNU Stow across all configuration modules.

To add any new app configuration to Stow:
```bash
mv ~/.config/myapp ~/projects/dotfiles/myapp/.config/
cd ~/projects/dotfiles && stow myapp
```

---

## ☁ Synchronization (Rclone)

Two automated `systemd` user services configured by [setup_user.yml](file:///data/projects/dotfiles/playbooks/setup_user.yml):

- **`rclone-mount.service`** — mounts Google Drive as FUSE filesystem at `/data/gdrive` with up to 10 GB local VFS cache. Obsidian and Zotero work against **local copies** in `/data/sync`, not the mount directly.
- **`rclone-sync.timer`** — syncs `/data/sync` → `gdrive:MySyncBackup` once per hour (5 min after boot, then every hour). Logs to `~/.cache/rclone/`.

---

## 🏁 Post-Installation Steps

1. **Configure Rclone remote:**
   ```bash
   rclone config
   # Create remote named 'gdrive', type 'drive' (Google Drive), complete browser auth
   ```

2. **Start Cloud Services:**
   ```bash
   systemctl --user start rclone-mount.service
   systemctl --user start rclone-sync.timer
   ```

3. **Restart Terminal / Shell Session:**  
   Open a new terminal window to apply shell config, `zoxide`, `mise`, `carapace`, Starship prompt, and path exports.

4. **Point Apps to `/data/sync`:**  
   Open Obsidian and Zotero and set their data paths to `/data/sync/Obsidian` and `/data/sync/Zotero`.

---

## 🗂 Toolchain Storage Reference

| Tool | Binary / Toolchain Path | Cache / Data Storage Path | Notes |
|------|-------------------------|--------------------------|-------|
| **Rust** | `~/.cargo/bin` (NVMe 0) | `/data/projects/.cargo-cache/` (NVMe 1) | `registry` and `git` caches symlinked to NVMe 1 |
| **sccache** | System binary | `/data/projects/.sccache/` (NVMe 1) | Shared C/C++/Rust compilation cache |
| **pnpm** | `~/.local/bin/pnpm` | `/data/projects/.pnpm-store/` (NVMe 1) | Same Btrfs volume as projects to allow fast hardlinking |
| **uv / Python** | `~/.local/share/uv/` | `/data/projects/.uv-cache/` (NVMe 1) | Btrfs `zstd:3` compressed cache; managed via `mise` |
| **Docker** | System binaries | `/var/lib/docker/` (XFS, NVMe 1) | Native Docker with `overlay2` & `prjquota` |
| **Libvirt VMs** | System binaries | `/var/lib/libvirt/images/` (ext4, NVMe 1) | QEMU/KVM disk images |
| **Games / Steam** | Steam client (`~/.local/share/Steam`) | `/data/games/` → `~/Games` (NVMe 0) | Symlinked `steamapps` -> `/data/games/SteamLibrary` |