#!/bin/bash
set -euo pipefail

# === ecos First Boot Configuration ===
echo "[ecos] Starting first boot configuration..."

ecos_STATE="/var/lib/ecos"
mkdir -p "$ecos_STATE"

# --- 1. Kernel cmdline: activer IOMMU ---
# bootc/ostree gère le kernel via bls, on utilise rpm-ostree kargs
echo "[ecos] Configuring kernel parameters for IOMMU + VFIO..."

KARGS=""
# Détecter CPU vendor
CPU_VENDOR=$(grep -m1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

if [[ "$CPU_VENDOR" == "AuthenticAMD" ]]; then
    KARGS="amd_iommu=on iommu=pt"
    echo "[ecos] AMD CPU detected — enabling AMD IOMMU"
elif [[ "$CPU_VENDOR" == "GenuineIntel" ]]; then
    KARGS="intel_iommu=on iommu=pt"
    echo "[ecos] Intel CPU detected — enabling Intel IOMMU"
fi

# Paramètres communs
KARGS="$KARGS vfio_iommu_type1.allow_unsafe_interrupts=1 kvm.ignore_msrs=1"

# Appliquer les kargs (bootc-compatible)
rpm-ostree kargs --append-if-missing="$KARGS" || true

# --- 2. Préparer le GPU passthrough ---
/usr/local/bin/ecos-prepare-gpu.sh

# --- 3. Configurer le réseau bridge ---
echo "[ecos] Setting up network bridge (br0)..."

# Trouver l'interface physique (exclure lo, docker, virbr)
IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -vE '^(lo|docker|virbr|veth)' | head -1)

if [[ -n "$IFACE" ]]; then
    nmcli con add type bridge con-name br0 ifname br0 ipv4.method auto ipv6.method auto 2>/dev/null || true
    nmcli con add type bridge-slave con-name "br0-slave" ifname "$IFACE" master br0 2>/dev/null || true
    nmcli con up br0 2>/dev/null || true
    echo "[ecos] Bridge br0 configured on $IFACE"
fi

# --- 4. Marquer le firstboot comme terminé ---
touch "$ecos_STATE/.firstboot-done"
echo "[ecos] First boot configuration complete!"

# --- 5. Reboot pour appliquer les kargs ---
echo "[ecos] Rebooting in 5 seconds to apply kernel parameters..."
sleep 5

# --- 6. Créer l'utilisateur admin ---
echo "[ecOS] Creating admin user..."

ADMIN_USER="ecos-admin"

# Créer l'utilisateur avec home et shell
useradd -m -s /bin/bash -G wheel,libvirt "$ADMIN_USER" || true

# Générer une clé SSH si aucune n'est fournie
# (en production, on injecterait la clé via cloud-init ou un fichier)
mkdir -p "/home/$ADMIN_USER/.ssh"
chmod 700 "/home/$ADMIN_USER/.ssh"

# Si une clé publique est présente sur une partition de config (USB secondaire)
# on la copie, sinon on génère une paire de clés et on affiche la publique
if [[ -f /run/media/*/ecos-ssh.pub ]]; then
    cp /run/media/*/ecos-ssh.pub "/home/$ADMIN_USER/.ssh/authorized_keys"
    echo "[ecOS] SSH public key found on USB config partition"
else
    ssh-keygen -t ed25519 -f "/home/$ADMIN_USER/.ssh/id_ed25519" -N "" -C "ecos-admin"
    cp "/home/$ADMIN_USER/.ssh/id_ed25519.pub" "/home/$ADMIN_USER/.ssh/authorized_keys"
    echo ""
    echo "[ecOS] No SSH key found on config partition."
    echo "[ecOS] Generated key pair for $ADMIN_USER."
    echo "[ecOS] Public key:"
    cat "/home/$ADMIN_USER/.ssh/id_ed25519.pub"
    echo ""
    echo "[ecOS] Retrieve this key to connect via SSH!"
fi

chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
chown -R "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh"

# Activer l'utilisateur dans AllowUsers
sed -i "s/^#AllowUsers.*/AllowUsers $ADMIN_USER/" /etc/ssh/sshd_config.d/ecos.conf

echo "[ecOS] Admin user '$ADMIN_USER' created."
sleep 5


reboot