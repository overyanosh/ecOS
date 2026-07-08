[![Build ecos Image](https://github.com/overyanosh/ecos/actions/workflows/build-image.yml/badge.svg?branch=main)](https://github.com/overyanosh/ecos/actions/workflows/build-image.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Base OS](https://img.shields.io/badge/base-AlmaLinux_9-orange.svg)](https://almalinux.org/)
[![Techno](https://img.shields.io/badge/bootc-enabled-6d4aff.svg)](https://github.com/uapi-group/bootc)

---

<div align="center">
  <img src="assets/ecos-logo.png" alt="ecOS Logo" width="320" />
  <h3>Embedded Cloud OS for Gaming VMs</h3>
  <sub>Immutable • Bootable USB • Multi-GPU Passthrough</sub>
</div>

<h1 align="center">🐻 ecOS</h1>

<p align="center">
  <strong>Système immuable dédié à l'hébergement de machines virtuelles gaming multi-GPU</strong>
</p>

<p align="center">
  <a href="#-features">Fonctionnalités</a> •
  <a href="#-quick-start">Démarrage rapide</a> •
  <a href="#-architecture">Architecture</a> •
  <a href="#-roadmap">Roadmap</a>
</p>

---

> Proxmox et Unraid sont d'excellents outils, mais ils ne répondent pas à un besoin précis : l'hébergement **headless** de VM gaming **multi-GPU** en passthrough pur. ecOS comble ce vide en se concentrant sur **une seule chose** : faire tourner des VM gaming avec GPU passthrough, le tout pilotable depuis une interface web légère.
---

## 🎯 Philosophy

    |      Principe         |                  Implementation                         |
    |-----------------------|---------------------------------------------------------|
    | **Immutabilité**      | bootc + ostree — système en lecture seule = sécurité    |
    | **Durabilité USB**    | Logs/temp en tmpfs, écritures minimisées                |
    | **Updates atomiques** | Pilotées par distribution (CI/CD), pas d'upgrade manuel |
    | **Headless-first**    | SSH uniquement, pas de desktop, pas de cockpit          |
    | **Gaming-focused**    | VFIO, IOMMU auto, CPU pinning, hugepages, tuned gaming  |

---

## ✨ Features

### Phase 1 — Système de base ✅

- [x] OS immuable AlmaLinux 9 + bootc/ostree
- [x] Boot USB UEFI prêt à l'emploi
- [x] GPU passthrough automatique (NVIDIA + AMD)
- [x] IOMMU autodétecté (Intel VT-d / AMD-Vi)
- [x] Soft RAID mdadm (sans ZFS gourmand en RAM)
- [x] iSCSI initiator + multipath
- [x] NVMe passthrough
- [x] Tuned gaming profile (performance governor, hugepages)
- [x] Bridge réseau `br0` auto-configuré
- [x] SSH headless (clés + mot de passe temporaire)
- [x] Updates atomiques via bootc container pulls

### Phase 2 — Interface web 🔨

- [ ] Backend Go (API REST)
- [ ] Frontend Vue.js 3 (style Ubiquiti)
- [ ] Configuration système (réseau, disques, RAID)
- [ ] Contrôle LED/ventilos (hwmon/IPMI)

### Phase 3 — Gestion des VM 🚧

- [ ] Catalogue de VM (Windows 10/11, Nobara, gaming distros)
- [ ] Création automatique (téléchargement → installation)
- [ ] Multi-head per-VM (chaque VM son propre GPU physique)
- [ ] CPU pinning via UI
- [ ] Power profiles slider
- [ ] Looking Glass support
- [ ] Snapshots + clonage de VM

---

## 🏗️ Architecture

    ┌─────────────────────────────────────────────┐ │ ecos (USB bootable) │ │ │ │ ┌──────────────┐ ┌──────────────────────┐ │ │ │ AlmaLinux 9 │ │ bootc / ostree │ │ │ │ (base OS) │──│ (immutable sysroot) │ │ │ └──────────────┘ └──────────────────────┘ │ │ │ │ ┌──────────────┐ ┌──────────────────────┐ │ │ │ QEMU/KVM │ │ libvirt │ │ │ │ (hypervisor) │──│ (VM management) │ │ │ └──────────────┘ └──────────────────────┘ │ │ │ │ ┌──────────────┐ ┌──────────────────────┐ │ │ │ VFIO │ │ IOMMU (AMD/Intel) │ │ │ │ (GPU PT) │──│ auto-detected │ │ │ └──────────────┘ └──────────────────────┘ │ │ │ │ ┌──────────────┐ ┌──────────────────────┐ │ │ │ mdadm │ │ iSCSI + multipath │ │ │ │ (RAID) │ │ (storage network) │ │ │ └──────────────┘ └──────────────────────┘ │ │ │ │ ┌──────────────┐ ┌──────────────────────┐ │ │ │ tuned │ │ NetworkManager │ │ │ │ (gaming) │ │ (bridge br0) │ │ │ └──────────────┘ └──────────────────────┘ │ │ │ │ ┌────────────────────────────────────────┐ │ │ │ SSH (headless) — clés + pass temporaire│ │ │ └────────────────────────────────────────┘ │ └─────────────────────────────────────────────┘ │ ▼ ┌──────────────┐ │ GitHub CI/CD │──→ build image → disk.raw (USB) └──────────────┘

🚀 Démarrage rapide
Via GitHub Actions (recommandé)

    Va sur github.com/overyanosh/ecos/actions
    Clique sur le dernier run réussi
    Descends à Artifacts → télécharge ecos-usb-image
    Décompresse le ZIP → tu as disk.raw

Build local (développeur)

# 1. Build container image
podman build -t ecos:latest -f container/Containerfile .

# 2. Générer image disque
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

# Flash ! (remplace sdX par ton device)
sudo dd if=disk.raw of=/dev/sdX bs=4M status=progress conv=fsync
sync

Premier boot

    Brancher la clé USB sur le serveur
    Démarrer en mode UEFI
    GRUB → écho avec le logo viking 🐻
    Le script firstboot s'exécute :
        Détection CPU → IOMMU activé
        Scan GPU → VFIO configuré
        Bridge réseau br0 créé
        Utilisateur ecos-admin créé
        Mot de passe temporaire : ecos
    Après reboot, connecte-toi via SSH :

ssh ecos-admin@<ip-du-serveur>
passwd  # change le mot de passe immédiatement

📦 Stack technique
    Composant               Technologie
    OS de base	            AlmaLinux 9
    Immutabilité	        bootc + ostree
    Hyperviseur	            QEMU/KVM + libvirt
    GPU                     Passthrough	VFIO (NVIDIA + AMD + INTEL)
    Soft RAID	            mdadm
    Stockage réseau	        iSCSI + device-mapper-multipath
    Réseau	                NetworkManager
    Accès distant	        OpenSSH
    CI/CD	                GitHub Actions
    Registry	            GHCR
    Web UI (à venir)	    Go + Vue.js 3

📋 Prérequis matériels

    CPU 64-bit avec IOMMU activé (Intel VT-d / AMD-Vi)
    16GB RAM minimum
    GPU discrets NVIDIA ou AMD
    Clé USB 16GB+ (10GB disque image)
    Serveur UEFI boot capable

📜 Licence

GPL-3.0 — voir LICENSE
👤 Auteur

overyanosh
GitHub: @overyanosh


🗺️ Roadmap
timeline
    title ecOS Development Roadmap
    Phase 1 (✅ Done) : Système immuable bootable USB<br/>GPU passthrough auto<br/>iSCSI + mdadm
    Phase 2 (🔨 In Progress) : Interface web Go + Vue.js<br/>Configuration système UI
    Phase 3 (🚧 Next) : Gestion des VM<br/>Catalogue création auto<br/>Looking Glass
    Phase 4 (⏳ Future) : Contrôle LED/ventilos<br/>CPU pinning UI

ecOS — Parce qu'aucune distribution ne faisaient exactement ça ! 🐻