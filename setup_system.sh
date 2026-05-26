#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run this script as root (sudo ./setup_system.sh)"
    exit 1
fi

REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo "🔍 Available storage drives:"
echo "--------------------------------------------------------"
lsblk -d -o NAME,SIZE,MODEL | grep -E "^(nvme|sd)"
echo "--------------------------------------------------------"
echo ""
echo "Please enter the NAME of the EMPTY drive you want to format."
echo "(For example: nvme0n1 or sda)"
read -p "Target drive: " INPUT_DISK

TARGET_DISK="/dev/$INPUT_DISK"

if [ ! -b "$TARGET_DISK" ]; then
    echo "❌ Error: Device $TARGET_DISK does not exist."
    exit 1
fi

# 🚨 SAFETY CHECK: Ensure we are not formatting the active OS drive!
if lsblk -n -o MOUNTPOINT "$TARGET_DISK" | grep -q -E "^/$|^/boot"; then
    echo "❌ FATAL ERROR: $TARGET_DISK contains your active CachyOS system!"
    echo "Aborting to prevent system destruction."
    exit 1
fi

echo ""
echo "⚠️  WARNING: Drive $TARGET_DISK will be COMPLETELY FORMATTED!"
echo "   This will destroy ALL DATA on this drive."
read -p "Are you ABSOLUTELY sure? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Cancelled."
    exit 1
fi

# Handle partition naming scheme (/dev/nvme0n1p1 vs /dev/sda1)
if [[ "$TARGET_DISK" == *nvme* ]]; then
    PART_PREFIX="${TARGET_DISK}p"
else
    PART_PREFIX="${TARGET_DISK}"
fi

# ──────────────────────────────────────────────
# 1. Stop services if running
# ──────────────────────────────────────────────
echo "🛑 1. Stopping services (if running)..."
systemctl stop docker libvirtd 2>/dev/null || true

# ──────────────────────────────────────────────
# 2. Partition Target Drive
# Layout (Proportional %):
#   p1 DOCKER   15%  – Docker Engine data-root
#   p2 LIBVIRT  15%  – VM qcow2 images
#   p3 PROJECTS 22%  – code, sccache, cargo registry
#   p4 GAMES    45%  – Steam libraries
#   p5 SYNC      3%  – Obsidian, Zotero local copies
# ──────────────────────────────────────────────
echo "💾 2. Partitioning drive $TARGET_DISK..."
parted -s "$TARGET_DISK" mklabel gpt
parted -s "$TARGET_DISK" mkpart DOCKER   ext4  0%   15%
parted -s "$TARGET_DISK" mkpart LIBVIRT  ext4 15%  30%
parted -s "$TARGET_DISK" mkpart PROJECTS ext4 30%  52%
parted -s "$TARGET_DISK" mkpart GAMES    ext4 52%  97%
parted -s "$TARGET_DISK" mkpart SYNC     ext4 97%  100%

# Wait for kernel to re-read partition table
sleep 2
partprobe "$TARGET_DISK"
sleep 1

echo "🗂️  3. Formatting filesystems (ext4 + noatime)..."
mkfs.ext4 -F -L DOCKER   "${PART_PREFIX}1"
mkfs.ext4 -F -L LIBVIRT  "${PART_PREFIX}2"
mkfs.ext4 -F -L PROJECTS "${PART_PREFIX}3"
mkfs.ext4 -F -L GAMES    "${PART_PREFIX}4"
mkfs.ext4 -F -L SYNC     "${PART_PREFIX}5"

echo "📁 4. Creating mount points..."
# Docker Desktop stores its VM image in ~/.docker/desktop/
# We mount DOCKER partition to /data/docker and symlink ~/.docker → /data/docker
# This is done in setup_user.sh (requires knowing the real user's home)
mkdir -p /data/docker
mkdir -p /var/lib/libvirt/images
mkdir -p /data/{projects,games,sync,gdrive}

echo "📝 5. Configuring /etc/fstab..."
cp /etc/fstab /etc/fstab.bak
if ! grep -q "LABEL=PROJECTS" /etc/fstab; then
    cat >> /etc/fstab << 'EOF'

# ── Target Drive data partitions ─────────────────────────────────────────────
# noatime: skip access-time writes → extends SSD lifespan, improves perf
# DOCKER partition → /data/docker (symlinked from ~/.docker in setup_user.sh)
LABEL=DOCKER    /data/docker             ext4  defaults,noatime  0 2
LABEL=LIBVIRT   /var/lib/libvirt/images  ext4  defaults,noatime  0 2
LABEL=PROJECTS  /data/projects           ext4  defaults,noatime  0 2
LABEL=GAMES     /data/games              ext4  defaults,noatime  0 2
LABEL=SYNC      /data/sync               ext4  defaults,noatime  0 2
EOF
fi

echo "🔗 6. Mounting all drives..."
mount -a

echo "🔑 7. Setting ownership for user '$REAL_USER'..."
chown -R "$REAL_USER:$REAL_USER" \
    /data/docker \
    /data/projects \
    /data/games \
    /data/sync \
    /data/gdrive
# libvirt images dir must be owned by root/libvirt, fixed in step 10

echo "📦 8. Installing system packages..."
# NOTE: docker, docker-compose, docker-buildx are NOT installed here —
# Docker Desktop ships its own versions and conflicts with those packages.
# Docker Desktop is installed via AUR (docker-desktop) in setup_user.sh.
pacman -Syu --needed --noconfirm \
    base-devel \
    parted \
    libvirt \
    qemu-desktop \
    rclone \
    mold \
    sccache \
    clang \
    nodejs \
    npm \
    distrobox \
    podman \
    vim          # provides xxd, required by NCALayer installer

# ──────────────────────────────────────────────
# 9. subuid/subgid for Docker Desktop file sharing
# Docker Desktop on Linux requires these for rootless container file access
# ──────────────────────────────────────────────
echo "🔑 9. Configuring subuid/subgid for Docker Desktop..."
if ! grep -q "^${REAL_USER}:" /etc/subuid 2>/dev/null; then
    echo "${REAL_USER}:100000:65536" >> /etc/subuid
fi
if ! grep -q "^${REAL_USER}:" /etc/subgid 2>/dev/null; then
    echo "${REAL_USER}:100000:65536" >> /etc/subgid
fi

# ──────────────────────────────────────────────
# 10. NCALayer (ЭЦП / digital signature for KZ gov services)
# Installs to ~/NCALayer by default (installer asks, we use defaults)
# ──────────────────────────────────────────────
echo "🇰🇿 10. Installing NCALayer..." 
NCALAYER_TMP=$(mktemp -d)
wget -q -O "$NCALAYER_TMP/ncalayer.zip" https://ncl.pki.gov.kz/images/NCALayer/ncalayer.zip
unzip -q "$NCALAYER_TMP/ncalayer.zip" -d "$NCALAYER_TMP/ncalayer"
# Run installer as real user (NCALayer must NOT be installed as root)
sudo -u "$REAL_USER" bash "$NCALAYER_TMP/ncalayer/ncalayer.sh" --nogui
rm -rf "$NCALAYER_TMP"
echo "   ✅ NCALayer installed. Run: ~/NCALayer/ncalayer.sh --run"

echo "🚀 11. Enabling and starting services..."
# Docker Desktop manages its own daemon — we do NOT enable docker.service
# Docker Desktop installer will create the docker group and start its service
systemctl enable --now libvirtd

# libvirt needs its images dir owned correctly
chown root:libvirt /var/lib/libvirt/images
chmod 775 /var/lib/libvirt/images

# Pre-create docker group so usermod works before Desktop is installed
groupadd -f docker
usermod -aG docker,libvirt,kvm "$REAL_USER"

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅ System setup complete!                                    ║"
echo "║                                                               ║"
echo "║  IMPORTANT: Log out and back in (or reboot) to apply         ║"
echo "║  new group memberships: docker, libvirt, kvm                 ║"
echo "║                                                               ║"
echo "║  Then run: bash setup_user.sh                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"