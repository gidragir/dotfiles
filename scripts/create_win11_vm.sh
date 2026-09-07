#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Скрипт: Автоматическое создание ВМ Windows 11 в KVM/libvirt на CachyOS
# ==============================================================================

VM_NAME="win11"
RAM_MB=8192
VCPUS=4
DISK_SIZE_GB=64

VM_DIR="/var/lib/libvirt/images"
ISO_DIR="$VM_DIR/iso"
DISK_PATH="$VM_DIR/${VM_NAME}.qcow2"
SHARED_DIR="/srv/Shared"

mkdir -p "$ISO_DIR"

# Функция поиска ISO файлов
find_iso() {
    local filename="$1"
    local search_path=""

    if [[ -f "$ISO_DIR/$filename" ]]; then
        search_path="$ISO_DIR/$filename"
    elif [[ -f "$HOME/Downloads/$filename" ]]; then
        echo "Перемещаем $filename в $ISO_DIR для доступа гипервизора..."
        mv "$HOME/Downloads/$filename" "$ISO_DIR/$filename"
        chmod 644 "$ISO_DIR/$filename"
        search_path="$ISO_DIR/$filename"
    elif [[ -f "$HOME/$filename" ]]; then
        echo "Перемещаем $filename в $ISO_DIR для доступа гипервизора..."
        mv "$HOME/$filename" "$ISO_DIR/$filename"
        chmod 644 "$ISO_DIR/$filename"
        search_path="$ISO_DIR/$filename"
    fi

    echo "$search_path"
}

echo "=== [1/4] Проверка образов ==="
WIN_ISO=$(find_iso "Win11_25H2_English_x64_v2.iso")
if [[ -z "$WIN_ISO" ]]; then
    # Автопоиск любого другого ISO Windows 11 в папке
    WIN_ISO=$(find "$ISO_DIR" "$HOME/Downloads" -maxdepth 1 -iname "*win11*.iso" 2>/dev/null | head -n 1 || true)
fi

if [[ -z "$WIN_ISO" || ! -f "$WIN_ISO" ]]; then
    echo "Ошибка: Образ Windows 11 не найден!"
    exit 1
fi
echo "Образ Windows: $WIN_ISO"

VIRTIO_ISO=$(find_iso "virtio-win.iso")
if [[ -z "$VIRTIO_ISO" || ! -f "$VIRTIO_ISO" ]]; then
    echo "Ошибка: Образ VirtIO не найден в $ISO_DIR или ~"
    exit 1
fi
echo "Образ VirtIO:  $VIRTIO_ISO"

echo ""
echo "=== [2/4] Проверка хранилища ВМ ($VM_DIR) ==="
if [[ ! -d "$VM_DIR" ]]; then
    echo "Ошибка: Директория $VM_DIR не найдена."
    exit 1
fi
echo "Диск будет создан в: $DISK_PATH (ext4 NVMe)"

echo ""
echo "=== [3/4] Проверка директории общего доступа ($SHARED_DIR) ==="
if [[ ! -d "$SHARED_DIR" ]]; then
    echo "Директория $SHARED_DIR не найдена. Создаем..."
    sudo mkdir -p "$SHARED_DIR"
    sudo chmod 2770 "$SHARED_DIR" 2>/dev/null || true
else
    echo "Директория общего доступа $SHARED_DIR готова."
fi

# Очистка предыдущей незавершенной ВМ перед стартом
if virsh -c qemu:///system dominfo "$VM_NAME" &>/dev/null; then
    echo "Удаление предыдущей конфигурации $VM_NAME..."
    virsh -c qemu:///system destroy "$VM_NAME" 2>/dev/null || true
    virsh -c qemu:///system undefine "$VM_NAME" --nvram 2>/dev/null || true
    rm -f "$DISK_PATH"
fi

echo ""
echo "=== [4/4] Запуск virt-install для создания ВМ $VM_NAME ==="

virt-install \
  --connect qemu:///system \
  --name "$VM_NAME" \
  --memory "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --os-variant win11 \
  --boot uefi,loader_secure=yes \
  --tpm backend.type=emulator,backend.version=2.0,model=tpm-tis \
  --disk path="$DISK_PATH",size="$DISK_SIZE_GB",bus=virtio,format=qcow2 \
  --cdrom "$WIN_ISO" \
  --disk path="$VIRTIO_ISO",device=cdrom \
  --network network=default,model=virtio \
  --graphics spice,listen=127.0.0.1 \
  --channel spicevmc,target_type=virtio,name=com.redhat.spice.0 \
  --channel unix,target_type=virtio,name=org.qemu.guest_agent.0 \
  --noautoconsole

echo ""
echo "=================================================================="
echo " ✅ Виртуальная машина '$VM_NAME' успешно создана и запущена!"
echo " Откройте Virtual Machine Manager для продолжения установки."
echo "=================================================================="
