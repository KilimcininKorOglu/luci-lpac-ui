# OpenWRT Travelmate Automatic WiFi Connection Guide

## Table of Contents
1. [Overview](#overview)
2. [What is Travelmate](#what-is-travelmate)
3. [Use Cases](#use-cases)
4. [Features](#features)
5. [Prerequisites](#prerequisites)
6. [Installation](#installation)
7. [Configuration](#configuration)
8. [Web Interface (LuCI) Configuration](#web-interface-luci-configuration)
9. [Command-Line Configuration](#command-line-configuration)
10. [Network Priority Management](#network-priority-management)
11. [Monitoring and Status](#monitoring-and-status)
12. [Advanced Configuration](#advanced-configuration)
13. [Troubleshooting](#troubleshooting)
14. [Best Practices](#best-practices)
15. [References](#references)

---

## Overview

Travelmate is an OpenWRT package that enables routers to automatically connect to pre-configured wireless networks. It's ideal for travel routers, mobile setups, or any scenario where your router needs to connect to various WiFi networks as a client while simultaneously providing its own access point.

**Key Capability:**
- Router acts as **WiFi client** to existing networks
- Simultaneously provides **WiFi access point** for your devices
- Automatically selects and connects to best available network
- Monitors connection quality and switches if needed

**Typical Setup:**
```
Internet ←→ Hotel/Coffee Shop WiFi ←→ Travel Router (Travelmate) ←→ Your Devices
```

---

## What is Travelmate

### Concept

Travelmate allows your OpenWRT router to:
1. Store multiple WiFi network credentials
2. Automatically scan for available networks
3. Connect to the best available network based on priority
4. Monitor connection quality
5. Failover to alternative networks if connection degrades
6. Maintain your own access point simultaneously

### Operating Modes

**Station Mode (STA):**
- Router connects to external WiFi as a client
- Similar to your laptop connecting to WiFi
- Managed by Travelmate

**Access Point Mode (AP):**
- Router provides WiFi for your devices
- Operates simultaneously with station mode
- Not managed by Travelmate (normal OpenWRT AP)

### Architecture

```
┌─────────────────────────────────────────┐
│   External WiFi Networks                │
│   - Hotel WiFi                           │
│   - Coffee Shop                          │
│   - Home Network                         │
│   - Office WiFi                          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│   OpenWRT Router (Travelmate)           │
│   ┌─────────────────────────────────┐   │
│   │ Travelmate Daemon               │   │
│   │ - Scan networks                 │   │
│   │ - Select best available         │   │
│   │ - Monitor quality               │   │
│   │ - Failover if needed            │   │
│   └─────────────────────────────────┘   │
│                                          │
│   WiFi Radio (dual function):           │
│   - Client mode (to external WiFi)      │
│   - AP mode (for your devices)          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│   Your Devices                           │
│   - Laptop, Phone, Tablet, etc.         │
└─────────────────────────────────────────┘
```

---

## Use Cases

### Travel Router

**Scenario:** Staying in hotels, Airbnb, or traveling
- Connect to hotel WiFi once
- All your devices use router's AP
- Switch between locations automatically
- Secure your traffic (VPN can be added)

### Coffee Shop / Coworking

**Scenario:** Working from various locations
- Pre-configure coffee shop WiFi credentials
- Router auto-connects when in range
- Consistent network name for your devices
- Failover to mobile hotspot if available

### RV / Camper Van

**Scenario:** Traveling and camping
- Connect to campground WiFi
- Failover to cellular modem
- Maintain consistent local network

### Backup Internet Connection

**Scenario:** Home/office backup WAN
- Primary: Wired WAN
- Backup: Neighbor's WiFi (with permission)
- Automatic failover

### IoT / Smart Home

**Scenario:** Mobile smart home setup
- Consistent WiFi SSID for IoT devices
- Router handles external network connection
- Devices don't need reconfiguration

---

## Features

### Core Features

**Automatic Network Selection:**
- Scans for configured networks
- Connects to highest priority available network
- Remembers previously failed networks

**Connection Quality Monitoring:**
- Monitors signal strength
- Configurable minimum quality threshold
- Automatic failover to better network

**Priority-based Connection:**
- Networks ordered by preference
- Higher priority networks checked first
- Manual priority adjustment

**Failover Support:**
- Switches networks if quality degrades
- Configurable retry attempts
- Maximum wait time settings

**Captive Portal Detection:**
- Detects captive portals (login pages)
- Optional auto-trigger browser
- Configurable portal detection

### Advanced Features

**Simultaneous AP Mode:**
- Router provides WiFi while connected as client
- Transparent to client devices
- No interruption during network switches

**Open Network Support:**
- Auto-connect to open (unencrypted) networks
- Configurable whitelist/blacklist
- Available in OpenWRT 19.07+

**Uplink Monitoring:**
- Continuously checks internet connectivity
- Not just WiFi connection, but actual internet access
- Configurable check intervals

**Runtime Status:**
- JSON status output
- Current connection info
- Failed network tracking

---

## Prerequisites

### Hardware Requirements

**Router:**
- OpenWRT-compatible device
- WiFi radio supporting station (client) mode
- Sufficient RAM (64MB+ recommended)

**WiFi Capabilities:**
- Station mode (STA) support
- Dual-mode capability (STA + AP simultaneously) preferred
- Single radio can work but limits functionality

### Software Requirements

**OpenWRT version:**
- OpenWRT 18.06 or newer
- Recommended: 19.07+ or 21.02+

**Required packages:**
- `travelmate` - Core daemon
- `luci-app-travelmate` - Web interface (optional but recommended)

**Optional packages:**
- `curl` or `wget` - For uplink checks
- `wpad` - For WPA2/3 enterprise support

---

## Installation

### Install via Web Interface (LuCI)

1. Navigate to **System → Software**
2. Click **Update lists**
3. Search for `travelmate`
4. Click **Install** next to `travelmate`
5. Search for `luci-app-travelmate`
6. Click **Install** next to `luci-app-travelmate`
7. Wait for installation to complete
8. Refresh browser page

### Install via Command Line

```bash
# Update package lists
opkg update

# Install travelmate and web interface
opkg install travelmate luci-app-travelmate

# Verify installation
opkg list-installed | grep travelmate
```

**Expected output:**
```
luci-app-travelmate - git-21.123.45678-abcdef
travelmate - 2.0.5-1
```

---

## Configuration

Configuration involves three main components:

1. **Wireless Configuration** - Define WiFi networks to connect to
2. **Network Configuration** - Create interface for uplink
3. **Travelmate Configuration** - Set behavior and parameters
4. **Firewall Configuration** - Allow traffic through travelmate interface

---

## Web Interface (LuCI) Configuration

### Access Travelmate Settings

1. Navigate to **Services → Travelmate**
2. **Enable Travelmate** checkbox
3. Configure settings

### Basic Settings Tab

**Enable Travelmate:**
- Check to activate

**Travelmate Network Interface:**
- Set to `trm_wwan` (default)
- This is the uplink interface name

**Minimum Signal Quality:**
- Default: 35 (%)
- Range: 0-100
- Networks below this threshold are ignored

**Maximum Retries:**
- Default: 3
- How many times to retry failed network

**Connection Timeout:**
- Default: 60 seconds
- How long to wait for connection

**Captive Portal Detection:**
- Enable to detect login pages
- Auto-redirect to portal when detected

### Add WiFi Networks

**Via Wireless Scan:**

1. In Travelmate interface, click **Wireless Scan**
2. Wait for scan to complete
3. Click **Add** next to desired network
4. Enter password (if required)
5. Set priority (optional)
6. Save

**Manual Addition:**

1. Go to **Network → Wireless**
2. Click **Add** on appropriate radio
3. Configure:
   - **Mode:** Client
   - **ESSID:** Network name
   - **Network:** `trm_wwan`
   - **Encryption:** Select appropriate type
   - **Key:** Password
4. **Important:** Leave **Disabled** checked initially
5. Save and apply

### Network Priority

**Set priority order:**
1. Go to **Services → Travelmate → Overview**
2. Drag networks to reorder (if supported)
3. Or manually edit configuration

**Priority determines connection order:**
- First network in list = highest priority
- Travelmate connects to first available

---

## Command-Line Configuration

### Step 1: Configure Wireless Networks

Edit `/etc/config/wireless`:

```bash
vi /etc/config/wireless
```

**Add WiFi client configuration for each network:**

```bash
# Example: Home network
config wifi-iface
    option device 'radio0'
    option network 'trm_wwan'
    option mode 'sta'
    option disabled '1'
    option ssid 'HomeWiFi'
    option encryption 'psk2'
    option key 'homepassword123'

# Example: Office network
config wifi-iface
    option device 'radio0'
    option network 'trm_wwan'
    option mode 'sta'
    option disabled '1'
    option ssid 'OfficeNetwork'
    option encryption 'psk2+ccmp'
    option key 'officepass456'

# Example: Coffee shop (open)
config wifi-iface
    option device 'radio0'
    option network 'trm_wwan'
    option mode 'sta'
    option disabled '1'
    option ssid 'CoffeeShop_Free'
    option encryption 'none'

# Example: Hotel (5GHz)
config wifi-iface
    option device 'radio1'
    option network 'trm_wwan'
    option mode 'sta'
    option disabled '1'
    option ssid 'Hotel_Guest_5G'
    option encryption 'psk2'
    option key 'guestpass789'
```

**Important notes:**
- All networks must have `option disabled '1'`
- Travelmate manages enabling/disabling
- All must use `option network 'trm_wwan'`
- Use `radio0` (2.4GHz) or `radio1` (5GHz) as appropriate

**Priority order:**
- First wifi-iface = highest priority
- Order matters!

### Step 2: Configure Network Interface

Edit `/etc/config/network`:

```bash
vi /etc/config/network
```

**Add travelmate uplink interface:**

```bash
config interface 'trm_wwan'
    option proto 'dhcp'
    option metric '100'
```

**Options explained:**
- `proto 'dhcp'` - Obtain IP via DHCP (most common)
- `metric '100'` - Route priority (optional, higher = lower priority)

**Alternative: Static IP**

```bash
config interface 'trm_wwan'
    option proto 'static'
    option ipaddr '192.168.1.100'
    option netmask '255.255.255.0'
    option gateway '192.168.1.1'
    option dns '8.8.8.8 8.8.4.4'
```

### Step 3: Configure Firewall

Edit `/etc/config/firewall`:

```bash
vi /etc/config/firewall
```

**Modify WAN zone to include trm_wwan:**

```bash
config zone
    option name 'wan'
    option input 'REJECT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option masq '1'
    option mtu_fix '1'
    option network 'wan wan6 trm_wwan'
```

**Key change:**
- Add `trm_wwan` to the `network` list

### Step 4: Configure Travelmate

Edit `/etc/config/travelmate`:

```bash
vi /etc/config/travelmate
```

**Basic configuration:**

```bash
config travelmate 'global'
    option trm_enabled '1'
    option trm_iface 'trm_wwan'
    option trm_minquality '35'
    option trm_maxretry '3'
    option trm_maxwait '30'
    option trm_timeout '60'
    option trm_captive '1'
```

**Advanced configuration:**

```bash
config travelmate 'global'
    option trm_enabled '1'
    option trm_iface 'trm_wwan'
    option trm_radio 'radio0'
    option trm_minquality '35'
    option trm_maxretry '3'
    option trm_maxwait '30'
    option trm_timeout '60'
    option trm_captive '1'
    option trm_scanbuffer '1024'
    option trm_maxautoadd '5'
    option trm_captiveurl 'http://captive.apple.com'
    option trm_useragent 'Mozilla/5.0'
```

**Options explained:**

| Option | Default | Description |
|--------|---------|-------------|
| trm_enabled | 0 | Enable/disable travelmate |
| trm_iface | trm_wwan | Uplink interface name |
| trm_radio | - | Specific radio (optional) |
| trm_minquality | 35 | Minimum signal quality (%) |
| trm_maxretry | 3 | Connection retry attempts |
| trm_maxwait | 30 | Wait between retries (seconds) |
| trm_timeout | 60 | Connection timeout (seconds) |
| trm_captive | 0 | Enable captive portal detection |
| trm_scanbuffer | 1024 | Scan result buffer size |
| trm_maxautoadd | 5 | Max auto-add open networks |
| trm_captiveurl | - | URL for captive portal check |
| trm_useragent | - | User agent for portal check |

### Step 5: Enable and Start

```bash
# Enable on boot
/etc/init.d/travelmate enable

# Start immediately
/etc/init.d/travelmate start

# Check status
/etc/init.d/travelmate status
```

### Apply All Configuration

```bash
# Reload network configuration
/etc/init.d/network reload

# Reload firewall
/etc/init.d/firewall reload

# Restart travelmate
/etc/init.d/travelmate restart
```

---

## Network Priority Management

### Priority Order

Networks are prioritized by their order in `/etc/config/wireless`:
- First wifi-iface (with trm_wwan) = highest priority
- Second = next priority
- And so on...

### Reorder Networks

**Method 1: Edit configuration file**

```bash
vi /etc/config/wireless

# Cut and paste wifi-iface sections to reorder
```

**Method 2: UCI commands**

```bash
# List all wifi-iface sections
uci show wireless | grep wifi-iface

# Identify section numbers
# Reorder by deleting and re-adding
```

**Example: Move network to top priority**

```bash
# Export current config
uci export wireless > /tmp/wireless.backup

# Manually edit and reorder
vi /tmp/wireless.backup

# Import back
uci import wireless < /tmp/wireless.backup
uci commit wireless
wifi reload
```

### Add New Network

```bash
# Add new wifi-iface
uci add wireless wifi-iface
uci set wireless.@wifi-iface[-1].device='radio0'
uci set wireless.@wifi-iface[-1].network='trm_wwan'
uci set wireless.@wifi-iface[-1].mode='sta'
uci set wireless.@wifi-iface[-1].disabled='1'
uci set wireless.@wifi-iface[-1].ssid='NewNetwork'
uci set wireless.@wifi-iface[-1].encryption='psk2'
uci set wireless.@wifi-iface[-1].key='password123'

# Commit
uci commit wireless

# Restart travelmate to detect
/etc/init.d/travelmate restart
```

### Remove Network

```bash
# Find section index
uci show wireless | grep -B3 "ssid='OldNetwork'"

# Delete (replace X with index)
uci delete wireless.@wifi-iface[X]

# Commit
uci commit wireless
/etc/init.d/travelmate restart
```

---

## Monitoring and Status

### Runtime Status File

**Location:** `/tmp/trm_runtime.json`

```bash
cat /tmp/trm_runtime.json
```

**Example output:**

```json
{
  "travelmate_version": "2.0.5",
  "travelmate_status": "connected (net)",
  "travelmate_enabled": "1",
  "station_id": "HomeWiFi, ec:08:6b:12:34:56, WPA2PSK (CCMP)",
  "station_interface": "trm_wwan",
  "station_radio": "radio0",
  "last_rundate": "2023-10-15 14:30:45",
  "faulty_stations": []
}
```

**Fields explained:**
- `travelmate_status` - Current state (connected, scanning, etc.)
- `station_id` - Connected network details
- `faulty_stations` - List of networks that failed

### Check Status via Command

```bash
# Travelmate service status
/etc/init.d/travelmate status

# Show detailed info
/etc/init.d/travelmate status verbose
```

### Monitor Logs

```bash
# Live log monitoring
logread -f | grep travelmate

# Show recent logs
logread | grep travelmate | tail -20
```

**Example log output:**

```
travelmate-2.0.5[12345]: travelmate instance started
travelmate-2.0.5[12345]: radio: radio0, available: HomeWiFi OfficeNetwork
travelmate-2.0.5[12345]: connected to uplink: HomeWiFi (90%)
```

### Web Interface Status

Navigate to **Services → Travelmate → Overview**

Shows:
- Connection status
- Current network
- Signal quality
- List of configured networks
- Scan button for new networks

---

## Advanced Configuration

### Captive Portal Handling

**Enable captive portal detection:**

```bash
uci set travelmate.global.trm_captive='1'
uci set travelmate.global.trm_captiveurl='http://detectportal.firefox.com'
uci commit travelmate
/etc/init.d/travelmate restart
```

**When captive portal detected:**
- Travelmate marks network as requiring login
- User redirected to portal page
- Manual login required

### Uplink Monitoring

**Configure connectivity check:**

```bash
uci set travelmate.global.trm_captiveurl='http://google.com'
uci set travelmate.global.trm_useragent='Mozilla/5.0'
uci commit travelmate
```

**Custom check script:**

Create `/etc/travelmate/travelmate.uplink`:

```bash
#!/bin/sh
# Custom uplink check

# Try to ping Google DNS
if ping -c 3 -W 2 8.8.8.8 > /dev/null 2>&1; then
    exit 0  # Success
else
    exit 1  # Failure
fi
```

Make executable:
```bash
chmod +x /etc/travelmate/travelmate.uplink
```

### Auto-add Open Networks

**Enable (19.07+):**

```bash
uci set travelmate.global.trm_maxautoadd='5'
uci commit travelmate
```

**Travelmate will:**
- Auto-discover open (unencrypted) networks
- Add up to 5 networks automatically
- Connect to them if no better option available

### Multiple Radio Support

**Use both 2.4GHz and 5GHz:**

```bash
# Add networks on both radios
# radio0 = 2.4GHz
config wifi-iface
    option device 'radio0'
    option network 'trm_wwan'
    option ssid 'Network_2.4GHz'
    ...

# radio1 = 5GHz
config wifi-iface
    option device 'radio1'
    option network 'trm_wwan'
    option ssid 'Network_5GHz'
    ...
```

**Travelmate will:**
- Scan both radios
- Connect to best available across both bands

---

## Troubleshooting

### Travelmate Not Connecting

**Problem:** Travelmate doesn't connect to any network.

**Solutions:**

1. **Check service status:**
   ```bash
   /etc/init.d/travelmate status
   ```

2. **Verify configuration:**
   ```bash
   uci show travelmate
   uci show wireless | grep trm_wwan
   ```

3. **Check logs:**
   ```bash
   logread | grep travelmate
   ```

4. **Ensure networks are disabled:**
   ```bash
   # All trm_wwan networks should be disabled='1'
   uci show wireless | grep -A10 trm_wwan | grep disabled
   ```

5. **Manual scan test:**
   ```bash
   iw dev wlan0 scan | grep SSID
   # Verify target networks visible
   ```

### Connection Drops Frequently

**Problem:** Travelmate connects but drops frequently.

**Solutions:**

1. **Increase minimum quality:**
   ```bash
   uci set travelmate.global.trm_minquality='50'
   uci commit travelmate
   ```

2. **Increase retry/timeout:**
   ```bash
   uci set travelmate.global.trm_maxretry='5'
   uci set travelmate.global.trm_timeout='90'
   uci commit travelmate
   ```

3. **Check signal strength:**
   ```bash
   iw dev wlan0-sta0 link
   # Look for signal level
   ```

### Wrong Network Priority

**Problem:** Travelmate connects to low-priority network.

**Solution:**

1. **Check priority order:**
   ```bash
   uci show wireless | grep -E "wifi-iface|ssid" | grep -B1 trm_wwan
   ```

2. **Reorder networks:**
   - Edit `/etc/config/wireless`
   - Move desired network to top of list

3. **Force rescan:**
   ```bash
   /etc/init.d/travelmate restart
   ```

### Captive Portal Not Detected

**Problem:** Connected but can't access internet (captive portal).

**Solutions:**

1. **Enable captive portal detection:**
   ```bash
   uci set travelmate.global.trm_captive='1'
   uci commit travelmate
   ```

2. **Manually access portal:**
   - Navigate to http://detectportal.firefox.com
   - Or http://captive.apple.com
   - Login to portal

3. **Check portal status:**
   ```bash
   curl -I http://detectportal.firefox.com
   # Look for redirect
   ```

### Travelmate Disables My AP

**Problem:** Access point stops working when travelmate active.

**Solution:**

This shouldn't happen. Verify:

```bash
# Check that AP interface is separate
uci show wireless | grep -E "wifi-iface|mode"

# AP should NOT use trm_wwan network
# AP uses 'lan' network, STA uses 'trm_wwan'
```

---

## Best Practices

### 1. Network Organization

```bash
# Order networks by reliability/preference
# 1. Home (most reliable)
# 2. Office (reliable)
# 3. Backup hotspot (reliable)
# 4. Coffee shops (less reliable)
# 5. Open networks (least reliable)
```

### 2. Signal Quality Thresholds

```bash
# Use appropriate minimum quality
# Weak signal = unstable connection

# For stationary use:
trm_minquality='35'  # Default

# For mobile/travel:
trm_minquality='50'  # Higher threshold
```

### 3. Timeout Configuration

```bash
# Adjust for network conditions

# Fast, reliable networks:
trm_timeout='30'

# Slow or congested networks:
trm_timeout='90'
```

### 4. Security Considerations

```bash
# Avoid storing passwords for untrusted networks
# Use VPN when on public WiFi
# Consider captive portal implications
```

### 5. Testing

```bash
# Test before travel
# Verify each network connects
# Check failover behavior

# Simulate failure:
# Disable current network and verify switch
```

### 6. Backup Connectivity

```bash
# Have backup plan
# Mobile hotspot as last resort
# Cellular USB modem failover
```

---

## References

### Official Documentation
- **Travelmate GitHub:** https://github.com/openwrt/packages/tree/master/net/travelmate
- **OpenWRT Travelmate:** https://openwrt.org/docs/guide-user/services/travelmate

### Related Pages
- **eko.one.pl Forum:** https://eko.one.pl/forum/viewtopic.php?pid=222577
- **OpenWRT WiFi Configuration:** https://openwrt.org/docs/guide-user/network/wifi/basic

### Community
- **OpenWRT Forum:** https://forum.openwrt.org/
- **Travelmate Issues:** https://github.com/openwrt/packages/issues

---

## Summary

Travelmate transforms your OpenWRT router into an intelligent travel router:

**Key Benefits:**
- Automatic connection to pre-configured WiFi networks
- Priority-based network selection
- Connection quality monitoring and failover
- Simultaneous AP mode for your devices
- Captive portal detection

**Quick Setup:**
```bash
# Install
opkg update
opkg install travelmate luci-app-travelmate

# Configure networks in /etc/config/wireless
# All use: mode='sta', network='trm_wwan', disabled='1'

# Enable
uci set travelmate.global.trm_enabled='1'
uci commit travelmate
/etc/init.d/travelmate enable
/etc/init.d/travelmate start

# Monitor
cat /tmp/trm_runtime.json
```

**Typical Use:**
1. Add WiFi networks via web interface or CLI
2. Order by priority
3. Travelmate automatically connects to best available
4. Your devices connect to router's AP
5. Seamless internet access anywhere

Perfect for travelers, mobile workers, RVs, backup connectivity, and consistent network environment for IoT devices.

---

*This guide is based on the eko.one.pl forum discussion and official OpenWRT Travelmate documentation.*
