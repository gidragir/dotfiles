# Subsystem: Shell & Modal Terminal UX (L1)

## Architecture & Interaction Patterns
- Terminal Emulator: Ghostty with native Wayland support and Catppuccin Mocha theme.
- Shell: Zsh configured via `zsh/.zshrc`, `zsh/.zshenv`, `zsh/.zprofile`.
- Modal Vi-Mode: `bindkey -v` enabled with cursor shape indicators (Beam `|` for Insert, Block `█` for Normal). Quick escape with `KEYTIMEOUT=1`.
- Neovim Command Edit: Press `v` in Normal mode to open current command buffer in LazyVim.
- Interactive Completions: `fzf-tab` with rich preview popups (`eza` for directories, `bat` for text, `ps` for processes).
- Fast Navigation: `zoxide` (`cd`), Television `tv`, Superfile `spf` (auto-cd on exit).
- Git Aliases: `gcai` for interactive staging and committing with `opencommit`.

## Script Organization Rule
- All custom scripts and window helpers MUST reside in `zsh/.zsh/scripts/`.
- The directory `~/.zsh/scripts` is automatically prepended to `$PATH` via `.zshenv`.
- Key scripts present:
  - `khoj-ctl`: CLI management for Khoj, healthchecks, indexing, search.
  - `khoj-tags`: High-speed ripgrep search for Obsidian tags and frontmatter.
  - `noctalia-dmenu`: Wrapper for Noctalia Dmenu plugin CLI.
  - Window helpers for Niri.

## Recent Updates
- Added `gcai` alias in `zsh/.zsh/alias/git.zsh` for interactive staging and committing with `opencommit`.
- Updated `.zshenv` to include `$PNPM_HOME/bin` in the `$PATH`.
- Removed the symbolic link `noctalia-dmenu` and replaced it with a script that checks for the executable and runs it.
- Updated `anything-ctl` script to include new paths for AI stack directories and corrected the `cmd_sync` function.
- Added `anythingllm-assistant-toggle.sh` script for toggling the AnythingLLM Assistant window.
- Updated `khoj-tags` script to use `glow` for preview if available.

## Hotkeys
- `v`: Open current command buffer in LazyVim in Normal mode.
- `KEYTIMEOUT=1`: Quick escape from Vi-Mode.
