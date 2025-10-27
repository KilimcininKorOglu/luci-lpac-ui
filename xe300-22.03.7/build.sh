#!/bin/bash
#
# GL-XE300 (OpenWrt 22.03.7) quectel_lpad build script for
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
echo "║  GL-XE300 quectel_lpad Cross-Compile Script               ║"
echo "║  Target: OpenWrt 22.03.7 / MIPS 24Kc                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Konfigürasyon
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OPENWRT_VERSION="22.03.7"
OPENWRT_TARGET="ath79"
OPENWRT_SUBTARGET="generic"

# SDK directory - in WSL home directory
SDK_DIR="${HOME}/xe300-22.03.7-sdk/sdk"
OUTPUT_DIR="${SCRIPT_DIR}/output"
BUILD_DIR="${SCRIPT_DIR}/build"

# SDK information (reference for manual installation)
SDK_URL="https://downloads.openwrt.org/releases/${OPENWRT_VERSION}/targets/${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}/openwrt-sdk-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}_gcc-11.2.0_musl.Linux-x86_64.tar.xz"
SDK_ARCHIVE="openwrt-sdk-${OPENWRT_VERSION}.tar.xz"
SDK_EXTRACTED="openwrt-sdk-${OPENWRT_VERSION}-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}_gcc-11.2.0_musl.Linux-x86_64"

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

    local deps=("wget" "tar" "make" "gcc" "g++" "file")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    # Python check (OpenWrt some OpenWrt packages require Python 2/3 in SDK)
    if ! command -v python3 &> /dev/null && ! command -v python2 &> /dev/null && ! command -v python &> /dev/null; then
        log_warn "Python not found (required for some OpenWrt packages)"
        missing+=("python3")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Eksik bağımlılıklar: ${missing[*]}"
        log_info "To install: sudo apt-get install ${missing[*]}"
        exit 1
    fi

    log_info "Tüm bağımlılıklar mevcut ✓"
}

# OpenWrt SDK check and automatic download
download_sdk() {
    log_step "Checking OpenWrt SDK..."

    if [ -d "$SDK_DIR" ]; then
        log_info "SDK directory found: $SDK_DIR"
        log_info "SDK ready ✓"
        return 0
    fi

    log_warn "SDK not found, otomatik indiriliyor..."

    local SDK_PARENT_DIR="${HOME}/xe300-${OPENWRT_VERSION}-sdk"

    mkdir -p "$SDK_PARENT_DIR"
    cd "$SDK_PARENT_DIR"

    # SDK'yı indir
    if [ ! -f "$SDK_ARCHIVE" ]; then
        log_info "SDK indiriliyor: $SDK_URL"
        log_info "Bu işlem birkaç dakika sürebilir (~80-100 MB)..."
        wget -q --show-progress "$SDK_URL" -O "$SDK_ARCHIVE" || {
            log_error "SDK indirilemedi!"
            log_error "To download manually:"
            log_error "  wget $SDK_URL"
            exit 1
        }
    else
        log_info "SDK arşivi zaten indirilmiş"
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
            log_error "Failed to move SDK directory!"
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
    export PATH="${SDK_DIR}/staging_dir/toolchain-mips_24kc_gcc-11.2.0_musl/bin:$PATH"

    # Toolchain check
    if ! command -v "${CROSS_COMPILE}gcc" &> /dev/null; then
        log_error "Toolchain not found: ${CROSS_COMPILE}gcc"
        log_error "STAGING_DIR: $STAGING_DIR"
        exit 1
    fi

    local gcc_version
    gcc_version=$("${CROSS_COMPILE}gcc" --version | head -1)
    log_info "Toolchain bulundu: $gcc_version"

    # Toolchain test
    log_info "Testing toolchain..."
    echo "int main() { return 0; }" | "${CROSS_COMPILE}gcc" -x c - -o /tmp/test_mips$$ || {
        log_error "Toolchain test failed!"
        exit 1
    }
    rm -f /tmp/test_mips$$

    log_info "Toolchain ready ✓"
}

# Use prebuilt wolfssl and libcurl from SDK
build_libcurl() {
    log_step "Checking SSL/TLS and libcurl (SDK prebuilt)..."

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
        log_info "✓ wolfssl bulundu (SDK prebuilt)"
    elif [ -f "${target_dir}/usr/lib/libmbedtls.so" ] || [ -f "${target_dir}/usr/lib/libmbedtls.a" ]; then
        ssl_lib="mbedtls"
        log_info "✓ mbedtls bulundu (SDK prebuilt)"
    else
        log_warn "SSL/TLS library in SDK'da not found, will be compiled..."
        # Fallback: wolfssl'i derle
        ./scripts/feeds update base packages 2>&1 | grep -v "^Checking" || true
        ./scripts/feeds install wolfssl 2>&1 | grep -v "^Checking" || true

        if [ ! -f .config ]; then
            echo "CONFIG_TARGET_ath79=y" > .config
            echo "CONFIG_TARGET_ath79_generic=y" >> .config
            echo "CONFIG_PACKAGE_libwolfssl=y" >> .config
            make defconfig > /dev/null 2>&1
        fi

        log_info "wolfssl being compiled..."
        make -j$(($(nproc)-1)) package/feeds/base/wolfssl/compile V=s 2>&1 | tail -20
        ssl_lib="wolfssl"
    fi

    # Check libcurl headers
    local curl_include="${target_dir}/usr/include/curl"
    if [ ! -d "$curl_include" ]; then
        log_warn "libcurl header'ları SDK'da not found, will be compiled..."
        # Fallback: curl'ü derle
        ./scripts/feeds update packages 2>&1 | grep -v "^Checking" || true
        ./scripts/feeds install curl 2>&1 | grep -v "^Checking" || true

        local curl_feed="packages"
        [ -d "package/feeds/base/curl" ] && curl_feed="base"

        log_info "curl being compiled..."
        make -j$(($(nproc)-1)) package/feeds/${curl_feed}/curl/compile V=s 2>&1 | tail -20
    else
        log_info "✓ libcurl headers bulundu (SDK prebuilt)"
    fi

    # Final check
    if [ ! -d "$curl_include" ]; then
        log_error "libcurl header'ları hala not found: $curl_include"
        exit 1
    fi

    log_info "SSL/TLS stack: $ssl_lib + libcurl (SDK prebuilt being used)"

    cd - > /dev/null
}

# Prepare source code
prepare_source() {
    log_step "Preparing source code..."

    # Clean build directory
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # Copy source files
    log_info "Source files being copied..."
    cp -r "$PROJECT_ROOT/app/app" "$BUILD_DIR/"
    cp -r "$PROJECT_ROOT/app/common" "$BUILD_DIR/"
    cp -r "$PROJECT_ROOT/app/qmi_manager" "$BUILD_DIR/"
    cp -r "$PROJECT_ROOT/app/http_manager" "$BUILD_DIR/"
    cp "$PROJECT_ROOT/app/Makefile" "$BUILD_DIR/"

    # Özel Makefile düzenlemeleri (eğer gerekirse)
    cd "$BUILD_DIR"


    # VERSION'ı güncelle (BUILD_NUMBER ile)
    local VERSION_FILE="$BUILD_DIR/common/common_def.h"
    if [ -f "$VERSION_FILE" ]; then
        sed -i "s/#define LPAD_VERSION \"1.0.7\"/#define LPAD_VERSION \"1.0.7-${BUILD_NUMBER}\"/" "$VERSION_FILE"
        log_info "VERSION güncellendi: 1.0.7-${BUILD_NUMBER}"
    else
        log_warn "VERSION file not found: $VERSION_FILE"
    fi
    log_info "Source code ready ✓"
}

# Compilation
compile() {
    log_step "quectel_lpad being compiled..."

    cd "$BUILD_DIR"

    # OpenWrt staging directories
    local target_dir="${SDK_DIR}/staging_dir/target-mips_24kc_musl"
    local toolchain_dir="${SDK_DIR}/staging_dir/toolchain-mips_24kc_gcc-11.2.0_musl"

    # Compiler flags (using OpenWrt libcurl + dependencies)
    export CFLAGS="-Os -march=24kc -mtune=24kc -ffunction-sections -fdata-sections -pipe"
    export CFLAGS="${CFLAGS} -I${target_dir}/usr/include"
    export CFLAGS="${CFLAGS} -I${toolchain_dir}/include"

    export LDFLAGS="-Wl,--gc-sections"
    export LDFLAGS="${LDFLAGS} -L${target_dir}/usr/lib"
    export LDFLAGS="${LDFLAGS} -L${toolchain_dir}/lib"

    # SSL/TLS: detect which SSL library libcurl is using
    local curl_lib="${target_dir}/usr/lib/libcurl.so"
    if [ -f "$curl_lib" ]; then
        if readelf -d "$curl_lib" 2>/dev/null | grep -q "libwolfssl"; then
            export LDFLAGS="${LDFLAGS} -lwolfssl"
            log_info "libcurl is using wolfssl"
        elif readelf -d "$curl_lib" 2>/dev/null | grep -q "libmbedtls"; then
            export LDFLAGS="${LDFLAGS} -lmbedtls -lmbedx509 -lmbedcrypto"
            log_info "libcurl is using mbedtls"
        else
            # Fallback: decide based on file existence
            if [ -f "${target_dir}/usr/lib/libwolfssl.so" ]; then
                export LDFLAGS="${LDFLAGS} -lwolfssl"
            else
                export LDFLAGS="${LDFLAGS} -lmbedtls -lmbedx509 -lmbedcrypto"
            fi
        fi
    fi

    # HTTP/2 desteği
    if [ -f "${target_dir}/usr/lib/libnghttp2.so" ]; then
        export LDFLAGS="${LDFLAGS} -lnghttp2"
    fi

    log_info "CROSS_COMPILE: ${CROSS_COMPILE}"
    log_info "Target dir: ${target_dir}"
    log_info "CFLAGS: ${CFLAGS}"
    log_info "LDFLAGS: ${LDFLAGS}"

    # Start compilation
    make clean 2>/dev/null || true
    make CROSS_COMPILE="${CROSS_COMPILE}" TARGET=quectel_lpad || {
        log_error "Compilation failed!"
        exit 1
    }

    if [ ! -f "quectel_lpad" ]; then
        log_error "Binary could not be created!"
        exit 1
    fi

    log_info "Compilation successful ✓"
}

# Strip ve analiz
post_process() {
    log_step "Binary işleniyor..."

    cd "$BUILD_DIR"

    # Binary information
    log_info "Binary information (before strip):"
    ls -lh quectel_lpad
    file quectel_lpad

    # Strip uygula
    log_info "Removing debug symbols (strip)..."
    "${CROSS_COMPILE}strip" quectel_lpad

    log_info "Binary information (strip sonrası):"
    ls -lh quectel_lpad

    # Architecture check
    local arch_info
    arch_info=$(file quectel_lpad)
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
    cp "$BUILD_DIR/quectel_lpad" "$OUTPUT_DIR/"

    # Create README
    cat > "$OUTPUT_DIR/README.txt" << EOF
╔════════════════════════════════════════════════════════════╗
║  quectel_lpad - GL-XE300 Binary                           ║
║  OpenWrt: ${OPENWRT_VERSION}                                      ║
║  Target: ${OPENWRT_TARGET}/${OPENWRT_SUBTARGET}                                ║
║  Arch: MIPS 24Kc                                          ║
║  Build Date: $(date '+%Y-%m-%d %H:%M:%S')                        ║
╚════════════════════════════════════════════════════════════╝

INSTALLATION:
--------
1. Connect to GL-XE300 via SSH:
   ssh root@192.168.8.1

2. Install dependencies:
   opkg update
   opkg install libcurl libpthread kmod-usb-net-qmi-wwan

3. Install the binary:
   # On this computer:
   scp quectel_lpad root@192.168.8.1:/usr/bin/

   # On GL-XE300:
   chmod +x /usr/bin/quectel_lpad

4. Verify modem:
   ls -l /dev/cdc-wdm0
   # Output: crw-rw---- ... /dev/cdc-wdm0

USAGE:
---------
# Add eSIM profile:
quectel_lpad -A "activation_code"

# Debug mode:
quectel_lpad -D 1 -A "activation_code"

# Delete profile (ID: 1-8):
quectel_lpad -R 1

# Help:
quectel_lpad

NOTES:
-------
- EP06-E modem firmware: EP06ELAR04A22M4G or higher
- Firmware check: echo "ATI" > /dev/ttyUSB2
- Default QMI device: /dev/cdc-wdm0
- Binary size: ~140-150 KB (stripped)

TROUBLESHOOTING:
--------------
1. "libcurl.so.4 not found" error:
   opkg install libcurl4

2. "/dev/cdc-wdm0 not found":
   lsusb | grep Quectel
   ls -l /dev/ttyUSB*

3. QMI cihaz izinleri:
   chmod 666 /dev/cdc-wdm0

SUPPORT:
-------
- See CLAUDE.md for detailed architecture
- Quectel Forum: https://forums.quectel.com/
- GL.iNet Forum: https://forum.gl-inet.com/

EOF

    # Create deployment script
    cat > "$OUTPUT_DIR/deploy.sh" << 'DEPLOYEOF'
#!/bin/bash
# GL-XE300 deployment script

set -e

ROUTER_IP="${1:-192.168.8.1}"
ROUTER_USER="root"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  GL-XE300 quectel_lpad Deployment Script                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Target: ${ROUTER_USER}@${ROUTER_IP}"
echo ""

# Check binary
if [ ! -f "quectel_lpad" ]; then
    echo "ERROR: quectel_lpad binary not found!"
    exit 1
fi

echo "[1/5] Transferring binary..."
scp quectel_lpad "${ROUTER_USER}@${ROUTER_IP}:/tmp/" || {
    echo "ERROR: Transfer failed!"
    exit 1
}

echo "[2/5] Checking dependencies..."
ssh "${ROUTER_USER}@${ROUTER_IP}" << 'REMOTEEOF'
opkg update
opkg list-installed | grep -q libcurl || opkg install libcurl
opkg list-installed | grep -q libpthread || echo "libpthread already installed"
opkg list-installed | grep -q kmod-usb-net-qmi-wwan || opkg install kmod-usb-net-qmi-wwan
REMOTEEOF

echo "[3/5] Installing binary..."
ssh "${ROUTER_USER}@${ROUTER_IP}" << 'REMOTEEOF'
mv /tmp/quectel_lpad /usr/bin/
chmod +x /usr/bin/quectel_lpad
REMOTEEOF

echo "[4/5] Checking modem..."
ssh "${ROUTER_USER}@${ROUTER_IP}" << 'REMOTEEOF'
if [ ! -e /dev/cdc-wdm0 ]; then
    echo "WARNING: /dev/cdc-wdm0 not found!"
    echo "Check if modem is connected:"
    lsusb | grep -i quectel || echo "  Quectel modem not found!"
    ls -l /dev/ttyUSB* 2>/dev/null || echo "  USB serial ports not found!"
else
    echo "QMI device found: /dev/cdc-wdm0"
fi
REMOTEEOF

echo "[5/5] Installation completed!"
echo ""
echo "To test:"
echo "  ssh ${ROUTER_USER}@${ROUTER_IP}"
echo "  quectel_lpad -D 1 -A \"activation_code\""
echo ""

DEPLOYEOF

    chmod +x "$OUTPUT_DIR/deploy.sh"

    log_info "Output ready: $OUTPUT_DIR/"
    log_info "  - quectel_lpad (binary)"
    log_info "  - README.txt (installation guide)"
    log_info "  - deploy.sh (automatic deployment)"

    # ==================== IPK PACKAGING ====================
    log_step "Creating IPK package..."

    local IPK_BUILD_DIR="$BUILD_DIR/ipk-build"
    local PKG_VERSION="1.0.7"
    local PKG_ARCH="mips_24kc"
    local IPK_NAME="quectel-lpad_${PKG_VERSION}-${BUILD_NUMBER}_${PKG_ARCH}.ipk"

    # Clean and create IPK structure
    rm -rf "$IPK_BUILD_DIR"
    mkdir -p "$IPK_BUILD_DIR"/{control,data/usr/bin}

    # Create debian-binary
    echo "2.0" > "$IPK_BUILD_DIR/debian-binary"

    # Copy binary to data folder
    cp "$BUILD_DIR/quectel_lpad" "$IPK_BUILD_DIR/data/usr/bin/"
    chmod +x "$IPK_BUILD_DIR/data/usr/bin/quectel_lpad"

    # Binary boyutunu calculate
    local BINARY_SIZE=$(stat -c%s "$BUILD_DIR/quectel_lpad" 2>/dev/null || stat -f%z "$BUILD_DIR/quectel_lpad" 2>/dev/null)

    # Create control file
    cat > "$IPK_BUILD_DIR/control/control" << CTRLEOF
Package: quectel-lpad
Version: ${PKG_VERSION}-${BUILD_NUMBER}
Depends: libc, libpthread, libcurl
Section: net
Architecture: ${PKG_ARCH}
Installed-Size: ${BINARY_SIZE}
Maintainer: quectel_lpad Team
Description: eSIM Profile Management Tool for Quectel Modems
 Command-line utility for managing eSIM profiles on Quectel modems.
 Implements GSMA RSP v2.2.0 protocol for adding and deleting eSIM
 profiles via QMI communication.
 .
 Features:
  - Add eSIM profiles with activation codes
  - Delete profiles by ID (1-16)
  - QMI-based modem communication
  - HTTP proxy for SM-DP+ servers
 .
 Compatible with: RG500Q, RM500Q, EP06-E and similar Quectel modems
 OpenWrt: ${OPENWRT_VERSION}
CTRLEOF

    # Create post-install script
    cat > "$IPK_BUILD_DIR/control/postinst" << 'POSTEOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh

echo ""
echo "✅ quectel-lpad kuruldu!"
echo ""
echo "Usage:"
echo "  quectel_lpad -A <activation_code>     # Profil ekle"
echo "  quectel_lpad -R <profile_id>          # Profil sil"
echo "  quectel_lpad -D 1 -A <code>           # Debug modu"
echo ""
echo "QMI cihaz: /dev/cdc-wdm0"
echo "Daha fazla: quectel_lpad -h"
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

    # Script'lere execute izni ver
    chmod +x "$IPK_BUILD_DIR/control/postinst"
    chmod +x "$IPK_BUILD_DIR/control/prerm"

    # Create TAR archives
    cd "$IPK_BUILD_DIR"
    tar czf control.tar.gz -C control . 2>/dev/null || {
        log_error "control.tar.gz could not be created!"
        return 1
    }
    tar czf data.tar.gz -C data . 2>/dev/null || {
        log_error "data.tar.gz could not be created!"
        return 1
    }

    # Create IPK
    tar czf "$IPK_NAME" debian-binary control.tar.gz data.tar.gz 2>/dev/null || {
        log_error "IPK package creation failed!"
        return 1
    }

    # OUTPUT_DIR'e taşı
    mv "$IPK_NAME" "$OUTPUT_DIR/"

    # Temizlik
    cd "$BUILD_DIR"
    rm -rf "$IPK_BUILD_DIR"

    log_info "IPK package created: $IPK_NAME"
    log_info "Boyut: $(du -h "$OUTPUT_DIR/$IPK_NAME" | cut -f1)"

    # ==================== IPK PACKAGING END ====================
}

# Summary report
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  BUILD SUCCESSFUL!                                        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Binary Information:${NC}"
    ls -lh "$OUTPUT_DIR/quectel_lpad"
    file "$OUTPUT_DIR/quectel_lpad"
    echo ""
    echo -e "${BLUE}Output Directory:${NC} $OUTPUT_DIR"
    echo -e "${BLUE}IPK Package:${NC}"
    ls -lh "$OUTPUT_DIR"/*.ipk 2>/dev/null || echo "  (IPK not found)"
    echo ""
    echo ""
    echo -e "${YELLOW}Sonraki Adımlar:${NC}"
    echo "  1. cd $OUTPUT_DIR"
    echo "  2. ./deploy.sh 192.168.8.1"
    echo "     (veya manuel: scp quectel_lpad root@192.168.8.1:/usr/bin/)"
    echo ""
    echo -e "${YELLOW}GL-XE300'de test:${NC}"
    echo "  ssh root@192.168.8.1"
    echo "  quectel_lpad -D 1 -A \"activation_code\""
    echo ""
}

# Temizlik fonksiyonu
clean_all() {
    log_step "Temizlik in progress..."
    rm -rf "$BUILD_DIR"
    rm -rf "$OUTPUT_DIR"
    log_info "Cleanup completed ✓"
    log_info "Not: SDK korundu (~/xe300-22.03.7-sdk/)"
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
            echo "Opsiyonlar:"
            echo "  clean    Clean all build files"
            echo "  -h       Bu yardımı göster"
            exit 0
            ;;
    esac

    # Calculate build number (available in all functions)
    # Clean output directory (except IPK)
    log_info "Cleaning output directory (preserving IPK files)..."
    if [ -d "$OUTPUT_DIR" ]; then
        find "$OUTPUT_DIR" -type f ! -name "*.ipk" -delete 2>/dev/null || true
        find "$OUTPUT_DIR" -type d -empty -delete 2>/dev/null || true
    fi
    LATEST_IPK=$(ls -t "$OUTPUT_DIR"/quectel-lpad_*.ipk 2>/dev/null | head -1)
    BUILD_NUMBER=1

    if [ -n "$LATEST_IPK" ]; then
        # quectel-lpad_1.0.7-5_mips_24kc.ipk -> extract 5
        BUILD_NUMBER=$(basename "$LATEST_IPK" | grep -oP '\d+\.\d+\.\d+-\K\d+' || echo "0")
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
        log_info "Önceki build: $(basename "$LATEST_IPK") → New build number: $BUILD_NUMBER"
    else
        log_info "Creating first build (build #$BUILD_NUMBER)"
    fi

    # Steps
    check_dependencies
    download_sdk
    setup_toolchain
    build_libcurl
    prepare_source
    compile
    post_process
    package_output
    print_summary
}

# Script çalıştır
main "$@"
