# 🌐 Vivaldi Browser Configuration

## Flags Configuration File: `~/.config/vivaldi-stable.conf`

Vivaldi reads persistent user command-line flags from `~/.config/vivaldi-stable.conf`. This file is managed in dotfiles via GNU Stow (`vivaldi/.config/vivaldi-stable.conf`) and persists across system-wide browser updates.

### Syntax Warning
The `.conf` file is parsed directly by the `/usr/bin/vivaldi-stable` launcher script.
- Do **NOT** use quotes (`"..."`) or variable assignments (`VIVALDI_USER_FLAGS=...`).
- Flags must be written directly (one flag per line or space-separated).

### Wayland & Native Integration (Niri / CachyOS)

To ensure native Wayland rendering and correct DBus notification integration under **Niri** (CachyOS Desktop Environment), use:

```bash
--enable-features=UseOzonePlatform
--ozone-platform=wayland
```

## Desktop Notifications (DBus)

Vivaldi automatically routes browser notifications to the system notification daemon via DBus (`org.freedesktop.Notifications`) when running in a Wayland session.

- **No browser toggle required**: There is no manual notification style toggle inside Vivaldi settings on Linux.
- **System Notification Daemon**: In CachyOS Niri, notifications are handled by **Quickshell**. Ensure the notification daemon is running so Vivaldi routes popups to the system rather than spawning separate browser windows as fallbacks.
- **Verification**: You can test system notifications via terminal using `notify-send "Test" "Hello"` or by visiting web notification test sites.