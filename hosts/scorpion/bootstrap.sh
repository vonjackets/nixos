#!/usr/bin/env bash
set -euo pipefail

# ── VERIFY THESE BEFORE RUNNING ───────────────────────────────────
# Run `lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT` first.
# ROTA=0 is SSD, ROTA=1 is HDD.
SSD="/dev/sda"
HDD="/dev/sdb"
# ──────────────────────────────────────────────────────────────────

for dev in "$SSD" "$HDD"; do
  [[ -b "$dev" ]] || { echo "ERROR: $dev not found"; exit 1; }
done

lsblk -o NAME,SIZE,ROTA,TYPE,MOUNTPOINT
echo ""
echo "SSD target : $SSD"
echo "HDD target : $HDD"
echo ""
echo "THIS WILL DESTROY ALL DATA ON BOTH DRIVES."
read -rp "Type YES to continue: " confirm
[[ "$confirm" == "YES" ]] || exit 1

# ── WIPE ──────────────────────────────────────────────────────────
sgdisk --zap-all "$SSD"
sgdisk --zap-all "$HDD"

# ── PARTITION SSD: EFI + root only ────────────────────────────────
sgdisk \
  --new=1:0:+1G   --typecode=1:ef00 --change-name=1:"EFI" \
  --new=2:0:0     --typecode=2:8300 --change-name=2:"nixos-root" \
  "$SSD"

# ── PARTITION HDD: swap + /main ───────────────────────────────────
# 8G swap is plenty; rest goes to /main for podman storage, data, etc.
sgdisk \
  --new=1:0:+8G   --typecode=1:8200 --change-name=1:"swap" \
  --new=2:0:0     --typecode=2:8300 --change-name=2:"main" \
  "$HDD"

partprobe "$SSD"
partprobe "$HDD"
sleep 2

# ── FORMAT ────────────────────────────────────────────────────────
mkfs.fat  -F 32 -n EFI        "${SSD}1"
mkfs.ext4 -L   nixos-root     "${SSD}2"
mkswap    -L   swap            "${HDD}1"
mkfs.ext4 -L   main            "${HDD}2"

# ── MOUNT ─────────────────────────────────────────────────────────
mount /dev/disk/by-label/nixos-root /mnt

mkdir -p /mnt/boot
mount /dev/disk/by-label/EFI /mnt/boot

mkdir -p /mnt/main
mount /dev/disk/by-label/main /mnt/main

swapon /dev/disk/by-label/swap

echo ""
echo ">>> Final layout:"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$SSD" "$HDD"

# ── EMIT NEW UUIDs ────────────────────────────────────────────────
echo ""
echo ">>> UUIDs for your hardware-configuration.nix and system.nix:"
blkid -s UUID -o value "${SSD}1"  | xargs echo "  EFI   (/boot) :"
blkid -s UUID -o value "${SSD}2"  | xargs echo "  root  (/)     :"
blkid -s UUID -o value "${HDD}1"  | xargs echo "  swap          :"
blkid -s UUID -o value "${HDD}2"  | xargs echo "  main  (/main) :"

echo ""
echo ">>> Mounts ready. Drop your flake config into /mnt/etc/nixos/ and run nixos-install."
