#!/bin/bash

# Generic OpenWrt Multi-version lpac Build Script
# Device-agnostic build system using device profiles

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="$SCRIPT_DIR/device-profiles"
OPENWRT_BASE_URL="https://downloads.openwrt.org"

# Global variables (populated from device profile)
DEVICE_NAME=""
DEVICE_PROFILE=""
OPENWRT_TARGET=""
OPENWRT_SUBTARGET=""
OPENWRT_VERSIONS=()
PARALLEL_JOBS=$(nproc)

# Define log functions first
log() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1" >&2
    fi
}

# Initialize BUILD_ROOT based on environment
# Hybrid approach: Use native FS for cache/extract (avoids symlink issues on WSL/Windows)
if grep -i microsoft /proc/version 2>/dev/null || [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    # Running on WSL
    BUILD_ROOT="${HOME}/.local/build/openwrt-lpac"
    debug "Detected WSL environment - using native filesystem for builds"
else
    # Running on native Linux
    BUILD_ROOT="$SCRIPT_DIR/lpac/build-openwrt"
fi

show_usage() {
    cat << EOF
Generic OpenWrt Multi-version lpac Build Script

Usage: $0 [OPTIONS] <TARGET> [VERSIONS...]

BUILD MODES:
  1. Device Profile Mode (with optimizations):
     $0 [OPTIONS] DEVICE_PROFILE [VERSIONS...]

  2. Generic Platform Mode (architecture only):
     $0 [OPTIONS] --arch TARGET/SUBTARGET [VERSIONS...]

TARGET:         Device profile name OR use --arch for generic platform
VERSIONS:       Specific OpenWrt versions to build (optional)
                Default: 23.05.5

OPTIONS:
  -h, --help              Show this help message
  -l, --list-devices      List available device profiles
  -i, --info DEVICE       Show device profile information
  -a, --arch TARGET/SUB   Build for generic platform (e.g., ath79/generic)
  --list-targets          List common OpenWrt targets
  -j, --jobs N            Number of parallel jobs (default: $(nproc))
  --verbose               Enable verbose output
  --clean TARGET          Clean build directory
  --clean-all             Clean all build directories

EXAMPLES:
  # Device profile mode (with optimizations)
  $0 xe300                              # Build XE300 with all versions
  $0 xe300 23.05.5                      # Build specific version
  $0 -j 8 xe300 23.05.5 22.03.7         # Build multiple versions

  # Generic platform mode
  $0 --arch ramips/mt7621 23.05.5       # Generic MT7621 build
  $0 --arch x86/64 23.05.5 22.03.7      # x86_64 multi-version
  $0 --arch ath79/generic 24.10.0       # Generic ATH79 build

  # Information
  $0 --list-devices                     # List device profiles
  $0 --list-targets                     # List common platforms
  $0 --info xe300                       # Show XE300 details
  $0 --clean xe300                      # Clean XE300 builds

EOF
}

list_devices() {
    echo "Available device profiles:"
    echo ""
    if [ ! -d "$PROFILES_DIR" ] || [ -z "$(ls -A "$PROFILES_DIR"/*.json 2>/dev/null)" ]; then
        echo "  No device profiles found in $PROFILES_DIR"
        return
    fi

    for profile in "$PROFILES_DIR"/*.json; do
        local device_name=$(basename "$profile" .json)
        local vendor=$(jq -r '.device.vendor // "Unknown"' "$profile" 2>/dev/null)
        local model=$(jq -r '.device.model // "Unknown"' "$profile" 2>/dev/null)
        local desc=$(jq -r '.device.description // ""' "$profile" 2>/dev/null)

        echo "  $device_name"
        echo "    Vendor: $vendor"
        echo "    Model:  $model"
        if [ -n "$desc" ]; then
            echo "    Description: $desc"
        fi
        echo ""
    done
}

list_targets() {
    cat << EOF
Common OpenWrt Targets:

  x86/64                  - x86 64-bit (PC, VM)
  x86/generic             - x86 32-bit
  ath79/generic           - Atheros AR71xx/AR9xxx (GL-XE300, many routers)
  ramips/mt7621           - MediaTek MT7621 (Xiaomi, Ubiquiti)
  ramips/mt7620           - MediaTek MT7620
  ramips/mt76x8           - MediaTek MT76x8
  ipq40xx/generic         - Qualcomm IPQ40xx (many mesh routers)
  ipq806x/generic         - Qualcomm IPQ806x
  rockchip/armv8          - Rockchip ARM64 (NanoPi, FriendlyARM)
  bcm27xx/bcm2711         - Raspberry Pi 4
  bcm27xx/bcm2710         - Raspberry Pi 3
  mediatek/mt7622         - MediaTek MT7622
  mvebu/cortexa9          - Marvell Armada (Linksys WRT)

For more targets, visit: https://downloads.openwrt.org/releases/

EOF
}

load_generic_platform() {
    local target_path=$1

    # Parse target/subtarget
    OPENWRT_TARGET="${target_path%/*}"
    OPENWRT_SUBTARGET="${target_path#*/}"

    if [ -z "$OPENWRT_TARGET" ] || [ -z "$OPENWRT_SUBTARGET" ]; then
        error "Invalid target format. Use: target/subtarget (e.g., ath79/generic)"
    fi

    DEVICE_NAME="$OPENWRT_TARGET-$OPENWRT_SUBTARGET"

    # Default versions for generic build
    OPENWRT_VERSIONS=("23.05.5")

    # Clear device profile (generic mode)
    DEVICE_PROFILE=""

    log "Using generic platform mode: $OPENWRT_TARGET/$OPENWRT_SUBTARGET"
    debug "Default version: ${OPENWRT_VERSIONS[0]}"
}

show_device_info() {
    local device=$1
    local profile_file="$PROFILES_DIR/${device}.json"

    if [ ! -f "$profile_file" ]; then
        error "Device profile not found: $device"
    fi

    echo "Device Profile: $device"
    echo ""
    echo "Hardware Information:"
    jq -r '.hardware | to_entries[] | "  \(.key): \(.value)"' "$profile_file" 2>/dev/null || true
    echo ""
    echo "OpenWrt Target: $(jq -r '.openwrt.target' "$profile_file")/$(jq -r '.openwrt.subtarget' "$profile_file")"
    echo "Supported Versions:"
    jq -r '.openwrt.versions[]' "$profile_file" | sed 's/^/  /' || true
    echo ""
}

load_device_profile() {
    local device=$1
    local profile_file="$PROFILES_DIR/${device}.json"

    debug "Loading device profile: $profile_file"

    if [ ! -f "$profile_file" ]; then
        error "Device profile not found: $device\nAvailable profiles: $(ls "$PROFILES_DIR"/*.json 2>/dev/null | xargs -n1 basename | sed 's/.json$//' | tr '\n' ' ')"
    fi

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Please install jq: apt-get install jq"
    fi

    # Parse profile
    DEVICE_NAME=$(jq -r '.device.name' "$profile_file")
    OPENWRT_TARGET=$(jq -r '.openwrt.target' "$profile_file")
    OPENWRT_SUBTARGET=$(jq -r '.openwrt.subtarget' "$profile_file")

    # Read versions into array
    readarray -t OPENWRT_VERSIONS < <(jq -r '.openwrt.versions[]' "$profile_file")

    log "Loaded profile for: $DEVICE_NAME"
    debug "Target: $OPENWRT_TARGET/$OPENWRT_SUBTARGET"
    debug "Versions: ${OPENWRT_VERSIONS[*]}"

    DEVICE_PROFILE="$profile_file"
}

check_dependencies() {
    local missing_deps=()
    local mode=$1  # "profile" or "generic"

    # Basic dependencies
    for cmd in wget tar gcc make; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # jq only required for profile mode
    if [ "$mode" = "profile" ] && ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}\nPlease install: apt-get install ${missing_deps[*]}"
    fi
}

check_disk_space() {
    local required_gb=20
    local build_path="$BUILD_ROOT"

    mkdir -p "$build_path"

    local available=$(df -BG "$build_path" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')

    # Fallback for systems without -BG support
    if [ -z "$available" ] || [ "$available" = "" ]; then
        available=$(df -k "$build_path" | awk 'NR==2 {print int($4/1024/1024)}')
    fi

    if [ -z "$available" ] || [ "$available" -lt "$required_gb" ]; then
        warn "Low disk space. Required: ${required_gb}GB, Available: ${available}GB"
    else
        log "Disk space check passed (Available: ${available}GB, Required: ${required_gb}GB)"
    fi
}

cleanup_temp_files() {
    log "Cleaning up temporary files..."

    # Remove temporary extraction directories
    if [ -d "$BUILD_ROOT" ]; then
        find "$BUILD_ROOT" -name "*.tmp" -type f -exec rm -f {} + 2>/dev/null || true
        find "$BUILD_ROOT" -name "*.tar" -type f -exec rm -f {} + 2>/dev/null || true
    fi

    debug "Cleanup completed"
}

# Trap for cleanup on exit
trap cleanup_temp_files EXIT INT TERM

get_gcc_version() {
    local openwrt_version=$1
    local major_version="${openwrt_version%%.*}"

    case $major_version in
        24) echo "13.3.0" ;;
        23) echo "12.3.0" ;;
        22) echo "11.2.0" ;;
        21) echo "8.4.0" ;;
        *) echo "12.3.0" ;;  # Default
    esac
}

download_sdk() {
    local version=$1
    local device=$2
    local sdk_dir="$BUILD_ROOT/$device/sdk-$version"
    local cache_dir="$BUILD_ROOT/cache"

    mkdir -p "$cache_dir" "$sdk_dir"

    # Determine SDK URL and name based on version
    local base_url
    local gcc_version=$(get_gcc_version "$version")
    local sdk_name

    case "$version" in
        24.10-SNAPSHOT|*-SNAPSHOT)
            # Snapshot builds use different URL structure
            base_url="$OPENWRT_BASE_URL/snapshots"

            log "Detecting snapshot SDK filename..."
            local dir_url="$base_url/targets/$OPENWRT_TARGET/$OPENWRT_SUBTARGET/"
            local sdk_pattern="openwrt-sdk-${OPENWRT_TARGET}-${OPENWRT_SUBTARGET}_gcc-.*_musl\.Linux-x86_64\.tar\.xz"

            # Try to get SDK filename from directory listing
            sdk_name=$(timeout 30 wget -q -O - "$dir_url" 2>/dev/null | \
                       grep -oE "$sdk_pattern" | head -1)

            # Fallback to curl if wget fails
            if [ -z "$sdk_name" ]; then
                debug "Trying with curl..."
                sdk_name=$(timeout 30 curl -s "$dir_url" 2>/dev/null | \
                           grep -oE "$sdk_pattern" | head -1)
            fi

            if [ -z "$sdk_name" ]; then
                error "Failed to detect snapshot SDK filename. Check your internet connection or try again later."
            fi

            log "Detected SDK: $sdk_name"
            ;;
        21.*)
            base_url="https://archive.openwrt.org/releases/$version"
            sdk_name="openwrt-sdk-$version-$OPENWRT_TARGET-$OPENWRT_SUBTARGET"
            sdk_name+="_gcc-${gcc_version}_musl.Linux-x86_64.tar.xz"
            ;;
        22.*)
            base_url="https://archive.openwrt.org/releases/$version"
            sdk_name="openwrt-sdk-$version-$OPENWRT_TARGET-$OPENWRT_SUBTARGET"
            sdk_name+="_gcc-${gcc_version}_musl.Linux-x86_64.tar.xz"
            ;;
        *)
            # 23.05.x and newer stable releases
            base_url="https://archive.openwrt.org/releases/$version"
            sdk_name="openwrt-sdk-$version-$OPENWRT_TARGET-$OPENWRT_SUBTARGET"
            sdk_name+="_gcc-${gcc_version}_musl.Linux-x86_64.tar.xz"
            ;;
    esac

    local sdk_url="$base_url/targets/$OPENWRT_TARGET/$OPENWRT_SUBTARGET/$sdk_name"
    local cache_file="$cache_dir/$sdk_name"

    log "Downloading SDK for $version..."
    debug "URL: $sdk_url"

    # Download SDK if not cached
    if [ ! -f "$cache_file" ]; then
        log "Starting download with progress indicator..."
        log "File size: ~300MB (may take 5-15 minutes depending on connection)"

        # Download with timeout (1 hour for slow connections)
        if ! timeout 3600 wget --progress=bar:force -O "$cache_file.tmp" "$sdk_url"; then
            rm -f "$cache_file.tmp"
            error "Failed to download SDK from $sdk_url"
        fi

        # Download and verify checksum if available
        local checksum_url="${sdk_url%.tar.xz}.sha256"
        local checksum_file="$cache_file.sha256"

        if wget -q --spider "$checksum_url" 2>/dev/null; then
            log "Downloading checksum file..."
            wget -q -O "$checksum_file" "$checksum_url" || warn "Failed to download checksum"

            # Verify checksum if downloaded
            if [ -f "$checksum_file" ]; then
                log "Verifying checksum..."
                local expected_checksum=$(cat "$checksum_file" | awk '{print $1}')
                local actual_checksum=$(sha256sum "$cache_file.tmp" | awk '{print $1}')

                if [ "$expected_checksum" = "$actual_checksum" ]; then
                    log "Checksum verification passed ✓"
                else
                    rm -f "$cache_file.tmp"
                    error "Checksum verification failed! Expected: $expected_checksum, Got: $actual_checksum"
                fi
            fi
        else
            warn "Checksum file not available, skipping verification"
        fi

        # Move to final location
        mv "$cache_file.tmp" "$cache_file"

        local file_size=$(du -h "$cache_file" | cut -f1)
        log "SDK downloaded successfully (size: $file_size)"
    else
        local file_size=$(du -h "$cache_file" | cut -f1)
        log "SDK already cached (size: $file_size)"
    fi

    # Extract SDK if not already extracted
    if [ ! -f "$sdk_dir/Makefile" ]; then
        log "Extracting SDK to $sdk_dir..."
        log "This may take several minutes..."

        # Use native tar for proper symlink handling (7zip breaks symlinks on WSL)
        mkdir -p "$sdk_dir"

        log "Extracting with tar (preserves symlinks)..."
        if ! tar -xJf "$cache_file" -C "$sdk_dir" --strip-components=1 2>&1; then
            error "Failed to extract SDK with tar"
        fi

        log "SDK extracted successfully"
    else
        log "SDK already extracted"
    fi

    echo "$sdk_dir"
}

generate_makefile() {
    local device=$1
    local sdk_dir=$2
    local output_file="$sdk_dir/package/lpac/Makefile"

    if [ -n "$DEVICE_PROFILE" ]; then
        log "Generating OpenWrt Makefile from device profile..."
        generate_makefile_from_profile "$device" "$sdk_dir" "$output_file"
    else
        log "Generating generic OpenWrt Makefile..."
        generate_generic_makefile "$device" "$sdk_dir" "$output_file"
    fi
}

generate_generic_makefile() {
    local device=$1
    local sdk_dir=$2
    local output_file=$3

    cat > "$output_file" << 'MAKEFILE_EOF'
# OpenWrt Makefile for lpac (Generic Build)

include $(TOPDIR)/rules.mk

PKG_NAME:=lpac
PKG_VERSION:=2.1.0
PKG_RELEASE:=$(shell date +%Y%m%d)-1

PKG_LICENSE:=AGPL-3.0
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=eSTKme Group <contact@estk.me>

PKG_BUILD_PARALLEL:=1

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/lpac
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=C-based eUICC Local Profile Agent
  URL:=https://github.com/estkme-group/lpac
  DEPENDS:=+libcurl +libpcsclite
  MENU:=1
endef

define Package/lpac/description
  lpac is a cross-platform local profile agent program,
  compatible with SGP.22 version 2.2.2.

  Includes multiple APDU backends (AT, PC/SC, stdio) and HTTP backends (curl, stdio).
  Default backend is AT for embedded devices.
  To use PC/SC: install libpcsclite and set LPAC_APDU=pcsc
endef

define Package/lpac/conffiles
/etc/config/lpac
endef

CMAKE_OPTIONS += \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DLPAC_WITH_APDU_PCSC=OFF \
  -DLPAC_WITH_APDU_AT=ON \
  -DLPAC_WITH_APDU_UQMI=ON \
  -DLPAC_WITH_HTTP_CURL=ON

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./CMakeLists.txt $(PKG_BUILD_DIR)/
	$(CP) -r ./cmake $(PKG_BUILD_DIR)/ 2>/dev/null || true
	$(CP) -r ./cjson-ext $(PKG_BUILD_DIR)/ 2>/dev/null || true
	$(CP) -r ./euicc $(PKG_BUILD_DIR)/
	$(CP) -r ./driver $(PKG_BUILD_DIR)/
	$(CP) -r ./src $(PKG_BUILD_DIR)/
	$(CP) -r ./utils $(PKG_BUILD_DIR)/ 2>/dev/null || true
	$(CP) -r ./dlfcn-win32 $(PKG_BUILD_DIR)/ 2>/dev/null || true
endef

define Package/lpac/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/lpac $(1)/usr/bin/

	# Install shared libraries
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libeuicc.so* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/liblpac-utils.so $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libeuicc-driver-loader.so* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libeuicc-drivers.so* $(1)/usr/lib/

	# Install driver plugins
	$(INSTALL_DIR) $(1)/usr/lib/lpac/driver
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lpac/driver/*.so $(1)/usr/lib/lpac/driver/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/lpac.config $(1)/etc/config/lpac

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/lpac.init $(1)/etc/init.d/lpac

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/90-lpac-config $(1)/etc/uci-defaults/90-lpac-config
endef

$(eval $(call BuildPackage,lpac))
MAKEFILE_EOF

    log "Generic Makefile generated successfully"
}

generate_makefile_from_profile() {
    local device=$1
    local sdk_dir=$2
    local output_file=$3

    # Read profile data
    local pkg_name=$(jq -r '.build.package_name' "$DEVICE_PROFILE")
    local cpu_model=$(jq -r '.hardware.cpu.model' "$DEVICE_PROFILE")
    local ram_size=$(jq -r '.hardware.memory.ram' "$DEVICE_PROFILE" | sed 's/MB//')
    local cmake_opts=$(jq -r '.build.cmake_options[]' "$DEVICE_PROFILE" | sed 's/^/  /')
    local cflags=$(jq -r '.build.compiler_flags.CFLAGS' "$DEVICE_PROFILE")
    local ldflags=$(jq -r '.build.compiler_flags.LDFLAGS' "$DEVICE_PROFILE")
    local deps=$(jq -r '.dependencies[]' "$DEVICE_PROFILE" | sed 's/^/+/' | tr '\n' ' ')
    local opt_deps=$(jq -r '.optional_dependencies[]' "$DEVICE_PROFILE" 2>/dev/null | sed 's/^/+/' | tr '\n' ' ' || echo "")

    cat > "$output_file" << 'MAKEFILE_EOF'
# OpenWrt Makefile for lpac
# Auto-generated from device profile

include $(TOPDIR)/rules.mk

PKG_NAME:=lpac
PKG_VERSION:=2.1.0
PKG_RELEASE:=$(shell date +%Y%m%d)-1

PKG_LICENSE:=AGPL-3.0
PKG_LICENSE_FILES:=LICENSE
PKG_MAINTAINER:=eSTKme Group <contact@estk.me>

PKG_BUILD_PARALLEL:=1
PKG_USE_MIPS16:=0

include $(INCLUDE_DIR)/package.mk
include $(INCLUDE_DIR)/cmake.mk

define Package/lpac
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=C-based eUICC Local Profile Agent
  URL:=https://github.com/estkme-group/lpac
MAKEFILE_EOF

    # Add dependencies
    echo "  DEPENDS:=$deps$opt_deps" >> "$output_file"

    cat >> "$output_file" << 'MAKEFILE_EOF'
  MENU:=1
endef

define Package/lpac/description
  lpac is a cross-platform local profile agent program,
  compatible with SGP.22 version 2.2.2.

  Features:
  - Profile management (list, download, enable, disable, delete)
  - Notification management
  - eUICC chip information
  - Multiple APDU backends (AT, PC/SC, QMI)
endef

define Package/lpac/conffiles
/etc/config/lpac
endef

MAKEFILE_EOF

    # Add CMake options
    echo "" >> "$output_file"
    echo "CMAKE_OPTIONS += \\" >> "$output_file"
    echo "$cmake_opts" | while read -r opt; do
        [ -n "$opt" ] && echo "  $opt \\" >> "$output_file"
    done
    echo "  -DCMAKE_BUILD_TYPE=Release \\" >> "$output_file"
    echo "  -DCMAKE_INSTALL_PREFIX=/usr \\" >> "$output_file"
    echo "  -DCMAKE_INSTALL_LIBDIR=lib \\" >> "$output_file"
    echo "  -DLPAC_WITH_APDU_PCSC=OFF \\" >> "$output_file"
    echo "  -DLPAC_WITH_APDU_AT=ON \\" >> "$output_file"
    echo "  -DLPAC_WITH_APDU_UQMI=ON \\" >> "$output_file"
    echo "  -DLPAC_WITH_HTTP_CURL=ON" >> "$output_file"

    # Add compiler flags
    echo "" >> "$output_file"
    echo "TARGET_CFLAGS += $cflags" >> "$output_file"
    echo "TARGET_LDFLAGS += $ldflags" >> "$output_file"

    # Add Build/Prepare section
    cat >> "$output_file" << 'MAKEFILE_EOF'

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./CMakeLists.txt $(PKG_BUILD_DIR)/
	$(CP) -r ./cmake $(PKG_BUILD_DIR)/ 2>/dev/null || true
	$(CP) -r ./cjson-ext $(PKG_BUILD_DIR)/ 2>/dev/null || true
	$(CP) -r ./euicc $(PKG_BUILD_DIR)/
	$(CP) -r ./driver $(PKG_BUILD_DIR)/
	$(CP) -r ./src $(PKG_BUILD_DIR)/
	$(CP) -r ./utils $(PKG_BUILD_DIR)/ 2>/dev/null || true
	$(CP) -r ./dlfcn-win32 $(PKG_BUILD_DIR)/ 2>/dev/null || true
endef

define Package/lpac/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_INSTALL_DIR)/usr/bin/lpac $(1)/usr/bin/

	# Install shared libraries
	$(INSTALL_DIR) $(1)/usr/lib
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libeuicc.so* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/liblpac-utils.so $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libeuicc-driver-loader.so* $(1)/usr/lib/
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/libeuicc-drivers.so* $(1)/usr/lib/

	# Install driver plugins
	$(INSTALL_DIR) $(1)/usr/lib/lpac/driver
	$(CP) $(PKG_INSTALL_DIR)/usr/lib/lpac/driver/*.so $(1)/usr/lib/lpac/driver/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/lpac.config $(1)/etc/config/lpac

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/lpac.init $(1)/etc/init.d/lpac

	$(INSTALL_DIR) $(1)/etc/uci-defaults
	$(INSTALL_BIN) ./files/90-lpac-config $(1)/etc/uci-defaults/90-lpac-config
endef

$(eval $(call BuildPackage,lpac))
MAKEFILE_EOF

    log "Makefile generated successfully"
}

prepare_package() {
    local sdk_dir=$1
    local device=$2
    local package_dir="$sdk_dir/package/lpac"

    log "Preparing package source..."

    mkdir -p "$package_dir"

    # Copy lpac source from lpac/ subdirectory (excluding build artifacts and scripts)
    rsync -a --exclude='build*' --exclude='output' --exclude='.git' \
        --exclude='app_ipk_archive' --exclude='*.sh' \
        "$SCRIPT_DIR/lpac/" "$package_dir/"

    # Verify required files exist
    if [ ! -d "$SCRIPT_DIR/lpac/files" ]; then
        error "Missing required files/ directory in lpac source!"
        return 1
    fi

    # Ensure config files are executable
    chmod +x "$SCRIPT_DIR/lpac/files/lpac.init" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/lpac/files/90-lpac-config" 2>/dev/null || true

    # LuCI UI integration disabled - use separate luci-app-lpac package

    # Generate Makefile
    generate_makefile "$device" "$sdk_dir"
}

build_version() {
    local version=$1
    local device=$2
    local output_dir="$BUILD_ROOT/$device/output/$version"

    # Start version timer
    local version_start=$(date +%s)

    log "================================================================"
    log "Building $DEVICE_NAME for OpenWrt $version"
    log "================================================================"

    # Create output directory early (for build.log)
    mkdir -p "$output_dir"

    # Download SDK
    local sdk_dir=$(download_sdk "$version" "$device")

    # Prepare package
    prepare_package "$sdk_dir" "$device"

    # Update feeds
    log "Updating feeds..."
    cd "$sdk_dir"
    ./scripts/feeds update -a >> "$output_dir/build.log" 2>&1 || warn "Feed update had warnings"
    ./scripts/feeds install -a >> "$output_dir/build.log" 2>&1 || warn "Feed install had warnings"

    # Configure
    log "Configuring build..."
    echo "CONFIG_PACKAGE_lpac=m" > "$sdk_dir/.config"
    make defconfig >> "$output_dir/build.log" 2>&1

    # Build
    log "Compiling package (this may take a while)..."
    if make package/lpac/compile -j"$PARALLEL_JOBS" V=s >> "$output_dir/build.log" 2>&1; then
        # Calculate version build time
        local version_end=$(date +%s)
        local version_elapsed=$((version_end - version_start))
        local ver_minutes=$((version_elapsed / 60))
        local ver_seconds=$((version_elapsed % 60))

        log "Build successful for $version (${ver_minutes}m ${ver_seconds}s)"
    else
        error "Build failed for $version. Check log: $output_dir/build.log"
    fi

    # Collect packages
    log "Collecting built packages..."
    find "$sdk_dir/bin" -name "*lpac*.ipk" -exec cp {} "$output_dir/" \;

    local pkg_count=$(find "$output_dir" -name "*.ipk" | wc -l)
    if [ "$pkg_count" -gt 0 ]; then
        log "Package(s) saved to: $output_dir"

        # Copy to Windows-accessible directory (build-ipk at project root)
        local project_ipk_dir="$SCRIPT_DIR/build-ipk/$device/$version"
        mkdir -p "$project_ipk_dir"
        cp "$output_dir"/*.ipk "$project_ipk_dir/" 2>/dev/null
        log "Package(s) copied to: $project_ipk_dir"

        # Archive to app_ipk_archive (at lpac source directory)
        local archive_dir="$SCRIPT_DIR/lpac/app_ipk_archive/$device/$version"
        mkdir -p "$archive_dir"
        cp "$output_dir"/*.ipk "$archive_dir/" 2>/dev/null
        log "Package(s) archived to: $archive_dir"

        # Show Windows path if running on WSL
        if grep -qi microsoft /proc/version 2>/dev/null; then
            local win_path=$(wslpath -w "$project_ipk_dir" 2>/dev/null || echo "")
            [ -n "$win_path" ] && log "Windows path: $win_path"
        fi

        find "$output_dir" -name "*.ipk" -exec basename {} \;
    else
        warn "No packages found for $version"
    fi
}

clean_build() {
    local device=$1
    local build_dir="$BUILD_ROOT/$device"

    if [ -d "$build_dir" ]; then
        log "Cleaning build directory for $device..."
        rm -rf "$build_dir"
        log "Cleaned: $build_dir"
    else
        log "No build directory to clean for $device"
    fi
}

clean_all() {
    if [ -d "$BUILD_ROOT" ]; then
        log "Cleaning all build directories..."
        rm -rf "$BUILD_ROOT"
        log "Cleaned: $BUILD_ROOT"
    else
        log "No build directories to clean"
    fi
}

main() {
    # Start timer
    local start_time=$(date +%s)

    local list_devices_flag=false
    local list_targets_flag=false
    local show_info=false
    local list_versions=false
    local clean=false
    local clean_all_flag=false
    local device=""
    local arch_mode=false
    local target_arch=""
    local versions_to_build=()
    local build_mode=""  # "profile" or "generic"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list-devices)
                list_devices_flag=true
                shift
                ;;
            --list-targets)
                list_targets_flag=true
                shift
                ;;
            -i|--info)
                show_info=true
                device="$2"
                shift 2
                ;;
            -a|--arch)
                arch_mode=true
                target_arch="$2"
                shift 2
                ;;
            -v|--list-versions)
                list_versions=true
                shift
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --clean)
                clean=true
                if [ -n "$2" ] && [[ "$2" != -* ]]; then
                    device="$2"
                    shift
                fi
                shift
                ;;
            --clean-all)
                clean_all_flag=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [ -z "$device" ] && [ "$arch_mode" = false ]; then
                    device="$1"
                else
                    versions_to_build+=("$1")
                fi
                shift
                ;;
        esac
    done

    # Handle special commands
    if [ "$list_devices_flag" = true ]; then
        list_devices
        exit 0
    fi

    if [ "$list_targets_flag" = true ]; then
        list_targets
        exit 0
    fi

    if [ "$clean_all_flag" = true ]; then
        clean_all
        exit 0
    fi

    # Handle clean command early (before profile validation)
    if [ "$clean" = true ]; then
        # For clean, we accept direct build directory names (e.g., ath79-nand)
        # without requiring device profiles or --arch mode
        if [ -n "$device" ]; then
            # Check if it's a valid build directory
            if [ -d "$BUILD_ROOT/$device" ]; then
                clean_build "$device"
                exit 0
            else
                log "No build directory to clean for $device"
                exit 0
            fi
        else
            error "No target specified for clean. Usage: $0 --clean <device-name or arch-name>"
        fi
    fi

    # Determine build mode
    if [ "$arch_mode" = true ]; then
        build_mode="generic"
        if [ -z "$target_arch" ]; then
            error "Architecture not specified with --arch. Example: --arch ath79/generic"
        fi
        load_generic_platform "$target_arch"
        device="$DEVICE_NAME"
    elif [ -n "$device" ]; then
        # Check if it's a device profile
        if [ -f "$PROFILES_DIR/${device}.json" ]; then
            build_mode="profile"
            load_device_profile "$device"
        else
            # Maybe it's a target/subtarget path
            if [[ "$device" == *"/"* ]]; then
                build_mode="generic"
                target_arch="$device"
                load_generic_platform "$target_arch"
                device="$DEVICE_NAME"
            else
                error "Device profile '$device' not found. Use -l to list available profiles or --arch for generic builds."
            fi
        fi
    else
        error "No target specified. Use -h for help, -l to list devices, or --list-targets for platforms."
    fi

    # Handle info command
    if [ "$show_info" = true ]; then
        if [ "$build_mode" = "profile" ]; then
            show_device_info "$device"
        else
            echo "Generic platform: $OPENWRT_TARGET/$OPENWRT_SUBTARGET"
            echo "Build mode: Generic (no optimizations)"
        fi
        exit 0
    fi

    # Handle list versions
    if [ "$list_versions" = true ]; then
        echo "Available OpenWrt versions:"
        if [ "$build_mode" = "profile" ]; then
            printf '%s\n' "${OPENWRT_VERSIONS[@]}"
        else
            echo "  Default: ${OPENWRT_VERSIONS[0]}"
            echo "  Or specify any OpenWrt version as argument"
        fi
        exit 0
    fi

    # Check dependencies
    check_dependencies "$build_mode"
    check_disk_space

    # Determine versions to build
    if [ ${#versions_to_build[@]} -eq 0 ]; then
        versions_to_build=("${OPENWRT_VERSIONS[@]}")
        if [ "$build_mode" = "profile" ]; then
            log "Building all profile versions: ${versions_to_build[*]}"
        else
            log "Building default version: ${versions_to_build[*]}"
        fi
    else
        log "Building specified versions: ${versions_to_build[*]}"
    fi

    # Show build info
    log "Build mode: $build_mode"
    log "Target: $OPENWRT_TARGET/$OPENWRT_SUBTARGET"

    # Build each version
    local success_count=0
    local fail_count=0

    for version in "${versions_to_build[@]}"; do
        # Create output directory
        mkdir -p "$SCRIPT_DIR/build-openwrt/$device/output/$version"

        if build_version "$version" "$device"; then
            ((success_count++))
        else
            ((fail_count++))
            warn "Build failed for version $version"
        fi
    done

    # Calculate elapsed time
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))

    # Format time string
    local time_str=""
    if [ $hours -gt 0 ]; then
        time_str="${hours}h ${minutes}m ${seconds}s"
    elif [ $minutes -gt 0 ]; then
        time_str="${minutes}m ${seconds}s"
    else
        time_str="${seconds}s"
    fi

    # Summary
    echo ""
    log "================================================================"
    log "Build Summary"
    log "================================================================"
    log "Build mode: $build_mode"
    log "Target: $OPENWRT_TARGET/$OPENWRT_SUBTARGET"
    log "Successful builds: $success_count"
    log "Failed builds: $fail_count"
    log "Total build time: $time_str"
    log "Output directory: $SCRIPT_DIR/build-openwrt/$device/output/"
    log "================================================================"
}

# Run main function
main "$@"
