# OpenWRT Guest Network Configuration Guide

## Table of Contents
- [Overview](#overview)
- [What is a Guest Network?](#what-is-a-guest-network)
- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Network Architecture](#network-architecture)
- [Basic Guest Network Setup](#basic-guest-network-setup)
- [Security Enhancements](#security-enhancements)
- [Advanced Features](#advanced-features)
- [Dynamic Password Management](#dynamic-password-management)
- [Bandwidth Limiting](#bandwidth-limiting)
- [Scheduled Availability](#scheduled-availability)
- [Restricted Access](#restricted-access)
- [Welcome Portal Integration](#welcome-portal-integration)
- [Privacy and Anonymity](#privacy-and-anonymity)
- [Management and Monitoring](#management-and-monitoring)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)
- [Real-World Examples](#real-world-examples)

## Overview

This comprehensive guide explains how to set up a guest WiFi network on OpenWRT routers, providing isolated internet access for visitors without sharing your primary network credentials or exposing your internal devices.

**What You'll Learn:**
- Creating isolated guest WiFi networks
- Implementing security measures (encryption, isolation, access control)
- Advanced features (dynamic passwords, bandwidth limits, scheduling)
- Portal integration for terms/conditions
- Privacy enhancements (MAC masking, Tor routing)

**Key Benefits:**
- Protect your primary network from guest devices
- Share internet without sharing passwords
- Control bandwidth usage
- Monitor and limit guest access
- Provide professional guest WiFi experience

## What is a Guest Network?

### Guest Network Basics

A **guest network** is a separate WiFi network that provides internet access to visitors while keeping them isolated from your main network and internal devices.

**Key Characteristics:**
- Separate SSID (network name)
- Isolated from main LAN
- Internet access only
- Optional password protection
- Bandwidth and time controls

### How It Works

**Network Separation:**
```
Main Network (LAN)           Guest Network
192.168.1.0/24              172.16.0.0/12
├── Your Computer           ├── Visitor Phone
├── NAS Storage             ├── Visitor Laptop
├── Smart TV                ├── Visitor Tablet
└── IoT Devices             └── (Internet Only)
    ↓                           ↓
    Full Access             Internet Only
```

**Traffic Flow:**
```
Guest Device
    ↓
Guest WiFi (SSID: Guest)
    ↓
Guest Network Interface (172.16.0.1)
    ↓
Firewall (allows only internet access)
    ↓
WAN Interface
    ↓
Internet
```

### Guest Network vs Regular Network

| Feature | Main Network | Guest Network |
|---------|-------------|---------------|
| Internal Device Access | Yes | No |
| Router Configuration | Yes | No |
| Bandwidth Priority | High | Limited |
| Monitoring | Optional | Recommended |
| Password Sharing | Risky | Safe |
| Security Risk | Low | Isolated |

## Use Cases

### 1. Home Guest WiFi

**Scenario:** Friends and family visit your home

**Configuration:**
- Simple password (daily/weekly rotation optional)
- Limited bandwidth to preserve main network
- No access to home servers, NAS, printers
- Optional time limits (auto-disable late night)

### 2. Small Business Customer WiFi

**Scenario:** Coffee shop, restaurant, waiting room

**Configuration:**
- Open or simple password
- Bandwidth limits per client
- Welcome portal with terms of service
- Usage tracking and statistics
- Scheduled availability (business hours only)

### 3. Vacation Rental Property

**Scenario:** Airbnb, vacation home WiFi for guests

**Configuration:**
- Unique password per booking (automated rotation)
- Bandwidth limits for fair usage
- No access to smart home devices
- Usage logs for troubleshooting
- Remote management capability

### 4. Office Visitor Network

**Scenario:** Corporate guest network for visitors/contractors

**Configuration:**
- WPA2 Enterprise with temporary credentials
- Strict bandwidth and time limits
- No access to corporate network
- Comprehensive logging for compliance
- Content filtering (optional)

### 5. Event/Conference WiFi

**Scenario:** Temporary WiFi for events

**Configuration:**
- Easy-to-share password
- High bandwidth allocation
- Time-limited (event duration only)
- Many simultaneous clients
- Simple connection process

## Prerequisites

### Hardware Requirements

**Minimum:**
- OpenWRT compatible router
- Dual-radio (recommended) or single radio with VAP support
- 8MB flash storage
- 64MB RAM

**Recommended:**
- Dual-band router (2.4GHz + 5GHz)
- 16MB+ flash
- 128MB+ RAM
- Gigabit ports

### Software Requirements

**OpenWRT Version:**
- OpenWRT 18.06 or newer
- Method varies by version (pre/post May 29, 2021)

**Check Version:**
```bash
cat /etc/openwrt_release
# Look for DISTRIB_RELEASE
```

**Required Packages:**
```bash
# Basic setup (usually pre-installed)
opkg update
opkg install kmod-br-netfilter

# Optional packages
opkg install uhttpd                # Web server for password page
opkg install wshaper               # Bandwidth shaping
opkg install nodogsplash           # Captive portal
```

### Knowledge Requirements

- Basic OpenWRT UCI configuration
- SSH access to router
- Understanding of IP addressing
- Basic firewall concepts

## Network Architecture

### Typical Deployment

```
                    Internet
                       |
                   [WAN Port]
                       |
                 [OpenWRT Router]
                   /        \
                  /          \
          [Main Network]  [Guest Network]
          192.168.1.0/24  172.16.0.0/12
          br-lan          br-guest
              |               |
        [LAN Ports]      [Guest WiFi]
              |               |
        Internal         Visitors
        Devices          (Internet Only)
```

### IP Addressing Scheme

**Main Network:**
- Subnet: 192.168.1.0/24
- Router: 192.168.1.1
- DHCP Range: 192.168.1.100-200
- Purpose: Internal trusted devices

**Guest Network:**
- Subnet: 172.16.0.0/12 (large range: 172.16.0.0 - 172.31.255.255)
- Router: 172.16.0.1
- DHCP Range: 172.16.0.100-250
- Purpose: Guest devices (internet only)

**Why 172.16.0.0/12?**
- Large private range (1,048,576 addresses)
- Avoids conflicts with common home networks (192.168.x.x)
- Room for future expansion
- RFC 1918 private address space

### Alternative Addressing Schemes

**Small Guest Network:**
```bash
# If you need only a few guests
Subnet: 10.20.30.0/24
Router: 10.20.30.1
DHCP: 10.20.30.100-150
```

**Medium Guest Network:**
```bash
# More guests, avoid 192.168.x.x
Subnet: 192.168.5.0/24
Router: 192.168.5.1
DHCP: 192.168.5.100-250
```

**Large Guest Network:**
```bash
# Many guests, large events
Subnet: 172.16.0.0/12
Router: 172.16.0.1
DHCP: 172.16.0.100-65000
```

## Basic Guest Network Setup

The setup process differs based on your OpenWRT version.

### Check Your OpenWRT Version

```bash
# Check release date
cat /etc/openwrt_release | grep DISTRIB_RELEASE

# If 21.02-rc2 or newer (after May 29, 2021): Use Method 2
# If 18.06, 19.07, early 21.02: Use Method 1
```

### Method 1: OpenWRT 18.06 - 21.02 (before May 29, 2021)

**Complete Setup Script:**

```bash
#!/bin/sh
# Guest Network Setup - Method 1 (older versions)

echo "Setting up Guest Network..."

# Create guest network interface
uci set network.guest=interface
uci set network.guest.proto='static'
uci set network.guest.ipaddr='172.16.0.1'
uci set network.guest.netmask='255.240.0.0'  # /12 subnet
uci set network.guest.type='bridge'

# Configure DHCP for guest network
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface='guest'
uci set dhcp.guest.start='100'
uci set dhcp.guest.limit='150'
uci set dhcp.guest.leasetime='2h'

# Create guest WiFi interface (2.4GHz)
uci set wireless.guest_radio0=wifi-iface
uci set wireless.guest_radio0.device='radio0'
uci set wireless.guest_radio0.mode='ap'
uci set wireless.guest_radio0.network='guest'
uci set wireless.guest_radio0.ssid='GuestWiFi'
uci set wireless.guest_radio0.encryption='psk2'
uci set wireless.guest_radio0.key='GuestPassword123'
uci set wireless.guest_radio0.isolate='1'  # Client isolation

# Enable radio if disabled
uci set wireless.radio0.disabled='0'

# Create guest firewall zone
uci add firewall zone
uci set firewall.@zone[-1].name='guest'
uci set firewall.@zone[-1].input='REJECT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='REJECT'
uci add_list firewall.@zone[-1].network='guest'

# Allow guest to WAN
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'

# Allow DHCP
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DHCP-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='67-68'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].family='ipv4'

# Allow DNS
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DNS-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='tcpudp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].family='ipv4'

# Commit all changes
uci commit

echo "Guest network configured. Rebooting..."
reboot
```

### Method 2: OpenWRT 21.02+ (after May 29, 2021)

**Complete Setup Script:**

```bash
#!/bin/sh
# Guest Network Setup - Method 2 (21.02+)

echo "Setting up Guest Network (21.02+ method)..."

# Create bridge device first
uci add network device
uci set network.@device[-1].name='br-guest'
uci set network.@device[-1].type='bridge'
uci set network.@device[-1].bridge_empty='1'

# Create guest network interface
uci set network.guest=interface
uci set network.guest.proto='static'
uci set network.guest.device='br-guest'
uci set network.guest.ipaddr='172.16.0.1'
uci set network.guest.netmask='255.240.0.0'  # /12 subnet

# Configure DHCP
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface='guest'
uci set dhcp.guest.start='100'
uci set dhcp.guest.limit='150'
uci set dhcp.guest.leasetime='2h'

# Create guest WiFi interface (2.4GHz)
uci set wireless.guest_radio0=wifi-iface
uci set wireless.guest_radio0.device='radio0'
uci set wireless.guest_radio0.mode='ap'
uci set wireless.guest_radio0.network='guest'
uci set wireless.guest_radio0.ssid='GuestWiFi'
uci set wireless.guest_radio0.encryption='psk2'
uci set wireless.guest_radio0.key='GuestPassword123'
uci set wireless.guest_radio0.isolate='1'

# Enable radio
uci set wireless.radio0.disabled='0'

# Create firewall zone
uci add firewall zone
uci set firewall.@zone[-1].name='guest'
uci set firewall.@zone[-1].input='REJECT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='REJECT'
uci add_list firewall.@zone[-1].network='guest'

# Allow guest → wan
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'

# Allow DHCP
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DHCP-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='67-68'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'

# Allow DNS
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DNS-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='53'
uci set firewall.@rule[-1].proto='tcpudp'
uci set firewall.@rule[-1].target='ACCEPT'

# Commit changes
uci commit

echo "Guest network configured. Rebooting..."
reboot
```

### Manual Configuration via LuCI

**Alternative: Web Interface Setup**

1. **Network → Interfaces:**
   - Add New Interface: "guest"
   - Protocol: Static address
   - IPv4 address: 172.16.0.1
   - Netmask: 255.240.0.0
   - (21.02+) Create bridge: br-guest

2. **Network → Wireless:**
   - Add new WiFi network on radio0
   - ESSID: GuestWiFi
   - Network: guest
   - Encryption: WPA2-PSK
   - Key: GuestPassword123
   - Advanced: Enable "Isolate Clients"

3. **Network → DHCP and DNS:**
   - Add DHCP server for guest
   - Start: 100
   - Limit: 150
   - Leasetime: 2h

4. **Network → Firewall:**
   - Add zone: guest
   - Input: reject
   - Output: accept
   - Forward: reject
   - Add forwarding: guest → wan
   - Add rules for DHCP and DNS

### Verification

**After reboot, verify:**

```bash
# Check interfaces
ifconfig br-guest
# Should show: inet addr:172.16.0.1

# Check wireless
iw dev
# Should show guest WiFi interface

# Check firewall
iptables -L -v -n | grep -A 10 guest

# Check DHCP
cat /tmp/dhcp.leases
# Connect a device and check for 172.16.0.x lease

# Test connectivity
# Connect to GuestWiFi
# Should get 172.16.0.x address
# Should be able to ping 8.8.8.8 (internet)
# Should NOT be able to ping 192.168.1.x (main LAN)
```

## Security Enhancements

### MAC Address Randomization and Privacy

**Problem:** Google tracks WiFi access points by MAC addresses for geolocation.

**Solutions:**

**Option 1: Disable MAC-based geolocation (Add _nomap to SSID)**
```bash
# Append _nomap to SSID to opt-out of Google geolocation
uci set wireless.guest_radio0.ssid='GuestWiFi_nomap'
uci commit wireless
wifi
```

**Option 2: Enable MAC address randomization**
```bash
# Some clients support MAC randomization
# This is client-side setting, but inform users to enable it
# iOS: Settings → WiFi → Private Address
# Android: WiFi Settings → Privacy → Use randomized MAC
```

### Prevent Router Access from Guest Network

**Block access to router management:**

```bash
# Change guest zone to be more restrictive
uci set firewall.@zone[-1].input='REJECT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='REJECT'

# Explicitly block access to router
uci add firewall rule
uci set firewall.@rule[-1].name='Block-Router-Access-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_ip='172.16.0.1'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].target='REJECT'

uci commit firewall
/etc/init.d/firewall restart
```

### Client Isolation (Wireless)

**Prevent guests from seeing each other:**

```bash
# Enable client isolation on wireless interface
uci set wireless.guest_radio0.isolate='1'
uci commit wireless
wifi
```

**What this does:**
- Guests can't communicate with each other
- Each guest only has internet access
- No file sharing, AirDrop, or local discovery between guests

### Encryption Options

**WPA2 Personal (Recommended):**
```bash
uci set wireless.guest_radio0.encryption='psk2'
uci set wireless.guest_radio0.key='YourStrongPassword123'
```

**WPA3 Personal (More Secure, if supported):**
```bash
uci set wireless.guest_radio0.encryption='sae'
uci set wireless.guest_radio0.key='YourStrongPassword123'
```

**WPA2/WPA3 Mixed Mode:**
```bash
uci set wireless.guest_radio0.encryption='sae-mixed'
uci set wireless.guest_radio0.key='YourStrongPassword123'
```

**Open Network (No Password):**
```bash
uci set wireless.guest_radio0.encryption='none'
# Not recommended without captive portal
```

### Additional Security Measures

**Disable ping to router:**
```bash
uci add firewall rule
uci set firewall.@rule[-1].name='Block-Ping-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_ip='172.16.0.1'
uci set firewall.@rule[-1].proto='icmp'
uci set firewall.@rule[-1].target='REJECT'
uci commit firewall
/etc/init.d/firewall restart
```

**Block access to local DNS:**
```bash
# Only allow DNS queries, not configuration
# Already handled by input='REJECT' and specific DNS allow rule
```

**Rate limit DHCP requests (prevent DoS):**
```bash
uci set firewall.@rule[-1].name='Limit-DHCP-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_port='67'
uci set firewall.@rule[-1].proto='udp'
uci set firewall.@rule[-1].target='ACCEPT'
uci set firewall.@rule[-1].limit='10/minute'
uci set firewall.@rule[-1].limit_burst='5'
```

## Advanced Features

### Dual-Band Guest Network (2.4GHz + 5GHz)

**Create guest network on both radios:**

```bash
# 2.4GHz guest network (radio0)
uci set wireless.guest_radio0=wifi-iface
uci set wireless.guest_radio0.device='radio0'
uci set wireless.guest_radio0.mode='ap'
uci set wireless.guest_radio0.network='guest'
uci set wireless.guest_radio0.ssid='GuestWiFi'
uci set wireless.guest_radio0.encryption='psk2'
uci set wireless.guest_radio0.key='GuestPassword123'
uci set wireless.guest_radio0.isolate='1'

# 5GHz guest network (radio1)
uci set wireless.guest_radio1=wifi-iface
uci set wireless.guest_radio1.device='radio1'
uci set wireless.guest_radio1.mode='ap'
uci set wireless.guest_radio1.network='guest'
uci set wireless.guest_radio1.ssid='GuestWiFi-5G'
uci set wireless.guest_radio1.encryption='psk2'
uci set wireless.guest_radio1.key='GuestPassword123'
uci set wireless.guest_radio1.isolate='1'

# Enable both radios
uci set wireless.radio0.disabled='0'
uci set wireless.radio1.disabled='0'

uci commit wireless
wifi
```

**Or use same SSID on both bands:**
```bash
# Use identical SSID for seamless roaming
uci set wireless.guest_radio0.ssid='GuestWiFi'
uci set wireless.guest_radio1.ssid='GuestWiFi'
# Devices will automatically choose best band
```

### VLAN-Based Guest Network (Advanced)

**For managed switches with VLAN support:**

```bash
# Create VLAN for guest network
uci set network.@switch_vlan[-1]=switch_vlan
uci set network.@switch_vlan[-1].device='switch0'
uci set network.@switch_vlan[-1].vlan='3'
uci set network.@switch_vlan[-1].vid='3'
uci set network.@switch_vlan[-1].ports='0t 4'  # Port 4 for guest

# Assign VLAN to guest interface
uci set network.guest.type='bridge'
uci set network.guest.ifname='eth0.3'

uci commit network
/etc/init.d/network restart
```

### Guest Network on Specific LAN Port

**Dedicate physical port to guest network:**

```bash
# Example: Port 4 for guest network (varies by router)
# Requires VLAN configuration (see above)

# Or use USB Ethernet adapter for guest
uci set network.guest.ifname='eth1'
```

## Dynamic Password Management

### Automated Daily Password Rotation

**Benefits:**
- Improved security
- Forces guests to request new password
- Easy to track who has current access
- Prevents password sharing over time

**Password Rotation Script:**

```bash
#!/bin/sh
# /root/rotate-guest-password.sh
# Automated guest WiFi password rotation

# Generate random 8-character password
NEW_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)

# Update guest WiFi password
uci set wireless.guest_radio0.key="$NEW_PASSWORD"

# If dual-band, update 5GHz as well
uci set wireless.guest_radio1.key="$NEW_PASSWORD"

# Commit changes
uci commit wireless

# Restart WiFi
wifi

# Log password change
echo "$(date '+%Y-%m-%d %H:%M:%S') - New password: $NEW_PASSWORD" >> /var/log/guest-passwords.log

# Optional: Send notification
logger -t guest-wifi "Password changed to: $NEW_PASSWORD"

# Optional: Update password display page
cat > /www/guest-password.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Guest WiFi Password</title></head>
<body style="font-family: Arial; text-align: center; margin-top: 100px;">
    <h1>Guest WiFi</h1>
    <p><strong>Network:</strong> GuestWiFi</p>
    <p><strong>Password:</strong> <span style="font-size: 24px; color: blue;">$NEW_PASSWORD</span></p>
    <p><small>Updated: $(date '+%Y-%m-%d %H:%M')</small></p>
</body>
</html>
EOF

exit 0
```

**Make executable:**
```bash
chmod +x /root/rotate-guest-password.sh
```

**Schedule via Cron:**

```bash
# Edit crontab
crontab -e

# Add daily rotation at 00:01 (just after midnight)
1 0 * * * /root/rotate-guest-password.sh

# Or weekly rotation (every Monday at 00:01)
1 0 * * 1 /root/rotate-guest-password.sh

# Or custom time (e.g., 6:00 AM daily)
0 6 * * * /root/rotate-guest-password.sh
```

**Restart cron:**
```bash
/etc/init.d/cron restart
```

### Password Display Web Page

**Setup uhttpd (if not installed):**
```bash
opkg update
opkg install uhttpd
```

**Create password display page:**
```bash
cat > /www/guest-password.html <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Guest WiFi Credentials</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            color: white;
        }
        .container {
            background: white;
            color: #333;
            padding: 40px;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            text-align: center;
            max-width: 400px;
        }
        h1 {
            color: #667eea;
            margin-top: 0;
        }
        .credential {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }
        .label {
            font-size: 14px;
            color: #666;
            margin-bottom: 5px;
        }
        .value {
            font-size: 24px;
            font-weight: bold;
            color: #667eea;
            font-family: 'Courier New', monospace;
        }
        .qr-code {
            margin: 20px 0;
        }
        .footer {
            font-size: 12px;
            color: #999;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Guest WiFi</h1>

        <div class="credential">
            <div class="label">Network Name (SSID)</div>
            <div class="value" id="ssid">Loading...</div>
        </div>

        <div class="credential">
            <div class="label">Password</div>
            <div class="value" id="password">Loading...</div>
        </div>

        <div class="footer">
            <p>Updated: <span id="updated">Loading...</span></p>
            <p>Internet access only • No access to internal network</p>
        </div>
    </div>

    <script>
        // Fetch current credentials via CGI
        fetch('/cgi-bin/guest-password')
            .then(response => response.json())
            .then(data => {
                document.getElementById('ssid').textContent = data.ssid;
                document.getElementById('password').textContent = data.password;
                document.getElementById('updated').textContent = data.updated;
            })
            .catch(error => {
                console.error('Error fetching credentials:', error);
            });
    </script>
</body>
</html>
EOF
```

**Create CGI script to fetch credentials:**
```bash
mkdir -p /www/cgi-bin
cat > /www/cgi-bin/guest-password <<'EOF'
#!/bin/sh
echo "Content-Type: application/json"
echo ""

# Get current SSID
SSID=$(uci get wireless.guest_radio0.ssid 2>/dev/null || echo "GuestWiFi")

# Get current password
PASSWORD=$(uci get wireless.guest_radio0.key 2>/dev/null || echo "No password set")

# Get last update time from log
UPDATED=$(tail -1 /var/log/guest-passwords.log 2>/dev/null | cut -d'-' -f1-3 || date '+%Y-%m-%d %H:%M')

# Output JSON
cat <<JSON
{
    "ssid": "$SSID",
    "password": "$PASSWORD",
    "updated": "$UPDATED"
}
JSON
EOF

chmod +x /www/cgi-bin/guest-password
```

**Access the page:**
- From main network: http://192.168.1.1/guest-password.html
- Display on tablet/screen in guest area

### Password History Logging

**Enhanced logging with history:**
```bash
#!/bin/sh
# Enhanced password rotation with history

LOG_FILE="/var/log/guest-passwords.log"
HISTORY_FILE="/var/log/guest-passwords-history.csv"

# Generate password
NEW_PASSWORD=$(tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 12)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DATE_ONLY=$(date '+%Y-%m-%d')

# Update configuration
uci set wireless.guest_radio0.key="$NEW_PASSWORD"
uci commit wireless
wifi

# Log to main log
echo "$TIMESTAMP - Password: $NEW_PASSWORD" >> "$LOG_FILE"

# Log to CSV history
echo "$DATE_ONLY,$NEW_PASSWORD" >> "$HISTORY_FILE"

# Keep only last 30 days of history
tail -30 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"
mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"

logger -t guest-wifi "Password rotated successfully"
```

## Bandwidth Limiting

### Using wshaper (Simple Bandwidth Limiter)

**Install wshaper:**
```bash
opkg update
opkg install wshaper
```

**Configure bandwidth limits:**
```bash
# Edit /etc/config/wshaper
uci set wshaper.@wshaper[0]=wshaper
uci set wshaper.@wshaper[0].network='guest'
uci set wshaper.@wshaper[0].downlink='512'      # 512 kbps download
uci set wshaper.@wshaper[0].uplink='1024'       # 1024 kbps upload

uci commit wshaper
/etc/init.d/wshaper enable
/etc/init.d/wshaper start
```

**Verification:**
```bash
# Check traffic control rules
tc qdisc show dev br-guest
tc class show dev br-guest
```

### Using SQM (Smart Queue Management)

**More advanced bandwidth management:**

```bash
# Install SQM
opkg update
opkg install sqm-scripts luci-app-sqm

# Configure SQM for guest interface
uci set sqm.@queue[0]=queue
uci set sqm.@queue[0].enabled='1'
uci set sqm.@queue[0].interface='br-guest'
uci set sqm.@queue[0].qdisc='cake'
uci set sqm.@queue[0].script='piece_of_cake.qos'
uci set sqm.@queue[0].download='5000'   # 5 Mbps
uci set sqm.@queue[0].upload='2500'     # 2.5 Mbps
uci set sqm.@queue[0].qdisc_advanced='0'
uci set sqm.@queue[0].linklayer='none'

uci commit sqm
/etc/init.d/sqm restart
```

### Per-Client Bandwidth Limits

**Using iptables and tc (advanced):**

```bash
#!/bin/sh
# Per-client bandwidth limiting

# Limit each client to 2 Mbps
CLIENT_LIMIT="2mbit"

# This requires more complex tc setup
# Example structure (requires full implementation):

# Create HTB qdisc
tc qdisc add dev br-guest root handle 1: htb default 10

# Create class for total bandwidth
tc class add dev br-guest parent 1: classid 1:1 htb rate 10mbit ceil 10mbit

# Create classes per client (dynamically via script)
# tc class add dev br-guest parent 1:1 classid 1:10 htb rate 2mbit ceil 2mbit

# Filter traffic to classes based on IP
# tc filter add dev br-guest parent 1: protocol ip prio 1 u32 \
#   match ip src 172.16.0.100 flowid 1:10
```

**Note:** Full per-client limiting requires dynamic script that creates classes for each DHCP lease.

## Scheduled Availability

### Time-Based Guest Network Control

**Enable guest network only during specific hours:**

**Create control scripts:**

```bash
# Enable guest network script
cat > /root/guest-enable.sh <<'EOF'
#!/bin/sh
# Enable guest WiFi

# Enable wireless
uci set wireless.guest_radio0.disabled='0'
uci commit wireless
wifi

logger -t guest-wifi "Guest network enabled"
EOF

# Disable guest network script
cat > /root/guest-disable.sh <<'EOF'
#!/bin/sh
# Disable guest WiFi

# Disable wireless
uci set wireless.guest_radio0.disabled='1'
uci commit wireless
wifi

logger -t guest-wifi "Guest network disabled"
EOF

chmod +x /root/guest-enable.sh
chmod +x /root/guest-disable.sh
```

**Schedule via cron:**

```bash
# Edit crontab
crontab -e

# Enable guest WiFi at 16:00 (4 PM)
0 16 * * * /root/guest-enable.sh

# Disable guest WiFi at 22:00 (10 PM)
0 22 * * * /root/guest-disable.sh

# Or business hours (Monday-Friday, 8 AM - 6 PM)
0 8 * * 1-5 /root/guest-enable.sh
0 18 * * 1-5 /root/guest-disable.sh
```

**Restart cron:**
```bash
/etc/init.d/cron restart
```

### Weekend-Only Guest Network

```bash
# Enable Saturday and Sunday only
# Enable Saturday morning
0 0 * * 6 /root/guest-enable.sh

# Disable Sunday night
0 23 * * 0 /root/guest-disable.sh
```

### Event-Based Scheduling

```bash
# Enable for specific dates (requires manual editing)
# January 15, 2025 at 9 AM
0 9 15 1 * /root/guest-enable.sh

# January 15, 2025 at 6 PM
0 18 15 1 * /root/guest-disable.sh
```

## Restricted Access

### HTTP-Only Access (Block HTTPS)

**Allow only HTTP traffic (port 80):**

```bash
# Block all traffic except HTTP
uci add firewall rule
uci set firewall.@rule[-1].name='Guest-Allow-HTTP-Only'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].target='ACCEPT'

# Block all other traffic
uci set firewall.@zone[-1].forward='REJECT'

uci commit firewall
/etc/init.d/firewall restart
```

**Note:** This severely limits functionality as most sites use HTTPS.

### Whitelist Specific Domains

**Allow only specific websites:**

```bash
#!/bin/sh
# Whitelist specific domains for guest network

# Get IP addresses of allowed domains
ALLOWED_DOMAINS="www.example.com www.google.com"

for domain in $ALLOWED_DOMAINS; do
    IPS=$(nslookup $domain | grep 'Address' | tail -n +2 | awk '{print $3}')

    for ip in $IPS; do
        # Allow access to this IP
        iptables -I FORWARD -s 172.16.0.0/12 -d $ip -j ACCEPT
    done
done

# Block all other forwarding
iptables -A FORWARD -s 172.16.0.0/12 -j REJECT
```

**Note:** IPs can change; requires periodic updates.

### Block Specific Services

**Block P2P, torrents, etc.:**

```bash
# Block BitTorrent
uci add firewall rule
uci set firewall.@rule[-1].name='Block-BitTorrent-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='6881-6889'
uci set firewall.@rule[-1].target='REJECT'

# Block common P2P ports
uci add firewall rule
uci set firewall.@rule[-1].name='Block-P2P-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='1214 4662 4672'
uci set firewall.@rule[-1].target='REJECT'

uci commit firewall
/etc/init.d/firewall restart
```

### Content Filtering

**Using DNS-based filtering (e.g., OpenDNS FamilyShield):**

```bash
# Set guest DHCP to use filtered DNS servers
uci add_list dhcp.guest.dhcp_option='6,208.67.222.123,208.67.220.123'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

**Or use local DNS filtering (requires additional packages like adblock).**

## Welcome Portal Integration

### Using Nodogsplash

**Install and configure nodogsplash:**

```bash
# Install
opkg update
opkg install nodogsplash

# Configure for guest network
uci set nodogsplash.@nodogsplash[0].enabled='1'
uci set nodogsplash.@nodogsplash[0].gatewayinterface='br-guest'
uci set nodogsplash.@nodogsplash[0].gatewayname='Guest WiFi'
uci set nodogsplash.@nodogsplash[0].maxclients='50'
uci set nodogsplash.@nodogsplash[0].clientforcetimeout='7200'  # 2 hours

uci commit nodogsplash

# Start service
/etc/init.d/nodogsplash enable
/etc/init.d/nodogsplash start
```

**See OPENWRT_NODOGSPLASH_CAPTIVE_PORTAL_GUIDE.md for detailed portal setup.**

### Using CoovaChilli

**For RADIUS authentication:**

```bash
opkg update
opkg install coova-chilli

# Basic configuration
uci set chilli.@chilli[0].network='guest'
uci set chilli.@chilli[0].radiusserver1='radius.example.com'
uci set chilli.@chilli[0].radiussecret='shared-secret'
uci set chilli.@chilli[0].uamserver='https://portal.example.com'

uci commit chilli
/etc/init.d/chilli enable
/etc/init.d/chilli start
```

## Privacy and Anonymity

### Tor Integration for Guest Network

**Route guest traffic through Tor network:**

**Install Tor:**
```bash
opkg update
opkg install tor tor-geoip

# Configure Tor
cat >> /etc/tor/torrc <<EOF
TransPort 172.16.0.1:9040
DNSPort 172.16.0.1:9053
EOF

# Start Tor
/etc/init.d/tor enable
/etc/init.d/tor start
```

**Redirect guest traffic to Tor:**
```bash
# Redirect DNS queries to Tor
iptables -t nat -A PREROUTING -i br-guest -p udp --dport 53 -j REDIRECT --to-ports 9053

# Redirect TCP traffic to Tor
iptables -t nat -A PREROUTING -i br-guest -p tcp --syn -j REDIRECT --to-ports 9040

# Allow direct access to Tor
iptables -A OUTPUT -m state --state ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o br-guest -j ACCEPT
```

**Warning:**
- Very slow speeds
- Not all traffic can be routed through Tor (UDP, etc.)
- May violate Tor's terms for exit node usage
- Consider legal/ethical implications

### VPN Integration

**Route guest traffic through VPN:**

```bash
# Example with OpenVPN client
opkg install openvpn-openssl

# Configure OpenVPN client (requires VPN provider config)
# Then route guest through VPN interface

# Change guest zone forwarding
uci set firewall.@forwarding[-1].dest='vpn'

uci commit firewall
/etc/init.d/firewall restart
```

## Management and Monitoring

### View Connected Guests

**List current DHCP leases:**
```bash
cat /tmp/dhcp.leases | grep 172.16
```

**Enhanced monitoring script:**
```bash
#!/bin/sh
# Guest network monitoring

echo "=== Guest Network Status ==="
echo ""

echo "Connected Clients:"
cat /tmp/dhcp.leases | grep 172.16 | while read line; do
    LEASE_TIME=$(echo $line | awk '{print $1}')
    MAC=$(echo $line | awk '{print $2}')
    IP=$(echo $line | awk '{print $3}')
    NAME=$(echo $line | awk '{print $4}')

    echo "  IP: $IP | MAC: $MAC | Name: $NAME"
done

echo ""
echo "Total Guests: $(cat /tmp/dhcp.leases | grep 172.16 | wc -l)"

echo ""
echo "Guest Network Stats:"
ifconfig br-guest | grep -E "RX|TX"
```

### Traffic Statistics

**Install iftop for real-time monitoring:**
```bash
opkg update
opkg install iftop

# Monitor guest interface
iftop -i br-guest
```

**Bandwidth usage tracking:**
```bash
#!/bin/sh
# Log daily guest bandwidth usage

LOG_FILE="/var/log/guest-bandwidth.log"
DATE=$(date '+%Y-%m-%d')

# Get interface statistics
RX_BYTES=$(ifconfig br-guest | grep 'RX bytes' | awk '{print $3}' | cut -d':' -f2)
TX_BYTES=$(ifconfig br-guest | grep 'TX bytes' | awk '{print $3}' | cut -d':' -f2)

# Convert to MB
RX_MB=$((RX_BYTES / 1024 / 1024))
TX_MB=$((TX_BYTES / 1024 / 1024))

# Log
echo "$DATE,Download:${RX_MB}MB,Upload:${TX_MB}MB" >> "$LOG_FILE"
```

**Add to cron (daily at midnight):**
```bash
echo "0 0 * * * /root/log-guest-bandwidth.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### Disconnect Specific Client

**Deauthorize by IP:**
```bash
# Release DHCP lease
# Find and remove from /tmp/dhcp.leases
# Or wait for lease expiration

# Block MAC address temporarily
iptables -I FORWARD -m mac --mac-source AA:BB:CC:DD:EE:FF -j DROP

# Permanent block via firewall
uci add firewall rule
uci set firewall.@rule[-1].name='Block-Device'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].src_mac='AA:BB:CC:DD:EE:FF'
uci set firewall.@rule[-1].target='REJECT'
uci commit firewall
/etc/init.d/firewall restart
```

### Guest Network Usage Reports

**Weekly usage report script:**
```bash
#!/bin/sh
# Generate weekly guest network report

REPORT_FILE="/tmp/guest-report.txt"
WEEK=$(date '+%Y-W%U')

cat > "$REPORT_FILE" <<EOF
Guest Network Weekly Report - $WEEK
====================================

Peak Clients:
$(cat /var/log/guest-clients.log 2>/dev/null | sort -n | tail -1 || echo "No data")

Total Bandwidth:
$(cat /var/log/guest-bandwidth.log 2>/dev/null | tail -7 | awk -F',' '{print $2,$3}')

Password Changes:
$(cat /var/log/guest-passwords.log 2>/dev/null | tail -7)

====================================
EOF

# Email report (requires mail setup)
# cat "$REPORT_FILE" | mail -s "Guest Network Report $WEEK" admin@example.com

# Display report
cat "$REPORT_FILE"
```

## Troubleshooting

### Guest Cannot Connect to Internet

**Diagnosis:**
```bash
# Check if guest can get IP
cat /tmp/dhcp.leases | grep 172.16

# Check firewall forwarding
iptables -L -v -n | grep -A 5 guest

# Check NAT
iptables -t nat -L -v -n | grep 172.16

# Check DNS
nslookup google.com 172.16.0.1

# Test from router
ping -I br-guest 8.8.8.8
```

**Solutions:**
```bash
# Ensure forwarding enabled
uci show firewall | grep -A 3 "guest.*wan"

# If missing, add forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'
uci commit firewall
/etc/init.d/firewall restart

# Check masquerading
iptables -t nat -L POSTROUTING -v -n | grep 172.16

# Add if missing
iptables -t nat -A POSTROUTING -s 172.16.0.0/12 -o eth1 -j MASQUERADE
```

### Guest Can Access Main LAN

**Diagnosis:**
```bash
# From guest device, try to ping main network
ping 192.168.1.1

# If successful, firewall not blocking
```

**Solutions:**
```bash
# Ensure no guest → lan forwarding
uci show firewall | grep forwarding

# Remove any guest → lan forwarding
# Find index: uci show firewall | grep -n "guest.*lan"
# Delete: uci delete firewall.@forwarding[X]

# Add explicit block rule
uci add firewall rule
uci set firewall.@rule[-1].name='Block-LAN-from-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_ip='192.168.0.0/16'
uci set firewall.@rule[-1].proto='all'
uci set firewall.@rule[-1].target='REJECT'

uci commit firewall
/etc/init.d/firewall restart
```

### DHCP Not Working

**Diagnosis:**
```bash
# Check DHCP configuration
uci show dhcp.guest

# Check if dnsmasq running
ps | grep dnsmasq

# Check dnsmasq logs
logread | grep dnsmasq
```

**Solutions:**
```bash
# Restart dnsmasq
/etc/init.d/dnsmasq restart

# Verify DHCP range
uci set dhcp.guest.start='100'
uci set dhcp.guest.limit='150'
uci commit dhcp
/etc/init.d/dnsmasq restart

# Check firewall allows DHCP
uci show firewall | grep -A 5 "DHCP.*Guest"
```

### WiFi Not Broadcasting

**Diagnosis:**
```bash
# Check wireless status
wifi status

# Check if interface exists
iw dev

# Check wireless configuration
uci show wireless.guest_radio0
```

**Solutions:**
```bash
# Ensure not disabled
uci set wireless.guest_radio0.disabled='0'
uci set wireless.radio0.disabled='0'
uci commit wireless

# Restart WiFi
wifi down
wifi up

# Or reload
wifi reload
```

### Slow Guest Network Speeds

**Diagnosis:**
```bash
# Check bandwidth limits
uci show wshaper
uci show sqm

# Check CPU usage
top

# Check wireless signal
iw dev wlan0-1 station dump
```

**Solutions:**
```bash
# Increase bandwidth limits
uci set sqm.@queue[0].download='10000'  # 10 Mbps
uci set sqm.@queue[0].upload='5000'     # 5 Mbps
uci commit sqm
/etc/init.d/sqm restart

# Reduce number of clients
uci set dhcp.guest.limit='50'

# Use 5GHz if available (faster)
# Enable guest on radio1 (5GHz)
```

## Best Practices

### Security Best Practices

✅ **Do:**
- Use WPA2 or WPA3 encryption
- Enable client isolation
- Rotate passwords regularly
- Monitor connected devices
- Log authentication and usage
- Implement bandwidth limits
- Use separate VLAN if possible
- Keep OpenWRT updated

❌ **Don't:**
- Allow guest access to router management
- Allow guest → LAN forwarding
- Use weak passwords
- Share main network password
- Ignore security updates
- Allow unlimited bandwidth
- Trust guest devices

### Performance Best Practices

**Optimize for Many Guests:**
- Use 5GHz band for better performance
- Increase DHCP pool size
- Optimize channel selection (use least congested)
- Enable 802.11ac/ax if supported
- Consider multiple APs for large areas
- Use CAKE qdisc for better QoS

**Optimize for Stability:**
- Shorter DHCP lease times (2-4 hours)
- Limit maximum clients
- Monitor and restart services if needed
- Use stable OpenWRT release
- Regular reboots if high usage

### Management Best Practices

**Documentation:**
- Document password rotation schedule
- Keep log of configuration changes
- Maintain guest access policies
- Track bandwidth usage trends

**Monitoring:**
- Check logs weekly
- Monitor bandwidth usage
- Track number of concurrent clients
- Test guest connectivity regularly

**Maintenance:**
- Update OpenWRT regularly
- Test backup/restore procedures
- Review and optimize firewall rules
- Clean old logs periodically

## Real-World Examples

### Example 1: Home Guest Network

**Simple setup for friends and family:**

```bash
#!/bin/sh
# Simple home guest network

# Network setup (21.02+)
uci add network device
uci set network.@device[-1].name='br-guest'
uci set network.@device[-1].type='bridge'

uci set network.guest=interface
uci set network.guest.proto='static'
uci set network.guest.device='br-guest'
uci set network.guest.ipaddr='172.16.0.1'
uci set network.guest.netmask='255.240.0.0'

# DHCP
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface='guest'
uci set dhcp.guest.start='100'
uci set dhcp.guest.limit='20'
uci set dhcp.guest.leasetime='4h'

# WiFi (both bands, same password)
uci set wireless.guest_radio0=wifi-iface
uci set wireless.guest_radio0.device='radio0'
uci set wireless.guest_radio0.mode='ap'
uci set wireless.guest_radio0.network='guest'
uci set wireless.guest_radio0.ssid='Smith-Guest'
uci set wireless.guest_radio0.encryption='psk2'
uci set wireless.guest_radio0.key='FamilyAndFriends2024'
uci set wireless.guest_radio0.isolate='1'

uci set wireless.guest_radio1=wifi-iface
uci set wireless.guest_radio1.device='radio1'
uci set wireless.guest_radio1.mode='ap'
uci set wireless.guest_radio1.network='guest'
uci set wireless.guest_radio1.ssid='Smith-Guest'
uci set wireless.guest_radio1.encryption='psk2'
uci set wireless.guest_radio1.key='FamilyAndFriends2024'
uci set wireless.guest_radio1.isolate='1'

# Firewall
uci add firewall zone
uci set firewall.@zone[-1].name='guest'
uci set firewall.@zone[-1].input='REJECT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='REJECT'
uci add_list firewall.@zone[-1].network='guest'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'

# Bandwidth limit: 5 Mbps
opkg update && opkg install sqm-scripts
uci set sqm.@queue[0].enabled='1'
uci set sqm.@queue[0].interface='br-guest'
uci set sqm.@queue[0].download='5000'
uci set sqm.@queue[0].upload='2500'

uci commit
reboot
```

### Example 2: Vacation Rental Auto-Rotation

**Automated password rotation for rental property:**

```bash
#!/bin/sh
# Vacation rental guest network with booking integration

# This example assumes booking system updates /tmp/current-booking.txt
# with check-in date

BOOKING_FILE="/tmp/current-booking.txt"
PASSWORD_FILE="/www/guest-info.html"

# Generate password based on check-in date
if [ -f "$BOOKING_FILE" ]; then
    CHECKIN_DATE=$(cat "$BOOKING_FILE")
    # Generate memorable password: PropertyName + CheckinDate
    NEW_PASSWORD="Sunset${CHECKIN_DATE}"
else
    # Default password
    NEW_PASSWORD="VacationRental2024"
fi

# Update WiFi password
uci set wireless.guest_radio0.key="$NEW_PASSWORD"
uci set wireless.guest_radio1.key="$NEW_PASSWORD"
uci commit wireless
wifi

# Create guest info page
cat > "$PASSWORD_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Vacation Rental WiFi</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial;
            text-align: center;
            padding: 50px;
            background: #f0f0f0;
        }
        .info-box {
            background: white;
            padding: 40px;
            border-radius: 10px;
            max-width: 400px;
            margin: 0 auto;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        .credential {
            background: #e8f4f8;
            padding: 15px;
            margin: 20px 0;
            border-radius: 5px;
        }
        .value {
            font-size: 20px;
            font-weight: bold;
            color: #0066cc;
        }
    </style>
</head>
<body>
    <div class="info-box">
        <h1>🏖️ Sunset Villa WiFi</h1>

        <div class="credential">
            <div>Network Name</div>
            <div class="value">Sunset-Villa-Guest</div>
        </div>

        <div class="credential">
            <div>Password</div>
            <div class="value">$NEW_PASSWORD</div>
        </div>

        <p>Enjoy your stay!</p>
        <p><small>WiFi available 24/7 during your reservation</small></p>
    </div>
</body>
</html>
EOF

logger -t rental-wifi "Guest WiFi updated for booking: $CHECKIN_DATE"
```

**Schedule:** Run on check-in day (integrated with booking system)

### Example 3: Coffee Shop with Portal

**Professional setup with captive portal and business hours:**

```bash
#!/bin/sh
# Coffee shop guest network setup

# Install portal
opkg update
opkg install nodogsplash uhttpd

# Network configuration
# ... (standard guest network setup)

# Nodogsplash portal
uci set nodogsplash.@nodogsplash[0].enabled='1'
uci set nodogsplash.@nodogsplash[0].gatewayinterface='br-guest'
uci set nodogsplash.@nodogsplash[0].gatewayname='Cafe Delight Free WiFi'
uci set nodogsplash.@nodogsplash[0].maxclients='30'
uci set nodogsplash.@nodogsplash[0].clientforcetimeout='7200'  # 2 hours

# Bandwidth limits
uci set sqm.@queue[0].download='10000'  # 10 Mbps total
uci set sqm.@queue[0].upload='5000'     # 5 Mbps total

# Scheduled availability (7 AM - 10 PM)
cat > /root/cafe-wifi-enable.sh <<'EOF'
#!/bin/sh
uci set wireless.guest_radio0.disabled='0'
uci commit wireless
wifi
logger -t cafe-wifi "Guest WiFi enabled"
EOF

cat > /root/cafe-wifi-disable.sh <<'EOF'
#!/bin/sh
uci set wireless.guest_radio0.disabled='1'
uci commit wireless
wifi
logger -t cafe-wifi "Guest WiFi disabled"
EOF

chmod +x /root/cafe-wifi-*.sh

# Cron schedule
echo "0 7 * * * /root/cafe-wifi-enable.sh" >> /etc/crontabs/root
echo "0 22 * * * /root/cafe-wifi-disable.sh" >> /etc/crontabs/root

uci commit
/etc/init.d/cron restart
```

## Conclusion

Setting up a guest WiFi network on OpenWRT provides secure, isolated internet access for visitors while protecting your main network and devices.

**Key Takeaways:**

✅ **Setup:**
- Create separate network (172.16.0.0/12)
- Configure DHCP with reasonable limits
- Enable WiFi with strong encryption
- Configure firewall for internet-only access

🔧 **Security:**
- Enable client isolation
- Block access to router and LAN
- Rotate passwords regularly
- Monitor connected devices
- Log access and usage

📊 **Best Practices:**
- Implement bandwidth limits
- Use scheduled availability
- Provide professional welcome portal
- Maintain usage logs
- Regular security audits

**When to Use Guest Network:**
- Home visitors
- Small business customers
- Vacation rentals
- Events and conferences
- Any scenario requiring internet sharing

**Advanced Options:**
- Captive portal with terms
- Dynamic password rotation
- Bandwidth management
- Time-based scheduling
- VPN/Tor routing for privacy

For more information:
- OpenWRT Documentation: https://openwrt.org/docs/guide-user/network/wifi/guestnetwork
- Firewall Guide: https://openwrt.org/docs/guide-user/firewall/start
- Wireless Configuration: https://openwrt.org/docs/guide-user/network/wifi/basic

---

**Document Version:** 1.0
**Last Updated:** Based on OpenWRT 18.06-22.03
**Tested Platforms:** Various OpenWRT routers
