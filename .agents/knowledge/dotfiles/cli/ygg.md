# CLI Reference: ygg (L2)

- **Captured Date:** 2026-11-08
- **Source:** `ygg --help`

## Key Commands in Dotfiles Workflow

```bash
# Check synchronization status across all active modules:
ygg status

# Inspect planned changes and drift without modifying host (dry-run):
ygg apply -n
ygg apply --dry-run

# Apply configurations, links, packages and setup across all modules:
ygg apply

# Apply links and run setup while skipping package installations:
ygg apply --skip-packages

# Isolated dry run / validation inside a temporary sandbox directory:
ygg apply --sandbox /tmp/ygg-sandbox --skip-packages

# Add a module from local directory or git repo:
ygg add <path-or-git-url> --scope pc

# Update git modules via rebase and apply:
ygg update
```

## Module Structure & Scopes

- **Manifest (`ygg.toml`):** Module name and target OS compatibility (`name = "dotfiles"`, `os = ["cachyos", "arch"]`).
- **Links (`links.toml`):** Flat symlink mapping declarations:
  - Base links: `[links]` (e.g. `"niri/cfg/*" = "~/.config/niri/cfg/*"`, `"noctalia" = "~/.config/noctalia"`).
  - Scope links: `[scope.pc.links]`, `[scope.asus.links]` (e.g. display outputs, hardware-specific scripts).
- **Packages (`packages.toml`):** Declarative package lists by manager (`pacman`, `paru`, `cargo`) and scopes (`[scope.pc.packages]`, `[scope.asus.packages]`).
- **Lifecycle Hook (`setup.nu`):** Procedural Nushell script for MIME-associations, cache directory creation, and systemd units enablement.
- **Host Manifest (`~/.ygg/host.toml`):** Registers active modules (`omni-dotfiles`, `dotfiles`) and host scopes (`scopes = ["pc"]`).
