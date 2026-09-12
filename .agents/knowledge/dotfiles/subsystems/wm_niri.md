# Subsystem: Niri Wayland Compositor (L1)

## Overview
Niri is a scrollable-tiling Wayland compositor configured declaratively using KDL syntax.
Configuration root: `niri/.config/niri/` -> deployed via GNU Stow to `~/.config/niri/`.

## Modular Configuration Layout
- `config.kdl`: Master configuration file including modular definitions:
  - `cfg/keybinds.kdl`: Keyboard shortcuts (Mod=Super). Mod+Return for terminal, Mod+D for launcher, Mod+Arrows/HJKL for column/window movement.
  - `cfg/rules.kdl`: Window behavior rules:
    - Floating dialogs (file pickers, authentication, pavucontrol, etc.).
    - Rounded corners and border geometry.
    - Default column widths and max sizes.
  - `cfg/autostart.kdl`: Daemons started on login:
    - Status bar (Noctalia / Waybar), notification daemon, `cliphist` clipboard manager, wallpaper daemon.
  - `cfg/display.kdl`: Monitor outputs and refresh rates (e.g. DP-2, HDMI-A-1).
  - `cfg/env/`: Host-specific environment variables.

## Key Operational Rules & Testing
- Safe test keybind config without restarting compositor: `niri validate` or `niri msg action reload-config`.
- Inspect active windows/workspaces: `niri msg windows`, `niri msg workspaces`.
- Helper scripts: `zsh/.zsh/scripts/niri-window-switcher` or custom scratchpad scripts.
- Never add loose window scripts to `/usr/local/bin` directly; maintain them in `zsh/.zsh/scripts/`.

## Recent Changes
- Updated `noctalia/settings.json` to use relative paths for `avatarImage` and `wallpaper.directory`:
  - `avatarImage` changed from `/home/gidragir/.face` to `~/.face`.
  - `wallpaper.directory` changed from `/home/gidragir/Pictures/Wallpapers` to `~/Pictures/Wallpapers`.

## New Configurations & Hotkeys
- Added `cfg/keybinds.kdl` entry for Mod+Shift+Return to open a floating terminal.
- Updated `cfg/rules.kdl` to include new application-specific rules for better integration.
- Added new keybinds for AI assistants:
  - Mod+Alt+A: Khoj WebApp
  - Mod+Ctrl+A: Local AI Hub

## Additional Notes
- Ensure all paths in configuration files are relative to the user's home directory to maintain portability across different setups.
- Regularly update the `cfg/autostart.kdl` file to include the latest system utilities and services.
