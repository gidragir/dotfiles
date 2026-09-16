#!/usr/bin/env bash
# =============================================================================
# Script      : obsidian-helper.sh
# Description : Obsidian Helper Wrapper for Noctalia Obsidian Plugin
# Usage       : obsidian-helper [arguments]
# Dependencies: noctalia
# Keybinds    : None
# =============================================================================
set -euo pipefail

TARGET_SCRIPT="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/obsidian/scripts/obsidian-helper.sh"

if [[ ! -x "$TARGET_SCRIPT" ]]; then
    echo "Error: obsidian-helper.sh not found or not executable at: $TARGET_SCRIPT" >&2
    exit 1
fi

exec "$TARGET_SCRIPT" "$@"
