# noctalia-obsidian

A native Obsidian companion plugin for [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell).

Track today's tasks directly in the top bar, quickly capture notes and to-dos without leaving your workflow, explore tags, and manage vault synchronization from a sleek flyout hub.

![Obsidian Companion Preview](preview.png)

## Features

- 📌 **Live Bar Indicator**:
  - Displays pending/completed markdown tasks from today's daily note (`3` or `✓ 2/5`).
  - Sync state indicator dot (active syncing / error alert).
  - Rich tooltip with note date, progress, and quick action hints.
- ⚡ **Obsidian Hub Flyout Panel**:
  - **Daily Note Overview**: View date, task completion progress, and interactive checkboxes to toggle `- [ ]` <-> `- [x]` markdown tasks in-place.
  - **Quick Capture**: Instantly append tasks or timestamped notes to Today's Daily Note (or Inbox).
  - **Quick Actions**:
    - Open Today's Note in **Neovim** (Ghostty) or **Obsidian Desktop App** (`obsidian://` URI).
    - **Explore Tags** with interactive TUI (`khoj-tags` + Glow markdown renderer).
    - **Search Notes** with fuzzy finder and live preview.
    - **Sync Vault Now** via user systemd unit (`rclone-obsidian-sync.service`) or `rclone bisync`.
- ⌨️ **IPC & Keybinding Integration**:
  - Control panel and capture from terminal or window manager shortcuts via `noctalia-shell ipc call plugin:obsidian <method>`.
- ⚙️ **Configurable & Bilingual**:
  - Settings UI in Noctalia Settings -> Plugins.
  - Vault path, daily notes folder, preferred editor, badge modes (`pending`, `fraction`, `icon-only`), and refresh intervals.
  - Complete English and Russian translations (`en`, `ru`).

---

## Installation

### Method 1: Noctalia Plugin Manager
When available in the official Noctalia Plugins repository:
1. Open Noctalia Settings (`Super+,` or click Settings icon).
2. Navigate to **Plugins** -> **Available**.
3. Search for **Obsidian Companion** and click **Install**.
4. Enable the plugin.
5. In **Bar Settings**, add `plugin:obsidian` to your desired bar section (e.g. `Right`).

### Method 2: Manual / Dotfiles
Clone or link into your Noctalia plugins directory:
```bash
git clone https://github.com/gidragir/noctalia-obsidian ~/.config/noctalia/plugins/obsidian
```

Add `obsidian` to `~/.config/noctalia/plugins.json`:
```json
{
  "states": {
    "obsidian": {
      "enabled": true
    }
  }
}
```

Add `"plugin:obsidian"` to your widgets in `~/.config/noctalia/settings.json`:
```json
"widgets": {
  "right": [
    { "id": "plugin:obsidian" }
  ]
}
```

Reload Noctalia Shell:
```bash
qs -c noctalia-shell ipc call noctalia reload
```

---

## IPC API

All methods are callable from any script or hotkey:

```bash
# Toggle Obsidian Hub panel
qs -c noctalia-shell ipc call plugin:obsidian toggle

# Open or close Hub panel
qs -c noctalia-shell ipc call plugin:obsidian open
qs -c noctalia-shell ipc call plugin:obsidian close

# Quick capture a task or note
qs -c noctalia-shell ipc call plugin:obsidian capture "Review PR #42" "task"
qs -c noctalia-shell ipc call plugin:obsidian capture "Idea for local AI stack" "note"

# Open today's daily note in editor
qs -c noctalia-shell ipc call plugin:obsidian openDaily "neovim"
qs -c noctalia-shell ipc call plugin:obsidian openDaily "obsidian"

# Trigger background vault sync
qs -c noctalia-shell ipc call plugin:obsidian sync

# Refresh status immediately
qs -c noctalia-shell ipc call plugin:obsidian refresh
```

### Niri Keybinding Example (`config.kdl`)
```kdl
binds {
    Mod+Shift+O { spawn "qs" "-c" "noctalia-shell" "ipc" "call" "plugin:obsidian" "toggle"; }
}
```

---

## Settings Reference

| Setting | Default | Description |
| :--- | :--- | :--- |
| `vaultPath` | `/data/obsidian` | Absolute path to your Obsidian vault |
| `dailyFolder` | `DAILY` | Subfolder within the vault for daily notes |
| `dailyFormat` | `YYYY-MM-DD` | Filename naming convention for daily notes |
| `preferredEditor` | `neovim` | Editor: `neovim`, `obsidian`, or `xdg-open` |
| `showBadge` | `true` | Show task counter badge on bar widget |
| `badgeMode` | `pending` | Mode: `pending` (e.g. 3), `fraction` (2/5), `icon-only` |
| `refreshIntervalSec` | `15` | Background task check interval in seconds |
| `syncService` | `rclone-obsidian-sync.service` | User systemd unit for vault sync |
| `panelPosition` | `follow_launcher` | Flyout position on screen |

---

## License

MIT License © 2026 gidragir
