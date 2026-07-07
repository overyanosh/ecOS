#!/bin/bash
set -euo pipefail

# === ecOS — Flash image to USB drive ===

IMAGE="${1:?Usage: $0 <image.raw.xz>}"
DEVICE="${2:-auto}"

echo "============================================"
echo "  ecOS — USB Flasher"
echo "============================================"
echo ""

# --- Trouver la clé USB ---
if [[ "$DEVICE" == "auto" ]]; then
    echo "Available removable drives:"
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,TRAN,RM | grep -E "RM.*1"
    echo ""
    read -rp "Enter device name (e.g., sdb): " DEVICE
fi

DEV_PATH="/dev/${DEVICE}"

# --- Vérifications ---
if [[ ! -b "$DEV_PATH" ]]; then
    echo "❌ Device $DEV_PATH not found!"
    exit 1
fi

if lsblk -no RM "$DEV_PATH" | grep -q "^0$"; then
    echo "⚠️  Warning: $DEV_PATH does not appear to be removable!"
    echo "Are you sure? This will ERASE ALL DATA on $DEV_PATH"
    read -rp "Type 'YES' to continue: " CONFIRM
    [[ "$CONFIRM" == "YES" ]] || exit 1
fi

# --- Démonter toutes les partitions ---
echo "Unmounting $DEVICE..."
lsblk -no NAME "$DEV_PATH" | xargs -I{} umount /dev/{} 2>/dev/null || true

# --- Flash ---
echo "Flashing image to $DEV_PATH..."
echo "This may take several minutes..."

if [[ "$IMAGE" == *.xz ]]; then
    xzcat "$IMAGE" | sudo dd of="$DEV_PATH" bs=4M status=progress conv=fsync iflag=fullblock
else
    sudo dd if="$IMAGE" of="$DEV_PATH" bs=4M status=progress conv=fsync
fi

sync
echo ""
echo "============================================"
echo "  ✅ ecOS flashed to $DEV_PATH!"
echo "============================================"
echo ""
echo "Partitions créées:"
lsblk -o NAME,SIZE,TYPE,FSTYPE "$DEV_PATH"
echo ""
echo "👉 Boot sur la clé USB, ecOS lancera le firstboot automatiquement."