#!/bin/bash

# OpenWrt build script for lpac
# This script demonstrates how to build lpac for OpenWrt

set -e

# Configuration
OPENWRT_SDK_URL="https://downloads.openwrt.org/releases/23.05.0/targets/x86/64/openwrt-sdk-23.05.0-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
BUILD_DIR="$HOME/openwrt-build"
PACKAGE_NAME="lpac"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    local deps=("wget" "tar" "make" "gcc" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Missing dependency: $dep. Please install it first."
        fi
    done
    
    log "All dependencies found."
}

# Download and extract OpenWrt SDK
setup_sdk() {
    log "Setting up OpenWrt SDK..."
    
    if [ ! -d "$BUILD_DIR" ]; then
        mkdir -p "$BUILD_DIR"
        cd "$BUILD_DIR"
        
        log "Downloading OpenWrt SDK..."
        wget -O openwrt-sdk.tar.xz "$OPENWRT_SDK_URL"
        
        log "Extracting SDK..."
        tar xf openwrt-sdk.tar.xz
        rm openwrt-sdk.tar.xz
        
        # Find extracted directory
        SDK_DIR=$(find . -maxdepth 1 -type d -name "openwrt-sdk-*" | head -n1)
        mv "$SDK_DIR" sdk
    else
        log "SDK already exists in $BUILD_DIR"
    fi
}

# Copy package to SDK
copy_package() {
    log "Copying lpac package to SDK..."
    
    local current_dir=$(pwd)
    local package_dir="$BUILD_DIR/sdk/package/$PACKAGE_NAME"
    
    mkdir -p "$package_dir"
    cp -r "$current_dir"/* "$package_dir/"
    
    log "Package copied to $package_dir"
}

# Update feeds
update_feeds() {
    log "Updating OpenWrt feeds..."
    
    cd "$BUILD_DIR/sdk"
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    
    log "Feeds updated successfully"
}

# Configure build
configure_build() {
    log "Configuring build..."
    
    cd "$BUILD_DIR/sdk"
    
    # Create minimal config
    cat > .config << 'EOF'
# Minimal OpenWrt configuration for lpac build
CONFIG_TARGET_x86=y
CONFIG_TARGET_x86_64=y
CONFIG_TARGET_x86_64_generic=y
CONFIG_TARGET_DEVICE_x86_64_generic=y
CONFIG_ALL_NONSHARED=y
CONFIG_DEVEL=y
CONFIG_TOOLCHAINOPTS=y
CONFIG_GCC_VERSION_12=y

# Package configuration
CONFIG_PACKAGE_lpac=m
CONFIG_PACKAGE_lpac-all=y

# Dependencies
CONFIG_PACKAGE_libcurl=y
CONFIG_PACKAGE_libpthread=y
CONFIG_PACKAGE_libcjson=y
CONFIG_PACKAGE_libpcsclite=y
CONFIG_PACKAGE_pcscd=y

# LuCI (optional, for web interface)
CONFIG_LUCI=y
CONFIG_PACKAGE_luci-app-lpac=m
EOF
    
    # Make oldconfig to accept defaults
    make oldconfig
    
    log "Build configuration completed"
}

# Build package
build_package() {
    log "Building $PACKAGE_NAME package..."
    
    cd "$BUILD_DIR/sdk"
    
    # Build only our package
    make package/$PACKAGE_NAME/compile V=s
    
    log "Build completed successfully"
}

# Find built packages
find_packages() {
    log "Finding built packages..."
    
    cd "$BUILD_DIR/sdk"
    find bin/ -name "*$PACKAGE_NAME*" -type f
    
    log "Package files are listed above"
}

# Clean build
clean_build() {
    log "Cleaning build directory..."
    
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
        log "Build directory cleaned"
    else
        log "No build directory to clean"
    fi
}

# Show usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build     - Build lpac package (default)"
    echo "  clean     - Clean build directory"
    echo "  help      - Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  OPENWRT_TARGET - OpenWrt target architecture (default: x86/64)"
    echo "  OPENWRT_VERSION - OpenWrt version (default: 23.05.0)"
}

# Main function
main() {
    local command=${1:-build}
    
    case "$command" in
        "build")
            check_dependencies
            setup_sdk
            copy_package
            update_feeds
            configure_build
            build_package
            find_packages
            ;;
        "clean")
            clean_build
            ;;
        "help"|"-h"|"--help")
            usage
            ;;
        *)
            error "Unknown command: $command. Use 'help' for usage."
            ;;
    esac
}

# Run main function with all arguments
main "$@"
