#!/usr/bin/env bash
# =============================================================================
# Script   : clipboard-picker.sh
# Purpose  : Interactive clipboard history picker with pinning & image preview
#            using Cliphist and Rofi under Wayland (Niri).
# Keybinds : Mod+V (configured in niri/cfg/keybinds.kdl)
# Controls :
#   - Enter         : Paste selected item into active window (Ctrl+Shift+V or Ctrl+V)
#   - Alt + P       : Pin / unpin selected item
#   - Alt + D       : Delete selected item from history
#   - Alt + W       : Wipe entire unpinned clipboard history
#   - Alt + A       : Preview image using imv
# Dependencies: rofi, cliphist, imv, wl-copy, wtype, ripgrep, niri
# =============================================================================

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
    unset pinned unpinned_array list_array pinned_array
    declare -A pinned=()
    declare -a unpinned_array=()
    declare -a list_array=()
    declare -a pinned_array=()

    mapfile -t pinned_array < "$pinned_file"
    
    for line in "${pinned_array[@]}"; do
        [ -z "$line" ] && continue
        id="${line%%$'\t'*}"
        pinned["$id"]=1
    done
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        id="${line%%$'\t'*}"
        [ -z "${pinned[$id]:-}" ] && unpinned_array+=("$line")
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
    
    [ "$exit_code" -ne 13 ] && pkill imv 2>/dev/null
    
    case $exit_code in
        0)
            cliphist decode <<< "$chosen" | wl-copy
            sleep 0.1 && wtype -M ctrl -M shift v
            exit 0
            ;;
        10)
            # Alt+P: Pin / Unpin
            if [ -n "${pinned[$id]}" ]; then
                unpin "$id"
                # If unpinned, the item will move to unpinned_array after the remaining pinned items
                # We can keep selected_row roughly or clamp to bounds
                if [ "$selected_row" -ge "${#pinned_array[@]}" ]; then
                    selected_row=$(( ${#pinned_array[@]} > 0 ? ${#pinned_array[@]} - 1 : 0 ))
                fi
            else
                [ -s "$pinned_file" ] && [ -n "$(tail -c1 "$pinned_file")" ] && echo "" >> "$pinned_file"
                echo "$chosen" >> "$pinned_file"
                # If newly pinned, it becomes the last item in pinned_array
                selected_row="${#pinned_array[@]}"
            fi
            ;;
        11)
            # Alt+D: Delete selected item from history and pinned
            cliphist delete <<< "$chosen"
            rm -f "$tmp_dir/$id.png"
            unpin "$id"
            if [ "$selected_row" -ge $(( ${#list_array[@]} - 1 )) ] && [ "$selected_row" -gt 0 ]; then
                selected_row=$(( selected_row - 1 ))
            fi
            ;;
        12)
            # Alt+W: Wipe only unpinned clipboard history
            for unpinned_item in "${unpinned_array[@]}"; do
                [ -z "$unpinned_item" ] && continue
                cliphist delete <<< "$unpinned_item"
                unpinned_id="${unpinned_item%%$'\t'*}"
                rm -f "$tmp_dir/$unpinned_id.png"
            done
            selected_row=0
            ;;
        13)
            # Alt+A: Preview image using imv
            if [[ "${chosen#*$'\t'}" == *"[[ binary data"* ]]; then
                img_path="$tmp_dir/$id.png"
                [ ! -f "$img_path" ] && cliphist decode "$id" > "$img_path" 2>/dev/null
                pkill imv 2>/dev/null
                imv "$img_path" >/dev/null 2>&1 &
            fi
            ;;
        *)
            exit 0
            ;;
    esac
done