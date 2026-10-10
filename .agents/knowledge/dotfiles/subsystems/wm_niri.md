# Subsystem: Niri Wayland Compositor (L1)

## Overview
Niri is a scrollable-tiling Wayland compositor configured declaratively using KDL syntax.
Configuration root: `home/dot_config/niri/` -> deployed via Chezmoi to `~/.config/niri/`.

## Modular Configuration Layout
- `config.kdl`: Master configuration file including modular definitions:
  - `cfg/keybinds.kdl`: Keyboard shortcuts (Mod=Super). Mod+Return for terminal, Mod+D for launcher, Mod+Arrows/HJKL for column/window movement.
  - `cfg/rules.kdl`: Window behavior rules:
    - Floating dialogs (file pickers, authentication, pavucontrol, etc.).
    - Rounded corners and border geometry.
    - Default column widths and max sizes.
  - `cfg/autostart.kdl`: Daemons started on login:
    - Status bar (Noctalia / Waybar), notification daemon, `cliphist` clipboard manager, wallpaper daemon.
  - `cfg/display.kdl.tmpl`: Monitor outputs and refresh rates templated by host chassis (`desktop`: DP-2, HDMI-A-1; `laptop`: eDP-1).
  - `cfg/env/`: Host-specific environment variables.

## Key Operational Rules & Testing
- Safe test keybind config without restarting compositor: `niri validate` or `niri msg action reload-config`.
- Inspect active windows/workspaces: `niri msg windows`, `niri msg workspaces`.
- Helper scripts: `home/dot_zsh/scripts/` (deployed to `~/.zsh/scripts/`).
- Never add loose window scripts to `/usr/local/bin` directly; maintain them in `home/dot_zsh/scripts/`.

## Noctalia Shell Architecture & Invariants (v5)
- **Runtime:** Native C++ Wayland layer-shell with Luau scripting engine.
- **Config Stack:** Base declarative config in `linked/noctalia/config.toml` (symlinked via Chezmoi to `~/.config/noctalia/config.toml`), overlaid by dynamic runtime state in `~/.local/state/noctalia/settings.toml`.
  - Invariant: Do not keep conflicting `[bar]` blocks in `settings.toml`; declarative layout belongs in `config.toml`.
  - Schema naming: Strict `snake_case` in TOML (`background_opacity`, `capsule_fill`, `font_weight`).
  - Color Tokens: `bar.<name>.color` sets text/icon color, NOT background fill. To guarantee readability against dark surfaces (Catppuccin Frappe/Mocha), set `color = "on_surface"` (`#c6d0f5`).
- **Bar Topology:** Active preset is single `islands` bar (`order = ["islands"]`).
  - Appearance: Translucent Catppuccin Frappe (`background_opacity = 0.82`, `compositor_blur = true`, `capsule_opacity = 0.85`, `border = "outline"`).
  - Audio: Native `volume` widget removed in favor of `blackbartblues/audio-switcher` (sink/source routing + volume).
  - LLM: `marccvictoria/llamanager` disabled and removed.
  - Headroom: Metric display defaults to `used` (consumed limit); for `remaining` (quota left), configure `display = "remaining"`.
  - Drive Health: Full SMART telemetry for NVMe drives requires the background collector unit `noctalia-drive-health.timer`.
- **Plugin & Panel Architecture (Luau):**
  - **Widget pattern:** In `widget.luau`, avoid simultaneous `barWidget.setGlyph()` and `barWidget.setText()` (causes overlap). Use `barWidget.render(ui.row({ gap = 6, align = "center" }, children))`.
  - **Dropdown Panels:** In `plugin.toml`, set `placement = "attached"`, `position = "auto"`, `open_near_click = true` so panels drop down directly under bar widgets rather than floating in screen center.
  - **Containers:** `ui.box` is strictly a childless leaf node (used for color swatches/squares). Grouped cards with children MUST use `ui.column` or `ui.row` (`fill = "surface_variant/0.25"`, `radius = 8`, `border = "outline"`, `borderWidth = 1`).
  - **Spacing:** Root panel layout must specify `padding = 14` on `ui.column({ flexGrow = 1, padding = 14, gap = 12 }, ...)`.
  - **Linting:** Always validate plugins with `noctalia plugins lint <path>`.
- **Validation & Sync:**
  - Check syntax: `rtk noctalia config validate`.
  - Lint plugins: `noctalia plugins lint linked/noctalia/plugins/<name>/`.
  - Apply changes: `rtk chezmoi apply --source /data/projects/dotfiles --force`.


## Recent Changes
- Updated `noctalia/settings.json` to use relative paths for `avatarImage` and `wallpaper.directory`:
  - `avatarImage` changed from `/home/gidragir/.face` to `~/.face`.
  - `wallpaper.directory` changed from `/home/gidragir/Pictures/Wallpapers` to `~/Pictures/Wallpapers`.
- Redesigned Noctalia top bar to Catppuccin Frappe `islands` preset with blur, custom plugins, and removed standard `volume` widget.

## New Configurations & Hotkeys
- Added `cfg/keybinds.kdl` entry for Mod+Shift+Return to open a floating terminal.
- Updated `cfg/rules.kdl` to include new application-specific rules for better integration.
- Added new keybinds for AI assistants:
  - Mod+Alt+A: Khoj WebApp
  - Mod+Ctrl+A: Local AI Hub

## Additional Notes
- Ensure all paths in configuration files are relative to the user's home directory to maintain portability across different setups.
- Regularly update the `cfg/autostart.kdl` file to include the latest system utilities and services.

