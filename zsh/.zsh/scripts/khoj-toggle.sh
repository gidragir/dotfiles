#!/usr/bin/env bash
# =============================================================================
# Script   : khoj-toggle.sh
# Purpose  : Smart window focus/toggle for Khoj AI assistant under Niri Wayland.
#            Dynamically pulls floating WebApp or main window to active workspace.
# Workflow :
#   1. Ensure Khoj container is active (auto-start if stopped)
#   2. Focus & move existing "Khoj" window to current workspace
#   3. Else launch Khoj as a standalone lightweight WebApp via Vivaldi
# Dependencies: niri, jq, docker, vivaldi-stable
# =============================================================================
set -euo pipefail

KHOJ_HOST="http://127.0.0.1:42110"
CONTAINER_NAME="khoj"

# 1. Проверяем состояние контейнера Khoj, запускаем если выключен
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
        notify-send -a "Khoj AI" "Khoj" "Запуск контейнера Khoj..." -t 2000
        docker start "$CONTAINER_NAME" >/dev/null 2>&1 || true
        sleep 1
    fi
fi

# 2. Получаем текущий активный монитор и индекс воркспейса в Niri
CURRENT_INFO=$(niri msg -j workspaces 2>/dev/null | jq -r '.[] | select(.is_focused == true) | "\(.output) \(.idx)"' | head -n 1)
read -r CURRENT_OUT CURRENT_IDX <<< "$CURRENT_INFO"

move_to_current_workspace() {
    local win_id="$1"
    if [ -n "$CURRENT_OUT" ] && [ -n "$CURRENT_IDX" ]; then
        niri msg action move-window-to-monitor "$CURRENT_OUT" --window-id "$win_id" 2>/dev/null || true
        niri msg action move-window-to-workspace "$CURRENT_IDX" --window-id "$win_id" 2>/dev/null || true
    fi
}

# 3. Ищем окно с заголовком "Khoj" или app_id vivaldi-127.0.0.1
KHOJ_WIN=$(niri msg -j windows 2>/dev/null | jq -r '.[] | select((.title != null and (.title | test("Khoj"; "i"))) or (.app_id != null and (.app_id | test("vivaldi-127\\.0\\.0\\.1")))) | .id' | head -n 1)

if [ -n "$KHOJ_WIN" ] && [ "$KHOJ_WIN" != "null" ]; then
    # Перемещаем на текущий монитор и воркспейс
    move_to_current_workspace "$KHOJ_WIN"
    # Гарантируем плавающий режим
    niri msg action move-window-to-floating --id "$KHOJ_WIN" 2>/dev/null || true
    niri msg action focus-window --id "$KHOJ_WIN"
    exit 0
fi

# 4. Если окно не найдено — открываем в режиме WebApp (без вкладок и панелей браузера)
nohup vivaldi-stable --new-window --app="${KHOJ_HOST}" >/dev/null 2>&1 &

# Ожидаем появления окна и гарантированно переводим в плавающий режим
for _ in {1..30}; do
    sleep 0.1
    KHOJ_WIN=$(niri msg -j windows 2>/dev/null | jq -r '.[] | select((.title != null and (.title | test("Khoj"; "i"))) or (.app_id != null and (.app_id | test("127\\.0\\.0\\.1")))) | .id' | head -n 1)
    if [ -n "$KHOJ_WIN" ] && [ "$KHOJ_WIN" != "null" ]; then
        move_to_current_workspace "$KHOJ_WIN"
        niri msg action move-window-to-floating --id "$KHOJ_WIN" 2>/dev/null || true
        niri msg action focus-window --id "$KHOJ_WIN" 2>/dev/null || true
        break
    fi
done
