# Subsystem: Ansible Playbook Orchestration (L1)

## Single Source of Truth: `playbooks/vars/packages.yml`
All packages must be declared in `playbooks/vars/packages.yml`:
- `system_packages`: Low-level kernel, boot, drivers, virtualization, and system daemons.
- `user_pacman_packages`: Official Arch/CachyOS repository CLI/GUI tools and multimedia libraries.
- `aur_packages`: AUR packages installed via `paru` (`kewlfft.aur` collection). Categorically NEVER run as root!
- `desktop_aur_packages` / `laptop_aur_packages`: Hardware-profile-specific AUR packages.
- `cargo_packages`: Rust binaries installed via `cargo-binstall`.
- `cli_essential_packages`: Core terminal tools (`chezmoi`, `fzf`, `eza`, `bat`, `ripgrep`, `fd`, `btop`, `glow`, etc.).
- `unwanted_packages`: Stock packages removed during installation (e.g. default browser).
- `ollama_packages`: Dedicated GPU/AI inference packages.

## Playbook Execution Pipeline

### 1. Root / System Level (`sudo bash scripts/setup_system.sh`)
- `packages.yml --tags system`: System packages, base development tools, container runtimes.
- `setup_system.yml`: Partitioning NVMe 1, filesystems (XFS prjquota, ext4, Btrfs), fstab, user group assignments (`docker`, `libvirt`, `kvm`).
- `setup_display_manager.yml`: Catppuccin Frappe SDDM theme, DP-2 primary monitor lock, and Limine bootloader styling.

### 2. User Level (`bash scripts/setup_user.sh`)
- `packages.yml --tags user,aur,cargo,cli`: Official user packages, essential CLI utilities, desktop AUR applications, and Cargo tools.
- `setup_user.yml`: Chezmoi configuration deployment (`chezmoi apply`), toolchain caches, user services (`rclone-obsidian-sync.timer`, `openrgb.service`).

### 3. Specialized Modular Playbooks
- `setup_rust.yml`: Isolated Rust toolchain with mold linker, sccache cache, and cargo-binstall tools.
- `setup_gaming.yml`: Steam, Lutris, Proton environment variables, and `/data/games` Steam library symlink.
- `setup_virt.yml`: QEMU/KVM, libvirt, swtpm, UFW network bridge rules, Virtio-FS `/srv/Shared`.
- `setup_cooler_control.yml`: Fan curves and profiles (Quiet, Gaming, Work) for CoolerControl.
- `setup_rclone.yml`: Obsidian bidirectional synchronization unit and timer.
- `setup_wallpaper_engine.yml`: `linux-wallpaperengine` runner and Waypaper integration.

## Diagnostics & Verification
```bash
# Verify playbook syntax:
ansible-playbook --syntax-check playbooks/*.yml

# Check host configuration and caches:
bash scripts/check_setup.sh

# Check Docker XFS and quota configuration:
sudo bash scripts/check.sh
```
