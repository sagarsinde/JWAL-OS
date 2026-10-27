#!/usr/bin/env bash
# ==============================================================================
# JWAL OS — Minimal aarch64 Root Filesystem Generator
# ==============================================================================
# Task: PH2-T1
# Purpose:
#   Builds a lean, bootable aarch64 Linux rootfs using Debian-slim (glibc)
#   with OpenRC init and automated tty1 autologin for user 'jwal'.
#
# Requirements (WSL2 Ubuntu):
#   - debootstrap, qemu-user-static, binfmt-support
#   - Root privileges (sudo)
# ==============================================================================

set -euo pipefail

# Default Configuration
DEBIAN_RELEASE="bookworm"
DEBIAN_MIRROR="http://deb.debian.org/debian"
TARGET_ARCH="arm64"
ROOT_PASS="jwal"
USER_NAME="jwal"
USER_PASS="jwal"
HOSTNAME="jwal-os"

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
IMAGE_OUTPUT="${BUILD_DIR}/rootfs.img"
# Always build on native ext4 (avoids Windows 9p/NTFS tar & permission errors)
WORK_DIR="/var/tmp/jwal-rootfs"
OUTPUT_DIR="$WORK_DIR"

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error(){ echo -e "${RED}[ERROR]${NC} $*" >&2; }

show_help() {
    cat << 'HELP_EOF'
JWAL OS — aarch64 Root Filesystem Builder

USAGE:
  sudo ./scripts/build-rootfs.sh [OPTIONS]

OPTIONS:
  -h, --help            Show this help message and exit
  -o, --output DIR      Output directory for rootfs (default: ./build/rootfs)
  -r, --release CODENAME Debian release codename (default: bookworm)
  --clean               Remove existing output directory before building

FEATURES:
  - Minimal aarch64 rootfs via debootstrap (glibc base for Flutter compatibility)
  - OpenRC deterministic service manager
  - Automatic console autologin on tty1 & ttyAMA0 for user 'jwal'
  - Compact size profile with apt caches purged
HELP_EOF
}

# Parse options
CLEAN_BUILD="false"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -r|--release)
            DEBIAN_RELEASE="$2"
            shift 2
            ;;
        --clean)
            CLEAN_BUILD="true"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

check_prerequisites() {
    log_info "Checking build host prerequisites..."
    if [[ $EUID -ne 0 ]]; then
        log_error "This script requires root privileges to mount filesystems and run debootstrap."
        echo "Please run: sudo $0 $*"
        exit 1
    fi

    local missing=0
    if ! command -v debootstrap >/dev/null 2>&1; then
        missing=$((missing + 1))
    fi
    if ! command -v qemu-aarch64-static >/dev/null 2>&1 && [[ ! -f "/usr/bin/qemu-aarch64-static" ]] && ! command -v qemu-aarch64 >/dev/null 2>&1; then
        missing=$((missing + 1))
    fi

    if [[ $missing -gt 0 ]]; then
        log_info "Installing debootstrap and QEMU user emulation packages..."
        apt-get update -y
        # Try qemu-user-binfmt (Ubuntu 26.04+), fallback to qemu-user-static (older Debian/Ubuntu)
        apt-get install -y --no-install-recommends debootstrap binfmt-support qemu-user-binfmt || \
            apt-get install -y --no-install-recommends debootstrap binfmt-support qemu-user-static || \
            apt-get install -y --no-install-recommends debootstrap binfmt-support qemu-user
    fi

    # Ensure /usr/bin/qemu-aarch64-static exists if only qemu-aarch64 is present
    if [[ ! -f "/usr/bin/qemu-aarch64-static" ]] && command -v qemu-aarch64-static >/dev/null 2>&1; then
        ln -sf "$(command -v qemu-aarch64-static)" /usr/bin/qemu-aarch64-static
    fi
    log_ok "Host prerequisites satisfied."
}

clean_output() {
    log_info "Preparing native ext4 workspace at $WORK_DIR..."
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR" "$BUILD_DIR"
}

bootstrap_rootfs() {
    log_info "Bootstrapping minimal aarch64 ($DEBIAN_RELEASE) into $OUTPUT_DIR..."
    
    local base_packages="linux-image-arm64,openrc,sudo,kmod,udev,procps,net-tools,iproute2,dhcpcd,wpasupplicant,cage,libwayland-client0,libegl1,libgles2,libdrm2,libgbm1,libxkbcommon0"

    if ! debootstrap --arch="$TARGET_ARCH" --variant=minbase --include="$base_packages" "$DEBIAN_RELEASE" "$OUTPUT_DIR" "$DEBIAN_MIRROR"; then
        log_warn "Single-stage debootstrap failed; attempting two-stage foreign bootstrap with QEMU..."
        debootstrap --arch="$TARGET_ARCH" --variant=minbase --foreign --include="$base_packages" "$DEBIAN_RELEASE" "$OUTPUT_DIR" "$DEBIAN_MIRROR"
        
        # Ensure qemu static binary is present in chroot
        if [[ -f "/usr/bin/qemu-aarch64-static" ]]; then
            mkdir -p "$OUTPUT_DIR/usr/bin"
            cp /usr/bin/qemu-aarch64-static "$OUTPUT_DIR/usr/bin/"
        fi
        chroot "$OUTPUT_DIR" /debootstrap/debootstrap --second-stage
    fi

    log_ok "Debootstrap phase completed."
}

configure_rootfs() {
    log_info "Configuring hostname, autologin, user accounts, and OpenRC init..."

    # 1. Hostname & Hosts
    echo "$HOSTNAME" > "$OUTPUT_DIR/etc/hostname"
    cat << EOF > "$OUTPUT_DIR/etc/hosts"
127.0.0.1   localhost
127.0.1.1   $HOSTNAME
::1         localhost ip6-localhost ip6-loopback
EOF

    # 2. Static filesystem mounts (fstab)
    cat << 'EOF' > "$OUTPUT_DIR/etc/fstab"
proc              /proc      proc    defaults              0 0
sysfs             /sys       sysfs   defaults              0 0
tmpfs             /tmp       tmpfs   defaults,nosuid,nodev 0 0
tmpfs             /run       tmpfs   mode=0755,nosuid,nodev 0 0
EOF

    # 3. User configuration
    chroot "$OUTPUT_DIR" /bin/bash -c "
        set -e
        echo 'root:$ROOT_PASS' | chpasswd

        if ! id '$USER_NAME' >/dev/null 2>&1; then
            useradd -m -s /bin/bash -G sudo,video,input,audio '$USER_NAME'
            echo '$USER_NAME:$USER_PASS' | chpasswd
        fi

        echo '$USER_NAME ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/010_jwal-nopasswd
        chmod 0440 /etc/sudoers.d/010_jwal-nopasswd
    "

    # 4. OpenRC Inittab with automated getty login on tty1 and serial ttyAMA0
    # Ensure standard /sbin/init points to OpenRC init binary
    ln -sf /sbin/openrc-init "$OUTPUT_DIR/sbin/init"

    cat << EOF > "$OUTPUT_DIR/etc/inittab"
id:3:initdefault:
si::sysinit:/sbin/openrc sysinit
rc::bootwait:/sbin/openrc boot
l3:3:wait:/sbin/openrc default
l6:6:wait:/sbin/openrc shutdown

# Autologin on primary virtual terminal (tty1)
tty1:12345:respawn:/sbin/agetty --autologin $USER_NAME --noclear 38400 tty1 linux

# Autologin on serial terminal for QEMU (ttyAMA0)
ttyAMA0:12345:respawn:/sbin/agetty --autologin $USER_NAME --noclear 115200 ttyAMA0 vt100
EOF

    # 5. Install jwal-shell service and launcher
    log_info "Installing jwal-shell OpenRC service and Wayland launcher..."
    if [[ -f "${PROJECT_ROOT}/services/jwal-shell" ]]; then
        cp "${PROJECT_ROOT}/services/jwal-shell" "$OUTPUT_DIR/etc/init.d/jwal-shell"
        chmod +x "$OUTPUT_DIR/etc/init.d/jwal-shell"
    fi
    if [[ -f "${PROJECT_ROOT}/services/jwal-shell-launcher" ]]; then
        mkdir -p "$OUTPUT_DIR/usr/local/bin"
        cp "${PROJECT_ROOT}/services/jwal-shell-launcher" "$OUTPUT_DIR/usr/local/bin/jwal-shell-launcher"
        chmod +x "$OUTPUT_DIR/usr/local/bin/jwal-shell-launcher"
    fi

    # 6. Enable baseline OpenRC services (including kiosk shell & networking)
    chroot "$OUTPUT_DIR" /bin/bash -c "
        rc-update add udev boot || true
        rc-update add jwal-shell default || true
        rc-update add dhcpcd default || true
    "

    # 7. Purge package caches to respect size budget
    log_info "Cleaning apt caches to minimize rootfs size..."
    chroot "$OUTPUT_DIR" /bin/bash -c "
        apt-get clean
        rm -rf /var/lib/apt/lists/*
        rm -rf /var/cache/apt/archives/*
        rm -rf /tmp/* /var/tmp/*
    "

    log_ok "Rootfs configuration complete."
}

package_image() {
    log_info "Creating ext4 filesystem image: $IMAGE_OUTPUT..."
    mkdir -p "$BUILD_DIR"
    
    # Calculate required image size with 20% headroom
    local used_kb
    used_kb=$(du -sk "$WORK_DIR" | cut -f1)
    local img_size_mb=$(( (used_kb / 1024) + 150 ))
    if [[ $img_size_mb -lt 800 ]]; then
        img_size_mb=800
    fi

    log_info "Packaging rootfs into ${img_size_mb} MB ext4 raw disk image using mke2fs..."
    mke2fs -t ext4 -d "$WORK_DIR" -F "$IMAGE_OUTPUT" "${img_size_mb}M"

    # Extract kernel and initramfs for direct QEMU booting
    log_info "Extracting kernel and initramfs to $BUILD_DIR for QEMU testing..."
    cp "$WORK_DIR"/boot/vmlinuz* "$BUILD_DIR/vmlinuz-aarch64" 2>/dev/null || true
    cp "$WORK_DIR"/boot/initrd.img* "$BUILD_DIR/initrd-aarch64" 2>/dev/null || true

    log_ok "Image packaging complete: $IMAGE_OUTPUT"
}

measure_size() {
    local size_mb
    size_mb=$(du -sm "$WORK_DIR" | cut -f1)
    local img_mb
    img_mb=$(du -sm "$IMAGE_OUTPUT" | cut -f1)

    echo -e "\n${GREEN}${BOLD}=== JWAL OS aarch64 Rootfs Built Successfully ===${NC}"
    echo -e "Rootfs Tree:   $WORK_DIR (${size_mb} MB)"
    echo -e "Boot Disk:     $IMAGE_OUTPUT (${img_mb} MB ext4)"
    echo -e "Kernel/Initrd: $BUILD_DIR/vmlinuz-aarch64"
    echo -e "Autologin:     User '${BOLD}$USER_NAME${NC}' on tty1 and ttyAMA0"
    echo -e "Init System:   OpenRC\n"
}

main() {
    check_prerequisites
    clean_output
    bootstrap_rootfs
    configure_rootfs
    package_image
    measure_size
}

main "$@"

