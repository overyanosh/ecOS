#!/bin/bash
set -x  # Log everything

echo "[ecOS] Starting first boot configuration..."

ECOS_STATE="/var/lib/ecos"
ECOS_CONFIG="/var/lib/ecos/config"
mkdir -p "$ECOS_STATE" "$ECOS_CONFIG"

# --- 1. Kernel cmdline: IOMMU ---
echo "[ecOS] Configuring kernel parameters for IOMMU + VFIO..."

CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    KARGS="amd_iommu=on iommu=pt"
    echo "[ecOS] AMD CPU detected — enabling AMD IOMMU"
elif [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    KARGS="intel_iommu=on iommu=pt"
    echo "[ecOS] Intel CPU detected — enabling Intel IOMMU"
else
    KARGS="iommu=pt"
fi

KARGS="$KARGS vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1"

rpm-ostree kargs --append-if-missing="$KARGS" 2>/dev/null || \
    echo "[ecOS] WARNING: Could not set kernel args"

# --- 2. Préparer le GPU passthrough ---
echo "[ecOS] Preparing GPU passthrough..."
/usr/local/bin/ecos-prepare-gpu.sh 2>/dev/null || \
    echo "[ecOS] WARNING: GPU preparation failed"

# --- 3. Configurer le réseau bridge ---
echo "[ecOS] Setting up network bridge (br0)..."

IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^(lo|docker|virbr|veth|br0)' | head -1)

if [[ -n "$IFACE" ]]; then
    nmcli con add type bridge con-name br0 ifname br0 ipv4.method auto ipv6.method auto 2>/dev/null || true
    nmcli con add type bridge-slave con-name "br0-slave" ifname "$IFACE" master br0 2>/dev/null || true
    nmcli con up br0 2>/dev/null || true
    echo "[ecOS] Bridge br0 configured on $IFACE"
else
    echo "[ecOS] WARNING: No suitable interface found for bridge"
fi

# --- 4. Configurer le splash screen GRUB ---
echo "[ecOS] Setting up boot splash screen..."
/usr/local/bin/ecos-grub-setup.sh 2>/dev/null || \
    echo "[ecOS] GRUB setup skipped"

# --- 5. Configurer SSH ---
echo "[ecOS] Configuring SSH..."

# S'assurer que sshd démarre
systemctl enable sshd 2>/dev/null || true
systemctl start sshd 2>/dev/null || true

# --- 6. Marquer le firstboot comme terminé ---
touch "$ECOS_STATE/.firstboot-done"
echo "[ecOS] First boot configuration complete!"

# --- 7. Reboot ---
echo "[ecOS] Rebooting in 5 seconds to apply kernel parameters..."
sleep 5
reboot