# ADR 0004: Noctalia Shell v5 Architecture & Luau Plugin Guidelines

- **Status:** Accepted
- **Date:** 2026-10-09
- **Context:**
  Following the upgrade to Noctalia Shell v5.2+ on CachyOS, existing QML-based plugins from Noctalia v4 broke, and newly migrated Luau plugins encountered several runtime issues:
  1. Panels popped up centered on the screen instead of dropping down directly from their clicked bar widgets.
  2. Plugin catalogs failed validation when using legacy `[[plugins]]` table syntax instead of `[[plugin]]`.
  3. Bar widget instances were missing from both base configuration (`config.toml`) and runtime state (`settings.toml`).
  4. Luau UI tree parser rejected `ui.box` containing children (`ui tree: 'box' cannot have children, 1 dropped`).
  5. Luau UI tree parser rejected invalid Material Design 3 tokens (e.g. `surface_container_low`), and required semantic role/alpha syntax (`surface_variant/0.25`).
  6. Panels suffered from lack of edge padding, rendering content directly against the window borders.

- **Decision:**
  1. **Panel Attachment & Positioning:**
     - For bar widget dropdown panels, declare in `plugin.toml`:
       ```toml
       [[panel]]
       id = "panel"
       entry = "panel.luau"
       placement = "attached"
       position = "auto"
       open_near_click = true
       ```
     - For standalone floating side-panels (like full-screen notes or scratchpads), use `placement = "floating"`, `position = "center_right"`.
  2. **Catalog & Registration Schema:**
     - In `linked/noctalia/plugins/catalog.toml`, use `[[plugin]]` entries strictly.
     - In `linked/noctalia/config.toml` and `~/.local/state/noctalia/settings.toml`, register widget instances under `[widget.<id>]` (`type = "<author>/<plugin>:<entry>"`) and place their IDs into `[bar.<name>.end]` or `[bar.<name>.start]`.
  3. **Luau Container Tree Rules:**
     - `ui.box` is strictly a leaf container without children (used for color squares, spacers, or fixed graphical swatches).
     - Card containers and sections with child elements MUST use `ui.column` or `ui.row`:
       ```luau
       ui.column({
         fill = "surface_variant/0.25",
         radius = 8,
         border = "outline",
         borderWidth = 1,
         padding = 10,
         gap = 8,
       }, { ... })
       ```
  4. **Color Tokens & Opacity:**
     - Valid semantic roles in Noctalia v5: `surface`, `surface_variant`, `primary`, `secondary`, `tertiary`, `outline`, `on_surface`, `on_surface_variant`, `on_primary`.
     - Opacity is passed via slash notation: `"<role>/<alpha>"` (e.g. `fill = "surface_variant/0.25"`).
  5. **Panel Layout & Spacing:**
     - Always wrap the root panel content with `padding = 14` and `gap = 12` in `panel.render(ui.column({ flexGrow = 1, padding = 14, gap = 12 }, ...))`.
     - Use `variant = "ghost"` for header controls (close, refresh) and `variant = "primary"` / `"outline"` for action buttons.
  6. **Validation Pipeline:**
     - Always lint plugins via `noctalia plugins lint <path>`.
     - Inspect runtime layer-shell attachment via `~/.cache/noctalia/noctalia.log` looking for `panel manager: opened "<id>" as attached layer-shell`.

- **Consequences:**
  - All bar dropdown panels render with zero visual artifacts, uniform Catppuccin theming, and drop down seamlessly beneath their bar icons.
  - Zero warnings or dropped nodes in `noctalia.log`.
