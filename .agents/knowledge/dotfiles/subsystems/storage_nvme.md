# Subsystem: Dual-NVMe Storage Architecture (L1)

## Hardware Allocation & Partitions
The system utilizes two distinct NVMe solid-state drives:

### NVMe 0: Operating System & User Profiles (System Drive)
- `/boot/efi` (FAT32, ~1GB): EFI System Partition (ESP) for Limine / systemd-boot.
- `/` (Btrfs / Ext4, ~100GB): CachyOS root filesystem.
- `swap` (8GB): Fast paging.
- `/home` (User configs and profiles, desktop caching).

### NVMe 1: High-Performance Data & Container Drive
Managed via `playbooks/setup_system.yml`:
1. `/var/lib/docker` (XFS, `defaults,noatime,prjquota`):
   - Native Docker storage directory with project quotas enabled (`ftype=1`).
   - Diagnostic script: `sudo bash check.sh`.
2. `/var/lib/libvirt/images` (ext4, `defaults,noatime`):
   - QEMU/KVM virtual machine images without CoW (Copy-on-Write) write amplification.
3. `/data/projects` (Btrfs, `compress=zstd:3,discard=async`):
   - Project repositories and centralized toolchain stores:
     - `/data/projects/.pnpm-store` (hardlinks inside same FS).
     - `/data/projects/.uv-cache` (Python wheels compressed with zstd).
     - `/data/projects/.sccache` (Rust compilation cache).
     - `/data/projects/.cargo-cache` (Cargo crates & git checkouts).
4. `/data/sync` (Btrfs, `compress=zstd:3,discard=async`):
   - Obsidian notes (`/data/obsidian`), Zotero, synchronized documentation.

## Critical Warnings
- `patrition_delete.sh` is a destructive formatting script for `/dev/nvme1n1`. NEVER run automatically!
- Validation script: `bash check_setup.sh`.
