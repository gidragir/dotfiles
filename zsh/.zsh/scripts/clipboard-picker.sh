#!/usr/bin/env bash

tmp_dir="/tmp/cliphist"
pinned_file="$HOME/.config/cliphist/pinned"
mkdir -p "$tmp_dir" "$(dirname "$pinned_file")"
touch "$pinned_file"

fd --type f --changed-before 2h . "$tmp_dir" -X rm 2>/dev/null

trap 'pkill imv' EXIT

selected_row=0
max_items=50

while true; do
    # Проверка размера файла исключает баг NR==FNR
    if [ -s "$pinned_file" ]; then
        mapfile -t list_array < <(
            cat "$pinned_file"
            cliphist list | head -n "$max_items" | awk -F'\t' 'NR==FNR{pinned[$1]; next} !($1 in pinned)' "$pinned_file" -
        )
    else
        mapfile -t list_array < <(cliphist list | head -n "$max_items")
    fi

    out=$(for line in "${list_array[@]}"; do
        id="${line%%$'\t'*}"
        content="${line#*$'\t'}"
        
        grep -q "^$id"$'\t' "$pinned_file" && is_pinned=1 || is_pinned=0
        
        if [[ "$content" == *"[[ binary data"* ]]; then
            img_path="$tmp_dir/$id.png"
            [ ! -f "$img_path" ] && cliphist decode "$id" > "$img_path" 2>/dev/null
            if [ "$is_pinned" -eq 1 ]; then
                echo -en "📌\0icon\x1f$img_path\n"
            else
                echo -en "\0icon\x1f$img_path\n"
            fi
        else
            if [ "$is_pinned" -eq 1 ]; then
                echo "📌 $content"
            else
                echo "$content"
            fi
        fi
    done | rofi -dmenu -format "i" -selected-row "$selected_row" \
        -kb-custom-1 "Alt+p" \
        -kb-custom-2 "Alt+d" \
        -kb-custom-3 "Alt+w" \
        -kb-custom-4 "Alt+a" \
        -theme ~/.config/rofi/cliphist.rasi -p "")
    
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
    id="${chosen%%$'\t'*}"
    
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
                pkill imv
                imv "$tmp_dir/$id.png" &
            fi
            ;;
        11)
            pkill imv
            cliphist delete <<< "$chosen"
            rm -f "$tmp_dir/$id.png"
            grep -v "^$id"$'\t' "$pinned_file" > "${pinned_file}.tmp" && mv "${pinned_file}.tmp" "$pinned_file"
            ;;
        12)
            pkill imv
            cliphist wipe
            rm -rf "$tmp_dir"/*
            > "$pinned_file"
            selected_row=0
            ;;
        13)
            if grep -q "^$id"$'\t' "$pinned_file"; then
                grep -v "^$id"$'\t' "$pinned_file" > "${pinned_file}.tmp" && mv "${pinned_file}.tmp" "$pinned_file"
            else
                echo "$chosen" >> "$pinned_file"
            fi
            ;;
        *)
            exit 0
            ;;
    esac
done