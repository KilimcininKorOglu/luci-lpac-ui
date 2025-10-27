# OpenWRT USB Storage & HDD Mounting Guide

## Table of Contents
- [Overview](#overview)
- [What is USB Storage Support?](#what-is-usb-storage-support)
- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Hardware Considerations](#hardware-considerations)
- [Installation](#installation)
- [Filesystem Support](#filesystem-support)
- [Partition Detection](#partition-detection)
- [Configuration Methods](#configuration-methods)
- [Automatic Mount Configuration](#automatic-mount-configuration)
- [Manual Mount Configuration](#manual-mount-configuration)
- [SWAP Configuration](#swap-configuration)
- [Filesystem-Specific Examples](#filesystem-specific-examples)
- [Service Auto-Start on Mount](#service-auto-start-on-mount)
- [Advanced Features](#advanced-features)
- [Maintenance and Troubleshooting](#maintenance-and-troubleshooting)
- [Performance Optimization](#performance-optimization)
- [Security Considerations](#security-considerations)
- [Real-World Examples](#real-world-examples)

## Overview

This comprehensive guide explains how to mount and use external storage devices (USB drives, external HDDs, SD cards) with OpenWRT routers, enabling expanded storage for downloads, file sharing, media servers, and more.

**What You'll Learn:**
- Installing USB storage support packages
- Configuring automatic mounting
- Supporting multiple filesystems (ext4, NTFS, FAT, exFAT)
- Setting up SWAP space
- Auto-starting services when storage connects
- Optimizing performance and reliability

**Key Benefits:**
- Expand router storage capacity
- Host file sharing (Samba, FTP, NFS)
- Run media servers (DLNA, Plex)
- Store downloads and torrents
- Backup configurations and logs
- Create additional SWAP space

## What is USB Storage Support?

### USB Storage Basics

**USB storage support** allows OpenWRT routers to recognize and use external storage devices connected via USB ports, transforming your router into a mini NAS (Network Attached Storage).

**Key Components:**
- **Kernel Modules**: USB drivers (USB 2.0/3.0)
- **Storage Drivers**: USB storage protocol support
- **Filesystem Drivers**: Support for different filesystems
- **Block-Mount**: Automatic mounting system
- **fstab Configuration**: Persistent mount configuration

### How It Works

**Connection Flow:**
```
1. USB device plugged into router
2. Kernel detects USB storage device
3. Creates block device (/dev/sda, /dev/sda1, etc.)
4. Block-mount checks /etc/config/fstab
5. Mounts device to specified directory
6. Optional: Starts configured services
```

**Device Naming:**
```
/dev/sda     - First USB storage device
/dev/sda1    - First partition on sda
/dev/sda2    - Second partition on sda
/dev/sdb     - Second USB storage device
/dev/sdb1    - First partition on sdb
```

### USB Storage vs Other Storage

| Feature | USB Storage | Network Storage (NFS/CIFS) | Internal Flash |
|---------|-------------|----------------------------|----------------|
| Capacity | Large (TB+) | Unlimited | Small (MB-GB) |
| Speed | Medium-Fast | Network dependent | Very Fast |
| Setup Complexity | Medium | High | N/A |
| Cost | Low-Medium | Server required | Fixed |
| Hot-Swap | Yes | N/A | No |
| Power Consumption | Medium | N/A | Low |

## Use Cases

### 1. Network Attached Storage (NAS)

**Scenario:** Central file storage for home/office

**Configuration:**
- Large external HDD (1TB+)
- Samba/FTP/NFS file sharing
- Automatic mounting
- User access control

### 2. Media Server

**Scenario:** Stream movies, music, photos to devices

**Configuration:**
- USB drive with media files
- MiniDLNA or Plex server
- Auto-start media server on mount
- Large storage for HD content

### 3. Download Station

**Scenario:** 24/7 BitTorrent/HTTP downloads

**Configuration:**
- USB drive for downloads
- Transmission or qBittorrent
- SWAP for additional memory
- Automatic service start

### 4. Backup Storage

**Scenario:** Router config backups, log storage

**Configuration:**
- Small USB flash drive
- Automated backup scripts
- Log rotation to USB
- Configuration snapshots

### 5. Extroot (Root Expansion)

**Scenario:** Expand root filesystem to install more packages

**Configuration:**
- USB drive as extended root
- Pivot root to USB
- More space for packages
- Enhanced functionality

## Prerequisites

### Hardware Requirements

**Router:**
- USB port (USB 2.0 minimum, USB 3.0 recommended)
- Sufficient power output for drive
- At least 32MB free RAM
- OpenWRT 8.09 or newer

**Storage Device:**
- USB flash drive (any size)
- External HDD (2.5" or 3.5")
- SD card (via USB adapter)
- USB SSD

**Power Considerations:**
- 2.5" HDDs: May need powered USB hub
- 3.5" HDDs: Always need external power
- USB flash drives: Usually powered by router
- SSDs: Lower power than HDDs

### Software Requirements

**OpenWRT Version:**
- 8.09+ (Kamikaze)
- Attitude Adjustment (12.09)
- Barrier Breaker (14.07)
- Chaos Calmer (15.05)
- Current releases (19.07, 21.02, 22.03)

**Check Version:**
```bash
cat /etc/openwrt_release
```

### Knowledge Requirements

- SSH access to router
- Basic Linux commands
- Understanding of filesystems
- Basic OpenWRT configuration

## Hardware Considerations

### Power Requirements

**USB Power Limits:**
- USB 2.0: 500mA (2.5W) per port
- USB 3.0: 900mA (4.5W) per port
- Most routers: 500mA limit

**Device Power Consumption:**
- USB flash drives: 100-200mA
- 2.5" HDDs: 400-1000mA (often exceeds router power)
- 3.5" HDDs: 2000-3000mA (requires external power)
- SSDs: 200-500mA

**Solutions for High-Power Devices:**
```
Option 1: Powered USB Hub
[Router USB] → [Powered Hub] → [External HDD]
              (External Power)

Option 2: Y-Cable (dual USB power)
[Router USB1 + USB2] → [Y-Cable] → [2.5" HDD]

Option 3: External Power Adapter
[External HDD with own power adapter]
```

### USB Version Compatibility

**USB 2.0 vs USB 3.0:**
- USB 2.0: Up to 480 Mbps (60 MB/s theoretical)
- USB 3.0: Up to 5 Gbps (625 MB/s theoretical)
- Real-world: USB 2.0 ~30 MB/s, USB 3.0 ~100 MB/s

**Compatibility:**
- USB 3.0 devices work on USB 2.0 ports (slower speed)
- USB 2.0 devices work on USB 3.0 ports
- Check router USB version: `lsusb -t`

### Filesystem Choice

**Recommended Filesystems:**

**ext4 (Best for Linux):**
- ✅ Native Linux support
- ✅ Journaling (prevents corruption)
- ✅ Large file support
- ✅ Permissions support
- ❌ Not readable by Windows without tools

**NTFS (Best for Windows compatibility):**
- ✅ Windows/Mac/Linux compatible
- ✅ Large file support
- ✅ Journaling
- ⚠️ Requires ntfs-3g (FUSE, slower)

**FAT32 (Best for compatibility):**
- ✅ Universal compatibility
- ✅ Fast, simple
- ❌ 4GB file size limit
- ❌ No permissions
- ❌ No journaling

**exFAT (Modern FAT):**
- ✅ No 4GB limit
- ✅ Good compatibility
- ⚠️ Requires extra package
- ❌ No journaling

## Installation

### Base USB Support Packages

**Install Core USB Modules:**

```bash
# Update package list
opkg update

# Install USB 2.0 support
opkg install kmod-usb-core kmod-usb2

# Install USB 3.0 support (if available)
opkg install kmod-usb3

# Install USB storage support
opkg install kmod-usb-storage

# Install block device utilities
opkg install block-mount
```

**Verify Installation:**
```bash
# Check loaded modules
lsmod | grep usb

# Should see:
# usb_storage
# ehci_hcd (USB 2.0)
# xhci_hcd (USB 3.0)

# Check USB devices
lsusb

# Plug in USB device and check detection
dmesg | tail -20
```

### Filesystem Support Packages

Install packages based on filesystem types you need:

**ext2/ext3/ext4 (Linux):**
```bash
opkg install kmod-fs-ext4

# Tools for formatting/checking
opkg install e2fsprogs
```

**FAT16/FAT32 (Windows/Universal):**
```bash
opkg install kmod-fs-vfat
opkg install kmod-nls-cp437 kmod-nls-iso8859-1

# Tools for formatting
opkg install dosfstools
```

**NTFS (Windows):**
```bash
opkg install ntfs-3g

# Tools for checking
opkg install ntfs-3g-utils
```

**exFAT:**
```bash
opkg install kmod-fs-exfat
opkg install exfat-utils
```

**HFS+ (macOS):**
```bash
opkg install kmod-fs-hfsplus
opkg install kmod-nls-utf8
opkg install hfsprogs
```

### Additional Useful Packages

```bash
# Partition management
opkg install fdisk

# Better disk tools
opkg install parted

# Filesystem utilities
opkg install swap-utils

# USB utilities
opkg install usbutils

# LuCI web interface for USB
opkg install luci-app-usb-storage
```

## Filesystem Support

### Creating Filesystems

**Format as ext4:**
```bash
# WARNING: This erases all data on the partition!

# Create partition table (if needed)
fdisk /dev/sda
# n (new partition)
# p (primary)
# 1 (partition number)
# Enter (default start)
# Enter (default end - use full disk)
# w (write and exit)

# Format as ext4
mkfs.ext4 /dev/sda1

# Add label (optional)
e2label /dev/sda1 MyUSBDrive
```

**Format as FAT32:**
```bash
# Create FAT32 filesystem
mkfs.vfat -F 32 /dev/sda1

# Add label
fatlabel /dev/sda1 MyUSBDrive
```

**Format as NTFS:**
```bash
# Create NTFS filesystem
mkfs.ntfs -f -L MyUSBDrive /dev/sda1
```

**Format as exFAT:**
```bash
# Create exFAT filesystem
mkfs.exfat /dev/sda1
```

### Checking Existing Filesystem

```bash
# Detect filesystem type
block info

# Example output:
# /dev/sda1: UUID="..." TYPE="ext4" LABEL="MyDrive"

# Or use blkid
blkid /dev/sda1

# Manual check
file -s /dev/sda1
```

## Partition Detection

### Automatic Detection

**List All Block Devices:**
```bash
# Using block command
block info

# Output example:
# /dev/sda1: UUID="abc123..." TYPE="ext4" LABEL="USB_Drive"

# Using ls
ls -l /dev/sd*

# Output:
# /dev/sda
# /dev/sda1
# /dev/sda2
```

**Monitor Device Connection:**
```bash
# Watch kernel messages
logread -f

# Or dmesg
dmesg -w

# Plug in USB device and watch for:
# usb 1-1: new high-speed USB device number 2 using ehci-platform
# sd 0:0:0:0: [sda] Attached SCSI disk
```

### Device Information

**Detailed Device Info:**
```bash
# Partition layout
fdisk -l /dev/sda

# Disk usage
df -h

# Block device attributes
blkid

# USB device tree
lsusb -t

# Detailed USB info
cat /sys/kernel/debug/usb/devices
```

## Configuration Methods

### Method 1: Automatic Configuration (Recommended)

**Auto-generate fstab configuration:**

```bash
# Generate configuration automatically
block detect > /etc/config/fstab

# Review generated configuration
cat /etc/config/fstab

# Enable auto-mounting
uci set fstab.@global[0].anon_mount='1'
uci set fstab.@global[0].auto_mount='1'
uci commit fstab

# Reload block mounts
/etc/init.d/fstab boot
```

**What `block detect` does:**
- Scans all connected storage devices
- Detects filesystems and UUIDs
- Generates mount configurations
- Creates sensible default settings

### Method 2: Manual Configuration

**Create fstab configuration manually:**

```bash
# Edit fstab config
vi /etc/config/fstab
```

**Basic structure:**
```
config global
    option anon_swap '0'
    option anon_mount '1'
    option auto_swap '1'
    option auto_mount '1'
    option delay_root '5'
    option check_fs '0'

config mount
    option enabled '1'
    option device '/dev/sda1'
    option target '/mnt/usb'
    option fstype 'ext4'
    option options 'rw,noatime'

config swap
    option enabled '0'
```

## Automatic Mount Configuration

### Global Settings

**Configure global automount behavior:**

```bash
# Enable automatic mounting
uci set fstab.@global[0].anon_mount='1'
uci set fstab.@global[0].auto_mount='1'

# Enable automatic swap
uci set fstab.@global[0].anon_swap='0'
uci set fstab.@global[0].auto_swap='1'

# Delay root mounting (seconds)
uci set fstab.@global[0].delay_root='5'

# Enable filesystem check on boot
uci set fstab.@global[0].check_fs='0'

# Commit changes
uci commit fstab
```

**Global Option Explanations:**

- `anon_mount`: Mount unknown devices automatically
- `auto_mount`: Enable automatic mounting system
- `anon_swap`: Use unknown swap partitions
- `auto_swap`: Enable automatic swap
- `delay_root`: Wait time before mounting (useful for slow USB)
- `check_fs`: Run fsck on boot (risky, can cause boot delays)

### Device Identification Methods

**Three ways to identify devices:**

**1. By Device Path (Not Recommended - changes):**
```bash
uci add fstab mount
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/usb'
uci set fstab.@mount[-1].enabled='1'
```

**2. By UUID (Recommended - persistent):**
```bash
# Get UUID
UUID=$(block info | grep /dev/sda1 | sed 's/.*UUID="\([^"]*\)".*/\1/')

uci add fstab mount
uci set fstab.@mount[-1].uuid="$UUID"
uci set fstab.@mount[-1].target='/mnt/usb'
uci set fstab.@mount[-1].enabled='1'
```

**3. By Label (Recommended - readable):**
```bash
# Get label
LABEL=$(block info | grep /dev/sda1 | sed 's/.*LABEL="\([^"]*\)".*/\1/')

uci add fstab mount
uci set fstab.@mount[-1].label="$LABEL"
uci set fstab.@mount[-1].target='/mnt/usb'
uci set fstab.@mount[-1].enabled='1'
```

### Mount Options

**Common mount options:**

```bash
# Basic read-write with noatime (recommended)
uci set fstab.@mount[-1].options='rw,noatime'

# Read-only
uci set fstab.@mount[-1].options='ro'

# With sync (slower but safer)
uci set fstab.@mount[-1].options='rw,sync,noatime'

# For FAT32 with full permissions
uci set fstab.@mount[-1].options='rw,umask=0000,dmask=0000,fmask=0000'

# For NTFS
uci set fstab.@mount[-1].options='rw,noatime,big_writes'
```

**Option Meanings:**
- `rw` - Read-write mode
- `ro` - Read-only mode
- `noatime` - Don't update access times (faster, reduces writes)
- `sync` - Synchronous writes (slower but safer)
- `umask` - Permission mask for FAT/NTFS
- `big_writes` - NTFS performance improvement

## Manual Mount Configuration

### Complete Mount Example

**Step-by-step mount configuration:**

```bash
# 1. Create mount point
mkdir -p /mnt/usb

# 2. Add mount configuration
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/usb'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,noatime'

# 3. Enable filesystem check
uci set fstab.@mount[-1].enabled_fsck='1'

# 4. Commit configuration
uci commit fstab

# 5. Reload fstab
/etc/init.d/fstab boot

# 6. Verify mount
df -h | grep /mnt/usb
```

### Multiple Mounts

**Mount multiple partitions:**

```bash
# Partition 1: /mnt/data (ext4)
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/data'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,noatime'

# Partition 2: /mnt/backup (ext4)
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda2'
uci set fstab.@mount[-1].target='/mnt/backup'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,noatime'

uci commit fstab
/etc/init.d/fstab boot
```

### Direct File Edit

**Edit /etc/config/fstab directly:**

```bash
vi /etc/config/fstab
```

**Example configuration:**
```
config global
    option anon_swap '0'
    option anon_mount '1'
    option auto_swap '1'
    option auto_mount '1'
    option delay_root '5'
    option check_fs '0'

config mount
    option target '/mnt/usb'
    option uuid '12345678-1234-1234-1234-123456789abc'
    option enabled '1'
    option fstype 'ext4'
    option options 'rw,noatime'
    option enabled_fsck '1'

config mount
    option target '/mnt/data'
    option label 'DataDrive'
    option enabled '1'
    option fstype 'ntfs-3g'
    option options 'rw,noatime,big_writes'
```

**Reload after editing:**
```bash
/etc/init.d/fstab restart
```

## SWAP Configuration

### Why Use SWAP?

**Benefits:**
- Prevents out-of-memory crashes
- Allows running memory-intensive applications
- Better multitasking with limited RAM
- Essential for routers with < 128MB RAM

**When to Use:**
- Running multiple services (Samba, Transmission, etc.)
- Installing many packages
- Memory-intensive applications
- Router with limited RAM

### Partition-Based SWAP

**Create SWAP partition:**

```bash
# 1. Create partition (if not exists)
fdisk /dev/sda
# Create partition type 82 (Linux swap)

# 2. Format as swap
mkswap /dev/sda2

# 3. Configure in fstab
uci add fstab swap
uci set fstab.@swap[-1].enabled='1'
uci set fstab.@swap[-1].device='/dev/sda2'

uci commit fstab

# 4. Enable swap
/etc/init.d/fstab boot

# 5. Verify
free -m
# Should show swap space
```

### File-Based SWAP

**Create SWAP file:**

```bash
# 1. Create mount point and mount drive
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb

# 2. Create swap file (512MB example)
dd if=/dev/zero of=/mnt/usb/swapfile bs=1M count=512

# 3. Set permissions
chmod 600 /mnt/usb/swapfile

# 4. Format as swap
mkswap /mnt/usb/swapfile

# 5. Configure in fstab
uci add fstab swap
uci set fstab.@swap[-1].enabled='1'
uci set fstab.@swap[-1].device='/mnt/usb/swapfile'

uci commit fstab

# 6. Enable swap
swapon /mnt/usb/swapfile

# 7. Verify
free -m
```

**Alternative dd method (using count blocks):**
```bash
# Create 128MB swap file (128MB = 262144 blocks of 512 bytes)
dd if=/dev/zero of=/mnt/usb/swap count=262144 bs=512

mkswap /mnt/usb/swap
```

### SWAP Size Recommendations

| RAM Size | Recommended SWAP |
|----------|------------------|
| 32MB | 256MB |
| 64MB | 256-512MB |
| 128MB | 128-256MB |
| 256MB+ | 128MB or none |

### SWAP Performance Tuning

**Adjust swappiness:**
```bash
# Check current swappiness (default: 60)
cat /proc/sys/vm/swappiness

# Set lower swappiness (prefer RAM, less swap usage)
echo 10 > /proc/sys/vm/swappiness

# Make permanent
echo "vm.swappiness=10" >> /etc/sysctl.conf
```

**Swappiness values:**
- `0` = Avoid swap except to prevent OOM
- `10` = Recommended for desktop/server
- `60` = Default (balanced)
- `100` = Aggressive swapping

## Filesystem-Specific Examples

### ext3/ext4 Mount (Linux Native)

**Best for:**
- Linux-only access
- Full permissions support
- Journaling and reliability

**Configuration:**
```bash
mkdir -p /mnt/data

uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/data'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,noatime'
uci set fstab.@mount[-1].enabled_fsck='1'

uci commit fstab
/etc/init.d/fstab boot
```

**Direct fstab entry:**
```
config mount
    option target '/mnt/data'
    option device '/dev/sda1'
    option fstype 'ext4'
    option options 'rw,noatime'
    option enabled '1'
    option enabled_fsck '1'
```

### FAT32/VFAT Mount (Universal)

**Best for:**
- Cross-platform compatibility
- Simple sharing
- Small files

**Configuration:**
```bash
mkdir -p /mnt/usb

uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/usb'
uci set fstab.@mount[-1].fstype='vfat'
uci set fstab.@mount[-1].options='rw,umask=0000,dmask=0000,fmask=0000'

uci commit fstab
/etc/init.d/fstab boot
```

**Permission options:**
- `umask=0000` - All permissions for all users
- `umask=0022` - Owner full, others read-only
- `dmask` - Directory permissions mask
- `fmask` - File permissions mask

**Direct fstab entry:**
```
config mount
    option target '/mnt/usb'
    option device '/dev/sda1'
    option fstype 'vfat'
    option options 'rw,umask=0000,dmask=0000,fmask=0000'
    option enabled '1'
```

### NTFS Mount (Windows)

**Best for:**
- Windows compatibility
- Large files
- Journaling

**Configuration:**
```bash
# Install NTFS support first
opkg install ntfs-3g

mkdir -p /mnt/ntfs

uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/ntfs'
uci set fstab.@mount[-1].fstype='ntfs-3g'
uci set fstab.@mount[-1].options='rw,noatime,big_writes'

uci commit fstab
/etc/init.d/fstab boot
```

**NTFS mount options:**
- `big_writes` - Better performance
- `noatime` - Reduce disk writes
- `compression` - Enable NTFS compression (slower)
- `permissions` - Enable POSIX permissions

**Direct fstab entry:**
```
config mount
    option target '/mnt/ntfs'
    option device '/dev/sda1'
    option fstype 'ntfs-3g'
    option options 'rw,noatime,big_writes'
    option enabled '1'
```

### exFAT Mount (Modern FAT)

**Best for:**
- Large files (> 4GB)
- Cross-platform
- Flash drives

**Configuration:**
```bash
# Install exFAT support
opkg install kmod-fs-exfat exfat-utils

mkdir -p /mnt/exfat

uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/exfat'
uci set fstab.@mount[-1].fstype='exfat'
uci set fstab.@mount[-1].options='rw,noatime'

uci commit fstab
/etc/init.d/fstab boot
```

## Service Auto-Start on Mount

### Hotplug Script for Services

**Enable services to start automatically when USB storage is mounted:**

**Download hotplug script:**
```bash
# Create hotplug directory
mkdir -p /etc/hotplug.d/block

# Download service script
wget http://dl.eko.one.pl/projekty/60-services -O /etc/hotplug.d/block/60-services

# Or create manually (see below)
chmod +x /etc/hotplug.d/block/60-services
```

**Manual hotplug script creation:**
```bash
cat > /etc/hotplug.d/block/60-services <<'EOF'
#!/bin/sh

# Service auto-start on USB mount

[ "$ACTION" = "add" ] || exit 0
[ -n "$DEVICE" ] || exit 0

# Wait for mount to complete
sleep 2

# Check if device is mounted
if mount | grep -q "$DEVICE"; then
    # Get mount configuration for this device
    CONFIG=$(uci show fstab | grep "$DEVICE" | head -1 | cut -d. -f2)

    if [ -n "$CONFIG" ]; then
        # Get list of services to start
        SERVICES=$(uci get fstab.${CONFIG}.service 2>/dev/null)

        # Start each service
        for service in $SERVICES; do
            logger -t hotplug "Starting service: $service (triggered by $DEVICE)"
            /etc/init.d/$service start
        done
    fi
fi
EOF

chmod +x /etc/hotplug.d/block/60-services
```

### Configure Services in fstab

**Add services to mount configuration:**

```bash
# Example: Start minidlna and vsftpd when USB mounts
uci add_list fstab.@mount[-1].service='minidlna'
uci add_list fstab.@mount[-1].service='vsftpd'
uci add_list fstab.@mount[-1].service='transmission'

uci commit fstab
```

**Direct fstab entry:**
```
config mount
    option enabled '1'
    option device '/dev/sda1'
    option target '/mnt/usb'
    option fstype 'ext4'
    option options 'rw,noatime'
    list service 'minidlna'
    list service 'vsftpd'
    list service 'transmission'
```

**How it works:**
1. USB device plugged in
2. Kernel detects device and creates /dev/sdaX
3. block-mount mounts device to target directory
4. Hotplug script triggered
5. Script reads service list from fstab
6. Starts configured services

### Example: DLNA Media Server Auto-Start

**Complete configuration:**

```bash
# 1. Install minidlna
opkg install minidlna

# 2. Configure minidlna to use USB drive
uci set minidlna.config.media_dir='/mnt/usb/media'
uci commit minidlna

# 3. Add to fstab mount config
uci set fstab.@mount[-1].target='/mnt/usb'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].fstype='ext4'
uci add_list fstab.@mount[-1].service='minidlna'
uci commit fstab

# 4. Test: Plug in USB drive
# minidlna should start automatically
```

## Advanced Features

### UUID-Based Mounting (Recommended)

**Why use UUID:**
- Device order independent
- Survives reconnection
- Multiple devices don't conflict
- Professional approach

**Get UUID:**
```bash
# Method 1: block info
block info | grep /dev/sda1

# Output: /dev/sda1: UUID="abc-def-123..." TYPE="ext4"

# Method 2: blkid
blkid /dev/sda1

# Extract UUID
UUID=$(block info | grep /dev/sda1 | sed 's/.*UUID="\([^"]*\)".*/\1/')
echo $UUID
```

**Configure with UUID:**
```bash
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].uuid='abc-def-123-456-789'
uci set fstab.@mount[-1].target='/mnt/data'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,noatime'

uci commit fstab
```

### Label-Based Mounting

**Create label:**
```bash
# ext4 label
e2label /dev/sda1 MyDataDrive

# FAT32 label
fatlabel /dev/sda1 MyUSB

# NTFS label
ntfslabel /dev/sda1 MyNTFS
```

**Configure with label:**
```bash
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].label='MyDataDrive'
uci set fstab.@mount[-1].target='/mnt/data'
uci set fstab.@mount[-1].fstype='ext4'

uci commit fstab
```

### Extroot (Pivot Root to USB)

**Expand root filesystem to USB:**

**Warning:** Advanced feature. Backup configuration first!

```bash
# 1. Format USB as ext4
mkfs.ext4 /dev/sda1

# 2. Mount temporarily
mkdir -p /mnt/usb
mount /dev/sda1 /mnt/usb

# 3. Copy root filesystem
tar -C /overlay -cvf - . | tar -C /mnt/usb -xf -

# 4. Configure fstab for extroot
uci add fstab mount
uci set fstab.@mount[-1].target='/overlay'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,noatime'
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].enabled_fsck='1'

uci commit fstab

# 5. Reboot
reboot

# After reboot, root filesystem is on USB
# Check: df -h
```

### Read-Only Root with USB Storage

**Mount root as read-only, use USB for writes:**

```bash
# Mount USB as /overlay
uci set fstab.@mount[-1].target='/overlay'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].options='rw,noatime'

# Benefits:
# - Protects internal flash from wear
# - Faster boot
# - Easy factory reset (remove USB)
```

## Maintenance and Troubleshooting

### Filesystem Check and Repair

**Check and repair ext4:**
```bash
# 1. Unmount first
umount /dev/sda1

# 2. Run filesystem check
e2fsck -y /dev/sda1

# Options:
# -y = automatically fix errors
# -f = force check even if clean
# -p = automatic repair (safe fixes only)

# 3. Remount
mount /dev/sda1 /mnt/usb
```

**Check FAT32:**
```bash
umount /dev/sda1
fsck.vfat -a /dev/sda1
```

**Check NTFS:**
```bash
umount /dev/sda1
ntfsfix /dev/sda1
```

### Safe Unmounting

**Proper unmount procedure:**

```bash
# 1. Stop services using the drive
/etc/init.d/minidlna stop
/etc/init.d/samba stop
/etc/init.d/transmission stop

# 2. Check what's using the mount
lsof | grep /mnt/usb
fuser -m /mnt/usb

# 3. Unmount
umount /mnt/usb

# 4. Verify unmounted
df -h | grep /mnt/usb
# Should show nothing

# 5. Safe to physically remove
```

**Force unmount (if busy):**
```bash
# Lazy unmount (detach now, cleanup when possible)
umount -l /mnt/usb

# Force unmount (risky - may cause data loss)
umount -f /mnt/usb

# Last resort: kill processes
fuser -km /mnt/usb
```

### Common Issues

#### Issue 1: Device Not Detected

**Symptoms:**
- USB device plugged in, but no /dev/sda

**Diagnosis:**
```bash
# Check if USB modules loaded
lsmod | grep usb_storage

# Check USB devices
lsusb

# Watch kernel messages
dmesg | tail -20

# Check USB power
cat /sys/kernel/debug/usb/devices
```

**Solutions:**
```bash
# Load USB modules manually
insmod usb-storage

# Check power (may need powered hub)
# Try different USB port

# Reboot router
reboot
```

#### Issue 2: Mount Fails

**Symptoms:**
- Device detected but won't mount
- Error messages in log

**Diagnosis:**
```bash
# Try manual mount
mkdir -p /mnt/test
mount -t ext4 /dev/sda1 /mnt/test

# Check logs
logread | grep mount

# Check filesystem
block info
```

**Solutions:**
```bash
# Check filesystem is supported
opkg list-installed | grep kmod-fs

# Install missing filesystem module
opkg install kmod-fs-ext4

# Check and repair filesystem
umount /dev/sda1
e2fsck -y /dev/sda1

# Try different filesystem type
mount -t auto /dev/sda1 /mnt/test
```

#### Issue 3: Slow Performance

**Symptoms:**
- Very slow read/write speeds
- System becomes unresponsive

**Diagnosis:**
```bash
# Test read speed
time dd if=/mnt/usb/testfile of=/dev/null bs=1M count=100

# Test write speed
time dd if=/dev/zero of=/mnt/usb/testfile bs=1M count=100

# Check USB version
lsusb -t

# Check CPU usage
top
```

**Solutions:**
```bash
# Use noatime option
uci set fstab.@mount[-1].options='rw,noatime'

# For NTFS, use big_writes
uci set fstab.@mount[-1].options='rw,noatime,big_writes'

# Use USB 3.0 if available
# Use SSD instead of HDD
# Reduce services running from USB

# For ext4, enable async
uci set fstab.@mount[-1].options='rw,noatime,async'
```

#### Issue 4: Out of Memory

**Symptoms:**
- Services crash
- System becomes unstable
- OOM (Out of Memory) in logs

**Solutions:**
```bash
# Enable SWAP
# See SWAP Configuration section

# Check memory usage
free -m

# Reduce running services
# Close unnecessary processes

# Increase SWAP size
dd if=/dev/zero of=/mnt/usb/swap bs=1M count=512
mkswap /mnt/usb/swap
swapon /mnt/usb/swap
```

### Monitoring and Logging

**Monitor disk usage:**
```bash
#!/bin/sh
# /root/monitor_disk.sh

while true; do
    echo "=== Disk Status $(date) ==="
    df -h | grep /mnt

    echo ""
    echo "=== USB Devices ==="
    lsusb

    echo ""
    sleep 300  # Every 5 minutes
done
```

**Log mount events:**
```bash
# Create hotplug logger
cat > /etc/hotplug.d/block/10-logger <<'EOF'
#!/bin/sh
logger -t usb-mount "ACTION=$ACTION DEVICE=$DEVICE MOUNT=$MOUNT"
EOF

chmod +x /etc/hotplug.d/block/10-logger

# View logs
logread | grep usb-mount
```

## Performance Optimization

### Mount Options for Performance

**Optimize for speed:**
```bash
# Disable access time updates
option options 'rw,noatime,nodiratime'

# Asynchronous I/O (faster but less safe)
option options 'rw,noatime,async'

# Commit interval (for ext4)
option options 'rw,noatime,commit=60'
```

**Optimize for safety:**
```bash
# Synchronous writes (slower but safer)
option options 'rw,sync'

# Journaling data mode (ext4)
option options 'rw,noatime,data=journal'
```

**Balanced (recommended):**
```bash
option options 'rw,noatime,async,commit=30'
```

### USB Performance Tuning

**Increase USB buffer size:**
```bash
# Create sysctl configuration
cat >> /etc/sysctl.conf <<EOF
# USB performance tuning
vm.dirty_ratio = 20
vm.dirty_background_ratio = 10
vm.dirty_writeback_centisecs = 500
EOF

# Apply settings
sysctl -p
```

### Filesystem-Specific Tuning

**ext4 tuning:**
```bash
# Disable journaling (faster but risky)
tune2fs -O ^has_journal /dev/sda1

# Adjust reserved blocks (5% default, reduce for data drives)
tune2fs -m 1 /dev/sda1

# Enable write-back mode
mount -o data=writeback /dev/sda1 /mnt/usb
```

**NTFS tuning:**
```bash
# Big writes option
mount -t ntfs-3g -o big_writes,noatime /dev/sda1 /mnt/ntfs

# Compression (slower writes, saves space)
mount -t ntfs-3g -o compression /dev/sda1 /mnt/ntfs
```

## Security Considerations

### Filesystem Permissions

**Set proper permissions:**
```bash
# After mounting ext4
chmod 755 /mnt/usb
chown root:root /mnt/usb

# Create user directories
mkdir -p /mnt/usb/shared
chmod 777 /mnt/usb/shared

mkdir -p /mnt/usb/admin
chmod 700 /mnt/usb/admin
```

### Encrypted Storage

**Using LUKS encryption:**
```bash
# Install cryptsetup
opkg install cryptsetup

# Create encrypted partition
cryptsetup luksFormat /dev/sda1

# Open encrypted partition
cryptsetup luksOpen /dev/sda1 encrypted_drive

# Format
mkfs.ext4 /dev/mapper/encrypted_drive

# Mount
mount /dev/mapper/encrypted_drive /mnt/secure

# Close when done
umount /mnt/secure
cryptsetup luksClose encrypted_drive
```

### Safe Removal Procedures

**Always:**
1. Stop services using the drive
2. Unmount filesystem
3. Wait for LED activity to stop
4. Physically remove device

**Never:**
- Pull drive while mounted
- Disconnect during write operations
- Power off router with mounted drive

## Real-World Examples

### Example 1: Basic NAS Setup

**Simple file sharing with Samba:**

```bash
#!/bin/sh
# Basic NAS setup script

# 1. Install packages
opkg update
opkg install kmod-usb-storage block-mount kmod-fs-ext4
opkg install samba4-server luci-app-samba4

# 2. Setup mount
mkdir -p /mnt/nas
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/nas'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,noatime'
uci commit fstab
/etc/init.d/fstab boot

# 3. Configure Samba
uci set samba4.@samba[0].name='OpenWrt'
uci set samba4.@samba[0].description='NAS'
uci add samba4 sambashare
uci set samba4.@sambashare[-1].name='Share'
uci set samba4.@sambashare[-1].path='/mnt/nas'
uci set samba4.@sambashare[-1].read_only='no'
uci set samba4.@sambashare[-1].guest_ok='yes'
uci commit samba4

# 4. Start services
/etc/init.d/samba4 enable
/etc/init.d/samba4 start

echo "NAS setup complete. Access at \\\\router-ip\\Share"
```

### Example 2: Download Station

**Transmission with USB storage:**

```bash
#!/bin/sh
# Download station setup

# 1. Install packages
opkg update
opkg install kmod-usb-storage block-mount kmod-fs-ext4
opkg install transmission-daemon transmission-web
opkg install swap-utils

# 2. Create SWAP (256MB)
mkdir -p /mnt/downloads
mount /dev/sda1 /mnt/downloads
dd if=/dev/zero of=/mnt/downloads/swap bs=1M count=256
mkswap /mnt/downloads/swap
swapon /mnt/downloads/swap

# 3. Configure mount with auto-start
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/downloads'
uci set fstab.@mount[-1].fstype='ext4'
uci add_list fstab.@mount[-1].service='transmission'

uci add fstab swap
uci set fstab.@swap[-1].device='/mnt/downloads/swap'
uci set fstab.@swap[-1].enabled='1'

uci commit fstab

# 4. Configure Transmission
uci set transmission.@transmission[0].download_dir='/mnt/downloads/complete'
uci set transmission.@transmission[0].incomplete_dir='/mnt/downloads/incomplete'
uci commit transmission

# 5. Create directories
mkdir -p /mnt/downloads/complete
mkdir -p /mnt/downloads/incomplete

# 6. Enable service
/etc/init.d/transmission enable

echo "Download station ready. Reboot to activate."
```

### Example 3: Media Server

**MiniDLNA media server:**

```bash
#!/bin/sh
# Media server setup

# 1. Install packages
opkg update
opkg install kmod-usb-storage block-mount kmod-fs-ext4
opkg install minidlna

# 2. Configure mount
mkdir -p /mnt/media
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/media'
uci set fstab.@mount[-1].fstype='ext4'
uci add_list fstab.@mount[-1].service='minidlna'
uci commit fstab

# 3. Configure minidlna
uci set minidlna.config.enabled='1'
uci set minidlna.config.friendly_name='Media Server'
uci set minidlna.config.media_dir='/mnt/media'
uci set minidlna.config.inotify='1'
uci commit minidlna

# 4. Mount and start
/etc/init.d/fstab boot
/etc/init.d/minidlna enable

echo "Media server configured. Put media files in /mnt/media"
```

## Conclusion

USB storage support transforms OpenWRT routers into versatile storage and service platforms, enabling NAS functionality, download stations, media servers, and more.

**Key Takeaways:**

✅ **Installation:**
- Install USB and filesystem modules
- Install block-mount for automatic mounting
- Choose appropriate filesystem for your needs

🔧 **Configuration:**
- Use UUID or label for reliable identification
- Configure fstab for automatic mounting
- Enable filesystem check for data safety
- Set appropriate mount options

💾 **Best Practices:**
- Use ext4 for Linux, NTFS for Windows compatibility
- Enable SWAP for memory-constrained routers
- Always unmount before disconnecting
- Use powered hub for 2.5" HDDs
- Regular filesystem checks

🔐 **Safety:**
- Never disconnect while mounted
- Stop services before unmounting
- Regular backups
- Use journaling filesystems
- Monitor disk health

**When to Use USB Storage:**
- File sharing (NAS)
- Media server
- Download station
- Router storage expansion
- Backup storage

For more information:
- OpenWRT Storage: https://openwrt.org/docs/guide-user/storage/start
- USB Basics: https://openwrt.org/docs/guide-user/storage/usb-drives
- Extroot: https://openwrt.org/docs/guide-user/additional-software/extroot_configuration

---

**Document Version:** 1.0
**Last Updated:** Based on OpenWRT 8.09+
**Tested Platforms:** Various OpenWRT routers with USB ports
