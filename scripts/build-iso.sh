#!/bin/bash
set -euo pipefail

# === ecOS — Build ISO/USB image ===
# Utilise bootc-image-builder pour générer une image bootable

IMAGE_NAME="ecos"
IMAGE_TAG="latest"
REGISTRY="ghcr.io/overyanosh/${IMAGE_NAME}:${IMAGE_TAG}"
OUTPUT_DIR="./output"
ARCH="$(uname -m)"

echo "============================================"
echo "  ecOS — Image Builder"
echo "============================================"
echo "Target: $REGISTRY"
echo "Arch:   $ARCH"
echo "Output: $OUTPUT_DIR"
echo ""

# --- 1. Build du container image ---
echo "[1/4] Building bootc container image..."
podman build -t "${IMAGE_NAME}:${IMAGE_TAG}" -f container/Containerfile .

# --- 2. Push vers le registry ---
echo "[2/4] Pushing to registry..."
podman push "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}" || \
    echo "[WARN] Push failed — continuing with local image"

# --- 3. Génération de l'image disque bootable avec bootc-image-builder ---
echo "[3/4] Generating bootable disk image..."
mkdir -p "$OUTPUT_DIR"

# Installer bootc-image-builder si nécessaire
which bootc-image-builder >/dev/null 2>&1 || {
    echo "[!] bootc-image-builder not found. Installing..."
    sudo dnf install -y bootc-image-builder 2>/dev/null || \
    pip install bootc-image-builder
}

# Générer l'image (format raw qui sera flashée sur USB)
sudo bootc-image-builder \
    --type disk \
    --output "$OUTPUT_DIR/ecos-${ARCH}.raw" \
    --arch "$ARCH" \
    "${IMAGE_NAME}:${IMAGE_TAG}"

# --- 4. Compression ---
echo "[4/4] Compressing image..."
xz -v -T0 "$OUTPUT_DIR/ecos-${ARCH}.raw"

echo ""
echo "============================================"
echo "  ✅ Image built successfully!"
echo "============================================"
echo "Output: $OUTPUT_DIR/ecos-${ARCH}.raw.xz"
echo ""
echo "To flash to USB: ./scripts/flash-usb.sh $OUTPUT_DIR/ecos-${ARCH}.raw.xz"