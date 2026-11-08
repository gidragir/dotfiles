#!/usr/bin/env bash
# =============================================================================
# Script      : ytm-toggle.sh
# Description : Smart scratchpad toggle for YouTube Music (pear-desktop) in Niri
# Logs        : ~/.local/state/noctalia/ytm.log
# =============================================================================
set -euo pipefail

LOG_DIR="${HOME}/.local/state/noctalia"
LOG_FILE="${LOG_DIR}/ytm.log"
mkdir -p "$LOG_DIR"

log_msg() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [toggle] [PID:$$] $*" >> "$LOG_FILE"
    # Автоматическая ротация при размере > 500Кб
    if [ -f "$LOG_FILE" ] && [ "$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)" -gt 512000 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.old" 2>/dev/null || true
    fi
}

log_msg "--- Invoked ytm-toggle.sh ---"

# 1. Получаем текущий активный монитор и воркспейс Niri
CURRENT_WS=$(niri msg -j workspaces 2>/dev/null | jq -r '.[] | select(.is_focused == true) | "\(.output) \(.idx) \(.id)"' | head -n 1)
read -r CURRENT_OUT CURRENT_IDX CURRENT_ID <<< "$CURRENT_WS"

log_msg "Current active workspace: output=$CURRENT_OUT idx=$CURRENT_IDX id=$CURRENT_ID"

find_ytm_window() {
    niri msg -j windows 2>/dev/null | jq -r '.[] | select(
        (.app_id != null) and
        (.app_id != "antigravity") and
        (.app_id != "code") and
        (.app_id != "dev.noctalia.Noctalia") and
        (
            (.app_id | test("^(pear-desktop|youtube-music|com\\.github\\.th[-_]ch\\.youtube[-_]music)$"; "i")) or
            ((.title != null) and (.title | test("YouTube Music"; "i")))
        )
    ) | "\(.id) \(.workspace_id) \(.app_id) \(.title)"' | head -n 1
}

# 2. Ищем существующее окно YouTube Music
WIN_INFO=$(find_ytm_window)

if [ -n "$WIN_INFO" ] && [ "$WIN_INFO" != "null" ]; then
    read -r YTM_WIN YTM_WS YTM_APP YTM_TITLE <<< "$WIN_INFO"
    log_msg "Found YTM window: id=$YTM_WIN ws=$YTM_WS app_id=$YTM_APP title='$YTM_TITLE'"

    # Если окно уже открыто на текущем воркспейсе -> СКРЫВАЕМ его на воркспейс 99 (без захвата фокуса)
    if [ "$YTM_WS" = "$CURRENT_ID" ]; then
        log_msg "Window is on active workspace ($CURRENT_ID) -> Hiding to workspace 99"
        niri msg action move-window-to-workspace 99 --window-id "$YTM_WIN" --focus false 2>/dev/null || true
        log_msg "Window $YTM_WIN moved to workspace 99"
        exit 0
    fi

    # Если окно скрыто или находится на другом воркспейсе ->
    # ПЕРЕНОСИМ его на текущий активный монитор и воркспейс
    log_msg "Window is on remote workspace ($YTM_WS) -> Bringing to active workspace ($CURRENT_IDX / $CURRENT_OUT)"
    if [ -n "$CURRENT_OUT" ] && [ -n "$CURRENT_IDX" ]; then
        niri msg action move-window-to-monitor "$CURRENT_OUT" --window-id "$YTM_WIN" 2>/dev/null || true
        niri msg action move-window-to-workspace "$CURRENT_IDX" --window-id "$YTM_WIN" --focus false 2>/dev/null || true
    fi
    niri msg action move-window-to-floating --id "$YTM_WIN" 2>/dev/null || true
    niri msg action focus-window --id "$YTM_WIN" 2>/dev/null || true
    log_msg "Window $YTM_WIN focused on workspace $CURRENT_IDX"
    exit 0
fi

# 3. Если окно не найдено — очищаем старые Singleton блокировки и запускаем плеер
log_msg "No running YTM window found. Checking locks and launching player..."

# Если нет живых процессов pear-desktop/electron42, очищаем зомби-блокировки Chromium
if ! pgrep -f 'pear-desktop' >/dev/null 2>&1; then
    if [ -d "${HOME}/.config/YouTube Music" ]; then
        rm -f "${HOME}/.config/YouTube Music"/Singleton* 2>/dev/null || true
        log_msg "Cleaned stale Singleton locks in ~/.config/YouTube Music/"
    fi
fi

if command -v pear-desktop >/dev/null 2>&1; then
    log_msg "Launching /usr/bin/pear-desktop..."
    nohup pear-desktop >/dev/null 2>&1 &
elif command -v youtube-music >/dev/null 2>&1; then
    log_msg "Launching /usr/bin/youtube-music..."
    nohup youtube-music >/dev/null 2>&1 &
elif command -v vivaldi-stable >/dev/null 2>&1; then
    log_msg "Fallback: Launching vivaldi-stable PWA..."
    nohup vivaldi-stable --new-window --app=https://music.youtube.com >/dev/null 2>&1 &
elif command -v chromium >/dev/null 2>&1; then
    log_msg "Fallback: Launching chromium PWA..."
    nohup chromium --new-window --app=https://music.youtube.com >/dev/null 2>&1 &
else
    log_msg "ERROR: No supported player found on system!"
    notify-send -u critical "YouTube Music" "Плеер не найден. Установите pear-desktop."
    exit 1
fi

# 4. Ожидаем появления окна в Niri и позиционируем его
log_msg "Waiting for window to register in Niri (up to 6.0 seconds)..."
for i in {1..40}; do
    sleep 0.15
    WIN_INFO=$(find_ytm_window)
    if [ -n "$WIN_INFO" ] && [ "$WIN_INFO" != "null" ]; then
        read -r YTM_WIN YTM_WS YTM_APP YTM_TITLE <<< "$WIN_INFO"
        log_msg "Window appeared at attempt $i: id=$YTM_WIN app_id=$YTM_APP"
        if [ -n "$CURRENT_OUT" ] && [ -n "$CURRENT_IDX" ]; then
            niri msg action move-window-to-monitor "$CURRENT_OUT" --window-id "$YTM_WIN" 2>/dev/null || true
            niri msg action move-window-to-workspace "$CURRENT_IDX" --window-id "$YTM_WIN" --focus false 2>/dev/null || true
        fi
        niri msg action move-window-to-floating --id "$YTM_WIN" 2>/dev/null || true
        niri msg action focus-window --id "$YTM_WIN" 2>/dev/null || true
        log_msg "Window $YTM_WIN successfully positioned and focused."
        exit 0
    fi
done

log_msg "WARNING: Timed out waiting for window to appear."
