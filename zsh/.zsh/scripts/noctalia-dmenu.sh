#!/usr/bin/env bash
# =============================================================================
# Script      : noctalia-dmenu.sh
# Description : Wrapper for Noctalia Dmenu plugin CLI
# Usage       : <command> | noctalia-dmenu [options]
# Dependencies: noctalia
# Keybinds    : None
# =============================================================================
set -euo pipefail

# In Noctalia v5, dmenu is a native built-in command ('noctalia dmenu')
if command -v noctalia &>/dev/null; then
    PROMPT=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--prompt)
                PROMPT="$2"
                shift 2
                ;;
            -c|--custom)
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    if [[ -n "$PROMPT" ]]; then
        exec noctalia dmenu -p "$PROMPT"
    else
        exec noctalia dmenu
    fi
fi

TARGET_BIN="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/dmenu/noctalia-dmenu"

if [[ ! -x "$TARGET_BIN" ]]; then
    echo "Error: noctalia dmenu not found" >&2
    exit 1
fi

exec "$TARGET_BIN" "$@"
