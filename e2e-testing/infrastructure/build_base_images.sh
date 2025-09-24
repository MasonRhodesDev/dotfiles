#!/bin/bash
set -euo pipefail

# Build base VM images using Packer

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKER_DIR="$SCRIPT_DIR/packer"
IMAGES_DIR="$SCRIPT_DIR/images/base"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."

    if ! command -v packer &> /dev/null; then
        error "Packer is not installed. Please install Packer first."
        exit 1
    fi

    if ! command -v qemu-system-x86_64 &> /dev/null; then
        error "QEMU is not installed. Please install QEMU first."
        exit 1
    fi

    # Check if KVM is available
    if [[ -c /dev/kvm ]]; then
        log "KVM acceleration available"
    else
        warn "KVM acceleration not available, using TCG (slower)"
    fi
}

# Create directories
setup_directories() {
    log "Setting up directories..."
    mkdir -p "$IMAGES_DIR"
    mkdir -p "$SCRIPT_DIR/images/test"
}

# Initialize Packer plugins
init_packer() {
    log "Initializing Packer plugins..."
    cd "$PACKER_DIR"

    if packer init arch-base.pkr.hcl; then
        log "Packer plugins initialized for Arch"
    else
        error "Failed to initialize Packer plugins for Arch"
        return 1
    fi

    if packer init fedora-base.pkr.hcl; then
        log "Packer plugins initialized for Fedora template"
    else
        error "Failed to initialize Packer plugins for Fedora"
        return 1
    fi
}

# Build Arch Linux base image
build_arch_image() {
    log "Building Arch Linux base image with archinstall..."
    cd "$PACKER_DIR"

    if packer build -force arch-base.pkr.hcl; then
        log "Arch Linux base image built successfully"
    else
        error "Failed to build Arch Linux base image"
        return 1
    fi
}

# Build Fedora base image
build_fedora_image() {
    log "Building Fedora base image..."
    cd "$PACKER_DIR"

    if packer build -force fedora-base.pkr.hcl; then
        log "Fedora base image built successfully"
    else
        error "Failed to build Fedora base image"
        return 1
    fi
}

# Main execution
main() {
    log "Starting base image build process..."

    check_dependencies
    setup_directories
    init_packer

    # Parse command line arguments
    BUILD_ARCH=true
    BUILD_FEDORA=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --arch-only)
                BUILD_FEDORA=false
                shift
                ;;
            --fedora-only)
                BUILD_ARCH=false
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [--arch-only|--fedora-only]"
                echo ""
                echo "Options:"
                echo "  --arch-only    Build only Arch Linux base image"
                echo "  --fedora-only  Build only Fedora base image"
                echo "  -h, --help     Show this help message"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Build images
    if $BUILD_ARCH; then
        build_arch_image
    fi

    if $BUILD_FEDORA; then
        build_fedora_image
    fi

    log "Base image build process completed!"
    log "Images available in: $IMAGES_DIR"
    ls -lh "$IMAGES_DIR"
}

# Execute main function
main "$@"