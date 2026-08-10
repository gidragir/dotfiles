#!/usr/bin/env bash

tmp_dir="/tmp/cliphist"
pinned_file="$HOME/.config/cliphist/pinned"
mkdir -p "$tmp_dir" "$(dirname "$pinned_file")"
touch "$pinned_file"

trap 'pkill imv 2>/dev/null' EXIT

selected_row=0
max_items=50

unpin() {
    rg -v "^$1"$'\t' "$pinned_file" > "${pinned_file}.tmp" || true
    mv "${pinned_file}.tmp" "$pinned_file"
}

while true; do
    mapfile -t pinned_array < "$pinned_file"
    
    declare -A pinned
    for line in "${pinned_array[@]}"; do
        [ -z "$line" ] && continue
        id="${line%%$'\t'*}"
        pinned["$id"]=1
    done
    
    declare -a unpinned_array
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        id="${line%%$'\t'*}"
        [ -z "${pinned[$id]}" ] && unpinned_array+=("$line")
    done < <(cliphist list | head -n "$max_items")
    
    list_array=("${pinned_array[@]}" "${unpinned_array[@]}")
    
    [ ${#list_array[@]} -eq 0 ] && { echo "History empty" | rofi -dmenu -p ""; exit 0; }

    out=$(for line in "${list_array[@]}"; do
        [ -z "$line" ] && continue
        
        id="${line%%$'\t'*}"
        content="${line#*$'\t'}"
        
        prefix=""
        [ -n "${pinned[$id]}" ] && prefix="📌 "
        
        if [[ "$content" == *"[[ binary data"* ]]; then
            img_path="$tmp_dir/$id.png"
            [ ! -f "$img_path" ] && cliphist decode "$id" > "$img_path" 2>/dev/null
            echo -en "${prefix}\0icon\x1f$img_path\n"
        else
            # Replace newlines with spaces so multiline entries display on a single line in Rofi
            clean_content=$(echo "$content" | tr '\n' ' ')
            echo "${prefix}${clean_content}"
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
            pkill imv 2>/dev/null
            continue
        fi
        exit 0
    fi
    
    selected_row="$out"
    chosen="${list_array[$selected_row]}"
    id="${chosen%%$'\t'*}"
    
    [ "$exit_code" -ne 10 ] && pkill imv 2>/dev/null
    
    case $exit_code in
        0)
            cliphist decode <<< "$chosen" | wl-copy
            sleep 0.1 && wtype -M ctrl -M shift v
            exit 0
            ;;
        10)
            if [[ "${chosen#*$'\t'}" == *"[[ binary data"* ]]; then
                img_path="$tmp_dir/$id.png"
                [ ! -f "$img_path" ] && cliphist decode "$id" > "$img_path" 2>/dev/null
                pkill imv 2>/dev/null
                imv "$img_path" >/dev/null 2>&1 &
            fi
            ;;
        11)
            cliphist delete <<< "$chosen"
            rm -f "$tmp_dir/$id.png"
            unpin "$id"
            ;;
        12)
            cliphist wipe
            rm -rf "$tmp_dir"/*
            > "$pinned_file"
            selected_row=0
            ;;
        13)
            if [ -n "${pinned[$id]}" ]; then
                unpin "$id"
            else
                [ -s "$pinned_file" ] && [ -n "$(tail -c1 "$pinned_file")" ] && echo "" >> "$pinned_file"
                echo "$chosen" >> "$pinned_file"
            fi
            ;;
        *)
            exit 0
            ;;
    esac
done