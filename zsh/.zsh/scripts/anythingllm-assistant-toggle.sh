#!/usr/bin/env bash
# =============================================================================
# Script   : anythingllm-assistant-toggle.sh
# Purpose  : Smart window focus/toggle for AnythingLLM Desktop under Niri Wayland.
#            Dynamically pulls floating overlay or main window to active workspace.
# Keybinds : Mod+A (configured in niri/cfg/keybinds.kdl)
# Workflow :
#   1. Focus & move "AnythingLLM Assistant" floating overlay to current workspace
#   2. Else focus & move main "anythingllm-desktop" window to current workspace
#   3. Else launch AnythingLLM Desktop AppImage in background
# Dependencies: niri, jq
# =============================================================================
set -euo pipefail


# 1. Получаем текущий активный монитор и индекс воркспейса в Niri
CURRENT_INFO=$(niri msg -j workspaces 2>/dev/null | jq -r '.[] | select(.is_focused == true) | "\(.output) \(.idx)"' | head -n 1)
read -r CURRENT_OUT CURRENT_IDX <<< "$CURRENT_INFO"

move_to_current_workspace() {
    local win_id="$1"
    if [ -n "$CURRENT_OUT" ] && [ -n "$CURRENT_IDX" ]; then
        niri msg action move-window-to-monitor "$CURRENT_OUT" --window-id "$win_id" 2>/dev/null || true
        niri msg action move-window-to-workspace "$CURRENT_IDX" --window-id "$win_id" 2>/dev/null || true
    fi
}

# 2. Ищем окно "AnythingLLM Assistant" (плавающий оверлей)
ASSISTANT_WIN=$(niri msg -j windows 2>/dev/null | jq -r '.[] | select(.title == "AnythingLLM Assistant") | .id' | head -n 1)

if [ -n "$ASSISTANT_WIN" ] && [ "$ASSISTANT_WIN" != "null" ]; then
    move_to_current_workspace "$ASSISTANT_WIN"
    niri msg action move-window-to-floating --id "$ASSISTANT_WIN" 2>/dev/null || true
    niri msg action focus-window --id "$ASSISTANT_WIN"
    exit 0
fi

# 3. Если плавающего ассистента нет, ищем главное окно AnythingLLM
MAIN_WIN=$(niri msg -j windows 2>/dev/null | jq -r '.[] | select(.app_id == "anythingllm-desktop") | .id' | head -n 1)

if [ -n "$MAIN_WIN" ] && [ "$MAIN_WIN" != "null" ]; then
    move_to_current_workspace "$MAIN_WIN"
    niri msg action move-window-to-floating --id "$MAIN_WIN" 2>/dev/null || true
    niri msg action focus-window --id "$MAIN_WIN"
    exit 0
fi

# 4. Если приложение вообще не запущено — запускаем
nohup /home/gidragir/AnythingLLMDesktop.AppImage >/dev/null 2>&1 &

# Ожидаем появления окна и гарантированно переводим в плавающий режим
for _ in {1..30}; do
    sleep 0.2
    WIN=$(niri msg -j windows 2>/dev/null | jq -r '.[] | select(.app_id == "anythingllm-desktop") | .id' | head -n 1)
    if [ -n "$WIN" ] && [ "$WIN" != "null" ]; then
        move_to_current_workspace "$WIN"
        niri msg action move-window-to-floating --id "$WIN" 2>/dev/null || true
        niri msg action focus-window --id "$WIN" 2>/dev/null || true
        break
    fi
done
