# OpenWrt OPKG & IPK Package Format Guide

**Source:** <https://eko.one.pl/?p=openwrt-opkg>

---

## Overview

OPKG (Open PacKaGe management) is the package manager for OpenWrt. It uses IPK (Itsy Package) format files, which are essentially ar archives containing package data and metadata.

**Important Notice:** Manual IPK creation is **not the recommended method** for OpenWrt packages. The normal SDK should be used for production packages. However, understanding the manual process is valuable for debugging and quick prototyping.

---

## IPK Package Structure

An IPK file is an **ar archive** containing exactly three components in this order:

```bash
packagename_version.ipk
├── debian-binary         # Format version (plain text file)
├── control.tar.gz        # Package metadata and scripts
└── data.tar.gz           # Actual files to be installed
```

### 1. debian-binary

**Content:** Plain text file containing the string "2.0" followed by a newline.

**Purpose:** Specifies the IPK format version.

**Example:**

```bash
echo "2.0" > debian-binary
```

### 2. data.tar.gz

**Content:** Compressed tar archive containing all files to be installed.

**Structure:** Files are organized relative to the root filesystem (`/`).

**Example structure:**

```bash
data/
├── usr/
│   ├── bin/
│   │   └── myprogram
│   └── lib/
│       └── mylib.so
└── etc/
    └── config/
        └── myconfig
```

**Creation:**

```bash
# From within build directory
tar -C data -czf data.tar.gz --owner=0 --group=0 .
```

**Key points:**

- Use `--owner=0 --group=0` to ensure root ownership
- Use `-C data` to change directory before archiving
- Use `.` to include all contents without the parent directory name

### 3. control.tar.gz

**Content:** Compressed tar archive containing package metadata and installation scripts.

**Required files:**

- `control` - Package metadata (REQUIRED)
- `postinst` - Post-installation script (OPTIONAL)
- `prerm` - Pre-removal script (OPTIONAL)
- `postrm` - Post-removal script (OPTIONAL)
- `preinst` - Pre-installation script (OPTIONAL)

**Example structure:**

```bash
CONTROL/
├── control
├── postinst
└── prerm
```

**Creation:**

```bash
tar -C CONTROL -czf control.tar.gz --owner=0 --group=0 .
```

---

## Control File Format

The `control` file contains package metadata in a specific format:

### Required Fields

```bash
Package: package-name
Version: 1.0.0-1
Depends: dependency1, dependency2
Section: category
Architecture: all|mips|arm|...
Installed-Size: bytes
Maintainer: Name <email@example.com>
Description: Short description
 Long description line 1
 Long description line 2
```

### Field Descriptions

| Field | Description | Example |
|-------|-------------|---------|
| **Package** | Package name (lowercase, no spaces) | `luci-app-lpac` |
| **Version** | Version in format: MAJOR.MINOR.PATCH-RELEASE | `1.0.1-7` |
| **Depends** | Comma-separated list of dependencies | `luci-base, luci-compat` |
| **Section** | Package category | `luci`, `net`, `utils`, `admin` |
| **Architecture** | Target architecture | `all`, `mips_24kc`, `arm_cortex-a9` |
| **Installed-Size** | Size in bytes after installation | `19389` |
| **Maintainer** | Package maintainer info | `John Doe <john@example.com>` |
| **Description** | Short description on first line, long description indented with space | See example above |

### Optional Fields

- **Source**: Source package name
- **License**: Package license (e.g., `MIT`, `GPL-2.0`)
- **Priority**: Installation priority (`required`, `important`, `standard`, `optional`)
- **Essential**: Whether package is essential (`yes`/`no`)

### Example control file

```bash
Package: luci-app-lpac
Version: 1.0.1-7
Depends: luci-base, luci-compat
Section: luci
Architecture: all
Installed-Size: 19389
Maintainer: Kerem <kerem@example.com>
Description: LuCI Support for eSIM Profile Management (LPAC)
 Web interface for managing eSIM profiles on Quectel modems.
 Provides add, delete, and status operations for eSIM profiles.
 Classic LuCI template-based architecture.
```

---

## Installation Scripts

### postinst (Post-installation)

**Purpose:** Execute commands after package installation.

**Example:**

```bash
#!/bin/sh
# Clear LuCI cache after installation
[ -d /tmp/luci-modulecache ] && rm -rf /tmp/luci-modulecache/* 2>/dev/null
[ -d /tmp/luci-indexcache ] && rm -rf /tmp/luci-indexcache/* 2>/dev/null

# Restart relevant services
/etc/init.d/uhttpd restart

exit 0
```

**Key points:**

- Must be executable (`chmod 755`)
- Must have shebang (`#!/bin/sh`)
- Must exit with code 0 on success
- Should be idempotent (safe to run multiple times)

### prerm (Pre-removal)

**Purpose:** Execute commands before package removal.

**Example:**

```bash
#!/bin/sh
# Stop services before removal
/etc/init.d/myservice stop

# Backup configuration
[ -f /etc/config/myconfig ] && cp /etc/config/myconfig /tmp/myconfig.backup

exit 0
```

### Standard OpenWrt Script Functions

Installation scripts can use these standard functions:

```bash
#!/bin/sh
[ "${IPKG_INSTROOT}" = "" ] || exit 0  # Only run on device, not during image build

# Enable and start service
/etc/init.d/myservice enable
/etc/init.d/myservice start

exit 0
```

---

## Package Creation Process

### Step-by-Step Manual Process

#### 1. Prepare Directory Structure

```bash
mkdir -p build/ipk/data
mkdir -p build/ipk/CONTROL
```

#### 2. Copy Files to data/

```bash
# Example: Install a binary and config file
mkdir -p build/ipk/data/usr/bin
mkdir -p build/ipk/data/etc/config

cp myprogram build/ipk/data/usr/bin/
chmod 755 build/ipk/data/usr/bin/myprogram

cp myconfig build/ipk/data/etc/config/
```

#### 3. Create control File

```bash
cat > build/ipk/CONTROL/control << EOF
Package: mypackage
Version: 1.0.0-1
Depends: libc
Section: utils
Architecture: all
Installed-Size: $(du -sb build/ipk/data | cut -f1)
Maintainer: Your Name <you@example.com>
Description: My custom package
 Longer description here
EOF
```

#### 4. Create postinst Script (Optional)

```bash
cat > build/ipk/CONTROL/postinst << 'EOF'
#!/bin/sh
echo "Package installed successfully"
exit 0
EOF
chmod 755 build/ipk/CONTROL/postinst
```

#### 5. Create prerm Script (Optional)

```bash
cat > build/ipk/CONTROL/prerm << 'EOF'
#!/bin/sh
echo "Removing package"
exit 0
EOF
chmod 755 build/ipk/CONTROL/prerm
```

#### 6. Build Archives

```bash
cd build/ipk

# Create debian-binary
echo "2.0" > debian-binary

# Create control.tar.gz
tar -C CONTROL -czf control.tar.gz --owner=0 --group=0 .

# Create data.tar.gz
tar -C data -czf data.tar.gz --owner=0 --group=0 .
```

#### 7. Create IPK Package

```bash
# Create final IPK using ar
ar q mypackage_1.0.0-1_all.ipk debian-binary control.tar.gz data.tar.gz
```

**Important:** The order matters! `debian-binary` must come first, followed by `control.tar.gz`, then `data.tar.gz`.

---

## Package Naming Convention

**Format:** `packagename_version_architecture.ipk`

**Examples:**

- `luci-app-lpac_1.0.1-7_all.ipk`
- `kmod-usb-net-qmi-wwan_5.4.188-1_mips_24kc.ipk`
- `libcurl_7.68.0-1_arm_cortex-a9.ipk`

**Components:**

- **packagename**: Lowercase, hyphens allowed, no underscores
- **version**: Format `MAJOR.MINOR.PATCH-RELEASE`
- **architecture**: `all` for platform-independent, or specific arch like `mips_24kc`, `arm_cortex-a9`

**Note:** While technically flexible, following this convention ensures compatibility with OpenWrt's package management tools.

---

## Verification & Testing

### 1. Verify Package Structure

```bash
# List archive contents
ar t mypackage.ipk

# Expected output:
# debian-binary
# control.tar.gz
# data.tar.gz
```

### 2. Inspect Control Data

```bash
# Extract and view control file
ar p mypackage.ipk control.tar.gz | tar -xzO ./control
```

### 3. Inspect Data Contents

```bash
# List files that will be installed
ar p mypackage.ipk data.tar.gz | tar -tzf -
```

### 4. Install Package

```bash
# Copy to OpenWrt device
scp mypackage.ipk root@192.168.1.1:/tmp/

# Install on device
ssh root@192.168.1.1
opkg install /tmp/mypackage.ipk
```

### 5. Verify Installation

```bash
# List installed packages
opkg list-installed | grep mypackage

# List installed files
opkg files mypackage

# Check package info
opkg info mypackage
```

### 6. Remove Package

```bash
opkg remove mypackage
```

---

## Common Issues & Solutions

### Issue 1: "Malformed package file"

**Causes:**

- Incorrect ar archive order (must be: debian-binary, control.tar.gz, data.tar.gz)
- Missing debian-binary file
- Corrupted tar archives
- Wrong file permissions in archives

**Solutions:**

```bash
# Ensure correct order when creating IPK
ar q package.ipk debian-binary control.tar.gz data.tar.gz

# Verify structure
ar t package.ipk

# Recreate with proper ownership
tar -czf control.tar.gz --owner=0 --group=0 -C CONTROL .
tar -czf data.tar.gz --owner=0 --group=0 -C data .
```

### Issue 2: Missing dependencies

**Cause:** Package depends on other packages not installed on the system.

**Solution:**

```bash
# Install dependencies first
opkg update
opkg install dependency1 dependency2

# Or use --force-depends (not recommended)
opkg install --force-depends package.ipk
```

### Issue 3: Architecture mismatch

**Cause:** Package built for wrong architecture.

**Solution:**

- Check device architecture: `opkg print-architecture`
- Rebuild package for correct architecture
- Or use `Architecture: all` for platform-independent packages

### Issue 4: Installed-Size mismatch

**Cause:** Manually specified Installed-Size doesn't match actual size.

**Solution:**

```bash
# Calculate size automatically
INSTALLED_SIZE=$(du -sb data | cut -f1)

# Use in control file
cat > CONTROL/control << EOF
...
Installed-Size: $INSTALLED_SIZE
...
EOF
```

### Issue 5: postinst/prerm scripts fail

**Causes:**

- Missing shebang (`#!/bin/sh`)
- Not executable
- Syntax errors
- Missing exit 0

**Solutions:**

```bash
# Ensure proper script format
cat > CONTROL/postinst << 'EOF'
#!/bin/sh
# Your commands here
exit 0
EOF

# Make executable
chmod 755 CONTROL/postinst

# Test script locally before packaging
sh -n CONTROL/postinst  # Syntax check
```

---

## Best Practices

### 1. File Permissions

```bash
# Binaries and scripts
chmod 755 data/usr/bin/*

# Configuration files
chmod 644 data/etc/config/*

# Sensitive files
chmod 600 data/etc/sensitive_config

# Directories
find data -type d -exec chmod 755 {} \;
```

### 2. Package Dependencies

- **Always** declare runtime dependencies in `Depends:` field
- Use exact version requirements when needed: `Depends: package (>= 1.0.0)`
- Separate multiple dependencies with commas: `Depends: dep1, dep2, dep3`

### 3. Package Versioning

- Use semantic versioning: `MAJOR.MINOR.PATCH-RELEASE`
- Increment RELEASE for packaging changes (no code changes)
- Increment PATCH for bug fixes
- Increment MINOR for new features (backward compatible)
- Increment MAJOR for breaking changes

### 4. Installation Scripts

```bash
# Always check if running on device vs. during image build
[ "${IPKG_INSTROOT}" = "" ] || exit 0

# Always provide cleanup on failure
trap 'echo "Installation failed"; exit 1' ERR

# Always exit with proper code
exit 0  # Success
```

### 5. File Conflicts

- Never install files to `/tmp` or `/var/run` (runtime directories)
- Avoid conflicts with other packages (check file paths)
- Use unique paths for package-specific data

### 6. Configuration Files

- Install to `/etc/config/` for UCI-managed configs
- Install to `/etc/` for traditional configs
- Mark config files in package metadata (advanced)

---

## Advanced Topics

### Using opkg-build Tool

Instead of manual creation, use `opkg-build` (if available):

```bash
# Prepare directory structure
mkdir -p mypackage/CONTROL
mkdir -p mypackage/data

# Create control file
cat > mypackage/CONTROL/control << EOF
Package: mypackage
Version: 1.0.0-1
...
EOF

# Copy files to data/
cp -r /path/to/files/* mypackage/data/

# Build IPK
opkg-build mypackage
```

### Cross-Compilation for OpenWrt

**Recommended approach:** Use OpenWrt SDK for proper cross-compilation:

```bash
# Download SDK
wget https://downloads.openwrt.org/.../openwrt-sdk-*.tar.xz

# Extract and setup
tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*

# Update feeds
./scripts/feeds update -a
./scripts/feeds install -a

# Build package
make package/mypackage/compile V=s
```

### Package Signing (Advanced)

For secure package distribution:

```bash
# Generate signing key
opkg-key add private.key

# Sign package
usign -S -m package.ipk -s private.key

# Creates package.ipk.sig
```

---

## Reference Commands

### Package Management

```bash
# Update package lists
opkg update

# Install package
opkg install package_name

# Remove package
opkg remove package_name

# List installed packages
opkg list-installed

# Search for package
opkg find package_name

# Show package files
opkg files package_name

# Show package info
opkg info package_name

# Verify installation
opkg status package_name
```

### Debugging

```bash
# Install with verbose output
opkg install -V2 package.ipk

# Force installation (ignore dependencies)
opkg install --force-depends package.ipk

# Force overwrite conflicting files
opkg install --force-overwrite package.ipk

# Simulate installation (dry run)
opkg install --noaction package.ipk
```

---

## Conclusion

While manual IPK creation is possible and useful for understanding the package format, **production OpenWrt packages should always be built using the SDK**. The manual process is best used for:

- Quick prototyping
- Learning the IPK format
- Debugging package issues
- Creating simple packages without compilation

For complex packages, especially those requiring compilation or integration with OpenWrt's build system, always use the official OpenWrt SDK and buildroot system.

---

## Additional Resources

- OpenWrt Official Documentation: <https://openwrt.org/docs/guide-developer/packages>
- OPKG Package Manager: <https://openwrt.org/docs/guide-user/additional-software/opkg>
- OpenWrt SDK Guide: <https://openwrt.org/docs/guide-developer/using_the_sdk>
- Package Makefile Guide: <https://openwrt.org/docs/guide-developer/packages>
