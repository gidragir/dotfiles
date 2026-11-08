#!/usr/bin/env bash
# =============================================================================
# Script      : ytm-helper.sh
# Description : Backend helper for Noctalia YouTube Music plugin
# Commands    : status, toggle, play-pause, next, prev
# Logs        : ~/.local/state/noctalia/ytm.log
# =============================================================================
set -euo pipefail

LOG_DIR="${HOME}/.local/state/noctalia"
LOG_FILE="${LOG_DIR}/ytm.log"
mkdir -p "$LOG_DIR"

log_msg() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [helper] [PID:$$] $*" >> "$LOG_FILE"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOGGLE_SCRIPT="${HOME}/.zsh/scripts/ytm-toggle.sh"
[ -f "$TOGGLE_SCRIPT" ] || TOGGLE_SCRIPT="${SCRIPT_DIR}/../../../../home/dot_zsh/scripts/ytm-toggle.sh"

get_player_name() {
    if ! command -v playerctl >/dev/null 2>&1; then
        return 0
    fi

    local players
    players=$(playerctl -l 2>/dev/null || true)
    [ -z "$players" ] && return 0

    # 1. Прямой поиск по известным именам
    for p in $players; do
        case "$p" in
            *pear-desktop*|*youtube*|*ytmusic*)
                echo "$p"
                return 0
                ;;
        esac
    done

    # 2. Поиск через PID процесса pear-desktop / electron42
    local pear_pids
    pear_pids=$(pgrep -f 'pear-desktop' 2>/dev/null || true)
    if [ -n "$pear_pids" ]; then
        for pid in $pear_pids; do
            for p in $players; do
                if [[ "$p" == *"instance${pid}"* ]]; then
                    echo "$p"
                    return 0
                fi
            done
        done
    fi

    # 3. Поиск среди chromium/vivaldi инстансов с активными метаданными
    for p in $players; do
        case "$p" in
            *chromium*|*vivaldi*)
                local track_title
                track_title=$(playerctl -p "$p" metadata title 2>/dev/null || true)
                if [ -n "$track_title" ]; then
                    echo "$p"
                    return 0
                fi
                ;;
        esac
    done

    # 4. Фоллбэк на первый найденный плеер
    head -n 1 <<< "$players"
}

cmd_status() {
    local player
    player=$(get_player_name)

    if [ -n "$player" ] && command -v playerctl >/dev/null 2>&1; then
        local status title artist album
        status=$(playerctl -p "$player" status 2>/dev/null || echo "Stopped")
        title=$(playerctl -p "$player" metadata title 2>/dev/null || echo "")
        artist=$(playerctl -p "$player" metadata artist 2>/dev/null || echo "")
        album=$(playerctl -p "$player" metadata album 2>/dev/null || echo "")

        jq -n \
            --arg status "$status" \
            --arg title "$title" \
            --arg artist "$artist" \
            --arg album "$album" \
            --arg player "$player" \
            '{hasPlayer: true, status: $status, title: $title, artist: $artist, album: $album, player: $player}'
    else
        # Fallback check if window exists via Niri
        local win_exists="false"
        if command -v niri >/dev/null 2>&1; then
            if niri msg -j windows 2>/dev/null | jq -e '.[] | select(
                (.app_id != null) and
                (.app_id != "antigravity") and
                (.app_id != "code") and
                (.app_id != "dev.noctalia.Noctalia") and
                (
                    (.app_id | test("^(pear-desktop|youtube-music|com\\.github\\.th[-_]ch\\.youtube[-_]music)$"; "i")) or
                    ((.title != null) and (.title | test("YouTube Music"; "i")))
                )
            )' >/dev/null 2>&1; then
                win_exists="true"
            fi
        fi

        jq -n \
            --arg win_exists "$win_exists" \
            '{hasPlayer: false, status: (if $win_exists == "true" then "Idle" else "Inactive" end), title: "", artist: "", album: "", player: ""}'
    fi
}

cmd_toggle() {
    log_msg "Executing toggle via $TOGGLE_SCRIPT"
    if [ -x "$TOGGLE_SCRIPT" ]; then
        exec "$TOGGLE_SCRIPT"
    else
        bash "$TOGGLE_SCRIPT"
    fi
}

cmd_play_pause() {
    local player
    player=$(get_player_name)
    log_msg "Command play-pause for player: $player"
    if [ -n "$player" ] && command -v playerctl >/dev/null 2>&1; then
        playerctl -p "$player" play-pause 2>/dev/null || true
    else
        noctalia msg media toggle 2>/dev/null || true
    fi
}

cmd_next() {
    local player
    player=$(get_player_name)
    log_msg "Command next for player: $player"
    if [ -n "$player" ] && command -v playerctl >/dev/null 2>&1; then
        playerctl -p "$player" next 2>/dev/null || true
    else
        noctalia msg media next 2>/dev/null || true
    fi
}

cmd_prev() {
    local player
    player=$(get_player_name)
    log_msg "Command prev for player: $player"
    if [ -n "$player" ] && command -v playerctl >/dev/null 2>&1; then
        playerctl -p "$player" previous 2>/dev/null || true
    else
        noctalia msg media previous 2>/dev/null || true
    fi
}

ACTION="${1:-status}"
case "$ACTION" in
    status)
        cmd_status
        ;;
    toggle)
        cmd_toggle
        ;;
    play-pause)
        cmd_play_pause
        ;;
    next)
        cmd_next
        ;;
    prev)
        cmd_prev
        ;;
    *)
        echo "Usage: $0 {status|toggle|play-pause|next|prev}" >&2
        exit 1
        ;;
esac
