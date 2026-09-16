#!/usr/bin/env bash
# =============================================================================
# Script      : sync-knowledge.sh
# Description : Trigger TypeScript knowledge synchronizer for dotfiles & AI stack
# Usage       : sync-knowledge [options]
# Dependencies: bun
# Keybinds    : None
# =============================================================================
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(dirname "$(dirname "$(dirname "$SCRIPTS_DIR")")")"
SYNC_SCRIPT="$DOTFILES_DIR/scripts/sync_knowledge.ts"

if [ ! -f "$SYNC_SCRIPT" ]; then
    echo "Error: sync_knowledge.ts not found at $SYNC_SCRIPT" >&2
    exit 1
fi

exec bun run "$SYNC_SCRIPT" "$@"
