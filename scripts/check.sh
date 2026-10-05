#!/usr/bin/env bash
# =============================================================================
# check.sh — Docker configuration verification (overlay2 + XFS)
# Run: sudo bash check.sh
# =============================================================================

set -euo pipefail

DOCKER_DATA_DIR="/var/lib/docker"
DOCKER_DISK_LABEL="docker"    # Label set during formatting (-L docker)
DAEMON_JSON="/etc/docker/daemon.json"

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

# Function: get device by mount point
get_device_for_mount() {
    findmnt -n -o SOURCE "$1" 2>/dev/null || echo ""
}

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Docker Storage Verification Script                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RST}"

# =============================================================================
header "1. Mount Points"
# =============================================================================

if mountpoint -q "$DOCKER_DATA_DIR" 2>/dev/null; then
    pass "$DOCKER_DATA_DIR is mounted"
else
    fail "$DOCKER_DATA_DIR is NOT mounted"
fi

DEVICE=$(get_device_for_mount "$DOCKER_DATA_DIR")
if [[ -n "$DEVICE" ]]; then
    pass "Device: $DEVICE"
else
    fail "Could not determine device for $DOCKER_DATA_DIR"
fi

# Check filesystem type
FS_TYPE=$(findmnt -n -o FSTYPE "$DOCKER_DATA_DIR" 2>/dev/null || echo "")
if [[ "$FS_TYPE" == "xfs" ]]; then
    pass "Filesystem type: XFS"
else
    fail "Filesystem type: '$FS_TYPE' (expected xfs)"
fi

# Check mount options
MOUNT_OPTS=$(findmnt -n -o OPTIONS "$DOCKER_DATA_DIR" 2>/dev/null || echo "")
echo "  → Options: $MOUNT_OPTS"

for OPT in noatime prjquota logbsize=256k; do
    if echo "$MOUNT_OPTS" | grep -q "$OPT"; then
        pass "Option '$OPT' active"
    else
        fail "Option '$OPT' NOT found in mount options"
    fi
done

# =============================================================================
header "2. XFS Filesystem"
# =============================================================================

if [[ -n "$DEVICE" ]]; then
    REAL_DEV=$(readlink -f "$DEVICE" 2>/dev/null || echo "$DEVICE")

    XFS_INFO=$(xfs_info "$DOCKER_DATA_DIR" 2>/dev/null || echo "")
    if [[ -n "$XFS_INFO" ]]; then
        pass "xfs_info executed successfully"

        if echo "$XFS_INFO" | grep -q "ftype=1"; then
            pass "ftype=1 enabled (required for overlay2)"
        else
            fail "ftype=1 NOT enabled! overlay2 will not function properly"
        fi

        BSIZE=$(echo "$XFS_INFO" | grep -oP 'bsize=\K[0-9]+' | head -1)
        pass "XFS block size: ${BSIZE} bytes"
    else
        fail "xfs_info failed (is xfsprogs installed?)"
    fi
fi

# =============================================================================
header "3. /etc/fstab"
# =============================================================================

if grep -q "$DOCKER_DATA_DIR" /etc/fstab; then
    FSTAB_LINE=$(grep "$DOCKER_DATA_DIR" /etc/fstab)
    pass "/etc/fstab contains entry for $DOCKER_DATA_DIR"
    echo "  → $FSTAB_LINE"

    if echo "$FSTAB_LINE" | grep -q "UUID="; then
        pass "Mounted by UUID (recommended)"
    else
        warn "NOT mounted by UUID — using UUID is recommended"
    fi

    if echo "$FSTAB_LINE" | grep -q "prjquota"; then
        pass "prjquota in fstab"
    else
        fail "prjquota NOT found in fstab"
    fi
else
    fail "/etc/fstab does not contain entry for $DOCKER_DATA_DIR"
fi

# =============================================================================
header "4. Docker: daemon.json"
# =============================================================================

if [[ -f "$DAEMON_JSON" ]]; then
    pass "$DAEMON_JSON exists"

    if python3 -m json.tool "$DAEMON_JSON" > /dev/null 2>&1; then
        pass "JSON syntax is valid"
    else
        fail "daemon.json contains syntax errors!"
    fi

    # Check key fields
    STORAGE_DRIVER=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(d.get('storage-driver',''))" 2>/dev/null || echo "")
    if [[ "$STORAGE_DRIVER" == "overlay2" ]]; then
        pass "storage-driver: overlay2"
    else
        fail "storage-driver: '$STORAGE_DRIVER' (expected overlay2)"
    fi

    LIVE_RESTORE=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(d.get('live-restore',''))" 2>/dev/null || echo "")
    if [[ "$LIVE_RESTORE" == "True" ]]; then
        pass "live-restore: true (containers survive daemon restart)"
    else
        warn "live-restore not enabled — restarting Docker will kill containers"
    fi

    STORAGE_OPTS=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(' '.join(d.get('storage-opts',[])))" 2>/dev/null || echo "")
    echo "  → storage-opts: $STORAGE_OPTS"

    if echo "$STORAGE_OPTS" | grep -q "overlay2.size"; then
        pass "overlay2.size configured"
    else
        warn "overlay2.size not configured — no per-container disk quota limit"
    fi

    # Ensure override_kernel_check is removed
    if echo "$STORAGE_OPTS" | grep -q "override_kernel_check"; then
        fail "overlay2.override_kernel_check found! This option was removed in Docker 19.03+"
    else
        pass "overlay2.override_kernel_check absent (correct)"
    fi
else
    fail "$DAEMON_JSON not found"
fi

# =============================================================================
header "5. Docker daemon: Runtime Check"
# =============================================================================

if ! command -v docker &>/dev/null; then
    fail "Docker is not installed"
else
    pass "Docker installed: $(docker --version 2>/dev/null)"

    if systemctl is-active --quiet docker 2>/dev/null; then
        pass "Docker daemon is running"

        RUNTIME_DRIVER=$(docker info --format '{{.Driver}}' 2>/dev/null || echo "")
        if [[ "$RUNTIME_DRIVER" == "overlay2" ]]; then
            pass "Runtime storage driver: overlay2 ✓"
        else
            fail "Runtime storage driver: '$RUNTIME_DRIVER' (expected overlay2)"
        fi

        RUNTIME_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "")
        if [[ "$RUNTIME_ROOT" == "$DOCKER_DATA_DIR" ]]; then
            pass "Docker root dir: $RUNTIME_ROOT"
        else
            warn "Docker root dir: '$RUNTIME_ROOT' (expected $DOCKER_DATA_DIR)"
        fi

        if docker info 2>/dev/null | grep -q "Backing Filesystem.*xfs"; then
            pass "Backing filesystem: xfs"
        fi

        if docker info 2>/dev/null | grep -q "Supports d_type.*true"; then
            pass "d_type (ftype): supported"
        fi

        if docker info 2>/dev/null | grep -q "Native Overlay Diff.*true"; then
            pass "Native Overlay Diff: enabled"
        fi

    else
        warn "Docker daemon is not running — runtime checks skipped"
        echo "    Run: systemctl start docker"
    fi
fi

# =============================================================================
header "6. Functional Test (Container Run)"
# =============================================================================

if systemctl is-active --quiet docker 2>/dev/null; then
    echo "  Running test container hello-world..."
    if docker run --rm hello-world > /dev/null 2>&1; then
        pass "Test container started and finished successfully"
    else
        fail "Test container failed"
    fi

    # Write test in container
    echo "  Testing container disk write..."
    if docker run --rm alpine sh -c "dd if=/dev/zero of=/tmp/test bs=1M count=10 2>/dev/null && echo OK" 2>/dev/null | grep -q "OK"; then
        pass "Write to overlay2 layer works correctly"
    else
        warn "Could not execute container write test"
    fi
else
    warn "Docker not running — functional tests skipped"
fi

# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RST}"
printf "${BOLD}║  Summary: ${GRN}%2d PASS${RST}${BOLD}  ${RED}%2d FAIL${RST}${BOLD}  ${YLW}%2d WARN${RST}${BOLD}                ║${RST}\n" $PASS $FAIL $WARN
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RST}"

if [[ $FAIL -gt 0 ]]; then
    echo -e "\n${RED}Errors found — please review items above.${RST}"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "\n${YLW}Completed with warnings — investigation recommended.${RST}"
    exit 0
else
    echo -e "\n${GRN}All checks passed! Docker overlay2 is configured correctly.${RST}"
    exit 0
fi