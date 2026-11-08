# 🚀 CachyOS Niri: Ultimate Developer Setup & Dotfiles

Automated setup scripts and Ansible playbooks for configuring a **CachyOS (Niri)** installation. Transforms a bare system into an optimized development environment for Rust, TypeScript, Python, Kubernetes, and DevOps — with a Zsh + Neovim workflow, modular dotfiles management via Yggdrasil (`ygg`, supporting PC and ASUS laptop scopes), native Docker, QEMU/KVM virtualization, and an optimized dual-NVMe storage layout.

---

## ⚡ Quick Start

Configuration is declaratively managed via **Yggdrasil (`ygg`)**:

```bash
# Check status across modules
ygg status

# Dry-run inspection
ygg apply -n

# Apply dotfiles and install packages
ygg apply
```

---

## 🛠 Playbooks & Network Optimization (`playbooks/`)

The [`playbooks/`](file:///data/projects/dotfiles/playbooks) directory contains standalone playbooks such as network bufferbloat optimization (`setup_network_optimization.yml`), with legacy provisioning playbooks archived under `playbooks/archive/`.

### 1. 🌐 Network Bufferbloat & Latency Optimization (`playbooks/setup_network_optimization.yml`)
Standalone playbook for TCP BBR, CAKE qdisc, and network optimizations with full revert capability:
```bash
# Apply optimizations:
ansible-playbook playbooks/setup_network_optimization.yml --ask-become-pass --tags apply

# Revert optimizations:
ansible-playbook playbooks/setup_network_optimization.yml --ask-become-pass --tags revert
```

### 2. 📦 Archived Bootstrap Playbooks (`playbooks/archive/`)
Legacy provisioning playbooks (system partitioning, user toolchains, SDDM/Limine theming, gaming) have been superseded by `ygg` and `mise`, and are preserved in `playbooks/archive/` for historical reference.

### 9. 🧠 Sovereign AI Infrastructure (`ai-dotfiles`)
Centralized AI stack and agent orchestration are tracked in [`ai-dotfiles`](file:///data/projects/ai-dotfiles):
- **Ollama Engine (`infra/playbooks/setup_ollama.yml`):** GPU-accelerated local SLMs (`qwen2.5:14b-ctx64k`, `qwen2.5-coder:14b`, `bge-m3:latest`) with 64K context and `q8_0` KV cache
- **Khoj & Hindsight Stacks (`infra/stacks/`):** Docker Compose stacks for Obsidian vault RAG (`:42110`) and agent long-term memory (`:9999`)
- **Hermes Idea Pipeline (`services/hermes/`):** Multi-agent idea refinement and Kanban board orchestration
- **Host CLI MCP (`services/host-cli/`):** TypeScript/Bun MCP server for system interactions and repository knowledge navigation
- **Task Runner (`ai-dotfiles/mise.toml`):** Orchestrates AI diagnostics and workflows (`mise run status`, `mise run ai:start`)

---


## 💻 Terminal & Zsh Integration (`~/.zsh/`)

The terminal environment is built on Zsh in [`zsh/`](file:///data/projects/dotfiles/zsh) (deployed to `~/.zsh/`) with deep tool integration:

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

### 4. Keybindings & ZLE Widgets (`~/.zsh/binds/main.zsh`)
- `Alt + S`: Fast `sudo` prefix toggle at start of line (`sudo-command-line`, supports EN and RU layouts)
- `Ctrl + K` / `Ctrl + T` / `F2` / `Alt + R`: Native `fzf` file and directory selector widget with live `eza`/`bat` preview (inserts selected path into command line; `ESC` cancels cleanly without cluttering terminal output)
- `Ctrl + X Ctrl + L`: Automatic Russian ↔ English layout fix on current command buffer (`switch-language-buffer`)
- `Alt + Q` (or `q` in vicmd): Line buffering (`push-line`) — saves current unfinished command line, clears input to run another command (e.g. `ls`), then restores the unfinished line
- `Alt + .`: Insert last argument of previous command in insert mode (viins)
- `Ctrl + A` / `Ctrl + E`: Navigate to start/end of line in insert mode without switching to Normal mode

### 5. Aliases & Shell Utilities (`~/.zsh/alias/`)
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
- **Automation Scripts & Window Helpers (`~/.zsh/scripts/`)**:
  - `clipboard-picker.sh`: Меню истории буфера обмена через rofi (`Mod+V`)
  - `cooler-toggle.sh`: Быстрое переключение профилей охлаждения CoolerControl (`Mod+F1`)
  - `noctalia-dmenu.sh`: Dmenu-провайдер для лаунчера Noctalia
  - `obsidian-create-note.sh`: Быстрое создание структурированных заметок в Obsidian
  - `virt-helper.sh`: Управление виртуальными машинами QEMU/KVM
  - `wallpaper-engine-runner`: Мульти-мониторный запуск Wallpaper Engine в Niri
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

### NVMe 1 — Data (Dual-NVMe Storage Architecture)

| Label | Mount Point | FS | Mount Options | Purpose |
|-------|-------------|------|------------|---------|
| `DOCKER` | `/var/lib/docker` | `xfs` | `defaults,noatime,prjquota` | Native Docker data root (with project disk quotas) |
| `LIBVIRT` | `/var/lib/libvirt/images` | `ext4` | `defaults,noatime` | QEMU/KVM virtual machine disk images |
| `PROJECTS` | `/data/projects` → `~/projects` | `btrfs` | `compress=zstd:3,discard=async` | Source code + `.pnpm-store`, `.uv-cache`, `.sccache` |
| `SYNC` | `/data/sync` | `btrfs` | `compress=zstd:3,discard=async` | Obsidian vaults, Zotero library |

---

## ⚙️ Configuration Management (Yggdrasil)

All user configurations are declaratively managed via **Yggdrasil (`ygg`)**, a minimalist, modular Nushell-based dotfile manager. Configurations are organized into modules (`omni-dotfiles` for L-Core tools and `dotfiles` for L-Host CachyOS) and linked directly into `$HOME` without template engines. Hardware roles are partitioned into declarative scopes (`pc` and `asus`).

### Directory Structure

```
dotfiles/
├── ygg.toml                     # Module identifier and OS compatibility (cachyos, arch)
├── links.toml                   # Symlink mappings and scope definitions ([scope.pc.links], [scope.asus.links])
├── packages.toml                # Declarative package lists (pacman, paru, cargo, scopes)
├── setup.nu                     # Procedural lifecycle hook (MIME apps, cache dirs, user services)
├── niri/                        # ~/.config/niri (config.kdl, cfg/*.kdl)
│   └── displays/                # Display configurations (pc.kdl, asus.kdl)
├── noctalia/                    # ~/.config/noctalia (config.toml, colors.json, plugins/)
├── rofi/                        # ~/.config/rofi (cliphist, main, noctalia.rasi)
├── systemd/                     # ~/.config/systemd/user (openrgb, rclone)
├── vivaldi/                     # ~/.config/vivaldi-stable.conf
│   └── vivaldi-stable.conf
├── wallpaper-engine/            # ~/.config/wallpaper-engine (config.json)
├── waypaper/                    # ~/.config/waypaper (config.ini)
├── wireplumber/                 # ~/.config/wireplumber (SPA-JSON 0.5 rules)
└── zsh/                         # ~/.zsh/
    ├── alias/                   # Core, git, k8s aliases
    ├── alias-pc/                # Hardware-specific aliases (cooler.zsh)
    ├── scripts/                 # Centralized user automation scripts
    └── scripts-pc/              # Hardware-specific scripts (cooler-toggle.sh)
```

### Essential Ygg Commands

```bash
# Check synchronization status across all active modules:
ygg status

# Inspect planned changes and drift without modifying host (dry-run):
ygg apply -n
ygg apply --dry-run

# Apply all module configurations to $HOME:
ygg apply

# Apply links and setup while skipping package installation:
ygg apply --skip-packages

# Isolated dry run / validation inside a temporary sandbox directory:
ygg apply --sandbox /tmp/ygg-sandbox --skip-packages
```

---

## 🔍 Audit & Diagnostic Utilities

The repository includes diagnostic utilities in `scripts/` orchestrated via `mise`:

1. **Docker Storage Verification** (`scripts/check.sh`):
   Validates `/var/lib/docker` mount point, XFS `ftype=1` flag, `prjquota` mount options, `/etc/fstab` entries, parses `/etc/docker/daemon.json`, and performs a test container execution.
   ```bash
   mise run docker:check
   ```

2. **Destructive Disk Wipe** (`scripts/patrition_delete.sh`):
   Standalone utility for destructive disk wiping of `/dev/nvme1n1` (`wipefs`, `sgdisk --zap-all`, `dd zero`). 
   > ⚠️ **WARNING**: Use only when completely re-partitioning the second NVMe drive!
   ```bash
   mise run disk:wipe
   ```

3. **Windows 11 VM Automation** (`scripts/create_win11_vm.sh`, `scripts/configure_win11_vm_postinstall.sh`):
   Automated QEMU/KVM Windows 11 VM deployment script with TPM 2.0, VirtIO drivers, shared virtio-fs, and post-installation configuration.
   ```bash
   mise run vm:create
   mise run vm:postinstall
   ```

---

## 🧹 Repository Hygiene (Items NOT to commit to Dotfiles)

Audit findings for maintaining a clean public dotfiles repository:

1. **Cargo Runtime Artifacts & Caching (`~/.cargo/`)**:
   - `~/.cargo/.global-cache` (binary cache file ~80 KB)
   - `~/.cargo/.package-cache` and `.package-cache-mutate`
   - Local binaries in `~/.cargo/bin/`, `registry/`, `git/`, `binstall/`
   - *Solution*: All runtime artifacts and binary caches are ignored in [.gitignore](file:///data/projects/dotfiles/.gitignore).
2. **Ansible Galaxy Cache (`.ansible/`)**:
   - The `.ansible/` directory contains downloaded Ansible Galaxy roles and collections (e.g. `kewlfft.aur`). Excluded in [.gitignore](file:///data/projects/dotfiles/.gitignore).
3. **Sensitive Files (Secrets & Credentials)**:
   - SSH keys (`id_rsa`, `id_ed25519`), API tokens, private `rclone.conf` configs, and Atuin/Zsh history files must not be committed. History files are stored in `XDG_STATE_HOME` (`~/.local/state/zsh/history`), and secrets should be managed via `sops` / `age`.