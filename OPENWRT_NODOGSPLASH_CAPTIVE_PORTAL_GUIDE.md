# OpenWRT Nodogsplash Captive Portal Guide

## Table of Contents
- [Overview](#overview)
- [What is a Captive Portal?](#what-is-a-captive-portal)
- [What is Nodogsplash?](#what-is-nodogsplash)
- [Use Cases](#use-cases)
- [Prerequisites](#prerequisites)
- [Network Architecture](#network-architecture)
- [Guest Network Setup](#guest-network-setup)
- [Nodogsplash Installation](#nodogsplash-installation)
- [Basic Configuration](#basic-configuration)
- [Splash Page Options](#splash-page-options)
- [Authentication Methods](#authentication-methods)
- [Advanced Configuration](#advanced-configuration)
- [Management and Monitoring](#management-and-monitoring)
- [Customization](#customization)
- [Bandwidth Control](#bandwidth-control)
- [Troubleshooting](#troubleshooting)
- [Security Considerations](#security-considerations)
- [Performance Optimization](#performance-optimization)
- [Real-World Examples](#real-world-examples)

## Overview

This comprehensive guide explains how to implement a captive portal hotspot using Nodogsplash on OpenWRT, enabling controlled guest network access with various authorization methods.

**What You'll Learn:**
- Setting up isolated guest WiFi network
- Installing and configuring Nodogsplash
- Creating custom splash pages
- Implementing authentication (password, username/password)
- Managing connected clients
- Bandwidth control and monitoring

**Key Benefits:**
- Free and open-source solution
- Lightweight and fast
- Flexible authentication options
- Easy customization
- No external dependencies required

## What is a Captive Portal?

### Captive Portal Basics

A **captive portal** is a web page displayed to users before they can access the internet on a WiFi network. It's commonly seen in:
- Coffee shops and restaurants
- Hotels and airports
- Libraries and public spaces
- Corporate guest networks

### How It Works

**Connection Flow:**
```
1. User connects to WiFi
2. User opens browser or device auto-detects portal
3. Captive portal page loads (splash page)
4. User accepts terms, enters credentials, or clicks accept
5. Access granted to internet
6. User can browse normally
```

**Technical Process:**
```
1. DHCP assigns IP address to client
2. DNS queries intercepted by captive portal
3. HTTP requests redirected to splash page
4. User authenticates/accepts terms
5. Client MAC address whitelisted
6. Normal internet access allowed
```

### Captive Portal vs Regular WiFi

| Feature | Open WiFi | Password WiFi | Captive Portal |
|---------|-----------|---------------|----------------|
| Initial Connection | Immediate | Requires WPA2 key | Immediate |
| Authentication | None | Pre-shared key | Web-based |
| User Tracking | Limited | Limited | Detailed |
| Terms Display | No | No | Yes |
| Time Limits | No | No | Yes |
| Bandwidth Control | Difficult | Difficult | Easy |
| Guest Isolation | Manual | Manual | Built-in |

## What is Nodogsplash?

### Nodogsplash Overview

**Nodogsplash** (NDS) is a lightweight captive portal solution designed specifically for embedded devices like OpenWRT routers.

**Key Characteristics:**
- Very small footprint (~100KB)
- Fast performance
- Written in C (efficient)
- Minimal dependencies
- Highly customizable
- Active development

### Nodogsplash vs Alternatives

**Comparison with Other Solutions:**

| Feature | Nodogsplash | CoovaChilli | WiFiDog | openNDS |
|---------|-------------|-------------|---------|---------|
| Size | Very Small | Large | Medium | Small |
| Complexity | Simple | Complex | Medium | Simple |
| RADIUS Support | No | Yes | Yes | No |
| External Auth | Script-based | Full | Full | Enhanced |
| Resource Usage | Very Low | High | Medium | Low |
| Setup Time | Minutes | Hours | Hour | Minutes |
| Active Development | Yes | Limited | Limited | Yes |

**When to Use Nodogsplash:**
- Small to medium deployments
- Limited resources (RAM/storage)
- Simple authentication needs
- Custom splash pages required
- Fast, lightweight solution needed

**When to Use Alternatives:**
- RADIUS authentication required (CoovaChilli)
- Complex billing systems (CoovaChilli)
- Need enhanced features (openNDS - fork of Nodogsplash)

### Nodogsplash Features

**Built-in Features:**
- MAC address-based authentication
- Session time limits
- Upload/download byte limits
- Custom splash pages
- Authentication scripts
- Client deauthentication
- Status monitoring
- Multiple authentication methods

**Limitations:**
- No built-in RADIUS support
- HTTPS traffic not intercepted (modern devices)
- No built-in user database
- No accounting/reporting (requires external scripts)

## Use Cases

### 1. Coffee Shop / Restaurant WiFi

**Scenario:** Free WiFi for customers with terms acceptance

**Configuration:**
- Open WiFi SSID
- Click-through splash page with terms
- No password required
- 2-hour session limit
- Guest network isolated from POS systems

### 2. Hotel Guest Network

**Scenario:** Password-based access for hotel guests

**Configuration:**
- Daily changing password (provided at check-in)
- Custom splash page with hotel branding
- 24-hour session limit
- Bandwidth throttling per user
- Isolated from hotel management network

### 3. Library / Public Space

**Scenario:** Controlled public access with user acceptance

**Configuration:**
- Username/password from library card
- Acceptable use policy on splash page
- 4-hour session limit
- Bandwidth limits to ensure fair usage
- Content filtering (optional)

### 4. Corporate Guest Network

**Scenario:** Temporary access for visitors/contractors

**Configuration:**
- Employee-issued temporary passwords
- Corporate branding on splash page
- 8-hour session limit
- Complete isolation from corporate LAN
- Logging for compliance

### 5. Event/Conference WiFi

**Scenario:** Temporary WiFi for event attendees

**Configuration:**
- Event code authentication
- Sponsor branding on splash page
- Event duration session limit
- High bandwidth for presentations
- Easy mass deauthentication after event

## Prerequisites

### Hardware Requirements

**Minimum:**
- OpenWRT compatible router
- 8MB flash storage
- 64MB RAM
- WiFi capability

**Recommended:**
- 16MB+ flash storage
- 128MB+ RAM
- Dual-band WiFi (2.4GHz + 5GHz)
- Multiple Ethernet ports

### Software Requirements

**OpenWRT Version:**
- OpenWRT 18.06 or newer
- Tested on 19.07, 21.02, 22.03

**Required Packages:**
```bash
opkg update
opkg install nodogsplash
```

**Optional Packages:**
```bash
# For bandwidth control
opkg install sqm-scripts

# For enhanced monitoring
opkg install iftop

# For custom web pages
opkg install lighttpd lighttpd-mod-fastcgi
```

### Knowledge Requirements

**Basic Understanding:**
- OpenWRT UCI configuration
- Basic networking (IP addressing, subnets)
- SSH access to router
- Basic HTML (for custom splash pages)

**Optional Skills:**
- Shell scripting (for advanced auth)
- CSS/JavaScript (for enhanced splash pages)
- iptables (for custom firewall rules)

## Network Architecture

### Typical Deployment Topology

```
                    Internet
                       |
                   [WAN Port]
                       |
                 [OpenWRT Router]
                   Nodogsplash
                  /            \
                 /              \
          [LAN Network]    [Guest Network]
          192.168.1.0/24    10.20.30.0/24
                |                 |
          Internal Devices   Guest Clients
          (Isolated)         (Captive Portal)
```

### Network Segmentation

**LAN Network (Internal):**
- Subnet: 192.168.1.0/24
- Gateway: 192.168.1.1
- Purpose: Internal devices, trusted users
- Access: Full network access
- Security: WPA2/WPA3 protected

**Guest Network (Captive Portal):**
- Subnet: 10.20.30.0/24
- Gateway: 10.20.30.1
- Purpose: Guest/public access
- Access: Internet only (no LAN access)
- Security: Captive portal controlled

### IP Addressing Scheme

**Example Allocation:**
```
Router LAN:     192.168.1.1
LAN DHCP Range: 192.168.1.100-250

Router Guest:   10.20.30.1
Guest DHCP:     10.20.30.100-250

DNS Servers:    10.20.30.1 (router)
                8.8.8.8, 1.1.1.1 (fallback)
```

### Traffic Flow

**Guest Client Internet Access:**
```
Guest Device (10.20.30.150)
    ↓
Guest WiFi (wlan0-1)
    ↓
Bridge (br-guest)
    ↓
Nodogsplash (authentication check)
    ↓
Firewall (guest → wan forwarding)
    ↓
NAT/Masquerading
    ↓
WAN Interface
    ↓
Internet
```

**Guest Client Blocked from LAN:**
```
Guest Device (10.20.30.150)
    ↓
Attempt to access 192.168.1.x
    ↓
Firewall (guest → lan = REJECT)
    ↓
Access Denied
```

## Guest Network Setup

### Version Differences

OpenWRT changed bridge configuration between versions. Choose the method for your version.

**Check OpenWRT Version:**
```bash
cat /etc/openwrt_release
# Look for DISTRIB_RELEASE
```

### Method 1: OpenWRT 18.06 - 21.02 (before May 29, 2021)

**Step 1: Create Guest Network Interface**
```bash
uci set network.guest=interface
uci set network.guest.proto=static
uci set network.guest.ipaddr=10.20.30.1
uci set network.guest.netmask=255.255.255.0
uci set network.guest.type=bridge
```

**Step 2: Configure DHCP for Guest Network**
```bash
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface=guest
uci set dhcp.guest.start=100
uci set dhcp.guest.limit=150
uci set dhcp.guest.leasetime=2h
```

**Step 3: Create Guest WiFi Interface**
```bash
uci set wireless.guest=wifi-iface
uci set wireless.guest.device=radio0
uci set wireless.guest.mode=ap
uci set wireless.guest.network=guest
uci set wireless.guest.ssid=GuestWiFi
uci set wireless.guest.encryption=none
uci set wireless.radio0.disabled=0
```

**Step 4: Configure Firewall**
```bash
# Create guest zone
uci add firewall zone
uci set firewall.@zone[-1].name=guest
uci set firewall.@zone[-1].network=guest
uci set firewall.@zone[-1].input=REJECT
uci set firewall.@zone[-1].output=ACCEPT
uci set firewall.@zone[-1].forward=REJECT

# Allow guest → wan forwarding
uci add firewall forwarding
uci set firewall.@forwarding[-1].src=guest
uci set firewall.@forwarding[-1].dest=wan

# Allow DHCP
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DHCP-Guest'
uci set firewall.@rule[-1].src=guest
uci set firewall.@rule[-1].proto=udp
uci set firewall.@rule[-1].src_port=67-68
uci set firewall.@rule[-1].dest_port=67-68
uci set firewall.@rule[-1].target=ACCEPT
uci set firewall.@rule[-1].family=ipv4

# Allow DNS
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DNS-Guest'
uci set firewall.@rule[-1].src=guest
uci set firewall.@rule[-1].dest_port=53
uci set firewall.@rule[-1].target=ACCEPT
uci set firewall.@rule[-1].family=ipv4
uci set firewall.@rule[-1].proto=tcpudp
```

**Step 5: Commit and Reboot**
```bash
uci commit
reboot
```

### Method 2: OpenWRT 21.02+ (after May 29, 2021)

**Step 1: Create Bridge Device**
```bash
uci add network device
uci set network.@device[-1].name='br-guest'
uci set network.@device[-1].type='bridge'
uci set network.@device[-1].bridge_empty='1'
```

**Step 2: Create Guest Network Interface**
```bash
uci set network.guest=interface
uci set network.guest.proto=static
uci set network.guest.device='br-guest'
uci set network.guest.ipaddr=10.20.30.1
uci set network.guest.netmask=255.255.255.0
```

**Step 3: Configure DHCP**
```bash
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface=guest
uci set dhcp.guest.start=100
uci set dhcp.guest.limit=150
uci set dhcp.guest.leasetime=2h
```

**Step 4: Create Guest WiFi Interface**
```bash
uci set wireless.guest=wifi-iface
uci set wireless.guest.device=radio0
uci set wireless.guest.mode=ap
uci set wireless.guest.network=guest
uci set wireless.guest.ssid=GuestWiFi
uci set wireless.guest.encryption=none
uci set wireless.radio0.disabled=0
```

**Step 5: Configure Firewall** (same as Method 1)
```bash
# Create guest zone
uci add firewall zone
uci set firewall.@zone[-1].name=guest
uci set firewall.@zone[-1].network=guest
uci set firewall.@zone[-1].input=REJECT
uci set firewall.@zone[-1].output=ACCEPT
uci set firewall.@zone[-1].forward=REJECT

# Allow guest → wan
uci add firewall forwarding
uci set firewall.@forwarding[-1].src=guest
uci set firewall.@forwarding[-1].dest=wan

# DHCP rule
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DHCP-Guest'
uci set firewall.@rule[-1].src=guest
uci set firewall.@rule[-1].proto=udp
uci set firewall.@rule[-1].src_port=67-68
uci set firewall.@rule[-1].dest_port=67-68
uci set firewall.@rule[-1].target=ACCEPT
uci set firewall.@rule[-1].family=ipv4

# DNS rule
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-DNS-Guest'
uci set firewall.@rule[-1].src=guest
uci set firewall.@rule[-1].dest_port=53
uci set firewall.@rule[-1].target=ACCEPT
uci set firewall.@rule[-1].family=ipv4
uci set firewall.@rule[-1].proto=tcpudp
```

**Step 6: Commit and Reboot**
```bash
uci commit
reboot
```

### Verify Guest Network

**After Reboot, Check:**
```bash
# Verify interface
ifconfig br-guest
# Should show: inet addr:10.20.30.1

# Verify DHCP
cat /var/dhcp.leases
# Should show guest clients when connected

# Verify firewall
iptables -L -v -n | grep -A 5 guest

# Test connectivity
# Connect device to GuestWiFi
# Should get IP 10.20.30.x
# Should NOT be able to ping 192.168.1.x
# Should be able to ping internet (after portal auth)
```

## Nodogsplash Installation

### Install Package

```bash
# Update package list
opkg update

# Install nodogsplash
opkg install nodogsplash

# Verify installation
opkg list-installed | grep nodogsplash

# Check version
nodogsplash -v
```

### Package Contents

**Installed Files:**
```
/etc/config/nodogsplash          # UCI configuration
/etc/init.d/nodogsplash          # Init script
/etc/nodogsplash/                # Configuration directory
/etc/nodogsplash/htdocs/         # Default splash pages
/usr/bin/nodogsplash             # Main daemon
/usr/bin/ndsctl                  # Control utility
/usr/lib/nodogsplash/            # Library files
```

### Initial Setup

**Enable Service:**
```bash
# Enable autostart
/etc/init.d/nodogsplash enable

# Don't start yet - configure first
```

## Basic Configuration

### UCI Configuration

**Minimum Configuration:**
```bash
# Enable nodogsplash
uci set nodogsplash.@nodogsplash[0].enabled=1

# Set gateway interface (IMPORTANT!)
uci set nodogsplash.@nodogsplash[0].gatewayinterface='br-guest'

# Set gateway name (displayed on splash page)
uci set nodogsplash.@nodogsplash[0].gatewayname='Guest WiFi'

# Commit changes
uci commit nodogsplash
```

### Configuration File Options

**View Current Config:**
```bash
uci show nodogsplash
```

**Edit Config File Directly:**
```bash
vi /etc/config/nodogsplash
```

**Example Configuration:**
```
config nodogsplash
	option enabled '1'
	option gatewayinterface 'br-guest'
	option gatewayname 'Guest WiFi Portal'
	option maxclients '250'
	option clientidletimeout '1200'
	option clientforcetimeout '7200'
	option gatewayiprange '0.0.0.0/0'
	option debuglevel '1'
	option splashpage '/etc/nodogsplash/htdocs/splash.html'
	option redirecturl 'http://www.google.com'
	option passwordattempts '5'
	option username 'disable'
	option password 'disable'
	option authenticate_immediately '0'
```

### Key Configuration Options

**Basic Options:**
```bash
# enabled: Enable/disable nodogsplash (0 or 1)
uci set nodogsplash.@nodogsplash[0].enabled=1

# gatewayinterface: Network interface to manage (REQUIRED)
uci set nodogsplash.@nodogsplash[0].gatewayinterface='br-guest'

# gatewayname: Portal name shown to users
uci set nodogsplash.@nodogsplash[0].gatewayname='MyHotspot'

# maxclients: Maximum simultaneous clients
uci set nodogsplash.@nodogsplash[0].maxclients=250

# debuglevel: Logging verbosity (0-3)
uci set nodogsplash.@nodogsplash[0].debuglevel=1
```

**Session Options:**
```bash
# clientidletimeout: Idle timeout in seconds (0 = no limit)
uci set nodogsplash.@nodogsplash[0].clientidletimeout=1200  # 20 min

# clientforcetimeout: Maximum session time in seconds (0 = no limit)
uci set nodogsplash.@nodogsplash[0].clientforcetimeout=7200  # 2 hours
```

**Splash Page Options:**
```bash
# splashpage: Path to custom splash page
uci set nodogsplash.@nodogsplash[0].splashpage='/etc/nodogsplash/htdocs/splash.html'

# redirecturl: Where to send user after authentication
uci set nodogsplash.@nodogsplash[0].redirecturl='http://www.example.com'

# statuspage: Custom status page
uci set nodogsplash.@nodogsplash[0].statuspage='/etc/nodogsplash/htdocs/status.html'
```

**Authentication Options:**
```bash
# binauth: External authentication script
uci set nodogsplash.@nodogsplash[0].binauth='/bin/auth.sh'

# username: Require username (enable/disable)
uci set nodogsplash.@nodogsplash[0].username='disable'

# password: Require password (enable/disable)
uci set nodogsplash.@nodogsplash[0].password='disable'

# passwordattempts: Failed login attempts before blocking
uci set nodogsplash.@nodogsplash[0].passwordattempts=5

# authenticate_immediately: Skip splash, auth immediately
uci set nodogsplash.@nodogsplash[0].authenticate_immediately=0
```

### Start Nodogsplash

```bash
# Start service
/etc/init.d/nodogsplash start

# Check status
/etc/init.d/nodogsplash status

# View logs
logread | grep -i nodogsplash
```

## Splash Page Options

Nodogsplash supports multiple splash page types based on your authentication requirements.

### Template Variables

**Available Variables in Splash Pages:**
- `$gatewayname` - Gateway name from config
- `$authaction` - Authentication URL (form action)
- `$tok` - Authentication token (required hidden field)
- `$redir` - Redirect URL after auth (required hidden field)
- `$clientip` - Client IP address
- `$clientmac` - Client MAC address
- `$gatewaymac` - Gateway MAC address
- `$maxclients` - Maximum clients allowed
- `$nclients` - Current number of clients

### Option 1: Click-Through (No Authentication)

**Use Case:** Simple acceptance of terms, no credentials required

**Configuration:**
```bash
uci set nodogsplash.@nodogsplash[0].username='disable'
uci set nodogsplash.@nodogsplash[0].password='disable'
uci commit nodogsplash
/etc/init.d/nodogsplash restart
```

**Splash Page HTML:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>$gatewayname</title>
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 100px;
            background-color: #f0f0f0;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            display: inline-block;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        button {
            background: #4CAF50;
            color: white;
            padding: 15px 40px;
            border: none;
            border-radius: 5px;
            font-size: 18px;
            cursor: pointer;
        }
        button:hover { background: #45a049; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to $gatewayname</h1>
        <p>Click below to accept the terms and access the internet.</p>
        <form method='GET' action='$authaction'>
            <input type='hidden' name='tok' value='$tok'>
            <input type='hidden' name='redir' value='$redir'>
            <button type='submit'>Accept & Connect</button>
        </form>
    </div>
</body>
</html>
```

**Save As:**
```bash
vi /etc/nodogsplash/htdocs/splash.html
# Paste content above

# Set in config
uci set nodogsplash.@nodogsplash[0].splashpage='/etc/nodogsplash/htdocs/splash.html'
uci commit nodogsplash
/etc/init.d/nodogsplash restart
```

### Option 2: Password-Only Authentication

**Use Case:** Single shared password for all guests

**Configuration:**
```bash
# Enable password authentication
uci set nodogsplash.@nodogsplash[0].password='enable'
uci set nodogsplash.@nodogsplash[0].username='disable'

# Set authentication script
uci set nodogsplash.@nodogsplash[0].binauth='/bin/nds-auth.sh'

uci commit nodogsplash
```

**Splash Page HTML:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>$gatewayname</title>
    <meta http-equiv="Cache-Control" content="no-cache">
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 100px;
            background-color: #f0f0f0;
        }
        .container {
            background: white;
            padding: 40px;
            border-radius: 10px;
            display: inline-block;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 { color: #333; }
        input[type="password"] {
            padding: 10px;
            font-size: 16px;
            width: 200px;
            margin: 10px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        button {
            background: #4CAF50;
            color: white;
            padding: 10px 30px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
        }
        button:hover { background: #45a049; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$gatewayname</h1>
        <p>Please enter the password to access the internet.</p>
        <form method='GET' action='$authaction'>
            <input type='hidden' name='tok' value='$tok'>
            <input type='hidden' name='redir' value='$redir'>
            <input type='password' name='password' placeholder='Password'
                   size='20' maxlength='20' required>
            <br>
            <button type='submit'>Connect</button>
        </form>
    </div>
</body>
</html>
```

**Authentication Script:**
```bash
#!/bin/sh
# /bin/nds-auth.sh
# Password-only authentication

METHOD="$1"
MAC="$2"

# Your password here
VALID_PASSWORD="guestwifi2024"

case "$METHOD" in
    auth_client)
        USERNAME="$3"
        PASSWORD="$4"

        if [ "$PASSWORD" = "$VALID_PASSWORD" ]; then
            # Auth successful
            # Format: timeout download_limit upload_limit
            # 3600 = 1 hour, 0 = unlimited bandwidth
            echo "3600 0 0"
            exit 0
        else
            # Auth failed
            exit 1
        fi
        ;;

    client_auth|client_deauth|idle_deauth|timeout_deauth|ndsctl_auth|ndsctl_deauth|shutdown_deauth)
        # Log client events
        INGOING_BYTES="$3"
        OUTGOING_BYTES="$4"
        SESSION_START="$5"
        SESSION_END="$6"

        logger -t nodogsplash "$METHOD: MAC=$MAC, Down=$INGOING_BYTES, Up=$OUTGOING_BYTES"
        ;;
esac

exit 0
```

**Setup Script:**
```bash
# Create auth script
vi /bin/nds-auth.sh
# Paste content above

# Make executable
chmod 755 /bin/nds-auth.sh

# Restart nodogsplash
/etc/init.d/nodogsplash restart
```

### Option 3: Username/Password Authentication

**Use Case:** Individual credentials per user

**Configuration:**
```bash
# Enable username and password
uci set nodogsplash.@nodogsplash[0].username='enable'
uci set nodogsplash.@nodogsplash[0].password='enable'
uci set nodogsplash.@nodogsplash[0].binauth='/bin/nds-auth.sh'

uci commit nodogsplash
```

**Splash Page HTML:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>$gatewayname</title>
    <meta http-equiv="Cache-Control" content="no-cache">
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            margin-top: 80px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            background: white;
            color: #333;
            padding: 40px;
            border-radius: 15px;
            display: inline-block;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
        }
        h1 { margin-top: 0; }
        input[type="text"], input[type="password"] {
            padding: 12px;
            font-size: 16px;
            width: 250px;
            margin: 10px 0;
            border: 2px solid #ddd;
            border-radius: 5px;
            display: block;
            margin-left: auto;
            margin-right: auto;
        }
        input:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            background: #667eea;
            color: white;
            padding: 12px 40px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 15px;
        }
        button:hover { background: #5568d3; }
    </style>
</head>
<body>
    <div class="container">
        <h1>$gatewayname</h1>
        <p>Please login to access the internet.</p>
        <form method='GET' action='$authaction'>
            <input type='hidden' name='tok' value='$tok'>
            <input type='hidden' name='redir' value='$redir'>
            <input type='text' name='username' placeholder='Username' required>
            <input type='password' name='password' placeholder='Password' required>
            <button type='submit'>Login</button>
        </form>
    </div>
</body>
</html>
```

**Authentication Script with Multiple Users:**
```bash
#!/bin/sh
# /bin/nds-auth.sh
# Username/password authentication

METHOD="$1"
MAC="$2"

# Function to check credentials
check_credentials() {
    local username="$1"
    local password="$2"

    # Simple hardcoded users
    # Format: username:password:timeout:download_limit:upload_limit
    # timeout in seconds, 0 = unlimited bandwidth

    case "$username" in
        guest)
            if [ "$password" = "guest123" ]; then
                echo "3600 0 0"  # 1 hour, unlimited bandwidth
                return 0
            fi
            ;;
        customer)
            if [ "$password" = "customer456" ]; then
                echo "7200 0 0"  # 2 hours, unlimited bandwidth
                return 0
            fi
            ;;
        vip)
            if [ "$password" = "vip789" ]; then
                echo "86400 0 0"  # 24 hours, unlimited bandwidth
                return 0
            fi
            ;;
    esac

    return 1
}

case "$METHOD" in
    auth_client)
        USERNAME="$3"
        PASSWORD="$4"

        if check_credentials "$USERNAME" "$PASSWORD"; then
            logger -t nodogsplash "AUTH SUCCESS: $USERNAME from $MAC"
            exit 0
        else
            logger -t nodogsplash "AUTH FAILED: $USERNAME from $MAC"
            exit 1
        fi
        ;;

    client_auth)
        INGOING="$3"
        OUTGOING="$4"
        SESSION_START="$5"
        SESSION_END="$6"
        logger -t nodogsplash "CLIENT AUTH: $MAC, Down=$INGOING, Up=$OUTGOING"
        ;;

    client_deauth)
        INGOING="$3"
        OUTGOING="$4"
        SESSION_START="$5"
        SESSION_END="$6"
        logger -t nodogsplash "CLIENT DEAUTH: $MAC, Down=$INGOING, Up=$OUTGOING"
        ;;

    idle_deauth)
        logger -t nodogsplash "IDLE TIMEOUT: $MAC"
        ;;

    timeout_deauth)
        logger -t nodogsplash "SESSION TIMEOUT: $MAC"
        ;;
esac

exit 0
```

**Setup:**
```bash
# Create script
vi /bin/nds-auth.sh
# Paste content

chmod 755 /bin/nds-auth.sh
/etc/init.d/nodogsplash restart
```

## Authentication Methods

### Authentication Script Format

The authentication script receives different parameters based on the event.

**Script Call Format:**
```bash
/bin/nds-auth.sh METHOD MAC [ADDITIONAL_PARAMS]
```

**METHOD Types:**
- `auth_client` - Client attempting authentication
- `client_auth` - Client successfully authenticated
- `client_deauth` - Client deauthenticated normally
- `idle_deauth` - Client deauthenticated due to idle timeout
- `timeout_deauth` - Client deauthenticated due to session timeout
- `ndsctl_auth` - Client authenticated via ndsctl command
- `ndsctl_deauth` - Client deauthenticated via ndsctl command
- `shutdown_deauth` - Client deauthenticated due to shutdown

**Parameters:**
```bash
METHOD="$1"          # Event type
MAC="$2"             # Client MAC address
USERNAME="$3"        # Username (auth_client only)
PASSWORD="$4"        # Password (auth_client only)
INGOING_BYTES="$3"   # Downloaded bytes (deauth events)
OUTGOING_BYTES="$4"  # Uploaded bytes (deauth events)
SESSION_START="$5"   # Session start time (deauth events)
SESSION_END="$6"     # Session end time (deauth events)
```

**Return Format (auth_client):**
```bash
echo "TIMEOUT DOWNLOAD_LIMIT UPLOAD_LIMIT"
# TIMEOUT: seconds (0 = unlimited)
# DOWNLOAD_LIMIT: bytes (0 = unlimited)
# UPLOAD_LIMIT: bytes (0 = unlimited)

# Examples:
echo "3600 0 0"           # 1 hour, unlimited bandwidth
echo "7200 104857600 104857600"  # 2 hours, 100MB down/up
echo "0 0 0"              # Unlimited time and bandwidth
```

### File-Based Authentication

**User Database File:**
```bash
# Create user database
cat > /etc/nodogsplash/users.txt <<EOF
# Format: username:password:timeout:download:upload
guest:guest123:3600:0:0
customer:pass456:7200:0:0
vip:secret789:86400:0:0
admin:admin2024:0:0:0
EOF

chmod 600 /etc/nodogsplash/users.txt
```

**Authentication Script:**
```bash
#!/bin/sh
# /bin/nds-auth.sh
# File-based authentication

METHOD="$1"
MAC="$2"
USER_DB="/etc/nodogsplash/users.txt"

check_user() {
    local username="$1"
    local password="$2"

    # Read user database
    while IFS=: read -r u p t d up; do
        # Skip comments and empty lines
        [ -z "$u" ] && continue
        [ "${u#\#}" != "$u" ] && continue

        if [ "$u" = "$username" ] && [ "$p" = "$password" ]; then
            echo "$t $d $up"
            return 0
        fi
    done < "$USER_DB"

    return 1
}

case "$METHOD" in
    auth_client)
        USERNAME="$3"
        PASSWORD="$4"

        if RESULT=$(check_user "$USERNAME" "$PASSWORD"); then
            echo "$RESULT"
            logger -t nodogsplash "AUTH OK: $USERNAME ($MAC)"
            exit 0
        else
            logger -t nodogsplash "AUTH FAIL: $USERNAME ($MAC)"
            exit 1
        fi
        ;;

    client_auth|client_deauth|idle_deauth|timeout_deauth)
        logger -t nodogsplash "$METHOD: $MAC"
        ;;
esac

exit 0
```

### MAC Address Whitelisting

**Pre-authorize specific MAC addresses:**
```bash
#!/bin/sh
# /bin/nds-auth.sh
# MAC whitelist authentication

METHOD="$1"
MAC="$2"

# Whitelisted MAC addresses
WHITELIST="
aa:bb:cc:dd:ee:01
aa:bb:cc:dd:ee:02
aa:bb:cc:dd:ee:03
"

is_whitelisted() {
    echo "$WHITELIST" | grep -q "$1"
}

case "$METHOD" in
    auth_client)
        USERNAME="$3"
        PASSWORD="$4"

        # Check if MAC is whitelisted
        if is_whitelisted "$MAC"; then
            # Whitelisted: grant unlimited access
            echo "0 0 0"
            logger -t nodogsplash "WHITELIST AUTH: $MAC"
            exit 0
        fi

        # Not whitelisted: check credentials
        if [ "$PASSWORD" = "guestpass" ]; then
            echo "3600 0 0"
            logger -t nodogsplash "PASSWORD AUTH: $MAC"
            exit 0
        fi

        exit 1
        ;;
esac

exit 0
```

### External Database Authentication

**MySQL/PostgreSQL Example:**
```bash
#!/bin/sh
# /bin/nds-auth.sh
# Database authentication (requires mysql client)

METHOD="$1"
MAC="$2"

DB_HOST="192.168.1.100"
DB_USER="hotspot"
DB_PASS="dbpass"
DB_NAME="hotspot"

check_db_user() {
    local username="$1"
    local password="$2"

    # Query database
    RESULT=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN <<EOF
SELECT timeout, download_limit, upload_limit
FROM users
WHERE username='$username'
AND password=MD5('$password')
AND enabled=1;
EOF
    )

    if [ -n "$RESULT" ]; then
        echo "$RESULT"
        return 0
    fi

    return 1
}

case "$METHOD" in
    auth_client)
        USERNAME="$3"
        PASSWORD="$4"

        if RESULT=$(check_db_user "$USERNAME" "$PASSWORD"); then
            echo "$RESULT"

            # Log to database
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" <<EOF
INSERT INTO sessions (username, mac, login_time)
VALUES ('$USERNAME', '$MAC', NOW());
EOF
            exit 0
        fi

        exit 1
        ;;

    client_deauth)
        INGOING="$3"
        OUTGOING="$4"

        # Update database with usage stats
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" <<EOF
UPDATE sessions
SET logout_time=NOW(), download=$INGOING, upload=$OUTGOING
WHERE mac='$MAC' AND logout_time IS NULL;
EOF
        ;;
esac

exit 0
```

## Advanced Configuration

### Session Time Limits

**Configure Timeouts:**
```bash
# Idle timeout: Disconnect after X seconds of inactivity
uci set nodogsplash.@nodogsplash[0].clientidletimeout=1200  # 20 minutes

# Force timeout: Maximum session duration
uci set nodogsplash.@nodogsplash[0].clientforcetimeout=7200  # 2 hours

# No timeout (unlimited)
# uci set nodogsplash.@nodogsplash[0].clientidletimeout=0
# uci set nodogsplash.@nodogsplash[0].clientforcetimeout=0

uci commit nodogsplash
/etc/init.d/nodogsplash restart
```

**Per-User Timeouts (in auth script):**
```bash
# Return different timeouts based on user
if [ "$USERNAME" = "guest" ]; then
    echo "3600 0 0"  # 1 hour
elif [ "$USERNAME" = "premium" ]; then
    echo "86400 0 0"  # 24 hours
elif [ "$USERNAME" = "unlimited" ]; then
    echo "0 0 0"  # No timeout
fi
```

### Bandwidth Limits

**Global Bandwidth Control with SQM:**
```bash
# Install SQM (Smart Queue Management)
opkg update
opkg install sqm-scripts luci-app-sqm

# Configure SQM for guest interface
uci set sqm.@queue[0].enabled='1'
uci set sqm.@queue[0].interface='br-guest'
uci set sqm.@queue[0].download='10000'  # 10 Mbps
uci set sqm.@queue[0].upload='5000'     # 5 Mbps
uci set sqm.@queue[0].qdisc='cake'
uci set sqm.@queue[0].script='piece_of_cake.qos'

uci commit sqm
/etc/init.d/sqm restart
```

**Per-User Bandwidth Limits (in auth script):**
```bash
# Return bandwidth limits in auth response
# Format: timeout download_bytes upload_bytes

# 100 MB download, 50 MB upload
echo "3600 104857600 52428800"

# 1 GB download, 500 MB upload
echo "7200 1073741824 536870912"

# Unlimited bandwidth
echo "3600 0 0"
```

**Note:** Nodogsplash bandwidth limits are cumulative session limits, not rate limits.

### Walled Garden (Allowed Sites)

**Allow access to specific sites without authentication:**
```bash
# Allow access to specific domains
uci add_list nodogsplash.@nodogsplash[0].walledgarden='www.example.com'
uci add_list nodogsplash.@nodogsplash[0].walledgarden='static.example.com'

# Allow specific IP ranges
uci add_list nodogsplash.@nodogsplash[0].walledgarden='192.0.2.0/24'

# Allow specific ports
uci add_list nodogsplash.@nodogsplash[0].trustedmaclist='aa:bb:cc:dd:ee:ff'

uci commit nodogsplash
/etc/init.d/nodogsplash restart
```

### Redirect After Login

**Configure Post-Login Redirect:**
```bash
# Redirect to specific URL
uci set nodogsplash.@nodogsplash[0].redirecturl='http://www.example.com/welcome'

# Redirect to user's original destination
# (leave empty or don't set)
uci delete nodogsplash.@nodogsplash[0].redirecturl

uci commit nodogsplash
/etc/init.d/nodogsplash restart
```

**Custom Redirect in Splash Page:**
```html
<form method='GET' action='$authaction'>
    <input type='hidden' name='tok' value='$tok'>
    <!-- Custom redirect -->
    <input type='hidden' name='redir' value='http://www.custom.com'>
    <button type='submit'>Login</button>
</form>
```

### Custom Status Page

**Create Status Page:**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Connection Status - $gatewayname</title>
    <meta http-equiv="refresh" content="300">
</head>
<body>
    <h1>You are connected to $gatewayname</h1>
    <p>Client IP: $clientip</p>
    <p>Client MAC: $clientmac</p>
    <p>Currently connected clients: $nclients / $maxclients</p>
    <p>This page will auto-refresh every 5 minutes.</p>
    <p><a href="$authtarget&amp;logout">Logout</a></p>
</body>
</html>
```

**Configure:**
```bash
# Save as status page
vi /etc/nodogsplash/htdocs/status.html
# Paste content

# Configure path
uci set nodogsplash.@nodogsplash[0].statuspage='/etc/nodogsplash/htdocs/status.html'
uci commit nodogsplash
/etc/init.d/nodogsplash restart
```

## Management and Monitoring

### ndsctl Command

**ndsctl** is the control utility for managing nodogsplash.

**Basic Commands:**
```bash
# Show status
ndsctl status

# List connected clients
ndsctl clients

# Show detailed client info
ndsctl json

# Stop nodogsplash
ndsctl stop
```

### Client Management

**List Clients:**
```bash
# Simple list
ndsctl clients

# Example output:
# Client 1
#   IP: 10.20.30.150
#   MAC: aa:bb:cc:dd:ee:01
#   State: Authenticated
#   Session Start: 2024-01-15 14:30:22
#   Download: 52428800 bytes
#   Upload: 10485760 bytes
```

**Deauthenticate Client:**
```bash
# By MAC address
ndsctl deauth aa:bb:cc:dd:ee:01

# By IP address
ndsctl deauth 10.20.30.150

# Deauth all clients
ndsctl deauth all
```

**Manually Authenticate Client:**
```bash
# Authenticate without splash page
# Useful for whitelisting or troubleshooting

# By MAC
ndsctl auth aa:bb:cc:dd:ee:01

# By IP
ndsctl auth 10.20.30.150

# With timeout (in seconds)
ndsctl auth aa:bb:cc:dd:ee:01 3600
```

### Logging and Monitoring

**View Logs:**
```bash
# Real-time log
logread -f | grep nodogsplash

# Recent logs
logread | grep nodogsplash | tail -50

# Search for specific client
logread | grep "aa:bb:cc:dd:ee:01"

# Search for auth failures
logread | grep "AUTH FAIL"
```

**Enhanced Logging Script:**
```bash
#!/bin/sh
# /bin/nds-log.sh
# Enhanced logging for nodogsplash events

LOG_FILE="/var/log/nodogsplash-detailed.log"
MAX_LOG_SIZE=1048576  # 1 MB

METHOD="$1"
MAC="$2"

# Rotate log if too large
if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt $MAX_LOG_SIZE ]; then
    mv "$LOG_FILE" "${LOG_FILE}.old"
fi

log_event() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" >> "$LOG_FILE"
}

case "$METHOD" in
    auth_client)
        USERNAME="$3"
        log_event "AUTH_ATTEMPT | MAC=$MAC | USER=$USERNAME"
        ;;

    client_auth)
        INGOING="$3"
        OUTGOING="$4"
        log_event "CLIENT_AUTH | MAC=$MAC | DOWN=$INGOING | UP=$OUTGOING"
        ;;

    client_deauth)
        INGOING="$3"
        OUTGOING="$4"
        SESSION_START="$5"
        SESSION_END="$6"
        DURATION=$((SESSION_END - SESSION_START))
        log_event "CLIENT_DEAUTH | MAC=$MAC | DURATION=${DURATION}s | DOWN=$INGOING | UP=$OUTGOING"
        ;;

    idle_deauth)
        log_event "IDLE_TIMEOUT | MAC=$MAC"
        ;;

    timeout_deauth)
        log_event "SESSION_TIMEOUT | MAC=$MAC"
        ;;
esac

# Also call actual auth script
exec /bin/nds-auth-real.sh "$@"
```

**Monitor Connected Clients:**
```bash
#!/bin/sh
# Monitor script

while true; do
    clear
    echo "=== Nodogsplash Status - $(date) ==="
    echo ""
    ndsctl status
    echo ""
    echo "=== Connected Clients ==="
    ndsctl clients
    sleep 10
done
```

### Statistics Collection

**Create Stats Script:**
```bash
#!/bin/sh
# /root/nds-stats.sh
# Collect usage statistics

STATS_DIR="/var/log/nds-stats"
mkdir -p "$STATS_DIR"

DATE=$(date '+%Y-%m-%d')
TIME=$(date '+%H:%M:%S')

# Get client count
CLIENT_COUNT=$(ndsctl json | grep -c "\"ip\"")

# Log statistics
echo "$DATE,$TIME,$CLIENT_COUNT" >> "$STATS_DIR/daily-$DATE.csv"

# Generate daily report at midnight
HOUR=$(date '+%H')
if [ "$HOUR" = "00" ]; then
    YESTERDAY=$(date -d "yesterday" '+%Y-%m-%d')
    if [ -f "$STATS_DIR/daily-$YESTERDAY.csv" ]; then
        # Calculate stats
        TOTAL=$(wc -l < "$STATS_DIR/daily-$YESTERDAY.csv")
        MAX=$(sort -t, -k3 -n "$STATS_DIR/daily-$YESTERDAY.csv" | tail -1 | cut -d, -f3)
        AVG=$(awk -F, '{sum+=$3} END {print int(sum/NR)}' "$STATS_DIR/daily-$YESTERDAY.csv")

        # Send report
        echo "Date: $YESTERDAY" > "$STATS_DIR/report-$YESTERDAY.txt"
        echo "Measurements: $TOTAL" >> "$STATS_DIR/report-$YESTERDAY.txt"
        echo "Max Clients: $MAX" >> "$STATS_DIR/report-$YESTERDAY.txt"
        echo "Avg Clients: $AVG" >> "$STATS_DIR/report-$YESTERDAY.txt"
    fi
fi
```

**Add to Cron:**
```bash
# Run every 10 minutes
echo "*/10 * * * * /root/nds-stats.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

## Customization

### Professional Splash Page Template

**Modern Responsive Design:**
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$gatewayname - WiFi Portal</title>
    <meta http-equiv="Cache-Control" content="no-cache">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }

        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 500px;
            width: 100%;
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px 30px;
            text-align: center;
        }

        .header h1 {
            font-size: 28px;
            margin-bottom: 10px;
        }

        .header p {
            opacity: 0.9;
            font-size: 14px;
        }

        .content {
            padding: 40px 30px;
        }

        .info-box {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 15px;
            margin-bottom: 25px;
            border-radius: 5px;
        }

        .info-box h3 {
            color: #333;
            margin-bottom: 10px;
            font-size: 16px;
        }

        .info-box ul {
            list-style: none;
            padding-left: 20px;
        }

        .info-box li:before {
            content: "✓ ";
            color: #667eea;
            font-weight: bold;
            margin-right: 5px;
        }

        input[type="text"],
        input[type="password"] {
            width: 100%;
            padding: 15px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            margin-bottom: 15px;
            transition: border-color 0.3s;
        }

        input:focus {
            outline: none;
            border-color: #667eea;
        }

        button {
            width: 100%;
            padding: 15px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 18px;
            font-weight: bold;
            cursor: pointer;
            transition: transform 0.2s, box-shadow 0.2s;
        }

        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
        }

        button:active {
            transform: translateY(0);
        }

        .footer {
            background: #f8f9fa;
            padding: 20px;
            text-align: center;
            font-size: 12px;
            color: #666;
        }

        @media (max-width: 600px) {
            .header h1 {
                font-size: 24px;
            }

            .content {
                padding: 30px 20px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>$gatewayname</h1>
            <p>Welcome to our free WiFi service</p>
        </div>

        <div class="content">
            <div class="info-box">
                <h3>Terms of Service</h3>
                <ul>
                    <li>Use respectfully and legally</li>
                    <li>No illegal activities permitted</li>
                    <li>Connection monitored for security</li>
                    <li>Session limited to 2 hours</li>
                </ul>
            </div>

            <form method="GET" action="$authaction">
                <input type="hidden" name="tok" value="$tok">
                <input type="hidden" name="redir" value="$redir">

                <input type="text" name="username" placeholder="Username" required>
                <input type="password" name="password" placeholder="Password" required>

                <button type="submit">Connect to WiFi</button>
            </form>
        </div>

        <div class="footer">
            <p>By connecting, you agree to our terms of service.</p>
            <p>Your IP: $clientip | Your MAC: $clientmac</p>
        </div>
    </div>
</body>
</html>
```

### Add Logo and Branding

```html
<div class="header">
    <!-- Add your logo -->
    <img src="data:image/png;base64,YOUR_BASE64_LOGO_HERE"
         alt="Logo" style="max-width: 150px; margin-bottom: 20px;">
    <h1>$gatewayname</h1>
    <p>Welcome to our free WiFi service</p>
</div>
```

**Convert image to base64:**
```bash
base64 -w 0 logo.png > logo.base64
# Copy output and paste in HTML
```

### Multi-Language Support

```html
<script>
function setLanguage(lang) {
    var texts = {
        'en': {
            'title': 'Welcome',
            'username': 'Username',
            'password': 'Password',
            'connect': 'Connect to WiFi'
        },
        'es': {
            'title': 'Bienvenido',
            'username': 'Nombre de usuario',
            'password': 'Contraseña',
            'connect': 'Conectar a WiFi'
        },
        'tr': {
            'title': 'Hoş Geldiniz',
            'username': 'Kullanıcı Adı',
            'password': 'Şifre',
            'connect': 'WiFi\'ye Bağlan'
        }
    };

    document.getElementById('title').textContent = texts[lang]['title'];
    document.getElementById('username').placeholder = texts[lang]['username'];
    document.getElementById('password').placeholder = texts[lang]['password'];
    document.getElementById('submit').textContent = texts[lang]['connect'];
}
</script>

<select onchange="setLanguage(this.value)">
    <option value="en">English</option>
    <option value="es">Español</option>
    <option value="tr">Türkçe</option>
</select>
```

## Bandwidth Control

### SQM-Scripts Configuration

**Install and Configure SQM:**
```bash
# Install packages
opkg update
opkg install sqm-scripts luci-app-sqm

# Configure for guest interface
uci set sqm.@queue[0].enabled='1'
uci set sqm.@queue[0].interface='br-guest'
uci set sqm.@queue[0].qdisc='cake'
uci set sqm.@queue[0].script='piece_of_cake.qos'
uci set sqm.@queue[0].qdisc_advanced='0'
uci set sqm.@queue[0].ingress_ecn='ECN'
uci set sqm.@queue[0].egress_ecn='NOECN'
uci set sqm.@queue[0].qdisc_really_really_advanced='0'
uci set sqm.@queue[0].download='10000'  # 10 Mbps
uci set sqm.@queue[0].upload='5000'     # 5 Mbps
uci set sqm.@queue[0].linklayer='none'

uci commit sqm
/etc/init.d/sqm restart
```

**Verify SQM:**
```bash
# Check status
/etc/init.d/sqm status

# View rules
tc qdisc show dev br-guest
tc class show dev br-guest
```

### Per-Client Rate Limiting

**Using tc (Traffic Control):**
```bash
#!/bin/sh
# /bin/nds-qos.sh
# Per-client bandwidth limiting

METHOD="$1"
MAC="$2"
CLIENT_IP=""

# Rate limits (in kbps)
DEFAULT_DOWNLOAD=5000  # 5 Mbps
DEFAULT_UPLOAD=2500    # 2.5 Mbps

set_rate_limit() {
    local ip="$1"
    local download="$2"
    local upload="$3"

    # Add rate limiting rules
    # (This is simplified - full implementation more complex)
    logger -t nds-qos "Setting limits for $ip: DL=$download UP=$upload"
}

remove_rate_limit() {
    local ip="$1"
    logger -t nds-qos "Removing limits for $ip"
}

case "$METHOD" in
    client_auth)
        # Get client IP from ndsctl
        CLIENT_IP=$(ndsctl json | grep -B 2 "$MAC" | grep "\"ip\"" | cut -d'"' -f4)

        if [ -n "$CLIENT_IP" ]; then
            set_rate_limit "$CLIENT_IP" "$DEFAULT_DOWNLOAD" "$DEFAULT_UPLOAD"
        fi
        ;;

    client_deauth|idle_deauth|timeout_deauth)
        CLIENT_IP=$(ndsctl json | grep -B 2 "$MAC" | grep "\"ip\"" | cut -d'"' -f4)

        if [ -n "$CLIENT_IP" ]; then
            remove_rate_limit "$CLIENT_IP"
        fi
        ;;
esac

# Call main auth script
exec /bin/nds-auth.sh "$@"
```

## Troubleshooting

### Common Issues

#### Issue 1: Captive Portal Not Appearing

**Symptoms:**
- Clients connect but no splash page
- Browser doesn't redirect

**Diagnosis:**
```bash
# Check if nodogsplash is running
/etc/init.d/nodogsplash status

# Check gateway interface
uci show nodogsplash | grep gatewayinterface

# Check firewall
iptables -L -v -n | grep -A 10 ndsNET

# Check logs
logread | grep nodogsplash
```

**Solutions:**
```bash
# Restart nodogsplash
/etc/init.d/nodogsplash restart

# Verify correct interface
uci set nodogsplash.@nodogsplash[0].gatewayinterface='br-guest'
uci commit nodogsplash
/etc/init.d/nodogsplash restart

# Clear browser cache on client device

# Try manual URL (on client):
# http://10.20.30.1/
```

#### Issue 2: HTTPS Sites Not Redirecting

**Symptoms:**
- HTTP sites redirect fine
- HTTPS sites show certificate errors or don't redirect

**Explanation:**
- Modern browsers use HTTPS by default
- Nodogsplash cannot intercept HTTPS traffic
- Certificate validation prevents redirection

**Solutions:**
```bash
# Configure captive portal detection URL
# Most devices check http://detectportal.firefox.com/success.txt
# or http://www.gstatic.com/generate_204

# Ensure router DNS is working
nslookup google.com

# On client device:
# - Manually navigate to http://neverssl.com
# - Or http://10.20.30.1
# - Disable "Always use secure connections" temporarily
```

#### Issue 3: Authentication Fails

**Symptoms:**
- Credentials entered but access denied
- Auth script not working

**Diagnosis:**
```bash
# Check if auth script exists
ls -la /bin/nds-auth.sh

# Check permissions
# Should be: -rwxr-xr-x (755)

# Test script manually
/bin/nds-auth.sh auth_client aa:bb:cc:dd:ee:ff testuser testpass

# Check logs
logread | grep -i auth

# Check script syntax
sh -n /bin/nds-auth.sh
```

**Solutions:**
```bash
# Fix permissions
chmod 755 /bin/nds-auth.sh

# Fix script syntax errors
vi /bin/nds-auth.sh

# Add debug logging
#!/bin/sh
logger -t nds-debug "METHOD=$1 MAC=$2 USER=$3 PASS=$4"
# ... rest of script

# Restart nodogsplash
/etc/init.d/nodogsplash restart
```

#### Issue 4: Clients Get Internet Without Authentication

**Symptoms:**
- Splash page bypassed
- Clients access internet immediately

**Diagnosis:**
```bash
# Check if nodogsplash is running
/etc/init.d/nodogsplash status

# Check firewall rules
iptables -L -v -n -t nat | grep -A 5 Nodogsplash
iptables -L -v -n -t filter | grep -A 10 ndsNET

# Check configuration
uci show nodogsplash
```

**Solutions:**
```bash
# Ensure nodogsplash is enabled
uci set nodogsplash.@nodogsplash[0].enabled=1
uci commit nodogsplash

# Restart completely
/etc/init.d/nodogsplash stop
sleep 2
/etc/init.d/nodogsplash start

# Reboot router if persistent
reboot
```

#### Issue 5: Client Cannot Access Internet After Auth

**Symptoms:**
- Authentication successful
- But still no internet access

**Diagnosis:**
```bash
# Check if client authenticated
ndsctl clients

# Check firewall forwarding
iptables -L -v -n | grep -A 5 forwarding

# Test DNS resolution (from router)
nslookup google.com

# Check NAT
iptables -t nat -L -v -n | grep MASQUERADE
```

**Solutions:**
```bash
# Verify guest → wan forwarding exists
uci show firewall | grep -A 3 forwarding | grep -B 1 wan

# Add if missing
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='guest'
uci set firewall.@forwarding[-1].dest='wan'
uci commit firewall
/etc/init.d/firewall restart

# Check DNS
uci show dhcp.guest

# Restart network
/etc/init.d/network restart
```

### Diagnostic Commands

**Complete Diagnostic Script:**
```bash
#!/bin/sh
# Nodogsplash diagnostic tool

echo "=== Nodogsplash Diagnostics ==="
echo ""

echo "1. Service Status"
/etc/init.d/nodogsplash status
echo ""

echo "2. Configuration"
uci show nodogsplash
echo ""

echo "3. Connected Clients"
ndsctl clients
echo ""

echo "4. Firewall Rules (NAT)"
iptables -t nat -L -v -n | grep -A 10 Nodogsplash
echo ""

echo "5. Firewall Rules (Filter)"
iptables -L -v -n | grep -A 10 ndsNET
echo ""

echo "6. Interface Status"
ifconfig br-guest
echo ""

echo "7. Recent Logs"
logread | grep nodogsplash | tail -20
echo ""

echo "8. Auth Script"
ls -la /bin/nds-auth.sh 2>/dev/null || echo "No auth script configured"
echo ""

echo "=== End Diagnostics ==="
```

## Security Considerations

### Guest Network Isolation

**Ensure Complete Isolation:**
```bash
# Verify no guest → lan forwarding
uci show firewall | grep -A 2 forwarding

# Should NOT have guest → lan

# Block all private networks
uci add firewall rule
uci set firewall.@rule[-1].name='Block-Private-Guest'
uci set firewall.@rule[-1].src='guest'
uci set firewall.@rule[-1].dest_ip='192.168.0.0/16 172.16.0.0/12 10.0.0.0/8'
uci set firewall.@rule[-1].target='REJECT'
uci set firewall.@rule[-1].proto='all'

uci commit firewall
/etc/init.d/firewall restart
```

### HTTPS for Splash Page

**Setup Local HTTPS (Self-Signed):**
```bash
# Generate certificate
opkg install openssl-util

mkdir -p /etc/nodogsplash/ssl
cd /etc/nodogsplash/ssl

openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 \
    -keyout server.key -out server.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=10.20.30.1"

chmod 600 server.key
chmod 644 server.crt

# Configure lighttpd or uhttpd for HTTPS
# (Advanced - requires additional setup)
```

**Note:** Self-signed certificates will show browser warnings.

### Password Security

**Strong Password Requirements:**
```bash
#!/bin/sh
# Check password strength

check_password_strength() {
    local pass="$1"
    local len=${#pass}

    # Minimum 8 characters
    [ $len -lt 8 ] && return 1

    # Require at least one number
    echo "$pass" | grep -q '[0-9]' || return 1

    # Require at least one letter
    echo "$pass" | grep -q '[a-zA-Z]' || return 1

    return 0
}

# In auth script:
if ! check_password_strength "$PASSWORD"; then
    logger -t nodogsplash "WEAK PASSWORD REJECTED: $USERNAME"
    exit 1
fi
```

### Rate Limiting Authentication Attempts

**Prevent Brute Force:**
```bash
#!/bin/sh
# /bin/nds-auth.sh with rate limiting

FAIL_LOG="/tmp/nds-auth-fails"
MAX_ATTEMPTS=5
BLOCK_TIME=3600  # 1 hour

check_blocked() {
    local mac="$1"

    if [ -f "$FAIL_LOG" ]; then
        # Count recent failures
        FAILURES=$(grep "$mac" "$FAIL_LOG" | wc -l)

        if [ $FAILURES -ge $MAX_ATTEMPTS ]; then
            # Check if block expired
            LAST_FAIL=$(grep "$mac" "$FAIL_LOG" | tail -1 | cut -d' ' -f1)
            NOW=$(date +%s)
            DIFF=$((NOW - LAST_FAIL))

            if [ $DIFF -lt $BLOCK_TIME ]; then
                logger -t nodogsplash "BLOCKED: $mac (too many failures)"
                return 1
            else
                # Clear old failures
                sed -i "/$mac/d" "$FAIL_LOG"
            fi
        fi
    fi

    return 0
}

record_failure() {
    local mac="$1"
    echo "$(date +%s) $mac" >> "$FAIL_LOG"
}

# In auth_client section:
check_blocked "$MAC" || exit 1

if check_credentials "$USERNAME" "$PASSWORD"; then
    # Success - clear failures
    sed -i "/$MAC/d" "$FAIL_LOG"
    exit 0
else
    # Failure - record it
    record_failure "$MAC"
    exit 1
fi
```

### Logging for Compliance

**Comprehensive Activity Logging:**
```bash
#!/bin/sh
# Detailed logging for legal compliance

LOG_DIR="/var/log/nodogsplash"
mkdir -p "$LOG_DIR"

METHOD="$1"
MAC="$2"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

case "$METHOD" in
    client_auth)
        # Log successful authentication
        echo "$TIMESTAMP|AUTH|$MAC|$3|$4" >> "$LOG_DIR/auth.log"
        ;;

    client_deauth)
        # Log session details
        DOWN="$3"
        UP="$4"
        START="$5"
        END="$6"
        DURATION=$((END - START))
        echo "$TIMESTAMP|DEAUTH|$MAC|DURATION=$DURATION|DOWN=$DOWN|UP=$UP" >> "$LOG_DIR/sessions.log"
        ;;
esac
```

## Performance Optimization

### Resource Usage

**Monitor Resources:**
```bash
# Check memory usage
free
# Nodogsplash should use < 5MB typically

# Check CPU usage
top -n 1 | grep nodogsplash

# Check process count
ps | grep nodogsplash | wc -l
```

**Optimize Configuration:**
```bash
# Reduce debug logging
uci set nodogsplash.@nodogsplash[0].debuglevel=0

# Limit max clients if needed
uci set nodogsplash.@nodogsplash[0].maxclients=100

# Increase checkinterval for less CPU usage
uci set nodogsplash.@nodogsplash[0].checkinterval=60

uci commit nodogsplash
/etc/init.d/nodogsplash restart
```

### High-Capacity Deployments

**For 200+ Simultaneous Clients:**
```bash
# Increase system limits
sysctl -w net.nf_conntrack_max=65536
sysctl -w net.netfilter.nf_conntrack_max=65536

# Make permanent
echo "net.nf_conntrack_max=65536" >> /etc/sysctl.conf
echo "net.netfilter.nf_conntrack_max=65536" >> /etc/sysctl.conf

# Increase max clients
uci set nodogsplash.@nodogsplash[0].maxclients=500

# Optimize DHCP lease time
uci set dhcp.guest.leasetime=30m  # Shorter for faster turnover

uci commit
reboot
```

### Splash Page Optimization

**Minimize Page Size:**
```html
<!-- Use inline CSS instead of external files -->
<!-- Compress images to base64 -->
<!-- Minimize JavaScript -->
<!-- Remove unnecessary whitespace -->

<!-- Minified example -->
<!DOCTYPE html><html><head><title>$gatewayname</title><style>body{font-family:Arial;text-align:center;margin-top:100px}</style></head><body><h1>$gatewayname</h1><form method=GET action=$authaction><input type=hidden name=tok value=$tok><input type=hidden name=redir value=$redir><button type=submit>Connect</button></form></body></html>
```

## Real-World Examples

### Example 1: Coffee Shop Setup

**Requirements:**
- Free WiFi for customers
- Accept terms only
- 2-hour session limit
- Branded splash page

**Complete Configuration:**
```bash
#!/bin/sh
# Coffee Shop Hotspot Setup

# Install package
opkg update
opkg install nodogsplash

# Configure network (21.02+)
uci add network device
uci set network.@device[-1].name='br-guest'
uci set network.@device[-1].type='bridge'
uci set network.guest=interface
uci set network.guest.proto=static
uci set network.guest.device='br-guest'
uci set network.guest.ipaddr=10.20.30.1
uci set network.guest.netmask=255.255.255.0

# DHCP
uci set dhcp.guest=dhcp
uci set dhcp.guest.interface=guest
uci set dhcp.guest.start=100
uci set dhcp.guest.limit=150
uci set dhcp.guest.leasetime=2h

# WiFi
uci set wireless.guest=wifi-iface
uci set wireless.guest.device=radio0
uci set wireless.guest.mode=ap
uci set wireless.guest.network=guest
uci set wireless.guest.ssid='CoffeeShop_WiFi'
uci set wireless.guest.encryption=none

# Firewall
uci add firewall zone
uci set firewall.@zone[-1].name=guest
uci set firewall.@zone[-1].network=guest
uci set firewall.@zone[-1].input=REJECT
uci set firewall.@zone[-1].output=ACCEPT
uci set firewall.@zone[-1].forward=REJECT

uci add firewall forwarding
uci set firewall.@forwarding[-1].src=guest
uci set firewall.@forwarding[-1].dest=wan

# Nodogsplash
uci set nodogsplash.@nodogsplash[0].enabled=1
uci set nodogsplash.@nodogsplash[0].gatewayinterface='br-guest'
uci set nodogsplash.@nodogsplash[0].gatewayname='Coffee Shop Free WiFi'
uci set nodogsplash.@nodogsplash[0].maxclients=50
uci set nodogsplash.@nodogsplash[0].clientforcetimeout=7200  # 2 hours

uci commit
reboot
```

### Example 2: Hotel Guest Network

**Requirements:**
- Password provided at check-in
- Daily password changes
- Guest branding
- 24-hour sessions

**Password Rotation Script:**
```bash
#!/bin/sh
# /root/rotate-password.sh
# Daily password rotation for hotel

# Generate random password
NEW_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 8)
DATE=$(date '+%Y-%m-%d')

# Update auth script
cat > /bin/nds-auth.sh <<EOF
#!/bin/sh
METHOD="\$1"
MAC="\$2"

case "\$METHOD" in
    auth_client)
        USERNAME="\$3"
        PASSWORD="\$4"

        if [ "\$PASSWORD" = "$NEW_PASS" ]; then
            echo "86400 0 0"  # 24 hours
            logger -t hotel-wifi "AUTH: Guest logged in with today's password"
            exit 0
        fi
        exit 1
        ;;
esac
exit 0
EOF

chmod 755 /bin/nds-auth.sh

# Log new password
echo "$DATE: $NEW_PASS" >> /var/log/hotel-passwords.log

# Email to staff (requires mail setup)
echo "Today's WiFi password: $NEW_PASS" | mail -s "Hotel WiFi Password $DATE" reception@hotel.com

logger -t hotel-wifi "Password rotated: $NEW_PASS"
```

**Add to Cron (daily at 6 AM):**
```bash
echo "0 6 * * * /root/rotate-password.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### Example 3: Library Public Access

**Requirements:**
- Library card authentication
- 4-hour sessions
- Bandwidth limits
- Content filtering

**User Database:**
```bash
# /etc/nodogsplash/library-cards.txt
# Format: card_number:pin:timeout:download:upload
123456:1234:14400:0:0
234567:2345:14400:0:0
345678:3456:14400:0:0
```

**Auth Script:**
```bash
#!/bin/sh
# /bin/nds-auth.sh
# Library card authentication

METHOD="$1"
MAC="$2"
DB="/etc/nodogsplash/library-cards.txt"

case "$METHOD" in
    auth_client)
        CARD="$3"
        PIN="$4"

        # Check database
        RESULT=$(grep "^${CARD}:${PIN}:" "$DB")

        if [ -n "$RESULT" ]; then
            # Extract timeout and limits
            TIMEOUT=$(echo "$RESULT" | cut -d: -f3)
            DOWNLOAD=$(echo "$RESULT" | cut -d: -f4)
            UPLOAD=$(echo "$RESULT" | cut -d: -f5)

            echo "$TIMEOUT $DOWNLOAD $UPLOAD"
            logger -t library-wifi "AUTH: Card $CARD"
            exit 0
        fi

        logger -t library-wifi "AUTH FAIL: Card $CARD"
        exit 1
        ;;
esac
exit 0
```

## Conclusion

Nodogsplash provides a flexible, lightweight captive portal solution for OpenWRT routers, suitable for a wide range of deployment scenarios from small cafes to larger public venues.

**Key Takeaways:**

✅ **Setup:**
- Create isolated guest network
- Configure firewall for internet-only access
- Install and configure nodogsplash
- Customize splash page

🔧 **Configuration:**
- Choose authentication method (none, password, username/password)
- Set session timeouts
- Configure bandwidth limits
- Create custom branding

🔐 **Security:**
- Isolate guest network from LAN
- Implement strong passwords
- Rate-limit authentication attempts
- Log activity for compliance

📊 **Best Practices:**
- Test thoroughly before deployment
- Monitor resource usage
- Regular password rotation (if applicable)
- Keep splash page simple and fast
- Provide clear terms of service

**When to Use Nodogsplash:**
- Small to medium hotspot deployments
- Resource-constrained devices
- Custom authentication requirements
- Simple, fast captive portal needed

**Alternatives to Consider:**
- openNDS (enhanced fork of Nodogsplash)
- CoovaChilli (for RADIUS integration)
- WiFiDog (for cloud management)
- Commercial solutions (for enterprise)

For more information:
- Nodogsplash GitHub: https://github.com/nodogsplash/nodogsplash
- OpenWRT Documentation: https://openwrt.org/docs/guide-user/services/captive-portal/nodogsplash
- Community Forum: https://forum.openwrt.org/

---

**Document Version:** 1.0
**Last Updated:** Based on OpenWRT 18.06-22.03
**Tested Platforms:** Various OpenWRT routers (ar71xx, ramips, ipq40xx)
