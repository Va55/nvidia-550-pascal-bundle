#!/usr/bin/bash
# nvidia-550-pascal-install-rpm.sh
# Install NVIDIA 550.163.01 driver + CUDA 12.4 on RPM-based distros
# Compatible with Fedora 39+ / RHEL 9 / Rocky 9 / Alma 9
# Designed for Tesla P4 / Pascal GPUs — 550 is the last consumer driver branch supporting them.
#
# Usage:
#   sudo ./nvidia-550-pascal-install-rpm.sh
#
# This will:
#   1. Install build prerequisites (dkms, kernel-devel, etc.)
#   2. Blacklist nouveau
#   3. Download and install NVIDIA 550.163.01 driver via .run installer (DKMS)
#   4. Optionally install CUDA 12.4 via NVIDIA .run installer
#   5. Load nvidia module and start nvidia-persistenced
#   6. Regenerate initramfs
#
# Flags:
#   --no-cuda    Skip CUDA toolkit installation
#   --no-reboot  Skip reboot prompt at end

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

DRIVER_VERSION="550.163.01"
CUDA_VERSION="12.4.1"
DRIVER_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${DRIVER_VERSION}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run"
CUDA_URL="https://developer.download.nvidia.com/compute/cuda/${CUDA_VERSION}/local_installers/cuda_${CUDA_VERSION}_550.54.15_linux.run"
INSTALL_DIR="/opt/nvidia-550-pascal"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  NVIDIA ${DRIVER_VERSION} Installer (RPM)        ${NC}"
echo -e "${GREEN}  (Tesla P4 / Pascal GPUs)              ${NC}"
echo -e "${GREEN}  Downloads from NVIDIA official sources ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: must run as root (use sudo)${NC}"
    exit 1
fi

# --- Detect distro ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="${ID}"
    VERSION="${VERSION_ID}"
else
    DISTRO="unknown"
    VERSION="unknown"
fi
echo -e "${GREEN}Detected: ${DISTRO} ${VERSION}${NC}"

# --- Determine package manager ---
if command -v dnf &>/dev/null; then
    PKG_CMD="dnf"
elif command -v yum &>/dev/null; then
    PKG_CMD="yum"
else
    echo -e "${RED}Error: neither dnf nor yum found${NC}"
    exit 1
fi
echo -e "${GREEN}Package manager: ${PKG_CMD}${NC}"

# --- Step 1: Install prerequisites ---
echo ""
echo -e "${GREEN}[1/6] Installing build prerequisites...${NC}"
${PKG_CMD} install -y epel-release 2>/dev/null || true  # RHEL clones

${PKG_CMD} install -y \
    gcc make patch dkms kernel-devel kernel-headers \
    elfutils-libelf-devel libglvnd-devel \
    pciutils file findutils \
    libX11-devel libXext-devel libXrandr-devel \
    libXv-devel libXxf86vm-devel \
    xorg-x11-server-devel \
    nvidia-persistenced \
    || echo -e "${YELLOW}  Some packages may not be available on this distro — continuing${NC}"

# Ensure kernel-devel matches running kernel
KERNEL_VER=$(uname -r)
if ! rpm -q kernel-devel &>/dev/null; then
    echo -e "${YELLOW}  Installing kernel-devel for ${KERNEL_VER}...${NC}"
    ${PKG_CMD} install -y "kernel-devel-${KERNEL_VER}" || \
        ${PKG_CMD} install -y kernel-devel || \
        echo -e "${YELLOW}  kernel-devel install had issues — DKMS may fail${NC}"
fi

# --- Step 2: Blacklist nouveau ---
echo ""
echo -e "${GREEN}[2/6] Blacklisting nouveau driver...${NC}"
NOUVEAU_BLACKLIST="/etc/modprobe.d/blacklist-nouveau.conf"
if [ ! -f "$NOUVEAU_BLACKLIST" ]; then
    cat > "$NOUVEAU_BLACKLIST" << 'EOF'
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF
    echo -e "${GREEN}  Created ${NOUVEAU_BLACKLIST}${NC}"
else
    echo -e "${GREEN}  nouveau already blacklisted${NC}"
fi

# Also remove any existing nvidia drivers/modules first
echo -e "${GREEN}  Removing existing NVIDIA modules if loaded...${NC}"
rmmod -f nvidia-drm nvidia-uvm nvidia-modeset nvidia 2>/dev/null || true

# --- Step 3: Download NVIDIA driver ---
echo ""
echo -e "${GREEN}[3/6] Downloading NVIDIA ${DRIVER_VERSION} driver...${NC}"
mkdir -p "$INSTALL_DIR"
DRIVER_RUN="${INSTALL_DIR}/NVIDIA-Linux-x86_64-${DRIVER_VERSION}.run"

if [ ! -f "$DRIVER_RUN" ]; then
    echo -e "${GREEN}  Downloading ${DRIVER_URL} ...${NC}"
    curl -fSL -o "$DRIVER_RUN" "$DRIVER_URL"
    chmod +x "$DRIVER_RUN"
    echo -e "${GREEN}  Downloaded ($(du -h "$DRIVER_RUN" | cut -f1))${NC}"
else
    echo -e "${GREEN}  Already downloaded ($(du -h "$DRIVER_RUN" | cut -f1))${NC}"
fi

# --- Step 4: Install NVIDIA driver ---
echo ""
echo -e "${GREEN}[4/6] Installing NVIDIA ${DRIVER_VERSION} driver...${NC}"

# Run the .run installer non-interactively
# --silent        : no interactive prompts
# --dkms          : build kernel module via DKMS
# --no-cc-version-check : don't fail on compiler version mismatch
# --install-compat32-libs : install 32-bit compatibility libs (optional)
echo -e "${GREEN}  Running NVIDIA .run installer (this may take a while)...${NC}"
"$DRIVER_RUN" \
    --silent \
    --dkms \
    --no-cc-version-check \
    --no-x-check \
    --no-nouveau-check \
    --no-opengl-files \
    --no-install-libglvnd \
    --kernel-module-type=dkms \
    --run-nvidia-xconfig \
    || {
        echo -e "${YELLOW}  .run installer returned non-zero — checking for errors...${NC}"
        if [ -f /var/log/nvidia-installer.log ]; then
            tail -30 /var/log/nvidia-installer.log
        fi
        echo -e "${RED}  Driver install encountered issues — inspect /var/log/nvidia-installer.log${NC}"
    }

# --- Step 5: Install CUDA 12.4 (optional) ---
if [ "${1:-}" != "--no-cuda" ] && [ "${2:-}" != "--no-cuda" ]; then
    echo ""
    echo -e "${GREEN}[5/6] Downloading/Installing CUDA ${CUDA_VERSION}...${NC}"
    CUDA_RUN="${INSTALL_DIR}/cuda_${CUDA_VERSION}_550.54.15_linux.run"

    if [ ! -f "$CUDA_RUN" ]; then
        echo -e "${GREEN}  Downloading ${CUDA_URL} ...${NC}"
        curl -fSL -o "$CUDA_RUN" "$CUDA_URL"
        chmod +x "$CUDA_RUN"
        echo -e "${GREEN}  Downloaded ($(du -h "$CUDA_RUN" | cut -f1))${NC}"
    fi

    echo -e "${GREEN}  Running CUDA installer...${NC}"
    "$CUDA_RUN" --silent --toolkit --no-opengl-libs --override 2>/dev/null || \
        echo -e "${YELLOW}  CUDA install had issues — check /var/log/cuda-installer.log${NC}"

    # Add CUDA to PATH for all users
    if [ -d /usr/local/cuda-12.4 ]; then
        echo 'export PATH=/usr/local/cuda-12.4/bin${PATH:+:${PATH}}' > /etc/profile.d/cuda.sh
        echo 'export LD_LIBRARY_PATH=/usr/local/cuda-12.4/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}' >> /etc/profile.d/cuda.sh
        chmod +x /etc/profile.d/cuda.sh
    fi
else
    echo ""
    echo -e "${YELLOW}[5/6] Skipping CUDA installation (--no-cuda)${NC}"
fi

# --- Load kernel module and start persistenced ---
echo ""
echo -e "${GREEN}[6/6] Loading NVIDIA kernel module & starting persistenced...${NC}"

# Regenerate initramfs to embed nouveau blacklist
if command -v dracut &>/dev/null; then
    echo -e "${GREEN}  Regenerating initramfs...${NC}"
    dracut --force
elif command -v mkinitrd &>/dev/null; then
    mkinitrd --force
fi

# Load modules
modprobe nvidia 2>/dev/null || echo -e "${YELLOW}  nvidia module not loaded — may need reboot${NC}"
modprobe nvidia-drm 2>/dev/null || true
modprobe nvidia-uvm 2>/dev/null || true
modprobe nvidia-modeset 2>/dev/null || true

# Start persistenced
if command -v nvidia-persistenced &>/dev/null; then
    systemctl enable nvidia-persistenced 2>/dev/null || true
    systemctl start nvidia-persistenced 2>/dev/null || \
        nvidia-persistenced --user root 2>/dev/null || true
fi

# --- Verify ---
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Verification${NC}"
echo -e "${GREEN}========================================${NC}"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi || echo -e "${YELLOW}  nvidia-smi failed — module may not be loaded${NC}"
else
    echo -e "${YELLOW}  nvidia-smi not found — may need to install separately${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation complete!                 ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}NOTE: If the nvidia module didn't load, a reboot is required.${NC}"
echo -e "${YELLOW}Driver files are pinned in ${INSTALL_DIR}/ — safe from upgrades.${NC}"
echo ""

if [ "${1:-}" != "--no-reboot" ] && [ "${2:-}" != "--no-reboot" ]; then
    echo -e "${YELLOW}It is recommended to reboot now. Reboot? [y/N]${NC}"
    read -r REBOOT_ANS
    if [[ "$REBOOT_ANS" =~ ^[Yy]$ ]]; then
        reboot
    fi
fi

echo ""
echo -e "${YELLOW}To remove this NVIDIA stack entirely:${NC}"
echo "  sudo ${DRIVER_RUN} --uninstall"
echo "  sudo rm -rf ${INSTALL_DIR}"
echo ""
echo -e "${YELLOW}To reinstall (e.g. after kernel update where DKMS didn't trigger):${NC}"
echo "  sudo ${DRIVER_RUN} --silent --dkms --no-cc-version-check --no-x-check"
