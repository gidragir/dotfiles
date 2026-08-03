#!/usr/bin/env bash
# =============================================================================
# check_setup.sh — Environment configuration and optimization check script
# Usage: bash check_setup.sh
# =============================================================================

set -uo pipefail

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
BLU='\033[1;34m'
RST='\033[0m'
BOLD='\033[1m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "  ${GRN}✓${RST} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}✗${RST} $1"; ((FAIL++)); }
warn() { echo -e "  ${YLW}!${RST} $1"; ((WARN++)); }
header() { echo -e "\n${BOLD}${BLU}▶ $1${RST}"; }

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║    Environment Optimization and Configuration Check  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RST}"

# =============================================================================
header "1. Verify Mount Points and Filesystem Parameters"
# =============================================================================

check_mount() {
    local path="$1"
    local expected_fs="$2"
    local expected_opt="$3"

    if mountpoint -q "$path" 2>/dev/null; then
        pass "Mount point $path is active"
        
        # Check filesystem type
        local fs_type
        fs_type=$(findmnt -n -o FSTYPE "$path" 2>/dev/null || echo "")
        if [[ "$fs_type" == "$expected_fs" ]]; then
            pass "  FS for $path matches expected: $fs_type"
        else
            fail "  FS for $path: '$fs_type' (expected $expected_fs)"
        fi

        # Check mount options
        local opts
        opts=$(findmnt -n -o OPTIONS "$path" 2>/dev/null || echo "")
        if echo "$opts" | grep -q "$expected_opt"; then
            pass "  Option '$expected_opt' for $path found in mount options"
        else
            fail "  Option '$expected_opt' for $path NOT found (active options: $opts)"
        fi
    else
        fail "Mount point $path is NOT active!"
    fi
}

check_mount "/data/projects" "btrfs" "compress=zstd"
check_mount "/data/sync" "btrfs" "compress=zstd"
check_mount "/var/lib/docker" "xfs" "prjquota"
check_mount "/var/lib/libvirt/images" "ext4" "noatime"

# =============================================================================
header "2. Verify Caches and Symlinks"
# =============================================================================

HOME_DIR="${HOME:-/home/$(whoami)}"

# Verify Cargo symlinks
check_symlink() {
    local link_path="$1"
    local target_path="$2"

    if [[ -L "$link_path" ]]; then
        local real_target
        real_target=$(readlink -f "$link_path" 2>/dev/null || echo "")
        if [[ "$real_target" == "$target_path" ]]; then
            pass "Symlink $link_path points to $target_path"
        else
            fail "Symlink $link_path points to '$real_target' (expected $target_path)"
        fi
    else
        fail "Path $link_path is not a symlink!"
    fi
}

check_symlink "$HOME_DIR/.cargo/registry" "/data/projects/.cargo-cache/registry"
check_symlink "$HOME_DIR/.cargo/git" "/data/projects/.cargo-cache/git"

# Verify cache directory existence
check_dir() {
    local dir_path="$1"
    if [[ -d "$dir_path" ]]; then
        pass "Cache directory $dir_path exists"
    else
        fail "Cache directory $dir_path NOT found!"
    fi
}

check_dir "/data/projects/.pnpm-store"
check_dir "/data/projects/.uv-cache"
check_dir "/data/projects/.sccache"

# =============================================================================
header "3. Verify Installed Cargo Utilities"
# =============================================================================

check_cmd() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        local version
        version=$("$cmd" --version 2>/dev/null | head -n 1 || echo "installed")
        pass "Utility $cmd is available ($version)"
    elif [[ -x "$HOME_DIR/.cargo/bin/$cmd" ]]; then
        local version
        version=$("$HOME_DIR/.cargo/bin/$cmd" --version 2>/dev/null | head -n 1 || echo "installed")
        pass "Utility $cmd is available in ~/.cargo/bin ($version)"
    else
        fail "Utility $cmd NOT found in PATH or ~/.cargo/bin!"
    fi
}

check_cmd "cargo-ramdisk"
check_cmd "cargo-nextest"
check_cmd "bacon"
check_cmd "cargo-machete"
check_cmd "atuin"

# Verify zsh plugins
if [[ -f "$HOME_DIR/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh" ]]; then
    pass "Zsh plugin fzf-tab is installed"
else
    fail "Zsh plugin fzf-tab NOT found in ~/.zsh/plugins/fzf-tab!"
fi

# Verify default shell
USER_SHELL=$(getent passwd "${USER:-$(whoami)}" | cut -d: -f7 2>/dev/null || echo "${SHELL:-}")
if [[ "$USER_SHELL" == *zsh* ]]; then
    pass "Default user shell is zsh ($USER_SHELL)"
else
    fail "Default user shell is '$USER_SHELL' (expected /usr/bin/zsh)"
fi

# =============================================================================
header "4. Verify Systemd Services and Timers"
# =============================================================================

# Verify system services (ratbagd)
if systemctl is-active --quiet ratbagd 2>/dev/null; then
    pass "Service ratbagd is active"
else
    warn "Service ratbagd is not active (needed for mouse configuration)"
fi

# Verify user services
check_user_service() {
    local service="$1"
    if systemctl --user is-enabled --quiet "$service" 2>/dev/null; then
        pass "User service $service is enabled"
    else
        warn "User service $service is NOT enabled"
    fi
}

check_user_service "rclone-mount.service"
check_user_service "rclone-sync.timer"

# Verify timer activity
if systemctl --user is-active --quiet rclone-sync.timer 2>/dev/null; then
    pass "Timer rclone-sync.timer is active"
else
    warn "Timer rclone-sync.timer is not active (rclone may not be configured yet)"
fi

# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RST}"
printf "${BOLD}║  Summary: ${GRN}%2d PASS${RST}${BOLD}  ${RED}%2d FAIL${RST}${BOLD}  ${YLW}%2d WARN${RST}${BOLD}                 ║${RST}\n" $PASS $FAIL $WARN
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RST}"

if [[ $FAIL -gt 0 ]]; then
    echo -e "\n${RED}Some optimizations/checks failed. Please inspect the logs above.${RST}"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "\n${YLW}Checks completed with warnings (non-critical).${RST}"
    exit 0
else
    echo -e "\n${GRN}All configurations and optimizations applied successfully!${RST}"
    exit 0
fi
