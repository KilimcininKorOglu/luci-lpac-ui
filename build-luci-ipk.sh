#!/bin/bash

# IMEI Changer LuCI IPK Builder Script
# Builds complete IPK package from luci-imeichanger source

set -e

# Get script directory dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# Get version from core module (dynamic path)
CORE_MODULE="$PROJECT_DIR/auto-imei-changer/modules/core.sh"

# Verify core module exists
if [ ! -f "$CORE_MODULE" ]; then
    echo "❌ Error: Core module not found at: $CORE_MODULE"
    echo "💡 Expected structure: [project]/auto-imei-changer/modules/core.sh"
    exit 1
fi

BASE_VERSION=$(grep '^VERSION=' "$CORE_MODULE" | cut -d'"' -f2)

# Verify version was found
if [ -z "$BASE_VERSION" ]; then
    echo "❌ Error: Could not extract version from core module"
    echo "📍 Core module: $CORE_MODULE"
    exit 1
fi

# Generate dynamic date and build number
CURRENT_DATE=$(date +%Y%m%d)
SOURCE_DIR="$PROJECT_DIR/luci-imeichanger"
BUILD_DIR="$PROJECT_DIR/build-luci-ipk"

# Check for existing builds today and increment build number
BUILD_NUMBER=1
ARCHIVE_DIR="$PROJECT_DIR/ipk_archive/$BASE_VERSION"
while [ -f "$ARCHIVE_DIR/luci-app-auto-imei-changer_${BASE_VERSION}-${CURRENT_DATE}-${BUILD_NUMBER}_all.ipk" ]; do
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
done

VERSION="${BASE_VERSION}-${CURRENT_DATE}-${BUILD_NUMBER}"

echo "=== IMEI Changer LuCI IPK Builder ==="
echo "Base Version: $BASE_VERSION"
echo "Build Date: $CURRENT_DATE"
echo "Build Number: $BUILD_NUMBER"
echo "Full Version: $VERSION"
echo "Source: $SOURCE_DIR"
echo "Build:  $BUILD_DIR"
echo

# Clean and create build directory
echo "🧹 Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Create debian-binary
echo "📦 Creating debian-binary..."
echo "2.0" >"$BUILD_DIR/debian-binary"

# Create control directory and files
echo "📋 Creating control files..."
mkdir -p "$BUILD_DIR/control"

# Control file
cat >"$BUILD_DIR/control/control" <<EOF
Package: luci-app-auto-imei-changer
Version: $VERSION
Depends: luci-base, luci-lib-json, luci-lib-jsonc, auto-imei-changer (>= $BASE_VERSION)
Section: luci
Architecture: all
Installed-Size: 125760
Maintainer: Hermes The Cat <k@keremgok.tr>
Description: LuCI Web Interface for OpenWrt IMEI Changer v$BASE_VERSION
 Professional web interface for OpenWrt IMEI Changer with complete JSON API
 integration, streamlined IMEI management, and modern responsive design. 
 Features 18 core commands with structured JSON responses, enhanced UX with 
 Use/Update/Delete buttons.
EOF

# Post-install script
cat >"$BUILD_DIR/control/postinst" <<'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh

# Ensure correct script permissions
chmod +x /usr/sbin/imei-changer 2>/dev/null
chmod +x /etc/auto-imei-changer/imei.sh 2>/dev/null

# Create required directories
mkdir -p /etc/auto-imei-changer
mkdir -p /var/log

# Clear LuCI cache
rm -rf /tmp/luci-*

# Restart services
/etc/init.d/rpcd restart 2>/dev/null || true
/etc/init.d/uhttpd restart 2>/dev/null || true

echo "IMEI Changer LuCI UI with UCI Configuration installed successfully!"
echo "Access via: Network -> IMEI Manager (Dashboard)"
echo "Configure via: Network -> IMEI Configuration (Settings & Webhook)"
default_postinst $0 $@
EOF

# Pre-removal script
cat >"$BUILD_DIR/control/prerm" <<'EOF'
#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh

echo "IMEI Changer LuCI interface removed."

default_prerm $0 $@
EOF

# Make scripts executable
chmod +x "$BUILD_DIR/control/postinst"
chmod +x "$BUILD_DIR/control/prerm"

# Create data directory structure
echo "📁 Creating data structure..."
mkdir -p "$BUILD_DIR/data/usr/lib/lua/luci/controller/network"
mkdir -p "$BUILD_DIR/data/usr/lib/lua/luci/view/network"
mkdir -p "$BUILD_DIR/data/usr/share/rpcd/acl.d"

# Copy LuCI files
echo "📄 Copying LuCI files..."

# Controllers
echo "  → Controllers"
cp "$SOURCE_DIR/luasrc/controller/network/imei.lua" \
    "$BUILD_DIR/data/usr/lib/lua/luci/controller/network/"
if [ -f "$SOURCE_DIR/luasrc/controller/network/imei_config.lua" ]; then
    cp "$SOURCE_DIR/luasrc/controller/network/imei_config.lua" \
       "$BUILD_DIR/data/usr/lib/lua/luci/controller/network/"
fi

# Views (with automatic line ending conversion)
echo "  → Views (*.htm)"
cp "$SOURCE_DIR/luasrc/view/network"/*.htm \
    "$BUILD_DIR/data/usr/lib/lua/luci/view/network/"

# Additional view templates for settings/help
if [ -d "$SOURCE_DIR/luasrc/view/auto-imei-changer" ]; then
    mkdir -p "$BUILD_DIR/data/usr/lib/lua/luci/view/auto-imei-changer"
    cp "$SOURCE_DIR/luasrc/view/auto-imei-changer"/*.htm \
       "$BUILD_DIR/data/usr/lib/lua/luci/view/auto-imei-changer/" 2>/dev/null || true
fi

# Convert line endings for template files (Unix format required for LuCI)
echo "  → Converting line endings (dos2unix)"
if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "$BUILD_DIR/data/usr/lib/lua/luci/view/network"/*.htm 2>/dev/null || true
    dos2unix "$BUILD_DIR/data/usr/lib/lua/luci/view/auto-imei-changer"/*.htm 2>/dev/null || true
    dos2unix "$BUILD_DIR/data/usr/lib/lua/luci/controller/network/imei.lua" 2>/dev/null || true
    dos2unix "$BUILD_DIR/data/usr/lib/lua/luci/controller/network/imei_config.lua" 2>/dev/null || true
    dos2unix "$PROJECT_DIR/auto-imei-changer/imei.sh" 2>/dev/null || true
    dos2unix "$PROJECT_DIR/auto-imei-changer/modules"/*.sh 2>/dev/null || true
else
    echo "  ⚠️  Warning: dos2unix not found, skipping line ending conversion"
fi

# ACL permissions
echo "  → ACL permissions"
cp "$SOURCE_DIR/root/usr/share/rpcd/acl.d/luci-app-imeichanger.json" \
    "$BUILD_DIR/data/usr/share/rpcd/acl.d/"

# CBI models
echo "  → CBI models"
mkdir -p "$BUILD_DIR/data/usr/lib/lua/luci/model/cbi/auto-imei-changer"
cp "$SOURCE_DIR/luasrc/model/cbi/auto-imei-changer"/*.lua \
   "$BUILD_DIR/data/usr/lib/lua/luci/model/cbi/auto-imei-changer/"

# Create archives
echo "🗜️  Creating tar archives..."
cd "$BUILD_DIR"

# Create control.tar.gz
tar czf control.tar.gz -C control .

# Create data.tar.gz
tar czf data.tar.gz -C data .

# Create final IPK
echo "📦 Creating IPK package..."
IPK_NAME="luci-app-auto-imei-changer_${VERSION}_all.ipk"
tar -czf "$IPK_NAME" debian-binary control.tar.gz data.tar.gz

# Create organized archive directory structure (already defined above)
echo "📁 Creating archive directory: ipk_archive/$BASE_VERSION"
mkdir -p "$ARCHIVE_DIR"

# Move IPK to organized archive directory
mv "$IPK_NAME" "$ARCHIVE_DIR/"

# Create latest copy in main archive folder
cp "$ARCHIVE_DIR/$IPK_NAME" "$PROJECT_DIR/ipk_archive/luci-app-auto-imei-changer_latest.ipk"

# List existing IPK files in this version
echo "📦 IPK files for version $BASE_VERSION:"
ls -la "$ARCHIVE_DIR"/*.ipk 2>/dev/null || echo "  This is the first build for version $BASE_VERSION"

# Show archive structure
echo ""
echo "📂 Archive Structure:"
echo "  ipk_archive/"
echo "  ├── $BASE_VERSION/ (current)"
if [ -d "$PROJECT_DIR/ipk_archive" ]; then
    for dir in "$PROJECT_DIR/ipk_archive"/*/; do
        if [ -d "$dir" ] && [ "$(basename "$dir")" != "$BASE_VERSION" ]; then
            echo "  ├── $(basename "$dir")/"
        fi
    done
fi

# Cleanup intermediate files (keep IPK files)
cd "$PROJECT_DIR"
rm -rf "$BUILD_DIR"

echo
echo "✅ OpenWrt IMEI Changer IPK package created successfully!"
echo "📍 Location: $ARCHIVE_DIR/$IPK_NAME"
echo "📏 Size: $(du -h "$ARCHIVE_DIR/$IPK_NAME" | cut -f1)"
echo "📦 Latest copy: ipk_archive/luci-app-auto-imei-changer_latest.ipk"
echo
echo "🚀 Install with: opkg install ipk_archive/$BASE_VERSION/$IPK_NAME"
echo "📱 Access via: Network → IMEI Manager"
echo