# CLI Reference: Core Workstation System Tools (L2)

## Chezmoi (Dotfiles & Configuration Management)
```bash
chezmoi status                    # Show modified/unmanaged targets
chezmoi diff                      # Compare repository state with $HOME
chezmoi verify                    # Validate 0 configuration drift
chezmoi apply                     # Apply changes to $HOME
chezmoi apply --source /data/projects/dotfiles --force  # Force apply from dotfiles repo
```

## Storage & Setup Health Checks
```bash
sudo bash check.sh                # Checks Docker XFS ftype, prjquota, mount points
bash check_setup.sh               # Checks user symlinks, Rust/pnpm/uv caches, env
```

## Navigation & File Management
- `z <directory>`: Fast jump with `zoxide`.
- `tv`: Television TUI fuzzy finder.
- `spf`: Superfile dual-pane file manager with shell wrapper for auto-cd on exit.
- `btop`: Resource, CPU, GPU, and memory monitor.
