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
OUTPUT_DIR="$(pwd)/build/rootfs"
ROOT_PASS="jwal"
USER_NAME="jwal"
USER_PASS="jwal"
HOSTNAME="jwal-os"

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
    for pkg in debootstrap qemu-aarch64-static; do
        if ! command -v "$pkg" >/dev/null 2>&1 && [[ ! -f "/usr/bin/$pkg" ]]; then
            log_warn "Missing required host tool: $pkg"
            missing=$((missing + 1))
        fi
    done

    if [[ $missing -gt 0 ]]; then
        log_info "Installing debootstrap, qemu-user-static, and binfmt-support..."
        apt-get update -y
        apt-get install -y --no-install-recommends debootstrap qemu-user-static binfmt-support
    fi
    log_ok "Host prerequisites satisfied."
}

clean_output() {
    if [[ -d "$OUTPUT_DIR" ]]; then
        if [[ "$CLEAN_BUILD" == "true" ]]; then
            log_info "Cleaning previous build directory: $OUTPUT_DIR..."
            rm -rf "$OUTPUT_DIR"
        else
            log_warn "Output directory already exists. Use --clean to rebuild from scratch."
        fi
    fi
    mkdir -p "$OUTPUT_DIR"
}

bootstrap_rootfs() {
    log_info "Bootstrapping minimal aarch64 ($DEBIAN_RELEASE) into $OUTPUT_DIR..."
    
    local base_packages="linux-image-arm64,openrc,sudo,kmod,udev,procps,net-tools,iproute2,dhcpcd,wpasupplicant,cage,libwayland-client0,libegl1,libgles2,libdrm2,libgbm1,libxkbcommon0"

    debootstrap \
        --arch="$TARGET_ARCH" \
        --variant=minbase \
        --include="$base_packages" \
        "$DEBIAN_RELEASE" \
        "$OUTPUT_DIR" \
        "$DEBIAN_MIRROR"

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

    # 5. Enable baseline OpenRC services
    chroot "$OUTPUT_DIR" /bin/bash -c "
        rc-update add udev boot || true
        rc-update add procfs boot || true
        rc-update add sysfs boot || true
    "

    # 6. Purge package caches to respect size budget
    log_info "Cleaning apt caches to minimize rootfs size..."
    chroot "$OUTPUT_DIR" /bin/bash -c "
        apt-get clean
        rm -rf /var/lib/apt/lists/*
        rm -rf /var/cache/apt/archives/*
        rm -rf /tmp/* /var/tmp/*
    "

    log_ok "Rootfs configuration complete."
}

measure_size() {
    local size_mb
    size_mb=$(du -sm "$OUTPUT_DIR" | cut -f1)
    echo -e "\n${GREEN}${BOLD}=== JWAL OS aarch64 Rootfs Built Successfully ===${NC}"
    echo -e "Location:     $OUTPUT_DIR"
    echo -e "Total Size:   ${BOLD}${size_mb} MB${NC}"
    echo -e "Autologin:    User '${BOLD}$USER_NAME${NC}' on tty1 and ttyAMA0"
    echo -e "Init System:  OpenRC\n"
}

main() {
    check_prerequisites
    clean_output
    bootstrap_rootfs
    configure_rootfs
    measure_size
}

main "$@"
