# Audio Outputs (`gidragir/audio-outputs`)

A modern, high-performance Noctalia Shell plugin for seamless audio output switching with hybrid PipeWire sink synthesis and GPU HDMI profiles support.

---

## Overview

On modern Linux systems with dedicated graphics cards (such as NVIDIA GeForce RTX), multiple display sinks (e.g. ultra-wide display, TV, AVR) may be connected to the same GPU. Due to ALSA Card Profile (ACP) and PipeWire architecture, a sound card only instantiates active PulseAudio/PipeWire sinks for its *currently active card profile*. Inactive HDMI outputs remain hidden at the card profile level and do not appear as selectable sinks in standard audio switchers.

`audio-outputs` solves this limitation by:
1. Synthesizing both active PipeWire sinks and valid GPU card profiles into a single, unified device list.
2. Managing automatic card profile transitions (`pactl set-card-profile`) with asynchronous sink discovery and safe rollback on timeout.
3. Automatically migrating all active audio streams (`sink-inputs`) to newly selected sinks without interruption or stream drops.
4. Preserving device identities and custom aliases through a persistent device cache (`knownDevices`).

---

## Architecture

The plugin is structured into modular components:

```
audio-outputs/
├── plugin.toml             # Manifest (id: "gidragir/audio-outputs", plugin_api = 32)
├── service.luau            # Background service (owns pactl subprocesses, stream tracking, state sync)
├── lib/
│   └── parser.luau         # Pure functional parser (pactl JSON -> normalized snapshot model)
├── panel.luau              # Attached flyout panel (volume slider, output list, alias editor)
├── widget.luau             # Status bar widget (volume icon, percentage, tooltip, click & scroll bindings)
├── launcher.luau           # Noctalia Launcher provider (prefix "audio", quick search & switch)
├── translations/           # Localization dictionaries
│   ├── en.json             # English
│   └── ru.json             # Russian
├── tests/                  # Unit and integration test suites
│   ├── parser_test.lua
│   ├── service_test.lua
│   ├── widget_launcher_test.lua
│   └── fixtures/           # Captured pactl sink & card JSON fixtures
└── README.md
```

### Component Roles

- **`service.luau`**:
  - The single source of truth and sole owner of child processes executing `pactl`.
  - Runs continuous asynchronous monitoring via `pactl subscribe`.
  - Maintains state snapshot (`audio_outputs_snapshot`) in `noctalia.state`.
  - Orchestrates asynchronous device switching with two-phase commit:
    - Active sinks: Immediate `set-default-sink` and stream migration.
    - Card profiles: Profile activation -> event-driven sink wait (3.5s timeout) -> `set-default-sink` -> stream migration -> rollback FSM on failure.
  - Handles debounced volume and mute changes with rate-limiting queues.
- **`lib/parser.luau`**:
  - Pure, deterministic parsing and filtering functions without global state or I/O.
  - Merges active sinks with GPU HDMI profiles, filtering out unused redundant surround profiles and inactive dummy ports.
  - Resolves display names via EDID/ELD metadata, card port properties, or user aliases.
- **`panel.luau`**:
  - Flyout panel following Noctalia design tokens (`surface_container`, `outline_variant`, `primary`, etc.).
  - Displays current active output, interactive volume slider, and output cards.
  - Supports inline alias editing and visibility toggles.
- **`widget.luau`**:
  - Bar widget displaying dynamic volume icons (`volume-2`, `volume-1`, `volume-x`), percentage, and error badges.
  - Supports left-click (toggle panel), right-click (cycle through outputs), and scroll wheel (volume adjustment).
- **`launcher.luau`**:
  - Exposes audio outputs as launcher items matching prefix `audio`.
  - Displays currently active sink, volume levels, and enables direct 1-click output switching.

---

## Hardware Quirks & Behavior

### NVIDIA GPU HDMI / DisplayPort Profiles
NVIDIA cards (e.g. RTX 4070 Ti Super) expose multiple HDMI/DisplayPort audio endpoints on a single PCI function. PipeWire ACP creates an active sink only for the selected profile (e.g. `output:hdmi-stereo` for DisplayPort 0 / Monitor, or `output:hdmi-stereo-extra1` for HDMI / TV).
When switching to an inactive profile, the card must be reconfigured before PipeWire will instantiate the corresponding sink node.

### WirePlumber & PipeWire ACP Persistence
WirePlumber remembers device volume and stream-to-sink affinities. When `audio-outputs` migrates streams (`pactl move-sink-input`), WirePlumber updates its internal state store (`~/.local/state/wireplumber/`), ensuring newly spawned applications route to the newly selected default output.

### Persistent Device Registry (`knownDevices`)
When an HDMI device (e.g. TV) is turned off or placed into standby, ALSA reports its port as `availability: not available`, and PipeWire may omit product strings.
`audio-outputs` persists verified device names in `~/.config/noctalia/plugins_data/gidragir_audio-outputs/preferences.json`:
- When a device is active and detected, its EDID/ELD name (`device.product.name`) is saved in `knownDevices`.
- When turned off or in standby, the device remains listed as `Disconnected / Standby` with its known name, allowing one-click reactivation ("Use").
- Empty ports that have never been connected and have no user alias are automatically omitted to prevent visual noise.

---

## Configuration Settings

Configure these in Noctalia Settings or directly in `~/.config/noctalia/plugins.json`:

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `show_percentage` | `bool` | `true` | Show numeric volume percentage next to the bar icon |
| `show_notification_on_switch` | `bool` | `true` | Display a system notification when the audio output changes |
| `show_disconnected` | `bool` | `true` | Show disconnected/standby outputs in the panel list |

---

## IPC Interface

The plugin service listens for IPC messages dispatched to `plugin gidragir/audio-outputs:service all <command>` or written to the `audio_outputs_command` state slot:

| Command | Arguments | Description |
| :--- | :--- | :--- |
| `set-output` | `<outputId>` | Switch default audio output to target sink or profile ID |
| `cycle-output` | _none_ | Cycle to the next available output in sequence |
| `volume-up` | `[delta]` | Increase volume by delta percentage (default: 5) |
| `volume-down` | `[delta]` | Decrease volume by delta percentage (default: 5) |
| `volume-set` | `<0..100>` | Set output volume to an exact percentage |
| `mute-toggle` | _none_ | Toggle mute on active default sink |
| `refresh` | _none_ | Force immediate state refresh from `pactl` |
| `set-alias` | `<id> [alias]` | Assign or clear a custom alias for an output |
| `set-icon` | `<id> [icon]` | Assign or clear a custom icon for an output |
| `toggle-hidden` | `<id>` | Toggle visibility of an output in the UI list |

### Example IPC Invocations

```bash
# Cycle to next audio output via Noctalia IPC
qs -c noctalia-shell ipc call plugin gidragir/audio-outputs:service all cycle-output

# Increase volume by 5%
qs -c noctalia-shell ipc call plugin gidragir/audio-outputs:service all volume-up

# Set specific output
qs -c noctalia-shell ipc call plugin gidragir/audio-outputs:service all set-output sink:alsa_output.pci-0000_00_1f.3.analog-stereo
```

---

## Testing and Debugging

### Running Automated Test Suites

The test suite runs offline without requiring a running display server or Noctalia instance:

```bash
cd linked/noctalia/plugins/audio-outputs

# 1. Pure parser and model unit tests
rtk lua tests/parser_test.lua

# 2. Service state machine, FSM rollback, and debounce tests
rtk lua tests/service_test.lua

# 3. Bar widget and launcher integration tests
rtk lua tests/widget_launcher_test.lua

# 4. Manifest and schema validation
rtk noctalia plugins lint linked/noctalia/plugins/audio-outputs
```

### Live Diagnostics

To inspect the PipeWire state on the host:

```bash
# Check current default sink
rtk pactl get-default-sink

# List active sinks in JSON format
rtk pactl -f json list sinks | rtk jq -r '.[].name'

# List cards and their active profiles
rtk pactl -f json list cards | rtk jq -r '.[] | "\(.name) active=\(.active_profile)"'

# Inspect ELD monitor information
rtk rg 'monitor_name|monitor_present' /proc/asound/card*/eld*
```

---

## License

MIT License. See [LICENSE](LICENSE).
