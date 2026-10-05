# 🚀 CachyOS Niri: Ultimate Developer Setup & Dotfiles

Automated setup scripts and Ansible playbooks for configuring a **CachyOS (Niri)** installation. Transforms a bare system into an optimized development environment for Rust, TypeScript, Python, Kubernetes, and DevOps — with a Zsh + Neovim workflow, dotfiles management via GNU Stow, native Docker, QEMU/KVM virtualization, and an optimized dual-NVMe storage layout.

---

## ⚡ Quick Start

All installation scripts support **both direct execution via `curl`** and local execution in a cloned repository. When executed via `curl`, the scripts automatically check for local playbooks and clone the repository to `~/projects/dotfiles` if necessary.

### 1. System Setup (sudo required)

Formats the target NVMe drive, installs system packages via Pacman, configures the `/data` mount points (Btrfs, XFS, ext4), and sets up Docker and libvirt user groups and services.

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/gidragir/dotfiles/main/scripts/setup_system.sh)"
```

> ⚠️ **IMPORTANT**: After the script finishes, **log out and back in** (or reboot) to apply new group memberships (`docker`, `libvirt`, `kvm`).

### 2. User Setup (run as normal user)

Configures the user environment: development runtimes via [mise](https://mise.jdx.sh/), AUR packages via `paru`, Cargo tools, dotfiles via GNU Stow, and background `rclone` sync timers.

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/gidragir/dotfiles/main/scripts/setup_user.sh)"
```

---

## 🛠 Utility & Specialized Playbooks (`playbooks/`)

The [`playbooks/`](file:///data/projects/dotfiles/playbooks) directory contains modular Ansible playbooks for selective execution and maintenance:

### 1. 🦀 Rust Development Stack (`playbooks/setup_rust.yml`)
Installs and isolates an optimized Rust toolchain:
- `rustup` (activates `stable` channel)
- Fast linker: `mold` + `clang`
- Compilation cache: `sccache` (cache stored on NVMe 1 at `/data/projects/.sccache`)
- Fast binary installer: `cargo-binstall`
- Developer utilities: `cargo-nextest`, `bacon`, `cargo-machete`, `cargo-ramdisk`

```bash
ansible-playbook playbooks/setup_rust.yml
```

### 2. 🎮 Gaming Environment & Steam (`playbooks/setup_gaming.yml`)
Configures CachyOS for gaming and graphics drivers:
- Packages: `cachyos-gaming-meta`, `lutris`, `protontricks`, `wine-mono`, `nvidia-prime`, `nvidia-utils`, `envycontrol` (AUR)
- Automatic Steam Library integration: links `~/.local/share/Steam/steamapps` to `/data/games/SteamLibrary` on main storage
- Proton/Wayland optimizations in `~/.config/environment.d/10-gaming.conf` (`PROTON_USE_NTSYNC=1`, `PROTON_ENABLE_WAYLAND=0`)
- GPU switching (Optimus/Prime):

```bash
# Basic gaming stack installation:
ansible-playbook -K playbooks/setup_gaming.yml

# Force switch GPU globally to NVIDIA via envycontrol:
ansible-playbook -K playbooks/setup_gaming.yml -e "switch_gpu_to_nvidia=true"
```

### 3. 🖥 QEMU/KVM Virtualization & Libvirt (`playbooks/setup_virt.yml`)
Deploys a complete KVM virtualization stack:
- Packages: `qemu-full`, `libvirt`, `virt-manager`, `edk2-ovmf` (UEFI), `swtpm` (TPM 2.0 emulator), `dnsmasq`, `ufw`
- Enables `virbr0` bridge and sets up UFW routing rules
- Fixes `swtpm` directory permissions
- Configures secure Virtio-FS shared folder `/srv/Shared` with `virtshare` group for host/VM file sharing

```bash
ansible-playbook -K playbooks/setup_virt.yml
```

### 4. 📦 Package Management (`playbooks/packages.yml`)
Selective package installation and updates:
```bash
# System packages (run as root):
ansible-playbook playbooks/packages.yml --tags system

# User pacman, AUR, and cargo packages:
ansible-playbook playbooks/packages.yml --tags user,aur,cargo
```

### 5. 🖥️ Display Manager & Bootloader UI (`playbooks/setup_display_manager.yml`)
Configures SDDM and Limine with Catppuccin Frappe theme:
- SDDM restricted exclusively to primary monitor `DP-2` (turns `HDMI-A-1` off in `Xsetup`)
- Installs `catppuccin-frappe-blue` SDDM theme and configures `/etc/sddm.conf.d/`
- Customizes Limine bootloader with Frappe color palette, wallpaper, and resolution

```bash
ansible-playbook -K playbooks/setup_display_manager.yml
```

### 6. ❄️ CoolerControl Fan Curves (`playbooks/setup_cooler_control.yml`)
Configures system cooling daemon, fan curves, and profiles (Quiet, Gaming, Work):
```bash
ansible-playbook -K playbooks/setup_cooler_control.yml
```

### 7. 🔄 Rclone Obsidian Bisync Timer (`playbooks/setup_rclone.yml`)
Configures systemd user service and timer for bidirectional sync of Obsidian vaults via `rclone bisync`:
```bash
ansible-playbook playbooks/setup_rclone.yml
```

### 8. 🖼️ Wallpaper Engine for Wayland (`playbooks/setup_wallpaper_engine.yml`)
Configures `linux-wallpaperengine` for Niri Wayland sessions with systemd user unit:
```bash
ansible-playbook -K playbooks/setup_wallpaper_engine.yml
```

### 9. 🧠 Sovereign AI Infrastructure (`ai-dotfiles/`)
Centralized AI stack and agent orchestration are tracked in [`ai-dotfiles`](file:///data/projects/dotfiles/ai-dotfiles):
- **Ollama Engine (`infra/playbooks/setup_ollama.yml`):** GPU-accelerated local SLMs (`qwen2.5:14b-ctx64k`, `qwen2.5-coder:14b`, `bge-m3:latest`) with 64K context and `q8_0` KV cache
- **Khoj & Hindsight Stacks (`infra/stacks/`):** Docker Compose stacks for Obsidian vault RAG (`:42110`) and agent long-term memory (`:9999`)
- **Hermes Idea Pipeline (`services/hermes/`):** Multi-agent idea refinement and Kanban board orchestration
- **Host CLI MCP (`services/host-cli/`):** TypeScript/Bun MCP server for system interactions and repository knowledge navigation
- **Task Runner (`mise.toml`):** Orchestrates AI diagnostics and workflows (`mise run ai:status`, `mise run knowledge:l0`)

---


## 💻 Terminal & Zsh Integration (`zsh/`)

The terminal environment is built on Zsh in [`zsh/`](file:///data/projects/dotfiles/zsh) with deep tool integration:

### 1. Vi-mode & Dynamic Cursor
- Full Vi keymap enabled (`bindkey -v`)
- **Dynamic Cursor Shape** (`zle-keymap-select`): Beam `|` in Insert mode, Block `█` in Normal mode
- **Fast Escape response** (`KEYTIMEOUT=1`, 10 ms delay)
- **Neovim command editing**: Press `v` in Normal mode to edit the current command buffer in Neovim (LazyVim) via `edit-command-line`

### 2. Starship Prompt & Atuin Smart History
- **Starship Prompt** natively displays the current Vi mode: `❯` (green — Insert), `[N]` (yellow — Normal), `[V]` (cyan — Visual)
- **Atuin**: Shell history search replaces standard `Ctrl+R` with context and execution time tracking
- Integrated with `zsh-autosuggestions` (`_zsh_autosuggest_strategy_atuin`) for history-driven completion suggestions

### 3. Interactive fzf-tab & Live Previews
`fzf-tab` replaces standard Zsh completion menus with contextual fuzzy search (`--height=40%`) and **live previews**:
- `cd [Tab]`: Directory contents preview via `eza`
- `systemctl [Tab]`: Service status via `systemctl status` with syntax highlighting
- `kill [Tab]`: Process details (PID, CPU, MEM, CMD) via `ps`
- `export` / `unset [Tab]`: Environment variable values preview
- `git add` / `diff` / `restore [Tab]`: Interactive `git diff` preview for selected files

### 4. Keybindings & ZLE Widgets (`zsh/.zsh/binds/main.zsh`)
- `Alt + S`: Fast `sudo` prefix toggle at start of line (`sudo-command-line`, supports EN and RU layouts)
- `Ctrl + K` / `Ctrl + T` / `F2` / `Alt + R`: Native `fzf` file and directory selector widget with live `eza`/`bat` preview (inserts selected path into command line; `ESC` cancels cleanly without cluttering terminal output)
- `Ctrl + X Ctrl + L`: Automatic Russian ↔ English layout fix on current command buffer (`switch-language-buffer`)
- `Alt + Q` (or `q` in vicmd): Line buffering (`push-line`) — saves current unfinished command line, clears input to run another command (e.g. `ls`), then restores the unfinished line
- `Alt + .`: Insert last argument of previous command in insert mode (viins)
- `Ctrl + A` / `Ctrl + E`: Navigate to start/end of line in insert mode without switching to Normal mode

### 5. Aliases & Shell Utilities (`zsh/.zsh/alias/`)
- **Modern Unix Replacements**: `ll` (`eza -l`), `la` (`eza -la`), `tree` (`eza --tree`)
- **Superfile File Manager (`spf`)**: `spf()` wrapper that automatically `cd`s into the last visited directory upon exit
- **Television + Superfile (`spft`)**: Fuzzy search files/folders via `tv` (Television) and immediately open in Superfile
- **Sandboxes & Containers**:
  - `niri-sandbox`: Runs a nested Wayland compositor session for safely testing bars, applets, and compositor configs
  - `sandbox-box [distro]`: Spawns a throwaway Distrobox container for testing CLI tools
  - `sandbox-rm`: Quickly removes the sandbox container
- **Kubernetes / k3d Utilities**:
  - `k3d-create [name]`: Bootstraps a local k3d cluster with port forwarding and local Nexus Registry mapping
  - `k8s-install-argocd`: Automated installation and wait helper for ArgoCD
- **Universal Archive Extractor (`extract` / `x`)**: Unpacks `.tar.gz`, `.zip`, `.7z`, `.tar.zst`, `.rar`, and other archive formats with a single command
- **Automation Scripts & Window Helpers (`zsh/.zsh/scripts/`)**:
  - `clipboard-picker.sh`: Меню истории буфера обмена через rofi (`Mod+V`)
  - `cooler-toggle.sh`: Быстрое переключение профилей охлаждения CoolerControl (`Mod+F1`)
  - `noctalia-dmenu.sh`: Dmenu-провайдер для лаунчера Noctalia
  - `virt-helper.sh`: Управление виртуальными машинами QEMU/KVM
  - `hermes-desktop-toggle.sh` / `hermes-capture-idea.sh`: Быстрый вызов и интейк идей Hermes
  - `sync-env.sh`: Синхронизация переменных окружения и профилей

---

## 💽 Disk Layout (Dual NVMe 1 TB)

### NVMe 0 — System (installed via CachyOS installer)

| Partition | Size | Purpose |
|-----------|------|---------|
| `/boot/efi` | 1 GB | EFI, FAT32 |
| `/` | ~100 GB | System root |
| `swap` | 8 GB | Swap / hibernation support |
| `/home` | ~891 GB | User data, configs, toolchains, games (`~/Games`) |

### NVMe 1 — Data (`scripts/setup_system.sh` partitions automatically)

| Label | Mount Point | FS | Mount Options | Purpose |
|-------|-------------|------|------------|---------|
| `DOCKER` | `/var/lib/docker` | `xfs` | `defaults,noatime,prjquota` | Native Docker data root (with project disk quotas) |
| `LIBVIRT` | `/var/lib/libvirt/images` | `ext4` | `defaults,noatime` | QEMU/KVM virtual machine disk images |
| `PROJECTS` | `/data/projects` → `~/projects` | `btrfs` | `compress=zstd:3,discard=async` | Source code + `.pnpm-store`, `.uv-cache`, `.sccache` |
| `SYNC` | `/data/sync` | `btrfs` | `compress=zstd:3,discard=async` | Obsidian vaults, Zotero library |

---

## ⚙️ Configuration Management (GNU Stow)

All configuration files are managed in `/data/projects/dotfiles` (symlinked to `~/projects/dotfiles`).
The repository layout mirrors `$HOME`:

```
dotfiles/
├── zsh/                      -> ~/.zshrc, ~/.zshenv, ~/.zprofile, ~/.zsh/
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
├── vivaldi/.config/          -> ~/.config/vivaldi-stable.conf
├── wireplumber/.config/      -> ~/.config/wireplumber
├── zellij/.config/zellij/    -> ~/.config/zellij
├── cargo/.cargo/             -> ~/.cargo/config.toml
├── noctalia/.config/         -> ~/.config/noctalia
├── btop/.config/btop/        -> ~/.config/btop
├── openrgb/.config/          -> ~/.config/OpenRGB, ~/.config/systemd/user
├── atuin/.config/            -> ~/.config/atuin
└── sheldon/.config/          -> ~/.config/sheldon
```

To add a new application configuration to Stow:
```bash
mv ~/.config/myapp ~/projects/dotfiles/myapp/.config/
cd ~/projects/dotfiles && stow -t ~ myapp
```

---

## 🔍 Audit & Diagnostic Scripts

The repository includes built-in diagnostic scripts in `scripts/` to verify system setup:

1. **[`scripts/check.sh`](file:///data/projects/dotfiles/scripts/check.sh)**:
   Docker storage verification. Validates `/var/lib/docker` mount point, XFS `ftype=1` flag, `prjquota` mount options, `/etc/fstab` entries, parses `/etc/docker/daemon.json`, and performs a test container execution.
   ```bash
   sudo bash scripts/check.sh
   ```

2. **[`scripts/check_setup.sh`](file:///data/projects/dotfiles/scripts/check_setup.sh)**:
   Comprehensive environment check-list. Verifies mount points (`/data/projects`, `/data/sync`, `/var/lib/docker`, `/var/lib/libvirt/images`), cache directories (`.pnpm-store`, `.uv-cache`, `.sccache`), Cargo symlinks, CLI tools availability, and `rclone` background timers status.
   ```bash
   bash scripts/check_setup.sh
   ```

3. **[`scripts/patrition_delete.sh`](file:///data/projects/dotfiles/scripts/patrition_delete.sh)**:
   Standalone utility for destructive disk wiping of `/dev/nvme1n1` (`wipefs`, `sgdisk --zap-all`, `dd zero`). 
   > ⚠️ **WARNING**: Use only when completely re-partitioning the second NVMe drive!

4. **[`scripts/create_win11_vm.sh`](file:///data/projects/dotfiles/scripts/create_win11_vm.sh)**:
   Automated QEMU/KVM Windows 11 VM deployment script with TPM 2.0, VirtIO drivers, and shared virtio-fs configuration.

---

## 🧹 Repository Hygiene (Items NOT to commit to Dotfiles)

Audit findings for maintaining a clean public dotfiles repository:

1. **Cargo Runtime Artifacts & Caching (`cargo/.cargo/`)**:
   - `cargo/.cargo/.global-cache` (binary cache file ~80 KB)
   - `cargo/.cargo/.package-cache` and `.package-cache-mutate`
   - Local binaries in `cargo/.cargo/bin/`, `registry/`, `git/`, `binstall/`
   - *Solution*: All runtime artifacts and binary caches are ignored in [.gitignore](file:///data/projects/dotfiles/.gitignore).
2. **Ansible Galaxy Cache (`.ansible/`)**:
   - The `.ansible/` directory contains downloaded Ansible Galaxy roles and collections (e.g. `kewlfft.aur`). Excluded in [.gitignore](file:///data/projects/dotfiles/.gitignore).
3. **Sensitive Files (Secrets & Credentials)**:
   - SSH keys (`id_rsa`, `id_ed25519`), API tokens, private `rclone.conf` configs, and Atuin/Zsh history files must not be committed. History files are stored in `XDG_STATE_HOME` (`~/.local/state/zsh/history`), and secrets should be managed via `sops` / `age`.