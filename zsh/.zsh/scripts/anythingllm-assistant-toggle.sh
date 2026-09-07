#!/usr/bin/env bash
set -euo pipefail

# 1. Получаем текущий активный воркспейс, на котором сейчас находится пользователь
CURRENT_WS=$(niri msg -j workspaces 2>/dev/null | jq -r '.[] | select(.is_focused == true) | .id' | head -n 1)

# 2. Ищем окно "AnythingLLM Assistant" (плавающий оверлей)
ASSISTANT_WIN=$(niri msg -j windows 2>/dev/null | jq -r '.[] | select(.title == "AnythingLLM Assistant") | .id' | head -n 1)

if [ -n "$ASSISTANT_WIN" ] && [ "$ASSISTANT_WIN" != "null" ]; then
    # Если плавающее окно на другом воркспейсе — перемещаем его прямо к нам на текущий воркспейс!
    if [ -n "$CURRENT_WS" ] && [ "$CURRENT_WS" != "null" ]; then
        niri msg action move-window-to-workspace --window-id "$ASSISTANT_WIN" "$CURRENT_WS"
    fi
    niri msg action focus-window --id "$ASSISTANT_WIN"
    exit 0
fi

# 3. Если плавающего ассистента нет, ищем главное окно AnythingLLM
MAIN_WIN=$(niri msg -j windows 2>/dev/null | jq -r '.[] | select(.app_id == "anythingllm-desktop") | .id' | head -n 1)

if [ -n "$MAIN_WIN" ] && [ "$MAIN_WIN" != "null" ]; then
    # Перемещаем окно к текущему монитору/воркспейсу и фокусируем
    if [ -n "$CURRENT_WS" ] && [ "$CURRENT_WS" != "null" ]; then
        niri msg action move-window-to-workspace --window-id "$MAIN_WIN" "$CURRENT_WS"
    fi
    niri msg action focus-window --id "$MAIN_WIN"
    exit 0
fi

# 4. Если приложение вообще не запущено — запускаем
nohup /home/gidragir/AnythingLLMDesktop.AppImage >/dev/null 2>&1 &
