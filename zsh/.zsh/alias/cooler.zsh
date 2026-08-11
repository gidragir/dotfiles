# ── CoolerControl Shortcuts ──────────────────────────────────────────────────
# Mode switching via REST API using dynamic UID lookup by mode name.
# Local secrets (CCTV_DAEMON_PASSWORD, token) are stored in .zshenv.local (git-ignored).
COOLER_TOKEN_FILE="${COOLERCONTROL_TOKEN_FILE:-$HOME/.config/coolercontrol/token}"
COOLER_BASE_URL="${COOLERCONTROL_BASE_URL:-https://127.0.0.1:11987}"

_cooler_activate() {
  local mode_name="$1"
  local token
  token="$(cat "$COOLER_TOKEN_FILE" 2>/dev/null)"
  if [[ -z "$token" ]]; then
    echo "❌ CoolerControl token not found at $COOLER_TOKEN_FILE" >&2
    return 1
  fi

  # Dynamically fetch mode UID by name from API
  local mode_uid
  if command -v jq >/dev/null 2>&1; then
    mode_uid="$(curl -k -s -H "Authorization: Bearer ${token}" "${COOLER_BASE_URL}/modes" \
      | jq -r ".modes[] | select(.name==\"${mode_name}\") | .uid" 2>/dev/null)"
  else
    mode_uid="$(curl -k -s -H "Authorization: Bearer ${token}" "${COOLER_BASE_URL}/modes" \
      | grep -o "{\"uid\":\"[^\"]*\",\"name\":\"${mode_name}\"" | cut -d'"' -f4)"
  fi

  if [[ -z "$mode_uid" || "$mode_uid" == "null" ]]; then
    echo "❌ Mode '${mode_name}' not found in CoolerControl UI" >&2
    return 1
  fi

  local http_code
  http_code="$(curl -k -s -o /dev/null -w '%{http_code}' -X POST \
    -H "Authorization: Bearer ${token}" \
    "${COOLER_BASE_URL}/modes-active/${mode_uid}")"

  if [[ "$http_code" == "200" ]]; then
    echo "► CoolerControl: Switched to '${mode_name}' mode"
  else
    echo "❌ Failed to activate '${mode_name}' mode (HTTP ${http_code})" >&2
    return 1
  fi
}

alias cooler-quiet='_cooler_activate Quiet'
alias cooler-gaming='_cooler_activate Gaming'
alias cooler-work='_cooler_activate Work'
alias cooler-status='systemctl status coolercontrold.service'
