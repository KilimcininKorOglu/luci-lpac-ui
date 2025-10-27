# OpenWRT WiFi Taxonomy Device Fingerprinting Guide

## Table of Contents
1. [Overview](#overview)
2. [What is WiFi Taxonomy](#what-is-wifi-taxonomy)
3. [Technical Background](#technical-background)
4. [Prerequisites](#prerequisites)
5. [Installation and Configuration](#installation-and-configuration)
6. [Usage and Client Querying](#usage-and-client-querying)
7. [Understanding Device Signatures](#understanding-device-signatures)
8. [Device Identification Methods](#device-identification-methods)
9. [Signature Analysis](#signature-analysis)
10. [Practical Applications](#practical-applications)
11. [Advanced Configuration](#advanced-configuration)
12. [Troubleshooting](#troubleshooting)
13. [Security Considerations](#security-considerations)
14. [References](#references)

---

## Overview

WiFi Taxonomy is a device fingerprinting technique that identifies connected WiFi clients based on their 802.11 probe and association frames. This guide explains how to implement WiFi taxonomy in OpenWRT routers using hostapd's built-in capabilities.

**Key Features:**
- Passive device identification without active scanning
- Device type and manufacturer detection
- Network behavior analysis
- Enhanced network management and security

**Based on:** Google Research publication on WiFi device fingerprinting
- **Research Paper:** https://research.google/pubs/pub45429/
- **Implementation:** https://github.com/NetworkDeviceTaxonomy/wifi_taxonomy

---

## What is WiFi Taxonomy

WiFi Taxonomy is a passive fingerprinting technique that analyzes the unique characteristics of WiFi frames sent by devices during network connection.

### How It Works

1. **Probe Requests:** Devices broadcast probe requests when searching for networks
2. **Association Requests:** Devices send association frames when connecting to an AP
3. **Signature Generation:** hostapd analyzes these frames and creates unique signatures
4. **Device Identification:** Signatures are matched against a taxonomy database

### Information Collected

- **802.11 Standards Support:** WiFi 4/5/6 capabilities
- **Channel Width:** 20MHz, 40MHz, 80MHz, 160MHz support
- **Security Capabilities:** WPA2, WPA3, encryption methods
- **Vendor-Specific IEs:** Manufacturer-specific information elements
- **HT/VHT/HE Capabilities:** MIMO, beamforming, spatial streams
- **Extended Capabilities:** Power management, QoS features

---

## Technical Background

### WiFi Frame Analysis

WiFi taxonomy analyzes the following 802.11 management frames:

**Probe Request Frames:**
- Information Elements (IEs) advertised by the client
- Supported rates and extended rates
- HT capabilities (802.11n)
- VHT capabilities (802.11ac)
- HE capabilities (802.11ax)
- Vendor-specific IEs

**Association Request Frames:**
- Similar to probe requests but sent during connection
- RSN (Robust Security Network) information
- QoS capabilities
- Power save mode preferences

### Signature Format

Signatures follow this structure:
```
wifi4|probe:IE_LIST,htcap:VALUE,htagg:VALUE,htmcs:VALUE,extcap:VALUE|assoc:IE_LIST,htcap:VALUE,htagg:VALUE,htmcs:VALUE,extcap:VALUE
```

**Components:**
- `wifi4/wifi5/wifi6`: Maximum supported 802.11 standard
- `probe:`: Information elements from probe request
- `assoc:`: Information elements from association request
- `htcap`: HT (802.11n) capability flags
- `htagg`: HT aggregation parameters
- `htmcs`: HT MCS (Modulation and Coding Scheme) set
- `vhtcap`: VHT (802.11ac) capability flags (if present)
- `extcap`: Extended capabilities

---

## Prerequisites

### Hardware Requirements
- OpenWRT-compatible router with WiFi capability
- Sufficient storage for wpad-openssl package (~400-500KB larger than basic)

### Software Requirements
- OpenWRT 19.07 or newer (21.02+ recommended)
- hostapd with taxonomy support (included in wpad-openssl)
- ubus for querying client information

### Network Requirements
- Active WiFi network (AP mode)
- Connected WiFi clients to analyze

---

## Installation and Configuration

### Step 1: Remove Basic WiFi Daemon

OpenWRT ships with lightweight WiFi daemons that don't include taxonomy support:

```bash
# Remove basic wpad packages
opkg remove wpad-basic wpad-mini

# Or if you have wpad-basic-wolfssl
opkg remove wpad-basic-wolfssl
```

**Note:** Removing wpad will temporarily disable WiFi until replacement is installed.

### Step 2: Update Package Lists

```bash
opkg update
```

### Step 3: Install wpad-openssl

```bash
# Install full-featured wpad with OpenSSL support
opkg install wpad-openssl
```

**Alternative Options:**
```bash
# If you prefer wolfSSL instead of OpenSSL
opkg install wpad-wolfssl

# Full wpad (uses internal crypto, largest package)
opkg install wpad
```

**Package Comparison:**

| Package | TLS Library | Size | Taxonomy Support |
|---------|-------------|------|------------------|
| wpad-basic | None | Smallest | No |
| wpad-basic-wolfssl | wolfSSL | Small | No |
| wpad-wolfssl | wolfSSL | Medium | Yes |
| wpad-openssl | OpenSSL | Medium | Yes |
| wpad | Internal | Largest | Yes |

### Step 4: Reboot Router

```bash
reboot
```

**Why reboot?**
- Ensures clean hostapd initialization
- Loads new WiFi daemon properly
- Reinitializes all wireless interfaces

### Step 5: Verify Installation

After reboot, check that hostapd is running with taxonomy support:

```bash
# Check hostapd process
ps | grep hostapd

# Verify wireless interfaces are up
wifi status

# Check if ubus endpoints are available
ubus list | grep hostapd
```

Expected output:
```
hostapd.wlan0
hostapd.wlan1
```

---

## Usage and Client Querying

### Basic Client Query

Query connected clients on each wireless interface:

```bash
# Query 2.4GHz clients (typically wlan0)
ubus call hostapd.wlan0 get_clients

# Query 5GHz clients (typically wlan1)
ubus call hostapd.wlan1 get_clients
```

### Example Output

```json
{
  "freq": 2437,
  "clients": {
    "aa:bb:cc:dd:ee:ff": {
      "auth": true,
      "assoc": true,
      "authorized": true,
      "preauth": false,
      "wds": false,
      "wmm": true,
      "ht": true,
      "vht": false,
      "wps": false,
      "mfp": false,
      "rrm": [0,0,0,0,0],
      "aid": 1,
      "signature": "wifi4|probe:0,1,50,3,45,221(0050f2,8),127,107,221(506f9a,16),htcap:012c,htagg:03,htmcs:000000ff,extcap:00000a820040|assoc:0,1,50,48,45,221(0050f2,2),127,htcap:012c,htagg:03,htmcs:000000ff,extcap:00000a8201400000"
    }
  }
}
```

### Query All Interfaces Automatically

```bash
#!/bin/sh
# Query all hostapd interfaces

for iface in $(ubus list | grep ^hostapd.); do
    echo "=== $iface ==="
    ubus call $iface get_clients
    echo ""
done
```

### Parse Client Information

```bash
#!/bin/sh
# Extract signatures from all connected clients

ubus call hostapd.wlan0 get_clients | jsonfilter -e '@.clients["*"].signature'
ubus call hostapd.wlan1 get_clients | jsonfilter -e '@.clients["*"].signature'
```

### Monitor New Connections

```bash
#!/bin/sh
# Monitor for new client connections

ubus subscribe hostapd.wlan0
ubus subscribe hostapd.wlan1

# Listen for events (will show association/disassociation)
ubus listen
```

---

## Understanding Device Signatures

### Signature Structure Breakdown

Let's analyze a real signature:

```
wifi4|probe:0,1,50,3,45,221(0050f2,8),127,107,221(506f9a,16),htcap:012c,htagg:03,htmcs:000000ff,extcap:00000a820040|assoc:0,1,50,48,45,221(0050f2,2),127,htcap:012c,htagg:03,htmcs:000000ff,extcap:00000a8201400000
```

**Breakdown:**

1. **wifi4** - Device supports up to 802.11n (WiFi 4)
   - wifi4 = 802.11n (2.4/5GHz)
   - wifi5 = 802.11ac (5GHz)
   - wifi6 = 802.11ax (2.4/5/6GHz)

2. **probe:0,1,50,3,45,221(...),127,107**
   - IE 0: SSID
   - IE 1: Supported Rates
   - IE 50: Extended Supported Rates
   - IE 3: DS Parameter Set
   - IE 45: HT Capabilities
   - IE 221: Vendor Specific (0050f2,8 = Wi-Fi Alliance, type 8)
   - IE 127: Extended Capabilities
   - IE 107: Interworking

3. **htcap:012c** - HT Capability flags
   - LDPC coding support
   - Channel width support (20/40MHz)
   - Short GI for 40MHz

4. **htagg:03** - HT Aggregation parameters
   - A-MPDU parameters
   - Maximum A-MPDU length exponent

5. **htmcs:000000ff** - HT MCS Set
   - Supported modulation and coding schemes
   - 000000ff = MCS 0-7 (1 spatial stream)

6. **extcap:00000a820040** - Extended Capabilities
   - BSS transition support
   - Proxy ARP
   - Operating mode notification

### Information Elements (IE) Reference

Common IEs in signatures:

| IE | Name | Purpose |
|----|------|---------|
| 0 | SSID | Network name |
| 1 | Supported Rates | Basic data rates |
| 3 | DS Parameter Set | Channel number |
| 45 | HT Capabilities | 802.11n features |
| 48 | RSN | Security capabilities |
| 50 | Extended Supported Rates | Additional rates |
| 107 | Interworking | Hotspot 2.0 |
| 127 | Extended Capabilities | Advanced features |
| 191 | VHT Capabilities | 802.11ac features |
| 221 | Vendor Specific | Manufacturer data |
| 255 | Extension (HE) | 802.11ax features |

---

## Device Identification Methods

### 1. WiFi Taxonomy Signature Matching

Match signatures against the taxonomy database:

**Database:** https://github.com/NetworkDeviceTaxonomy/wifi_taxonomy/blob/master/taxonomy/wifi.py

Example database entries:
```python
"wifi4|probe:0,1,50,3,45,221(0050f2,8),127,107,221(506f9a,16),htcap:012c": "iPhone 8",
"wifi5|probe:0,1,45,191,221(0050f2,8),127,107,vhtcap:03800032": "Samsung Galaxy S10",
```

### 2. MAC Address OUI Lookup

First three octets identify manufacturer:

```bash
# Example MAC: aa:bb:cc:dd:ee:ff
# OUI = aa:bb:cc

# Common manufacturers:
# 00:1A:11 - Google
# 3C:28:6D - Apple
# 28:11:A5 - Samsung
# DC:A6:32 - Raspberry Pi Foundation
```

**OUI Database:** https://standards-oui.ieee.org/

### 3. DHCP Hostname

Many devices provide hostname in DHCP requests:

```bash
# Check DHCP leases
cat /tmp/dhcp.leases

# Example output:
# 1635789012 aa:bb:cc:dd:ee:ff 192.168.1.100 Johns-iPhone *
```

### 4. HTTP User-Agent

For devices accessing captive portal or web interface:

```bash
# Example User-Agent strings:
# Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)
# Mozilla/5.0 (Linux; Android 11; SM-G991B)
```

### Combining Methods for Accuracy

```bash
#!/bin/sh
# Comprehensive device identification script

MAC="$1"

echo "=== Device Identification for $MAC ==="
echo ""

# 1. WiFi Taxonomy Signature
echo "WiFi Taxonomy:"
SIGNATURE=$(ubus call hostapd.wlan0 get_clients | jsonfilter -e "@.clients['$MAC'].signature")
echo "$SIGNATURE"
echo ""

# 2. OUI Lookup
echo "Manufacturer (OUI):"
OUI=$(echo $MAC | cut -d: -f1-3 | tr '[:lower:]' '[:upper:]')
grep -i "$OUI" /usr/share/ieee-oui.txt 2>/dev/null || echo "Unknown"
echo ""

# 3. DHCP Hostname
echo "DHCP Hostname:"
grep -i "$MAC" /tmp/dhcp.leases | awk '{print $4}'
echo ""

# 4. IP Address
echo "IP Address:"
grep -i "$MAC" /tmp/dhcp.leases | awk '{print $3}'
echo ""
```

---

## Signature Analysis

### Automated Device Recognition Script

```bash
#!/bin/sh
# /usr/bin/identify-devices.sh

# Download latest taxonomy database
TAXONOMY_DB="/tmp/wifi_taxonomy.txt"

if [ ! -f "$TAXONOMY_DB" ]; then
    wget -O "$TAXONOMY_DB" https://raw.githubusercontent.com/NetworkDeviceTaxonomy/wifi_taxonomy/master/taxonomy/wifi.py
fi

# Query all connected clients
for iface in wlan0 wlan1; do
    echo "=== Interface: $iface ==="

    # Get client list
    ubus call hostapd.$iface get_clients | jsonfilter -e '@.clients' | \
    while read -r mac; do
        # Remove quotes and braces
        mac=$(echo "$mac" | tr -d '"{}')

        # Get signature
        sig=$(ubus call hostapd.$iface get_clients | jsonfilter -e "@.clients['$mac'].signature")

        # Try to match in database
        device=$(grep -F "$sig" "$TAXONOMY_DB" | head -1)

        echo "MAC: $mac"
        echo "Device: ${device:-Unknown}"
        echo "Signature: $sig"
        echo ""
    done
done
```

### Real-Time Device Logging

```bash
#!/bin/sh
# Log all connecting devices with taxonomy data

LOG_FILE="/var/log/wifi_devices.log"

# Create log directory
mkdir -p /var/log

# Subscribe to hostapd events
ubus subscribe hostapd.wlan0 &
ubus subscribe hostapd.wlan1 &

# Listen for association events
ubus listen | while read -r line; do
    if echo "$line" | grep -q "assoc"; then
        # Extract MAC address from event
        MAC=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')

        if [ -n "$MAC" ]; then
            # Get device info
            for iface in wlan0 wlan1; do
                SIG=$(ubus call hostapd.$iface get_clients 2>/dev/null | \
                      jsonfilter -e "@.clients['$MAC'].signature")

                if [ -n "$SIG" ]; then
                    echo "$(date) - $MAC - $SIG" >> "$LOG_FILE"
                    break
                fi
            done
        fi
    fi
done
```

### Network Capability Analysis

```bash
#!/bin/sh
# Analyze network capabilities of connected devices

analyze_capabilities() {
    local signature="$1"

    echo "=== Capability Analysis ==="

    # WiFi generation
    if echo "$signature" | grep -q "wifi6"; then
        echo "WiFi Generation: WiFi 6 (802.11ax)"
    elif echo "$signature" | grep -q "wifi5"; then
        echo "WiFi Generation: WiFi 5 (802.11ac)"
    elif echo "$signature" | grep -q "wifi4"; then
        echo "WiFi Generation: WiFi 4 (802.11n)"
    else
        echo "WiFi Generation: Legacy (802.11a/b/g)"
    fi

    # HT support
    if echo "$signature" | grep -q "htcap:"; then
        echo "802.11n: Supported"
    fi

    # VHT support
    if echo "$signature" | grep -q "vhtcap:"; then
        echo "802.11ac: Supported"
    fi

    # HE support
    if echo "$signature" | grep -q "hecap:"; then
        echo "802.11ax: Supported"
    fi

    # WMM/QoS
    if echo "$signature" | grep -q "221(0050f2,2)"; then
        echo "WMM/QoS: Supported"
    fi
}

# Usage
MAC="aa:bb:cc:dd:ee:ff"
SIG=$(ubus call hostapd.wlan0 get_clients | jsonfilter -e "@.clients['$MAC'].signature")
analyze_capabilities "$SIG"
```

---

## Practical Applications

### 1. Network Access Control

```bash
#!/bin/sh
# Allow only known device types

ALLOWED_PATTERNS="iPhone|Samsung|Pixel|MacBook"

for iface in wlan0 wlan1; do
    ubus call hostapd.$iface get_clients | jsonfilter -e '@.clients' | \
    while read -r mac; do
        mac=$(echo "$mac" | tr -d '"{}')
        sig=$(ubus call hostapd.$iface get_clients | jsonfilter -e "@.clients['$mac'].signature")

        # Match against known database
        device=$(grep -F "$sig" /tmp/wifi_taxonomy.txt)

        if ! echo "$device" | grep -qE "$ALLOWED_PATTERNS"; then
            echo "Blocking unknown device: $mac"
            ubus call hostapd.$iface del_client "{ \"addr\": \"$mac\", \"deauth\": true, \"reason\": 5 }"
        fi
    done
done
```

### 2. QoS Based on Device Type

```bash
#!/bin/sh
# Prioritize traffic based on device type

identify_and_prioritize() {
    local mac="$1"
    local sig="$2"

    # High priority devices
    if echo "$sig" | grep -q "wifi6"; then
        # WiFi 6 devices get best QoS
        tc class add dev br-lan parent 1:1 classid 1:10 htb rate 100mbit
        tc filter add dev br-lan protocol ip parent 1:0 prio 1 u32 match ether src $mac flowid 1:10
    elif echo "$sig" | grep -q "wifi5"; then
        # WiFi 5 devices get medium priority
        tc class add dev br-lan parent 1:1 classid 1:20 htb rate 50mbit
        tc filter add dev br-lan protocol ip parent 1:0 prio 2 u32 match ether src $mac flowid 1:20
    fi
}
```

### 3. Guest Network Device Segregation

```bash
#!/bin/sh
# Automatically move IoT devices to guest network

IOT_PATTERNS="ESP8266|ESP32|Sonoff|Shelly|Tuya"

for iface in wlan0 wlan1; do
    ubus call hostapd.$iface get_clients | jsonfilter -e '@.clients' | \
    while read -r mac; do
        mac=$(echo "$mac" | tr -d '"{}')
        sig=$(ubus call hostapd.$iface get_clients | jsonfilter -e "@.clients['$mac'].signature")

        device=$(grep -F "$sig" /tmp/wifi_taxonomy.txt)

        if echo "$device" | grep -qE "$IOT_PATTERNS"; then
            echo "Moving IoT device to guest network: $mac"
            # Add to guest network MAC filter
            uci add wireless wifi-iface
            uci set wireless.@wifi-iface[-1].device='radio0'
            uci set wireless.@wifi-iface[-1].mode='ap'
            uci set wireless.@wifi-iface[-1].network='guest'
            uci set wireless.@wifi-iface[-1].ssid='IoT_Network'
            uci add_list wireless.@wifi-iface[-1].maclist="$mac"
            uci commit wireless
        fi
    done
done
```

### 4. Security Monitoring

```bash
#!/bin/sh
# Alert on unknown device connections

ALERT_EMAIL="admin@example.com"

monitor_new_devices() {
    KNOWN_DEVICES="/etc/known_wifi_devices.txt"

    ubus listen | while read -r line; do
        if echo "$line" | grep -q "assoc"; then
            MAC=$(echo "$line" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}')

            if ! grep -q "$MAC" "$KNOWN_DEVICES"; then
                # Unknown device connected
                SIG=$(ubus call hostapd.wlan0 get_clients | jsonfilter -e "@.clients['$MAC'].signature")

                # Send alert
                echo "Unknown device connected: $MAC with signature: $SIG" | \
                    mail -s "WiFi Security Alert" "$ALERT_EMAIL"

                logger -t wifi_security "Unknown device: $MAC - $SIG"
            fi
        fi
    done
}
```

### 5. Network Statistics and Reporting

```bash
#!/bin/sh
# Generate device type statistics

generate_report() {
    local report_file="/tmp/wifi_device_report.txt"

    echo "=== WiFi Device Report - $(date) ===" > "$report_file"
    echo "" >> "$report_file"

    # Count by WiFi generation
    echo "Devices by WiFi Generation:" >> "$report_file"

    for iface in wlan0 wlan1; do
        ubus call hostapd.$iface get_clients | jsonfilter -e '@.clients["*"].signature' | \
        while read -r sig; do
            if echo "$sig" | grep -q "wifi6"; then echo "WiFi 6"; fi
            if echo "$sig" | grep -q "wifi5"; then echo "WiFi 5"; fi
            if echo "$sig" | grep -q "wifi4"; then echo "WiFi 4"; fi
        done | sort | uniq -c >> "$report_file"
    done

    cat "$report_file"
}

# Run daily via cron
# Add to /etc/crontabs/root:
# 0 0 * * * /usr/bin/generate_wifi_report.sh
```

---

## Advanced Configuration

### Enable Detailed Logging in hostapd

Edit `/etc/config/wireless`:

```bash
uci set wireless.radio0.log_level=1
uci set wireless.radio1.log_level=1
uci commit wireless
wifi reload
```

View detailed logs:
```bash
logread | grep hostapd
```

### Custom hostapd Configuration

For advanced taxonomy features, edit `/var/run/hostapd-wlan0.conf`:

```bash
# Enable taxonomy
taxonomy=1

# Log all probe requests
logger_syslog=-1
logger_syslog_level=2

# Enable additional debugging
debug=2
```

**Note:** Changes to `/var/run/hostapd-*.conf` are temporary and reset on WiFi reload.

### Persistent Custom Configuration

Create UCI override:

```bash
# Add custom hostapd options
uci set wireless.radio0.hostapd_options='taxonomy=1'
uci commit wireless
wifi reload
```

### Integration with RADIUS/AAA

```bash
# Configure RADIUS with device fingerprinting
uci set wireless.@wifi-iface[0].auth_server='192.168.1.10'
uci set wireless.@wifi-iface[0].auth_port='1812'
uci set wireless.@wifi-iface[0].auth_secret='secret123'

# Enable MAC address authentication with taxonomy
uci set wireless.@wifi-iface[0].macfilter='radius'
uci commit wireless
wifi reload
```

---

## Troubleshooting

### Signature Field is Empty or Missing

**Problem:** `ubus call hostapd.wlan0 get_clients` returns no signature field.

**Solutions:**

1. **Verify wpad-openssl is installed:**
   ```bash
   opkg list-installed | grep wpad
   ```
   Should show: `wpad-openssl`

2. **Check hostapd version:**
   ```bash
   hostapd -v
   ```
   Should include taxonomy support.

3. **Reinstall wpad-openssl:**
   ```bash
   opkg remove wpad-openssl
   opkg update
   opkg install wpad-openssl
   reboot
   ```

4. **Not all clients provide signatures:**
   Some simple devices (IoT, legacy WiFi) may not send enough information for signature generation.

### ubus Command Not Found

**Problem:** `ubus: command not found`

**Solution:**
```bash
opkg update
opkg install ubus
```

### No Clients Shown

**Problem:** `get_clients` returns empty client list.

**Solutions:**

1. **Verify clients are connected:**
   ```bash
   iw dev wlan0 station dump
   ```

2. **Check interface name:**
   ```bash
   ubus list | grep hostapd
   ```
   Use correct interface name (wlan0, wlan1, phy0-ap0, etc.)

3. **Ensure WiFi is enabled:**
   ```bash
   wifi status
   wifi up
   ```

### Permission Denied Errors

**Problem:** `ubus call` returns permission denied.

**Solution:**
```bash
# Run as root
sudo ubus call hostapd.wlan0 get_clients

# Or add user to ubus group
```

### Signature Database Not Updating

**Problem:** Old or incomplete device identification.

**Solution:**
```bash
# Download latest taxonomy database
wget -O /tmp/wifi_taxonomy.py \
    https://raw.githubusercontent.com/NetworkDeviceTaxonomy/wifi_taxonomy/master/taxonomy/wifi.py

# Or clone entire repository
opkg install git
git clone https://github.com/NetworkDeviceTaxonomy/wifi_taxonomy.git /opt/wifi_taxonomy
```

### High CPU Usage After Installation

**Problem:** wpad-openssl uses more CPU than wpad-basic.

**Solutions:**

1. **Use wpad-wolfssl instead (lighter):**
   ```bash
   opkg remove wpad-openssl
   opkg install wpad-wolfssl
   ```

2. **Disable taxonomy if not needed:**
   Remove `taxonomy=1` from hostapd configuration.

3. **Reduce logging level:**
   ```bash
   uci set wireless.radio0.log_level=0
   uci commit wireless
   ```

---

## Security Considerations

### Privacy Concerns

**WiFi taxonomy can be used for tracking:**
- Device fingerprints are persistent across networks
- Signatures can identify specific device models
- Combined with MAC addresses, enables user tracking

**Privacy Protection:**
- MAC randomization partially defeats tracking
- Modern devices (iOS 14+, Android 10+) randomize MAC addresses
- Signature can still identify device type even with randomized MAC

### Access Control

**Do not rely solely on signatures for security:**
- Signatures can be spoofed with custom drivers
- Use WPA2/WPA3 encryption in addition to MAC/signature filtering
- Implement RADIUS/802.1X for enterprise environments

### Data Protection

**Protect taxonomy data:**
```bash
# Restrict access to logs
chmod 600 /var/log/wifi_devices.log

# Encrypt stored data
opkg install openvpn-openssl
# Use encrypted storage for sensitive device databases
```

### Compliance

**GDPR and data protection:**
- MAC addresses and device signatures are personal data
- Inform users about device fingerprinting
- Implement data retention policies
- Provide opt-out mechanisms where required

---

## References

### Official Documentation
- **Google Research Paper:** https://research.google/pubs/pub45429/
- **WiFi Taxonomy GitHub:** https://github.com/NetworkDeviceTaxonomy/wifi_taxonomy
- **OpenWRT Wireless:** https://openwrt.org/docs/guide-user/network/wifi/basic
- **hostapd Documentation:** https://w1.fi/hostapd/

### OpenWRT Development
- **PR #16568:** User fingerprinting functionality (October 2024)
- **wpad Variants:** https://openwrt.org/packages/pkgdata/wpad-openssl

### Related Technologies
- **802.11 Standards:** https://standards.ieee.org/ieee/802.11/7028/
- **OUI Database:** https://standards-oui.ieee.org/
- **ubus Documentation:** https://openwrt.org/docs/techref/ubus

### Community Resources
- **eko.one.pl Forum:** https://eko.one.pl/forum/
- **OpenWRT Forum:** https://forum.openwrt.org/

---

## Summary

WiFi Taxonomy provides powerful device fingerprinting capabilities in OpenWRT:

**Key Benefits:**
- Passive device identification without active scanning
- Enhanced network management and visibility
- Security monitoring and anomaly detection
- QoS optimization based on device capabilities

**Implementation Steps:**
1. Install `wpad-openssl` to replace basic wpad
2. Query clients using `ubus call hostapd.wlanX get_clients`
3. Analyze signatures against taxonomy database
4. Implement custom scripts for automation

**Important Notes:**
- Not all devices provide complete signatures
- Combine with MAC OUI, DHCP hostname, and User-Agent for best results
- Consider privacy implications and regulatory compliance
- Keep taxonomy database updated for accurate identification

**Recent Development:**
As of October 2024, official OpenWRT support for user fingerprinting has been merged, providing enhanced capabilities for device identification and network management.

---

*This guide is based on the eko.one.pl forum discussion and Google Research on WiFi device fingerprinting. For the latest updates, refer to the OpenWRT and WiFi Taxonomy GitHub repositories.*
