#!/bin/bash

# LuCI App LPAC - IPK Package Builder
# Builds standalone IPK package without OpenWrt SDK
# For eSIM profile management on Quectel modems

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

# Package information
PKG_NAME="luci-app-lpac"
PKG_VERSION=$(grep '^PKG_VERSION:=' "$PROJECT_DIR/Makefile" | cut -d'=' -f2)
PKG_ARCH="all"

# Auto-increment build number based on existing IPK files
# Pattern: luci-app-lpac_1.0.1-N_all.ipk -> extract N and increment
BASE_VERSION="$PKG_VERSION"
LATEST_BUILD=0

# Find all existing IPK files and extract highest build number
shopt -s nullglob
for ipk in "$PROJECT_DIR"/${PKG_NAME}_${BASE_VERSION}-*_${PKG_ARCH}.ipk; do
    if [ -f "$ipk" ]; then
        # Extract build number using Perl regex: 1.0.1-N_all.ipk -> N
        BUILD_NUM=$(basename "$ipk" | perl -ne 'print $1 if /'"$PKG_NAME"'_'"${BASE_VERSION//./\\.}"'-(\d+)_'"$PKG_ARCH"'\.ipk/')
        if [ -n "$BUILD_NUM" ] && [ "$BUILD_NUM" -gt "$LATEST_BUILD" ]; then
            LATEST_BUILD=$BUILD_NUM
        fi
    fi
done
shopt -u nullglob

# Increment build number
NEW_BUILD=$((LATEST_BUILD + 1))
PKG_RELEASE="$NEW_BUILD"
FULL_VERSION="${PKG_VERSION}-${PKG_RELEASE}"

# Update Makefile with new build number
sed -i "s/^PKG_RELEASE:=.*/PKG_RELEASE:=$NEW_BUILD/" "$PROJECT_DIR/Makefile"

# Extract package information from Makefile
PKG_LICENSE=$(grep '^PKG_LICENSE:=' "$PROJECT_DIR/Makefile" | cut -d'=' -f2)
PKG_MAINTAINER=$(grep '^PKG_MAINTAINER:=' "$PROJECT_DIR/Makefile" | cut -d'=' -f2)
# Extract developer name from maintainer (e.g., "Name <email>" -> "Name")
DEVELOPER_NAME=$(echo "$PKG_MAINTAINER" | sed 's/<.*//' | sed 's/[[:space:]]*$//')

# Update about.htm with package information from Makefile
if [ -f "$PROJECT_DIR/luasrc/view/lpac/about.htm" ]; then
    # Update version number
    sed -i "s/<td class=\"cbi-value-field\">1\.0\.1-[0-9]*<\/td>/<td class=\"cbi-value-field\">$FULL_VERSION<\/td>/" "$PROJECT_DIR/luasrc/view/lpac/about.htm"

    # Update changelog version
    sed -i "s/<legend><%:What's New in v1\.0\.1-[0-9]*%><\/legend>/<legend><%:What's New in v$FULL_VERSION%><\/legend>/" "$PROJECT_DIR/luasrc/view/lpac/about.htm"

    # Update package name
    sed -i "s/<td class=\"cbi-value-field\">luci-app-lpac<\/td>/<td class=\"cbi-value-field\">$PKG_NAME<\/td>/" "$PROJECT_DIR/luasrc/view/lpac/about.htm"

    # Update license
    sed -i "s/<td class=\"cbi-value-field\">MIT License<\/td>/<td class=\"cbi-value-field\">$PKG_LICENSE<\/td>/" "$PROJECT_DIR/luasrc/view/lpac/about.htm"

    # Update developer name
    sed -i "s/<td class=\"cbi-value-field\">Kilimcinin Kör Oğlu<\/td>/<td class=\"cbi-value-field\">$DEVELOPER_NAME<\/td>/" "$PROJECT_DIR/luasrc/view/lpac/about.htm"
fi

if [ $LATEST_BUILD -eq 0 ]; then
    echo -e "${BLUE}Build Number:${NC}  $NEW_BUILD (first build)"
else
    echo -e "${BLUE}Build Number:${NC}  $LATEST_BUILD → ${GREEN}$NEW_BUILD${NC} (auto-incremented)"
fi
echo -e "${BLUE}Makefile:${NC}     Updated PKG_RELEASE=$NEW_BUILD"
echo -e "${BLUE}About page:${NC}   Updated version to $FULL_VERSION"

# Build date
BUILD_DATE=$(date +%Y%m%d)

# Directories
BUILD_DIR="$PROJECT_DIR/build"
IPK_DIR="$BUILD_DIR/ipk"
CONTROL_DIR="$IPK_DIR/CONTROL"
DATA_DIR="$IPK_DIR/data"

echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   LuCI App LPAC - IPK Package Builder${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Package:${NC}       $PKG_NAME"
echo -e "${BLUE}Version:${NC}       $FULL_VERSION"
echo -e "${BLUE}Architecture:${NC}  $PKG_ARCH"

# Clean previous build
echo -e "${YELLOW}[1/6]${NC} Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$CONTROL_DIR" "$DATA_DIR"

# Create directory structure
echo -e "${YELLOW}[2/6]${NC} Creating directory structure..."
mkdir -p "$DATA_DIR/usr/lib/lua/luci/controller"
mkdir -p "$DATA_DIR/usr/lib/lua/luci/view/lpac"
mkdir -p "$DATA_DIR/usr/bin"
mkdir -p "$DATA_DIR/etc/config"

# Copy LuCI files
echo -e "${YELLOW}[3/6]${NC} Copying LuCI files..."
echo "  → Controller (lpac.lua)"
cp "$PROJECT_DIR/luasrc/controller/lpac.lua" "$DATA_DIR/usr/lib/lua/luci/controller/"

echo "  → Template views (profiles.htm, about.htm)"
cp "$PROJECT_DIR/luasrc/view/lpac/profiles.htm" "$DATA_DIR/usr/lib/lua/luci/view/lpac/"
cp "$PROJECT_DIR/luasrc/view/lpac/about.htm" "$DATA_DIR/usr/lib/lua/luci/view/lpac/"

echo "  → Wrapper script (lpac_json)"
cp "$PROJECT_DIR/root/usr/bin/lpac_json" "$DATA_DIR/usr/bin/"
chmod 755 "$DATA_DIR/usr/bin/lpac_json"

# UCI config is now provided by lpac package, not luci-app-lpac
# echo "  → UCI configuration (lpac)"
# cp "$PROJECT_DIR/root/etc/config/lpac" "$DATA_DIR/etc/config/"

# Copy additional root files if they exist
if [ -d "$PROJECT_DIR/root" ]; then
    echo "  → Additional root files"
    # Copy everything except usr/bin/quectel_lpad_json (already copied)
    find "$PROJECT_DIR/root" -mindepth 1 -maxdepth 1 ! -name usr -exec cp -r {} "$DATA_DIR/" \; 2>/dev/null || true
    if [ -d "$PROJECT_DIR/root/usr" ]; then
        find "$PROJECT_DIR/root/usr" -mindepth 1 -maxdepth 1 ! -name bin -exec cp -r {} "$DATA_DIR/usr/" \; 2>/dev/null || true
    fi
fi

# Verify all files have Unix line endings
echo -e "${YELLOW}[4/6]${NC} Verifying file formats..."
find "$DATA_DIR" -type f \( -name "*.lua" -o -name "*.htm" -o -name "*.sh" \) | while read file; do
    if file "$file" | grep -q CRLF; then
        echo -e "  ${RED}✗${NC} Converting: $file (had Windows line endings)"
        sed -i 's/\r$//' "$file"
    fi
done
echo -e "  ${GREEN}✓${NC} All text files have Unix line endings"

# Create control file
echo -e "${YELLOW}[5/6]${NC} Creating package metadata..."
cat > "$CONTROL_DIR/control" << EOF
Package: $PKG_NAME
Version: $FULL_VERSION
Depends: luci-base, luci-compat
Section: luci
Architecture: $PKG_ARCH
Installed-Size: $(du -sb "$DATA_DIR" | cut -f1)
Maintainer: Kerem <kerem@example.com>
Description: LuCI Support for eSIM Profile Management (LPAC)
 Web interface for managing eSIM profiles on Quectel modems via lpac binary.
 Supports multiple APDU drivers: AT, AT_CSIM, and MBIM.
 Provides ICCID-based profile management: add, delete, enable, disable, list.
 Requires lpac binary and curl/wget for HTTP communication.
 Classic LuCI template-based architecture.
EOF

echo "  → Control file created"

# Create postinst script (optional - for clearing LuCI cache)
cat > "$CONTROL_DIR/postinst" << 'EOF'
#!/bin/sh
# Clear LuCI cache after installation
[ -d /tmp/luci-modulecache ] && rm -rf /tmp/luci-modulecache/* 2>/dev/null
[ -d /tmp/luci-indexcache ] && rm -rf /tmp/luci-indexcache/* 2>/dev/null
exit 0
EOF
chmod 755 "$CONTROL_DIR/postinst"
echo "  → Post-install script created"

# Create prerm script (optional - for cleanup before removal)
cat > "$CONTROL_DIR/prerm" << 'EOF'
#!/bin/sh
# Cleanup before removal
exit 0
EOF
chmod 755 "$CONTROL_DIR/prerm"
echo "  → Pre-removal script created"

# Build IPK package
echo -e "${YELLOW}[6/6]${NC} Building IPK package..."

cd "$IPK_DIR"

# Create debian-binary
echo "2.0" > debian-binary

# Create control.tar.gz
# Important: Must be created from CONTROL directory, not including CONTROL itself
# Order: debian-binary, control.tar.gz, data.tar.gz (CRITICAL!)
tar -C CONTROL -czf control.tar.gz --owner=0 --group=0 --numeric-owner .

# Verify control.tar.gz was created
if [ ! -f control.tar.gz ]; then
    echo -e "${RED}ERROR: Failed to create control.tar.gz${NC}"
    exit 1
fi

# Create data.tar.gz
# Important: Must be created from data directory, not including data itself
tar -C data -czf data.tar.gz --owner=0 --group=0 --numeric-owner .

# Verify data.tar.gz was created
if [ ! -f data.tar.gz ]; then
    echo -e "${RED}ERROR: Failed to create data.tar.gz${NC}"
    exit 1
fi

# Create IPK (tar.gz archive, NOT ar!)
IPK_FILE="$PROJECT_DIR/${PKG_NAME}_${FULL_VERSION}_${PKG_ARCH}.ipk"

# Remove old IPK if exists
rm -f "$IPK_FILE"

# Create IPK using tar (like the working example)
# CRITICAL: Order must be: debian-binary, control.tar.gz, data.tar.gz
tar -czf "$IPK_FILE" debian-binary control.tar.gz data.tar.gz

# Verify IPK was created properly
if [ ! -f "$IPK_FILE" ]; then
    echo -e "${RED}ERROR: Failed to create IPK package${NC}"
    exit 1
fi

# Verify IPK structure
echo -e "${BLUE}Verifying IPK structure...${NC}"
IPK_CONTENTS=$(tar -tzf "$IPK_FILE" 2>/dev/null | head -3)
EXPECTED_ORDER="debian-binary
control.tar.gz
data.tar.gz"

if [ "$IPK_CONTENTS" != "$EXPECTED_ORDER" ]; then
    echo -e "${RED}ERROR: IPK has incorrect structure!${NC}"
    echo -e "${RED}Expected:${NC}"
    echo "$EXPECTED_ORDER"
    echo -e "${RED}Got:${NC}"
    echo "$IPK_CONTENTS"
    exit 1
fi

echo -e "${GREEN}✓${NC} IPK structure verified (correct order)"

# Cleanup build directory
cd "$PROJECT_DIR"
rm -rf "$BUILD_DIR"

# Display results
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   BUILD SUCCESSFUL!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Package Details:${NC}"
echo -e "  Name:         ${PKG_NAME}_${FULL_VERSION}_${PKG_ARCH}.ipk"
echo -e "  Size:         $(du -h "$IPK_FILE" | cut -f1)"
echo -e "  Location:     $IPK_FILE"
echo ""
echo -e "${BLUE}Contents:${NC}"
echo -e "  ✓ Controller:  /usr/lib/lua/luci/controller/lpac.lua"
echo -e "  ✓ View:        /usr/lib/lua/luci/view/lpac/profiles.htm"
echo -e "  ✓ Wrapper:     /usr/bin/lpac_json"
echo -e "  ✓ UCI Config:  /etc/config/lpac"
echo ""
echo -e "${BLUE}Installation:${NC}"
echo -e "  opkg install $IPK_FILE"
echo ""
echo -e "${BLUE}Web Access:${NC}"
echo -e "  http://router-ip/cgi-bin/luci/admin/network/lpac"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
