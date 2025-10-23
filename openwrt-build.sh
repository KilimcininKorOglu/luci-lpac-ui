#!/bin/bash

# OpenWrt Cross-compilation Script for lpac
# This script builds lpac for various OpenWrt architectures

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-openwrt"
OPENWRT_BASE_URL="https://downloads.openwrt.org/releases"

# Supported architectures
declare -A ARCHITECTURES=(
    ["x86_64"]="x86/64"
    ["ramips_mt7621"]="ramips/mt7621" 
    ["ipq40xx"]="qualcommax/ipq40xx"
    ["rockchip_armv8"]="rockchip/armv8"
    ["bcm27xx_bcm2711"]="bcm27xx/bcm2711"
)

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

show_usage() {
    echo "OpenWrt lpac Cross-compilation Script"
    echo ""
    echo "Usage: $0 [OPTIONS] ARCHITECTURE [OPENWRT_VERSION]"
    echo ""
    echo "ARCHITECTURES:"
    for arch in "${!ARCHITECTURES[@]}"; do
        echo "  $arch"
    done
    echo ""
    echo "OPENWRT_VERSION: OpenWrt version (default: 23.05.0)"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build directory"
    echo "  -l, --list     List available architectures"
    echo "  -v, --verbose  Verbose output"
    echo ""
    echo "Examples:"
    echo "  $0 x86_64                    # Build for x86_64 with latest 23.05.0"
    echo "  $0 ramips_mt7621 22.03.5     # Build for MT7621 with OpenWrt 22.03.5"
}

list_architectures() {
    echo "Available architectures:"
    for arch in "${!ARCHITECTURES[@]}"; do
        echo "  $arch -> ${ARCHITECTURES[$arch]}"
    done
}

download_sdk() {
    local arch=$1
    local version=$2
    local target=${ARCHITECTURES[$arch]}
    local sdk_name="openwrt-sdk-${version}-${target}-gcc-12.3.0_musl.Linux-x86_64.tar.xz"
    local sdk_url="${OPENWRT_BASE_URL}/releases/${version}/targets/${target}/${sdk_name}"
    local sdk_dir="${BUILD_DIR}/sdk-${arch}"
    
    log "Downloading SDK for $arch..."
    
    if [ -f "${BUILD_DIR}/${sdk_name}" ]; then
        log "SDK already downloaded: ${sdk_name}"
    else
        mkdir -p "$BUILD_DIR"
        wget -O "${BUILD_DIR}/${sdk_name}" "$sdk_url" || error "Failed to download SDK"
    fi
    
    if [ -d "$sdk_dir" ]; then
        log "SDK already extracted: $sdk_dir"
    else
        log "Extracting SDK..."
        mkdir -p "$sdk_dir"
        tar xf "${BUILD_DIR}/${sdk_name}" -C "$sdk_dir" --strip-components=1
    fi
    
    echo "$sdk_dir"
}

prepare_toolchain() {
    local sdk_dir=$1
    
    # Set environment variables for cross-compilation
    export STAGING_DIR="${sdk_dir}/staging_dir"
    export TOOLCHAIN_DIR="${STAGING_DIR}/toolchain-x86_64_gcc-12.3.0_musl"
    export PATH="${TOOLCHAIN_DIR}/bin:$PATH"
    
    # Find the cross-compiler
    local cross_prefix=$(find "$TOOLCHAIN_DIR/bin" -name "x86_64-openwrt-linux-*gcc" | head -n1 | sed 's/-gcc$//')
    export CC="${cross_prefix}-gcc"
    export CXX="${cross_prefix}-g++"
    export AR="${cross_prefix}-ar"
    export STRIP="${cross_prefix}-strip"
    export RANLIB="${cross_prefix}-ranlib"
    
    log "Using toolchain: $cross_prefix"
}

prepare_package() {
    local sdk_dir=$1
    local package_dir="${sdk_dir}/package/lpac"
    
    log "Preparing package source..."
    
    # Copy source to package directory
    mkdir -p "$package_dir"
    cp -r "$SCRIPT_DIR"/* "$package_dir/"
    
    # Copy OpenWrt specific files
    cp "$SCRIPT_DIR/Makefile.openwrt" "$package_dir/Makefile"
    
    # Create patches directory
    mkdir -p "$package_dir/patches"
    
    # Copy our OpenWrt Makefile if it exists
    if [ -f "$SCRIPT_DIR/files/Makefile.openwrt" ]; then
        cp "$SCRIPT_DIR/files/Makefile.openwrt" "$package_dir/Makefile"
    fi
}

build_package() {
    local sdk_dir=$1
    local arch=$2
    
    log "Building package for $arch..."
    
    cd "$sdk_dir"
    
    # Update feeds
    log "Updating feeds..."
    ./scripts/feeds update -a
    ./scripts/feeds install -a
    
    # Configure build
    log "Configuring build..."
    make defconfig
    
    # Build our package
    log "Compiling lpac package..."
    make package/lpac/compile V=s -j$(nproc)
    
    # Find built packages
    log "Finding built packages..."
    find "$sdk_dir/bin" -name "*lpac*" -type f -ls
}

clean_build() {
    if [ -d "$BUILD_DIR" ]; then
        log "Cleaning build directory..."
        rm -rf "$BUILD_DIR"
        log "Build directory cleaned"
    else
        log "No build directory to clean"
    fi
}

main() {
    local clean=false
    local list=false
    local verbose=false
    local arch=""
    local version="23.05.0"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -c|--clean)
                clean=true
                shift
                ;;
            -l|--list)
                list=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                set -x
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [ -z "$arch" ]; then
                    arch="$1"
                elif [ -z "$version" ]; then
                    version="$1"
                else
                    error "Too many arguments"
                fi
                shift
                ;;
        esac
    done
    
    # Handle special commands
    if [ "$clean" = true ]; then
        clean_build
        exit 0
    fi
    
    if [ "$list" = true ]; then
        list_architectures
        exit 0
    fi
    
    # Check if architecture is specified
    if [ -z "$arch" ]; then
        error "Architecture not specified. Use -h for help."
    fi
    
    # Check if architecture is supported
    if [[ ! -v "ARCHITECTURES[$arch]" ]]; then
        error "Unsupported architecture: $arch. Use -l to list available architectures."
    fi
    
    log "Building lpac for $arch (OpenWrt $version)"
    
    # Download and prepare SDK
    local sdk_dir=$(download_sdk "$arch" "$version")
    
    # Prepare toolchain
    prepare_toolchain "$sdk_dir"
    
    # Prepare package
    prepare_package "$sdk_dir"
    
    # Build package
    build_package "$sdk_dir" "$arch"
    
    log "Build completed successfully!"
    log "Packages are located in: $sdk_dir/bin"
}

# Run main function
main "$@"
