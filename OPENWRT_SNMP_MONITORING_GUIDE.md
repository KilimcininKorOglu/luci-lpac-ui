# OpenWRT SNMP Monitoring Guide

## Table of Contents
1. [Overview](#overview)
2. [SNMP Protocol Background](#snmp-protocol-background)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Starting the Service](#starting-the-service)
6. [Testing SNMP](#testing-snmp)
7. [Monitored Parameters](#monitored-parameters)
8. [Remote Access Configuration](#remote-access-configuration)
9. [Monitoring Tools Integration](#monitoring-tools-integration)
10. [Advanced Configuration](#advanced-configuration)
11. [Security Considerations](#security-considerations)
12. [Troubleshooting](#troubleshooting)
13. [Use Cases](#use-cases)

---

## Overview

SNMP (Simple Network Management Protocol) enables network administrators to monitor and manage network devices remotely. This guide covers implementing SNMP monitoring on OpenWRT routers using `mini_snmpd`, a lightweight SNMP daemon optimized for embedded systems.

### What is SNMP?

SNMP is an Internet-standard protocol for:
- **Monitoring** network devices (routers, switches, servers, printers)
- **Collecting** performance metrics (traffic, CPU, memory, uptime)
- **Alerting** on threshold violations
- **Managing** device configurations remotely

### Why Use SNMP on OpenWRT?

- ✅ **Centralized Monitoring**: Track multiple routers from single dashboard
- ✅ **Performance Analysis**: Historical data for capacity planning
- ✅ **Proactive Alerting**: Detect issues before users complain
- ✅ **Integration**: Works with enterprise monitoring systems
- ✅ **Lightweight**: Minimal resource usage with mini_snmpd
- ✅ **Standardized**: Compatible with all SNMP monitoring tools

### Guide Validation

This guide is tested and verified on:
- OpenWRT 19.07 (Chaos Calmer)
- OpenWRT 21.02
- OpenWRT 22.03
- OpenWRT 23.05

---

## SNMP Protocol Background

### SNMP Versions

| Version | Features | Security | Usage |
|---------|----------|----------|-------|
| SNMPv1 | Basic monitoring | Community strings (plain text) | Legacy |
| SNMPv2c | Bulk operations, 64-bit counters | Community strings (plain text) | Common |
| SNMPv3 | Full protocol | Authentication + Encryption | Enterprise |

**mini_snmpd supports SNMPv1 and SNMPv2c** (SNMPv3 not available in mini version)

### SNMP Architecture

```
┌─────────────────┐         SNMP Request          ┌──────────────┐
│  SNMP Manager   │ ─────────────────────────────> │ SNMP Agent   │
│  (Monitoring    │                                 │ (OpenWRT     │
│   Server)       │ <───────────────────────────── │  Router)     │
└─────────────────┘         SNMP Response          └──────────────┘
                                                           │
                                                           ▼
                                                    ┌──────────────┐
                                                    │     MIB      │
                                                    │ (Management  │
                                                    │  Database)   │
                                                    └──────────────┘
```

### Key Concepts

**SNMP Manager (NMS - Network Management System):**
- Monitoring server that polls devices
- Examples: Nagios, Cacti, Zabbix, PRTG

**SNMP Agent:**
- Service running on monitored device (OpenWRT router)
- Responds to manager requests
- `mini_snmpd` on OpenWRT

**MIB (Management Information Base):**
- Database of monitored parameters
- Organized in hierarchical tree structure
- Each parameter has unique OID (Object Identifier)

**OID (Object Identifier):**
- Unique numeric identifier for each parameter
- Example: `1.3.6.1.2.1.1.1.0` = System Description

**Community String:**
- Password-like string for authentication
- Default: `public` (read-only)
- Transmitted in plain text (security consideration)

### SNMP Port

- **UDP Port 161**: Standard SNMP port
- **UDP Port 162**: SNMP Trap port (for alerts)

---

## Installation

### Prerequisites

Ensure your OpenWRT router has:
- Internet connectivity
- Sufficient storage (mini_snmpd is small: ~50KB)
- Available memory (minimal: ~1-2MB RAM)

### Install mini_snmpd

```bash
# Update package lists
opkg update

# Install mini_snmpd
opkg install mini_snmpd

# Verify installation
opkg list-installed | grep snmp
# Output: mini_snmpd - 1.4-2020-09-07-2
```

### Why mini_snmpd?

**mini_snmpd** is designed for embedded systems:
- **Tiny footprint**: ~50KB package size
- **Low memory**: Uses 1-2MB RAM
- **No MIB files**: Reduces storage requirements
- **Read-only**: Cannot change router configuration via SNMP
- **Essential metrics**: Covers 95% of monitoring needs

**Alternative: net-snmp** (not recommended for OpenWRT):
- Full-featured SNMP daemon
- Large footprint: 2-5MB+ package
- Higher memory usage: 5-10MB+ RAM
- Includes MIB compiler and tools
- Only needed for advanced features

---

## Configuration

### Configuration Methods

OpenWRT provides two configuration methods:

1. **UCI (Unified Configuration Interface)** - Recommended
2. **Direct file editing** - Alternative

### Method 1: UCI Configuration (Recommended)

```bash
# Enable mini_snmpd
uci set mini_snmpd.@mini_snmpd[0].enabled='1'

# Set community string (default: public)
uci set mini_snmpd.@mini_snmpd[0].community='public'

# Set contact information
uci set mini_snmpd.@mini_snmpd[0].contact='admin@example.com'

# Set location
uci set mini_snmpd.@mini_snmpd[0].location='Server Room Rack 3'

# Set listening interfaces
# Listen on all interfaces (default)
uci set mini_snmpd.@mini_snmpd[0].interfaces='br-lan'

# Add disks to monitor (optional)
uci add_list mini_snmpd.@mini_snmpd[0].disks='/tmp'
uci add_list mini_snmpd.@mini_snmpd[0].disks='/overlay'

# Commit changes
uci commit mini_snmpd
```

### Method 2: Direct File Editing

Edit `/etc/config/mini_snmpd`:

```bash
config mini_snmpd
    option enabled '1'
    option community 'public'
    option contact 'admin@example.com'
    option location 'Server Room Rack 3'
    option interfaces 'br-lan'
    list disks '/tmp'
    list disks '/overlay'
```

### Configuration Options Explained

**enabled** (`0` or `1`):
- Enable or disable the SNMP daemon
- Default: `0` (disabled)

**community** (string):
- SNMP community string (read-only password)
- Default: `public`
- **Security**: Change this for production!

**contact** (string):
- Administrator contact information
- Returned in SNMP system information
- Example: Email, phone, name

**location** (string):
- Physical location of device
- Useful for large deployments
- Example: "Building A, Floor 2, Room 201"

**interfaces** (interface name):
- Network interface mini_snmpd listens on
- Default: `br-lan` (LAN bridge)
- Multiple interfaces: Space-separated
- Use `*` for all interfaces (security risk!)

**disks** (list of paths):
- Filesystem paths to monitor for disk usage
- Common paths:
  - `/tmp` - Temporary files
  - `/overlay` - Persistent storage
  - `/mnt/usb` - USB storage

### Example Configurations

**Basic Configuration:**
```bash
uci set mini_snmpd.@mini_snmpd[0].enabled='1'
uci set mini_snmpd.@mini_snmpd[0].community='public'
uci commit mini_snmpd
```

**Production Configuration:**
```bash
uci set mini_snmpd.@mini_snmpd[0].enabled='1'
uci set mini_snmpd.@mini_snmpd[0].community='MySecretString123'
uci set mini_snmpd.@mini_snmpd[0].contact='netadmin@company.com'
uci set mini_snmpd.@mini_snmpd[0].location='HQ DataCenter Rack12'
uci set mini_snmpd.@mini_snmpd[0].interfaces='br-lan'
uci add_list mini_snmpd.@mini_snmpd[0].disks='/overlay'
uci commit mini_snmpd
```

**Multi-Interface Configuration:**
```bash
# Listen on LAN and specific VLAN
uci set mini_snmpd.@mini_snmpd[0].interfaces='br-lan br-vlan10'
uci commit mini_snmpd
```

---

## Starting the Service

### Enable and Start mini_snmpd

```bash
# Enable service (start on boot)
/etc/init.d/mini_snmpd enable

# Start service now
/etc/init.d/mini_snmpd start

# Check service status
/etc/init.d/mini_snmpd status
# Output: running
```

### Service Management Commands

```bash
# Start service
/etc/init.d/mini_snmpd start

# Stop service
/etc/init.d/mini_snmpd stop

# Restart service (after config changes)
/etc/init.d/mini_snmpd restart

# Reload configuration
/etc/init.d/mini_snmpd reload

# Enable (start on boot)
/etc/init.d/mini_snmpd enable

# Disable (don't start on boot)
/etc/init.d/mini_snmpd disable

# Check status
/etc/init.d/mini_snmpd status
```

### Verify Service is Running

```bash
# Check process
ps | grep mini_snmpd
# Output: 12345 root      1328 S    /usr/bin/mini_snmpd

# Check listening port
netstat -anup | grep 161
# Output: udp        0      0 0.0.0.0:161             0.0.0.0:*                           12345/mini_snmpd

# Or with ss (modern alternative)
ss -anup | grep 161
```

---

## Testing SNMP

### Testing from OpenWRT Router Itself

```bash
# Install snmpwalk utility (if not present)
opkg install snmpwalk

# Test SNMP locally
snmpwalk -v 2c -c public localhost
# Should output all available SNMP data
```

### Testing from Remote Computer

**On Linux/Mac:**

```bash
# Install SNMP tools
# Debian/Ubuntu:
sudo apt-get install snmp snmp-mibs-downloader

# RHEL/CentOS:
sudo yum install net-snmp-utils

# Mac (with Homebrew):
brew install net-snmp

# Test SNMP connection
snmpwalk -v 2c -c public 192.168.1.1
# Replace 192.168.1.1 with your router IP
```

**On Windows:**

Download and install:
- **Net-SNMP for Windows**: http://www.net-snmp.org/download.html
- Or use **SNMP Tester**: https://www.paessler.com/tools/snmptester

```cmd
# Test from Windows command prompt
snmpwalk -v 2c -c public 192.168.1.1
```

### Quick SNMP Test Commands

```bash
# Get system description
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.1.0

# Get system uptime
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.3.0

# Get hostname
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.5.0

# Walk entire tree
snmpwalk -v 2c -c public 192.168.1.1
```

---

## Monitored Parameters

mini_snmpd provides comprehensive monitoring data:

### System Information

**OID: 1.3.6.1.2.1.1.x**

```bash
# System Description
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.1.0
# Example: Linux OpenWrt 5.4.143 #0 SMP Thu Aug 5 10:22:13 2021 mips

# System Uptime (in 1/100th seconds)
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.3.0
# Example: 123456789 (converts to ~14 days)

# System Contact
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.4.0
# Example: admin@example.com

# System Hostname
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.5.0
# Example: OpenWrt

# System Location
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.1.6.0
# Example: Server Room Rack 3
```

### Network Interfaces

**OID: 1.3.6.1.2.1.2.2.1.x**

```bash
# List all interfaces
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.2
# Output:
# IF-MIB::ifDescr.1 = STRING: lo
# IF-MIB::ifDescr.2 = STRING: eth0
# IF-MIB::ifDescr.3 = STRING: br-lan
# IF-MIB::ifDescr.4 = STRING: wlan0

# Interface status (1=up, 2=down)
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.8

# Interface speed (bits per second)
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.5

# Bytes IN
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.10

# Bytes OUT
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.16
```

**Example output:**
```
IF-MIB::ifInOctets.3 = Counter32: 4567890123
IF-MIB::ifOutOctets.3 = Counter32: 9876543210
```

### Traffic Statistics per Interface

```bash
# br-lan interface (typically interface 3)
# Incoming bytes
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.10.3
# Outgoing bytes
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.16.3

# Incoming packets
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.11.3
# Outgoing packets
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.17.3

# Incoming errors
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.14.3
# Outgoing errors
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.20.3

# Incoming discards
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.13.3
# Outgoing discards
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.2.1.2.2.1.19.3
```

### Memory Statistics

**OID: 1.3.6.1.4.1.2021.4.x**

```bash
# Total RAM (KB)
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.4.5.0

# Free RAM (KB)
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.4.6.0

# Total Swap (KB)
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.4.3.0

# Free Swap (KB)
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.4.4.0

# Cached memory (KB)
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.4.15.0

# Memory buffers (KB)
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.4.14.0
```

**Example output:**
```
UCD-SNMP-MIB::memTotalReal.0 = INTEGER: 131072 KB
UCD-SNMP-MIB::memAvailReal.0 = INTEGER: 45678 KB
UCD-SNMP-MIB::memCached.0 = INTEGER: 23456 KB
```

### CPU Load Average

**OID: 1.3.6.1.4.1.2021.10.1.3.x**

```bash
# 1-minute load average
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.10.1.3.1

# 5-minute load average
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.10.1.3.2

# 15-minute load average
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.10.1.3.3
```

**Example output:**
```
UCD-SNMP-MIB::laLoad.1 = STRING: 0.15
UCD-SNMP-MIB::laLoad.2 = STRING: 0.23
UCD-SNMP-MIB::laLoad.3 = STRING: 0.31
```

### Disk Usage

**OID: 1.3.6.1.4.1.2021.9.1.x**

```bash
# List monitored disks
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.9.1.2

# Total disk size (KB)
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.9.1.6

# Used disk space (KB)
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.9.1.8

# Available disk space (KB)
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.9.1.7

# Percentage used
snmpwalk -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.9.1.9
```

**Example output:**
```
UCD-SNMP-MIB::dskPath.1 = STRING: /tmp
UCD-SNMP-MIB::dskTotal.1 = INTEGER: 62464 KB
UCD-SNMP-MIB::dskUsed.1 = INTEGER: 1234 KB
UCD-SNMP-MIB::dskAvail.1 = INTEGER: 61230 KB
UCD-SNMP-MIB::dskPercent.1 = INTEGER: 2
```

### Process Statistics

```bash
# Number of running processes
snmpget -v 2c -c public 192.168.1.1 1.3.6.1.4.1.2021.2.1.5.0
```

---

## Remote Access Configuration

By default, mini_snmpd listens only on LAN interface. For remote monitoring:

### Firewall Configuration

**Option 1: Allow SNMP from Specific Monitoring Server**

```bash
# Allow SNMP from monitoring server IP
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SNMP-Monitoring'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].src_ip='203.0.113.10'  # Monitoring server IP
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='161'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

**Option 2: Allow SNMP from Network Range**

```bash
# Allow SNMP from specific subnet
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SNMP-Subnet'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].src_ip='203.0.113.0/24'  # Monitoring subnet
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='161'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

**Option 3: Port Forwarding from WAN**

```bash
# Configure mini_snmpd to listen on all interfaces
uci set mini_snmpd.@mini_snmpd[0].interfaces='*'
uci commit mini_snmpd
/etc/init.d/mini_snmpd restart

# Add firewall rule
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SNMP-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='161'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
/etc/init.d/firewall restart
```

### Security Warning

⚠️ **Never open SNMP to the entire Internet without proper security:**
- Use strong community strings (not "public")
- Restrict by source IP
- Consider VPN for remote access
- Use firewall rules to limit access
- SNMPv1/v2c sends credentials in plain text

### Recommended: VPN Access

Instead of exposing SNMP to WAN, use VPN:

```bash
# Install WireGuard or OpenVPN
opkg install wireguard luci-proto-wireguard

# Configure VPN (see OpenWRT VPN guide)
# Access SNMP over VPN tunnel (encrypted)
```

---

## Monitoring Tools Integration

### Nagios

**Install SNMP plugin:**
```bash
# On Nagios server
apt-get install nagios-plugins-snmp
```

**Configure host:**
```bash
# /etc/nagios/objects/openwrt.cfg
define host {
    use                     linux-server
    host_name               openwrt-router
    alias                   OpenWRT Router
    address                 192.168.1.1
}

define service {
    use                     generic-service
    host_name               openwrt-router
    service_description     SNMP Uptime
    check_command           check_snmp!-C public -o 1.3.6.1.2.1.1.3.0
}

define service {
    use                     generic-service
    host_name               openwrt-router
    service_description     SNMP Memory Usage
    check_command           check_snmp!-C public -o 1.3.6.1.4.1.2021.4.6.0 -w 10000: -c 5000:
}
```

### Cacti

1. **Add device in Cacti web interface:**
   - Console → Devices → Add
   - Hostname: 192.168.1.1
   - SNMP Version: 2
   - SNMP Community: public

2. **Create graphs:**
   - Select device
   - Create Graphs → Select templates
   - Choose: Interface Traffic, CPU Usage, Memory Usage

3. **Templates available:**
   - Interface - Traffic
   - ucd/net - CPU Usage
   - ucd/net - Memory Usage
   - ucd/net - Load Average

### Zabbix

**Add host:**
```bash
# Configuration → Hosts → Create host
Host name: openwrt-router
Groups: Linux servers
Interfaces: SNMP
  IP address: 192.168.1.1
  Port: 161
  SNMP version: SNMPv2
  SNMP community: {$SNMP_COMMUNITY}
```

**Link templates:**
- Template Net Network Generic Device SNMPv2
- Template Module Linux CPU SNMPv2
- Template Module Linux memory SNMPv2

### MRTG (Multi Router Traffic Grapher)

**Configuration file:**
```bash
# /etc/mrtg/mrtg.cfg
WorkDir: /var/www/mrtg
Options[_]: growright,bits

# OpenWRT Router - br-lan interface
Target[router.lan]: 3:public@192.168.1.1:
MaxBytes[router.lan]: 1250000000
Title[router.lan]: OpenWRT LAN Traffic
PageTop[router.lan]: <h1>OpenWRT LAN Interface</h1>
```

### Prometheus with SNMP Exporter

**snmp.yml configuration:**
```yaml
auths:
  public_v2:
    community: public
    security_level: noAuthNoPriv
    auth_protocol: MD5
    priv_protocol: DES
    version: 2

modules:
  openwrt:
    walk:
      - 1.3.6.1.2.1.1      # System info
      - 1.3.6.1.2.1.2      # Interfaces
      - 1.3.6.1.4.1.2021   # UCD-SNMP-MIB
```

**Prometheus config:**
```yaml
scrape_configs:
  - job_name: 'snmp'
    static_configs:
      - targets:
        - 192.168.1.1
    metrics_path: /snmp
    params:
      module: [openwrt]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9116  # SNMP exporter address
```

### collectd

**On OpenWRT:**
```bash
opkg install collectd collectd-mod-snmp

# Edit /etc/collectd.conf
LoadPlugin snmp
<Plugin snmp>
    <Data "std_traffic">
        Type "if_octets"
        Table true
        Instance "IF-MIB::ifDescr"
        Values "IF-MIB::ifInOctets" "IF-MIB::ifOutOctets"
    </Data>
</Plugin>
```

### LibreNMS

1. **Add device in LibreNMS:**
```bash
# Via CLI
./addhost.php openwrt-router public v2c

# Or via web interface:
# Devices → Add Device
```

2. **LibreNMS will auto-discover:**
   - Device type
   - Interfaces
   - Available sensors
   - Create graphs automatically

---

## Advanced Configuration

### Custom Community String

```bash
# Use strong, unique community string
uci set mini_snmpd.@mini_snmpd[0].community='MyStr0ng!SNMP#Pass2024'
uci commit mini_snmpd
/etc/init.d/mini_snmpd restart
```

### Multiple Disk Monitoring

```bash
# Monitor multiple filesystems
uci delete mini_snmpd.@mini_snmpd[0].disks
uci add_list mini_snmpd.@mini_snmpd[0].disks='/overlay'
uci add_list mini_snmpd.@mini_snmpd[0].disks='/tmp'
uci add_list mini_snmpd.@mini_snmpd[0].disks='/mnt/usb'
uci add_list mini_snmpd.@mini_snmpd[0].disks='/mnt/sda1'
uci commit mini_snmpd
/etc/init.d/mini_snmpd restart
```

### Custom SNMP Location and Contact

```bash
# Set detailed location
uci set mini_snmpd.@mini_snmpd[0].location='Building A, Floor 2, Room 201, Rack 5'

# Set multiple contacts
uci set mini_snmpd.@mini_snmpd[0].contact='Primary: admin@example.com, Secondary: ops@example.com, Phone: +1-555-0100'

uci commit mini_snmpd
/etc/init.d/mini_snmpd restart
```

### SNMP Wrapper Script for Custom Metrics

Since mini_snmpd is read-only and doesn't support extending, use external scripts:

```bash
# Create monitoring script
cat > /usr/local/bin/openwrt-stats.sh << 'EOF'
#!/bin/sh

case "$1" in
    temperature)
        # Read CPU temperature (if available)
        cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0"
        ;;
    wifi_clients)
        # Count WiFi clients
        iw dev wlan0 station dump | grep -c "Station"
        ;;
    uptime_seconds)
        # Uptime in seconds
        awk '{print int($1)}' /proc/uptime
        ;;
    connections)
        # Active connections count
        wc -l < /proc/net/nf_conntrack
        ;;
esac
EOF

chmod +x /usr/local/bin/openwrt-stats.sh

# Test
/usr/local/bin/openwrt-stats.sh wifi_clients
```

### Automated Monitoring Script

```bash
cat > /root/snmp-status.sh << 'EOF'
#!/bin/bash

ROUTER_IP="192.168.1.1"
COMMUNITY="public"

echo "=== OpenWRT SNMP Status ==="
echo ""

echo "System Information:"
snmpget -v 2c -c $COMMUNITY $ROUTER_IP 1.3.6.1.2.1.1.5.0 | awk -F': ' '{print "Hostname: " $2}'
snmpget -v 2c -c $COMMUNITY $ROUTER_IP 1.3.6.1.2.1.1.3.0 | awk -F': ' '{print "Uptime: " $2}'

echo ""
echo "Memory Usage:"
TOTAL=$(snmpget -v 2c -c $COMMUNITY $ROUTER_IP 1.3.6.1.4.1.2021.4.5.0 -Oqv)
FREE=$(snmpget -v 2c -c $COMMUNITY $ROUTER_IP 1.3.6.1.4.1.2021.4.6.0 -Oqv)
USED=$((TOTAL - FREE))
PERCENT=$((USED * 100 / TOTAL))
echo "Total: ${TOTAL} KB"
echo "Used: ${USED} KB (${PERCENT}%)"

echo ""
echo "Load Average:"
snmpget -v 2c -c $COMMUNITY $ROUTER_IP 1.3.6.1.4.1.2021.10.1.3.1 -Oqv | awk '{print "1 min: " $1}'
snmpget -v 2c -c $COMMUNITY $ROUTER_IP 1.3.6.1.4.1.2021.10.1.3.2 -Oqv | awk '{print "5 min: " $1}'
snmpget -v 2c -c $COMMUNITY $ROUTER_IP 1.3.6.1.4.1.2021.10.1.3.3 -Oqv | awk '{print "15 min: " $1}'

echo ""
echo "==========================="
EOF

chmod +x /root/snmp-status.sh
```

---

## Security Considerations

### Best Practices

1. **Change Default Community String**
```bash
# Never use "public" in production
uci set mini_snmpd.@mini_snmpd[0].community='ComplexStr1ng!2024#SNMP'
uci commit mini_snmpd
```

2. **Restrict Listening Interface**
```bash
# Only listen on LAN, not WAN
uci set mini_snmpd.@mini_snmpd[0].interfaces='br-lan'
uci commit mini_snmpd
```

3. **Firewall Rules**
```bash
# Only allow from monitoring server
uci add firewall rule
uci set firewall.@rule[-1].name='SNMP-from-Monitor'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].src_ip='192.168.1.100'  # Monitoring server only
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].dest_port='161'
uci set firewall.@rule[-1].target='ACCEPT'
uci commit firewall
```

4. **Use VPN for Remote Access**
   - Don't expose SNMP directly to Internet
   - Use WireGuard or OpenVPN
   - Access via encrypted tunnel

5. **Regular Audits**
```bash
# Check who's accessing SNMP
logread | grep mini_snmpd

# Monitor connection attempts
tcpdump -i any port 161
```

### SNMPv1/v2c Limitations

**Plain Text Transmission:**
- Community strings sent unencrypted
- All SNMP data unencrypted
- Vulnerable to packet sniffing

**Limited Authentication:**
- Single community string
- No user-level access control
- No accounting

**Recommendation:**
- Use only on trusted networks
- Consider VPN for remote access
- Upgrade to SNMPv3 if available (requires net-snmp, not mini_snmpd)

---

## Troubleshooting

### Service Won't Start

**Check configuration:**
```bash
# Validate configuration
uci show mini_snmpd

# Check for syntax errors
/etc/init.d/mini_snmpd restart
logread | grep mini_snmpd
```

**Common issues:**
- Invalid disk paths
- Incorrect interface name
- Syntax errors in config file

### Cannot Connect from Remote Host

**Test locally first:**
```bash
# On router
netstat -anup | grep 161
# Should show mini_snmpd listening

# Test locally
snmpwalk -v 2c -c public localhost
```

**Check firewall:**
```bash
# Verify firewall rules
uci show firewall | grep 161

# Temporarily disable firewall for testing
/etc/init.d/firewall stop
# Test SNMP
# Re-enable firewall
/etc/init.d/firewall start
```

**Check interface binding:**
```bash
# Make sure mini_snmpd listens on correct interface
uci show mini_snmpd.@mini_snmpd[0].interfaces

# For remote access, may need '*'
uci set mini_snmpd.@mini_snmpd[0].interfaces='*'
uci commit mini_snmpd
/etc/init.d/mini_snmpd restart
```

### Timeout Errors

**Increase timeout on client:**
```bash
# Default timeout is 1 second, increase to 5
snmpget -v 2c -c public -t 5 192.168.1.1 1.3.6.1.2.1.1.1.0
```

**Check network connectivity:**
```bash
# Ping router
ping 192.168.1.1

# Check UDP port 161 reachable
nmap -sU -p 161 192.168.1.1
```

### Wrong Community String

**Error message:**
```
Timeout: No Response from 192.168.1.1
```

**Solution:**
```bash
# Verify community string
uci show mini_snmpd.@mini_snmpd[0].community

# Try with correct string
snmpget -v 2c -c YOUR_COMMUNITY 192.168.1.1 1.3.6.1.2.1.1.1.0
```

### OID Not Found

**Some OIDs may not be available in mini_snmpd:**
- Limited MIB support
- Read-only access
- Reduced feature set

**Solution:**
```bash
# Walk entire tree to see available OIDs
snmpwalk -v 2c -c public 192.168.1.1

# Use supported OIDs only
# Refer to "Monitored Parameters" section
```

---

## Use Cases

### Home Network Monitoring

**Scenario:** Monitor home router bandwidth and uptime

```bash
# Configure Cacti or LibreNMS
# Create graphs for:
# - Internet bandwidth usage
# - WiFi clients count
# - Router uptime
# - Memory usage

# Set alerts for:
# - High bandwidth usage (>80%)
# - Router reboot (uptime reset)
# - Low memory (<10MB free)
```

### Small Business Network

**Scenario:** Monitor multiple branch office routers

```bash
# Central monitoring server with Zabbix/Nagios
# Monitor all routers from single dashboard

# Track metrics:
# - WAN uptime and availability
# - Bandwidth usage per location
# - VPN tunnel status
# - Router health (CPU, memory)

# Alerts:
# - Email on router offline
# - SMS on high bandwidth
# - Ticket creation on persistent issues
```

### ISP/MSP Monitoring

**Scenario:** Manage hundreds of customer routers

```bash
# LibreNMS or similar at scale
# Auto-discovery of new routers
# Per-customer dashboards
# Billing integration (bandwidth usage)

# Automation:
# - Auto-provision new routers
# - Collect usage data for billing
# - Proactive issue detection
# - SLA monitoring and reporting
```

### IoT Gateway Monitoring

**Scenario:** Monitor OpenWRT as IoT gateway

```bash
# Track:
# - Connected IoT devices count
# - MQTT traffic statistics
# - Gateway uptime
# - Sensor data forwarding rates

# Integration with:
# - Home Assistant
# - Node-RED
# - InfluxDB + Grafana
```

---

## Conclusion

SNMP monitoring on OpenWRT provides powerful visibility into router performance and network health. Key takeaways:

### Best Practices Summary

✅ **Installation:**
- Use mini_snmpd for resource-constrained devices
- Enable on boot for continuous monitoring

✅ **Configuration:**
- Change default community string
- Set meaningful contact and location
- Monitor relevant disk paths
- Restrict to LAN interface

✅ **Security:**
- Use strong community strings
- Implement firewall rules
- Prefer VPN for remote access
- Never expose to public Internet

✅ **Integration:**
- Choose appropriate monitoring tool (Nagios, Cacti, Zabbix, LibreNMS)
- Create meaningful graphs and alerts
- Document baseline performance
- Set up proactive alerting

✅ **Monitoring Strategy:**
- Track uptime and availability
- Monitor bandwidth utilization
- Watch memory and CPU usage
- Alert on threshold violations
- Regular reporting and analysis

### Available Monitoring Tools

- **Nagios**: Alerting and availability monitoring
- **Cacti**: Performance graphing and trending
- **Zabbix**: Enterprise-scale monitoring
- **LibreNMS**: Auto-discovery and network mapping
- **MRTG**: Simple traffic graphing
- **Prometheus**: Modern metrics collection
- **collectd**: Lightweight stats collection

### Key Metrics to Monitor

1. **Availability**: Uptime, reachability
2. **Performance**: Bandwidth, latency, packet loss
3. **Capacity**: Memory usage, disk space, connections
4. **Health**: CPU load, errors, discards

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-snmp*
*Tested on: OpenWRT 19.07, 21.02, 22.03, 23.05*
