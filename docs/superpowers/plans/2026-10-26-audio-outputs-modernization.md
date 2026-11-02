# Audio Outputs Modernization & 1:1 Audio Switcher Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform `gidragir/audio-outputs` into a self-contained, modern, high-quality audio switcher matching `blackbartblues/audio-switcher` 1:1 in UI/UX and feature completeness (dual Sound/Microphone volume cards, Outputs/Inputs tabs, Bluetooth devices, output groups, cycle, device customization) while adding seamless PipeWire ALSA Card Profile (ACP) switching for GPU HDMI/DP receivers (TV and monitors).

**Architecture:** Self-contained Luau plugin architecture for Noctalia Shell v5.3+ (`plugin_api = 32`). Elimination of external `dofile`/`require` module imports in `service.luau` to prevent Luau sandbox crashes. Unified state publishing to `audio_outputs_snapshot` via `noctalia.state`, dual-channel volume debounce, and PipeWire stream migration.

**Tech Stack:** Luau, PipeWire 1.6 (`pactl` JSON & stream subscribe), WirePlumber 0.5, BlueZ (`bluetoothctl`), Noctalia Shell UI DSL.

**Spec:** [docs/superpowers/specs/2026-10-26-audio-outputs-design.md](file:///home/gidragir/projects/dotfiles/docs/superpowers/specs/2026-10-26-audio-outputs-design.md)

## Global Constraints

- Plugin ID remains `gidragir/audio-outputs` in `plugin.toml` and Noctalia config.
- Zero external file requirements (`dofile`, `require("lib.parser")`) inside runtime Luau scripts to ensure sandbox compatibility.
- Prefix all shell and terminal operations with `rtk` (Rust Token Killer).
- Strictly use `fd` and `rg` for search operations.
- Localization: complete English (`en.json`) and Russian (`ru.json`) translations.
- UI styling must strictly use Noctalia theme color tokens (`surface_variant`, `outline`, `primary`, `on_surface`, `on_surface_variant`, `error`).

## Review Focus

1. **Service Startup Stability:** Service must never crash on load; `audio_outputs_snapshot` must be published immediately on launch so the panel never falls back to an empty placeholder.
2. **Dual-Channel Volume & Mute:** Sound and Microphone sliders must independently update, debounce changes, and reconcile without freezing or jitter.
3. **Card Profile (HDMI/TV) Integration:** Inactive GPU HDMI/DP ports with connected or known devices must appear in the Outputs list and switch cleanly via `pactl set-card-profile` with stream migration.
4. **Bluetooth Connectivity:** Bluetooth audio devices must be discovered, displayed with slots/status, and support pairing/connecting through `Connect & use`.
5. **Noctalia Bar & Launcher Integration:** Bar widget and launcher actions must open the correct panel ID `gidragir/audio-outputs:audio-outputs`.

---

### Task 1: Complete Translations (English and Russian)

**Files:**
- Modify: `linked/noctalia/plugins/audio-outputs/translations/en.json`
- Modify: `linked/noctalia/plugins/audio-outputs/translations/ru.json`

- [ ] Add all localization strings matching `audio-switcher` schema: `actions`, `device`, `editor`, `errors`, `launcher`, `notifications`, `panel`, `settings`, `widget`.
- [ ] Add strings specific to card profile switching (`device.profile`, `device.gpu_output`, `notifications.profile_switched`).
- [ ] Verify both JSON files are valid JSON via `rtk jq . <file>`.

---

### Task 2: Modernized Manifest `plugin.toml`

**Files:**
- Modify: `linked/noctalia/plugins/audio-outputs/plugin.toml`

- [ ] Define plugin metadata (`id = "gidragir/audio-outputs"`, `name = "Audio Outputs"`, `plugin_api = 32`, `dependencies = ["pactl", "bluetoothctl", "sleep"]`).
- [ ] Configure `[[widget]]` with volume scroll and click actions (toggle panel, cycle output, cycle input).
- [ ] Configure `[[panel]]` with dimensions (width = 620, height = 650, placement = "attached", position = "top_right", open_near_click = true).
- [ ] Configure `[[launcher_provider]]` with prefix `audio` and glyph `switch-horizontal`.
- [ ] Configure `[[service]]` with entry `service.luau`.
- [ ] Validate TOML formatting.

---

### Task 3: Self-Contained Service Backend (`service.luau`)

**Files:**
- Modify: `linked/noctalia/plugins/audio-outputs/service.luau`

- [ ] Remove all `dofile` and external `require` calls. Embed all parsing and normalization functions directly.
- [ ] Implement robust `pactl` and `bluetoothctl` execution helpers with `LC_ALL=C`.
- [ ] Implement `loadAudio`: query `pactl -f json info`, `pactl list short modules`, `pactl -f json list sinks`, `pactl -f json list sources`, and `pactl -f json list cards`.
- [ ] Implement GPU HDMI/DP card profile discovery: extract monitor names from port properties (`device.product.name`) and synthesize profile output items into `snapshot.outputs`.
- [ ] Implement `setOutput`: handle both `sink` (immediate `set-default-sink` + `move-sink-input`) and `profile` (`set-card-profile` + await spawned sink + `set-default-sink` + `move-sink-input`).
- [ ] Implement `setInput`: handle `set-default-source` and source port switching.
- [ ] Implement Bluetooth scanning, connection retry loop, and slot keybind assignment.
- [ ] Implement volume debounce & display reconciliation for both `output` and `input`.
- [ ] Implement output groups creation/disband via `module-combine-sink`.
- [ ] Implement `LC_ALL=C pactl subscribe` event stream monitoring for sink, source, and server changes.
- [ ] Implement IPC handler `onIpc(event, payload)` and `audio_outputs_command` watcher.
- [ ] Publish complete `snapshot` to `audio_outputs_snapshot` on every change and initial startup.

---

### Task 4: Interactive Panel UI (`panel.luau`) 1:1 Parity

**Files:**
- Modify: `linked/noctalia/plugins/audio-outputs/panel.luau`

- [ ] Update panel dimensions and bindings to read `audio_outputs_snapshot` and write to `audio_outputs_command`.
- [ ] Header: Switch/arrow glyph, title "Audio Outputs", subtitle (Current Sound · Current Microphone), action buttons (Bluetooth scan, Refresh, Settings, Close).
- [ ] Dual Volume Cards:
  - Sound Card: glyph, name, percentage, mute button, volume slider with debounce tracking.
  - Microphone Card: mic glyph, name, percentage, mute button, volume slider with debounce tracking.
- [ ] Tab Switcher: `Outputs` and `Inputs` tabs with badge counts and selection styling.
- [ ] Top Controls: `Visible N`, `Hidden` toggle button, `Cycle` button, `Group outputs` button.
- [ ] Group Outputs Mode: multi-select checkboxes for available sinks, "Create group" / "Cancel" buttons.
- [ ] Device Items:
  - Icon (automatic or custom style: speaker, over_ear, tws, wired), title, subtitle/port.
  - Badges: `Current` (for default output/input), `Use` (for available outputs/profiles), `Connect & use` (for Bluetooth), slot `#N`.
  - Inline Device Editor: display name alias, slot number input, icon style selector, save/cancel buttons.
  - Hide/Show toggle button (`eye` / `eye-off`).
- [ ] Footer text explaining hidden device cycling and Bluetooth slots.

---

### Task 5: Widget & Launcher Components

**Files:**
- Modify: `linked/noctalia/plugins/audio-outputs/widget.luau`
- Modify: `linked/noctalia/plugins/audio-outputs/launcher.luau`

- [ ] `widget.luau`: Watch `audio_outputs_snapshot`, display active output glyph and volume %, set comprehensive tooltip (current output, input, and mouse gesture hints).
- [ ] `launcher.luau`: Handle `onQuery` and `onActivate` for `audio` query to toggle `gidragir/audio-outputs:audio-outputs`.

---

### Task 6: Unit Testing & Host Verification

**Files:**
- Create/Modify: `linked/noctalia/plugins/audio-outputs/tests/modern_service_test.lua`

- [ ] Write standalone Lua test validating:
  1. JSON parsing of sinks, sources, cards.
  2. ACP profile synthesis (extracting HDMI monitor names and non-duplicate profiles).
  3. Sound & mic volume parsing.
  4. Bluetooth device parsing.
  5. Command dispatcher routing.
- [ ] Run test suite with `rtk lua tests/modern_service_test.lua`.
- [ ] Verify Noctalia config and trigger panel toggle via `rtk noctalia msg panel-toggle gidragir/audio-outputs:audio-outputs`.
