#!/usr/bin/env bash
# lib/state.sh — profile state management
# Reads/writes ~/.config/OpenRGB/current_profile.txt

STATE_DIR="${OPENRGB_STATE_DIR:-$HOME/.config/OpenRGB}"
_STATE_FILE="$STATE_DIR/current_profile.txt"
_BRIGHTNESS_FILE="$STATE_DIR/brightness.txt"
_BASE_COLOR_FILE="$STATE_DIR/base_color.txt"

# Ensure state directory exists
state_init() {
  mkdir -p "$STATE_DIR"
}

# state_read → prints current profile name (default: "off")
state_read() {
  if [[ -f "$_STATE_FILE" ]]; then
    tr -d '[:space:]' < "$_STATE_FILE"
  else
    echo "off"
  fi
}

# state_write <profile_name>
state_write() {
  echo "$1" > "$_STATE_FILE"
}

# state_read_brightness → prints brightness percentage (default: 100)
state_read_brightness() {
  if [[ -f "$_BRIGHTNESS_FILE" ]]; then
    local val
    val="$(tr -d '[:space:]' < "$_BRIGHTNESS_FILE")"
    if [[ "$val" =~ ^[0-9]+$ ]] && [[ "$val" -ge 0 ]] && [[ "$val" -le 100 ]]; then
      echo "$val"
      return 0
    fi
  fi
  echo "100"
}

# state_write_brightness <percent 0-100>
state_write_brightness() {
  local val="${1:-100}"
  val=$(( val < 0 ? 0 : (val > 100 ? 100 : val) ))
  echo "$val" > "$_BRIGHTNESS_FILE"
}

# state_read_base_color → prints base unscaled hex color (default: "FF0000")
state_read_base_color() {
  if [[ -f "$_BASE_COLOR_FILE" ]]; then
    tr -d '[:space:]' < "$_BASE_COLOR_FILE"
  else
    echo "FF0000"
  fi
}

# state_write_base_color <hex>
state_write_base_color() {
  local hex="${1:-FF0000}"
  hex="${hex#"#"}"
  echo "$hex" > "$_BASE_COLOR_FILE"
}

# state_list_profiles → prints JSON array of profile names
# Always starts with "off"; skips any "off.orp" file to avoid duplicate
state_list_profiles() {
  local -a names=("off")
  for f in "$STATE_DIR"/*.orp; do
    [[ -f "$f" ]] || continue
    local name
    name="$(basename "$f" .orp)"
    [[ "$name" == "off" ]] && continue
    names+=("$name")
  done
  printf '%s\n' "${names[@]}" | json_array_from_lines
}

# state_profile_exists <name> → returns 0 if the .orp file exists
state_profile_exists() {
  [[ -f "$STATE_DIR/${1}.orp" ]]
}

# state_profile_path <name> → prints full path to .orp file
state_profile_path() {
  echo "$STATE_DIR/${1}.orp"
}
