# Noctalia OpenRGB

A Noctalia Shell plugin for controlling OpenRGB profiles, colors, brightness, and optional ratbag-compatible devices.

## Features

- Show the active RGB profile in the bar.
- Apply saved OpenRGB profiles and virtual color presets.
- Set a color and brightness from the panel.
- Save and delete OpenRGB profiles.
- Keep state in `~/.config/OpenRGB`.

## Requirements

- Noctalia Shell 3.9.0 or newer.
- `bash`, `jq`, and `openrgb` on `PATH`.
- Optional: `ratbagctl` for mouse LED control.

The plugin is Linux-specific. OpenRGB hardware access must already work for the user running Noctalia Shell.

## Installation

Clone the repository into the Noctalia plugin directory:

```bash
git clone https://github.com/gidragir/noctalia-openrgb ~/.config/noctalia/plugins/openrgb
```

Enable `openrgb` in `~/.config/noctalia/plugins.json`, add `plugin:openrgb` to a bar or panel widget, and reload Noctalia Shell:

```bash
qs -c noctalia-shell ipc call noctalia reload
```

## Device configuration

Copy the example configuration and edit it for the local machine:

```bash
cp ~/.config/noctalia/plugins/openrgb/scripts/config/devices.conf.example \
  ~/.config/noctalia/plugins/openrgb/scripts/config/devices.conf
```

`devices.conf` is intentionally machine-specific and is not part of the public repository.

## Helper API

```bash
scripts/openrgb-helper.sh list
scripts/openrgb-helper.sh apply <profile|off>
scripts/openrgb-helper.sh set_color <hex>
scripts/openrgb-helper.sh set_brightness <0-100>
scripts/openrgb-helper.sh save <name>
scripts/openrgb-helper.sh delete <name>
```

Hardware commands are best effort: OpenRGB or ratbag failures do not prevent the plugin from updating its local state.

## License

MIT. See [LICENSE](LICENSE).
