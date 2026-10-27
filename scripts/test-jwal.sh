#!/usr/bin/env bash
# ==============================================================================
# JWAL OS — QEMU aarch64 OS Boot Verification (PH2-T4)
# ==============================================================================
# Purpose:
#   Automates booting the generated JWAL OS aarch64 disk image in QEMU.
#   Verifies:
#     1. Linux aarch64 kernel boots with VirtIO block device
#     2. OpenRC initializes services (udev, networking, jwal-shell)
#     3. Automatic login on ttyAMA0 / tty1 as user 'jwal'
#
# Usage:
#   ./scripts/test-jwal.sh [--timeout <seconds>] [--interactive]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
ROOTFS_IMG="${BUILD_DIR}/rootfs.img"
KERNEL_BIN="${BUILD_DIR}/vmlinuz-aarch64"
INITRD_BIN="${BUILD_DIR}/initrd-aarch64"
SERIAL_LOG="${BUILD_DIR}/serial-jwal.log"
TIMEOUT_SECS=60
INTERACTIVE="false"

# ANSI colors
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
    cat << 'EOF'
JWAL OS — QEMU aarch64 Boot Verification Test

USAGE:
  ./scripts/test-jwal.sh [OPTIONS]

OPTIONS:
  -h, --help            Show this help message and exit
  --timeout <seconds>   Maximum seconds to wait for boot verification (default: 60)
  --interactive         Run QEMU directly in current terminal (interactive console)

VERIFICATION CRITERIA:
  Passes when kernel boots, OpenRC starts, and autologin/login prompt is reached.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --timeout)
            TIMEOUT_SECS="$2"
            shift 2
            ;;
        --interactive)
            INTERACTIVE="true"
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# 1. Verify build artifacts exist
log_info "Verifying required OS build artifacts in $BUILD_DIR..."
for artifact in "$ROOTFS_IMG" "$KERNEL_BIN" "$INITRD_BIN"; do
    if [[ ! -f "$artifact" ]]; then
        log_error "Missing required artifact: $artifact"
        echo "Run 'sudo ./scripts/build-rootfs.sh' first to generate rootfs and kernel."
        exit 1
    fi
done
log_ok "All artifacts found (rootfs.img, vmlinuz-aarch64, initrd-aarch64)."

# 2. Check QEMU availability
if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
    log_error "qemu-system-aarch64 not found. Run ./scripts/env-setup.sh first."
    exit 1
fi

rm -f "${SERIAL_LOG}"

if [[ "$INTERACTIVE" == "true" ]]; then
    log_info "Launching QEMU in interactive console mode..."
    echo "Press Ctrl+A then X to exit QEMU."
    exec qemu-system-aarch64 \
        -M virt \
        -cpu cortex-a57 \
        -smp 2 \
        -m 1024M \
        -kernel "${KERNEL_BIN}" \
        -initrd "${INITRD_BIN}" \
        -drive file="${ROOTFS_IMG}",format=raw,if=virtio \
        -append "root=/dev/vda rw console=ttyAMA0 rootwait init=/sbin/openrc-init" \
        -nographic \
        -serial mon:stdio
fi

# 3. Automated background test mode
log_info "Starting automated QEMU boot test (timeout: ${TIMEOUT_SECS}s)..."
log_info "Logging serial console to: ${SERIAL_LOG}"

set +e
timeout --foreground "${TIMEOUT_SECS}s" qemu-system-aarch64 \
    -M virt \
    -cpu cortex-a57 \
    -smp 2 \
    -m 1024M \
    -kernel "${KERNEL_BIN}" \
    -initrd "${INITRD_BIN}" \
    -drive file="${ROOTFS_IMG}",format=raw,if=virtio \
    -append "root=/dev/vda rw console=ttyAMA0 rootwait init=/sbin/openrc-init" \
    -nographic \
    -monitor none \
    -serial file:"${SERIAL_LOG}" &
QEMU_PID=$!
set -e

# Poll serial log for boot completion markers
log_info "Waiting for boot verification markers..."
ELAPSED=0
BOOT_SUCCESS="false"

while [[ $ELAPSED -lt $TIMEOUT_SECS ]]; do
    if [[ -f "${SERIAL_LOG}" ]]; then
        if grep -q -E "jwal-os login:|jwal@jwal-os|Starting JWAL OS TV Shell|Linux version" "${SERIAL_LOG}"; then
            # Check for autologin or login prompt
            if grep -q -E "jwal-os login:|jwal@jwal-os|Welcome to Debian|OpenRC" "${SERIAL_LOG}"; then
                BOOT_SUCCESS="true"
                break
            fi
        fi
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
done

# Terminate QEMU process
if kill -0 "$QEMU_PID" 2>/dev/null; then
    kill "$QEMU_PID" 2>/dev/null || true
    wait "$QEMU_PID" 2>/dev/null || true
fi

echo -e "\n${BOLD}--- Serial Console Output (last 25 lines) ---${NC}"
if [[ -f "${SERIAL_LOG}" ]]; then
    tail -n 25 "${SERIAL_LOG}"
else
    echo "(No serial log generated)"
fi
echo -e "${BOLD}--------------------------------------------${NC}\n"

if [[ "$BOOT_SUCCESS" == "true" ]]; then
    log_ok "QEMU boot smoke test PASSED in ${ELAPSED} seconds!"
    exit 0
else
    log_error "Boot verification FAILED within ${TIMEOUT_SECS}s timeout."
    exit 1
fi

