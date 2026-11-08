#!/usr/bin/env bash

set -euo pipefail

NOTE_TYPE="${1:-}"
NOTE_TITLE="${2:-}"
VAULT_DIR="${3:-${OBSIDIAN_VAULT:-/data/obsidian}}"

if [[ -z "$NOTE_TYPE" ]]; then
    if ! command -v noctalia-dmenu.sh >/dev/null 2>&1; then
        echo "Error: note type is required when noctalia-dmenu.sh is unavailable" >&2
        exit 1
    fi
    choice=$(printf '%s\n' 'STICKY' 'WORKSTATION' 'FLEETING' | noctalia-dmenu.sh -p 'Note type:' || true)
    NOTE_TYPE="$choice"
fi

NOTE_TYPE="${NOTE_TYPE^^}"
case "$NOTE_TYPE" in
    STICKY)
        target_dir="$VAULT_DIR/STICKY"
        tag_name="sticky_note"
        connection="[[STICKY]]"
        type_name="sticky_note"
        prefix="Sticky"
        ;;
    WORKSTATION)
        target_dir="$VAULT_DIR/PARA/WORKSTATION"
        tag_name="workstation_note"
        connection="[[WORKSTATION]]"
        type_name="workstation_note"
        prefix="Workstation"
        ;;
    FLEETING)
        target_dir="$VAULT_DIR/ZETA/FLEETING"
        tag_name="fleeting_note"
        connection="[[FLEETING]]"
        type_name="fleeting_note"
        prefix="Fleeting"
        ;;
    *)
        echo "Error: unknown note type '$NOTE_TYPE'" >&2
        exit 1
        ;;
esac

if [[ -z "$NOTE_TITLE" ]]; then
    NOTE_TITLE="$prefix $(date '+%Y-%m-%d %H%M')"
fi
NOTE_TITLE="$(printf '%s' "$NOTE_TITLE" | sed 's#[/\\:*"<>|]##g' | xargs)"
[[ -n "$NOTE_TITLE" ]] || { echo "Error: note title cannot be empty" >&2; exit 1; }

mkdir -p "$target_dir"
filename="$NOTE_TITLE"
[[ "$filename" == *.md ]] || filename="${filename}.md"
full_path="$target_dir/$filename"

if [[ ! -f "$full_path" ]]; then
    now="$(date '+%Y-%m-%d %H:%M')"
    cat > "$full_path" <<EOF
---
tags:
  - $tag_name
created: $now
connections:
  - "$connection"
cssclasses:
  - hide-properties_editing
type: $type_name
---

## Inputs
\`INPUT[text:reference]\`
## Overview
\`VIEW[{reference}][link]\`

EOF
fi

printf '%s\n' "$full_path"
