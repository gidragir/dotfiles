# Audio Outputs Noctalia Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать плагин `gidragir/audio-outputs` для Noctalia Shell v5.3.0, объединяющий активные стоки PipeWire и неактивные HDMI-профили карты NVIDIA в единый список для бесшовного переключения выходов с миграцией потоков.

**Architecture:** Модульный плагин Noctalia: `service.luau` — единственный владелец подпроцессов `pactl`, подписывается на события `pactl subscribe` через `runStream` и управляет очередью команд; чистая библиотека `lib/parser.luau` синтезирует единый список стоков и профилей с разрешением имен через ELD/EDID и кэш `knownDevices`; `panel.luau`, `widget.luau` и `launcher.luau` отображают состояние и передают действия через IPC.

**Tech Stack:** Luau/Lua 5.5, Noctalia Plugin API v32, PipeWire 1.6 / WirePlumber 0.5, PulseAudio CLI (`pactl`), Linux ALSA `/proc/asound`.

**Spec:** `/home/gidragir/projects/dotfiles/docs/superpowers/specs/2026-10-26-audio-outputs-design.md`

## Global Constraints
- Target directory: `/home/gidragir/projects/dotfiles/linked/noctalia/plugins/audio-outputs/`
- Manifest identifier: `id = "gidragir/audio-outputs"`
- Noctalia API version: `plugin_api = 32`
- Luau nonstrict mode: `--!nonstrict` at the top of Luau files
- Styling: Catppuccin Frappe tokens only (no hardcoded hex colors); `ui.box` is strictly leaf; cards use `ui.column`/`ui.row`
- Shell commands: prefix with `rtk` in terminal executions; quotes via `shellQuote` in Luau
- Configuration: do not break existing `blackbartblues/audio-switcher` in `config.toml`

## Review Focus
1. **Таймаут спавна стока при неработающем HDMI-приёмнике:** Если ТВ отключен от питания и сток не появляется за 3.5 с, плагин обязан откатить профиль карты, восстановить исходный сток и вернуть ошибку в результат без падения UI.
2. **Множественные быстрые переключения выходов:** При серии кликов пользователя очередь команд должна сериализоваться (`busy` guard), предотвращая гонки и рассинхронизацию PipeWire.
3. **Фильтрация пустых портов видеокарты:** Порты `hdmi-output-2` и `hdmi-output-3` без подключенных мониторов и без алиасов не должны засорять интерфейс.
4. **Сброс default sink на встроенный звук:** При переключении профиля WirePlumber временно переводит default sink на `Built-in Audio`; плагин обязан явно дождаться появления нового стока и назначить его.
5. **Сохранение и дебаунс громкости:** Быстрый скролл колесом мыши в виджете или слайдере не должен спавнить лавину процессов `pactl`.

---

### Task 1: Scaffolding, Manifest, Translations and Test Fixtures

**Files:**
- Create: `linked/noctalia/plugins/audio-outputs/plugin.toml`
- Create: `linked/noctalia/plugins/audio-outputs/translations/en.json`
- Create: `linked/noctalia/plugins/audio-outputs/translations/ru.json`
- Create: `linked/noctalia/plugins/audio-outputs/tests/fixtures/sinks.json`
- Create: `linked/noctalia/plugins/audio-outputs/tests/fixtures/cards.json`
- Create: `linked/noctalia/plugins/audio-outputs/LICENSE`

**Interfaces:**
- Produces: `plugin.toml` manifest with `plugin_api = 32`, declared settings `show_percentage`, `show_notification_on_switch`, `show_disconnected`.
- Produces: JSON fixtures captured from host `pactl -f json list sinks` and `cards`.

- [x] **Step 1: Create plugin directory and capture real pactl fixtures from host**

```bash
mkdir -p linked/noctalia/plugins/audio-outputs/tests/fixtures
mkdir -p linked/noctalia/plugins/audio-outputs/translations
mkdir -p linked/noctalia/plugins/audio-outputs/lib
rtk pactl -f json list sinks > linked/noctalia/plugins/audio-outputs/tests/fixtures/sinks.json
rtk pactl -f json list cards > linked/noctalia/plugins/audio-outputs/tests/fixtures/cards.json
```

- [x] **Step 2: Create `plugin.toml` manifest**

Define ID `gidragir/audio-outputs`, `plugin_api = 32`, tags, settings, actions, widget, panel, service, and launcher provider declarations.

- [x] **Step 3: Create translation files (`en.json` and `ru.json`)**

Define keys for settings labels/descriptions, status labels (`available`, `disconnected`, `active`, `current`, `use`), errors (`command_start`, `sink_spawn_timeout`, `pactl_missing`), actions, and tooltip entries.

- [x] **Step 4: Create MIT LICENSE file**

- [x] **Step 5: Run lint check**

Run: `rtk noctalia plugins lint linked/noctalia/plugins/audio-outputs`
Expected: 0 errors (warnings about missing entry files are expected until implemented).

---

### Task 2: Pure Parser and Model Engine (`lib/parser.luau` + TDD)

**Files:**
- Create: `linked/noctalia/plugins/audio-outputs/lib/parser.luau`
- Create: `linked/noctalia/plugins/audio-outputs/tests/parser_test.lua`

**Interfaces:**
- Produces: `parser.buildOutputs(sinks, cards, defaultSinkName, preferences, eldData) -> OutputItem[]`
- Produces: `parser.findHdmiMonitorName(card, portName, eldData) -> string?`
- Produces: `parser.matchSinkForProfile(cardName, profileName, sinks) -> SinkItem?`

- [x] **Step 1: Write failing parser unit test in `tests/parser_test.lua`**

Test scenarios:
1. Synthetic cards + sinks: active HDMI sink identified as `kind = "sink"`, `isDefault = true`, `displayName = "LG ULTRAWIDE"`.
2. Inactive HDMI profile `output:hdmi-stereo-extra1` identified as `kind = "profile"`, `available = false` (or `true` when connected), `displayName = "Panasonic-TV"` via ELD or `knownDevices`.
3. Unused GPU ports (HDMI 3, HDMI 4) filtered out when not in `knownDevices` and no alias exists.
4. Correct icon detection based on port type and device description.

- [x] **Step 2: Run test to verify it fails**

Run: `cd linked/noctalia/plugins/audio-outputs && rtk lua tests/parser_test.lua`
Expected: FAIL (module `lib/parser.luau` not found).

- [x] **Step 3: Implement `lib/parser.luau`**

Implement pure Luau functions:
- Extraction of monitor names from `port.properties["device.product.name"]` and ELD lines.
- Filtering of duplicate surround profiles (`surround*` ignored when stereo equivalent exists).
- Merging active sinks with valid inactive profiles.
- Sorting: active default first, then available sinks, then available profiles, then disconnected known devices.

- [x] **Step 4: Run test to verify it passes**

Run: `cd linked/noctalia/plugins/audio-outputs && rtk lua tests/parser_test.lua`
Expected: PASS with "parser tests: ok".

---

### Task 3: Backend Service Daemon (`service.luau`)

**Files:**
- Create: `linked/noctalia/plugins/audio-outputs/service.luau`
- Create: `linked/noctalia/plugins/audio-outputs/tests/service_test.lua`

**Interfaces:**
- Consumes: `lib/parser.luau`
- Produces: State `audio_outputs_snapshot` in `noctalia.state`
- Produces: IPC handler `onIpc(sender, message)` supporting:
  - `set-output <outputId>`
  - `cycle-output`
  - `volume-up`
  - `volume-down`
  - `volume-set <val>`
  - `mute-toggle`
  - `refresh`

- [x] **Step 1: Write service integration unit test in `tests/service_test.lua`**

Mock `noctalia` runtime (`runAsync`, `runStream`, `state`, `pluginDataDir`).
Verify:
1. Initial refresh publishes valid snapshot to `audio_outputs_snapshot`.
2. Switching `kind == "sink"` triggers `pactl set-default-sink` and `pactl move-sink-input`.
3. Switching `kind == "profile"` triggers `set-card-profile`, waits for stream event, and commits default sink.
4. Timeout in profile switch triggers rollback to `previousCardProfile` and restores `previousSink`.
5. Volume debounce batches rapid volume changes.

- [x] **Step 2: Run test to verify it fails**

Run: `cd linked/noctalia/plugins/audio-outputs && rtk lua tests/service_test.lua`
Expected: FAIL (file `service.luau` not found).

- [x] **Step 3: Implement `service.luau`**

- Subscribe to `pactl subscribe` via `noctalia.runStream`.
- Fallback polling timer via `noctalia.setUpdateInterval(3000)`.
- Command queue with FSM rollback for profile activation timeout.
- Preferences management (`preferences.json`: `knownDevices`, `aliases`, `hiddenOutputs`, `icons`).
- Safe execution via `noctalia.runAsync` with quoted shell arguments.

- [x] **Step 4: Run test to verify it passes**

Run: `cd linked/noctalia/plugins/audio-outputs && rtk lua tests/service_test.lua`
Expected: PASS with "service tests: ok".

---

### Task 4: Panel UI (`panel.luau`)

**Files:**
- Create: `linked/noctalia/plugins/audio-outputs/panel.luau`

**Interfaces:**
- Consumes: State `audio_outputs_snapshot` via `noctalia.state.watch`
- Produces: UI component structure matching Noctalia guidelines:
  - Header with title and refresh button.
  - Active output card (`ui.column`, `fill = "surface_variant/0.45"`, `radius = 12`) with volume slider and mute toggle.
  - Outputs list: rows with status badge, glyph, name, alias button, and "Use"/"Current" action button.
  - Preferences modal/expansion for setting aliases and toggling visibility.

- [x] **Step 1: Implement `panel.luau`**

Ensure zero hardcoded hex colors, correct responsive constraints (`fill = "surface_variant/0.25"`, `radius = 8`, `border = "outline"`), proper error banners on failure.

- [x] **Step 2: Validate panel syntax with Luau/lint**

Run: `rtk noctalia plugins lint linked/noctalia/plugins/audio-outputs`
Expected: PASS without syntax errors in `panel.luau`.

---

### Task 5: Status Bar Widget (`widget.luau`) and Launcher (`launcher.luau`)

**Files:**
- Create: `linked/noctalia/plugins/audio-outputs/widget.luau`
- Create: `linked/noctalia/plugins/audio-outputs/launcher.luau`

**Interfaces:**
- Consumes: State `audio_outputs_snapshot`
- Produces: Bar widget with:
  - Icon (`volume-2`, `volume-1`, `volume-x` depending on mute and volume level).
  - Optional percentage text (`show_percentage`).
  - Color tint depending on busy / error state.
  - Interactive tooltip with output list summary.
  - Click bindings (left = toggle panel, right = cycle output, scroll = volume).
- Produces: Launcher provider matching prefix `audio` that opens panel.

- [x] **Step 1: Implement `widget.luau`**

- [x] **Step 2: Implement `launcher.luau`**

- [x] **Step 3: Run plugin lint**

Run: `rtk noctalia plugins lint linked/noctalia/plugins/audio-outputs`
Expected: 0 errors, 0 warnings.

---

### Task 6: Documentation, Catalog Registration and Live Hardware Verification

**Files:**
- Create: `linked/noctalia/plugins/audio-outputs/README.md`
- Modify: `linked/noctalia/plugins/catalog.toml`

- [x] **Step 1: Create `README.md`**

Document architecture, hardware quirks (NVIDIA HDMI profiles, PipeWire ACP behavior, WirePlumber persistence, `knownDevices` cache), configuration settings, and limitation notes.

- [x] **Step 2: Register plugin in `linked/noctalia/plugins/catalog.toml`**

Add `[plugins."gidragir/audio-outputs"]` entry pointing to `audio-outputs/plugin.toml`.

- [x] **Step 3: Run automated test suite**

Run:
```bash
cd linked/noctalia/plugins/audio-outputs
rtk lua tests/parser_test.lua
rtk lua tests/service_test.lua
rtk noctalia plugins lint .
```
Expected: All tests pass, 0 errors, 0 warnings.

- [x] **Step 4: Live hardware check on host**

Test:
1. Verify `pactl get-default-sink` and active output.
2. Send test command to switch output to USB Audio and back to LG ULTRAWIDE.
3. Test profile switch to `output:hdmi-stereo-extra1` and verify sink creation and migration of `sink-inputs`.
4. Return default sink to normal state.

