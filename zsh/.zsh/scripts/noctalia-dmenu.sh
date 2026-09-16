#!/usr/bin/env bash
# =============================================================================
# Script      : noctalia-dmenu.sh
# Description : Wrapper for Noctalia Dmenu plugin CLI
# Usage       : <command> | noctalia-dmenu [options]
# Dependencies: noctalia
# Keybinds    : None
# =============================================================================
set -euo pipefail

TARGET_BIN="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/dmenu/noctalia-dmenu"

if [[ ! -x "$TARGET_BIN" ]]; then
    echo "Error: noctalia-dmenu plugin executable not found at: $TARGET_BIN" >&2
    exit 1
fi

exec "$TARGET_BIN" "$@"
