#!/usr/bin/env bash
# lib/devices.sh — hardware device abstraction (Strategy pattern)
#
# Reads device configuration from devices.conf (sourced before this lib).
#
# OPENRGB_DEVICES entry format:
#   "by-name:<OpenRGB device name>[:<mode>]"
#   "by-index:<N>[:<mode>]"
#
# <mode> is optional and defaults to:
#   • "Direct" for apply_color (best for DDR5, GPU)
#   • "static" / "off" for apply_off (per device type)
#
# If mode is explicitly set in the entry it overrides the default.
# Example:
#   "by-index:3:Static"   — motherboard ARGB headers need Static, not Direct
#
# OpenRGB execution model:
#   • ALL openrgb device commands are sent as ONE process using chained args:
#     openrgb -c HEX -d 0 -m Direct -c HEX -d 3 -m Static -c HEX
#     This eliminates race conditions and makes all changes truly simultaneous.
#   • ratbagctl runs in the background (independent daemon).

# --- Internal: scale hex color by brightness percentage (0-100) ---
scale_color_brightness() {
  local hex="${1:-000000}"
  local brightness="${2:-100}"
  hex="${hex#"#"}"

  if [[ "$brightness" -ge 100 ]]; then
    printf '%s\n' "$hex"
    return 0
  fi
  if [[ "$brightness" -le 0 ]]; then
    printf '000000\n'
    return 0
  fi

  local r_hex="${hex:0:2}"
  local g_hex="${hex:2:2}"
  local b_hex="${hex:4:2}"

  local r=$(( 16#$r_hex ))
  local g=$(( 16#$g_hex ))
  local b=$(( 16#$b_hex ))

  local r_scaled=$(( (r * brightness + 50) / 100 ))
  local g_scaled=$(( (g * brightness + 50) / 100 ))
  local b_scaled=$(( (b * brightness + 50) / 100 ))

  printf '%02X%02X%02X\n' "$r_scaled" "$g_scaled" "$b_scaled"
}

# --- Internal: ratbagctl LED control ---
_ratbag_set_color() {
  local hex="${1:-000000}"

  [[ -z "${RATBAG_DEVICE_MATCH:-}" ]] && return 0
  command -v ratbagctl >/dev/null 2>&1 || return 0

  local dev_id
  dev_id="$(ratbagctl list 2>/dev/null \
    | grep -i "$RATBAG_DEVICE_MATCH" \
    | awk -F':' '{print $1}' \
    | head -n1 || true)"
  [[ -z "$dev_id" ]] && return 0

  local count="${RATBAG_LED_COUNT:-1}"

  if [[ "$hex" == "000000" ]]; then
    for ((i = 0; i < count; i++)); do
      ratbagctl "$dev_id" led "$i" set mode off >/dev/null 2>&1 || true
    done
  else
    for ((i = 0; i < count; i++)); do
      ratbagctl "$dev_id" led "$i" set mode on      >/dev/null 2>&1 || true
      ratbagctl "$dev_id" led "$i" set color "$hex" >/dev/null 2>&1 || true
    done
  fi
}

# --- Internal: parse "kind:val[:mode[:extra]]" entry ---
# Sets globals: _kind, _val, _mode, _extra
_parse_device_entry() {
  local entry="$1"
  _kind=""
  _val=""
  _mode=""
  _extra=""
  IFS=':' read -r _kind _val _mode _extra <<< "$entry"
}

# devices_apply_off — set all devices to off/black
devices_apply_off() {
  # Mouse: independent daemon, run in background for immediate response
  _ratbag_set_color "000000" &

  # Build a SINGLE openrgb invocation for all devices simultaneously
  local -a cmd=(openrgb -c 000000)

  local -a _devs=()
  [[ -v OPENRGB_DEVICES ]] && _devs=("${OPENRGB_DEVICES[@]}")
  for dev in "${_devs[@]+"${_devs[@]}"}"; do
    local _kind _val _mode _extra
    _parse_device_entry "$dev"
    case "$_kind" in
      by-name|by-index)
        if [[ -n "$_mode" ]]; then
          # Device has explicit mode: use it with black (e.g. Static → black Static)
          cmd+=(-d "$_val" -m "$_mode" -c 000000)
        elif [[ "$_kind" == "by-index" ]]; then
          # Default for by-index: hardware-level off
          cmd+=(-d "$_val" -m off)
        else
          # Default for by-name: static black
          cmd+=(-d "$_val" -m static -c 000000)
        fi
        if [[ -n "$_extra" ]]; then
          # shellcheck disable=SC2206
          local -a extra_args=($_extra)
          cmd+=("${extra_args[@]}")
        fi
        ;;
    esac
  done

  "${cmd[@]}" >/dev/null 2>&1 || true

  wait  # wait for ratbagctl
}

# devices_apply_color <hex> — set all devices to a specific color
devices_apply_color() {
  local hex="${1:-000000}"
  hex="${hex#"#"}"  # strip leading '#' if present

  # Mouse: independent daemon, run in background for immediate response
  _ratbag_set_color "$hex" &

  # Build a SINGLE openrgb invocation for all devices simultaneously:
  # -c sets global color (GPU and any unlisted device)
  # Per-device entries override mode for devices that need it (e.g. DDR5→Direct, fans→Static)
  local -a cmd=(openrgb -c "$hex")

  local -a _devs=()
  [[ -v OPENRGB_DEVICES ]] && _devs=("${OPENRGB_DEVICES[@]}")
  for dev in "${_devs[@]+"${_devs[@]}"}"; do
    local _kind _val _mode _extra
    _parse_device_entry "$dev"
    case "$_kind" in
      by-name|by-index)
        local mode="${_mode:-Direct}"  # Direct is default for color commands
        cmd+=(-d "$_val" -m "$mode" -c "$hex")
        if [[ -n "$_extra" ]]; then
          # shellcheck disable=SC2206
          local -a extra_args=($_extra)
          cmd+=("${extra_args[@]}")
        fi
        ;;
    esac
  done

  "${cmd[@]}" >/dev/null 2>&1 || true

  wait  # wait for ratbagctl
}
