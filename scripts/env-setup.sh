#!/usr/bin/env bash
# ==============================================================================
# JWAL OS — WSL2 Ubuntu Development Environment Provisioning Script
# ==============================================================================
# Purpose:
#   Sets up a complete toolchain inside WSL2 Ubuntu for building, testing,
#   and running JWAL OS images and components.
#
# Usage:
#   ./scripts/env-setup.sh [OPTIONS]
#
# Requirements:
#   - Host: Ubuntu 22.04 LTS or newer (inside WSL2)
#   - Root privileges (sudo) for apt package installation
# ==============================================================================

set -euo pipefail

# Configuration defaults
FLUTTER_VERSION="3.29.0-stable"
FLUTTER_INSTALL_DIR="${HOME}/development/flutter"
RUST_VERSION="stable"

# ANSI styling
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print log messages
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Print help documentation
show_help() {
    echo -e "${BOLD}JWAL OS Development Environment Setup${NC}"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo "  ./scripts/env-setup.sh [OPTIONS]"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  -h, --help        Show this help message and exit"
    echo "  -c, --check       Verify installed toolchain without making system modifications"
    echo "  --no-flutter      Skip Flutter SDK and flutter-elinux installation"
    echo "  --no-rust         Skip Rust toolchain installation"
    echo "  --no-qemu         Skip QEMU system emulator installation"
    echo ""
    echo -e "${BOLD}DESCRIPTION:${NC}"
    echo "  Automates the provisioning of:"
    echo "    1. System packages (build-essential, cmake, ninja, git, curl)"
    echo "    2. Graphics & Wayland dependencies for flutter-elinux"
    echo "    3. Disk and rootfs creation utilities (parted, dosfstools, e2fsprogs)"
    echo "    4. QEMU aarch64 emulation toolchain (qemu-system-arm, qemu-efi-aarch64)"
    echo "    5. Rust compiler toolchain with aarch64/x86_64 musl compilation targets"
    echo "    6. Flutter SDK (Linux desktop enabled) & flutter-elinux CLI"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  ./scripts/env-setup.sh          # Full environment provisioning"
    echo "  ./scripts/env-setup.sh --check  # Verify toolchain status"
}

# System requirement checks
check_environment() {
    log_info "Verifying host operating system..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "Unsupported OS. /etc/os-release not found. JWAL OS build environment requires Ubuntu inside WSL2."
        exit 1
    fi

    # Read OS release info
    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" && "${ID_LIKE:-}" != *"ubuntu"* && "${ID_LIKE:-}" != *"debian"* ]]; then
        log_warn "Detected OS is '${ID:-unknown}'. Recommended distribution is Ubuntu 22.04 LTS or newer."
    else
        log_ok "Host OS: ${PRETTY_NAME:-Linux}"
    fi

    # Check for WSL environment
    if grep -qi "microsoft" /proc/version 2>/dev/null; then
        log_ok "WSL2 environment detected."
    else
        log_info "Running on standard Linux (non-WSL)."
    fi
}

# Verify tool status
check_toolchain() {
    local missing=0

    echo -e "\n${BOLD}--- Toolchain Status Check ---${NC}"
    
    # 1. Core build tools
    for cmd in gcc g++ make cmake ninja git curl wget; do
        if command -v "$cmd" >/dev/null 2>&1; then
            echo -e "  [x] $cmd ($(command -v "$cmd"))"
        else
            echo -e "  [ ] $cmd (MISSING)"
            missing=$((missing + 1))
        fi
    done

    # 2. QEMU
    if command -v qemu-system-aarch64 >/dev/null 2>&1; then
        echo -e "  [x] qemu-system-aarch64 ($(qemu-system-aarch64 --version | head -n1))"
    else
        echo -e "  [ ] qemu-system-aarch64 (MISSING)"
        missing=$((missing + 1))
    fi

    # 3. Rust & Cargo
    if command -v cargo >/dev/null 2>&1; then
        echo -e "  [x] cargo ($(cargo --version))"
    else
        echo -e "  [ ] cargo (MISSING)"
        missing=$((missing + 1))
    fi

    # 4. Flutter & Dart
    if command -v flutter >/dev/null 2>&1; then
        echo -e "  [x] flutter ($(flutter --version 2>&1 | head -n1))"
    else
        echo -e "  [ ] flutter (MISSING)"
        missing=$((missing + 1))
    fi

    # 5. flutter-elinux
    if command -v flutter-elinux >/dev/null 2>&1; then
        echo -e "  [x] flutter-elinux ($(flutter-elinux --version 2>&1 | head -n1 || echo 'present'))"
    else
        echo -e "  [ ] flutter-elinux (MISSING)"
        missing=$((missing + 1))
    fi

    echo -e "${BOLD}------------------------------${NC}\n"

    if [[ $missing -eq 0 ]]; then
        log_ok "All required tools are installed and available in PATH."
        return 0
    else
        log_warn "$missing tool(s) missing. Run './scripts/env-setup.sh' to install."
        return 1
    fi
}

# Install APT system packages
install_apt_packages() {
    local install_qemu="$1"

    log_info "Updating apt package repositories..."
    sudo apt-get update -y

    log_info "Installing core build, disk packaging, and Wayland development libraries..."
    sudo apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        pkg-config \
        git \
        curl \
        wget \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        parted \
        dosfstools \
        e2fsprogs \
        mtools \
        squashfs-tools \
        libwayland-dev \
        wayland-protocols \
        libxkbcommon-dev \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
        libdrm-dev \
        libgbm-dev

    if [[ "$install_qemu" == "true" ]]; then
        log_info "Installing QEMU aarch64 emulation suite and UEFI firmware..."
        sudo apt-get install -y --no-install-recommends \
            qemu-system-arm \
            qemu-efi-aarch64 \
            qemu-utils
    fi

    log_ok "System packages installed successfully."
}

# Install Rust toolchain
install_rust() {
    if command -v rustup >/dev/null 2>&1; then
        log_info "Rustup already installed. Updating default toolchain..."
        rustup update "$RUST_VERSION"
    else
        log_info "Installing Rust toolchain via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain "$RUST_VERSION"
        # shellcheck disable=SC1091
        source "${HOME}/.cargo/env"
    fi

    log_info "Adding static musl compilation targets for jwald daemon..."
    rustup target add aarch64-unknown-linux-musl
    rustup target add x86_64-unknown-linux-musl

    log_ok "Rust toolchain configured (musl targets ready)."
}

# Install Flutter and flutter-elinux
install_flutter() {
    if command -v flutter >/dev/null 2>&1; then
        log_info "Flutter already present in PATH."
    else
        log_info "Installing Flutter SDK to ${FLUTTER_INSTALL_DIR}..."
        mkdir -p "$(dirname "${FLUTTER_INSTALL_DIR}")"
        if [[ ! -d "${FLUTTER_INSTALL_DIR}" ]]; then
            git clone --depth 1 -b stable https://github.com/flutter/flutter.git "${FLUTTER_INSTALL_DIR}"
        fi
        
        # Add to current path
        export PATH="${FLUTTER_INSTALL_DIR}/bin:${PATH}"
        
        # Suggest shell profile update if not already present
        local profile_file="${HOME}/.bashrc"
        if ! grep -q "flutter/bin" "$profile_file" 2>/dev/null; then
            log_info "Appending Flutter to ${profile_file}..."
            echo "export PATH=\"${FLUTTER_INSTALL_DIR}/bin:\$PATH\"" >> "$profile_file"
        fi
    fi

    log_info "Enabling Flutter Linux desktop support..."
    flutter config --enable-linux-desktop --no-analytics

    log_info "Installing flutter-elinux tool for embedded Linux Wayland runtime..."
    if command -v dart >/dev/null 2>&1; then
        dart pub global activate flutter_elinux
        export PATH="${HOME}/.pub-cache/bin:${PATH}"
        
        local profile_file="${HOME}/.bashrc"
        if ! grep -q ".pub-cache/bin" "$profile_file" 2>/dev/null; then
            echo "export PATH=\"\$HOME/.pub-cache/bin:\$PATH\"" >> "$profile_file"
        fi
    else
        log_warn "Dart binary not found in PATH yet. Run 'source ~/.bashrc' and 'dart pub global activate flutter_elinux' afterwards."
    fi

    log_ok "Flutter and flutter-elinux setup completed."
}

# Main execution entrypoint
main() {
    local check_only="false"
    local install_flutter_flag="true"
    local install_rust_flag="true"
    local install_qemu_flag="true"

    # Argument parser
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--check)
                check_only="true"
                shift
                ;;
            --no-flutter)
                install_flutter_flag="false"
                shift
                ;;
            --no-rust)
                install_rust_flag="false"
                shift
                ;;
            --no-qemu)
                install_qemu_flag="false"
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                show_help
                exit 1
                ;;
        esac
    done

    check_environment

    if [[ "$check_only" == "true" ]]; then
        check_toolchain || exit 1
        exit 0
    fi

    # Perform installations
    install_apt_packages "$install_qemu_flag"

    if [[ "$install_rust_flag" == "true" ]]; then
        install_rust
    fi

    if [[ "$install_flutter_flag" == "true" ]]; then
        install_flutter
    fi

    echo -e "\n${GREEN}${BOLD}=== JWAL OS Development Environment Ready ===${NC}"
    echo "Reload your shell profile to apply path changes:"
    echo "  source ~/.bashrc"
    echo ""
    echo "Verify your toolchain:"
    echo "  ./scripts/env-setup.sh --check"
}

main "$@"
