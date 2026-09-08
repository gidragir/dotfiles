#!/usr/bin/env bash
# =============================================================================
# Script   : path-picker-dmenu.sh
# Purpose  : Interactive fuzzy picker for Obsidian notes (/data/obsidian) and
#            development projects (/data/projects) using noctalia-dmenu.
# Keybinds : Mod+I or Mod+Shift+O (in niri/cfg/keybinds.kdl)
# Actions  :
#   1. Step 1: Select note or project folder via noctalia-dmenu
#   2. Step 2 (if note): Select action (Insert Path / @agent read / Paste Content)
# Dependencies: noctalia-dmenu, fd, stat, jq, wl-copy, wtype, niri
# =============================================================================
set -euo pipefail

OBSIDIAN_DIR="/data/obsidian"
PROJECTS_DIR="/data/projects"

# 1. Сбор заметок Obsidian, отсортированных по дате изменения
notes_list=""
if [ -d "$OBSIDIAN_DIR" ]; then
    notes_list=$(
        cd "$OBSIDIAN_DIR" && \
        fd -e md --exec stat --printf="%Y\t%n\n" 2>/dev/null | \
        sort -nr | \
        cut -f2 | \
        sed 's|^\./||' | \
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            echo -e "📝 [Obsidian] ${file}\t${OBSIDIAN_DIR}/${file}"
        done
    )
fi

# 2. Сбор каталогов проектов
projects_list=""
if [ -d "$PROJECTS_DIR" ]; then
    projects_list=$(
        cd "$PROJECTS_DIR" && \
        find . -maxdepth 1 -mindepth 1 -type d ! -name '.*' 2>/dev/null | \
        sed 's|^\./||' | \
        sort | \
        while IFS= read -r proj; do
            [ -z "$proj" ] && continue
            echo -e "📁 [Project] ${proj}\t${PROJECTS_DIR}/${proj}"
        done
    )
fi

if [ -n "$notes_list" ] && [ -n "$projects_list" ]; then
    full_list="${notes_list}"$'\n'"${projects_list}"
elif [ -n "$notes_list" ]; then
    full_list="$notes_list"
else
    full_list="$projects_list"
fi

if [ -z "$(echo "$full_list" | tr -d '[:space:]')" ]; then
    notify-send "Path Picker" "Файлы не найдены в $OBSIDIAN_DIR или $PROJECTS_DIR"
    exit 0
fi

# 3. Вызов noctalia-dmenu (Шаг 1: выбор заметки или проекта)
selected_display=$(echo "$full_list" | cut -f1 | noctalia-dmenu -p "Select Note or Project:")
if [ -z "$selected_display" ]; then
    exit 0
fi

target_path=$(echo "$full_list" | grep -F "$selected_display"$'\t' | cut -f2 | head -n 1)
if [ -z "$target_path" ]; then
    exit 0
fi

to_insert=""

# Если выбран каталог проекта — сразу вставляем путь
if [ -d "$target_path" ]; then
    to_insert="$target_path"
else
    # Если выбрана markdown-заметка — вызываем быстрое меню действий (Шаг 2)
    action=$(echo -e "📌 Insert Path\n🤖 @agent прочитай\n📄 Paste File Content" | noctalia-dmenu -p "Action:")
    case "$action" in
        "📌 Insert Path")
            to_insert="$target_path"
            ;;
        "🤖 @agent прочитай")
            to_insert="@agent прочитай \"$target_path\" "
            ;;
        "📄 Paste File Content")
            if [ -f "$target_path" ]; then
                to_insert=$(cat "$target_path")
            else
                to_insert="$target_path"
            fi
            ;;
        *)
            exit 0
            ;;
    esac
fi

# 4. Копирование в буфер обмена и вставка в текущее активное окно
echo -n "$to_insert" | wl-copy
sleep 0.1

focused_app=$(niri msg -j focused-window 2>/dev/null | jq -r '.app_id // empty' || true)
if [ "$focused_app" = "ghostty" ]; then
    wtype -M ctrl -M shift -k v -m shift -m ctrl
else
    wtype -M ctrl -k v -m ctrl
fi
