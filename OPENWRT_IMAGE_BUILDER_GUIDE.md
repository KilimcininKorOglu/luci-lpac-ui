# OpenWrt Image Builder Guide

**Source:** https://eko.one.pl/?p=openwrt-imagebuilder

**Purpose:** Create custom OpenWrt firmware images without full compilation

---

## Table of Contents

- [Overview](#overview)
- [When to Use Image Builder](#when-to-use-image-builder)
- [System Requirements](#system-requirements)
- [Getting Started](#getting-started)
- [Building Custom Images](#building-custom-images)
- [Advanced Customization](#advanced-customization)
- [Package Management](#package-management)
- [Custom Files Integration](#custom-files-integration)
- [Firmware Selector (Web Alternative)](#firmware-selector-web-alternative)
- [Practical Examples](#practical-examples)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

### What is Image Builder?

The **OpenWrt Image Builder** is a pre-compiled environment that allows you to create custom firmware images for OpenWrt-supported devices **without compiling the entire source tree**.

**Think of it as:**
- A "firmware assembly kit" using pre-built components
- Quick way to create custom images with specific packages
- Bridge between stock firmware and fully custom builds

### How It Works

```
Pre-built Packages + Configuration + Custom Files
                    ↓
            Image Builder
                    ↓
        Custom Firmware Image (.bin)
```

**Process:**
1. Download Image Builder for your device architecture
2. Select packages to include/exclude
3. Optionally add custom files
4. Build firmware image
5. Flash to device

---

## When to Use Image Builder

### ✅ Use Image Builder When:

- **Quick customization needed** - Add/remove packages from official builds
- **No compilation required** - Don't want to set up full build environment
- **Standard packages sufficient** - Using packages from OpenWrt repository
- **Multiple device deployment** - Same configuration for many routers
- **Limited resources** - Build host has low RAM/storage
- **Time-sensitive** - Need custom image in minutes, not hours

### ❌ Don't Use Image Builder When:

- **Custom package compilation needed** - Need to build packages from source
- **Kernel modifications required** - Need custom kernel config or patches
- **Device tree changes** - Modifying hardware definitions
- **Custom toolchain needed** - Special compiler flags or libraries
- **Full control desired** - Want complete build customization

**For these cases, use full OpenWrt compilation instead.**

---

## System Requirements

### Operating System

- **Linux**: Ubuntu, Debian, Fedora, Arch, etc.
- **WSL (Windows Subsystem for Linux)**: WSL2 recommended
- **macOS**: Supported with minor adjustments
- **Windows native**: Not supported (use WSL)

### Required Packages

#### Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install build-essential libncurses5-dev libncursesw5-dev \
    zlib1g-dev gawk git gettext libssl-dev xsltproc rsync wget unzip \
    python3 python3-distutils file
```

#### Fedora

```bash
sudo dnf install @development-tools ncurses-devel zlib-devel \
    gawk git-core gettext openssl-devel perl-ExtUtils-MakeMaker \
    wget rsync unzip python3
```

#### Arch Linux

```bash
sudo pacman -S base-devel ncurses zlib gawk git gettext openssl \
    libxslt wget rsync unzip python
```

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM** | 1GB | 2GB+ |
| **Storage** | 2GB | 5GB+ |
| **CPU** | 1 core | 2+ cores |
| **Internet** | Required | Broadband |

**Note:** Image Builder is much lighter than full OpenWrt compilation (which needs 4GB+ RAM and 50GB+ storage).

---

## Getting Started

### Step 1: Identify Your Device

You need to know your router's:
- **Model** (e.g., Netgear R6220)
- **Architecture/Platform** (e.g., ramips/mt7621)
- **OpenWrt version** (e.g., 23.05.0)

#### Find Platform Information

**Option A: Check OpenWrt Wiki**

Visit: https://openwrt.org/toh/start

Search for your device and note:
- Target: `ramips`
- Subtarget: `mt7621`
- Profile: `netgear_r6220`

**Option B: From Running OpenWrt**

```bash
# SSH to router
ssh root@192.168.1.1

# Check architecture
cat /etc/openwrt_release

# Output example:
# DISTRIB_TARGET='ramips/mt7621'
# DISTRIB_ARCH='mipsel_24kc'
```

### Step 2: Download Image Builder

Visit: https://downloads.openwrt.org/releases/

**URL structure:**
```
https://downloads.openwrt.org/releases/[VERSION]/targets/[PLATFORM]/[SUBTARGET]/
```

**Example for Netgear R6220 (OpenWrt 23.05.0):**
```
https://downloads.openwrt.org/releases/23.05.0/targets/ramips/mt7621/
```

**Download the Image Builder:**
```bash
# Example for ramips/mt7621
wget https://downloads.openwrt.org/releases/23.05.0/targets/ramips/mt7621/openwrt-imagebuilder-23.05.0-ramips-mt7621.Linux-x86_64.tar.xz

# Extract
tar xJf openwrt-imagebuilder-23.05.0-ramips-mt7621.Linux-x86_64.tar.xz

# Navigate to directory
cd openwrt-imagebuilder-23.05.0-ramips-mt7621.Linux-x86_64
```

### Step 3: Explore Image Builder

```bash
# View help
make help

# List available profiles (device models)
make info

# Search for specific device
make info | grep -i r6220
```

**Output example:**
```
netgear_r6220:
    Netgear R6220
    Packages: kmod-mt76x2 kmod-usb3
```

---

## Building Custom Images

### Basic Image (Stock Packages)

Build firmware with default package set:

```bash
make image PROFILE="netgear_r6220"
```

**Output location:**
```
bin/targets/ramips/mt7621/
├── openwrt-23.05.0-ramips-mt7621-netgear_r6220-squashfs-sysupgrade.bin
└── openwrt-23.05.0-ramips-mt7621-netgear_r6220-squashfs-factory.bin
```

### Adding Packages

Include additional packages from OpenWrt repository:

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl curl wget htop nano"
```

**Package naming:**
- `luci` - Web interface (basic)
- `luci-ssl` - HTTPS support for LuCI
- `curl` - HTTP client
- `wget` - File downloader
- `htop` - Process monitor
- `nano` - Text editor

### Removing Packages

Use `-` prefix to exclude packages:

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci -ppp -pppoe -pppox"
```

**Common packages to remove:**
- `-ppp` - PPP protocol (if not needed)
- `-pppoe` - PPPoE for DSL (if using cable/fiber)
- `-dnsmasq` - DNS/DHCP server (if using alternative)
- `-odhcpd` - DHCPv6 server (if IPv6 not needed)

### Combining Add and Remove

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl wireguard-tools \
              -ppp -pppoe -pppox -wpad-basic-mbedtls"
```

---

## Advanced Customization

### Build with Custom Files

#### Step 1: Create Files Directory

```bash
# Create directory structure
mkdir -p files/etc/config
mkdir -p files/etc/uci-defaults
mkdir -p files/root
```

#### Step 2: Add Custom Files

**Example: Custom network configuration**

`files/etc/config/network:`
```bash
cat > files/etc/config/network << 'EOF'
config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.10.1'
    option netmask '255.255.255.0'

config interface 'wan'
    option device 'eth0.2'
    option proto 'dhcp'
EOF
```

**Example: First-boot script**

`files/etc/uci-defaults/99-custom-setup:`
```bash
cat > files/etc/uci-defaults/99-custom-setup << 'EOF'
#!/bin/sh

# Set hostname
uci set system.@system[0].hostname='MyRouter'

# Set timezone
uci set system.@system[0].timezone='UTC'

# Disable password authentication for SSH
uci set dropbear.@dropbear[0].PasswordAuth='off'
uci set dropbear.@dropbear[0].RootPasswordAuth='off'

# Commit changes
uci commit

# Enable services
/etc/init.d/dropbear enable
/etc/init.d/firewall enable

exit 0
EOF
chmod +x files/etc/uci-defaults/99-custom-setup
```

**Example: SSH authorized keys**

`files/root/.ssh/authorized_keys:`
```bash
mkdir -p files/root/.ssh
cat > files/root/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@host
EOF
chmod 700 files/root/.ssh
chmod 600 files/root/.ssh/authorized_keys
```

#### Step 3: Build with Custom Files

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl" \
    FILES="files"
```

### Build with External Package Repository

Add custom package repository:

```bash
# Add repository to repositories.conf
echo "src/gz custom_repo http://myrepo.example.com/packages" >> repositories.conf

# Update package index
make package_index

# Build with packages from custom repo
make image PROFILE="netgear_r6220" \
    PACKAGES="luci custom-package"
```

### Disable Package Signature Checking

For development/testing only:

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci custom-package" \
    DISABLED_SERVICES="opkg package_signing"
```

**⚠️ Warning:** Only use for testing. Production images should always verify signatures.

---

## Package Management

### Finding Available Packages

```bash
# List all available packages
make package_list

# Search for specific package
make package_list | grep vpn

# Show package details
opkg info wireguard-tools
```

### Package Categories

**Network:**
- `curl`, `wget` - HTTP clients
- `tcpdump` - Packet capture
- `iperf3` - Network performance testing
- `mtr` - Network diagnostic tool

**VPN:**
- `openvpn-openssl` - OpenVPN
- `wireguard-tools` - WireGuard
- `strongswan` - IPsec VPN

**Storage:**
- `kmod-usb-storage` - USB storage support
- `kmod-fs-ext4` - EXT4 filesystem
- `block-mount` - USB mount automation

**System:**
- `htop` - Process monitor
- `nano`, `vi` - Text editors
- `bash` - Bash shell
- `screen` - Terminal multiplexer

**LuCI Apps:**
- `luci-app-wireguard` - WireGuard GUI
- `luci-app-ddns` - Dynamic DNS
- `luci-app-upnp` - UPnP configuration
- `luci-app-sqm` - QoS (SQM)

### Package Dependencies

Image Builder automatically resolves dependencies:

```bash
# This will also install dependencies:
# - libustream-openssl
# - libmbedtls
# - ca-certificates
make image PROFILE="netgear_r6220" \
    PACKAGES="luci-ssl"
```

### Checking Package Size

```bash
# Before building, check package sizes
make package_list | grep -A 5 "luci-ssl"

# Output shows:
# Package: luci-ssl
# Version: ...
# Size: 12345
# Installed-Size: 23456
```

---

## Custom Files Integration

### Files Directory Structure

The `files/` directory mirrors the target filesystem:

```
files/
├── etc/
│   ├── config/
│   │   ├── network      # Network configuration
│   │   ├── wireless     # WiFi configuration
│   │   ├── firewall     # Firewall rules
│   │   └── dhcp         # DHCP/DNS settings
│   ├── uci-defaults/
│   │   └── 99-custom    # First-boot script
│   ├── dropbear/
│   │   └── authorized_keys  # SSH keys (deprecated, use /root/.ssh/)
│   └── banner           # Login banner
├── root/
│   ├── .ssh/
│   │   └── authorized_keys  # SSH keys (recommended location)
│   └── .bashrc          # Root user bash config
└── usr/
    └── local/
        └── bin/
            └── custom-script.sh  # Custom scripts
```

### Common Customization Examples

#### 1. Network Configuration

`files/etc/config/network:`
```
config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '10.0.0.1'
    option netmask '255.255.255.0'
    option ip6assign '60'

config interface 'wan'
    option device 'eth1'
    option proto 'dhcp'

config interface 'wan6'
    option device 'eth1'
    option proto 'dhcpv6'
```

#### 2. Wireless Configuration

`files/etc/config/wireless:`
```
config wifi-device 'radio0'
    option type 'mac80211'
    option channel '1'
    option hwmode '11g'
    option htmode 'HT20'

config wifi-iface 'default_radio0'
    option device 'radio0'
    option network 'lan'
    option mode 'ap'
    option ssid 'MyNetwork'
    option encryption 'psk2'
    option key 'MySecurePassword'
```

#### 3. Firewall Rules

`files/etc/config/firewall:`
```
config rule
    option name 'Allow-SSH-WAN'
    option src 'wan'
    option proto 'tcp'
    option dest_port '22'
    option target 'ACCEPT'

config rule
    option name 'Allow-HTTPS-WAN'
    option src 'wan'
    option proto 'tcp'
    option dest_port '443'
    option target 'ACCEPT'
```

#### 4. DHCP/DNS Configuration

`files/etc/config/dhcp:`
```
config dnsmasq
    option domainneeded '1'
    option boguspriv '1'
    option localise_queries '1'
    option rebind_protection '1'
    option local '/lan/'
    option domain 'lan'
    option expandhosts '1'
    option authoritative '1'
    option readethers '1'
    option leasefile '/tmp/dhcp.leases'

config dhcp 'lan'
    option interface 'lan'
    option start '100'
    option limit '150'
    option leasetime '12h'
```

#### 5. Custom Login Banner

`files/etc/banner:`
```
 ╔═══════════════════════════════════════╗
 ║   Welcome to My Custom OpenWrt       ║
 ║   Unauthorized access is prohibited  ║
 ╚═══════════════════════════════════════╝
```

#### 6. Custom Scripts

`files/usr/local/bin/backup.sh:`
```bash
#!/bin/sh
# Automatic backup script

BACKUP_DIR="/mnt/usb/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Create backup
sysupgrade -b "${BACKUP_DIR}/backup-${TIMESTAMP}.tar.gz"

# Keep only last 10 backups
ls -t ${BACKUP_DIR}/backup-*.tar.gz | tail -n +11 | xargs rm -f

echo "Backup completed: backup-${TIMESTAMP}.tar.gz"
```

Make executable:
```bash
chmod +x files/usr/local/bin/backup.sh
```

---

## Firmware Selector (Web Alternative)

### What is Firmware Selector?

A web-based tool for building custom images without using command line:

**URL:** https://firmware-selector.openwrt.org/

### Features

✅ **Supported:**
- Select device model
- Add/remove official repository packages
- View package list

❌ **Not Supported:**
- Custom files integration
- External package repositories
- Advanced build options

### How to Use

1. **Visit:** https://firmware-selector.openwrt.org/
2. **Search:** Enter device model (e.g., "Netgear R6220")
3. **Select version:** Choose OpenWrt version
4. **Customize packages:**
   - Click "Customize installed packages"
   - Add packages (space-separated)
   - Remove packages (prefix with `-`)
5. **Build:** Click "Request Build"
6. **Download:** Download generated firmware

### Example Package List

```
luci luci-ssl curl wget htop nano wireguard-tools -ppp -pppoe
```

### Limitations

- Cannot upload custom files
- Cannot use custom package repositories
- Cannot modify build options
- Limited to official packages only

**For advanced customization, use Image Builder CLI instead.**

---

## Practical Examples

### Example 1: Basic Router with LuCI

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl luci-app-firewall luci-app-upnp"
```

**Includes:**
- LuCI web interface
- HTTPS support
- Firewall management GUI
- UPnP support

### Example 2: VPN Gateway

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl \
              wireguard-tools luci-app-wireguard \
              openvpn-openssl luci-app-openvpn \
              -ppp -pppoe"
```

**Includes:**
- WireGuard VPN
- OpenVPN
- Web management for both
- Removes unnecessary PPP packages

### Example 3: NAS Router

```bash
# Create files directory
mkdir -p files/etc/config

# Add Samba configuration
cat > files/etc/config/samba4 << 'EOF'
config samba
    option workgroup 'WORKGROUP'
    option description 'OpenWrt NAS'
    option homes '1'

config sambashare
    option name 'storage'
    option path '/mnt/sda1'
    option read_only 'no'
    option guest_ok 'yes'
    option create_mask '0666'
    option dir_mask '0777'
EOF

# Build image
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl \
              kmod-usb-storage kmod-fs-ext4 \
              block-mount e2fsprogs \
              samba4-server luci-app-samba4 \
              hdparm" \
    FILES="files"
```

**Includes:**
- USB storage support
- EXT4 filesystem
- Samba file sharing
- Web management
- Pre-configured share

### Example 4: Network Monitoring Router

```bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl \
              luci-app-statistics \
              collectd-mod-cpu \
              collectd-mod-interface \
              collectd-mod-load \
              collectd-mod-memory \
              collectd-mod-network \
              tcpdump iperf3 mtr"
```

**Includes:**
- Real-time statistics
- Network performance tools
- Traffic analysis

### Example 5: Minimal Router (No LuCI)

```bash
# Create SSH key
mkdir -p files/root/.ssh
cat > files/root/.ssh/authorized_keys << 'EOF'
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... user@host
EOF
chmod 700 files/root/.ssh
chmod 600 files/root/.ssh/authorized_keys

# Build minimal image
make image PROFILE="netgear_r6220" \
    PACKAGES="dropbear curl wget htop nano \
              -luci -luci-ssl -uhttpd -ppp -pppoe -dnsmasq" \
    FILES="files"
```

**Includes:**
- SSH only (no web interface)
- Basic utilities
- Pre-configured SSH keys
- Minimal footprint

---

## Troubleshooting

### Build Failures

#### Missing Dependencies

**Error:**
```
Package libncurses not found
```

**Solution:**
```bash
sudo apt-get install libncurses5-dev libncursesw5-dev
```

#### Insufficient Disk Space

**Error:**
```
No space left on device
```

**Solution:**
```bash
# Check available space
df -h

# Clean build directory
make clean

# Or remove entire image builder and re-download
```

#### Package Not Found

**Error:**
```
Package 'mypackage' not found
```

**Solution:**
```bash
# Update package index
make package_index

# List available packages
make package_list | grep mypackage

# Check package name spelling
```

### Image Too Large

**Error:**
```
Image size too large (exceeds device capacity)
```

**Solution:**
```bash
# Remove unnecessary packages
make image PROFILE="device" \
    PACKAGES="luci -ppp -pppoe -wpad-basic -dnsmasq"

# Use minimal package set
make image PROFILE="device" \
    PACKAGES="base-files busybox dropbear firewall4"
```

### Image Builder Version Mismatch

**Error:**
```
Package version mismatch
```

**Solution:**
- Always use Image Builder from same version as target OpenWrt
- Don't mix 23.05 packages with 22.03 Image Builder

---

## Best Practices

### 1. Version Control

```bash
# Save build command in script
cat > build.sh << 'EOF'
#!/bin/bash
make image PROFILE="netgear_r6220" \
    PACKAGES="luci luci-ssl wireguard-tools" \
    FILES="files"
EOF
chmod +x build.sh

# Track in git
git init
git add build.sh files/
git commit -m "Initial build configuration"
```

### 2. Test in Stages

1. **Basic build first:**
   ```bash
   make image PROFILE="device" PACKAGES="luci"
   ```

2. **Add packages incrementally:**
   ```bash
   make image PROFILE="device" PACKAGES="luci curl wget"
   ```

3. **Add custom files last:**
   ```bash
   make image PROFILE="device" PACKAGES="luci" FILES="files"
   ```

### 3. Keep Backups

```bash
# Before flashing custom image
ssh root@192.168.1.1
sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz

# Download backup
scp root@192.168.1.1:/tmp/backup-*.tar.gz ./
```

### 4. Clean Builds

```bash
# Clean before important builds
make clean

# Rebuild
make image PROFILE="device" PACKAGES="..."
```

### 5. Documentation

```bash
# Document build configuration
cat > BUILD_INFO.txt << 'EOF'
Device: Netgear R6220
OpenWrt Version: 23.05.0
Image Builder Version: 23.05.0-ramips-mt7621
Build Date: 2024-01-15
Packages Added: luci, luci-ssl, wireguard-tools
Packages Removed: ppp, pppoe
Custom Files: network config, SSH keys
EOF
```

---

## Additional Resources

- **Official Documentation:** https://openwrt.org/docs/guide-user/additional-software/imagebuilder
- **Firmware Selector:** https://firmware-selector.openwrt.org/
- **Package List:** https://openwrt.org/packages/start
- **Device Table:** https://openwrt.org/toh/start
- **Downloads:** https://downloads.openwrt.org/
- **Forum:** https://forum.openwrt.org/

---

## Comparison: Image Builder vs Full Compilation

| Feature | Image Builder | Full Compilation |
|---------|---------------|------------------|
| **Build Time** | 2-5 minutes | 2-4 hours |
| **Disk Space** | 2-5 GB | 50-200 GB |
| **RAM Required** | 1-2 GB | 4-8 GB |
| **Custom Packages** | ❌ No | ✅ Yes |
| **Kernel Mods** | ❌ No | ✅ Yes |
| **Package Selection** | ✅ Yes | ✅ Yes |
| **Custom Files** | ✅ Yes | ✅ Yes |
| **Learning Curve** | Low | High |
| **Use Case** | Quick custom images | Full customization |

---

## Conclusion

The OpenWrt Image Builder is perfect for:
- Quick firmware customization
- Deployment to multiple devices
- Adding/removing packages
- Including custom configuration files

For full control over compilation, kernel, and custom packages, use the full OpenWrt build system instead.

**Key Takeaways:**
1. Image Builder = Fast custom images without compilation
2. Use `PACKAGES=""` to add/remove packages
3. Use `FILES=""` to include custom files
4. Always backup before flashing
5. Test incrementally
