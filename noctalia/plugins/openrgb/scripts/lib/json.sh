#!/usr/bin/env bash
# lib/json.sh — JSON output helpers
# Eliminates manual echo '{"status":"error"...}' constructs

# json_ok [extra_fields]
# Example: json_ok '"profile":"red"'  →  {"status":"ok","profile":"red"}
json_ok() {
  if [[ -n "${1:-}" ]]; then
    printf '{"status":"ok",%s}\n' "$1"
  else
    printf '{"status":"ok"}\n'
  fi
}

# json_error <message>
json_error() {
  local msg="${1:-Unknown error}"
  # Escape double quotes inside message
  msg="${msg//\"/\\\"}"
  printf '{"status":"error","message":"%s"}\n' "$msg"
}

# json_kv <key> <value>  →  "key":"value"
# Use inside json_ok: json_ok "$(json_kv profile red)"
json_kv() {
  local val="${2//\"/\\\"}"
  printf '"%s":"%s"' "$1" "$val"
}

# json_array_from_lines  — reads lines from stdin, emits a JSON string array
# Example: printf 'off\nred\n' | json_array_from_lines  →  ["off","red"]
json_array_from_lines() {
  jq -R . | jq -sc .
}
