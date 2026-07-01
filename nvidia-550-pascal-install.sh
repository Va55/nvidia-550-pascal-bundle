#!/usr/bin/bash
# nvidia-550-pascal-install.sh
# Install NVIDIA 550.163.01 driver + CUDA 12.4 from Debian repos
# Compatible with Debian 13 (Trixie)+
# Designed for Tesla P4 / Pascal GPUs — 550 is the last driver branch supporting them.
#
# Usage:
#   sudo ./nvidia-550-pascal-install.sh
#
# This will:
#   1. Enable Debian non-free repos (if not already)
#   2. Pin nvidia packages to 550 series
#   3. Install NVIDIA 550 driver + CUDA 12.4
#   4. Build kernel module via DKMS
#   5. Load nvidia module and start nvidia-persistenced

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  NVIDIA 550.163.01 Installer           ${NC}"
echo -e "${GREEN}  (Tesla P4 / Pascal GPUs)              ${NC}"
echo -e "${GREEN}  Fetches packages from Debian repos    ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: must run as root (use sudo)${NC}"
    exit 1
fi

# --- Detect Debian release ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DEBIAN_CODENAME="${VERSION_CODENAME:-trixie}"
else
    DEBIAN_CODENAME="trixie"
fi
echo -e "${GREEN}Detected: ${ID} ${VERSION_ID} (${DEBIAN_CODENAME})${NC}"

# --- Step 1: Ensure non-free repos ---
echo -e "${GREEN}[1/5] Enabling Debian non-free repositories...${NC}"
NONFREE_SOURCE="/etc/apt/sources.list.d/nvidia-550-nonfree.sources"
if [ ! -f "$NONFREE_SOURCE" ]; then
    cat > "$NONFREE_SOURCE" <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: ${DEBIAN_CODENAME} ${DEBIAN_CODENAME}-updates ${DEBIAN_CODENAME}-backports
Components: main non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    echo -e "${GREEN}  Added ${NONFREE_SOURCE}${NC}"
else
    echo -e "${GREEN}  Non-free repos already configured${NC}"
fi

# --- Step 2: Pin nvidia packages to 550 ---
echo -e "${GREEN}[2/5] Pinning nvidia packages to 550 series...${NC}"
PIN_FILE="/etc/apt/preferences.d/nvidia-550-pin"
if [ ! -f "$PIN_FILE" ]; then
    cat > "$PIN_FILE" <<'EOF'
# Pin nvidia packages to 550 series (last Pascal-compatible branch)
Package: nvidia-driver nvidia-driver-bin nvidia-driver-libs nvidia-smi
Pin: version 550.*
Pin-Priority: 1001

Package: nvidia-kernel-dkms nvidia-kernel-support nvidia-kernel-common
Pin: version 550.*
Pin-Priority: 1001

Package: nvidia-settings nvidia-persistenced nvidia-modprobe
Pin: version 550.*
Pin-Priority: 1001

Package: xserver-xorg-video-nvidia nvidia-vdpau-driver
Pin: version 550.*
Pin-Priority: 1001

Package: libcuda1 libnvidia-* libgl1-nvidia-* libegl-nvidia* libglx-nvidia*
Pin: version 550.*
Pin-Priority: 1001

Package: firmware-nvidia-gsp firmware-nvidia-graphics
Pin: version 550.*
Pin-Priority: 1001

# CUDA packages (any version is fine, these don't affect driver)
Package: libcublas12 libcublaslt12 libcudart12 libcufft11 libcurand10
Pin: version 12.4*
Pin-Priority: 1001

Package: libcusolver11 libcusolvermg11 libcusparse12 libnvjitlink12
Pin: version 12.4*
Pin-Priority: 1001

Package: libnpp* libnvjpeg12 libcupti* nvidia-cuda-* nsight-*
Pin: version 12.4*
Pin-Priority: 1001
EOF
    echo -e "${GREEN}  Added ${PIN_FILE}${NC}"
else
    echo -e "${GREEN}  Pin file already exists${NC}"
fi

# --- Step 3: Install packages ---
echo -e "${GREEN}[3/5] Installing NVIDIA 550 driver + CUDA 12.4...${NC}"
apt update

# Driver packages
apt install -y nvidia-driver nvidia-smi nvidia-kernel-dkms nvidia-settings \
    nvidia-persistenced firmware-nvidia-gsp firmware-nvidia-graphics

# CUDA runtime (optional, skip with --no-cuda flag)
if [ "${1:-}" != "--no-cuda" ]; then
    echo -e "${GREEN}  Installing CUDA 12.4 runtime...${NC}"
    apt install -y libcublas12 libcudart12 libcufft11 libcurand10 \
        libcusolver11 libcusparse12 libnvjitlink12 libnppc12 \
        nvidia-cuda-toolkit || echo -e "${YELLOW}  Some CUDA packages unavailable, continuing...${NC}"
fi

# --- Step 4: Build and load kernel module ---
echo -e "${GREEN}[4/5] Loading NVIDIA kernel module...${NC}"
if ! lsmod | grep -q nvidia; then
    modprobe nvidia 2>/dev/null || echo -e "${YELLOW}  nvidia module not loaded — check 'dkms status'${NC}"
fi
modprobe nvidia-drm 2>/dev/null || true
modprobe nvidia-uvm 2>/dev/null || true
modprobe nvidia-modeset 2>/dev/null || true

if command -v nvidia-persistenced &>/dev/null; then
    if ! pgrep -x nvidia-persistenced &>/dev/null; then
        nvidia-persistenced --user root || true
    fi
fi

# --- Step 5: Verify ---
echo ""
echo -e "${GREEN}[5/5] Verification${NC}"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi || echo -e "${YELLOW}  nvidia-smi failed — module may not be loaded${NC}"
else
    echo -e "${YELLOW}  nvidia-smi not found${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Packages are pinned to 550 — safe from accidental upgrade.${NC}"
echo ""
echo -e "${YELLOW}To remove this NVIDIA stack:${NC}"
echo '  sudo apt purge $(dpkg -l | grep -E "^ii.*(nvidia|libcuda|libnv|libcublas|libcufft|libcurand|libcusolver|libcusparse|libnpp|nsight)" | awk "{print \$2}" | sed "s/:amd64//" | sort -u | tr "\n" " ")'
echo '  sudo apt autoremove --purge'
echo ""
echo -e "${YELLOW}To temporary unhold for future upgrades (if you move to newer GPU):${NC}"
echo "  sudo rm /etc/apt/preferences.d/nvidia-550-pin"
echo "  sudo rm /etc/apt/sources.list.d/nvidia-550-nonfree.sources"
echo "  sudo apt update"
