[![Build ecos Image](https://github.com/overyanosh/ecos/actions/workflows/build-image.yml/badge.svg?branch=main)](https://github.com/overyanosh/ecos/actions/workflows/build-image.yml)

# ecOS  

**ecOS** — Embedded Cloud OS — un système d'exploitation immuable, basé sur AlmaLinux 9 (bootc), conçu spécifiquement pour l'hébergement de machines virtuelles gaming multi-GPU.

> Né de la frustration de ne pas trouver une distribution orientée virtualisation pure gaming headless multihead. ecOS se concentre sur **une seule chose** : faire tourner des VM gaming avec GPU passthrough, le tout pilotable depuis une interface web légère.

---

## 🎯 Philosophie

| Principe             | Implementation                                                                          |
|----------------------|-----------------------------------------------------------------------------------------|
| **Immutabilité**     | bootc + ostree — le système de base est en lecture seule                                |
| **Durabilité USB**   | Logs et temp en tmpfs, écritures minimisées sur la clé                                  |
| **Updates pilotées** | Mises à jour atomiques via container image, pas de mise à jour utilisateur à la demande |
| **Légèreté**         | Pas de cockpit, pas de 桌面, pas de services inutiles                                     |
| **Gaming-first**     | GPU passthrough, CPU pinning, hugepages, tuned gaming profile                           |

---

## 🏗️ Architecture
┌─────────────────────────────────────────────┐
│             ecos (USB bootable)             │ 
│                                             │  
│ ┌─────────────┐  ┌───────────────────────┐  │ 
│ │ AlmaLinux 9 │  │    bootc / ostree     │  │ 
│ │ (base OS)   │──│   (immutable sysroot) │  │ 
│ └─────────────┘  └───────────────────────┘  │ 
│                                             │ 
│ ┌─────────────┐  ┌───────────────────────┐  │ 
│ │  QEMU/KVM   │  │       libvirt         │  │ 
│ │ (hypervisor)│──│     (VM management)   │  │ 
│ └─────────────┘  └───────────────────────┘  │ 
│                                             │ 
│ ┌─────────────┐  ┌───────────────────────┐  │ 
│ │    VFIO     │  │IOMMU (AMD/Intel/Intel)│  │ 
│ │ (GPU PT)    │──│    auto-detected      │  │ 
│ └─────────────┘  └───────────────────────┘  │ 
│                                             │  
│ ┌─────────────┐  ┌───────────────────────┐  │ 
│ │   mdadm     │  │   iSCSI initiator     │  │ 
│ │ (soft RAID) │  │    + multipath        │  │ 
│ └─────────────┘  └───────────────────────┘  │ 
│                                             │ 
│ ┌─────────────┐ ┌───────────────────────┐   │ 
│ │    tuned    │ │    NetworkManager     │   │ 
│ │   (gaming)  │ │     (bridge br0)      │   │ 
│ └─────────────┘ └───────────────────────┘   │ 
│                                             │ 
│ ┌─────────────────────────────────────────┐ │ 
│ │  SSH (headless) — clés only, root locké │ │ 
│ └─────────────────────────────────────────┘ │ └─────────────────────────────────────────────┘ 
                 │ ▼ | 
             ┌───────────┐ 
             │   GitHub  │──→ CI/CD (Actions) 
             │(overyanosh)│──→ bootc image build          
             └───────────┘──→ bootc-image-builder ↓ disk.raw (USB bootable)

✨ Fonctionnalités
Phase 1 — Système de base (actuel)

    ✅ OS immuable basé sur AlmaLinux 9 + bootc/ostree
    ✅ Boot sur USB avec préservation de la clé (tmpfs pour logs/temp)
    ✅ GPU passthrough automatique — détection des GPU au firstboot, binding VFIO
        Support NVIDIA et AMD
        Libération du 1er GPU si pas d'iGPU (headless complet)
    ✅ IOMMU auto-détecté — AMD ou Intel selon le CPU
    ✅ Soft RAID via mdadm (sans ZFS, économe en RAM)
    ✅ iSCSI initiator + multipath pour stockage réseau
    ✅ NVMe passthrough prêt
    ✅ Tuned gaming profile — performance governor, hugepages, I/O tuning
    ✅ Réseau bridge (br0) configuré automatiquement au firstboot
    ✅ SSH headless — clés publiques uniquement, root verrouillé
    ✅ Cockpit supprimé — aucune surcouche inutile
    ✅ Updates atomiques pilotées par distribution (bootc container pulls)
    ✅ CI/CD GitHub Actions — build automatique sur push

Phase 2 — Interface web (à venir)

    🔲 Backend Go (API REST)
    🔲 Frontend Vue.js 3 (interface type Ubiquiti)
    🔲 Configuration système complète (réseau, disques, RAID)
    🔲 Gestion LED et ventilateurs (hwmon/IPMI)

Phase 3 — Gestion des VM (à venir)

    🔲 Catalogue de VM (Windows 10/11, Nobara, distros gaming, workstation)
    🔲 Création automatique (téléchargement → création → installation)
    🔲 GPU passthrough par VM (multi-GPU, multihead)
    🔲 CPU pinning via interface
    🔲 Power profiles slider
    🔲 Looking Glass support optionnel
    🔲 Snapshots et clonage de VM

📁 Structure du projet

ecos/
├── README.md
├── LICENSE                          # GPL-3.0
├── .github/
│   └── workflows/
│       └── build-image.yml          # CI: build + push + disk image
├── container/
│   ├── Containerfile                # Image bootc principale
│   └── files/
│       ├── etc/
│       │   ├── dracut.conf.d/
│       │   │   └── vfio.conf        # Dracut: early VFIO modules
│       │   ├── modprobe.d/
│       │   │   ├── vfio.conf         # VFIO binding config
│       │   │   └── blacklist.conf    # Blacklist drivers GPU natifs
│       │   ├── ssh/
│       │   │   └── sshd_config.d/
│       │   │       └── ecos.conf     # SSH durci
│       │   ├── iscsi/
│       │   │   └── iscsid.conf       # iSCSI initiator config
│       │   ├── sysctl.d/
│       │   │   └── ecos-vm.conf      # Kernel tuning VM
│       │   ├── tuned/
│       │   │   └── ecos-gaming/
│       │   │       └── tuned.conf    # Profil gaming
│       │   ├── bootc/
│       │   │   └── ecos-update-policy.conf
│       │   └── systemd/
│       │       └── system/
│       │           ├── ecos-immutable.service
│       │           ├── ecos-tmpfs-logs.service
│       │           ├── ecos-power-profile.service
│       │           └── ecos-firstboot.service
│       └── usr/
│           ├── local/
│           │   └── bin/
│           │       ├── ecos-firstboot.sh      # Setup initial auto
│           │       ├── ecos-prepare-gpu.sh     # GPU scan + VFIO
│           │       └── ecos-lock-writes.sh      # Write protection
│           └── sbin/
│               └── ecos-update-checker          # Check updates bootc
├── scripts/
│   ├── build-iso.sh                 # Build local
│   └── flash-usb.sh                  # Flash clé USB
├── web-ui/                           # Phase 2 (à venir)
│   ├── backend/                      # Go API
│   └── frontend/                     # Vue.js 3
└── docs/
    ├── ARCHITECTURE.md
    ├── BOOTC-SETUP.md
    └── GPU-PASSTHROUGH.md

🚀 Démarrage rapide
Build via GitHub Actions

Le build est entièrement automatisé. Sur un push vers main :

    Le container image est buildé et poussé vers ghcr.io/overyanosh/ecos:latest
    bootc-image-builder génère une image disque disk.raw
    L'artifact est disponible en téléchargement depuis GitHub Actions

Build local

# 1. Build du container image
podman build -t ecos:latest -f container/Containerfile .

# 2. Génération de l'image disque bootable
sudo podman pull quay.io/centos-bootc/bootc-image-builder:latest
sudo podman run --rm --privileged \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  -v $(pwd)/output:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  ecos:latest \
  --type raw \
  --rootfs xfs \
  --verbose

Flash sur clé USB

# Identifier la clé USB
lsblk

# Flasher
sudo dd if=output/disk.raw of=/dev/sdX bs=4M status=progress conv=fsync
sync

Premier boot

    Brancher la clé USB sur le serveur
    (Optionnel) Brancher une seconde clé USB avec un fichier ecos-ssh.pub contenant votre clé publique SSH
    Démarrer sur la clé USB (mode UEFI)
    ecOS exécute automatiquement le firstboot :
        Détection CPU → activation IOMMU (AMD/Intel)
        Scan des GPU → binding VFIO
        Configuration du bridge réseau br0
        Création de l'utilisateur ecos-admin
        Configuration SSH
        Application du profil tuned gaming
        Reboot automatique
    Après reboot, le système est prêt — connectez-vous via SSH

ssh ecos-admin@<ip-du-serveur>

🔧 Configuration GPU passthrough

ecOS gère automatiquement le GPU passthrough au premier boot :

    Avec iGPU (Intel/AMD intégré) : l'iGPU gère la console hôte, tous les GPU discrets passent en VFIO
    Sans iGPU (headless complet) : tous les GPU passent en VFIO, y compris le premier — l'hôte utilise efifb/simplefb

Le script ecos-prepare-gpu.sh :

    Liste tous les GPU VGA/3D détectés via lspci
    Extrait les vendor:device IDs
    Génère /etc/modprobe.d/vfio.conf avec les IDs VFIO
    Blacklist les drivers natifs (nouveau, nvidia, amdgpu, radeon)
    Régénère l'initramfs

🔄 Mises à jour

Les mises à jour ecOS suivent le modèle bootc :

    L'image container est rebuildée et poussée via CI/CD
    bootc upgrade récupère la nouvelle image
    Au prochain reboot, le système démarre sur la nouvelle version
    Rollback automatique en cas de problème (ostree garde l'ancienne version)

Les mises à jour ne peuvent pas être déclenchées manuellement par un utilisateur — elles sont pilotées par la distribution via le pipeline CI/CD.

🛠️ Stack technique

Composant           	Technologie
OS de base	            AlmaLinux 9
Immutabilité        	bootc + ostree
Hyperviseur	            QEMU/KVM + libvirt
GPU passthrough	VFIO    (NVIDIA + AMD)
Soft RAID	            mdadm
Stockage réseau	        iSCSI + device-mapper-multipath
Profils de performance	tuned (ecos-gaming custom)
Réseau	                NetworkManager (bridge br0)
Accès distant	        OpenSSH (clés uniquement)
CI/CD	                GitHub Actions
Registry	            GitHub Container Registry (GHCR)
Web UI (à venir)    	Go + Vue.js 3


📋 Prérequis matériels

    CPU 64-bit avec support IOMMU (Intel VT-d ou AMD-Vi)
    16GB RAM minimum (recommandé pour VM gaming)
    1 ou plusieurs GPU discrets (NVIDIA,AMD ou intel)
    1 clé USB (16GB+ recommandé)
    Systeme UEFI boot capable uniquement

📜 Licence

GPL-3.0
👤 Auteur

overyanosh
GitHub: @overyanosh
🗺️ Roadmap

    Phase 1 — Système de base immuable bootable USB
    Phase 2 — Interface web Go + Vue.js
    Phase 3 — Gestion des VM (catalogue, création auto, GPU PT)
    Phase 4 — Contrôle LED/ventilos
    Phase 5 — CPU pinning UI, power profiles slider

ecOS — Parce que Proxmox et Unraid ne faisaient pas exactement ça !
