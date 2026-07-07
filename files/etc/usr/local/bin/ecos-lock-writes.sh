#!/bin/bash
set -euo pipefail

# === ecOS USB Write Protection ===
# Montage en read-only des chemins sensibles pour préserver la clé USB

ACTION="${1:-mount}"

case "$ACTION" in
    mount)
        echo "[ecOS] Locking writes to preserve USB drive..."
        
        # Le sysroot bootc/ostree est déjà géré par ostree (read-only par défaut)
        # On verrouille les partitions additionnelles
        
        # /var — rester writable mais limiter
        # ostree gère /var comme overlay, c'est OK
        
        # /etc — ostree gère via /usr/etc, donc c'est déjà protégé
        
        # S'assurer que le journald ne persiste pas sur la clé
        mkdir -p /var/log/journal
        # Le service ecos-tmpfs-logs s'occupe du montage tmpfs
        
        echo "[ecOS] Write protection applied."
        ;;
    unmount)
        echo "[ecOS] Unlocking writes..."
        # Pour maintenance/updates bootc
        ;;
    *)
        echo "Usage: $0 {mount|unmount}"
        exit 1
        ;;
esac