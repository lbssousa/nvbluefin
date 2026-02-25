#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# NVIDIA Proprietary Driver Installation
###############################################################################
# This script installs the NVIDIA proprietary driver following the
# @ublue-os/hwe pattern. It requires pre-built NVIDIA kernel modules (akmods)
# mounted at /tmp/akmods-rpms from the ghcr.io/ublue-os/akmods-nvidia OCI
# container. The kernel modules are pre-signed for Secure Boot.
#
# Reference: https://github.com/ublue-os/hwe/blob/main/nvidia-install.sh
###############################################################################

RELEASE="$(rpm -E '%fedora')"

echo "::group:: Install NVIDIA Proprietary Driver"

# Disable any remaining rpmfusion repos to avoid conflicts
if ls /etc/yum.repos.d/rpmfusion*.repo &>/dev/null; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion*.repo
fi

# Disable Cisco OpenH264 repo to avoid conflicts
if [[ -f /etc/yum.repos.d/fedora-cisco-openh264.repo ]]; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo
fi

# Install NVIDIA addons (provides repo configs and systemd services)
dnf5 install -y /tmp/akmods-rpms/ublue-os/ublue-os-nvidia-addons-*.rpm

# Install multilib (32-bit) mesa packages for compatibility
# NOTE: Both x86_64 and i686 versions are installed in a single transaction to avoid
# file conflicts when the negativo17-fedora-multimedia repo (enabled by ublue-os-nvidia-addons)
# provides newer mesa versions than the base image. Installing both architectures together
# ensures dnf5 upgrades the x86_64 packages to match the i686 versions from negativo17.
MULTILIB=(
    mesa-dri-drivers
    mesa-filesystem
    mesa-libEGL
    mesa-libGL
    mesa-libgbm
    mesa-va-drivers
    mesa-vulkan-drivers
    mesa-dri-drivers.i686
    mesa-filesystem.i686
    mesa-libEGL.i686
    mesa-libGL.i686
    mesa-libgbm.i686
    mesa-va-drivers.i686
    mesa-vulkan-drivers.i686
)

dnf5 install -y "${MULTILIB[@]}"

# Enable repos provided by ublue-os-nvidia-addons
sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/negativo17-fedora-nvidia.repo
sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/nvidia-container-toolkit.repo

# Disable negativo17-fedora-multimedia to ensure negativo17-fedora-nvidia is used
if [[ -f /etc/yum.repos.d/negativo17-fedora-multimedia.repo ]] && grep -q "enabled=1" /etc/yum.repos.d/negativo17-fedora-multimedia.repo; then
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo
fi

# Source NVIDIA kernel module version info from akmods
# shellcheck source=/dev/null
source /tmp/akmods-rpms/kmods/nvidia-vars

# Install NVIDIA driver packages and pre-built kernel module
dnf5 install -y \
    libnvidia-fbc \
    libnvidia-ml.i686 \
    libva-nvidia-driver \
    nvidia-driver \
    nvidia-driver-cuda \
    nvidia-driver-cuda-libs.i686 \
    nvidia-driver-libs.i686 \
    nvidia-settings \
    nvidia-container-toolkit \
    "/tmp/akmods-rpms/kmods/kmod-nvidia-${KERNEL_VERSION}-${NVIDIA_AKMOD_VERSION}.fc${RELEASE}.rpm"

# Disable repos after install (critical - prevents repo persistence)
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-nvidia.repo
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/nvidia-container-toolkit.repo

# Ensure kernel.conf matches the NVIDIA flavor from akmods
sed -i "s/^MODULE_VARIANT=.*/MODULE_VARIANT=$KERNEL_MODULE_TYPE/" /etc/nvidia/kernel.conf

# Enable NVIDIA container toolkit CDI service
systemctl enable ublue-nvctk-cdi.service

# Install SELinux module for NVIDIA containers
semodule --verbose --install /usr/share/selinux/packages/nvidia-container.pp

# Initramfs fixes for NVIDIA desktops
cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
# Force driver load to fix black screen on boot for NVIDIA desktops
sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
# Pre-load Intel/AMD iGPU to ensure hardware acceleration works in browsers
sed -i 's@ nvidia @ i915 amdgpu nvidia @g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

echo "::endgroup::"

echo "::group:: Rebuild Initramfs"

# Rebuild initramfs with NVIDIA module support
QUALIFIED_KERNEL="$(rpm -qa | grep -oP 'kernel-core-\K[^\s]+')"
/usr/bin/dracut --no-hostonly --kver "${QUALIFIED_KERNEL}" --reproducible --zstd -v --add ostree -f "/lib/modules/${QUALIFIED_KERNEL}/initramfs.img"

echo "::endgroup::"

echo "NVIDIA driver installation complete!"
