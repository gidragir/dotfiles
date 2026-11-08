#!/usr/bin/env bash
# openrgb-helper.sh — thin command dispatcher for the Noctalia OpenRGB plugin
#
# Usage: openrgb-helper.sh <action> [args...]
#   list                   → JSON: { current, profiles[] }
#   apply  <profile|off>   → JSON: { status, profile }
#   set_color <hex>        → JSON: { status, color }
#   save   <name>          → JSON: { status, profile }
#   delete <name>          → JSON: { status }

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Libraries ────────────────────────────────────────────────────────────────
source "$SCRIPT_DIR/lib/json.sh"
source "$SCRIPT_DIR/lib/state.sh"
source "$SCRIPT_DIR/lib/devices.sh"

# ── Device config (machine-specific, not committed to git) ───────────────────
CONF="$SCRIPT_DIR/config/devices.conf"
[[ -f "$CONF" ]] && source "$CONF"

state_init

# ── Helpers ──────────────────────────────────────────────────────────────────

# Returns 0 if profile is a virtual color preset (in PROFILE_COLORS, no .orp file)
_is_virtual_profile() {
  [[ -v "PROFILE_COLORS[$1]" ]] && ! state_profile_exists "$1"
}

# Build merged profile list: .orp profiles + PROFILE_COLORS virtual presets
_list_all_profiles() {
  local -a names=()

  # 1. Collect .orp-based profiles (via state lib)
  while IFS= read -r name; do
    names+=("$name")
  done < <(state_list_profiles | jq -r '.[]')

  # 2. Append PROFILE_COLORS entries that have no .orp file (virtual presets)
  #    declare -p is the reliable way to test if an associative array exists
  if declare -p PROFILE_COLORS &>/dev/null; then
    for name in "${!PROFILE_COLORS[@]}"; do
      state_profile_exists "$name" && continue  # already covered by .orp
      # Skip if already in the names array
      local found=false
      for existing in "${names[@]}"; do
        [[ "$existing" == "$name" ]] && { found=true; break; }
      done
      $found || names+=("$name")
    done
  fi

  printf '%s\n' "${names[@]}" | json_array_from_lines
}

# ── Dispatcher ───────────────────────────────────────────────────────────────
action="${1:-list}"

case "$action" in

  list)
    current="$(state_read)"
    brightness="$(state_read_brightness)"
    base_color="$(state_read_base_color)"
    profiles="$(_list_all_profiles)"
    printf '{"current":"%s","brightness":%d,"base_color":"%s","profiles":%s}\n' "$current" "$brightness" "$base_color" "$profiles"
    ;;

  apply)
    profile="${2:-off}"
    brightness="$(state_read_brightness)"
    if [[ "$profile" == "off" ]]; then
      devices_apply_off
    elif state_profile_exists "$profile"; then
      # Load .orp profile and push color to DDR5/mouse simultaneously
      openrgb -p "$(state_profile_path "$profile")" >/dev/null 2>&1 || true &
      if [[ -v "PROFILE_COLORS[$profile]" ]]; then
        base_color="${PROFILE_COLORS[$profile]}"
        state_write_base_color "$base_color"
        scaled_color="$(scale_color_brightness "$base_color" "$brightness")"
        devices_apply_color "$scaled_color" &
      fi
      wait
    elif _is_virtual_profile "$profile"; then
      # Virtual color preset — apply scaled color
      base_color="${PROFILE_COLORS[$profile]}"
      state_write_base_color "$base_color"
      scaled_color="$(scale_color_brightness "$base_color" "$brightness")"
      devices_apply_color "$scaled_color"
    fi
    state_write "$profile"
    json_ok "$(json_kv profile "$profile")"
    ;;

  set_color)
    color="${2:-000000}"
    color="${color#"#"}"
    brightness="$(state_read_brightness)"
    state_write_base_color "$color"
    scaled_color="$(scale_color_brightness "$color" "$brightness")"
    devices_apply_color "$scaled_color"
    state_write "custom_$color"
    json_ok "$(json_kv color "$color")"
    ;;

  set_brightness)
    brightness="${2:-100}"
    state_write_brightness "$brightness"
    current="$(state_read)"
    base_color="$(state_read_base_color)"

    if [[ "$current" != "off" ]]; then
      scaled_color="$(scale_color_brightness "$base_color" "$brightness")"
      devices_apply_color "$scaled_color"
    fi
    json_ok "$(json_kv brightness "$brightness")"
    ;;

  save)
    name="${2:-}"
    if [[ -z "$name" ]]; then
      json_error "No profile name"
      exit 1
    fi
    openrgb --save-profile "$name" >/dev/null 2>&1 || true
    state_write "$name"
    json_ok "$(json_kv profile "$name")"
    ;;

  delete)
    name="${2:-}"
    if [[ -n "$name" && "$name" != "off" ]] && state_profile_exists "$name"; then
      rm -f "$(state_profile_path "$name")"
    fi
    json_ok
    ;;

  *)
    json_error "Unknown action: $action"
    exit 1
    ;;

esac
