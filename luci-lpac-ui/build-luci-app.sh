#!/bin/bash
#
# LuCI App lpac Build Script
# Builds only the web interface (assumes lpac binary from OpenWrt repo)
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUCI_APP_DIR="$SCRIPT_DIR/luci-app-lpac"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# Build root - use WSL native FS if on WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    BUILD_ROOT="${HOME}/.local/build/openwrt-luci-lpac"
else
    BUILD_ROOT="$SCRIPT_DIR/build"
fi

# Default OpenWrt version
OPENWRT_VERSION="${1:-24.10.0}"
ARCH="${2:-ath79/generic}"

OPENWRT_TARGET="${ARCH%/*}"
OPENWRT_SUBTARGET="${ARCH#*/}"
SDK_DIR="$BUILD_ROOT/sdk-$OPENWRT_VERSION"
CACHE_DIR="$BUILD_ROOT/cache"
OUTPUT_DIR="$BUILD_ROOT/output/$OPENWRT_VERSION"

log "Building LuCI App lpac for OpenWrt $OPENWRT_VERSION ($ARCH)"

# Check if luci-app-lpac exists
if [ ! -d "$LUCI_APP_DIR" ]; then
    error "LuCI app directory not found: $LUCI_APP_DIR"
fi

# Create directories
mkdir -p "$CACHE_DIR" "$OUTPUT_DIR"

# Determine GCC version based on OpenWrt version
case "$OPENWRT_VERSION" in
    24.10*|SNAPSHOT)
        GCC_VERSION="13.3.0"
        BASE_URL="https://downloads.openwrt.org/snapshots/targets"
        ;;
    23.05*)
        GCC_VERSION="12.3.0"
        BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets"
        ;;
    22.03*)
        GCC_VERSION="11.2.0"
        BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets"
        ;;
    *)
        GCC_VERSION="12.3.0"
        BASE_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets"
        ;;
esac

# Download SDK if not cached
SDK_FILENAME="openwrt-sdk-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}_gcc-${GCC_VERSION}_musl.Linux-x86_64.tar.xz"
SDK_URL="${BASE_URL}/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}/${SDK_FILENAME}"
SDK_CACHE="$CACHE_DIR/$SDK_FILENAME"

if [ ! -f "$SDK_CACHE" ]; then
    log "Downloading SDK from: $SDK_URL"
    wget -q --show-progress -O "$SDK_CACHE" "$SDK_URL" || {
        # Try snapshot URL if release URL fails
        if [[ "$OPENWRT_VERSION" == "24.10"* ]]; then
            SDK_FILENAME="openwrt-sdk-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}_gcc-${GCC_VERSION}_musl.Linux-x86_64.tar.xz"
            SDK_URL="https://downloads.openwrt.org/snapshots/targets/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}/${SDK_FILENAME}"
            log "Trying snapshot URL: $SDK_URL"
            wget -q --show-progress -O "$SDK_CACHE" "$SDK_URL" || error "Failed to download SDK"
        else
            error "Failed to download SDK"
        fi
    }
else
    log "SDK already cached"
fi

# Extract SDK
if [ ! -f "$SDK_DIR/Makefile" ]; then
    log "Extracting SDK..."
    mkdir -p "$SDK_DIR"
    tar -xJf "$SDK_CACHE" -C "$SDK_DIR" --strip-components=1 || error "Failed to extract SDK"
else
    log "SDK already extracted"
fi

# Prepare package directory
PKG_DIR="$SDK_DIR/package/luci-app-lpac"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"

# Copy LuCI app files
log "Copying LuCI app files..."
mkdir -p "$PKG_DIR/root"
cp "$LUCI_APP_DIR/Makefile" "$PKG_DIR/"
cp -r "$LUCI_APP_DIR/files"/* "$PKG_DIR/root/"
if [ -d "$LUCI_APP_DIR/po" ]; then
    cp -r "$LUCI_APP_DIR/po" "$PKG_DIR/"
fi

# Update feeds
log "Updating feeds..."
cd "$SDK_DIR"
./scripts/feeds update -a >/dev/null 2>&1 || warn "Feed update had warnings"
./scripts/feeds install -a >/dev/null 2>&1

# Configure build
log "Configuring build..."
cat > .config << EOF
CONFIG_TARGET_${OPENWRT_TARGET}=y
CONFIG_TARGET_${OPENWRT_TARGET}_${OPENWRT_SUBTARGET}=y
CONFIG_PACKAGE_luci-app-lpac=m
EOF

make defconfig >/dev/null 2>&1

# Build package
log "Building LuCI package..."
make package/luci-app-lpac/compile V=s || error "Build failed"

# Collect built package
log "Collecting package..."
find bin/packages -name "luci-app-lpac*.ipk" -exec cp {} "$OUTPUT_DIR/" \;

# Copy to project build-ipk directory
PROJECT_IPK_DIR="$SCRIPT_DIR/../build-ipk/luci-app-lpac/$OPENWRT_VERSION"
mkdir -p "$PROJECT_IPK_DIR"
cp "$OUTPUT_DIR"/*.ipk "$PROJECT_IPK_DIR/"

log "Build successful!"
log "Package saved to: $OUTPUT_DIR"
log "Also copied to: $PROJECT_IPK_DIR"

ls -lh "$OUTPUT_DIR"/*.ipk
