# Subsystem: Ansible Playbook Orchestration (L1)

## Single Source of Truth: `playbooks/vars/packages.yml`
All packages must be declared in `playbooks/vars/packages.yml`:
- `system_packages`: Low-level kernel, boot, drivers, system daemons.
- `user_pacman_packages`: Official Arch/CachyOS repository CLI/GUI tools.
- `aur_packages`: AUR packages installed via `paru` (kewlfft.aur collection). NEVER run as root!
- `cargo_packages`: Rust binaries installed via `cargo-binstall`.
- `cli_essential_packages`: Core terminal tools (fzf, eza, bat, ripgrep, etc.).
- `unwanted_packages`: Removed packages (e.g. stock browsers or terminals).
- `ollama_packages`: Dedicated GPU/AI inference packages (installed on-demand via `setup_ollama.yml`).

## Playbook Roles & Execution Order
1. Root / System Level (`sudo bash setup_system.sh`):
   - `packages.yml --tags system`
   - `setup_system.yml`: Partitioning NVMe 1, filesystems, fstab, user groups (docker, libvirt, kvm).
   - `setup_display_manager.yml`: SDDM & Limine Catppuccin theme.
2. User Level (`bash setup_user.sh`):
   - `packages.yml --tags user,aur,cargo`
   - `setup_user.yml`: Cleanup default colliding files, GNU Stow symlinking, cache directory creation.
   - `setup_rclone.yml`: Obsidian bisync with Google Drive systemd user timer.
3. Modular AI Stack (`ansible-playbook playbooks/setup_ai_stack.yml`):
   - `setup_ollama.yml`: Stow `ollama/`, start `ollama.service`, pull target models.
   - `deploy/khoj`: Docker compose up, postgres initialization, setup.sh.
   - `setup_anythingllm.yml`: Desktop config, TS skills build, MCP linkage.

## Recent Changes
- **`playbooks/packages.yml`**: Added `ollama_packages` for GPU/AI inference packages.
- **`playbooks/setup_user.yml`**: Updated GNU Stow command to exclude additional directories (`deploy`, `docs`, `scripts`, `evals`, `ollama`, `local-ai-stack`, `crates`).
- **`playbooks/vars/packages.yml`**: Added `ollama_packages` variable for dedicated GPU/AI inference packages.

## Hotkeys
- **Super + A**: Open Alfred (if configured).
- **Super + E**: Open Nemo file manager.
- **Super + T**: Open Terminal.
- **Super + S**: Open System Monitor.
- **Super + Q**: Open Quick Switcher (if configured).
- **Super + L**: Lock the screen (added for security).

## Additional Configurations
- **Rclone**: Configured for Obsidian bisync with Google Drive.
- **GNU Stow**: Excludes directories like `deploy`, `docs`, `scripts`, `evals`, `ollama`, `local-ai-stack`, and `crates` during symlinking.
- **Ollama**: Installed via `setup_ollama.yml` with CUDA support for GPU acceleration.
- **Screen Lock**: Added hotkey `Super + L` for locking the screen.
