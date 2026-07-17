#!/usr/bin/env bash

tmp_dir="/tmp/cliphist"
mkdir -p "$tmp_dir"
fd --type f --changed-before 2h . "$tmp_dir" -X rm 2>/dev/null

trap 'pkill imv' EXIT

selected_row=0
max_items=50

while true; do
    mapfile -t list_array < <(cliphist list | head -n "$max_items")

    out=$(for line in "${list_array[@]}"; do
        id="${line%%$'\t'*}"
        content="${line#*$'\t'}"
        if [[ "$content" == *"[[ binary data"* ]]; then
            img_path="$tmp_dir/$id.png"
            [ ! -f "$img_path" ] && cliphist decode "$id" > "$img_path" 2>/dev/null
            echo -en "\0icon\x1f$img_path\n"
        else
            echo "$content"
        fi
    done | rofi -dmenu -format "i" -selected-row "$selected_row" -kb-custom-1 "Alt+p" -theme ~/.config/rofi/cliphist.rasi -p "")
    
    exit_code=$?
    
    if [ -z "$out" ]; then
        if pgrep imv >/dev/null; then
            pkill imv
            continue
        fi
        exit 0
    fi
    
    selected_row="$out"
    chosen="${list_array[$selected_row]}"
    
    case $exit_code in
        0)
            pkill imv
            cliphist decode <<< "$chosen" | wl-copy
            sleep 0.1 && wtype -M ctrl v
            exit 0
            ;;
        10)
            content="${chosen#*$'\t'}"
            if [[ "$content" == *"[[ binary data"* ]]; then
                id="${chosen%%$'\t'*}"
                pkill imv
                imv "$tmp_dir/$id.png" &
            fi
            ;;
        *)
            exit 0
            ;;
    esac
done