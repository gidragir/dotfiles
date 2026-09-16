#!/usr/bin/env bash
# =============================================================================
# Script      : ai-launcher.sh
# Description : Interactive AI Hub selector for Noctalia & Niri Wayland
# Usage       : ai-launcher.sh
# Dependencies: noctalia-dmenu, ghostty, niri, jq, notify-send
# Keybinds    : None
# =============================================================================
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MENU_ITEMS=(
    "🧠 AnythingLLM Desktop (Assistant / Window)"
    "🔍 Khoj Web Chat (Obsidian Notes & WebApp)"
    "💬 Khoj CLI Quick Chat (Interactive Terminal)"
    "🏷️ Khoj Obsidian Tags Browser"
    "🔄 Sync Notes & Reindex Khoj"
    "📊 AI Stack Health & VRAM Monitor"
    "⚙️ AnythingLLM Inspection (anything-ctl)"
)

# Формируем список для noctalia-dmenu
menu_input=$(printf "%s\n" "${MENU_ITEMS[@]}")

# Вызов noctalia-dmenu
selected=$(echo "$menu_input" | "$SCRIPTS_DIR/noctalia-dmenu.sh" -p "🧠 Local AI Hub:")

if [[ -z "$selected" ]]; then
    exit 0
fi

case "$selected" in
    *"AnythingLLM Desktop"*)
        exec "$SCRIPTS_DIR/anythingllm-assistant-toggle.sh"
        ;;
    *"Khoj Web Chat"*)
        exec "$SCRIPTS_DIR/khoj-toggle.sh"
        ;;
    *"Khoj CLI Quick Chat"*)
        ghostty --title="Khoj Quick Chat" -e bash -c '
            echo -e "\033[1;36m=== 🔍 Khoj AI Interactive Chat ===\033[0m"
            echo -e "\033[0;90mВведите запрос (или пустую строку / Ctrl+C для выхода)\033[0m\n"
            while true; do
                read -r -p "Khoj > " query || break
                [[ -z "$query" ]] && break
                echo ""
                "'"$SCRIPTS_DIR"'/khoj-ctl.sh" chat "$query"
                echo ""
            done
            echo "Сессия завершена."
            sleep 1
        ' &
        ;;
    *"Khoj Obsidian Tags"*)
        ghostty --title="Khoj Tags Browser" -e "$SCRIPTS_DIR/khoj-tags.sh" &
        ;;
    *"Sync Notes & Reindex Khoj"*)
        notify-send -a "Khoj AI" "Khoj Sync" "Запущена синхронизация и индексация заметок..." -t 3000
        "$SCRIPTS_DIR/khoj-ctl.sh" sync
        notify-send -a "Khoj AI" "Khoj Sync" "Синхронизация заметок завершена!" -t 3000
        ;;
    *"AI Stack Health & VRAM Monitor"*)
        ghostty --title="AI Stack Status" -e bash -c '
            "'"$SCRIPTS_DIR"'/khoj-ctl.sh" status
            echo ""
            nvidia-smi
            echo ""
            read -p "Нажмите Enter для закрытия..."
        ' &
        ;;
    *"AnythingLLM Inspection"*)
        ghostty --title="Anything-CTL" -e bash -c '
            "'"$SCRIPTS_DIR"'/anything-ctl.sh" info
            echo ""
            read -p "Нажмите Enter для закрытия..."
        ' &
        ;;
    *)
        exit 0
        ;;
esac
