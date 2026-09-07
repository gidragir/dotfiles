#!/usr/bin/env bash
# =============================================================================
# Script   : path-picker.sh
# Purpose  : Interactive fuzzy picker for Obsidian notes (/data/obsidian) and
#            development projects (/data/projects) using Rofi under Wayland (Niri).
# Keybinds : Mod+I or Mod+Shift+O (configured in niri/cfg/keybinds.kdl)
# Actions  :
#   - Enter         : Insert absolute path into active window
#   - Alt + Enter   : Insert agent command (@agent прочитай "/data/obsidian/...")
#   - Ctrl + Enter  : Insert full markdown note content directly
# Dependencies: rofi, fd, stat, jq, wl-copy, wtype, niri
# =============================================================================
set -euo pipefail


OBSIDIAN_DIR="/data/obsidian"
PROJECTS_DIR="/data/projects"

# 1. Сбор заметок Obsidian, отсортированных по дате изменения (самые свежие первыми)
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

# 3. Вызов меню Rofi
# Enter (код 0)       → Вставить абсолютный путь
# Alt+Enter (код 10)  → Вставить команду @agent прочитай "..."
# Ctrl+Enter (код 11) → Вставить полное содержимое заметки
# Временно отключаем set -e, чтобы перехватить кастомные коды возврата Rofi (10, 11)
set +e
selected_idx=$(
    echo "$full_list" | cut -f1 | rofi -dmenu \
        -format "i" \
        -p "Вставить путь" \
        -theme ~/.config/rofi/main.rasi \
        -i \
        -kb-accept-custom "" \
        -kb-accept-alt "" \
        -kb-custom-1 "Alt+Return" \
        -kb-custom-2 "Control+Return" 2>/dev/null
)
exit_code=$?
set -e

# Rofi возвращает 1 при отмене (Esc)
if [ "$exit_code" -eq 1 ] || [ -z "$selected_idx" ] || [ "$selected_idx" -lt 0 ] 2>/dev/null; then
    exit 0
fi

# Извлечение пути из выбранной строки
line_num=$((selected_idx + 1))
target_path=$(echo "$full_list" | sed -n "${line_num}p" | cut -f2)

if [ -z "$target_path" ]; then
    exit 0
fi

case $exit_code in
    0)
        # Enter: вставить путь
        to_insert="$target_path"
        ;;
    10)
        # Alt+Enter: вставить команду для агента
        to_insert="@agent прочитай \"$target_path\" "
        ;;
    11)
        # Ctrl+Enter: вставить содержимое файла (если файл существует)
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

# 4. Копирование в буфер обмена и вставка в текущее активное окно
echo -n "$to_insert" | wl-copy
sleep 0.1

focused_app=$(niri msg -j focused-window 2>/dev/null | jq -r '.app_id // empty' || true)
if [ "$focused_app" = "ghostty" ]; then
    wtype -M ctrl -M shift -k v -m shift -m ctrl
else
    wtype -M ctrl -k v -m ctrl
fi
