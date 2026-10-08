#!/usr/bin/env bash
# =============================================================================
# Script      : spf-clip.sh
# Description : Copy file or directory URI to Wayland clipboard (text/uri-list)
# Usage       : spf-clip [file]
# Dependencies: realpath, wl-copy
# Keybinds    : None
# =============================================================================
set -euo pipefail

FILE="${1:-$(pwd)}"
ABS=$(realpath "$FILE")
printf "file://%s" "$ABS" | wl-copy -t text/uri-list