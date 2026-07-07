#!/bin/bash
set -euo pipefail

# === ecOS First Boot Configuration ===
echo "[ecOS] Starting first boot configuration..."

ECOS_STATE="/var/lib/ecos"
mkdir -p "$ECOS_STATE"

# --- 1. Kernel cmdline: activer IOMMU ---
# bootc/ostree gère le kernel via bls, on utilise rpm-ostree kargs
echo "[ecOS] Configuring kernel parameters for IOMMU + VFIO..."

KARGS=""
# Détecter CPU vendor
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    KARGS="amd_iommu=on iommu=pt"
    echo "[ecOS] AMD CPU detected — enabling AMD IOMMU"
elif [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    KARGS="intel_iommu=on iommu=pt"
    echo "[ecOS] Intel CPU detected — enabling Intel IOMMU"
fi

# Paramètres communs
KARGS="$KARGS vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1"

# Appliquer les kargs (bootc-compatible)
rpm-ostree kargs --append-if-missing="$KARGS" || true

# --- 2. Préparer le GPU passthrough ---
/usr/local/bin/ecos-prepare-gpu.sh

# --- 3. Configurer le réseau bridge ---
echo "[ecOS] Setting up network bridge (br0)..."

# Trouver l'interface physique (exclure lo, docker, virbr)
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^(lo|docker|virbr|veth)' | head -1)

if [[ -n "$IFACE" ]]; then
    nmcli con add type bridge con-name br0 ifname br0 ipv4.method auto ipv6.method auto 2>/dev/null || true
    nmcli con add type bridge-slave con-name "br0-slave" ifname "$IFACE" master br0 2>/dev/null || true
    nmcli con up br0 2>/dev/null || true
    echo "[ecOS] Bridge br0 configured on $IFACE"
fi

# --- 4. Marquer le firstboot comme terminé ---
touch "$ECOS_STATE/.firstboot-done"
echo "[ecOS] First boot configuration complete!"

# --- 5. Reboot pour appliquer les kargs ---
echo "[ecOS] Rebooting in 5 seconds to apply kernel parameters..."
sleep 5
reboot