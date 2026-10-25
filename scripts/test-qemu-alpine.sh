#!/usr/bin/env bash
# ==============================================================================
# JWAL OS — QEMU aarch64 Alpine Boot Verification (PH1-T3)
# ==============================================================================
# Purpose:
#   Boots Alpine Linux aarch64 in QEMU emulator to verify:
#     1. aarch64 CPU emulation (Cortex-A57)
#     2. UEFI / EDK2 firmware execution
#     3. Linux kernel boot & OpenRC init
#     4. Serial console output capture
#
# Usage:
#   ./scripts/test-qemu-alpine.sh [--timeout <seconds>]
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
ISO_DIR="${BUILD_DIR}/iso"
ISO_FILE="${ISO_DIR}/alpine-virt-3.21.9-aarch64.iso"
ISO_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/aarch64/alpine-virt-3.21.9-aarch64.iso"
SERIAL_LOG="${BUILD_DIR}/serial.log"
TIMEOUT_SECS=60

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout)
            TIMEOUT_SECS="$2"
            shift 2
            ;;
        *)
            log_error "Unknown argument: $1"
            exit 1
            ;;
    esac
done

mkdir -p "${ISO_DIR}"

# 1. Ensure Alpine ISO is present
if [[ ! -f "${ISO_FILE}" ]]; then
    log_info "Downloading Alpine aarch64 virt ISO..."
    wget -q --show-progress -c "${ISO_URL}" -O "${ISO_FILE}"
fi
log_ok "Alpine aarch64 ISO ready: $(du -h "${ISO_FILE}" | cut -f1)"

# 2. Locate UEFI firmware
UEFI_BIOS=""
for candidate in \
    "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd" \
    "/usr/share/AAVMF/AAVMF_CODE.fd" \
    "/usr/share/edk2/aarch64/QEMU_EFI.fd"; do
    if [[ -f "$candidate" ]]; then
        UEFI_BIOS="$candidate"
        break
    fi
done

if [[ -z "${UEFI_BIOS}" ]]; then
    log_error "No aarch64 UEFI firmware found. Ensure 'qemu-efi-aarch64' is installed."
    exit 1
fi
log_ok "UEFI firmware located: ${UEFI_BIOS}"

# 3. Clean prior serial log
rm -f "${SERIAL_LOG}"

log_info "Starting QEMU aarch64 (Cortex-A57, 1024MB RAM, UEFI, VirtIO)..."
log_info "Serial output streaming to: ${SERIAL_LOG}"
log_info "Boot timeout set to ${TIMEOUT_SECS} seconds."

# Launch QEMU with timeout
# -nographic disables GUI; -serial file:... captures serial port output directly
set +e
timeout --foreground "${TIMEOUT_SECS}s" qemu-system-aarch64 \
    -M virt \
    -cpu cortex-a57 \
    -smp 2 \
    -m 1024M \
    -bios "${UEFI_BIOS}" \
    -drive file="${ISO_FILE}",format=raw,if=virtio,media=cdrom,readonly=on \
    -nographic \
    -monitor none \
    -serial file:"${SERIAL_LOG}"
QEMU_STATUS=$?
set -e

log_info "QEMU execution finished with exit code: ${QEMU_STATUS}"

# 4. Analyze boot evidence
echo -e "\n${BOLD}=== Boot Log Inspection ===${NC}"

BOOT_SUCCESS=0

if grep -qi "Welcome to Alpine Linux" "${SERIAL_LOG}"; then
    log_ok "Detected banner: 'Welcome to Alpine Linux'"
    BOOT_SUCCESS=1
fi

if grep -qi "login:" "${SERIAL_LOG}"; then
    log_ok "Detected console login prompt: 'login:'"
    BOOT_SUCCESS=1
fi

if grep -qi "Linux version 6\." "${SERIAL_LOG}"; then
    log_ok "Detected Linux kernel initialization: $(grep -i "Linux version 6\." "${SERIAL_LOG}" | head -n1)"
    BOOT_SUCCESS=1
fi

if grep -qi "OpenRC" "${SERIAL_LOG}"; then
    log_ok "Detected OpenRC init system running"
    BOOT_SUCCESS=1
fi

echo -e "${BOLD}===========================${NC}\n"

if [[ $BOOT_SUCCESS -eq 1 ]]; then
    log_ok "PH1-T3 SUCCESS: QEMU successfully booted Alpine aarch64 ISO!"
    exit 0
else
    log_error "PH1-T3 FAILED: Expected boot markers not found in ${SERIAL_LOG} within ${TIMEOUT_SECS}s."
    echo "--- Last 20 lines of serial log ---"
    tail -n 20 "${SERIAL_LOG}" || true
    echo "-----------------------------------"
    exit 1
fi
