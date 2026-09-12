# CLI Reference: Core Workstation System Tools (L2)

## GNU Stow (Dotfiles Linking)
```bash
cd /data/projects/dotfiles
stow -nv -t ~ <package>           # Dry run: check for potential file collisions
stow -t ~ <package>               # Link package to $HOME
stow -D -t ~ <package>            # Unlink package from $HOME
stow -R -t ~ <package>            # Re-stow (refresh symlinks)
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
