# ---- ecOS bootc image ----
# Base: AlmaLinux 9 bootc
FROM quay.io/almalinuxorg/9-bootc:latest

LABEL org.opencontainers.image.title="ecOS"
LABEL org.opencontainers.image.description="Gaming-focused immutable virtualization host"
LABEL org.opencontainers.image.source="https://github.com/overyanosh/ecOS"
LABEL org.opencontainers.image.licenses="GPL-3.0"

# ============================================================
# 1. PACKAGES — Virtualisation + GPU passthrough + RAID + réseau
# ============================================================
RUN dnf -y update && dnf -y install \
    qemu-kvm \
    qemu-img \
    libvirt \
    libvirt-client \
    virt-install \
    virt-manager-cli \
    genisoimage \
    bridge-utils \
    vlan \
    iptables-nft \
    iproute \
    mdadm \
    lvm2 \
    nvme-cli \
    smartmontools \
    pciutils \
    usbutils \
    tuned \
    tuned-profiles-cpu-partitioning \
    lm_sensors \
    dmidecode \
    edk2-ovmf \
    swtpm \
    wget \
    curl \
    rsync \
    git \
    podman \
    bootc \
    skopeo \
    ostree \
    && dnf clean all

# ============================================================
# 2. KERNEL & IOMMU CONFIGURATION
# ============================================================

# -- Kernel command line via grub bls (bootc gère grub automatiquement,
#    mais on force certains params via rpm-ostree kargs dans un script firstboot)

# Dracut: charger VFIO tôt dans l'initramfs
COPY files/etc/dracut.conf.d/vfio.conf /etc/dracut.conf.d/vfio.conf

# -- VFIO module config
COPY files/etc/modprobe.d/vfio.conf /etc/modprobe.d/vfio.conf
COPY files/etc/modprobe.d/blacklist.conf /etc/modprobe.d/blacklist.conf

# ============================================================
# 3. SYSTEMD SERVICES — Immutabilité & protection USB
# ============================================================

COPY files/etc/systemd/system/ecos-immutable.service \
     /etc/systemd/system/ecos-immutable.service
COPY files/etc/systemd/system/ecos-tmpfs-logs.service \
     /etc/systemd/system/ecos-tmpfs-logs.service
COPY files/etc/systemd/system/ecos-power-profile.service \
     /etc/systemd/system/ecos-power-profile.service

RUN systemctl enable ecos-immutable.service && \
    systemctl enable ecos-tmpfs-logs.service && \
    systemctl enable ecos-power-profile.service

# ============================================================
# 4. KERNEL TUNING — Virtualisation gaming
# ============================================================

COPY files/etc/sysctl.d/ecos-vm.conf /etc/sysctl.d/ecos-vm.conf
RUN sysctl --system || true

# ============================================================
# 5. TUNED PROFILE — ecOS-gaming
# ============================================================

COPY files/etc/tuned/ecos-gaming/tuned.conf \
     /etc/tuned/ecos-gaming/tuned.conf
RUN tuned-adm profile ecos-gaming || true

# ============================================================
# 6. ECOS BINAIRES & SCRIPTS
# ============================================================

COPY files/usr/local/bin/ecos-firstboot.sh /usr/local/bin/ecos-firstboot.sh
COPY files/usr/local/bin/ecos-prepare-gpu.sh /usr/local/bin/ecos-prepare-gpu.sh
COPY files/usr/local/bin/ecos-lock-writes.sh /usr/local/bin/ecos-lock-writes.sh
COPY files/usr/sbin/ecos-update-checker /usr/sbin/ecos-update-checker

RUN chmod +x /usr/local/bin/ecos-*.sh /usr/sbin/ecos-update-checker

# ============================================================
# 7. DISABLE COCKPIT (si présent dans la base)
# ============================================================

RUN dnf -y remove cockpit* 2>/dev/null || true && \
    systemctl mask cockpit.socket cockpit.service 2>/dev/null || true

# ============================================================
# 8. ENABLE SERVICES DE BASE
# ============================================================

RUN systemctl enable libvirtd && \
    systemctl enable virtlogd && \
    systemctl enable tuned && \
    systemctl enable NetworkManager

# ============================================================
# 9. FIRSTBOOT — Trigger via systemd
# ============================================================

COPY files/etc/systemd/system/ecos-firstboot.service \
     /etc/systemd/system/ecos-firstboot.service
RUN systemctl enable ecos-firstboot.service

# ============================================================
# 10. bootc config — Update policy: distribution-controlled
# ============================================================

COPY files/etc/bootc/ /etc/bootc/

# ============================================================
# 11. USERS — root locked, admin user created at firstboot
# ============================================================

RUN passwd -l root

# ============================================================
# FIN
# ============================================================