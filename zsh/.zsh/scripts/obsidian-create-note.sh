#!/usr/bin/env bash
# =============================================================================
# Script   : obsidian-create-note.sh
# Purpose  : Create Obsidian notes with type selection (STICKY, WORKSTATION, FLEETING)
#            and corresponding templates via noctalia-dmenu.
# Keybinds : Mod+Alt+N or Mod+N (in niri/cfg/keybinds.kdl)
# =============================================================================
set -euo pipefail

VAULT_DIR="/data/obsidian"
TEMPLATE_DIR="$VAULT_DIR/SYSTEM/TEMPLATE/FORMAT"

# ── 1. Выбор типа заметки ──
NOTE_TYPE="${1:-}"

if [ -z "$NOTE_TYPE" ]; then
    # Меню выбора типа через noctalia-dmenu
    MENU_ITEMS="📌 STICKY — Стикер / Быстрая мысль\n🖥️ WORKSTATION — Рабочая станция / Контекст\n💡 FLEETING — Мимолётная заметка / Идея"
    CHOSEN=$(echo -e "$MENU_ITEMS" | noctalia-dmenu -p "Тип заметки:" || true)

    if [ -z "$CHOSEN" ]; then
        exit 0
    fi

    case "$CHOSEN" in
        *"STICKY"*)
            NOTE_TYPE="STICKY"
            ;;
        *"WORKSTATION"*)
            NOTE_TYPE="WORKSTATION"
            ;;
        *"FLEETING"*)
            NOTE_TYPE="FLEETING"
            ;;
        *)
            exit 0
            ;;
    esac
fi

NOTE_TYPE=$(echo "$NOTE_TYPE" | tr '[:lower:]' '[:upper:]')

# ── 2. Ввод заголовка (опционально) ──
NOTE_TITLE="${2:-}"

if [ -z "$NOTE_TITLE" ]; then
    sleep 0.25
    DEFAULT_OPT="📅 Использовать дату и время ($(date '+%Y-%m-%d %H:%M'))"
    HINT_OPT="✍️ Введите свой заголовок выше и нажмите Enter"
    TITLE_INPUT=$(echo -e "${DEFAULT_OPT}\n${HINT_OPT}" | noctalia-dmenu -c -p "Заголовок для ${NOTE_TYPE}:" || true)

    if [ -z "$TITLE_INPUT" ]; then
        # Отменено пользователем (Escape)
        exit 0
    fi

    if [ "$TITLE_INPUT" = "$DEFAULT_OPT" ] || [[ "$TITLE_INPUT" == *"Введите свой заголовок"* ]]; then
        NOTE_TITLE=""
    else
        NOTE_TITLE="$TITLE_INPUT"
    fi
fi

# Очистка заголовка от недопустимых символов для имени файла
NOTE_TITLE=$(echo "$NOTE_TITLE" | sed 's/[/\\:*"<>|]//g' | xargs)

# ── 3. Подготовка путей и метаданных ──
TODAY_DATE=$(date '+%Y-%m-%d')
NOW_DATETIME=$(date '+%Y-%m-%d %H:%M')
NOW_TIME_COMPACT=$(date '+%H%M')

TARGET_DIR=""
FILENAME=""
TAG_NAME=""
CONNECTION_LINK=""
TYPE_FIELD=""

case "$NOTE_TYPE" in
    STICKY)
        TARGET_DIR="$VAULT_DIR/STICKY"
        TAG_NAME="sticky_note"
        CONNECTION_LINK="[[STICKY]]"
        TYPE_FIELD="sticky_note"
        if [ -n "$NOTE_TITLE" ]; then
            if [[ "$NOTE_TITLE" =~ ^[Ss]ticky ]]; then
                FILENAME="${NOTE_TITLE}.md"
            else
                FILENAME="Sticky ${NOTE_TITLE}.md"
            fi
        else
            FILENAME="Sticky ${TODAY_DATE}.md"
            if [ -f "$TARGET_DIR/$FILENAME" ]; then
                FILENAME="Sticky ${TODAY_DATE} ${NOW_TIME_COMPACT}.md"
            fi
        fi
        ;;

    WORKSTATION)
        TARGET_DIR="$VAULT_DIR/PARA/WORKSTATION"
        TAG_NAME="workstation_note"
        CONNECTION_LINK="[[WORKSTATION]]"
        TYPE_FIELD="workstation_note"
        if [ -n "$NOTE_TITLE" ]; then
            if [[ "$NOTE_TITLE" =~ ^[Ww]orkstation ]]; then
                FILENAME="${NOTE_TITLE}.md"
            else
                FILENAME="Workstation ${NOTE_TITLE}.md"
            fi
        else
            FILENAME="Workstation ${TODAY_DATE}.md"
            if [ -f "$TARGET_DIR/$FILENAME" ]; then
                FILENAME="Workstation ${TODAY_DATE} ${NOW_TIME_COMPACT}.md"
            fi
        fi
        ;;

    FLEETING)
        TARGET_DIR="$VAULT_DIR/ZETA/FLEETING"
        TAG_NAME="fleeting_note"
        CONNECTION_LINK="[[FLEETING]]"
        TYPE_FIELD="fleeting_note"
        if [ -n "$NOTE_TITLE" ]; then
            FILENAME="${NOTE_TITLE}.md"
        else
            FILENAME="Fleeting ${TODAY_DATE} ${NOW_TIME_COMPACT}.md"
        fi
        ;;

    *)
        notify-send "Obsidian" "Неизвестный тип заметки: $NOTE_TYPE" -u critical
        exit 1
        ;;
esac

mkdir -p "$TARGET_DIR"
FULL_PATH="$TARGET_DIR/$FILENAME"

# ── 4. Генерация содержимого на основе шаблона ──
if [ ! -f "$FULL_PATH" ]; then
    cat <<EOF > "$FULL_PATH"
---
tags:
  - ${TAG_NAME}
created: ${NOW_DATETIME}
connections:
  - "${CONNECTION_LINK}"
cssclasses:
  - hide-properties_editing
type: ${TYPE_FIELD}
---

## Inputs
\`INPUT[text:reference]\`
## Overview
\`VIEW[{reference}][link]\`

EOF
    notify-send "Obsidian" "Создана заметка: $FILENAME" -i "notes"
fi

# ── 5. Обновление плагина Noctalia и открытие редактора ──
# Обновляем статус в баре Noctalia
qs -c noctalia-shell ipc call plugin:obsidian refresh >/dev/null 2>&1 || true

# Открываем заметку в Neovim внутри центрированного плавающего Ghostty
ghostty --title="Obsidian Note: $FILENAME" -e nvim "+normal G" "$FULL_PATH" &
