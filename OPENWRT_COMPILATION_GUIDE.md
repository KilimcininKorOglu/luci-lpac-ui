# OpenWrt Compilation & Package Development Guide

**Source:** https://eko.one.pl/?p=openwrt-kompilacja

**Target Audience:** Users with intermediate Linux knowledge

---

## Table of Contents

- [System Requirements](#system-requirements)
- [Setting Up Build Environment](#setting-up-build-environment)
- [Obtaining OpenWrt Source Code](#obtaining-openwrt-source-code)
- [Build Configuration](#build-configuration)
- [Compilation Process](#compilation-process)
- [Understanding the SDK](#understanding-the-sdk)
- [Cross-Compilation](#cross-compilation)
- [Package Development](#package-development)
- [Creating Custom Package Repository](#creating-custom-package-repository)
- [Advanced Topics](#advanced-topics)
- [Troubleshooting](#troubleshooting)

---

## System Requirements

### Supported Operating Systems

- **Linux**: Debian, Ubuntu, Linux Mint (recommended)
- **macOS**: Supported
- **Unix-based systems**: Generally supported
- **Windows**: Not recommended (use WSL2 instead)

### Hardware Requirements

| Component | Minimum | Recommended | Notes |
|-----------|---------|-------------|-------|
| **RAM** | 4GB | 8GB+ | 2GB will cause out-of-memory errors |
| **Storage** | 10GB | 50GB-500GB | Depends on packages selected |
| **CPU** | 2 cores | 4+ cores | More cores = faster compilation |
| **Internet** | Required | Broadband | For downloading sources |

### User Account

- **Compile as regular user** - DO NOT compile as root
- Root privileges only needed for installing dependencies

### Required Packages (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install build-essential binutils bzip2 gawk gettext git \
    libncurses5-dev patch unzip zlib1g-dev libssl-dev flex wget rsync
```

**Package descriptions:**
- `build-essential` - GCC compiler and build tools
- `binutils` - Binary utilities (assembler, linker)
- `bzip2` - Compression utility
- `gawk` - GNU AWK text processing
- `gettext` - Internationalization tools
- `git` - Version control
- `libncurses5-dev` - Terminal UI library (for menuconfig)
- `patch` - Apply source code patches
- `unzip` - ZIP archive extraction
- `zlib1g-dev` - Compression library
- `libssl-dev` - SSL/TLS development files
- `flex` - Lexical analyzer generator
- `wget` - File downloader
- `rsync` - File synchronization

---

## Setting Up Build Environment

### 1. Create Working Directory

```bash
# Create directory for OpenWrt sources
mkdir -p ~/openwrt
cd ~/openwrt
```

### 2. Verify Dependencies

```bash
# Check GCC version (should be 7.x or newer)
gcc --version

# Check available disk space (need at least 10GB free)
df -h ~

# Check available RAM
free -h
```

---

## Obtaining OpenWrt Source Code

### Clone Official Repository

```bash
# Clone OpenWrt repository
git clone https://git.openwrt.org/openwrt/openwrt.git
cd openwrt

# List available versions
git tag

# Example output:
# v21.02.0
# v21.02.1
# v22.03.0
# v23.05.0
# v24.10.0
```

### Checkout Specific Version

```bash
# Fetch all tags
git fetch --tags

# Checkout specific version (example: v24.10.0)
git checkout v24.10.0

# Verify current version
git describe --tags
```

**Version Selection Guidelines:**
- **Latest stable** (e.g., v24.10.x) - Most features, latest packages
- **LTS versions** (e.g., v23.05.x) - Long-term support, stability
- **Older versions** - For specific device compatibility

### Update Feeds

```bash
# Update package feeds
./scripts/feeds update -a

# Install all packages from feeds
./scripts/feeds install -a
```

**What are feeds?**
Feeds are package repositories containing additional software:
- `packages` - General-purpose packages
- `luci` - Web interface components
- `routing` - Routing protocols
- `telephony` - VoIP packages

---

## Build Configuration

### Launch Configuration Menu

```bash
make menuconfig
```

This opens an ncurses-based terminal UI for configuration.

### Navigation

- **Arrow keys** - Move cursor
- **Enter** - Select/enter submenu
- **Space** - Toggle option (M/*/empty)
- **/** - Search for options
- **?** - Help for current option
- **Esc Esc** - Go back/exit

### Key Configuration Areas

#### 1. Target System

**Path:** `Target System`

Select your router's architecture:
- `Atheros AR7xxx/AR9xxx` - Popular TP-Link routers
- `MediaTek Ralink MIPS` - MediaTek-based devices
- `Broadcom BCM47xx/53xx` - Broadcom routers
- `x86` - PC-based systems, virtual machines

#### 2. Subtarget

**Path:** `Subtarget`

Specific CPU variant within architecture:
- For AR71xx: `Generic`, `NAND Flash`, etc.
- For x86: `x86_64`, `Generic`, `Legacy`

#### 3. Target Profile

**Path:** `Target Profile`

Specific device model or generic profile.

#### 4. Build Options

**Path:** `Global build settings`

Important options:
- `Select all kernel module packages by default` - Include all drivers
- `Select all userspace packages by default` - Include all applications
- `Build the OpenWrt SDK` - Generate SDK for cross-compilation
- `Build the OpenWrt Image Builder` - Create custom image builder

#### 5. Package Selection

**Path:** `LuCI` → `Collections`, `Applications`, `Modules`

Package selection symbols:
- `< >` - Not included
- `<M>` - Build as module (.ipk package)
- `<*>` - Built into firmware image

**Common packages:**
- `luci` - Web interface
- `luci-ssl` - HTTPS support for LuCI
- Network tools: `tcpdump`, `iperf3`, `mtr`
- VPN: `openvpn`, `wireguard`
- USB support: `kmod-usb-storage`, `kmod-fs-ext4`

### Save Configuration

1. Navigate to `Exit` at bottom
2. Confirm save when prompted
3. Configuration saved to `.config` file

---

## Compilation Process

### Single-Thread Compilation

```bash
# Basic compilation (slow but safe)
make

# With verbose output
make V=s
```

**V=s flags:**
- `V=s` - Show full command output (useful for debugging)
- `V=w` - Show warnings only

### Multi-Thread Compilation

```bash
# Use all available CPU cores
make -j$(nproc)

# Use specific number of threads (e.g., 4)
make -j4
```

**Performance notes:**
- First compilation: 2-4 hours (depending on hardware)
- Subsequent builds: Much faster (only changed packages rebuild)
- `-j` factor: Generally use number of CPU cores + 1

### Compilation Stages

The build process goes through these stages:

1. **toolchain** - Cross-compiler creation
2. **target/linux** - Kernel compilation
3. **package** - Package compilation
4. **target/install** - Image creation

### Monitor Progress

```bash
# In another terminal, watch build log
tail -f build_dir/target-*/root-*/tmp/.packageinfo

# Check current build stage
ps aux | grep make
```

### Expected Output Location

After successful compilation:

```
bin/targets/[architecture]/[subtarget]/
├── openwrt-[version]-[target]-[subtarget]-[profile]-squashfs-sysupgrade.bin
├── openwrt-[version]-[target]-[subtarget]-[profile]-squashfs-factory.bin
├── packages/
│   ├── package1.ipk
│   ├── package2.ipk
│   └── ...
└── sha256sums
```

**File types:**
- `*-sysupgrade.bin` - For upgrading existing OpenWrt installation
- `*-factory.bin` - For first-time installation from stock firmware
- `*.ipk` - Individual package files

---

## Understanding the SDK

### What is the OpenWrt SDK?

The SDK (Software Development Kit) is a pre-compiled development environment that includes:
- Cross-compiler toolchain
- Headers and libraries
- Build system
- Staging directories

**Purpose:** Compile packages without building entire OpenWrt system.

### SDK Location After Build

```
staging_dir/
├── host/           # Host tools
├── toolchain-*/    # Cross-compiler
└── target-*/       # Target system headers/libs
```

### Toolchain Components

**Location:** `staging_dir/toolchain-[architecture]_gcc-[version]_musl/`

**Contents:**
```
bin/
├── mips-openwrt-linux-musl-gcc       # C compiler
├── mips-openwrt-linux-musl-g++       # C++ compiler
├── mips-openwrt-linux-musl-ld        # Linker
├── mips-openwrt-linux-musl-ar        # Archiver
├── mips-openwrt-linux-musl-strip     # Symbol stripper
└── ...
```

### Target Headers and Libraries

**Headers:** `staging_dir/target-[architecture]/usr/include/`

Common headers:
- `stdio.h`, `stdlib.h` - Standard C library
- `pthread.h` - Threading
- `curl/curl.h` - libcurl
- `openssl/ssl.h` - OpenSSL

**Libraries:** `staging_dir/target-[architecture]/usr/lib/`

Common libraries:
- `libc.so` - C standard library (musl)
- `libpthread.so` - Threading
- `libcurl.so` - HTTP client
- `libssl.so`, `libcrypto.so` - SSL/TLS

---

## Cross-Compilation

### Environment Setup

```bash
# Navigate to toolchain directory
cd ~/openwrt/staging_dir/toolchain-mips_24kc_gcc-11.2.0_musl

# Set environment variables
export STAGING_DIR=$(pwd)
export PATH=$STAGING_DIR/bin:$PATH
export CROSS_COMPILE=mips-openwrt-linux-musl-
```

### Manual Compilation Example

#### Simple C Program

**hello.c:**
```c
#include <stdio.h>

int main() {
    printf("Hello from OpenWrt!\n");
    return 0;
}
```

**Compile:**
```bash
# Basic compilation
${CROSS_COMPILE}gcc -o hello hello.c

# With optimization
${CROSS_COMPILE}gcc -O2 -o hello hello.c

# Strip symbols for smaller binary
${CROSS_COMPILE}strip hello

# Check binary size
ls -lh hello

# Verify architecture
file hello
# Output: hello: ELF 32-bit MSB executable, MIPS, MIPS32 rel2 version 1 (SYSV)...
```

#### Program with External Libraries

**Example: Program using libcurl**

```bash
# Set include path
INCLUDE_PATH="${STAGING_DIR}/../target-mips_24kc_musl/usr/include"

# Set library path
LIB_PATH="${STAGING_DIR}/../target-mips_24kc_musl/usr/lib"

# Compile
${CROSS_COMPILE}gcc -o myprogram myprogram.c \
    -I${INCLUDE_PATH} \
    -L${LIB_PATH} \
    -lcurl

# Strip
${CROSS_COMPILE}strip myprogram
```

### Common Cross-Compilation Flags

```bash
# Optimization
-O2              # Optimize for speed
-Os              # Optimize for size (important for embedded)

# Debugging
-g               # Include debug symbols
-ggdb            # GDB-specific debug info

# Warnings
-Wall            # Enable all warnings
-Werror          # Treat warnings as errors

# Architecture-specific
-march=mips32r2  # Target MIPS32 Release 2
-mtune=24kc      # Optimize for 24Kc core

# Linking
-static          # Static linking (larger but standalone)
-Wl,-rpath=/usr/lib  # Set runtime library path
```

### Verify Cross-Compiled Binary

```bash
# Check file type
file myprogram

# Check library dependencies
${CROSS_COMPILE}readelf -d myprogram | grep NEEDED

# Check size
ls -lh myprogram

# Disassemble (first few instructions)
${CROSS_COMPILE}objdump -d myprogram | head -30
```

---

## Package Development

### Package Structure

OpenWrt packages follow a standard structure:

```
mypackage/
├── Makefile           # Build instructions
├── files/             # Files to install
│   └── etc/
│       └── config/
│           └── myconfig
└── patches/           # Source code patches (optional)
    └── 001-fix-bug.patch
```

### Makefile Template

**Path:** `package/mypackage/Makefile`

```makefile
# Copyright (C) 2024 Your Name
# This is free software, licensed under the MIT License.

include $(TOPDIR)/rules.mk

PKG_NAME:=mypackage
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://downloads.example.com/
PKG_HASH:=skip

PKG_MAINTAINER:=Your Name <you@example.com>
PKG_LICENSE:=MIT
PKG_LICENSE_FILES:=LICENSE

include $(INCLUDE_DIR)/package.mk

define Package/mypackage
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=My custom package
  DEPENDS:=+libc +libpthread
  URL:=https://example.com/mypackage
endef

define Package/mypackage/description
  This is a detailed description of my package.
  It can span multiple lines.
endef

define Package/mypackage/conffiles
/etc/config/myconfig
endef

define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef

define Package/mypackage/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/myprogram $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/myconfig $(1)/etc/config/
endef

$(eval $(call BuildPackage,mypackage))
```

### Makefile Sections Explained

#### Package Information

```makefile
PKG_NAME:=mypackage           # Package name (lowercase)
PKG_VERSION:=1.0.0            # Upstream version
PKG_RELEASE:=1                # OpenWrt package revision
```

#### Source Download

```makefile
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://downloads.example.com/
PKG_HASH:=sha256sum_here      # Or 'skip' for development
```

#### Package Definition

```makefile
define Package/mypackage
  SECTION:=utils              # Category: utils, net, multimedia, etc.
  CATEGORY:=Utilities         # Menu category
  TITLE:=Short description
  DEPENDS:=+libc +libpthread  # Runtime dependencies (+ means required)
  URL:=https://example.com
endef
```

**Common dependencies:**
- `+libc` - C standard library
- `+libpthread` - Threading
- `+librt` - Real-time extensions
- `+libcurl` - HTTP client
- `+libopenssl` - SSL/TLS

#### Build Instructions

```makefile
define Build/Compile
	$(MAKE) -C $(PKG_BUILD_DIR) \
		CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" \
		LDFLAGS="$(TARGET_LDFLAGS)"
endef
```

**Available variables:**
- `$(TARGET_CC)` - Cross-compiler path
- `$(TARGET_CFLAGS)` - C compiler flags
- `$(TARGET_LDFLAGS)` - Linker flags
- `$(PKG_BUILD_DIR)` - Build directory

#### Installation

```makefile
define Package/mypackage/install
	$(INSTALL_DIR) $(1)/usr/bin          # Create directory
	$(INSTALL_BIN) source $(1)/dest      # Install executable
	$(INSTALL_CONF) source $(1)/dest     # Install config (chmod 644)
	$(INSTALL_DATA) source $(1)/dest     # Install data file
endef
```

**Install functions:**
- `$(INSTALL_DIR)` - Create directory (chmod 755)
- `$(INSTALL_BIN)` - Install binary (chmod 755)
- `$(INSTALL_CONF)` - Install config (chmod 644)
- `$(INSTALL_DATA)` - Install data file (chmod 644)

### Building Package

```bash
# From OpenWrt root directory
make package/mypackage/compile V=s

# Clean before rebuild
make package/mypackage/clean
make package/mypackage/compile V=s
```

### Package Output

```
bin/packages/[architecture]/base/
└── mypackage_1.0.0-1_mips_24kc.ipk
```

---

## Creating Custom Package Repository

### Why Create a Repository?

- Distribute packages to multiple routers
- Automatic updates via opkg
- Professional package management
- Version control for deployments

### Repository Structure

```
repository/
├── Packages                # Package index (text)
├── Packages.gz             # Compressed index
├── Packages.sig            # Cryptographic signature
└── *.ipk                   # Package files
```

### Step 1: Collect IPK Files

```bash
# Create repository directory
mkdir -p ~/custom-repo
cd ~/custom-repo

# Copy IPK files
cp ~/openwrt/bin/packages/*/base/*.ipk .
cp ~/openwrt/bin/targets/*/*/packages/*.ipk .
```

### Step 2: Generate Package Index

```bash
# Navigate to OpenWrt SDK scripts
cd ~/openwrt/scripts

# Generate index
./ipkg-make-index.sh ~/custom-repo > ~/custom-repo/Packages

# Compress index
gzip -c ~/custom-repo/Packages > ~/custom-repo/Packages.gz
```

**Packages file format:**
```
Package: mypackage
Version: 1.0.0-1
Depends: libc, libpthread
Section: utils
Architecture: mips_24kc
Installed-Size: 12345
Filename: mypackage_1.0.0-1_mips_24kc.ipk
Size: 5678
SHA256sum: abc123...
Description: My custom package
```

### Step 3: Sign Repository (Optional but Recommended)

```bash
# Generate signing key
usign -G -s ~/repo-secret.key -p ~/repo-public.key

# Sign package index
usign -S -m ~/custom-repo/Packages -s ~/repo-secret.key -x ~/custom-repo/Packages.sig
```

### Step 4: Publish Repository

#### Option A: HTTP Server

```bash
# Using Python HTTP server (for testing)
cd ~/custom-repo
python3 -m http.server 8080
```

#### Option B: Web Server (nginx)

**nginx configuration:**
```nginx
server {
    listen 80;
    server_name repo.example.com;

    root /var/www/custom-repo;

    location / {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
```

#### Option C: GitHub Pages

```bash
# Create GitHub repository
git init
git add .
git commit -m "Initial repository"
git remote add origin https://github.com/username/openwrt-repo.git
git push -u origin main

# Enable GitHub Pages in repository settings
```

### Step 5: Configure Router

#### Add Custom Repository

**File:** `/etc/opkg/customfeeds.conf`

```bash
# SSH to router
ssh root@192.168.1.1

# Add repository
cat >> /etc/opkg/customfeeds.conf << EOF
src/gz custom_repo http://repo.example.com
EOF
```

#### Install Public Key (if signed)

```bash
# Copy public key to router
scp ~/repo-public.key root@192.168.1.1:/etc/opkg/keys/

# Or add to image during build
mkdir -p ~/openwrt/files/etc/opkg/keys/
cp ~/repo-public.key ~/openwrt/files/etc/opkg/keys/
```

#### Update and Install

```bash
# Update package lists
opkg update

# Search for package
opkg list | grep mypackage

# Install package
opkg install mypackage
```

---

## Advanced Topics

### Custom Files in Firmware Image

You can include custom files in compiled firmware by creating a `files/` directory:

```bash
# Create files directory in OpenWrt root
cd ~/openwrt
mkdir -p files/etc/config
mkdir -p files/etc/init.d
mkdir -p files/root

# Add custom config
cat > files/etc/config/myconfig << 'EOF'
config settings 'general'
    option enabled '1'
    option port '8080'
EOF

# Add init script
cat > files/etc/init.d/myservice << 'EOF'
#!/bin/sh /etc/rc.common
START=99

start() {
    echo "Starting my service"
}
EOF
chmod +x files/etc/init.d/myservice

# Add root files
echo "alias ll='ls -lah'" > files/root/.bashrc
```

These files will be included in the firmware image during compilation.

### Kernel Configuration

```bash
# Open kernel menuconfig
make kernel_menuconfig

# Common options to configure:
# - Device drivers
# - Filesystems
# - Network protocols
# - CPU features
```

### Image Builder

The Image Builder allows creating custom firmware images without full compilation:

```bash
# Download Image Builder
wget https://downloads.openwrt.org/.../openwrt-imagebuilder-*.tar.xz

# Extract
tar xf openwrt-imagebuilder-*.tar.xz
cd openwrt-imagebuilder-*

# Build image with custom packages
make image PROFILE="device_profile" PACKAGES="luci mypackage1 mypackage2 -ppp -pppoe"

# Packages with '-' prefix are excluded
```

### SDK-Only Compilation

Download pre-built SDK instead of compiling entire system:

```bash
# Download SDK
wget https://downloads.openwrt.org/.../openwrt-sdk-*.tar.xz

# Extract
tar xf openwrt-sdk-*.tar.xz
cd openwrt-sdk-*

# Update feeds
./scripts/feeds update -a
./scripts/feeds install -a

# Build package
make package/mypackage/compile
```

---

## Troubleshooting

### Build Failures

#### Out of Memory Error

**Symptoms:**
```
virtual memory exhausted: Cannot allocate memory
make[2]: *** [something.o] Error 1
```

**Solutions:**
```bash
# Reduce parallel jobs
make -j2

# Add swap space
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

#### Missing Dependencies

**Symptoms:**
```
/bin/sh: gawk: command not found
configure: error: C compiler cannot create executables
```

**Solution:**
```bash
# Install all required packages
sudo apt-get install build-essential binutils bzip2 gawk gettext git \
    libncurses5-dev patch unzip zlib1g-dev libssl-dev flex wget rsync
```

#### Download Failures

**Symptoms:**
```
--2024-01-01 12:00:00-- https://downloads.openwrt.org/...
ERROR 404: Not Found
```

**Solutions:**
```bash
# Update feeds
./scripts/feeds update -a

# Clean download cache
rm -rf dl/*

# Retry with different mirror
make download V=s
```

### Package Build Failures

#### Undefined References

**Symptoms:**
```
/usr/bin/ld: undefined reference to 'function_name'
```

**Solution:**
```bash
# Check library dependencies in Makefile
# Add missing library to DEPENDS
DEPENDS:=+libc +libpthread +libcurl
```

#### Wrong Architecture

**Symptoms:**
```
cannot execute binary file: Exec format error
```

**Solution:**
```bash
# Verify cross-compiler is used
echo $CROSS_COMPILE
# Should output: mips-openwrt-linux-musl- or similar

# Check binary architecture
file mybinary
```

### Cleaning Build Environment

```bash
# Clean everything (starts from scratch)
make clean

# Clean specific package
make package/mypackage/clean

# Remove downloaded sources
make dirclean

# Reset all configuration
rm .config
make defconfig
```

---

## Best Practices

### 1. Version Control

```bash
# Save configuration
cp .config .config.backup

# Track configuration in git
git add .config
git commit -m "Updated configuration for device X"
```

### 2. Build Logs

```bash
# Save build log
make V=s 2>&1 | tee build.log

# Search for errors
grep -i error build.log
```

### 3. Clean Builds

```bash
# Always clean before important builds
make clean
make -j$(nproc)
```

### 4. Testing

- Test in virtual machine first (if using x86 target)
- Keep backup firmware before flashing
- Test sysupgrade before factory image

### 5. Package Organization

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Document dependencies clearly
- Include README and LICENSE files
- Test on clean OpenWrt installation

---

## Additional Resources

- **Official Documentation**: https://openwrt.org/docs/guide-developer/start
- **Build System**: https://openwrt.org/docs/guide-developer/build-system/start
- **Package Creation**: https://openwrt.org/docs/guide-developer/packages
- **UCI System**: https://openwrt.org/docs/guide-user/base-system/uci
- **OpenWrt Forum**: https://forum.openwrt.org/
- **GitHub Repository**: https://github.com/openwrt/openwrt

---

## Conclusion

This guide covered the complete OpenWrt compilation process from source code download to custom package repository creation. Key takeaways:

1. **Build environment** requires proper dependencies and adequate resources
2. **Configuration** through menuconfig determines what gets compiled
3. **Cross-compilation** uses SDK toolchain for target architecture
4. **Package development** follows standard Makefile structure
5. **Custom repositories** enable professional package distribution

For production use, always use stable OpenWrt releases and thoroughly test custom packages before deployment.
