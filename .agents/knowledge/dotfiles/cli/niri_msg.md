# CLI Reference: niri msg (L2)

## Purpose
`niri msg` is the official IPC control client for the Niri Wayland compositor.

## Common Operations & Syntax
```bash
# Configuration & State
niri validate                     # Check ~/.config/niri/config.kdl syntax
niri msg action reload-config     # Hot-reload configuration without restarting session

# Window & Workspace Inspection
niri msg windows                  # List all open windows with IDs, titles, app-ids, focus state
niri msg workspaces               # List active workspaces and outputs
niri msg outputs                  # List connected monitor outputs and modes

# Window Management Actions
niri msg action close-window                     # Close active window
niri msg action fullscreen-window                # Toggle fullscreen
niri msg action toggle-window-floating           # Toggle floating / tiling state
niri msg action center-column                    # Center active column on screen
niri msg action focus-column-left                # Move focus left
niri msg action focus-column-right               # Move focus right
niri msg action move-column-left                 # Shift column left
niri msg action move-column-right                # Shift column right
niri msg action set-column-width <width>         # Set width (e.g. +10%, -10%, 50%)
```
