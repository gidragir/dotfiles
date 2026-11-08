#!/usr/bin/env bash
# =============================================================================
# Script      : virt-helper.sh
# Description : Virt-Manager Helper Wrapper for Noctalia Plugin
# Usage       : virt-helper [arguments]
# Dependencies: noctalia
# Keybinds    : None
# =============================================================================
set -euo pipefail

TARGET_SCRIPT="${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/plugins/virt-manager/scripts/virt-helper.sh"

# Fallback to repository location if executed directly from repo before chezmoi apply
if [[ ! -x "$TARGET_SCRIPT" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_FALLBACK="$(cd "$SCRIPT_DIR/../../../linked/noctalia/plugins/virt-manager/scripts" 2>/dev/null && pwd)/virt-helper.sh"
    if [[ -x "$REPO_FALLBACK" ]]; then
        TARGET_SCRIPT="$REPO_FALLBACK"
    fi
fi

if [[ ! -x "$TARGET_SCRIPT" ]]; then
    echo "Error: virt-helper.sh not found or not executable at: $TARGET_SCRIPT" >&2
    exit 1
fi

exec "$TARGET_SCRIPT" "$@"
