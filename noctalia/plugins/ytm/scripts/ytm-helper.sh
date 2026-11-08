#!/usr/bin/env bash
# =============================================================================
# Script      : ytm-helper.sh
# Description : Backend helper for Noctalia YouTube Music plugin
# Commands    : status, toggle, play-pause, next, prev, volume, volume-up, volume-down
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
VOLUME_FILE="${LOG_DIR}/ytm-volume"

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

get_ytm_sink_inputs() {
    if ! command -v pactl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    local pear_pids
    pear_pids=$(pgrep -f 'pear-desktop' 2>/dev/null || true)

    local all_pids=()
    for p in $pear_pids; do
        all_pids+=("$p")
        local children
        children=$(pgrep -P "$p" 2>/dev/null || true)
        for c in $children; do
            all_pids+=("$c")
        done
    done

    local inputs_json
    inputs_json=$(pactl -f json list sink-inputs 2>/dev/null || echo "[]")

    if [ ${#all_pids[@]} -gt 0 ]; then
        local pids_str="${all_pids[*]}"
        local matched
        matched=$(echo "$inputs_json" | jq -r --arg pids "$pids_str" '
            ($pids | split(" ")) as $plist |
            .[] | select(. as $item | $plist | index($item.properties["application.process.id"])) | .index
        ')
        if [ -n "$matched" ]; then
            echo "$matched"
            return 0
        fi
    fi

    # Fallback match by binary name or application name
    echo "$inputs_json" | jq -r '
        .[] | select(
            ((.properties["application.process.binary"] // "") | test("^(electron|pear-desktop|youtube-music)$"; "i")) or
            ((.properties["application.name"] // "") | test("^(pear-desktop|youtube-music|YouTube Music|Chromium)$"; "i"))
        ) | .index
    '
}

get_current_volume() {
    local sink_inputs
    sink_inputs=$(get_ytm_sink_inputs)

    if [ -n "$sink_inputs" ]; then
        local first_idx
        first_idx=$(head -n 1 <<< "$sink_inputs")
        local pct_str
        pct_str=$(pactl -f json list sink-inputs 2>/dev/null | jq -r --argjson idx "$first_idx" '
            .[] | select(.index == $idx) | .volume["front-left"].value_percent // .volume[0].value_percent // ""
        ')
        if [ -n "$pct_str" ] && [ "$pct_str" != "null" ]; then
            local num
            num="${pct_str%%%}"
            local cur_vol
            cur_vol=$(awk -v n="$num" 'BEGIN { printf "%.2f", n / 100.0 }')

            if [ -f "$VOLUME_FILE" ]; then
                local stored
                stored=$(cat "$VOLUME_FILE" 2>/dev/null || true)
                if [ -n "$stored" ]; then
                    local diff
                    diff=$(awk -v c="$cur_vol" -v s="$stored" 'BEGIN { d = c - s; if (d < 0) d = -d; print (d > 0.03) ? 1 : 0 }')
                    if [ "$diff" -eq 1 ]; then
                        local target_pct
                        target_pct=$(awk -v v="$stored" 'BEGIN { printf "%d", v * 100 }')
                        for idx in $sink_inputs; do
                            pactl set-sink-input-volume "$idx" "${target_pct}%" 2>/dev/null || true
                        done
                        echo "$stored"
                        return 0
                    fi
                fi
            fi

            echo "$cur_vol" > "$VOLUME_FILE" 2>/dev/null || true
            echo "$cur_vol"
            return 0
        fi
    fi

    if [ -f "$VOLUME_FILE" ]; then
        local stored
        stored=$(cat "$VOLUME_FILE" 2>/dev/null || true)
        if [ -n "$stored" ]; then
            echo "$stored"
            return 0
        fi
    fi

    echo "1.0"
}

set_sink_volume() {
    local target_vol="$1"
    target_vol=$(awk -v v="$target_vol" 'BEGIN {
        if (v < 0.0) v = 0.0;
        if (v > 1.0) v = 1.0;
        printf "%.2f", v;
    }')

    echo "$target_vol" > "$VOLUME_FILE" 2>/dev/null || true

    local pct
    pct=$(awk -v v="$target_vol" 'BEGIN { printf "%d", v * 100 }')

    local sink_inputs
    sink_inputs=$(get_ytm_sink_inputs)

    if [ -n "$sink_inputs" ]; then
        for idx in $sink_inputs; do
            pactl set-sink-input-volume "$idx" "${pct}%" 2>/dev/null || true
        done
    fi

    local wp_props="${HOME}/.local/state/wireplumber/stream-properties"
    if [ -f "$wp_props" ]; then
        local cubic
        cubic=$(awk -v v="$target_vol" 'BEGIN { printf "%.6f", v * v * v }')
        sed -i -E 's/(Output\/Audio:application\.name:Chromium=\{.*"channelVolumes":\[)[^,]+,[^]]+(\].*\})/\1'"$cubic"', '"$cubic"'\2/' "$wp_props" 2>/dev/null || true
    fi

    local player
    player=$(get_player_name)
    if [ -n "$player" ] && command -v playerctl >/dev/null 2>&1; then
        playerctl -p "$player" volume "$target_vol" 2>/dev/null || true
    fi
}

cmd_status() {
    local player
    player=$(get_player_name)
    local vol
    vol=$(get_current_volume)

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
            --arg volume "$vol" \
            '{hasPlayer: true, status: $status, title: $title, artist: $artist, album: $album, player: $player, volume: ($volume | tonumber? // 1.0)}'
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
            --arg volume "$vol" \
            '{hasPlayer: false, status: (if $win_exists == "true" then "Idle" else "Inactive" end), title: "", artist: "", album: "", player: "", volume: ($volume | tonumber? // 1.0)}'
    fi
}

cmd_volume() {
    local val="${1:-}"
    if [ -n "$val" ]; then
        log_msg "Setting volume to $val"
        local target_vol
        target_vol=$(awk -v v="$val" 'BEGIN { if (v > 1.0) print v / 100.0; else print v }')
        set_sink_volume "$target_vol"
    else
        get_current_volume
    fi
}

cmd_volume_up() {
    local step="${1:-0.05}"
    local norm_step
    norm_step=$(awk -v s="$step" 'BEGIN { if (s > 1.0) print s / 100.0; else print s }')
    log_msg "Command volume-up step=$norm_step"

    local cur_vol
    cur_vol=$(get_current_volume)
    local new_vol
    new_vol=$(awk -v c="$cur_vol" -v s="$norm_step" 'BEGIN {
        v = c + s;
        if (v > 1.0) v = 1.0;
        printf "%.2f", v;
    }')

    set_sink_volume "$new_vol"
}

cmd_volume_down() {
    local step="${1:-0.05}"
    local norm_step
    norm_step=$(awk -v s="$step" 'BEGIN { if (s > 1.0) print s / 100.0; else print s }')
    log_msg "Command volume-down step=$norm_step"

    local cur_vol
    cur_vol=$(get_current_volume)
    local new_vol
    new_vol=$(awk -v c="$cur_vol" -v s="$norm_step" 'BEGIN {
        v = c - s;
        if (v < 0.0) v = 0.0;
        printf "%.2f", v;
    }')

    set_sink_volume "$new_vol"
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
    volume)
        cmd_volume "${2:-}"
        ;;
    volume-up)
        cmd_volume_up "${2:-0.05}"
        ;;
    volume-down)
        cmd_volume_down "${2:-0.05}"
        ;;
    *)
        echo "Usage: $0 {status|toggle|play-pause|next|prev|volume|volume-up|volume-down}" >&2
        exit 1
        ;;
esac
