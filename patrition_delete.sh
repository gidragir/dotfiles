#!/bin/bash

TARGET="/dev/nvme1n1"

if [[ $EUID -ne 0 ]]; then
   echo "Ошибка: Требуются права root."
   exit 1
fi

echo "1. Отключение swap..."
swapoff --all 2>/dev/null

echo "2. Принудительное размонтирование разделов ${TARGET}..."
umount -f -l ${TARGET}p* 2>/dev/null

echo "3. Остановка mdadm и dmraid..."
mdadm --stop --scan 2>/dev/null
dmraid -an 2>/dev/null

echo "4. Принудительное удаление маппингов device-mapper..."
dmsetup remove_all --force 2>/dev/null

echo "5. Затирание заголовков диска (dd)..."
dd if=/dev/zero of=${TARGET} bs=1M count=10 oflag=sync status=none

echo "6. Уничтожение таблиц GPT/MBR (sgdisk)..."
sgdisk --zap-all ${TARGET} 2>/dev/null

echo "7. Очистка оставшихся сигнатур (wipefs)..."
wipefs -a ${TARGET} 2>/dev/null

echo "8. Принудительное обновление ядра (partprobe)..."
partprobe ${TARGET} 2>/dev/null

echo "Очистка завершена."