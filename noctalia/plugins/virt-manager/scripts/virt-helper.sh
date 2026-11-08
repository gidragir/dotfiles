#!/usr/bin/env bash
# =============================================================================
# Script      : virt-helper.sh
# Description : Backend helper for Noctalia virt-manager plugin
# Usage       : virt-helper.sh [list|launch <domain>]
# Dependencies: virsh, virt-viewer, jq, awk, setsid, niri (optional)
#
# Mock support (for E2E tests):
#   MOCK_VIRSH=1              — use built-in mock via MOCK_VIRSH_OUTPUT/MOCK_DOMAINS
#   MOCK_VIRSH=/path/to/mock  — use external mock script instead of real virsh
#   MOCK_VIEWER=/path/to/mock — use external mock script instead of virt-viewer
#   MOCK_LAUNCH=1             — skip real launch, print mock message
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve virsh and virt-viewer commands (allow mock substitution)
# ---------------------------------------------------------------------------
resolve_virsh_cmd() {
    local mock="${MOCK_VIRSH:-}"
    # If MOCK_VIRSH is a path to an executable, use it as virsh substitute
    if [[ -n "$mock" && "$mock" != "1" && -x "$mock" ]]; then
        echo "$mock"
    else
        echo "virsh"
    fi
}

resolve_viewer_cmd() {
    local mock="${MOCK_VIEWER:-}"
    if [[ -n "$mock" && -x "$mock" ]]; then
        echo "$mock"
    else
        echo "virt-viewer"
    fi
}

# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------
format_virsh_table() {
    local raw="$1"
    local json

    json=$(printf '%s\n' "$raw" | awk 'NR>2 && $1 ~ /^[0-9]+$/ {printf "%s\t%s\t%s\n", $1, $2, $3}' | jq -R -s -c '
        split("\n")
        | map(select(length > 0))
        | map(split("\t") | {id: .[0], name: .[1], state: .[2]})
    ' 2>/dev/null || true)

    if [[ -z "$json" || "$json" == "null" ]]; then
        echo "[]"
    else
        echo "$json"
    fi
}

format_domain_names() {
    local names="$1"
    local items=()
    local idx=1

    for domain in $names; do
        [[ -z "$domain" ]] && continue
        local item
        item=$(jq -n --arg id "$idx" --arg name "$domain" --arg state "running" '{id: $id, name: $name, state: $state}')
        items+=("$item")
        idx=$((idx + 1))
    done

    if [[ ${#items[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf '%s\n' "${items[@]}" | jq -s -c .
    fi
}

# ---------------------------------------------------------------------------
# list_domains — discover running VMs
# ---------------------------------------------------------------------------
list_domains() {
    local mock_val="${MOCK_VIRSH:-0}"

    # Built-in mock mode (MOCK_VIRSH=1)
    if [[ "$mock_val" == "1" ]]; then
        if [[ -v MOCK_VIRSH_OUTPUT ]]; then
            local trimmed
            trimmed=$(echo "${MOCK_VIRSH_OUTPUT}" | tr -d '[:space:]')
            if [[ -z "$trimmed" ]]; then
                echo "[]"
                return 0
            fi

            # Case 1: Already valid JSON array
            if echo "$MOCK_VIRSH_OUTPUT" | jq -e 'type == "array"' >/dev/null 2>&1; then
                echo "$MOCK_VIRSH_OUTPUT" | jq -c .
                return 0
            fi

            # Case 2: virsh table format
            if echo "$MOCK_VIRSH_OUTPUT" | grep -q -e '---' -e 'Id.*Name'; then
                format_virsh_table "$MOCK_VIRSH_OUTPUT"
                return 0
            fi

            # Case 3: Space or comma-separated list of domain names
            local raw_names
            raw_names=$(echo "$MOCK_VIRSH_OUTPUT" | tr ',' ' ')
            format_domain_names "$raw_names"
            return 0
        fi

        local mock_domains="${MOCK_DOMAINS:-${MOCK_VIRSH_DOMAINS:-}}"
        if [[ -n "$mock_domains" ]]; then
            local raw_names
            raw_names=$(echo "$mock_domains" | tr ',' ' ')
            format_domain_names "$raw_names"
            return 0
        fi

        # Default empty mock
        echo "[]"
        return 0
    fi

    # External mock or live virsh
    local virsh_cmd
    virsh_cmd=$(resolve_virsh_cmd)

    local virsh_raw
    if ! virsh_raw=$("$virsh_cmd" -c qemu:///system list --state-running 2>/dev/null); then
        echo "[]"
        return 0
    fi

    format_virsh_table "$virsh_raw"
}

# ---------------------------------------------------------------------------
# launch_domain — focus existing window or spawn virt-viewer
# ---------------------------------------------------------------------------
launch_domain() {
    local domain="${1:-}"
    # Trim whitespace and validate
    domain=$(echo "$domain" | xargs 2>/dev/null || true)
    if [[ -z "$domain" ]]; then
        echo "Error: domain name is required for launch" >&2
        exit 1
    fi

    # Mock launch support for test harnesses
    if [[ "${MOCK_LAUNCH:-0}" == "1" ]]; then
        if [[ -n "${MOCK_WINDOW_ID:-}" ]]; then
            echo "Mock: focused window $MOCK_WINDOW_ID for domain $domain"
            return 0
        else
            echo "Mock: launched virt-viewer for domain $domain"
            return 0
        fi
    fi

    # Check if a Niri window for virt-viewer already exists for this domain
    # Skip this check in mock/test mode to always exercise the launch path
    local win_id=""
    if [[ -z "${MOCK_VIEWER:-}" ]] && command -v niri >/dev/null 2>&1; then
        win_id=$(niri msg -j windows 2>/dev/null | jq -r --arg domain "$domain" '
            .[] | select(
                ((.app_id // "") | ascii_downcase | contains("virt-viewer")) and
                ((.title // "") | ascii_downcase | contains($domain | ascii_downcase))
            ) | .id
        ' 2>/dev/null | head -n 1 || true)
    fi

    if [[ -n "$win_id" ]]; then
        niri msg action focus-window --id "$win_id" 2>/dev/null || true
        return 0
    fi

    # Launch virt-viewer detached in its own session
    local viewer_cmd
    viewer_cmd=$(resolve_viewer_cmd)

    # setsid -f already forks to background; no trailing & needed.
    # In mock mode, avoid output suppression so mock scripts can write log files.
    if [[ -n "${MOCK_VIEWER:-}" ]]; then
        setsid -f "$viewer_cmd" --connect qemu:///system --attach "$domain" </dev/null
    else
        setsid -f "$viewer_cmd" --connect qemu:///system --attach "$domain" </dev/null &>/dev/null
    fi
    return 0
}

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
usage() {
    echo "Usage: $(basename "$0") <list|launch <domain>>" >&2
    echo "  list             Output JSON array of running KVM/libvirt domains" >&2
    echo "  launch <domain>  Focus existing Niri window or launch virt-viewer detached" >&2
}

action="${1:-list}"

case "$action" in
    list)
        list_domains
        ;;
    launch)
        shift || true
        domain="${1:-}"
        launch_domain "$domain"
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        echo "Error: unknown action '$action'" >&2
        usage
        exit 1
        ;;
esac
