# OpenWrt Beginner's Guide & FAQ

**Source:** https://eko.one.pl/forum/viewtopic.php?id=12021

**Purpose:** Introduction to OpenWrt for beginners

---

## Table of Contents

- [What is OpenWrt?](#what-is-openwrt)
- [Version History](#version-history)
- [Hardware Requirements](#hardware-requirements)
- [Installation Methods](#installation-methods)
- [Configuration System](#configuration-system)
- [Package Management](#package-management)
- [Network Configuration](#network-configuration)
- [System Administration](#system-administration)
- [Troubleshooting](#troubleshooting)
- [Common Tasks](#common-tasks)
- [Best Practices](#best-practices)

---

## What is OpenWrt?

### Overview

**OpenWrt is a Linux-based operating system for routers and embedded devices.**

Key characteristics:
- **Full Linux OS** - Not just firmware, complete operating system
- **Open Source** - GPL licensed, community-developed
- **Package Management** - Like desktop Linux (apt/yum)
- **Highly Customizable** - Replace manufacturer firmware
- **Active Development** - Regular updates and security patches

### Differences from Stock Firmware

| Feature | Stock Firmware | OpenWrt |
|---------|---------------|---------|
| **Base** | Proprietary | Linux |
| **Updates** | Vendor-dependent | Community-driven |
| **Customization** | Limited | Extensive |
| **Package Installation** | Vendor apps only | Thousands available |
| **Configuration** | NVRAM/Web GUI | UCI + CLI + Web |
| **Performance** | Fixed | Tunable |

### Why Use OpenWrt?

✅ **Features:**
- Advanced routing protocols (BGP, OSPF)
- VPN support (WireGuard, OpenVPN, IPsec)
- Traffic shaping and QoS
- USB storage/printer sharing
- Ad blocking (AdBlock)
- Custom DNS (DoH, DoT)
- Network monitoring

✅ **Benefits:**
- Extended device lifetime (old routers get updates)
- Remove vendor limitations
- Security updates for unsupported devices
- Learning Linux networking
- Free and open source

❌ **Challenges:**
- Learning curve (CLI familiarity helpful)
- Risk of bricking device
- Limited vendor support
- Some features may not work (WiFi, USB)

---

## Version History

### Current Version

**OpenWrt 24.10** (Latest stable as of documentation)

### Historical Versions

| Version | Code Name | Year | Notes |
|---------|-----------|------|-------|
| **0.9** | White Russian | 2005 | First stable release |
| **8.09** | Kamikaze | 2008 | Major rewrite |
| **10.03** | Backfire | 2010 | Improved hardware support |
| **12.09** | Attitude Adjustment | 2013 | IPv6 support |
| **14.07** | Barrier Breaker | 2014 | Procd init system |
| **15.05** | Chaos Calmer | 2015 | Improved stability |
| **LEDE 17.01** | Reboot | 2017 | Fork period |
| **18.06** | - | 2018 | Reunification |
| **19.07** | - | 2020 | Long-term support |
| **21.02** | - | 2021 | WPA3 support |
| **22.03** | - | 2022 | Firewall4/nftables |
| **23.05** | - | 2023 | Current LTS |
| **24.10** | - | 2024 | Latest stable |

### LEDE Fork (2016-2018)

**History:**
- **2016:** Core developers forked OpenWrt → LEDE (Linux Embedded Development Environment)
- **Reason:** Disagreements over development process
- **2018:** Projects reunified under OpenWrt name
- **Legacy:** LEDE improvements integrated into OpenWrt

**Impact:**
- Faster release cycle
- Better testing infrastructure
- Modern build system
- Improved documentation

### Version Selection Guide

**For Production:**
- Use **latest stable** (24.10) for newest features
- Use **LTS version** (23.05) for long-term deployments

**For Old Hardware:**
- Use **19.07** if newer versions don't fit
- Use **15.05** for very old devices (4MB flash)

**For Bleeding Edge:**
- Use **SNAPSHOT** builds (no release guarantees)

---

## Hardware Requirements

### Minimum Requirements (Historical)

**Critical thresholds:**
- **4MB flash + 32MB RAM** = Insufficient for modern OpenWrt
- **8MB flash + 64MB RAM** = Problematic, very limited
- **16MB flash + 128MB RAM** = Minimum for current releases
- **32MB flash + 256MB RAM** = Comfortable for most use cases

### Modern Recommendations (2024)

| Component | Minimum | Recommended | Optimal |
|-----------|---------|-------------|---------|
| **Flash** | 16MB | 32MB | 128MB+ |
| **RAM** | 128MB | 256MB | 512MB+ |
| **CPU** | 300MHz | 600MHz | 1GHz+ |
| **Switch** | 100Mbps | 1Gbps | 1Gbps |
| **WiFi** | 802.11n | 802.11ac | 802.11ax (WiFi 6) |

### Why Larger Storage Matters

**Flash size determines:**
- Available packages
- Features (VPN, monitoring, USB support)
- Future updates (versions grow over time)

**Example package sizes:**
- Base system: ~3-5MB
- LuCI web interface: ~1-2MB
- OpenVPN: ~500KB
- WireGuard: ~100KB
- Full feature router: 10-15MB

### Architecture Compatibility

**Common architectures:**
- **MIPS** - Most Atheros, MediaTek routers
- **ARM** - Newer routers, Raspberry Pi
- **x86_64** - PC Engines APU, virtual machines
- **PowerPC** - Older routers (rare)

**Check your device:**
- OpenWrt Table of Hardware: https://openwrt.org/toh/start
- Search by manufacturer and model
- Verify flash/RAM specifications

---

## Installation Methods

### Before Installation

⚠️ **Critical Steps:**

1. **Backup original firmware**
   - Some manufacturers provide firmware downloads
   - Save in safe location (not on router)

2. **Read device-specific instructions**
   - Each device may have unique requirements
   - Check OpenWrt wiki page for your model

3. **Prepare recovery method**
   - Know how to access bootloader/recovery
   - TFTP server setup (for emergency recovery)
   - Serial console access (advanced)

4. **Verify hardware compatibility**
   - Ensure device is supported
   - Check known issues
   - Verify correct hardware revision

### Installation Image Types

#### 1. Factory Image

**Purpose:** Install from manufacturer's original firmware

**File naming:**
```
openwrt-[version]-[platform]-[device]-squashfs-factory.bin
```

**Method:**
- Upload through stock firmware web interface
- Usually under "Firmware Upgrade" or "System Update"

**Example:**
```
openwrt-23.05.0-ramips-mt7621-netgear_r6220-squashfs-factory.img
```

#### 2. Sysupgrade Image

**Purpose:** Upgrade existing OpenWrt installation

**File naming:**
```
openwrt-[version]-[platform]-[device]-squashfs-sysupgrade.bin
```

**Method:**
```bash
# Upload via LuCI web interface
# Or via command line:
sysupgrade -n /tmp/openwrt-23.05.0-...-sysupgrade.bin

# -n flag = do not keep settings (fresh install)
```

#### 3. Kernel + Rootfs (Advanced)

**Purpose:** Some devices require separate kernel and rootfs

**Files:**
- `*-kernel.bin` - Linux kernel
- `*-rootfs.bin` - Root filesystem

**Method:**
- Device-specific (check wiki)
- Usually via bootloader (U-Boot)

#### 4. TFTP Recovery (Emergency)

**Purpose:** Unbrick router after failed flash

**Requirements:**
- TFTP server on computer
- Ethernet cable
- Specific IP configuration

**Process:**
1. Setup TFTP server on PC
2. Configure PC with static IP (usually 192.168.1.x)
3. Power on router while holding reset button
4. Router requests firmware via TFTP
5. Automatic installation

### Installation Steps

#### Method 1: Web Interface (Easy)

1. **Login to stock firmware**
   ```
   http://192.168.1.1 (or manufacturer default)
   ```

2. **Navigate to firmware update**
   - Usually: Administration → Firmware Upgrade

3. **Upload factory image**
   - Select `*-factory.bin` file
   - Click "Upload" or "Flash"

4. **Wait for installation**
   - **DO NOT POWER OFF**
   - Process takes 2-5 minutes
   - Router will reboot

5. **Connect to OpenWrt**
   ```
   http://192.168.1.1
   # First time: no password, click "Login"
   ```

#### Method 2: Command Line (Advanced)

```bash
# SSH to existing OpenWrt
ssh root@192.168.1.1

# Download firmware (if internet available)
cd /tmp
wget http://downloads.openwrt.org/.../sysupgrade.bin

# Verify checksum
wget http://downloads.openwrt.org/.../sha256sums
sha256sum -c sha256sums 2>/dev/null | grep OK

# Perform upgrade
sysupgrade -v sysupgrade.bin

# With backup of settings:
sysupgrade -v -c sysupgrade.bin

# Without keeping settings (fresh install):
sysupgrade -n -v sysupgrade.bin
```

---

## Configuration System

### UCI (Unified Configuration Interface)

**What is UCI?**
- OpenWrt's configuration system
- Text-based config files in `/etc/config/`
- Command-line tool: `uci`
- Web interface (LuCI) uses UCI backend

### Configuration Files

**Location:** `/etc/config/`

**Common configuration files:**

| File | Purpose |
|------|---------|
| `network` | Network interfaces, VLANs, bridges |
| `wireless` | WiFi settings |
| `firewall` | Firewall rules, zones, port forwards |
| `dhcp` | DHCP server, DNS settings |
| `system` | Hostname, timezone, logging |
| `dropbear` | SSH server configuration |
| `uhttpd` | Web server (LuCI) settings |

### Differences from NVRAM

**Stock firmware (NVRAM):**
```
# Settings stored in binary partition
nvram get wan_ipaddr
nvram set wan_ipaddr=192.168.1.1
nvram commit
```

**OpenWrt (UCI):**
```bash
# Settings in text files
uci get network.wan.ipaddr
uci set network.wan.ipaddr='192.168.1.1'
uci commit network
```

### UCI Command Examples

#### Reading Settings

```bash
# Show all network settings
uci show network

# Get specific value
uci get network.lan.ipaddr
# Output: 192.168.1.1

# List all sections
uci show
```

#### Changing Settings

```bash
# Set LAN IP address
uci set network.lan.ipaddr='192.168.10.1'

# Set WiFi SSID
uci set wireless.@wifi-iface[0].ssid='MyNetwork'

# Set WiFi password
uci set wireless.@wifi-iface[0].key='MyPassword'

# Commit changes (write to file)
uci commit wireless

# Apply changes (restart service)
/etc/init.d/network restart
wifi reload
```

#### Adding/Removing Entries

```bash
# Add firewall rule
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SSH-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart

# Delete entry
uci delete wireless.@wifi-iface[1]
uci commit wireless
wifi reload
```

### Configuration File Format

**Example:** `/etc/config/network`

```
config interface 'lan'
    option device 'br-lan'
    option proto 'static'
    option ipaddr '192.168.1.1'
    option netmask '255.255.255.0'
    option ip6assign '60'

config interface 'wan'
    option device 'eth1'
    option proto 'dhcp'
```

**Structure:**
- `config [type] '[name]'` - Section definition
- `option [key] '[value]'` - Option within section
- `list [key] '[value]'` - List item (multiple values)

---

## Package Management

### OPKG (Package Manager)

**Similar to:**
- `apt` (Debian/Ubuntu)
- `yum`/`dnf` (RedHat/Fedora)
- `pacman` (Arch Linux)

### Basic Commands

```bash
# Update package lists
opkg update

# Install package
opkg install package-name

# Remove package
opkg remove package-name

# List installed packages
opkg list-installed

# Search for package
opkg find '*vpn*'

# Show package info
opkg info wireguard-tools

# List available packages
opkg list

# Upgrade all packages
opkg upgrade
```

### Package Repositories

**Configuration:** `/etc/opkg/*.conf`

**Example:** `/etc/opkg/distfeeds.conf`
```
src/gz openwrt_core https://downloads.openwrt.org/.../packages/mips_24kc/base
src/gz openwrt_packages https://downloads.openwrt.org/.../packages/mips_24kc/packages
src/gz openwrt_luci https://downloads.openwrt.org/.../packages/mips_24kc/luci
```

### Adding Custom Repository

```bash
# Add custom feed
echo "src/gz custom_repo http://myrepo.example.com/packages" >> /etc/opkg/customfeeds.conf

# Update lists
opkg update

# Install from custom repo
opkg install custom-package
```

### Common Packages

**Web Interface:**
```bash
opkg install luci luci-ssl
```

**VPN:**
```bash
opkg install wireguard-tools luci-app-wireguard
opkg install openvpn-openssl luci-app-openvpn
```

**USB Support:**
```bash
opkg install kmod-usb-storage kmod-fs-ext4 block-mount
```

**Network Tools:**
```bash
opkg install tcpdump iperf3 mtr curl wget
```

**System Tools:**
```bash
opkg install htop nano screen
```

---

## Network Configuration

### Default Network Setup

**Fresh OpenWrt installation:**
- **LAN IP:** 192.168.1.1/24
- **DHCP:** Enabled on LAN
- **WAN:** DHCP client
- **WiFi:** Disabled by default

### Changing LAN IP

#### Method 1: Web Interface

1. Navigate to **Network → Interfaces**
2. Click **Edit** on LAN interface
3. Change IPv4 address
4. Click **Save & Apply**

#### Method 2: Command Line

```bash
uci set network.lan.ipaddr='192.168.10.1'
uci commit network
/etc/init.d/network restart

# Note: SSH connection will drop
# Reconnect to new IP
```

### Configuring WAN

#### DHCP (Automatic)

```bash
uci set network.wan.proto='dhcp'
uci commit network
/etc/init.d/network restart
```

#### Static IP

```bash
uci set network.wan.proto='static'
uci set network.wan.ipaddr='203.0.113.10'
uci set network.wan.netmask='255.255.255.0'
uci set network.wan.gateway='203.0.113.1'
uci set network.wan.dns='8.8.8.8 8.8.4.4'
uci commit network
/etc/init.d/network restart
```

#### PPPoE (DSL)

```bash
uci set network.wan.proto='pppoe'
uci set network.wan.username='myusername'
uci set network.wan.password='mypassword'
uci commit network
/etc/init.d/network restart
```

### WiFi Configuration

#### Enable WiFi

```bash
# Enable radio
uci set wireless.radio0.disabled='0'

# Set channel
uci set wireless.radio0.channel='6'

# Set SSID
uci set wireless.@wifi-iface[0].ssid='MyNetwork'

# Set encryption
uci set wireless.@wifi-iface[0].encryption='psk2'
uci set wireless.@wifi-iface[0].key='MyPassword123'

# Apply
uci commit wireless
wifi reload
```

#### Disable WiFi

```bash
uci set wireless.radio0.disabled='1'
uci commit wireless
wifi reload
```

---

## System Administration

### First-Time Setup

```bash
# Set root password
passwd

# Set timezone
uci set system.@system[0].timezone='UTC'
uci commit system

# Set hostname
uci set system.@system[0].hostname='MyRouter'
uci commit system
/etc/init.d/system reload
```

### SSH Access

**Default:** SSH enabled on LAN only

```bash
# Allow SSH from WAN (not recommended)
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SSH-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

### Web Interface (LuCI)

**Install LuCI:**
```bash
opkg update
opkg install luci luci-ssl
/etc/init.d/uhttpd restart
```

**Access:**
- HTTP: http://192.168.1.1
- HTTPS: https://192.168.1.1

### Logs

```bash
# View system log
logread

# Follow log (real-time)
logread -f

# Kernel messages
dmesg

# Clear log
logread -c
```

---

## Troubleshooting

### Device Won't Boot

**Symptoms:**
- No lights
- Power LED only
- No network connection

**Solutions:**
1. **Wait** - First boot takes longer
2. **Hard reset** - Hold reset button 10 seconds
3. **TFTP recovery** - See installation methods
4. **Serial console** - Advanced debugging

### Cannot Access Web Interface

**Check:**
```bash
# Verify uhttpd is running
ps | grep uhttpd

# Check listening ports
netstat -tuln | grep :80

# Restart web server
/etc/init.d/uhttpd restart
```

### No Internet Connection

**Diagnose:**
```bash
# Check WAN interface
ifconfig eth1  # or your WAN device

# Check default route
ip route show

# Test connectivity
ping -c 4 8.8.8.8

# Test DNS
nslookup google.com
```

### WiFi Not Working

```bash
# Check radio status
wifi status

# Check if disabled
uci show wireless | grep disabled

# Enable and restart
uci set wireless.radio0.disabled='0'
uci commit wireless
wifi reload
```

### Check System Resources

```bash
# Free memory
free

# Disk usage
df -h

# CPU load
uptime

# Running processes
top
```

---

## Common Tasks

### Backup Configuration

```bash
# Create backup
sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz

# Download to PC
scp root@192.168.1.1:/tmp/backup-*.tar.gz ./
```

### Restore Configuration

```bash
# Upload backup to router
scp backup.tar.gz root@192.168.1.1:/tmp/

# Restore
sysupgrade -r /tmp/backup.tar.gz
```

### Reset to Defaults

```bash
# Reset all settings
firstboot
reboot
```

### Upgrade Firmware

```bash
# Download new firmware
cd /tmp
wget http://downloads.openwrt.org/.../sysupgrade.bin

# Upgrade (keeping settings)
sysupgrade -v sysupgrade.bin

# Upgrade (fresh install)
sysupgrade -n -v sysupgrade.bin
```

---

## Best Practices

### Security

1. **Set strong root password**
   ```bash
   passwd
   ```

2. **Disable WAN SSH access**
   - Only allow from LAN
   - Or use VPN

3. **Use SSH keys instead of passwords**
   ```bash
   # On PC:
   ssh-copy-id root@192.168.1.1
   ```

4. **Enable firewall**
   - Default is enabled
   - Review rules regularly

5. **Keep firmware updated**
   - Check for updates monthly
   - Subscribe to security announcements

### Performance

1. **Disable unused services**
   ```bash
   /etc/init.d/service_name disable
   /etc/init.d/service_name stop
   ```

2. **Monitor resources**
   ```bash
   opkg install htop
   htop
   ```

3. **Use appropriate QoS**
   ```bash
   opkg install luci-app-sqm
   ```

### Maintenance

1. **Regular backups**
   - Before upgrades
   - After configuration changes

2. **Document changes**
   - Keep notes of customizations
   - Save configuration files

3. **Test before production**
   - Try upgrades on spare device first
   - Verify functionality after changes

---

## Additional Resources

- **Official Wiki:** https://openwrt.org/
- **Forum:** https://forum.openwrt.org/
- **Table of Hardware:** https://openwrt.org/toh/start
- **Package Repository:** https://openwrt.org/packages/start
- **Downloads:** https://downloads.openwrt.org/

---

## Conclusion

OpenWrt transforms consumer routers into powerful Linux-based networking devices. Key takeaways:

1. **Check hardware compatibility** before installation
2. **Backup original firmware** (if available)
3. **Learn UCI** for configuration
4. **Use OPKG** for package management
5. **Keep updated** for security

OpenWrt provides professional-grade features on consumer hardware, but requires Linux knowledge and careful configuration.
