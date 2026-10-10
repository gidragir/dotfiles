# CLI Reference: chezmoi (L2)

- **Captured Date:** 2026-10-08
- **Source:** `chezmoi --help`

## Key Commands in Dotfiles Workflow

```bash
# Verify synchronization (0 drift between repo and $HOME):
chezmoi verify

# Check current status of managed targets:
chezmoi status

# View unified diff between repo source state and $HOME:
chezmoi diff

# Apply changes to home directory:
chezmoi apply

# Force apply changes from dotfiles repository root:
chezmoi apply --source /data/projects/dotfiles --force

# Test template evaluation for desktop/laptop profiles:
chezmoi execute-template --override-data '{"chassis":"desktop"}' < home/dot_config/niri/cfg/display.kdl.tmpl
chezmoi execute-template --override-data '{"chassis":"laptop"}' < home/dot_config/niri/cfg/display.kdl.tmpl
```

## Managed vs Unmanaged Boundaries

- **Managed via Symlink (`mode = "symlink"`):** Static tool configs (`bat`, `fzf`, `rtk`, `nvim`, `ghostty`, `sheldon`, `btop`, `television`, `superfile`, `zellij`). Zero-latency live-editing.
- **Managed via Templates (`.tmpl`):** Configs containing host/user-dependent variables (`waypaper/config.ini.tmpl`, `wallpaper-engine/config.json.tmpl`, `environment.d/10-environment.conf.tmpl`, `display.kdl.tmpl`). Always use `{{ .chezmoi.homeDir }}` or `{{ .chassis }}`.
- **Intentionally Unmanaged (Host-Local):** Desktop theme/default handlers (`gtk-3.0`, `gtk-4.0`, `mimeapps.list`), generic fallbacks (`micro`), hardware-specific state (`OpenRGB/Configuration.json`, `sizes.ors`), and secrets (`gh`, `coolercontrol/token`, `rclone.conf`).
- **AI-Stack Managed (Stow):** Isolated via `.chezmoiignore` (`.hermes/**`, `.config/Hermes/**`, `.opencommit*`, `.gemini/**`). Managed independently in `ai-dotfiles`.

## Flags & Parameters

- `--source, -S`: Set source repository directory (default: `~/.local/share/chezmoi`, overridden to `/data/projects/dotfiles`).
- `--force`: Apply changes without interactive confirmation prompts.
- `--verbose, -v`: Print detailed unified diff of applied changes.
- `--override-data`: Pass JSON object to override template data during testing.
- `mode = "symlink"`: Configured in `home/.chezmoi.toml.tmpl` to deploy static files as native symlinks.

