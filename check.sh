#!/usr/bin/env bash
# =============================================================================
# verify_docker_storage.sh — проверка конфигурации Docker (overlay2 + XFS)
# Запуск: sudo bash verify_docker_storage.sh
# =============================================================================

set -euo pipefail

DOCKER_DATA_DIR="/var/lib/docker"
DOCKER_DISK_LABEL="docker"    # Метка, которую мы выставили при форматировании (-L docker)
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

# Функция: получить устройство по точке монтирования
get_device_for_mount() {
    findmnt -n -o SOURCE "$1" 2>/dev/null || echo ""
}

echo -e "${BOLD}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║   Docker Storage Verification Script                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${RST}"

# =============================================================================
header "1. Монтирование"
# =============================================================================

if mountpoint -q "$DOCKER_DATA_DIR" 2>/dev/null; then
    pass "$DOCKER_DATA_DIR смонтирован"
else
    fail "$DOCKER_DATA_DIR НЕ смонтирован"
fi

DEVICE=$(get_device_for_mount "$DOCKER_DATA_DIR")
if [[ -n "$DEVICE" ]]; then
    pass "Устройство: $DEVICE"
else
    fail "Не удалось определить устройство для $DOCKER_DATA_DIR"
fi

# Проверяем тип ФС
FS_TYPE=$(findmnt -n -o FSTYPE "$DOCKER_DATA_DIR" 2>/dev/null || echo "")
if [[ "$FS_TYPE" == "xfs" ]]; then
    pass "Тип ФС: XFS"
else
    fail "Тип ФС: '$FS_TYPE' (ожидается xfs)"
fi

# Проверяем опции монтирования
MOUNT_OPTS=$(findmnt -n -o OPTIONS "$DOCKER_DATA_DIR" 2>/dev/null || echo "")
echo "  → Опции: $MOUNT_OPTS"

for OPT in noatime prjquota logbsize=256k; do
    if echo "$MOUNT_OPTS" | grep -q "$OPT"; then
        pass "Опция '$OPT' активна"
    else
        fail "Опция '$OPT' НЕ найдена в mount options"
    fi
done

# =============================================================================
header "2. XFS файловая система"
# =============================================================================

if [[ -n "$DEVICE" ]]; then
    # Нужно проверить базовое устройство (не UUID-алиас)
    REAL_DEV=$(readlink -f "$DEVICE" 2>/dev/null || echo "$DEVICE")

    XFS_INFO=$(xfs_info "$DOCKER_DATA_DIR" 2>/dev/null || echo "")
    if [[ -n "$XFS_INFO" ]]; then
        pass "xfs_info выполнен успешно"

        if echo "$XFS_INFO" | grep -q "ftype=1"; then
            pass "ftype=1 включён (обязательно для overlay2)"
        else
            fail "ftype=1 НЕ включён! overlay2 не будет работать корректно"
        fi

        BSIZE=$(echo "$XFS_INFO" | grep -oP 'bsize=\K[0-9]+' | head -1)
        pass "Размер блока XFS: ${BSIZE} байт"
    else
        fail "xfs_info не выполнен (xfsprogs установлен?)"
    fi
fi

# =============================================================================
header "3. /etc/fstab"
# =============================================================================

if grep -q "$DOCKER_DATA_DIR" /etc/fstab; then
    FSTAB_LINE=$(grep "$DOCKER_DATA_DIR" /etc/fstab)
    pass "/etc/fstab содержит запись для $DOCKER_DATA_DIR"
    echo "  → $FSTAB_LINE"

    if echo "$FSTAB_LINE" | grep -q "UUID="; then
        pass "Монтирование по UUID (надёжно)"
    else
        warn "Монтирование НЕ по UUID — рекомендуется использовать UUID"
    fi

    if echo "$FSTAB_LINE" | grep -q "prjquota"; then
        pass "prjquota в fstab"
    else
        fail "prjquota НЕ найден в fstab"
    fi
else
    fail "/etc/fstab не содержит записи для $DOCKER_DATA_DIR"
fi

# =============================================================================
header "4. Docker: daemon.json"
# =============================================================================

if [[ -f "$DAEMON_JSON" ]]; then
    pass "$DAEMON_JSON существует"

    if python3 -m json.tool "$DAEMON_JSON" > /dev/null 2>&1; then
        pass "JSON синтаксис корректен"
    else
        fail "daemon.json содержит синтаксические ошибки!"
    fi

    # Проверяем ключевые поля
    STORAGE_DRIVER=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(d.get('storage-driver',''))" 2>/dev/null || echo "")
    if [[ "$STORAGE_DRIVER" == "overlay2" ]]; then
        pass "storage-driver: overlay2"
    else
        fail "storage-driver: '$STORAGE_DRIVER' (ожидается overlay2)"
    fi

    LIVE_RESTORE=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(d.get('live-restore',''))" 2>/dev/null || echo "")
    if [[ "$LIVE_RESTORE" == "True" ]]; then
        pass "live-restore: true (контейнеры переживут рестарт демона)"
    else
        warn "live-restore не включён — рестарт Docker убьёт контейнеры"
    fi

    STORAGE_OPTS=$(python3 -c "import json; d=json.load(open('$DAEMON_JSON')); print(' '.join(d.get('storage-opts',[])))" 2>/dev/null || echo "")
    echo "  → storage-opts: $STORAGE_OPTS"

    if echo "$STORAGE_OPTS" | grep -q "overlay2.size"; then
        pass "overlay2.size задан"
    else
        warn "overlay2.size не задан — нет лимита дискового пространства на контейнер"
    fi

    # Проверяем что override_kernel_check УБРАН
    if echo "$STORAGE_OPTS" | grep -q "override_kernel_check"; then
        fail "overlay2.override_kernel_check найден! Эта опция удалена в Docker 19.03+"
    else
        pass "overlay2.override_kernel_check отсутствует (правильно)"
    fi
else
    fail "$DAEMON_JSON не найден"
fi

# =============================================================================
header "5. Docker daemon: runtime проверка"
# =============================================================================

if ! command -v docker &>/dev/null; then
    fail "Docker не установлен"
else
    pass "Docker установлен: $(docker --version 2>/dev/null)"

    if systemctl is-active --quiet docker 2>/dev/null; then
        pass "Docker daemon запущен"

        # Проверяем реальный storage driver через docker info
        RUNTIME_DRIVER=$(docker info --format '{{.Driver}}' 2>/dev/null || echo "")
        if [[ "$RUNTIME_DRIVER" == "overlay2" ]]; then
            pass "Runtime storage driver: overlay2 ✓"
        else
            fail "Runtime storage driver: '$RUNTIME_DRIVER' (ожидается overlay2)"
        fi

        RUNTIME_ROOT=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "")
        if [[ "$RUNTIME_ROOT" == "$DOCKER_DATA_DIR" ]]; then
            pass "Docker root dir: $RUNTIME_ROOT"
        else
            warn "Docker root dir: '$RUNTIME_ROOT' (ожидается $DOCKER_DATA_DIR)"
        fi

        # Проверяем прав-квоты через docker info
        if docker info 2>/dev/null | grep -q "Backing Filesystem.*xfs"; then
            pass "Backing filesystem: xfs"
        fi

        if docker info 2>/dev/null | grep -q "Supports d_type.*true"; then
            pass "d_type (ftype): поддерживается"
        fi

        if docker info 2>/dev/null | grep -q "Native Overlay Diff.*true"; then
            pass "Native Overlay Diff: включён"
        fi

    else
        warn "Docker daemon не запущен — runtime-проверки пропущены"
        echo "    Запустите: systemctl start docker"
    fi
fi

# =============================================================================
header "6. Функциональный тест (запуск контейнера)"
# =============================================================================

if systemctl is-active --quiet docker 2>/dev/null; then
    echo "  Запуск тестового контейнера hello-world..."
    if docker run --rm hello-world > /dev/null 2>&1; then
        pass "Тестовый контейнер запущен и завершился успешно"
    else
        fail "Тестовый контейнер завершился с ошибкой"
    fi

    # Тест записи в контейнере
    echo "  Тест записи в контейнере..."
    if docker run --rm alpine sh -c "dd if=/dev/zero of=/tmp/test bs=1M count=10 2>/dev/null && echo OK" 2>/dev/null | grep -q "OK"; then
        pass "Запись в overlay2 слой работает корректно"
    else
        warn "Не удалось выполнить тест записи в контейнере"
    fi
else
    warn "Docker не запущен — функциональные тесты пропущены"
fi

# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RST}"
printf "${BOLD}║  Итог: ${GRN}%2d PASS${RST}${BOLD}  ${RED}%2d FAIL${RST}${BOLD}  ${YLW}%2d WARN${RST}${BOLD}                    ║${RST}\n" $PASS $FAIL $WARN
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RST}"

if [[ $FAIL -gt 0 ]]; then
    echo -e "\n${RED}Есть ошибки — проверьте пункты выше.${RST}"
    exit 1
elif [[ $WARN -gt 0 ]]; then
    echo -e "\n${YLW}Есть предупреждения — рекомендуется разобраться.${RST}"
    exit 0
else
    echo -e "\n${GRN}Всё в порядке! Docker overlay2 настроен корректно.${RST}"
    exit 0
fi