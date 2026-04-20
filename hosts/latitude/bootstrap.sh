#!/usr/bin/env bash
set -euo pipefail

# ── VERIFY BEFORE RUNNING ─────────────────────────────────────────
# Run `lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT` first.
# NVMe will show as nvme0n1, partitions as nvme0n1p1, nvme0n1p2, etc.
NVME="/dev/nvme0n1"
# ──────────────────────────────────────────────────────────────────

[[ -b "$NVME" ]] || { echo "ERROR: $NVME not found. Check lsblk output."; exit 1; }

lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT
echo ""
echo "NVMe target : $NVME"
echo ""
echo "THIS WILL DESTROY ALL DATA ON $NVME."
read -rp "Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || exit 1

# ── WIPE ──────────────────────────────────────────────────────────
sgdisk --zap-all "$NVME"

# ── PARTITION ─────────────────────────────────────────────────────
# 512GB NVMe — give swap 16G (enough for hibernate if you want it later),
# rest goes to root.
sgdisk \
  --new=1:0:+1G    --typecode=1:ef00 --change-name=1:"EFI" \
  --new=2:0:+16G   --typecode=2:8200 --change-name=2:"swap" \
  --new=3:0:0      --typecode=3:8300 --change-name=3:"nixos-root" \
  "$NVME"

partprobe "$NVME"
sleep 2

# ── FORMAT ────────────────────────────────────────────────────────
mkfs.fat  -F 32 -n EFI       "${NVME}p1"
mkswap    -L   swap           "${NVME}p2"
mkfs.ext4 -L   nixos-root    "${NVME}p3"

# ── MOUNT ─────────────────────────────────────────────────────────
mount /dev/disk/by-label/nixos-root /mnt

mkdir -p /mnt/boot
mount /dev/disk/by-label/EFI /mnt/boot

swapon /dev/disk/by-label/swap

echo ""
echo ">>> Final layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$NVME"

echo ""
echo ">>> UUIDs (for reference, hardware-configuration.nix will capture these):"
blkid -s UUID -o value "${NVME}p1" | xargs echo "  EFI   (/boot) :"
blkid -s UUID -o value "${NVME}p2" | xargs echo "  swap          :"
blkid -s UUID -o value "${NVME}p3" | xargs echo "  root  (/)     :"

echo ""
echo ">>> Mounts ready. Next steps:"
echo "    1. Get your flake repo onto this machine (git clone or cp from USB)"
echo "    2. nixos-generate-config --root /mnt"
echo "    3. cp /mnt/etc/nixos/hardware-configuration.nix hosts/latitude/"
echo "    4. nixos-install --flake /path/to/repo#latitude"
