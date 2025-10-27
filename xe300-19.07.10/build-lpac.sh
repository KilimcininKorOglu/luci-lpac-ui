#!/bin/bash
#
# GL-XE300 (OpenWrt 19.07.10) lpac build script
# Hedef: MIPS 24Kc (QCA9531 @ 650MHz)
# Mimari: mips-openwrt-linux-musl
#

set -e  # Stop on error

# Renkler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  GL-XE300 lpac Cross-Compile Script                       ║"
echo "║  Target: OpenWrt 19.07.10 / MIPS 24Kc                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Konfigürasyon
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OPENWRT_VERSION="19.07.10"
OPENWRT_TARGET="ath79"
OPENWRT_SUBTARGET="generic"

# SDK directory - in WSL home directory
SDK_DIR="${HOME}/xe300-19.07.10-sdk/sdk"
OUTPUT_DIR="${SCRIPT_DIR}/output"

# Build on native Linux filesystem to avoid Windows symlink issues
BUILD_DIR="${HOME}/.local/build/lpac-xe300-19.07.10"

# LPAC source directory
LPAC_SOURCE_DIR="${PROJECT_ROOT}/lpac"

# SDK information (reference for manual installation)
SDK_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}/openwrt-sdk-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}_gcc-7.5.0_musl.Linux-x86_64.tar.xz"
SDK_ARCHIVE="openwrt-sdk-${OPENWRT_VERSION}.tar.xz"
SDK_EXTRACTED="openwrt-sdk-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}_gcc-7.5.0_musl.Linux-x86_64"

# Toolchain information
TOOLCHAIN_PREFIX="mips-openwrt-linux-musl-"
CROSS_COMPILE="${TOOLCHAIN_PREFIX}"

# Log fonksiyonu
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# System check
check_dependencies() {
    log_step "Checking system dependencies..."

    local deps=("wget" "tar" "make" "gcc" "g++" "file" "cmake")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    # Python check (required for lpac build system)
    if ! command -v python3 &> /dev/null; then
        log_warn "Python3 not found (required for lpac)"
        missing+=("python3")
    fi

    # Check CMake version (lpac requires >= 3.23)
    if command -v cmake &> /dev/null; then
        local cmake_version=$(cmake --version | head -1 | awk '{print $3}')
        local cmake_major=$(echo $cmake_version | cut -d. -f1)
        local cmake_minor=$(echo $cmake_version | cut -d. -f2)

        if [ "$cmake_major" -lt 3 ] || ([ "$cmake_major" -eq 3 ] && [ "$cmake_minor" -lt 23 ]); then
            log_warn "CMake version $cmake_version found, but lpac requires >= 3.23"
            log_info "You may need to install a newer CMake"
        else
            log_info "CMake version: $cmake_version ✓"
        fi
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "To install: sudo apt-get install ${missing[*]}"
        exit 1
    fi

    log_info "All dependencies available ✓"
}

# OpenWrt SDK check and automatic download
download_sdk() {
    log_step "Checking OpenWrt SDK..."

    if [ -d "$SDK_DIR" ]; then
        log_info "SDK directory found: $SDK_DIR"
        log_info "SDK ready ✓"
        return 0
    fi

    log_warn "SDK not found, downloading automatically..."

    local SDK_PARENT_DIR="${HOME}/xe300-${OPENWRT_VERSION}-sdk"

    mkdir -p "$SDK_PARENT_DIR"
    cd "$SDK_PARENT_DIR"

    # SDK'yı indir
    if [ ! -f "$SDK_ARCHIVE" ]; then
        log_info "Downloading SDK: $SDK_URL"
        log_info "This may take a few minutes (~80-100 MB)..."
        wget -q --show-progress "$SDK_URL" -O "$SDK_ARCHIVE" || {
            log_error "SDK download failed!"
            log_error "To download manually:"
            log_error "  wget $SDK_URL"
            exit 1
        }
    else
        log_info "SDK archive already downloaded"
    fi

    # Extract SDK
    if [ ! -d "$SDK_EXTRACTED" ]; then
        log_info "Extracting SDK..."
        tar -xf "$SDK_ARCHIVE" || {
            log_error "SDK extraction failed!"
            exit 1
        }
    fi

    # Rename SDK directory
    if [ ! -d "sdk" ]; then
        log_info "Organizing SDK directory..."
        mv "$SDK_EXTRACTED" sdk || {
            log_error "Could not move SDK directory!"
            exit 1
        }
    fi

    log_info "SDK ready: $SDK_DIR ✓"
    cd - > /dev/null
}

# Toolchain ve libcurl setup
setup_toolchain() {
    log_step "Setting up toolchain..."

    export STAGING_DIR="${SDK_DIR}/staging_dir"
    export PATH="${SDK_DIR}/staging_dir/toolchain-mips_24kc_gcc-7.5.0_musl/bin:$PATH"

    # Toolchain check
    if ! command -v "${CROSS_COMPILE}gcc" &> /dev/null; then
        log_error "Toolchain not found: ${CROSS_COMPILE}gcc"
        log_error "STAGING_DIR: $STAGING_DIR"
        exit 1
    fi

    local gcc_version
    gcc_version=$("${CROSS_COMPILE}gcc" --version | head -1)
    log_info "Toolchain found: $gcc_version"

    # Toolchain test
    log_info "Testing toolchain..."
    echo "int main() { return 0; }" | "${CROSS_COMPILE}gcc" -x c - -o /tmp/test_mips$$ || {
        log_error "Toolchain test failed!"
        exit 1
    }
    rm -f /tmp/test_mips$$

    log_info "Toolchain ready ✓"
}

# Setup dependencies (libcurl, pcsclite, etc.)
setup_dependencies() {
    log_step "Setting up lpac dependencies..."

    cd "$SDK_DIR"

    # Prereq bypass (OpenWrt 19.07-22.03 and 23.05+ compatible)
    mkdir -p staging_dir/host host
    touch staging_dir/host/.prereq-build 2>/dev/null || true
    touch host/.prereq-build 2>/dev/null || true

    # Check libraries in SDK staging directory
    local target_dir="${SDK_DIR}/staging_dir/target-mips_24kc_musl"

    # Check if wolfssl or mbedtls exists
    local ssl_lib=""
    if [ -f "${target_dir}/usr/lib/libwolfssl.so" ] || [ -f "${target_dir}/usr/lib/libwolfssl.a" ]; then
        ssl_lib="wolfssl"
        log_info "✓ wolfssl found (SDK prebuilt)"
    elif [ -f "${target_dir}/usr/lib/libmbedtls.so" ] || [ -f "${target_dir}/usr/lib/libmbedtls.a" ]; then
        ssl_lib="mbedtls"
        log_info "✓ mbedtls found (SDK prebuilt)"
    else
        log_warn "SSL/TLS library not found in SDK, will compile..."
        # Fallback: compile wolfssl
        ./scripts/feeds update base packages 2>&1 | grep -v "^Checking" || true
        ./scripts/feeds install wolfssl 2>&1 | grep -v "^Checking" || true

        if [ ! -f .config ]; then
            echo "CONFIG_TARGET_ath79=y" > .config
            echo "CONFIG_TARGET_ath79_generic=y" >> .config
            echo "CONFIG_PACKAGE_libwolfssl=y" >> .config
            make defconfig > /dev/null 2>&1
        fi

        log_info "Compiling wolfssl..."
        make -j$(($(nproc)-1)) package/feeds/base/wolfssl/compile V=s 2>&1 | tail -20
        ssl_lib="wolfssl"
    fi

    # Check libcurl headers
    local curl_include="${target_dir}/usr/include/curl"
    if [ ! -d "$curl_include" ]; then
        log_warn "libcurl headers not found in SDK, will compile..."
        # Fallback: compile curl
        ./scripts/feeds update packages 2>&1 | grep -v "^Checking" || true
        ./scripts/feeds install curl 2>&1 | grep -v "^Checking" || true

        local curl_feed="packages"
        [ -d "package/feeds/base/curl" ] && curl_feed="base"

        log_info "Compiling curl..."
        make -j$(($(nproc)-1)) package/feeds/${curl_feed}/curl/compile V=s 2>&1 | tail -20
    else
        log_info "✓ libcurl headers found (SDK prebuilt)"
    fi

    # Check pcsc-lite (if needed by lpac drivers)
    if [ ! -d "${target_dir}/usr/include/PCSC" ]; then
        log_warn "pcsc-lite headers not found (lpac will use AT driver)"
    else
        log_info "✓ pcsc-lite headers found"
    fi

    # Final check
    if [ ! -d "$curl_include" ]; then
        log_error "libcurl headers still not found: $curl_include"
        exit 1
    fi

    log_info "Dependencies ready: $ssl_lib + libcurl ✓"

    cd - > /dev/null
}

# Prepare source code
prepare_source() {
    log_step "Preparing lpac source code..."

    # Check if lpac source exists
    if [ ! -d "$LPAC_SOURCE_DIR" ]; then
        log_error "lpac source directory not found: $LPAC_SOURCE_DIR"
        exit 1
    fi

    # Clean build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    log_info "Source directory: $LPAC_SOURCE_DIR"
    log_info "Build directory: $BUILD_DIR"
    log_info "Source code ready ✓"
}

# Compilation with CMake
compile() {
    log_step "Building lpac (CMake)..."

    local target_dir="${SDK_DIR}/staging_dir/target-mips_24kc_musl"

    # Copy source to build directory to avoid Windows filesystem issues
    log_info "Copying source to native Linux filesystem..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cp -r "$LPAC_SOURCE_DIR"/* "$BUILD_DIR/"

    # Now create toolchain file in the new location
    local TOOLCHAIN_FILE="${BUILD_DIR}/openwrt-mips.cmake"
    local toolchain_dir="${SDK_DIR}/staging_dir/toolchain-mips_24kc_gcc-7.5.0_musl"

    log_info "Creating CMake toolchain file..."
    cat > "$TOOLCHAIN_FILE" << EOF
# CMake toolchain file for OpenWrt MIPS 24Kc cross-compilation
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR mips)

# Specify the cross compiler
set(CMAKE_C_COMPILER ${toolchain_dir}/bin/${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_CXX_COMPILER ${toolchain_dir}/bin/${TOOLCHAIN_PREFIX}g++)

# Where to find the target environment
set(CMAKE_FIND_ROOT_PATH ${target_dir})
set(CMAKE_SYSROOT ${target_dir})

# Search for programs in the build host directories
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
# For libraries and headers in the target directories
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Compiler flags for MIPS 24Kc
set(CMAKE_C_FLAGS "-Os -march=24kc -mtune=24kc -ffunction-sections -fdata-sections -pipe" CACHE STRING "")
set(CMAKE_CXX_FLAGS "-Os -march=24kc -mtune=24kc -ffunction-sections -fdata-sections -pipe" CACHE STRING "")
set(CMAKE_EXE_LINKER_FLAGS "-Wl,--gc-sections" CACHE STRING "")

# Include and library paths
include_directories(${target_dir}/usr/include)
include_directories(${toolchain_dir}/include)
link_directories(${target_dir}/usr/lib)
link_directories(${toolchain_dir}/lib)

# Environment variables
set(ENV{STAGING_DIR} "${SDK_DIR}/staging_dir")
set(ENV{PATH} "${toolchain_dir}/bin:\$ENV{PATH}")
EOF

    cd "$BUILD_DIR"

    # Configure with CMake
    log_info "CMake configuration..."
    cmake -B build -Wno-dev \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_SKIP_RPATH=TRUE \
        -DCMAKE_SKIP_INSTALL_RPATH=TRUE \
        -DUSE_SYSTEM_DEPS=OFF \
        -DLPAC_DYNAMIC_LIBEUICC=OFF \
        -DLPAC_WITH_APDU_PCSC=OFF \
        -DLPAC_WITH_APDU_AT=ON || {
        log_error "CMake configuration failed!"
        exit 1
    }

    # Build
    log_info "Building lpac..."
    cmake --build build -j$(($(nproc)-1)) || {
        log_error "Compilation failed!"
        exit 1
    }

    # Check if binary exists
    if [ ! -f "build/src/lpac" ]; then
        log_error "Binary creation failed!"
        exit 1
    fi

    log_info "Compilation successful ✓"

    cd - > /dev/null
}

# Strip and analyze
post_process() {
    log_step "Processing binary..."

    local BINARY_PATH="$BUILD_DIR/build/src/lpac"

    # Binary information
    log_info "Binary information (before strip):"
    ls -lh "$BINARY_PATH"
    file "$BINARY_PATH"

    # Apply strip
    log_info "Removing debug symbols (strip)..."
    "${CROSS_COMPILE}strip" "$BINARY_PATH"

    log_info "Binary information (after strip):"
    ls -lh "$BINARY_PATH"

    # Architecture check
    local arch_info
    arch_info=$(file "$BINARY_PATH")
    if [[ ! "$arch_info" =~ "MIPS" ]]; then
        log_error "Binary is not MIPS architecture!"
        log_error "Info: $arch_info"
        exit 1
    fi

    log_info "Binary MIPS architecture verified ✓"
}

# Output packaging
package_output() {
    log_step "Packaging output..."

    # Clean output directory (except IPK)
    log_info "Cleaning output directory (preserving IPK files)..."
    if [ -d "$OUTPUT_DIR" ]; then
        find "$OUTPUT_DIR" -type f ! -name "*.ipk" -delete 2>/dev/null || true
        find "$OUTPUT_DIR" -type d -empty -delete 2>/dev/null || true
    fi
    mkdir -p "$OUTPUT_DIR"

    # Copy binary
    cp "$BUILD_DIR/build/src/lpac" "$OUTPUT_DIR/"

    # Copy drivers if built
    if [ -d "$BUILD_DIR/build/driver" ]; then
        mkdir -p "$OUTPUT_DIR/driver"
        find "$BUILD_DIR/build/driver" -name "*.so*" -type f -exec cp {} "$OUTPUT_DIR/driver/" \; 2>/dev/null || true
        if [ "$(ls -A $OUTPUT_DIR/driver 2>/dev/null)" ]; then
            log_info "Drivers copied to output/driver/"
        fi
    fi

    # Create README
    cat > "$OUTPUT_DIR/README.txt" << EOF
╔════════════════════════════════════════════════════════════╗
║  lpac - GL-XE300 Binary                                   ║
║  OpenWrt: ${OPENWRT_VERSION}                                      ║
║  Target: ${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}                                ║
║  Arch: MIPS 24Kc                                          ║
║  Build Date: $(date '+%Y-%m-%d %H:%M:%S')                        ║
╚════════════════════════════════════════════════════════════╝

INSTALLATION:
-------------
1. Connect to GL-XE300 via SSH:
   ssh root@192.168.8.1

2. Install dependencies:
   opkg update
   opkg install libcurl libpthread

3. Install the binary:
   # On this computer:
   scp lpac root@192.168.8.1:/usr/bin/

   # On GL-XE300:
   chmod +x /usr/bin/lpac

4. Verify modem:
   ls -l /dev/ttyUSB*
   # Should show: /dev/ttyUSB0, /dev/ttyUSB1, /dev/ttyUSB2, etc.

USAGE:
------
# List profiles:
lpac profile list

# Download profile:
lpac profile download -a <activation_code>

# Enable profile:
lpac profile enable -i <iccid>

# Chip info:
lpac chip info

# Help:
lpac -h

CONFIGURATION:
--------------
lpac uses AT driver for Quectel modems.
Default device: /dev/ttyUSB2 (AT port)

You can override with:
  export LPAC_APDU=at
  export LPAC_AT_DEVICE=/dev/ttyUSB2

NOTES:
------
- EP06-E modem firmware: EP06ELAR04A22M4G or higher
- Firmware check: echo "ATI" > /dev/ttyUSB2 && cat /dev/ttyUSB2
- Default AT port: /dev/ttyUSB2
- Binary size: varies (stripped)

TROUBLESHOOTING:
----------------
1. "libcurl.so.4 not found" error:
   opkg install libcurl4

2. "/dev/ttyUSB2 not found":
   lsusb | grep Quectel
   ls -l /dev/ttyUSB*

3. AT device permissions:
   chmod 666 /dev/ttyUSB2

SUPPORT:
--------
- lpac GitHub: https://github.com/estkme-group/lpac
- See project documentation for details

EOF

    # Create deployment script
    cat > "$OUTPUT_DIR/deploy.sh" << 'DEPLOYEOF'
#!/bin/bash
# GL-XE300 lpac deployment script

set -e

ROUTER_IP="${1:-192.168.8.1}"
ROUTER_USER="root"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  GL-XE300 lpac Deployment Script                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Target: ${ROUTER_USER}@${ROUTER_IP}"
echo ""

# Check binary
if [ ! -f "lpac" ]; then
    echo "ERROR: lpac binary not found!"
    exit 1
fi

echo "[1/4] Transferring binary..."
scp lpac "${ROUTER_USER}@${ROUTER_IP}:/tmp/" || {
    echo "ERROR: Transfer failed!"
    exit 1
}

echo "[2/4] Checking dependencies..."
ssh "${ROUTER_USER}@${ROUTER_IP}" << 'REMOTEEOF'
opkg update
opkg list-installed | grep -q libcurl || opkg install libcurl
opkg list-installed | grep -q libpthread || echo "libpthread already installed"
REMOTEEOF

echo "[3/4] Installing binary..."
ssh "${ROUTER_USER}@${ROUTER_IP}" << 'REMOTEEOF'
mv /tmp/lpac /usr/bin/
chmod +x /usr/bin/lpac
REMOTEEOF

echo "[4/4] Checking modem..."
ssh "${ROUTER_USER}@${ROUTER_IP}" << 'REMOTEEOF'
if [ ! -e /dev/ttyUSB2 ]; then
    echo "WARNING: /dev/ttyUSB2 not found!"
    echo "Check if modem is connected:"
    lsusb | grep -i quectel || echo "  Quectel modem not found!"
    ls -l /dev/ttyUSB* 2>/dev/null || echo "  USB serial ports not found!"
else
    echo "AT device found: /dev/ttyUSB2"
fi
REMOTEEOF

echo ""
echo "Installation completed!"
echo ""
echo "To test:"
echo "  ssh ${ROUTER_USER}@${ROUTER_IP}"
echo "  lpac chip info"
echo ""

DEPLOYEOF

    chmod +x "$OUTPUT_DIR/deploy.sh"

    log_info "Output ready: $OUTPUT_DIR/"
    log_info "  - lpac (binary)"
    log_info "  - driver/ (optional drivers)"
    log_info "  - README.txt (installation guide)"
    log_info "  - deploy.sh (automatic deployment)"

    # ==================== IPK PACKAGING ====================
    log_step "Creating IPK package..."

    local IPK_BUILD_DIR="$BUILD_DIR/ipk-build"
    local PKG_VERSION="2.3.0"
    local PKG_ARCH="mips_24kc"
    local IPK_NAME="lpac_${PKG_VERSION}-${BUILD_NUMBER}_${PKG_ARCH}.ipk"

    # Clean and create IPK structure
    rm -rf "$IPK_BUILD_DIR"
    mkdir -p "$IPK_BUILD_DIR"/{control,data/usr/bin,data/usr/lib,data/etc/config}

    # Create debian-binary
    echo "2.0" > "$IPK_BUILD_DIR/debian-binary"

    # Copy binary to /usr/lib/lpac (following official OpenWrt package structure)
    cp "$BUILD_DIR/build/src/lpac" "$IPK_BUILD_DIR/data/usr/lib/lpac"
    chmod +x "$IPK_BUILD_DIR/data/usr/lib/lpac"

    # Copy drivers to /usr/lib/driver (lpac binary at /usr/lib/lpac expects drivers at $ORIGIN/driver = /usr/lib/driver)
    if [ -d "$OUTPUT_DIR/driver" ] && [ "$(ls -A $OUTPUT_DIR/driver 2>/dev/null)" ]; then
        mkdir -p "$IPK_BUILD_DIR/data/usr/lib/driver"
        cp "$OUTPUT_DIR/driver"/* "$IPK_BUILD_DIR/data/usr/lib/driver/" 2>/dev/null || true
    fi

    # Copy liblpac-utils.so (critical utility library)
    if [ -f "$BUILD_DIR/build/utils/liblpac-utils.so" ]; then
        mkdir -p "$IPK_BUILD_DIR/data/usr/lib/driver"
        cp "$BUILD_DIR/build/utils/liblpac-utils.so" "$IPK_BUILD_DIR/data/usr/lib/driver/"
        log_info "Added liblpac-utils.so to IPK package"
    fi

    # Create wrapper script at /usr/bin/lpac (following official OpenWrt package structure)
    cat > "$IPK_BUILD_DIR/data/usr/bin/lpac" << 'WRAPPEREOF'
#!/bin/sh
# lpac wrapper script - reads UCI config and calls the real binary
# Based on official OpenWrt lpac package structure

# Load UCI helper functions
. /lib/config/uci.sh

# Read driver configuration from UCI (with fallback defaults)
APDU_DRIVER="$(uci_get lpac device driver at)"
AT_DEVICE="$(uci_get lpac device at_device /dev/ttyUSB2)"
MBIM_DEVICE="$(uci_get lpac device mbim_device /dev/cdc-wdm0)"
QMI_DEVICE="$(uci_get lpac device qmi_device /dev/cdc-wdm0)"
HTTP_CLIENT="$(uci_get lpac device http_client curl)"

# Export HTTP client
export LPAC_HTTP="$HTTP_CLIENT"

# Export APDU driver and device path based on driver type
export LPAC_APDU="$APDU_DRIVER"

case "$APDU_DRIVER" in
    at|at_csim)
        export LPAC_APDU_AT_DEVICE="$AT_DEVICE"
        ;;
    mbim)
        export MBIM_DEVICE="$MBIM_DEVICE"
        ;;
    qmi|uqmi)
        export LPAC_QMI_DEV="$QMI_DEVICE"
        ;;
    qmi_qrtr)
        # QMI QRTR doesn't need device path - uses Qualcomm IPC Router
        ;;
esac

# Call the real lpac binary in /usr/lib
exec /usr/lib/lpac "$@"
WRAPPEREOF
    chmod +x "$IPK_BUILD_DIR/data/usr/bin/lpac"
    log_info "Created wrapper script at /usr/bin/lpac"

    # Create UCI config file - shared with LuCI app
    cat > "$IPK_BUILD_DIR/data/etc/config/lpac" << 'UCIEOF'
config settings 'device'
	option driver 'at'
	option at_device '/dev/ttyUSB2'
	option mbim_device '/dev/cdc-wdm0'
	option qmi_device '/dev/cdc-wdm0'
	option http_client 'curl'
UCIEOF
    log_info "Created UCI config at /etc/config/lpac"

    # Calculate binary size
    local BINARY_SIZE=$(stat -c%s "$BUILD_DIR/build/src/lpac" 2>/dev/null || stat -f%z "$BUILD_DIR/build/src/lpac" 2>/dev/null)

    # Create control file
    cat > "$IPK_BUILD_DIR/control/control" << CTRLEOF
Package: lpac
Version: ${PKG_VERSION}-${BUILD_NUMBER}
Depends: libc, libpthread, libcurl
Section: net
Architecture: ${PKG_ARCH}
Installed-Size: ${BINARY_SIZE}
Maintainer: lpac Team <https://github.com/estkme-group/lpac>
Description: C-based eUICC LPA (Local Profile Assistant)
 lpac is a cross-platform local profile agent program compatible with
 SGP.22 version 2.2.2 (GSMA eSIM standard).
 .
 Features:
  - Support Activation Code and Confirmation Code
  - Support Custom IMEI sent to server
  - Profile management: list, enable, disable, delete and nickname
  - Notification management: list, send and delete
  - Lookup eUICC chip info
 .
 Compatible with: Quectel EP06-E, RM500Q, RG500Q and similar modems
 OpenWrt: ${OPENWRT_VERSION}
CTRLEOF

    # Create post-install script
    cat > "$IPK_BUILD_DIR/control/postinst" << 'POSTEOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh

echo ""
echo "✅ lpac v8 installed (OpenWrt standard structure)"
echo ""
echo "Package structure:"
echo "  /usr/bin/lpac        → Shell wrapper (user-facing command)"
echo "  /usr/lib/lpac        → Real binary"
echo "  /usr/lib/driver/     → Driver plugins (.so files)"
echo "  /etc/config/lpac     → UCI configuration"
echo ""
echo "Usage:"
echo "  lpac chip info                    # Show chip info"
echo "  lpac profile list                 # List profiles"
echo "  lpac profile download -a <code>   # Download profile"
echo "  lpac profile enable -i <iccid>    # Enable profile"
echo ""
echo "Configuration:"
echo "  Edit /etc/config/lpac to change driver settings"
echo "  Default: AT driver on /dev/ttyUSB2 (Quectel modem)"
echo ""
echo "More info: lpac -h"
echo ""

default_postinst $0 $@
POSTEOF

    # Create pre-removal script
    cat > "$IPK_BUILD_DIR/control/prerm" << 'PREMEOF'
#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh

default_prerm $0 $@
PREMEOF

    # Give execute permission to scripts
    chmod +x "$IPK_BUILD_DIR/control/postinst"
    chmod +x "$IPK_BUILD_DIR/control/prerm"

    # Create TAR archives
    cd "$IPK_BUILD_DIR"
    tar czf control.tar.gz -C control . 2>/dev/null || {
        log_error "Could not create control.tar.gz!"
        return 1
    }
    tar czf data.tar.gz -C data . 2>/dev/null || {
        log_error "Could not create data.tar.gz!"
        return 1
    }

    # Create IPK
    tar czf "$IPK_NAME" debian-binary control.tar.gz data.tar.gz 2>/dev/null || {
        log_error "Could not create IPK package!"
        return 1
    }

    # Move to OUTPUT_DIR
    mv "$IPK_NAME" "$OUTPUT_DIR/"

    # Cleanup
    cd "$BUILD_DIR"
    rm -rf "$IPK_BUILD_DIR"

    log_info "IPK package created: $IPK_NAME"
    log_info "Size: $(du -h "$OUTPUT_DIR/$IPK_NAME" | cut -f1)"

    # ==================== IPK PACKAGING END ====================
}

# Summary report
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  COMPILATION SUCCESSFUL!                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Binary Information:${NC}"
    ls -lh "$OUTPUT_DIR/lpac"
    file "$OUTPUT_DIR/lpac"
    echo ""
    echo -e "${BLUE}Output Directory:${NC} $OUTPUT_DIR"
    echo -e "${BLUE}IPK Package:${NC}"
    ls -lh "$OUTPUT_DIR"/*.ipk 2>/dev/null || echo "  (IPK not found)"
    echo ""
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. cd $OUTPUT_DIR"
    echo "  2. ./deploy.sh 192.168.8.1"
    echo "     (or manual: scp lpac root@192.168.8.1:/usr/bin/)"
    echo ""
    echo -e "${YELLOW}Test on GL-XE300:${NC}"
    echo "  ssh root@192.168.8.1"
    echo "  lpac chip info"
    echo "  lpac profile list"
    echo ""
}

# Cleanup function
clean_all() {
    log_step "Cleaning up..."
    rm -rf "$BUILD_DIR"
    rm -rf "$OUTPUT_DIR"
    log_info "Cleanup completed ✓"
    log_info "Note: SDK preserved (~/xe300-19.07.10-sdk/)"
}

# Main function
main() {
    # Parameters
    case "${1:-}" in
        clean)
            clean_all
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [clean]"
            echo ""
            echo "Options:"
            echo "  clean    Clean all build files"
            echo "  -h       Show this help"
            exit 0
            ;;
    esac

    # Calculate build number (available in all functions)
    mkdir -p "$OUTPUT_DIR"
    LATEST_IPK=$(ls -t "$OUTPUT_DIR"/lpac_*.ipk 2>/dev/null | head -1)
    BUILD_NUMBER=1

    if [ -n "$LATEST_IPK" ]; then
        # lpac_2.3.0-5_mips_24kc.ipk -> extract 5
        BUILD_NUMBER=$(basename "$LATEST_IPK" | grep -oP '\d+\.\d+\.\d+-\K\d+' || echo "0")
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
        log_info "Previous build: $(basename "$LATEST_IPK") → New build number: $BUILD_NUMBER"
    else
        log_info "Creating first build (build #$BUILD_NUMBER)"
    fi

    # Steps
    check_dependencies
    download_sdk
    setup_toolchain
    setup_dependencies
    prepare_source
    compile
    post_process
    package_output
    print_summary
}

# Script çalıştır
main "$@"
