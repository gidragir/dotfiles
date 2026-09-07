#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Скрипт: Настройка пост-установки ВМ Windows 11 (Шаг 8: Virtio-FS, Шаг 9: Видео)
# ==============================================================================

VM_NAME="win11"
SHARED_DIR="/srv/Shared"
MOUNT_TAG="host_share"

echo "=== [1/4] Проверка состояния ВМ '$VM_NAME' ==="
if ! virsh -c qemu:///system dominfo "$VM_NAME" &>/dev/null; then
    echo "Ошибка: Виртуальная машина '$VM_NAME' не найдена в libvirt!"
    exit 1
fi

DOM_STATE=$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || echo "unknown")
if [[ "$DOM_STATE" == "running" || "$DOM_STATE" == "paused" ]]; then
    echo "Внимание: ВМ '$VM_NAME' сейчас запущена ($DOM_STATE)."
    echo "Останавливаем ВМ для применения изменений оборудования..."
    virsh -c qemu:///system shutdown "$VM_NAME" 2>/dev/null || true

    # Ожидание корректного выключения (до 30 секунд)
    for _ in {1..30}; do
        sleep 1
        STATE=$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || echo "shut off")
        if [[ "$STATE" == "shut off" ]]; then
            break
        fi
    done

    # Принудительная остановка, если не выключилась
    STATE=$(virsh -c qemu:///system domstate "$VM_NAME" 2>/dev/null || echo "shut off")
    if [[ "$STATE" != "shut off" ]]; then
        echo "Принудительно выключаем ВМ (destroy)..."
        virsh -c qemu:///system destroy "$VM_NAME" 2>/dev/null || true
        sleep 1
    fi
fi
echo "ВМ '$VM_NAME' выключена."

echo ""
echo "=== [2/4] Проверка общей директории ($SHARED_DIR) ==="
if [[ ! -d "$SHARED_DIR" ]]; then
    echo "Создаем $SHARED_DIR..."
    sudo mkdir -p "$SHARED_DIR"
    sudo chmod 2770 "$SHARED_DIR" 2>/dev/null || true
fi

echo ""
echo "=== [3/4] Модификация конфигурации ВМ ==="

echo "1. Настройка Shared Memory (memfd + shared access)..."
virt-xml -c qemu:///system "$VM_NAME" --edit --memorybacking source.type=memfd,access.mode=shared

echo "2. Настройка устройства VirtIO-FS..."
if virsh -c qemu:///system dumpxml "$VM_NAME" | grep -q "<target dir=['\"]${MOUNT_TAG}['\"]"; then
    echo "Filesystem '$MOUNT_TAG' уже присутствует, обновляем путь..."
    virt-xml -c qemu:///system "$VM_NAME" --edit target.dir="$MOUNT_TAG" --filesystem type=mount,driver.type=virtiofs,source.dir="$SHARED_DIR"
else
    echo "Добавляем устройство VirtIO-FS..."
    virt-xml -c qemu:///system "$VM_NAME" --add-device --filesystem type=mount,driver.type=virtiofs,source.dir="$SHARED_DIR",target.dir="$MOUNT_TAG"
fi

echo "3. Переключение видеодрайвера на Virtio..."
virt-xml -c qemu:///system "$VM_NAME" --edit --video model.type=virtio,model.heads=1

echo ""
echo "=== [4/4] Запуск виртуальной машины ==="
virsh -c qemu:///system start "$VM_NAME"

echo ""
echo "=================================================================="
echo " ✅ Настройки успешно применены, и ВМ '$VM_NAME' запущена!"
echo ""
echo " Следующие действия в Windows 11 (Шаг 8):"
echo " 1. Установите WinFSP с диска virtio-win (или папку virtio-fs)."
echo " 2. Откройте services.msc -> найдите 'VirtIO-FS Service'."
echo " 3. Переведите тип запуска в 'Автоматически' и нажмите 'Запустить'."
echo "    После этого появится сетевой диск Z: (/srv/Shared)."
echo "=================================================================="
