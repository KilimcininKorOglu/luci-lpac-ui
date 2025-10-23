#!/bin/bash

# lpac LuCI IPK Builder Script
# Builds complete IPK package from luci-app-lpac source
# Modern LuCI (HTTP API) architecture - No RPCD/ACL required

set -e

# Get script directory dynamically
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# Get version from Makefile
MAKEFILE="$PROJECT_DIR/luci-app-lpac/Makefile"

# Verify Makefile exists
if [ ! -f "$MAKEFILE" ]; then
    echo "❌ Error: Makefile not found at: $MAKEFILE"
    echo "💡 Expected structure: [project]/luci-app-lpac/Makefile"
    exit 1
fi

BASE_VERSION=$(grep '^PKG_VERSION:=' "$MAKEFILE" | cut -d'=' -f2)

# Verify version was found
if [ -z "$BASE_VERSION" ]; then
    echo "❌ Error: Could not extract version from Makefile"
    echo "📍 Makefile: $MAKEFILE"
    exit 1
fi

# Generate dynamic date and build number
CURRENT_DATE=$(date +%Y%m%d)
SOURCE_DIR="$PROJECT_DIR/luci-app-lpac"
BUILD_DIR="$PROJECT_DIR/build-luci-ipk"

# Check for existing builds today and increment build number
BUILD_NUMBER=1
ARCHIVE_DIR="$PROJECT_DIR/ipk_archive/$BASE_VERSION"
while [ -f "$ARCHIVE_DIR/luci-app-lpac_${BASE_VERSION}-${CURRENT_DATE}-${BUILD_NUMBER}_all.ipk" ]; do
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
done

VERSION="${BASE_VERSION}-${CURRENT_DATE}-${BUILD_NUMBER}"

echo "=== lpac LuCI IPK Builder ==="
echo "Base Version: $BASE_VERSION"
echo "Build Date: $CURRENT_DATE"
echo "Build Number: $BUILD_NUMBER"
echo "Full Version: $VERSION"
echo "Source: $SOURCE_DIR"
echo "Build:  $BUILD_DIR"
echo

# Count source files dynamically
echo "🔍 Counting source files..."

# Count API endpoints in controller
CONTROLLER_FILE="$SOURCE_DIR/luasrc/controller/lpac.lua"
if [ -f "$CONTROLLER_FILE" ]; then
    ENDPOINT_COUNT=$(grep -c '^\s*entry(' "$CONTROLLER_FILE" 2>/dev/null || echo "0")
else
    ENDPOINT_COUNT=0
fi

# Count model modules
MODEL_COUNT=$(find "$SOURCE_DIR/luasrc/model/lpac" -name "*.lua" 2>/dev/null | wc -l)

# Count JavaScript views
VIEW_COUNT=$(find "$SOURCE_DIR/htdocs/luci-static/resources/view/lpac" -name "*.js" 2>/dev/null | wc -l)

# Count CSS files
CSS_COUNT=$(find "$SOURCE_DIR/htdocs/luci-static/resources" -maxdepth 1 -name "*.css" 2>/dev/null | wc -l)

echo "  📊 Found: $ENDPOINT_COUNT endpoints, $MODEL_COUNT models, $VIEW_COUNT views, $CSS_COUNT CSS"
echo

# Verify source files exist
echo "🔍 Verifying source files..."
MISSING_FILES=0

# Check controller
if [ ! -f "$CONTROLLER_FILE" ]; then
    echo "  ❌ Missing: luasrc/controller/lpac.lua"
    MISSING_FILES=$((MISSING_FILES + 1))
else
    echo "  ✅ Controller found ($ENDPOINT_COUNT API endpoints)"
fi

# Check model files
if [ $MODEL_COUNT -eq 0 ]; then
    echo "  ❌ Missing: Model files in luasrc/model/lpac/"
    MISSING_FILES=$((MISSING_FILES + 1))
else
    echo "  ✅ Model files found ($MODEL_COUNT modules)"
fi

# Check views
if [ $VIEW_COUNT -eq 0 ]; then
    echo "  ❌ Missing: View files in htdocs/luci-static/resources/view/lpac/"
    MISSING_FILES=$((MISSING_FILES + 1))
else
    echo "  ✅ View files found ($VIEW_COUNT views)"
fi

# Check CSS
if [ $CSS_COUNT -eq 0 ]; then
    echo "  ❌ Missing: CSS files in htdocs/luci-static/resources/"
    MISSING_FILES=$((MISSING_FILES + 1))
else
    echo "  ✅ CSS files found ($CSS_COUNT files)"
fi

# Note: UCI config file is provided by lpac package, not this package

# Check uci-defaults
if [ ! -f "$SOURCE_DIR/root/etc/uci-defaults/90-luci-lpac" ]; then
    echo "  ❌ Missing: root/etc/uci-defaults/90-luci-lpac"
    MISSING_FILES=$((MISSING_FILES + 1))
else
    echo "  ✅ UCI defaults found"
fi

if [ $MISSING_FILES -gt 0 ]; then
    echo ""
    echo "❌ Build aborted: $MISSING_FILES required file(s) missing"
    exit 1
fi

echo "  ✅ All source files verified"
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

# Control file - Modern LuCI dependencies (NO rpcd)
cat >"$BUILD_DIR/control/control" <<EOF
Package: luci-app-lpac
Version: $VERSION
Depends: luci-base, lpac, luci-lib-jsonc
Section: luci
Architecture: all
Installed-Size: 130048
Maintainer:  kilimcinin kör oğlu <koroglan@hermestech.uk>
Description: LuCI Web Interface for lpac eSIM Management v$BASE_VERSION
 Modern web interface for lpac eSIM profile management with HTTP API
 integration and responsive design. Supports OpenWrt 23.05+ with Modern
 LuCI framework.
 .
 Features:
  - Dashboard with system overview
  - eUICC chip information display
  - Profile management (list, enable, disable, delete, rename)
  - Profile download (activation code or manual entry)
  - Notification management
  - Configuration settings
  - HTTP API with $ENDPOINT_COUNT endpoints
  - No RPCD/ACL required (Modern LuCI HTTP API)
EOF

# Post-install script - Optimized for Modern LuCI
cat >"$BUILD_DIR/control/postinst" <<'EOF'
#!/bin/sh
[ "${IPKG_NO_SCRIPT}" = "1" ] && exit 0
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh

# Ensure lpac binary is executable
if [ -f /usr/bin/lpac ]; then
    chmod +x /usr/bin/lpac 2>/dev/null || true
    echo "✓ lpac binary found and executable"
else
    echo "⚠ Warning: lpac binary not found at /usr/bin/lpac"
    echo "  Install lpac package for full functionality"
fi

# Clear LuCI cache
rm -rf /tmp/luci-* 2>/dev/null || true

# Restart web server to load new LuCI modules
/etc/init.d/uhttpd restart 2>/dev/null || true

echo ""
echo "✅ luci-app-lpac installed successfully!"
echo ""
echo "Access via: Network → eSIM Management"
echo ""
echo "Available pages:"
echo "  • Dashboard - System overview"
echo "  • Chip Info - eUICC hardware details"
echo "  • Profiles - Manage eSIM profiles"
echo "  • Download - Download new profiles"
echo "  • Notifications - Process pending notifications"
echo "  • Settings - Configuration and advanced operations"
echo "  • About - System information"
echo ""

default_postinst $0 $@
EOF

# Pre-removal script
cat >"$BUILD_DIR/control/prerm" <<'EOF'
#!/bin/sh
[ -s ${IPKG_INSTROOT}/lib/functions.sh ] || exit 0
. ${IPKG_INSTROOT}/lib/functions.sh

echo "lpac LuCI interface removed."

# Clear LuCI cache
rm -rf /tmp/luci-* 2>/dev/null || true

default_prerm $0 $@
EOF

# Make scripts executable
chmod +x "$BUILD_DIR/control/postinst"
chmod +x "$BUILD_DIR/control/prerm"

# Create data directory structure (Modern LuCI paths)
echo "📁 Creating data structure..."
mkdir -p "$BUILD_DIR/data/usr/lib/lua/luci/controller"
mkdir -p "$BUILD_DIR/data/usr/lib/lua/luci/model/lpac"
mkdir -p "$BUILD_DIR/data/www/luci-static/resources/view/lpac"
mkdir -p "$BUILD_DIR/data/www/luci-static/resources"
mkdir -p "$BUILD_DIR/data/etc/uci-defaults"

# Copy LuCI files
echo "📄 Copying LuCI files..."

# Controller (HTTP API)
echo "  → Controller (HTTP API - $ENDPOINT_COUNT endpoints)"
cp "$SOURCE_DIR/luasrc/controller/lpac.lua" \
    "$BUILD_DIR/data/usr/lib/lua/luci/controller/"

# Model layer (Business logic)
echo "  → Model layer ($MODEL_COUNT modules)"
cp "$SOURCE_DIR/luasrc/model/lpac"/*.lua \
    "$BUILD_DIR/data/usr/lib/lua/luci/model/lpac/"

# JavaScript views (Modern LuCI)
echo "  → JavaScript views ($VIEW_COUNT files)"
cp "$SOURCE_DIR/htdocs/luci-static/resources/view/lpac"/*.js \
    "$BUILD_DIR/data/www/luci-static/resources/view/lpac/"

# CSS styling
echo "  → Custom CSS ($CSS_COUNT files)"
cp "$SOURCE_DIR/htdocs/luci-static/resources/"*.css \
    "$BUILD_DIR/data/www/luci-static/resources/"

# Note: UCI config file is provided by lpac package, not copied here

# UCI defaults (post-install automation)
echo "  → UCI defaults"
cp "$SOURCE_DIR/root/etc/uci-defaults/90-luci-lpac" \
    "$BUILD_DIR/data/etc/uci-defaults/"

# Set correct permissions
chmod 755 "$BUILD_DIR/data/etc/uci-defaults/90-luci-lpac"

# Create archives
echo "🗜️  Creating tar archives..."
cd "$BUILD_DIR"

# Create control.tar.gz
tar czf control.tar.gz -C control .

# Create data.tar.gz
tar czf data.tar.gz -C data .

# Create final IPK
echo "📦 Creating IPK package..."
IPK_NAME="luci-app-lpac_${VERSION}_all.ipk"
tar -czf "$IPK_NAME" debian-binary control.tar.gz data.tar.gz

# Create organized archive directory structure
echo "📁 Creating archive directory: ipk_archive/$BASE_VERSION"
mkdir -p "$ARCHIVE_DIR"

# Move IPK to organized archive directory
mv "$IPK_NAME" "$ARCHIVE_DIR/"

# Create latest copy in main archive folder
mkdir -p "$PROJECT_DIR/ipk_archive"
cp "$ARCHIVE_DIR/$IPK_NAME" "$PROJECT_DIR/ipk_archive/luci-app-lpac_latest.ipk"

# List existing IPK files in this version
echo ""
echo "📦 IPK files for version $BASE_VERSION:"
ls -lh "$ARCHIVE_DIR"/*.ipk 2>/dev/null || echo "  This is the first build for version $BASE_VERSION"

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
echo "  └── luci-app-lpac_latest.ipk (symlink)"

# Cleanup intermediate files (keep IPK files)
cd "$PROJECT_DIR"
rm -rf "$BUILD_DIR"

echo ""
echo "✅ luci-app-lpac IPK package created successfully!"
echo "📍 Location: $ARCHIVE_DIR/$IPK_NAME"
echo "📏 Size: $(du -h "$ARCHIVE_DIR/$IPK_NAME" | cut -f1)"
echo "📦 Latest copy: ipk_archive/luci-app-lpac_latest.ipk"
echo ""
echo "🔧 Architecture: Modern LuCI (HTTP API, No RPCD)"
echo "📋 Contents:"
echo "   • 1 Controller (HTTP API with $ENDPOINT_COUNT endpoints)"
echo "   • $MODEL_COUNT Model modules"
echo "   • $VIEW_COUNT JavaScript views (Modern LuCI)"
echo "   • $CSS_COUNT CSS files (custom styling)"
echo "   • UCI defaults script (config provided by lpac package)"
echo ""
echo "🚀 Install with:"
echo "   opkg update"
echo "   opkg install lpac  # Install dependency first"
echo "   opkg install $ARCHIVE_DIR/$IPK_NAME"
echo ""
echo "📱 Access via: Network → eSIM Management"
echo ""
