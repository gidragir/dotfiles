# CLI Reference: Core Workstation System Tools (L2)

## Yggdrasil (Dotfiles & Module Configuration Management)
```bash
ygg status                        # Show module sync status and active scopes
ygg apply -n                      # Dry-run inspection of link/config drift
ygg apply                         # Apply all module configurations to $HOME
ygg apply --skip-packages         # Apply links and run setup without touching packages
ygg apply --sandbox /tmp/sb       # Test deployment in isolated sandbox root
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
