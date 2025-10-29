#!/bin/bash
# Copyright 2025 KilimcininKorOglu
# https://github.com/KilimcininKorOglu/luci-lpac-ui
# Licensed under the MIT License

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

# Self-check: Fix line endings in build.sh itself if needed
# This ensures the script can run even if it has Windows line endings
if command -v dos2unix >/dev/null 2>&1; then
    # dos2unix available - use it
    if file "$0" 2>/dev/null | grep -q "CRLF"; then
        echo -e "${YELLOW}⚠${NC} Build script has Windows line endings, converting..."
        dos2unix "$0" 2>/dev/null
        echo -e "${GREEN}✓${NC} Converted build.sh to Unix line endings"
        echo -e "${BLUE}ℹ${NC} Please re-run the build script"
        exit 0
    fi
else
    # dos2unix not available - use sed
    if grep -q $'\r' "$0" 2>/dev/null; then
        echo -e "${YELLOW}⚠${NC} Build script has Windows line endings, converting..."
        sed -i 's/\r$//' "$0"
        echo -e "${GREEN}✓${NC} Converted build.sh to Unix line endings"
        echo -e "${BLUE}ℹ${NC} Please re-run the build script"
        exit 0
    fi
fi

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

# Generate changelog from recent git commits (excluding version bump commits)
generate_changelog() {
    local changelog_items=""
    local count=0

    # Get last 10 commits, filter out version bumps and chore commits, take first 5
    while IFS= read -r commit_msg; do
        # Skip version bump commits
        if echo "$commit_msg" | grep -q "bump version\|chore:"; then
            continue
        fi

        # Extract the description after emoji and type
        # Format: "🔧 feat(build): description" -> "description"
        local desc=$(echo "$commit_msg" | sed -E 's/^[^ ]+ [^:]+: (.+)$/\1/')

        # Capitalize first letter
        desc="$(echo ${desc:0:1} | tr '[:lower:]' '[:upper:]')${desc:1}"

        changelog_items="${changelog_items}        <li><%:${desc}%></li>\n"
        count=$((count + 1))

        # Stop after 5 items
        if [ $count -ge 5 ]; then
            break
        fi
    done < <(git log --pretty=format:"%s" -10)

    echo -e "$changelog_items"
}

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

    # Update changelog items with recent commits
    CHANGELOG_ITEMS=$(generate_changelog)
    # Replace the changelog items section (between <ul> and </ul>)
    awk -v changelog="$CHANGELOG_ITEMS" '
        /<legend><%:What.*New in v/ {print; in_changelog=1; next}
        in_changelog && /<ul>/ {print; print changelog; skip=1; next}
        in_changelog && /<\/ul>/ {print; in_changelog=0; skip=0; next}
        !skip {print}
    ' "$PROJECT_DIR/luasrc/view/lpac/about.htm" > "$PROJECT_DIR/luasrc/view/lpac/about.htm.tmp"
    mv "$PROJECT_DIR/luasrc/view/lpac/about.htm.tmp" "$PROJECT_DIR/luasrc/view/lpac/about.htm"
fi

if [ $LATEST_BUILD -eq 0 ]; then
    echo -e "${BLUE}Build Number:${NC}  $NEW_BUILD (first build)"
else
    echo -e "${BLUE}Build Number:${NC}  $LATEST_BUILD → ${GREEN}$NEW_BUILD${NC} (auto-incremented)"
fi
echo -e "${BLUE}Makefile:${NC}     Updated PKG_RELEASE=$NEW_BUILD"
echo -e "${BLUE}About page:${NC}   Updated version to $FULL_VERSION"
echo -e "${BLUE}Changelog:${NC}    Auto-generated from recent git commits"

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
Maintainer: $PKG_MAINTAINER
Description: LuCI Support for eSIM Profile Management (LPAC)
 Web interface for managing eSIM profiles on Quectel modems via lpac binary.
 Supports multiple APDU drivers: AT, AT_CSIM, QMI and MBIM.
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

# Clean up old UCI config format (if exists)
# Old format used: lpac.global, lpac.at, lpac.uqmi
# New format uses only: lpac.device
if [ -f /etc/config/lpac ]; then
    # Check if old sections exist and remove them
    uci -q delete lpac.global 2>/dev/null
    uci -q delete lpac.at 2>/dev/null
    uci -q delete lpac.uqmi 2>/dev/null
    uci -q delete lpac.mbim 2>/dev/null
    uci -q delete lpac.qmi 2>/dev/null

    # Ensure device section exists with defaults
    if ! uci -q get lpac.device >/dev/null; then
        uci set lpac.device=settings
        uci set lpac.device.driver='at'
        uci set lpac.device.at_device='/dev/ttyUSB2'
        uci set lpac.device.mbim_device='/dev/cdc-wdm0'
        uci set lpac.device.qmi_device='/dev/cdc-wdm0'
        uci set lpac.device.http_client='curl'
    fi

    uci commit lpac 2>/dev/null
fi

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

# Auto-commit version changes to git
echo ""
echo -e "${YELLOW}[7/7]${NC} Committing version changes to git..."

# Check if we're in a git repository
if git rev-parse --git-dir > /dev/null 2>&1; then
    # Stage the changed files
    git add "$PROJECT_DIR/Makefile" "$PROJECT_DIR/luasrc/view/lpac/about.htm" 2>/dev/null

    # Check if there are changes to commit
    if git diff --cached --quiet; then
        echo -e "  ${BLUE}ℹ${NC} No version changes to commit"
    else
        # Create commit with version bump message
        git commit -m "🔖 chore: bump version to $FULL_VERSION

Auto-generated commit from build script.

Changes:
- Updated PKG_RELEASE to $PKG_RELEASE in Makefile
- Updated version display in about.htm to $FULL_VERSION
- Auto-generated changelog from recent commits"

        if [ $? -eq 0 ]; then
            echo -e "  ${GREEN}✓${NC} Version changes committed successfully"
            echo -e "  ${BLUE}Commit:${NC}       $(git log -1 --pretty=format:'%h - %s')"
        else
            echo -e "  ${RED}✗${NC} Failed to commit version changes"
        fi
    fi
else
    echo -e "  ${BLUE}ℹ${NC} Not a git repository, skipping commit"
fi

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
