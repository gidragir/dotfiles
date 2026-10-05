#!/usr/bin/env bash
# =============================================================================
# patrition_delete.sh — Standalone destructive disk wipe tool for /dev/nvme1n1
# Usage: sudo bash patrition_delete.sh
# =============================================================================

TARGET="/dev/nvme1n1"

if [[ $EUID -ne 0 ]]; then
   echo "Error: Root privileges required."
   exit 1
fi

echo "1. Disabling swap..."
swapoff --all 2>/dev/null

echo "2. Force unmounting partitions on ${TARGET}..."
umount -f -l ${TARGET}p* 2>/dev/null

echo "3. Stopping mdadm and dmraid..."
mdadm --stop --scan 2>/dev/null
dmraid -an 2>/dev/null

echo "4. Force removing device-mapper mappings..."
dmsetup remove_all --force 2>/dev/null

echo "5. Zeroing disk headers (dd)..."
dd if=/dev/zero of=${TARGET} bs=1M count=10 oflag=sync status=none

echo "6. Destroying GPT/MBR tables (sgdisk)..."
sgdisk --zap-all ${TARGET} 2>/dev/null

echo "7. Wiping remaining signatures (wipefs)..."
wipefs -a ${TARGET} 2>/dev/null

echo "8. Forcing kernel partition table re-read (partprobe)..."
partprobe ${TARGET} 2>/dev/null

echo "Disk wipe complete."