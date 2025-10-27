# OpenWRT Attended Sysupgrade Guide

## Table of Contents
- [Overview](#overview)
- [What is Attended Sysupgrade?](#what-is-attended-sysupgrade)
- [Benefits and Features](#benefits-and-features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Console Usage (auc)](#console-usage-auc)
- [LuCI Web Interface](#luci-web-interface)
- [Configuration](#configuration)
- [Upgrade Process](#upgrade-process)
- [Package Management](#package-management)
- [Backup and Restore](#backup-and-restore)
- [Alternative Update Servers](#alternative-update-servers)
- [Advanced Options](#advanced-options)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Comparison with Manual Sysupgrade](#comparison-with-manual-sysupgrade)

## Overview

This comprehensive guide explains Attended Sysupgrade (ASU), an automated firmware update system for OpenWRT that simplifies the upgrade process by automatically building custom firmware images with your installed packages and preserving configurations.

**What You'll Learn:**
- Installing and configuring Attended Sysupgrade
- Using console and web interface methods
- Automating package preservation across upgrades
- Backing up and restoring package lists
- Using alternative update servers
- Troubleshooting upgrade issues

**Key Benefits:**
- Automated firmware update checking
- Custom image building with your packages
- Configuration preservation
- Package list backup/restore
- Version upgrade notifications
- Web and console interfaces

## What is Attended Sysupgrade?

### Attended Sysupgrade Overview

**Attended Sysupgrade (ASU)** is an automated firmware update system for OpenWRT that:
- Checks for new firmware versions
- Builds custom images with your installed packages
- Downloads and applies updates
- Preserves configurations automatically

**Traditional Sysupgrade vs Attended Sysupgrade:**

| Feature | Manual Sysupgrade | Attended Sysupgrade |
|---------|-------------------|---------------------|
| Update Check | Manual | Automatic |
| Package Preservation | Manual reinstall | Automatic inclusion |
| Custom Image Build | Manual process | Automatic |
| Configuration Backup | Manual | Automatic |
| Web Interface | Basic | Advanced |
| Package Selection | N/A | Interactive |

### How It Works

**Attended Sysupgrade Workflow:**
```
1. Check for updates (auc or LuCI)
   ↓
2. Retrieve list of installed packages
   ↓
3. Send request to build server
   ↓
4. Server builds custom image with packages
   ↓
5. Download custom firmware
   ↓
6. Backup configuration
   ↓
7. Flash new firmware
   ↓
8. Restore configuration
   ↓
9. System reboots with updated firmware and packages
```

**Key Components:**
- **auc**: Console client (Attended Upgrade Client)
- **luci-app-attendedsysupgrade**: Web interface
- **Build Server**: Creates custom images (default: OpenWRT official)
- **Configuration**: `/etc/config/attendedsysupgrade`

## Benefits and Features

### Main Features

**Automation:**
- Automatic update checking
- One-command upgrades
- Custom image building
- Configuration preservation

**Package Management:**
- Automatic package inclusion
- Package list backup
- Package restoration after upgrade
- Custom package selection

**User Interface:**
- Command-line interface (auc)
- Web-based interface (LuCI)
- Advanced mode for package editing
- Update notifications

**Safety:**
- Configuration backup before upgrade
- Rollback possible with backups
- Pre-upgrade verification
- Package compatibility checking

### Advantages Over Manual Upgrade

**Time Saving:**
- No manual package reinstallation
- Automated process (one command)
- No need to track installed packages
- No configuration loss

**Reliability:**
- Verified package compatibility
- Automated backup
- Consistent upgrade process
- Reduced human error

**Convenience:**
- Web interface available
- Package list management
- Update notifications
- Version comparison

## Prerequisites

### Hardware Requirements

**Minimum:**
- OpenWRT compatible router
- 8MB+ flash storage (16MB+ recommended)
- 64MB+ RAM (128MB+ recommended)
- Internet connectivity

**Recommended:**
- 32MB+ flash for package space
- 256MB+ RAM for smooth operation
- Fast internet connection

### Software Requirements

**OpenWRT Version:**
- OpenWRT 19.07 or newer
- Barrier Breaker 14.07+ (limited support)
- Current releases: 21.02, 22.03, 23.05

**Check Version:**
```bash
cat /etc/openwrt_release
```

**Internet Connection:**
- Working WAN connection
- DNS resolution
- Firewall allowing outbound HTTPS

**Verify Connectivity:**
```bash
# Test internet
ping -c 3 8.8.8.8

# Test DNS
nslookup openwrt.org

# Test HTTPS access
wget -O /dev/null https://sysupgrade.openwrt.org
```

### Free Space Requirements

**Check Available Space:**
```bash
df -h

# Look for /overlay or / partition
# Need at least 10-20MB free for upgrade process
```

**Free Space if Needed:**
```bash
# Clean package cache
rm -rf /tmp/opkg-lists/*

# Remove old kernels/backups
rm -rf /tmp/*

# Check logs
ls -lh /var/log/
```

## Installation

### Console Installation (auc)

**Install Attended Upgrade Client:**

```bash
# Update package list
opkg update

# Install auc package
opkg install auc

# Verify installation
which auc

# Check version
auc -h
```

**Minimal Installation:**
```bash
# Only console interface
opkg install auc
```

### Web Interface Installation (LuCI)

**Install LuCI Application:**

```bash
# Update package list
opkg update

# Install web interface
opkg install luci-app-attendedsysupgrade

# Optional: Install language support (example: Polish)
opkg install luci-i18n-attendedsysupgrade-pl

# Restart web server
/etc/init.d/uhttpd restart
```

**Access Web Interface:**
- Navigate to: System → Attended Sysupgrade
- Or: http://router-ip/cgi-bin/luci/admin/system/attended_sysupgrade

### Complete Installation (Both Methods)

```bash
# Install everything
opkg update
opkg install auc luci-app-attendedsysupgrade

# Optional language packs
# opkg install luci-i18n-attendedsysupgrade-de  # German
# opkg install luci-i18n-attendedsysupgrade-es  # Spanish
# opkg install luci-i18n-attendedsysupgrade-fr  # French

# Restart services
/etc/init.d/uhttpd restart
```

### Verify Installation

```bash
# Check installed packages
opkg list-installed | grep -E "auc|attendedsysupgrade"

# Expected output:
# auc - ...
# luci-app-attendedsysupgrade - ...

# Test auc command
auc -V

# Check configuration
uci show attendedsysupgrade
```

## Console Usage (auc)

### Basic Usage

**Check for Updates:**

```bash
# Run auc to check for updates
auc

# Example output:
# Checking for updates...
# New release 23.05.2 available
# Currently installed: 23.05.0
#
# Updates available:
# - Package1: 1.0 → 1.1
# - Package2: 2.0 → 2.1
#
# Upgrade now? [y/N]
```

**Interactive Upgrade:**

```bash
# Check and upgrade
auc

# Review changes
# Press 'y' to confirm
# Wait for download and installation
# System will reboot automatically
```

### Command Options

**Check Version:**
```bash
auc -V
# or
auc --version
```

**Help:**
```bash
auc -h
# or
auc --help
```

**Verbose Mode:**
```bash
# More detailed output
auc -v
```

**Force Reinstall:**
```bash
# Force rebuild even if same version
auc -f
```

**Non-Interactive Mode:**
```bash
# Auto-confirm (use with caution!)
auc -y
```

### Upgrade Workflow

**Step-by-Step Upgrade Process:**

**Step 1: Check for Updates**
```bash
# Run auc
auc

# Output will show:
# - Current version
# - Available version
# - Package updates
# - Required actions
```

**Step 2: Review Information**
```
Review displayed information:
- New version number
- Package changes (updates, additions, removals)
- Configuration preservation note
- Estimated download size
```

**Step 3: Confirm Upgrade**
```bash
# Type 'y' and press Enter
y

# Process begins:
# - Request custom image build
# - Wait for build completion
# - Download firmware image
# - Verify checksum
# - Backup configuration
# - Flash firmware
# - Reboot
```

**Step 4: Wait for Completion**
```
Typical timeline:
- Build request: 5-10 seconds
- Build process: 1-5 minutes
- Download: 1-3 minutes (depends on speed)
- Flash & reboot: 1-2 minutes

Total: ~5-10 minutes
```

**Step 5: Verify After Reboot**
```bash
# After system comes back up
# Check version
cat /etc/openwrt_release

# Verify packages
opkg list-installed | wc -l

# Check connectivity
ping -c 3 8.8.8.8
```

### Example Session

**Complete Upgrade Example:**

```bash
root@OpenWrt:~# auc
Checking for updates...
Device: TP-Link Archer C7 v2
Current version: 22.03.5
Available version: 23.05.2

Updates available:
  base-files: 1447-r20134 → 1560-r23130
  busybox: 1.35.0-4 → 1.36.1-1
  firewall4: 2022-08-30-1 → 2023-04-15-1
  ... (15 more packages)

Build custom image with these packages? [y/N]: y

Requesting custom image build...
Build queued (queue position: 3)
Waiting for build completion...
Build completed in 120 seconds

Downloading firmware (12.5 MB)...
[==================================] 100%

Verifying checksum... OK

Creating configuration backup...
Backup saved to /tmp/backup-OpenWrt-2024-01-15.tar.gz

Flashing new firmware...
Writing image to flash...

Upgrade successful. System will reboot in 5 seconds...
```

## LuCI Web Interface

### Accessing the Interface

**Navigation:**
1. Login to LuCI web interface
2. Go to: **System** → **Attended Sysupgrade**
3. Or direct URL: `http://192.168.1.1/cgi-bin/luci/admin/system/attended_sysupgrade`

### Interface Overview

**Main Tabs:**

**Tab 1: Updates**
- Check for updates button
- Current version display
- Available version display
- Package changes list
- Download and flash button

**Tab 2: Configuration**
- Server URL setting
- Advanced options
- Package management
- Backup settings

### Checking for Updates

**Update Check Process:**

1. Click **"Check for updates"** button
2. Wait for server response (5-10 seconds)
3. Review information:
   - Current firmware version
   - Available firmware version
   - List of package updates
   - Download size estimate

**Update Display:**
```
Current Version: 22.03.5
Available Version: 23.05.2

Package Changes:
+ New packages (3):
  - firewall4
  - nftables
  - kmod-nft-offload

↑ Updated packages (25):
  - base-files: 1447 → 1560
  - busybox: 1.35.0 → 1.36.1
  - dropbear: 2022.82 → 2022.83
  ...

- Removed packages (1):
  - firewall3 (replaced by firewall4)

Total download size: 12.5 MB
```

### Performing Upgrade

**Web Interface Upgrade Steps:**

**Step 1: Check for Updates**
- Click "Check for updates"
- Wait for response

**Step 2: Review Changes**
- Read package changes carefully
- Check for incompatibilities
- Note any removed packages

**Step 3: Advanced Mode (Optional)**
- Enable "Advanced Mode" checkbox
- Review installed packages
- Deselect packages you don't want
- Add additional packages if needed

**Step 4: Start Upgrade**
- Click "Request firmware image" or "Download and flash"
- Confirm action in popup dialog
- Wait for image build

**Step 5: Flash Firmware**
- Image downloads automatically
- Click "Flash firmware" when ready
- Confirm flash operation
- Wait for completion and reboot

### Advanced Mode

**Enable Advanced Mode:**
- Check the "Advanced Mode" checkbox
- Installed packages list appears

**Package Management:**
```
Installed Packages:
☑ luci
☑ luci-ssl
☑ luci-app-firewall
☑ wpad-openssl
☐ luci-app-sqm (optional, can deselect)
☐ ddns-scripts (optional, can deselect)

Add package: [___________________] [Add]
```

**Actions:**
- **Uncheck packages**: Exclude from new firmware
- **Add packages**: Include additional packages
- **Review required**: Ensure dependencies met

### Configuration Tab

**Server Settings:**
- **Server URL**: Build server address
- **Branch**: Stable, snapshot, or custom
- **Advanced options**: Expert settings

**Options:**
- Use defaults for most users
- Change only if needed
- See Configuration section for details

## Configuration

### Configuration File

**Location:**
```bash
/etc/config/attendedsysupgrade
```

**View Configuration:**
```bash
uci show attendedsysupgrade

# Example output:
# attendedsysupgrade.server=server
# attendedsysupgrade.server.url='https://sysupgrade.openwrt.org'
# attendedsysupgrade.client=client
# attendedsysupgrade.client.upgrade_packages='1'
# attendedsysupgrade.client.advanced_mode='0'
# attendedsysupgrade.client.auto_search='0'
```

### Server Configuration

**Change Server URL:**

```bash
# Official OpenWRT server (default)
uci set attendedsysupgrade.server.url='https://sysupgrade.openwrt.org'

# Alternative server
uci set attendedsysupgrade.server.url='https://asu.aparcar.org'

# Custom server
uci set attendedsysupgrade.server.url='https://your-server.com'

# Commit changes
uci commit attendedsysupgrade
```

**Via Web Interface:**
1. System → Attended Sysupgrade → Configuration
2. Edit "Server URL" field
3. Click "Save & Apply"

### Client Configuration

**Upgrade Packages Option:**
```bash
# Enable automatic package upgrades (default)
uci set attendedsysupgrade.client.upgrade_packages='1'

# Disable (only upgrade base system)
uci set attendedsysupgrade.client.upgrade_packages='0'

uci commit attendedsysupgrade
```

**Advanced Mode:**
```bash
# Enable advanced mode by default
uci set attendedsysupgrade.client.advanced_mode='1'

# Disable
uci set attendedsysupgrade.client.advanced_mode='0'

uci commit attendedsysupgrade
```

**Auto Search:**
```bash
# Automatically search for updates on page load
uci set attendedsysupgrade.client.auto_search='1'

# Manual search only
uci set attendedsysupgrade.client.auto_search='0'

uci commit attendedsysupgrade
```

### Complete Configuration Example

```bash
# Configure attendedsysupgrade
uci set attendedsysupgrade.server.url='https://sysupgrade.openwrt.org'
uci set attendedsysupgrade.client.upgrade_packages='1'
uci set attendedsysupgrade.client.advanced_mode='0'
uci set attendedsysupgrade.client.auto_search='0'

# Commit all changes
uci commit attendedsysupgrade

# Verify
uci show attendedsysupgrade
```

## Upgrade Process

### What Gets Preserved

**Automatically Preserved:**
- ✅ Configuration files in `/etc/config/`
- ✅ Network settings
- ✅ Wireless configuration
- ✅ Firewall rules
- ✅ User accounts and passwords
- ✅ UCI configurations
- ✅ Files listed in `/etc/sysupgrade.conf`

**NOT Automatically Preserved:**
- ❌ Manually installed packages (unless specified in ASU)
- ❌ Custom scripts outside `/etc/config/`
- ❌ Kernel modules not in package list
- ❌ Files not in `/etc/sysupgrade.conf`
- ❌ `/tmp/` contents (temporary files)
- ❌ Log files in `/var/log/`

### Pre-Upgrade Checklist

**Before Starting Upgrade:**

```bash
# 1. Backup current configuration
sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz

# 2. Copy backup to safe location (USB, network, etc.)
scp /tmp/backup-*.tar.gz user@backup-server:/backups/

# 3. Document installed packages
opkg list-installed > /tmp/packages.txt

# 4. Check free space
df -h

# 5. Note current version
cat /etc/openwrt_release > /tmp/version.txt

# 6. Test current configuration
ping -c 3 8.8.8.8
```

**Important Files to Backup Manually:**
```bash
# Custom scripts
/root/scripts/

# Custom firewall rules (if not in /etc/config/)
/etc/firewall.user

# Custom cron jobs
/etc/crontabs/root

# Custom hosts
/etc/hosts

# SSL certificates
/etc/ssl/
```

### During Upgrade

**What Happens:**

1. **Image Request** (30 seconds - 5 minutes)
   - auc sends device info to build server
   - Server queues build job
   - Custom image built with your packages
   - Image ready for download

2. **Download** (1-5 minutes)
   - Firmware image downloaded to `/tmp/`
   - Checksum verified
   - Space verified

3. **Backup** (10-30 seconds)
   - Configuration backed up to `/tmp/`
   - Backup includes all UCI configs

4. **Flash** (1-2 minutes)
   - Old firmware erased
   - New firmware written
   - Bootloader updated if needed

5. **Reboot** (1-2 minutes)
   - System reboots
   - New firmware loads
   - Configuration restored

**Visual Progress:**
```
[1/5] Requesting image build...
[2/5] Downloading firmware (12.5 MB)...
[==============        ] 60%
[3/5] Verifying checksum... OK
[4/5] Backing up configuration...
[5/5] Flashing firmware...

Upgrade successful. Rebooting...
```

### Post-Upgrade Verification

**After Reboot:**

```bash
# 1. Verify new version
cat /etc/openwrt_release
grep DISTRIB_RELEASE /etc/openwrt_release

# 2. Check internet connectivity
ping -c 3 8.8.8.8
ping -c 3 openwrt.org

# 3. Verify web interface
# Access http://router-ip

# 4. Check installed packages
opkg list-installed | wc -l
# Compare with pre-upgrade count

# 5. Verify wireless
wifi status

# 6. Check services
/etc/init.d/network status
/etc/init.d/firewall status
/etc/init.d/dnsmasq status

# 7. Review logs
logread | tail -50
```

**Common Post-Upgrade Tasks:**
```bash
# Update package lists
opkg update

# Reinstall any missing packages
opkg install package-name

# Reconfigure custom settings if needed
# Check firewall rules
# Verify wireless settings
# Test VPN if configured
```

## Package Management

### Understanding Package Handling

**Package Categories:**

**Included Automatically:**
- Base system packages
- Previously installed user packages
- Dependencies

**Not Included:**
- Manually removed packages
- Packages deselected in advanced mode
- Packages not compatible with new version

### Package Selection

**Console (auc):**
- Automatically includes all installed packages
- No manual selection in basic auc

**Web Interface:**
- Basic mode: All packages included
- Advanced mode: Manual selection available

**Advanced Mode Package Selection:**
```
1. Enable "Advanced Mode" checkbox
2. Review package list
3. Uncheck packages to exclude
4. Add new packages via input field
5. Proceed with upgrade
```

### Custom Package Lists

**Save Package List:**
```bash
# List all manually installed packages
opkg list-installed | awk '{print $1}' > /etc/backup-packages.txt

# Or only user-installed (excluding base)
opkg list-installed | grep -v "^base-" | awk '{print $1}' > /etc/user-packages.txt

# Include in sysupgrade backup
echo "/etc/backup-packages.txt" >> /etc/sysupgrade.conf
```

**Restore Packages Manually:**
```bash
# After upgrade, reinstall from list
while read pkg; do
    opkg install "$pkg"
done < /etc/backup-packages.txt
```

## Backup and Restore

### Backup & Restore Package

**Available Since:** August 2023

**Installation:**
```bash
opkg update
opkg install backupandrestore
```

**Package Contents:**
- `backuppkgslist.sh` - Backup package list
- `restorepkgslist.sh` - Restore packages

### Creating Package Backup

**Backup Script Usage:**

```bash
# Run backup script
backuppkgslist.sh

# Creates file: /etc/backup/installed_packages.txt

# Verify backup
cat /etc/backup/installed_packages.txt

# Example content:
# luci
# luci-ssl
# luci-app-firewall
# wpad-openssl
# htop
# iftop
# tcpdump
```

**Include in Sysupgrade:**
```bash
# Add to sysupgrade config
echo "/etc/backup/installed_packages.txt" >> /etc/sysupgrade.conf

# Verify
cat /etc/sysupgrade.conf
```

### Restoring Packages

**Restore Script Usage:**

```bash
# After upgrade, restore packages
restorepkgslist.sh

# Script will:
# 1. Update package lists
# 2. Read /etc/backup/installed_packages.txt
# 3. Install each package
# 4. Report success/failures
```

**Manual Restore:**
```bash
# Update package lists first
opkg update

# Restore from backup list
while read package; do
    echo "Installing $package..."
    opkg install "$package"
done < /etc/backup/installed_packages.txt
```

### Complete Backup Strategy

**Before Upgrade:**

```bash
#!/bin/sh
# Complete backup script

BACKUP_DIR="/tmp/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# 1. System configuration backup
sysupgrade -b "$BACKUP_DIR/config.tar.gz"

# 2. Package list backup
backuppkgslist.sh
cp /etc/backup/installed_packages.txt "$BACKUP_DIR/"

# 3. Custom files
tar czf "$BACKUP_DIR/custom-files.tar.gz" \
    /root/scripts/ \
    /etc/firewall.user \
    /etc/crontabs/root

# 4. Version info
cat /etc/openwrt_release > "$BACKUP_DIR/version.txt"

# 5. Network info
uci export network > "$BACKUP_DIR/network.conf"
uci export wireless > "$BACKUP_DIR/wireless.conf"
uci export firewall > "$BACKUP_DIR/firewall.conf"

# 6. Copy to safe location
# scp -r "$BACKUP_DIR" user@backup-server:/backups/

echo "Backup completed: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
```

## Alternative Update Servers

### eko.one.pl Server

**Why Use Alternative Server:**
- Pre-compiled images (faster)
- Additional packages
- Custom configurations
- Local/regional mirrors

**Configure eko.one.pl Server:**

**Console Method:**
```bash
# Set alternative server
uci set attendedsysupgrade.server.url='https://dl.eko.one.pl'
uci commit attendedsysupgrade

# Verify
uci get attendedsysupgrade.server.url
```

**Web Interface Method:**
1. System → Attended Sysupgrade
2. Configuration tab
3. Server section
4. Change URL to: `https://dl.eko.one.pl`
5. Save & Apply

### Other Alternative Servers

**Community Servers:**
```bash
# ASU official mirror
uci set attendedsysupgrade.server.url='https://asu.aparcar.org'

# Custom/corporate server
uci set attendedsysupgrade.server.url='https://your-company.com/asu'

uci commit attendedsysupgrade
```

**Important Notes:**
- Verify server trustworthiness
- Check server compatibility
- Test with non-critical device first
- Backup before using alternative servers

### Server Selection Criteria

**Consider:**
- ✅ Geographic proximity (faster downloads)
- ✅ Package availability
- ✅ Update frequency
- ✅ Server reliability
- ✅ Trust and security

## Advanced Options

### Custom Build Options

**Build Parameters:**
- Target device
- OpenWRT version/branch
- Package selections
- Default configurations

**Specify Branch:**
```bash
# Use snapshot builds (latest development)
# Note: Requires manual configuration edit

# Stable release (recommended)
# Default behavior
```

### Integration with Scripts

**Automated Upgrade Script:**

```bash
#!/bin/sh
# Automated attended sysupgrade script

# Pre-upgrade tasks
backuppkgslist.sh
sysupgrade -b /tmp/pre-upgrade-backup.tar.gz

# Run upgrade (auto-confirm)
auc -y

# Post-upgrade tasks will run after reboot
# Create post-upgrade script in /etc/rc.local or similar
```

**Scheduled Updates:**
```bash
# Add to cron (weekly check)
echo "0 3 * * 0 /usr/bin/auc 2>&1 | logger -t auc" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### Notification Integration

**Email Notification:**
```bash
#!/bin/sh
# Check for updates and send email

auc -v > /tmp/auc-output.txt 2>&1

if grep -q "Updates available" /tmp/auc-output.txt; then
    cat /tmp/auc-output.txt | mail -s "OpenWRT Updates Available" admin@example.com
fi
```

## Troubleshooting

### Common Issues

#### Issue 1: Build Request Fails

**Symptoms:**
- "Build request failed" error
- Timeout waiting for build
- Server unreachable

**Diagnosis:**
```bash
# Test connectivity
ping -c 3 sysupgrade.openwrt.org

# Test HTTPS
wget -O /dev/null https://sysupgrade.openwrt.org

# Check logs
logread | grep auc
```

**Solutions:**
```bash
# Check internet connection
ping -c 3 8.8.8.8

# Check DNS
nslookup sysupgrade.openwrt.org

# Try alternative server
uci set attendedsysupgrade.server.url='https://asu.aparcar.org'
uci commit attendedsysupgrade

# Retry
auc
```

#### Issue 2: Package Incompatibility

**Symptoms:**
- Some packages missing after upgrade
- Package conflicts reported
- Build fails due to package issues

**Solutions:**
```bash
# Check package availability in new version
opkg update
opkg find package-name

# Remove problematic package before upgrade
opkg remove problematic-package

# Manually install after upgrade
opkg install package-name

# Use advanced mode to deselect incompatible packages
```

#### Issue 3: Insufficient Space

**Symptoms:**
- "Not enough space" error
- Download fails
- Flash operation fails

**Diagnosis:**
```bash
# Check available space
df -h

# Check /tmp space (used for download)
df -h /tmp

# Check /overlay space
df -h /overlay
```

**Solutions:**
```bash
# Clean package cache
rm -rf /tmp/opkg-lists/*

# Remove old files
rm -rf /tmp/*

# Remove unnecessary packages
opkg remove unused-package

# Use external storage for download
# (advanced - requires custom configuration)
```

#### Issue 4: Configuration Not Restored

**Symptoms:**
- Settings lost after upgrade
- Need to reconfigure manually

**Solutions:**
```bash
# Verify sysupgrade.conf
cat /etc/sysupgrade.conf

# Add missing paths
echo "/etc/config/custom" >> /etc/sysupgrade.conf

# Manually restore from backup
cd /
tar xzf /tmp/backup-config.tar.gz

# Reboot
reboot
```

### Debug Mode

**Enable Verbose Logging:**
```bash
# Run auc with verbose flag
auc -v

# Check system logs
logread -f

# Check for errors
logread | grep -i error
```

## Best Practices

### Before Upgrade

**Checklist:**
- ✅ Create full backup
- ✅ Document installed packages
- ✅ Copy backups to external storage
- ✅ Verify internet connectivity
- ✅ Check available disk space
- ✅ Review release notes for new version
- ✅ Test upgrade on non-critical device first

### During Upgrade

**Best Practices:**
- ⏱️ Allow sufficient time (30+ minutes)
- 🔌 Ensure stable power (UPS recommended)
- 🌐 Maintain internet connection
- 📵 Don't interrupt the process
- 👀 Monitor progress
- 📝 Take notes of any errors

### After Upgrade

**Post-Upgrade Tasks:**
- ✅ Verify version
- ✅ Test internet connectivity
- ✅ Check web interface access
- ✅ Verify wireless functionality
- ✅ Test all services
- ✅ Review logs for errors
- ✅ Reinstall any missing packages
- ✅ Reconfigure custom settings if needed

### Regular Maintenance

**Recommendations:**
- Check for updates monthly
- Keep backups current
- Update package lists regularly
- Monitor OpenWRT security advisories
- Test configurations after changes
- Document customizations

## Comparison with Manual Sysupgrade

### Feature Comparison

| Feature | Attended Sysupgrade | Manual Sysupgrade |
|---------|---------------------|-------------------|
| Update Check | Automated | Manual |
| Package List | Auto-preserved | Manual tracking |
| Custom Image | Automatic | Manual build |
| Configuration | Auto-preserved | Auto-preserved |
| Web Interface | Advanced | Basic |
| Package Selection | Interactive | N/A |
| Ease of Use | Easy | Moderate |
| Flexibility | Moderate | High |

### When to Use Each Method

**Use Attended Sysupgrade:**
- Regular updates
- Standard configurations
- Many installed packages
- Prefer automation
- Less technical expertise

**Use Manual Sysupgrade:**
- Custom firmware builds
- Non-standard configurations
- Troubleshooting
- Maximum control needed
- Offline upgrades

## Conclusion

Attended Sysupgrade significantly simplifies the OpenWRT firmware upgrade process by automating package preservation, custom image building, and configuration backup.

**Key Takeaways:**

✅ **Installation:**
- Console: `opkg install auc`
- Web: `opkg install luci-app-attendedsysupgrade`
- Both methods available

🔧 **Usage:**
- Console: Simple `auc` command
- Web: System → Attended Sysupgrade
- Automatic package preservation

💾 **Backup:**
- Configuration automatically preserved
- Package list backup recommended
- Manual backups for custom files

📊 **Best Practices:**
- Regular backups before upgrades
- Test on non-critical devices first
- Monitor release notes
- Maintain package documentation

**Advantages:**
- Automated process
- Time-saving
- Reduced errors
- Package preservation
- User-friendly interfaces

**Remember:**
- Always backup before upgrading
- Verify internet connectivity
- Ensure sufficient disk space
- Review changes before confirming
- Test after upgrade

For more information:
- OpenWRT ASU: https://openwrt.org/docs/guide-user/installation/attended.sysupgrade
- ASU Server: https://github.com/aparcar/asu
- Forum: https://forum.openwrt.org/

---

**Document Version:** 1.0
**Last Updated:** Based on OpenWRT 19.07+
**Feature Availability:** Varies by OpenWRT version
