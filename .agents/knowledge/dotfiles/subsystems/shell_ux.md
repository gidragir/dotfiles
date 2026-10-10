# Subsystem: Shell & Modal Terminal UX (L1)

## Architecture & Interaction Patterns
- **Terminal Emulator:** Ghostty with native Wayland support and Catppuccin Frappe theme.
- **Shell:** Zsh configured via `home/dot_zshrc`, `home/dot_zshenv.tmpl`, `home/dot_zprofile` (deployed to `~` via Chezmoi).
- **Modal Vi-Mode:** `bindkey -v` enabled with cursor shape indicators (Beam `|` for Insert, Block `█` for Normal). Quick escape with `KEYTIMEOUT=1`.
- **Neovim Command Edit:** Press `v` in Normal mode to open current command buffer in LazyVim via `edit-command-line`.
- **Interactive Completions:** `fzf-tab` with rich preview popups (`eza` for directories, `bat` for text, `ps` for processes).
- **Fast Navigation:** `zoxide` (`cd`), Television `tv`, Superfile `spf` (auto-cd on exit).
- **Terminal Token Optimization:** `rtk` (Rust Token Killer) used across shell sessions to prune CLI command output.
- **Secrets Management:** Rendered from `~/.config/chezmoi/secrets.toml` into `.zshenv` with fallback to `.zshenv.local`.

## Centralized Script Organization Rule
- **Zero Loose Scripts Invariant:** All custom scripts, CLI utilities, and window helpers MUST reside in `home/dot_zsh/scripts/`.
- The directory `~/.zsh/scripts` is automatically prepended to `$PATH` via `.zshenv`.
- **Key scripts present:**
  - `clipboard-picker.sh`: Rofi-based clipboard history picker (`Mod+V`).
  - `cooler-toggle.sh`: Fast cycling of CoolerControl profiles (`Mod+F1`).
  - `noctalia-dmenu.sh`: Dmenu provider script for Noctalia launcher.
  - `obsidian-create-note.sh`: Rapid capture of structured notes into Obsidian.
  - `obsidian-helper.sh`: Obsidian vault workspace integration.
  - `path-picker.sh` / `path-picker-dmenu.sh`: File and folder selector widgets with previews.
  - `spf-clip.sh`: Superfile clipboard helper.
  - `virt-helper.sh`: Fast KVM/libvirt VM discovery and virt-viewer connection wrapper.
  - `wallpaper-engine-runner`: Multi-monitor runner for `linux-wallpaperengine` in Niri.
  - `gamescope-run`: Isolated gaming session runner.
  - `hermes-bar-status.sh` / `hermes-capture-idea.sh` / `hermes-desktop-toggle.sh`: Noctalia panel and idea pipeline integration scripts.

## Hotkeys
- `v`: Open current command buffer in LazyVim in Normal mode.
- `Alt + S`: Fast `sudo` prefix toggle at start of command line.
- `Ctrl + K` / `Ctrl + T` / `F2`: Native `fzf` file and directory selector with `eza`/`bat` preview.
- `Alt + Q`: Line buffering (`push-line`).
- `Ctrl + X Ctrl + L`: Automatic Russian ↔ English layout switcher on command buffer.
