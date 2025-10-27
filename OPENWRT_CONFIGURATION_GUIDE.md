# OpenWrt Configuration Guide

Comprehensive guide for configuring OpenWrt routers via command-line interface (CLI) and UCI (Unified Configuration Interface).

**Based on:** https://eko.one.pl/?p=openwrt-konfiguracja
**Target Audience:** System administrators, network engineers, OpenWrt users
**OpenWrt Versions:** Compatible with OpenWrt 15.05 through current releases

---

## Table of Contents

1. [Introduction to UCI](#introduction-to-uci)
2. [System Configuration](#system-configuration)
3. [Network Configuration](#network-configuration)
4. [Wireless Configuration](#wireless-configuration)
5. [DHCP and DNS](#dhcp-and-dns)
6. [Firewall Configuration](#firewall-configuration)
7. [USB and Storage](#usb-and-storage)
8. [Advanced Features](#advanced-features)
9. [Service Management](#service-management)
10. [Troubleshooting](#troubleshooting)

---

## Introduction to UCI

### What is UCI?

**UCI (Unified Configuration Interface)** is OpenWrt's centralized configuration system that uses simple text files to manage all router settings. All configuration files are stored in `/etc/config/`.

### UCI Command Syntax

```bash
# Read configuration value
uci get <config>.<section>.<option>

# Set configuration value
uci set <config>.<section>.<option>=<value>

# Add new section
uci add <config> <section_type>

# Delete configuration
uci delete <config>.<section>[.<option>]

# Commit changes (write to file)
uci commit [<config>]

# Show all changes
uci changes

# Revert uncommitted changes
uci revert <config>
```

### Important Notes

- Changes made with `uci set` are **temporary** until you run `uci commit`
- After committing, you usually need to **restart the service** for changes to take effect
- Configuration files are in `/etc/config/` (e.g., `/etc/config/network`, `/etc/config/wireless`)
- You can edit files directly, but using UCI commands is recommended for consistency

---

## System Configuration

### File Location
`/etc/config/system`

### Set Timezone

```bash
# Set timezone to Central European Time (Warsaw, Berlin, Paris)
uci set system.@system[0].timezone='CET-1CEST,M3.5.0,M10.5.0/3'
uci set system.@system[0].zonename='Europe/Warsaw'
uci commit system
```

**Common Timezones:**
- **UTC**: `UTC0`
- **EST (US Eastern)**: `EST5EDT,M3.2.0,M11.1.0`
- **PST (US Pacific)**: `PST8PDT,M3.2.0,M11.1.0`
- **CET (Europe Central)**: `CET-1CEST,M3.5.0,M10.5.0/3`
- **GMT (London)**: `GMT0BST,M3.5.0/1,M10.5.0`

### Set Hostname

```bash
uci set system.@system[0].hostname='MyRouter'
uci commit system
/etc/init.d/system reload
```

### Configure System Logging

**Local File Logging:**
```bash
uci set system.@system[0].log_file='/var/log/messages'
uci set system.@system[0].log_size='64'  # Size in KB
uci commit system
/etc/init.d/log restart
```

**Remote Syslog Server:**
```bash
uci set system.@system[0].log_ip='192.168.1.100'  # Syslog server IP
uci set system.@system[0].log_port='514'
uci set system.@system[0].log_proto='udp'
uci commit system
/etc/init.d/log restart
```

### Reboot Router

```bash
# Immediate reboot
reboot

# Scheduled reboot (e.g., 23:00 daily)
echo "0 23 * * * /sbin/reboot" >> /etc/crontabs/root
/etc/init.d/cron restart
```

**Important:** OpenWrt devices typically lack RTC (Real-Time Clock) hardware, so time resets on power loss unless NTP is configured.

---

## Network Configuration

### File Location
`/etc/config/network`

### LAN Interface Configuration

**Static IP (Default):**
```bash
uci set network.lan.ipaddr='192.168.1.1'
uci set network.lan.netmask='255.255.255.0'
uci set network.lan.proto='static'
uci commit network
/etc/init.d/network restart
```

**Change LAN Subnet:**
```bash
uci set network.lan.ipaddr='10.0.0.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

### WAN Interface Configuration

**DHCP (Automatic IP):**
```bash
uci set network.wan.proto='dhcp'
uci commit network
ifup wan
```

**Static IP:**
```bash
uci set network.wan.proto='static'
uci set network.wan.ipaddr='203.0.113.10'
uci set network.wan.netmask='255.255.255.0'
uci set network.wan.gateway='203.0.113.1'
uci set network.wan.dns='8.8.8.8 8.8.4.4'
uci commit network
ifup wan
```

**PPPoE (DSL/Fiber):**
```bash
uci set network.wan.proto='pppoe'
uci set network.wan.username='your_username'
uci set network.wan.password='your_password'
uci commit network
ifup wan
```

### MAC Address Cloning

**For older OpenWrt versions (15.05, Chaos Calmer):**
```bash
uci set network.wan.macaddr='AA:BB:CC:DD:EE:FF'
uci commit network
ifup wan
```

**For newer OpenWrt versions (18.06+):**
```bash
uci set network.wan.device.macaddr='AA:BB:CC:DD:EE:FF'
uci commit network
ifup wan
```

### VLAN Configuration

**Example: Separate Guest Network on VLAN 10:**
```bash
# Create VLAN interface
uci set network.guest=interface
uci set network.guest.type='bridge'
uci set network.guest.proto='static'
uci set network.guest.ipaddr='192.168.10.1'
uci set network.guest.netmask='255.255.255.0'
uci set network.guest.ifname='eth0.10'

uci commit network
/etc/init.d/network restart
```

### View Current Network Configuration

```bash
# Show all network config
uci show network

# Show specific interface
uci show network.lan

# Check interface status
ifstatus lan
ifstatus wan
```

---

## Wireless Configuration

### File Location
`/etc/config/wireless`

### Initial WiFi Setup

**WiFi is disabled by default after OpenWrt installation.** Enable it:

```bash
# Auto-detect wireless hardware
wifi detect > /etc/config/wireless

# Enable WiFi
uci set wireless.radio0.disabled='0'
uci commit wireless
wifi
```

### Basic Access Point Configuration

```bash
# Configure 2.4GHz radio
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.channel='6'
uci set wireless.radio0.htmode='HT20'
uci set wireless.radio0.country='US'

# Configure SSID and security
uci set wireless.default_radio0.ssid='MyNetwork'
uci set wireless.default_radio0.encryption='psk2'  # WPA2-PSK
uci set wireless.default_radio0.key='MySecurePassword123'
uci set wireless.default_radio0.network='lan'

uci commit wireless
wifi
```

### 5GHz WiFi Configuration

```bash
# Configure 5GHz radio
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.channel='36'
uci set wireless.radio1.htmode='VHT80'
uci set wireless.radio1.country='US'

# Configure SSID
uci set wireless.default_radio1.ssid='MyNetwork-5G'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.key='MySecurePassword123'
uci set wireless.default_radio1.network='lan'

uci commit wireless
wifi
```

### WiFi Channel Selection

**2.4GHz Channels:**
- **1, 6, 11**: Non-overlapping channels (recommended)
- Channels 1-13 available in most countries
- Channel 14 available only in Japan

**5GHz Channels:**
- **36, 40, 44, 48**: Lower 5GHz band
- **149, 153, 157, 161**: Upper 5GHz band (higher power in some regions)
- **DFS channels (52-144)**: Require radar detection, may cause delays

**Set channel manually:**
```bash
uci set wireless.radio0.channel='6'
uci commit wireless
wifi
```

**Auto channel selection:**
```bash
uci set wireless.radio0.channel='auto'
uci commit wireless
wifi
```

### WiFi Security Options

```bash
# No encryption (open network - NOT RECOMMENDED)
uci set wireless.default_radio0.encryption='none'

# WEP (obsolete, do not use)
uci set wireless.default_radio0.encryption='wep'
uci set wireless.default_radio0.key='1234567890'

# WPA-PSK (legacy, not recommended)
uci set wireless.default_radio0.encryption='psk'
uci set wireless.default_radio0.key='password'

# WPA2-PSK (recommended for home use)
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='MySecurePassword123'

# WPA2/WPA3 Mixed (modern, best compatibility)
uci set wireless.default_radio0.encryption='psk2+ccmp'
uci set wireless.default_radio0.key='MySecurePassword123'

# WPA3-SAE (most secure, newer devices only)
uci set wireless.default_radio0.encryption='sae'
uci set wireless.default_radio0.key='MySecurePassword123'

uci commit wireless
wifi
```

### MAC Address Filtering

**Whitelist Mode (allow only specific devices):**
```bash
uci set wireless.default_radio0.macfilter='allow'
uci add_list wireless.default_radio0.maclist='AA:BB:CC:DD:EE:01'
uci add_list wireless.default_radio0.maclist='AA:BB:CC:DD:EE:02'
uci commit wireless
wifi
```

**Blacklist Mode (block specific devices):**
```bash
uci set wireless.default_radio0.macfilter='deny'
uci add_list wireless.default_radio0.maclist='AA:BB:CC:DD:EE:FF'
uci commit wireless
wifi
```

### WiFi Client Mode (Connect to Another AP)

```bash
# Configure radio
uci set wireless.radio0.disabled='0'

# Set interface to client/station mode
uci set wireless.default_radio0.mode='sta'
uci set wireless.default_radio0.ssid='UpstreamNetwork'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.key='UpstreamPassword'
uci set wireless.default_radio0.network='wan'

uci commit wireless
wifi
```

### IEEE 802.11r Fast Roaming

**For seamless roaming between multiple access points:**
```bash
uci set wireless.default_radio0.ieee80211r='1'
uci set wireless.default_radio0.mobility_domain='4f57'
uci set wireless.default_radio0.ft_over_ds='1'
uci set wireless.default_radio0.ft_psk_generate_local='1'
uci commit wireless
wifi
```

**Note:** All APs must have:
- Same SSID and password
- Same mobility_domain value
- IEEE 802.11r enabled

### Guest WiFi Network

```bash
# Create guest network interface
uci set network.guest=interface
uci set network.guest.proto='static'
uci set network.guest.ipaddr='192.168.2.1'
uci set network.guest.netmask='255.255.255.0'

# Create guest SSID
uci set wireless.guest=wifi-iface
uci set wireless.guest.device='radio0'
uci set wireless.guest.mode='ap'
uci set wireless.guest.network='guest'
uci set wireless.guest.ssid='GuestNetwork'
uci set wireless.guest.encryption='psk2'
uci set wireless.guest.key='GuestPassword123'
uci set wireless.guest.isolate='1'  # Client isolation

uci commit network
uci commit wireless
/etc/init.d/network restart
wifi
```

### WiFi Power Settings

```bash
# Set transmit power (dBm)
uci set wireless.radio0.txpower='20'
uci commit wireless
wifi
```

**Typical values:**
- **10 dBm**: Very low power (10 mW)
- **20 dBm**: Standard power (100 mW)
- **27 dBm**: High power (500 mW)
- **30 dBm**: Maximum power (1000 mW)

**Check regulatory limits:**
```bash
iw reg get
```

### View WiFi Status

```bash
# Show WiFi configuration
uci show wireless

# Show WiFi status
wifi status

# Show connected clients
iwinfo wlan0 assoclist

# Scan for networks
iwinfo wlan0 scan
```

---

## DHCP and DNS

### File Location
`/etc/config/dhcp`

### Basic DHCP Server Configuration

```bash
uci set dhcp.lan.interface='lan'
uci set dhcp.lan.start='100'        # Start of IP range
uci set dhcp.lan.limit='150'        # Number of IPs to assign
uci set dhcp.lan.leasetime='12h'    # Lease duration
uci commit dhcp
/etc/init.d/dnsmasq restart
```

**Example:** With LAN IP `192.168.1.1`, this assigns `192.168.1.100` through `192.168.1.249`.

### Custom DNS Servers

**Set DNS servers for DHCP clients:**
```bash
# Use Google DNS
uci add_list dhcp.lan.dhcp_option='6,8.8.8.8,8.8.4.4'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

**Common DNS servers:**
- **Google**: `8.8.8.8`, `8.8.4.4`
- **Cloudflare**: `1.1.1.1`, `1.0.0.1`
- **Quad9**: `9.9.9.9`, `149.112.112.112`
- **OpenDNS**: `208.67.222.222`, `208.67.220.220`

### Custom Default Gateway

```bash
# Override gateway (DHCP option 3)
uci add_list dhcp.lan.dhcp_option='3,192.168.1.254'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### Static DHCP Leases (MAC-to-IP Binding)

**Method 1: Using UCI commands:**
```bash
uci add dhcp host
uci set dhcp.@host[-1].name='MyServer'
uci set dhcp.@host[-1].mac='AA:BB:CC:DD:EE:FF'
uci set dhcp.@host[-1].ip='192.168.1.50'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

**Method 2: Using /etc/ethers file:**
```bash
# Add MAC-to-IP mapping
echo "AA:BB:CC:DD:EE:FF 192.168.1.50" >> /etc/ethers

# Add hostname
echo "192.168.1.50 myserver" >> /etc/hosts

/etc/init.d/dnsmasq restart
```

### DNS Forwarding

**Forward specific domains to different DNS server:**
```bash
# Forward *.local to 192.168.1.2
uci add_list dhcp.@dnsmasq[0].server='/local/192.168.1.2'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### Disable DNS (DNS forwarding only)

```bash
uci set dhcp.@dnsmasq[0].port='0'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

### Local DNS Records

```bash
# Add local DNS record
uci add dhcp domain
uci set dhcp.@domain[-1].name='router.local'
uci set dhcp.@domain[-1].ip='192.168.1.1'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

Or edit `/etc/hosts`:
```bash
echo "192.168.1.1 router.local" >> /etc/hosts
```

---

## Firewall Configuration

### File Location
`/etc/config/firewall`

### Basic Firewall Concepts

OpenWrt uses **zones** to define network security:
- **LAN zone**: Trusted network (allows everything)
- **WAN zone**: Untrusted network (blocks incoming, allows outgoing)
- **Guest zone**: Isolated network (limited access)

**Default policies:**
- LAN → WAN: **ACCEPT** (allow internet access)
- WAN → LAN: **REJECT** (block incoming connections)
- LAN → Router: **ACCEPT** (allow management)

### Port Forwarding (DNAT)

**Example: Forward HTTP (port 80) to internal web server:**
```bash
uci add firewall redirect
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].proto='tcp'
uci set firewall.@redirect[-1].src_dport='80'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.100'
uci set firewall.@redirect[-1].dest_port='80'
uci set firewall.@redirect[-1].name='HTTP to Web Server'
uci set firewall.@redirect[-1].target='DNAT'
uci commit firewall
/etc/init.d/firewall restart
```

**Port range forwarding:**
```bash
uci add firewall redirect
uci set firewall.@redirect[-1].src='wan'
uci set firewall.@redirect[-1].proto='tcp udp'
uci set firewall.@redirect[-1].src_dport='5000-5010'
uci set firewall.@redirect[-1].dest='lan'
uci set firewall.@redirect[-1].dest_ip='192.168.1.200'
uci set firewall.@redirect[-1].name='Port Range Forward'
uci set firewall.@redirect[-1].target='DNAT'
uci commit firewall
/etc/init.d/firewall restart
```

### Open Ports on WAN

**Example: Allow SSH from internet (port 22):**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SSH-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].dest_port='22'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

**Security warning:** Opening SSH on WAN is risky. Use strong passwords or key-based authentication.

### Block IP Address

```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Block-Malicious-IP'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].src_ip='203.0.113.50'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].target='REJECT'
uci commit firewall
/etc/init.d/firewall restart
```

### Block MAC Address

```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Block-Device-MAC'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].src_mac='AA:BB:CC:DD:EE:FF'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].target='REJECT'
uci commit firewall
/etc/init.d/firewall restart
```

### Time-Based Firewall Rules

**Block internet access during specific hours:**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Block-Night-Internet'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].src_mac='AA:BB:CC:DD:EE:FF'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].start_time='22:00'
uci set firewall.@rule[-1].stop_time='06:00'
uci set firewall.@rule[-1].weekdays='mon tue wed thu fri'
uci set firewall.@rule[-1].target='REJECT'
uci commit firewall
/etc/init.d/firewall restart
```

### VPN Passthrough

**Enable IPSec passthrough:**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='IPSec-Passthrough'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='esp'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='IPSec-IKE'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='500 4500'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

**Enable PPTP passthrough:**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='PPTP-Passthrough'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='gre'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='PPTP-Control'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='1723'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

### Guest Network Isolation

```bash
# Create guest zone
uci add firewall zone
uci set firewall.@zone[-1].name='guest'
uci set firewall.@zone[-1].input='REJECT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='REJECT'
uci set firewall.@zone[-1].network='guest'

# Allow guest to access WAN only
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'

# Allow DNS and DHCP from router
uci add firewall rule
uci set firewall.@rule[-1].name='Guest-DNS'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='tcp udp'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Guest-DHCP'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='67'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall restart
```

### Custom Firewall Rules

For advanced iptables rules, edit `/etc/firewall.user`:

```bash
cat >> /etc/firewall.user << 'EOF'
# Custom iptables rules
iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
iptables -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
EOF

/etc/init.d/firewall restart
```

### View Firewall Status

```bash
# Show firewall configuration
uci show firewall

# Show active iptables rules
iptables -L -v -n

# Show NAT rules
iptables -t nat -L -v -n

# Show connection tracking
cat /proc/net/nf_conntrack
```

---

## USB and Storage

### Install USB Support Packages

```bash
opkg update
opkg install kmod-usb-core kmod-usb2 kmod-usb3
```

### Install Filesystem Support

**For ext4 (Linux filesystems):**
```bash
opkg install kmod-fs-ext4 e2fsprogs
```

**For FAT/FAT32 (Windows filesystems):**
```bash
opkg install kmod-fs-vfat kmod-nls-cp437 kmod-nls-iso8859-1
```

**For NTFS (Windows NTFS):**
```bash
opkg install kmod-fs-ntfs ntfs-3g
```

**For exFAT:**
```bash
opkg install kmod-fs-exfat exfat-utils
```

### Auto-Mount USB Drives

**Install block-mount:**
```bash
opkg update
opkg install block-mount kmod-usb-storage
```

**Enable auto-mount:**
```bash
uci set fstab.@global[0].anon_mount='1'
uci commit fstab
/etc/init.d/fstab enable
/etc/init.d/fstab start
```

### Manual Mount

```bash
# Create mount point
mkdir -p /mnt/usb

# List available devices
block info

# Mount device
mount /dev/sda1 /mnt/usb

# Unmount
umount /mnt/usb
```

### Permanent Mount in fstab

```bash
uci add fstab mount
uci set fstab.@mount[-1].enabled='1'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].target='/mnt/usb'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].options='rw,sync'
uci commit fstab
/etc/init.d/fstab restart
```

### USB Storage as Root Overlay

**Expand root filesystem to USB drive (requires extroot):**
```bash
opkg update
opkg install block-mount kmod-fs-ext4 e2fsprogs

# Format USB drive
mkfs.ext4 /dev/sda1

# Mount temporarily
mount /dev/sda1 /mnt

# Copy root filesystem
tar -C /overlay -cvf - . | tar -C /mnt -xf -

# Configure extroot
uci add fstab mount
uci set fstab.@mount[-1].target='/overlay'
uci set fstab.@mount[-1].device='/dev/sda1'
uci set fstab.@mount[-1].fstype='ext4'
uci set fstab.@mount[-1].enabled='1'
uci commit fstab

# Reboot to activate
reboot
```

---

## Advanced Features

### TTL Manipulation (TTL+1)

**Use case:** Some ISPs detect tethering by TTL values. Incrementing TTL can bypass detection.

**For older iptables versions:**
```bash
# Add to /etc/firewall.user
cat >> /etc/firewall.user << 'EOF'
iptables -t mangle -A POSTROUTING -o pppoe-wan -j TTL --ttl-inc 1
iptables -t mangle -A PREROUTING -i pppoe-wan -j TTL --ttl-inc 1
EOF

/etc/init.d/firewall restart
```

**For newer iptables versions:**
```bash
cat >> /etc/firewall.user << 'EOF'
iptables -t mangle -A POSTROUTING -j TTL --ttl-set 65
EOF

/etc/init.d/firewall restart
```

### Flow Offloading (Hardware NAT)

**For kernel 4.14 and newer (significant performance boost):**

```bash
# Install package
opkg update
opkg install kmod-ipt-offload

# Enable software flow offloading
uci set firewall.@defaults[0].flow_offloading='1'

# Enable hardware flow offloading (if supported)
uci set firewall.@defaults[0].flow_offloading_hw='1'

uci commit firewall
/etc/init.d/firewall restart
```

**Performance impact:**
- **Without offloading**: ~100-300 Mbps on typical routers
- **Software offloading**: ~400-700 Mbps
- **Hardware offloading**: ~900+ Mbps (on supported hardware)

**Check if flow offloading is working:**
```bash
cat /proc/sys/net/netfilter/nf_conntrack_tcp_timeout_established
# Should show reduced value when offloading is active

# View offloaded connections
cat /proc/net/nf_conntrack | grep OFFLOAD
```

### QoS (Quality of Service)

**Install SQM (Smart Queue Management):**
```bash
opkg update
opkg install sqm-scripts luci-app-sqm

# Configure via LuCI web interface at:
# Network → SQM QoS
```

**Basic SQM configuration via CLI:**
```bash
uci set sqm.eth1=queue
uci set sqm.eth1.enabled='1'
uci set sqm.eth1.interface='eth1'
uci set sqm.eth1.download='50000'  # Download speed in kbps
uci set sqm.eth1.upload='10000'    # Upload speed in kbps
uci set sqm.eth1.script='simple.qos'
uci set sqm.eth1.qdisc='cake'
uci commit sqm
/etc/init.d/sqm restart
```

### Dynamic DNS (DDNS)

```bash
opkg update
opkg install ddns-scripts luci-app-ddns

# Example: No-IP configuration
uci set ddns.myddns=service
uci set ddns.myddns.enabled='1'
uci set ddns.myddns.service_name='noip.com'
uci set ddns.myddns.domain='myhostname.ddns.net'
uci set ddns.myddns.username='myusername'
uci set ddns.myddns.password='mypassword'
uci set ddns.myddns.interface='wan'
uci commit ddns
/etc/init.d/ddns start
```

### VPN Client (OpenVPN)

```bash
opkg update
opkg install openvpn-openssl luci-app-openvpn

# Copy VPN config file
scp myvpn.ovpn root@192.168.1.1:/etc/openvpn/

# Start VPN
openvpn --config /etc/openvpn/myvpn.ovpn &
```

### AdBlock (DNS-based ad blocking)

```bash
opkg update
opkg install adblock luci-app-adblock

# Enable adblock
uci set adblock.global.adb_enabled='1'
uci commit adblock
/etc/init.d/adblock start
```

---

## Service Management

### Common Service Commands

```bash
# Start service
/etc/init.d/<service> start

# Stop service
/etc/init.d/<service> stop

# Restart service
/etc/init.d/<service> restart

# Reload configuration (without full restart)
/etc/init.d/<service> reload

# Enable service at boot
/etc/init.d/<service> enable

# Disable service at boot
/etc/init.d/<service> disable

# Check service status
/etc/init.d/<service> status
```

### Common Services

| Service | Description |
|---------|-------------|
| `network` | Network interfaces |
| `dnsmasq` | DHCP and DNS server |
| `firewall` | Firewall rules |
| `dropbear` | SSH server |
| `uhttpd` | Web server (LuCI) |
| `odhcpd` | IPv6 DHCP server |
| `cron` | Scheduled tasks |
| `log` | System logging |

### List All Services

```bash
ls /etc/init.d/
```

### View Service Logs

```bash
# System log
logread

# Follow log in real-time
logread -f

# Kernel messages
dmesg

# Specific service (if it logs to file)
tail -f /var/log/messages
```

---

## Troubleshooting

### Network Issues

**Check interface status:**
```bash
ifstatus wan
ifstatus lan
ip addr show
```

**Check routing table:**
```bash
ip route show
route -n
```

**Test connectivity:**
```bash
ping 8.8.8.8           # Test internet
ping 192.168.1.1       # Test gateway
ping google.com        # Test DNS resolution
```

**Restart networking:**
```bash
/etc/init.d/network restart
```

### WiFi Issues

**Check WiFi status:**
```bash
wifi status
iwinfo
iw dev wlan0 info
```

**Restart WiFi:**
```bash
wifi down
wifi up
```

**Check wireless drivers:**
```bash
lsmod | grep -i wifi
dmesg | grep -i wifi
```

**Scan for interference:**
```bash
iwinfo wlan0 scan
iw dev wlan0 scan
```

### DHCP Issues

**Check DHCP leases:**
```bash
cat /tmp/dhcp.leases
```

**Restart DHCP server:**
```bash
/etc/init.d/dnsmasq restart
```

**Check dnsmasq logs:**
```bash
logread | grep dnsmasq
```

### Firewall Issues

**Check firewall rules:**
```bash
iptables -L -v -n
iptables -t nat -L -v -n
```

**Temporarily disable firewall (for testing):**
```bash
/etc/init.d/firewall stop
```

**Restart firewall:**
```bash
/etc/init.d/firewall restart
```

### Reset to Defaults

**Reset network settings:**
```bash
uci revert network
uci commit network
/etc/init.d/network restart
```

**Full factory reset (erase all settings):**
```bash
firstboot
reboot
```

**Note:** Factory reset will delete all configuration and installed packages.

### Recovery Mode (Failsafe)

If you lose access to the router:

1. Power off the router
2. Power on and **immediately** press the reset button repeatedly
3. Wait for LED to flash rapidly (failsafe mode)
4. Connect to router via Ethernet
5. Access router at `192.168.1.1` (no password)
6. Run `mount_root` to access filesystem
7. Fix configuration or run `firstboot` to reset

### Package Installation Issues

**Update package list:**
```bash
opkg update
```

**Check available space:**
```bash
df -h
```

**Clear opkg cache:**
```bash
rm /var/opkg-lists/*
opkg update
```

**Force reinstall package:**
```bash
opkg remove <package>
opkg install <package>
```

### Performance Issues

**Check CPU and memory:**
```bash
top
cat /proc/cpuinfo
free
```

**Check connection count:**
```bash
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max
```

**Increase connection tracking table size:**
```bash
echo 65536 > /proc/sys/net/netfilter/nf_conntrack_max
```

**To make permanent, add to `/etc/sysctl.conf`:**
```bash
echo "net.netfilter.nf_conntrack_max=65536" >> /etc/sysctl.conf
```

### Web Interface (LuCI) Issues

**Restart web server:**
```bash
/etc/init.d/uhttpd restart
```

**Clear browser cache and cookies**

**Reset admin password:**
```bash
passwd root
```

**Reinstall LuCI:**
```bash
opkg update
opkg remove luci
opkg install luci
```

---

## Best Practices

### Security

1. **Change default password immediately:**
   ```bash
   passwd root
   ```

2. **Disable SSH on WAN:**
   ```bash
   uci set dropbear.@dropbear[0].Interface='lan'
   uci commit dropbear
   /etc/init.d/dropbear restart
   ```

3. **Use SSH keys instead of passwords:**
   ```bash
   # On your computer, copy public key
   cat ~/.ssh/id_rsa.pub

   # On router, add to authorized_keys
   echo "ssh-rsa AAAA..." >> /etc/dropbear/authorized_keys
   chmod 600 /etc/dropbear/authorized_keys

   # Disable password authentication
   uci set dropbear.@dropbear[0].PasswordAuth='off'
   uci commit dropbear
   /etc/init.d/dropbear restart
   ```

4. **Keep firmware updated:**
   ```bash
   opkg update
   opkg list-upgradable
   opkg upgrade <package>
   ```

5. **Use WPA2/WPA3 encryption** for WiFi (never WEP or open)

6. **Enable firewall** (enabled by default, but verify)

### Performance

1. **Enable flow offloading** for faster NAT performance
2. **Use SQM/QoS** to prevent bufferbloat
3. **Optimize WiFi channels** to avoid interference
4. **Disable unused services** to save resources
5. **Use external storage** for logs and packages on low-memory devices

### Maintenance

1. **Backup configuration regularly:**
   ```bash
   sysupgrade -b /tmp/backup-$(date +%Y%m%d).tar.gz
   ```

2. **Monitor system logs:**
   ```bash
   logread -f
   ```

3. **Check for package updates:**
   ```bash
   opkg update
   opkg list-upgradable
   ```

4. **Document custom configurations** in `/etc/config/` files with comments

5. **Test configuration changes** before rebooting in production

---

## Quick Reference

### Essential UCI Commands

```bash
uci show <config>                      # Show all settings
uci get <config>.<section>.<option>    # Read value
uci set <config>.<section>.<option>=<value>  # Set value
uci add <config> <type>                # Add section
uci delete <config>.<section>          # Delete section
uci commit <config>                    # Save changes
uci changes                            # Show uncommitted changes
uci revert <config>                    # Discard changes
```

### Essential Network Commands

```bash
ifconfig                    # Show network interfaces
ip addr show                # Show IP addresses
ip route show               # Show routing table
ping <host>                 # Test connectivity
traceroute <host>           # Trace route to host
nslookup <domain>           # DNS lookup
iwinfo                      # WiFi information
wifi                        # Restart WiFi
/etc/init.d/network restart # Restart networking
```

### Essential File Locations

```bash
/etc/config/                # UCI configuration files
/etc/config/network         # Network configuration
/etc/config/wireless        # WiFi configuration
/etc/config/dhcp            # DHCP and DNS configuration
/etc/config/firewall        # Firewall rules
/etc/config/system          # System settings
/etc/firewall.user          # Custom firewall rules
/etc/hosts                  # Local DNS records
/etc/ethers                 # Static DHCP leases
/tmp/dhcp.leases            # Active DHCP leases
```

---

## Additional Resources

- **Official Documentation**: https://openwrt.org/docs/start
- **UCI Documentation**: https://openwrt.org/docs/guide-user/base-system/uci
- **Network Configuration**: https://openwrt.org/docs/guide-user/network/start
- **Wireless Configuration**: https://openwrt.org/docs/guide-user/network/wifi/start
- **Package Repository**: https://openwrt.org/packages/start
- **OpenWrt Forum**: https://forum.openwrt.org/

---

**Document Version:** 1.0
**Last Updated:** 2025-10-25
**Based on:** https://eko.one.pl/?p=openwrt-konfiguracja (Polish original)
**License:** CC BY-SA 4.0
