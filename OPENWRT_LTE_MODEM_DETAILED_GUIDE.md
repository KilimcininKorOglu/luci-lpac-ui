# OpenWRT LTE Modem Detailed Configuration Guide

## Table of Contents
1. [Overview](#overview)
2. [LTE Technology Background](#lte-technology-background)
3. [General Requirements](#general-requirements)
4. [Operating Modes](#operating-modes)
5. [Huawei E398 Series](#huawei-e398-series)
6. [Huawei E3272/E3276 Series](#huawei-e3272e3276-series)
7. [ZTE MF821D](#zte-mf821d)
8. [Alcatel L800](#alcatel-l800)
9. [Protocol Comparison](#protocol-comparison)
10. [Performance Optimization](#performance-optimization)
11. [Troubleshooting](#troubleshooting)
12. [Advanced Configuration](#advanced-configuration)

---

## Overview

This guide provides in-depth technical documentation for configuring LTE modems on OpenWRT. Unlike general guides, this document focuses on specific LTE modem models with detailed device information, USB interface mapping, performance characteristics, and real-world configuration examples.

### What Makes LTE Modems Different?

LTE (4G) modems differ from older 3G modems in several ways:

1. **Higher Speeds**: LTE Cat 3-4 modems support 100-150 Mbps downloads
2. **Multiple Protocols**: Support for QMI, MBIM, NCM, not just PPP
3. **More Complex Configuration**: Multiple USB interfaces with different functions
4. **MIMO Support**: Multiple antennas for improved performance
5. **Carrier Aggregation**: Combining multiple frequency bands

### Document Purpose

This guide documents:
- **Real device configurations** that have been tested and verified
- **USB interface mappings** (which ttyUSB* is for what)
- **Actual performance data** from real-world testing
- **Protocol-specific optimizations** for each modem
- **Troubleshooting solutions** for common issues

---

## LTE Technology Background

### LTE Categories

| Category | Max Download | Max Upload | Technology |
|----------|-------------|-----------|------------|
| Cat 1 | 10 Mbps | 5 Mbps | Basic LTE |
| Cat 3 | 100 Mbps | 50 Mbps | Standard LTE |
| Cat 4 | 150 Mbps | 50 Mbps | Enhanced LTE |
| Cat 6 | 300 Mbps | 50 Mbps | LTE-Advanced |
| Cat 9 | 450 Mbps | 50 Mbps | 3x Carrier Aggregation |
| Cat 12 | 600 Mbps | 100 Mbps | 4x Carrier Aggregation |
| Cat 16 | 1 Gbps | 150 Mbps | 4x4 MIMO |

### Frequency Bands

LTE operates on multiple frequency bands worldwide:

**Europe (Primary):**
- Band 3 (1800 MHz) - Most common
- Band 7 (2600 MHz) - High speed
- Band 20 (800 MHz) - Rural coverage

**USA:**
- Band 2, 4, 5, 12, 13, 17, 25, 26, 66, 71

**Asia:**
- Band 1, 3, 5, 8, 38, 39, 40, 41

### MIMO (Multiple Input Multiple Output)

- **2x2 MIMO**: Two antennas, standard for LTE
- **4x4 MIMO**: Four antennas, LTE-Advanced
- **Benefits**: Improved speed and reliability

---

## General Requirements

### Essential Packages

All LTE modems require base packages:

```bash
opkg update

# USB support
opkg install kmod-usb-core kmod-usb2 kmod-usb3
opkg install usbutils

# Mode switching
opkg install usb-modeswitch

# Serial drivers (for PPP mode)
opkg install kmod-usb-serial
opkg install kmod-usb-serial-option
opkg install kmod-usb-serial-wwan

# PPP support
opkg install ppp ppp-mod-pppoe
opkg install chat comgt
```

### Protocol-Specific Packages

**For QMI Protocol:**
```bash
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi
opkg install luci-proto-qmi  # Web interface
```

**For MBIM Protocol:**
```bash
opkg install kmod-usb-net-cdc-mbim
opkg install umbim
opkg install luci-proto-mbim  # Web interface
```

**For NCM Protocol:**
```bash
opkg install kmod-usb-net-cdc-ncm
opkg install kmod-usb-net-huawei-cdc-ncm  # For Huawei
opkg install comgt-ncm
opkg install luci-proto-ncm  # Web interface
```

**For RNDIS Protocol:**
```bash
opkg install kmod-usb-net-rndis
```

---

## Operating Modes

### RAS Mode (PPP/Serial)

**Characteristics:**
- Traditional dial-up style connection
- Uses `/dev/ttyUSB*` devices
- Speed limited to ~30 Mbps
- Universal compatibility
- Higher CPU usage

**When to Use:**
- Fallback when other modes don't work
- Older OpenWRT versions
- Debugging connection issues

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci commit network
```

### NDIS/NCM Mode

**Characteristics:**
- Modem appears as network card
- Full LTE speed support
- Uses `/dev/cdc-wdm*` devices
- Low CPU overhead
- Modern standard

**When to Use:**
- Primary mode for LTE modems
- When maximum speed is needed
- Modern OpenWRT (19.07+)

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='ncm'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='IP'
uci commit network
```

### QMI Mode

**Characteristics:**
- Qualcomm proprietary protocol
- Excellent performance
- Rich feature set
- Good OpenWRT support

**When to Use:**
- Qualcomm-based modems
- When advanced features needed
- Best overall choice for compatible modems

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='ipv4v6'
uci commit network
```

---

## Huawei E398 Series

### Huawei E398 u-18

**Overview:**
- LTE Cat 3 modem (100 Mbps download)
- Five USB serial interfaces
- Supports LTE and HSPA+ fallback
- Good availability and pricing

#### USB Interface Mapping

```bash
lsusb -t
# After mode switch, creates 5 serial ports:

/dev/ttyUSB0 - Debug/Diagnostic port (usually inactive)
/dev/ttyUSB1 - Diagnostic interface (AT commands) ← PRIMARY AT PORT
/dev/ttyUSB2 - PCUI (Huawei PC UI protocol)
/dev/ttyUSB3 - GPS NMEA data (if available)
/dev/ttyUSB4 - PPP data connection
```

**Note:** Unlike most Huawei modems where ttyUSB0 is the AT port, the E398 u-18 uses **ttyUSB1** for AT commands.

#### Device Information

**USB IDs:**
- Before mode switch: `12d1:1505`
- After mode switch: `12d1:1506`

**AT Command Response (ATI):**
```
Manufacturer: huawei
Model: E398
Revision: 11.126.16.00.00
IMEI: xxxxxxxxxxxxx
+GCAP: +CGSM,+DS,+ES
```

**System Info (AT^SYSINFOEX):**
```
^SYSINFOEX: 2,4,0,5,,3,"WCDMA",41,"WCDMA 2100"
- Service status: 2 (Available)
- Service domain: 4 (No service)
- Roaming: 0 (Not roaming)
- System mode: 5 (WCDMA)
- SIM state: 3 (Valid)
```

**Supported Bands:**
- LTE: Band 7 (2600 MHz), Band 20 (800 MHz)
- UMTS: Band 1 (2100 MHz), Band 8 (900 MHz)
- GSM: 900/1800 MHz

#### Installation

```bash
# Install required packages
opkg install kmod-usb-serial-option
opkg install usb-modeswitch
opkg install comgt ppp chat

# Mode switch happens automatically, or manually:
usb_modeswitch -v 12d1 -p 1505 -M '55534243123456780000000000000611062000000000000000000000000000'

# Verify devices
ls -l /dev/ttyUSB*
```

#### Configuration - PPP Mode

```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB4'  # Data port
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci commit network

# Add to WAN zone
uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

#### Performance

**Test Results:**
- Protocol: HSPA+ (LTE not available in test area)
- Download speed: **2.21 MB/s** (17.68 Mbps)
- Upload speed: ~5 Mbps
- Latency: 40-60 ms
- CPU usage: 10-15% on typical router

#### AT Commands for E398 u-18

```bash
# Use ttyUSB1 for AT commands (not ttyUSB0!)
AT_PORT=/dev/ttyUSB1

# Get signal strength
echo "AT+CSQ" > $AT_PORT; cat $AT_PORT
# Response: +CSQ: 18,99

# Get detailed signal info
echo "AT^HCSQ?" > $AT_PORT; cat $AT_PORT

# Force LTE mode
echo "AT^SYSCFGEX=\"03\",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,," > $AT_PORT

# Auto mode (LTE/HSPA+/GSM)
echo "AT^SYSCFGEX=\"00\",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,," > $AT_PORT

# Get current network mode
echo "AT^SYSINFOEX" > $AT_PORT; cat $AT_PORT
```

### Huawei E398 u-1

**Overview:**
- Similar to u-18 but different band support
- Dual external antenna connectors (better MIMO)
- Distributed through Cyfrowy Polsat (Poland)

#### Key Differences from u-18

**USB IDs:**
- Before mode switch: `12d1:1505`
- After mode switch: `12d1:1506`

**Supported Bands:**
- GSM: 900/1800 MHz
- WCDMA: Band 1 (2100 MHz), Band 8 (900 MHz)
- LTE: Band 3 (1800 MHz), Band 7 (2600 MHz), Band 20 (800 MHz)

**Physical Features:**
- Two external antenna connectors
- Better for external antenna setup
- Improved reception with dual antennas

#### Configuration

Same as E398 u-18 (configuration is identical).

#### External Antenna Connection

**Antenna Types:**
- Two TS9 or SMA connectors (model-dependent)
- Use dual MIMO antennas for best performance
- Position antennas perpendicular to each other

**Expected Improvement:**
- 10-20 dB signal gain
- More stable connection
- Higher speeds in fringe areas

---

## Huawei E3272/E3276 Series

### Huawei E3272

**Overview:**
- LTE Cat 4 modem (150 Mbps download)
- Single diagnostic interface
- Supports NCM and QMI modes
- Compact USB stick form factor

#### USB Interface Mapping

```bash
# After mode switch:
/dev/ttyUSB0 - Diagnostic/AT command interface (ONLY ONE)
/dev/cdc-wdm0 - NCM/QMI control interface
```

**Important:** E3272 creates only ONE serial port (ttyUSB0), not multiple like E398.

#### Device Information

**USB IDs:**
- Before mode switch: `12d1:155e`
- After mode switch: `12d1:14dc`

**Supported Bands:**
- LTE: Band 1, 3, 7, 8, 20, 38, 40
- UMTS: Band 1, 8
- GSM: 900/1800 MHz

#### Installation

```bash
# Install NCM drivers
opkg install kmod-usb-net-cdc-ncm
opkg install kmod-usb-net-huawei-cdc-ncm
opkg install comgt-ncm

# Or install QMI drivers
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi

# Mode switch
usb_modeswitch -v 12d1 -p 155e -M '55534243123456780000000000000611062000000000000000000000000000'
```

#### Configuration - NCM Mode (Recommended)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='ncm'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='IP'
uci set network.wwan.delay='15'
uci set network.wwan.pincode='1234'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

#### Configuration - QMI Mode (Alternative)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='ipv4v6'
uci set network.wwan.pincode='1234'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

#### Enable RAS/PPP Mode (If Needed)

Some E3272 modems boot in NCM-only mode. To enable PPP:

```bash
# Send AT command to enable serial ports
echo -e 'AT^SETPORT="A1,A2;1,2,3"\r' > /dev/ttyUSB0

# Or full port configuration
echo -e 'AT^SETPORT="FF;10,12,13,14,16,A1,A2"\r' > /dev/ttyUSB0

# Replug modem after this command
```

**Port Configuration Explanation:**
- `A1,A2` - NCM interfaces
- `1,2,3` - Serial diagnostic, AT, PPP ports
- `FF` - All ports
- `10,12,13,14,16` - Various control interfaces

### Huawei E3276

**Overview:**
- LTE Cat 4 modem (150 Mbps download)
- Improved version of E3272
- Better band support
- Rotatable USB connector

#### Key Features

- **Swivel USB Connector**: Rotates 180° for better placement
- **Band Support**: More LTE bands than E3272
- **Performance**: Up to 150 Mbps download, 50 Mbps upload
- **MIMO**: 2x2 MIMO support

#### Configuration

Same as E3272 - use NCM or QMI mode.

#### AT Commands for E3272/E3276

```bash
# Port is /dev/ttyUSB0 (only one serial port)
AT_PORT=/dev/ttyUSB0

# Get modem info
echo "ATI" > $AT_PORT; cat $AT_PORT

# Get signal
echo "AT+CSQ" > $AT_PORT; cat $AT_PORT

# Get network info
echo "AT^SYSINFOEX" > $AT_PORT; cat $AT_PORT

# Force LTE only
echo "AT^SYSCFGEX=\"03\",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,," > $AT_PORT

# Check current port configuration
echo "AT^SETPORT?" > $AT_PORT; cat $AT_PORT

# Enable all ports
echo "AT^SETPORT=\"FF;10,12,13,14,16,A1,A2\"" > $AT_PORT
```

---

## ZTE MF821D

**Overview:**
- LTE Cat 3 modem (100 Mbps download)
- Four USB serial interfaces
- Excellent QMI support
- Cost-effective option

### USB Interface Mapping

```bash
# After mode switch, creates 4 serial ports:
/dev/ttyUSB0 - AT command interface (general)
/dev/ttyUSB1 - AT command interface (alternate)
/dev/ttyUSB2 - Primary data/AT interface ← USE THIS
/dev/ttyUSB3 - Debug interface

/dev/cdc-wdm0 - QMI control interface
```

**Important:** Use **ttyUSB2** for AT commands and PPP data.

### Device Information

**USB IDs:**
- Before mode switch: `19d2:0166`
- After mode switch: `19d2:0167`

**AT Command Response (ATI):**
```
Manufacturer: ZTE INCORPORATED
Model: MF821D
Revision: BD_3GEFGP821DM14V1.0.0B03
IMEI: xxxxxxxxxxxxx
```

**Supported Bands:**
- LTE: Band 1, 3, 7, 8, 20
- UMTS: Band 1, 8
- GSM: 900/1800 MHz

### Installation

```bash
# Install QMI support (recommended)
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi

# Or serial/PPP support
opkg install kmod-usb-serial-option
opkg install comgt ppp

# Mode switch
usb_modeswitch -v 19d2 -p 0166 -M '5553424312345678000000000000061b000000020000000000000000000000'

# Verify
lsusb
# Should show: ID 19d2:0167
```

### Configuration - QMI Mode (Recommended)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='ipv4v6'
uci set network.wwan.pincode='1234'
uci set network.wwan.autoconnect='1'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### Configuration - PPP Mode (Alternative)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB2'  # Important: ttyUSB2
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### AT Commands for MF821D

```bash
# Use ttyUSB2 for best compatibility
AT_PORT=/dev/ttyUSB2

# Get signal strength
echo "AT+CSQ" > $AT_PORT; cat $AT_PORT

# Get system info
echo "AT+ZRSSI" > $AT_PORT; cat $AT_PORT  # ZTE-specific signal command
echo "AT+ZPAS?" > $AT_PORT; cat $AT_PORT  # Network status

# Set LTE only mode
echo "AT+ZSNT=6,0,0" > $AT_PORT; cat $AT_PORT

# Set auto mode (LTE/UMTS/GSM)
echo "AT+ZSNT=0,0,0" > $AT_PORT; cat $AT_PORT

# Network mode options:
# 0 = Auto
# 1 = GSM only
# 2 = WCDMA only
# 6 = LTE only

# Get current network mode
echo "AT+ZSNT?" > $AT_PORT; cat $AT_PORT

# Get network registration
echo "AT+CREG?" > $AT_PORT; cat $AT_PORT
echo "AT+CEREG?" > $AT_PORT; cat $AT_PORT  # LTE registration
```

### QMI Commands for MF821D

```bash
# Get device info
uqmi -d /dev/cdc-wdm0 --get-device-operating-mode

# Get signal info
uqmi -d /dev/cdc-wdm0 --get-signal-info

# Get network info
uqmi -d /dev/cdc-wdm0 --get-serving-system

# Start network
uqmi -d /dev/cdc-wdm0 --start-network internet --autoconnect

# Get current settings
uqmi -d /dev/cdc-wdm0 --get-current-settings
```

---

## Alcatel L800

**Overview:**
- LTE Cat 4 modem (150 Mbps download)
- RNDIS mode (appears as network card)
- Built-in web interface
- Unique configuration approach

### Characteristics

**Operating Mode:**
- RNDIS (Remote Network Driver Interface Specification)
- Modem creates its own network with built-in DHCP
- Acts as router with web interface

**Network Configuration:**
- Default IP: `192.168.1.1`
- DHCP range: `192.168.1.100-192.168.1.200`
- Web interface: `http://192.168.1.1`

### USB Interface

```bash
# Creates RNDIS network interface
usb0 or eth1 (depends on system)

# No serial ports created
# All configuration via web interface or RNDIS
```

### Device Information

**USB ID:**
- `1bbb:0195` (Alcatel L800)

**Supported Bands:**
- LTE: Band 1, 3, 7, 8, 20, 38, 40
- UMTS: Band 1, 8
- GSM: 900/1800 MHz

### Installation

```bash
# Install RNDIS support
opkg install kmod-usb-net-rndis

# No mode switch needed
# Device appears immediately as network interface
```

### Configuration - OpenWRT as Client

**Method 1: DHCP Client (Simple)**

```bash
uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.ifname='usb0'  # or eth1
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

**Method 2: Static IP**

```bash
uci set network.wwan=interface
uci set network.wwan.proto='static'
uci set network.wwan.ifname='usb0'
uci set network.wwan.ipaddr='192.168.1.100'
uci set network.wwan.netmask='255.255.255.0'
uci set network.wwan.gateway='192.168.1.1'
uci set network.wwan.dns='192.168.1.1'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### Handling IP Conflicts

**Problem:** Router LAN and modem both use 192.168.1.x

**Solution 1: Change Router LAN**
```bash
uci set network.lan.ipaddr='192.168.2.1'
uci set network.lan.netmask='255.255.255.0'
uci commit network
/etc/init.d/network restart
```

**Solution 2: Access Modem Web Interface and Change**
- Connect to modem at `http://192.168.1.1`
- Login (default: admin/admin)
- Settings → LAN → Change IP to 192.168.8.1
- Update OpenWRT configuration accordingly

### Modem Configuration via Web Interface

Access `http://192.168.1.1`:

1. **Login**: admin/admin (default)
2. **Settings → Mobile Network**:
   - Set APN
   - Network mode (Auto/LTE only/3G only)
   - Band selection
   - PIN code
3. **Settings → Connection**:
   - Connection mode (Auto/Manual)
   - Roaming settings
4. **Status → Information**:
   - Signal strength
   - Connected band
   - Data usage

### Performance

**Advantages:**
- Simple setup (no protocol configuration)
- Full speed support
- Built-in web interface
- No OpenWRT protocol drivers needed

**Disadvantages:**
- IP address conflict potential
- Double NAT scenario
- Less control from OpenWRT
- Cannot use advanced features like SMS

---

## Protocol Comparison

### Performance Comparison

| Protocol | Max Speed | CPU Usage | Latency | OpenWRT Support | Complexity |
|----------|-----------|-----------|---------|-----------------|------------|
| PPP/Serial | ~30 Mbps | High | Medium | Excellent | Low |
| QMI | Full LTE | Low | Low | Excellent | Medium |
| MBIM | Full LTE | Low | Low | Good | Medium |
| NCM | Full LTE | Low | Low | Good | Medium |
| RNDIS/HiLink | Full LTE | Very Low | Low | Good | Very Low |

### Protocol Selection Guide

**Use QMI when:**
- ✅ Modem supports it (most Huawei, ZTE, Quectel)
- ✅ Need maximum control (band selection, mode, etc.)
- ✅ Want best performance
- ✅ Using modern OpenWRT (19.07+)

**Use MBIM when:**
- ✅ Modem doesn't support QMI
- ✅ Newer modem (2018+)
- ✅ Multi-carrier/roaming scenarios
- ✅ Windows-certified modem

**Use NCM when:**
- ✅ Huawei modem without QMI
- ✅ Simple network card operation needed
- ✅ Good compatibility required

**Use PPP when:**
- ✅ Other modes don't work
- ✅ Older OpenWRT version
- ✅ Maximum compatibility needed
- ✅ Speed not critical

**Use RNDIS/HiLink when:**
- ✅ Simplest setup needed
- ✅ Double NAT acceptable
- ✅ Modem has built-in router features

---

## Performance Optimization

### Antenna Optimization

**External Antenna Benefits:**
- 10-20 dB signal improvement
- More stable connection
- Higher sustained speeds
- Better penetration through buildings

**MIMO Antenna Setup:**
```
For 2x2 MIMO:
- Use two identical antennas
- Position perpendicular to each other (90° angle)
- Place 20-30 cm apart minimum
- Point in direction of cell tower
```

**Antenna Types:**
- **Omnidirectional**: Good for general use, unknown tower location
- **Directional (Yagi)**: Best performance when tower location known
- **Panel**: Good compromise between omni and directional

### Signal Quality Monitoring

**Check signal strength regularly:**

```bash
# For QMI modems
uqmi -d /dev/cdc-wdm0 --get-signal-info

# For AT command modems
echo "AT+CSQ" > /dev/ttyUSB0; cat /dev/ttyUSB0
```

**Signal Quality Thresholds:**
- **RSSI** (Received Signal Strength Indicator):
  - Excellent: > -60 dBm
  - Good: -60 to -70 dBm
  - Fair: -70 to -80 dBm
  - Poor: -80 to -90 dBm
  - Very Poor: < -90 dBm

- **RSRP** (Reference Signal Received Power):
  - Excellent: > -80 dBm
  - Good: -80 to -90 dBm
  - Fair: -90 to -100 dBm
  - Poor: < -100 dBm

- **RSRQ** (Reference Signal Received Quality):
  - Excellent: > -10 dB
  - Good: -10 to -15 dB
  - Fair: -15 to -20 dB
  - Poor: < -20 dB

- **SINR** (Signal to Interference plus Noise Ratio):
  - Excellent: > 20 dB
  - Good: 13 to 20 dB
  - Fair: 0 to 13 dB
  - Poor: < 0 dB

### Band Selection for Performance

**Force best performing band:**

```bash
# Huawei - Lock to Band 3 (1800 MHz) - usually fastest
echo 'AT^SYSCFGEX="03",800,1,2,800,,' > /dev/ttyUSB0

# ZTE - Lock to Band 3
echo 'AT+ZBAND=3' > /dev/ttyUSB2

# Auto mode (all bands)
echo 'AT^SYSCFGEX="03",3FFFFFFF,1,2,7FFFFFFFFFFFFFFF,,' > /dev/ttyUSB0
```

**Band Selection Strategy:**
1. Test each band individually
2. Run speed test on each
3. Note signal quality on each
4. Select best performing band
5. Lock to that band during peak usage

### MTU Optimization

**LTE typically works best with lower MTU:**

```bash
# Set MTU to 1420 (good for LTE)
uci set network.wwan.mtu='1420'
uci commit network
ifup wwan

# Or try 1428, 1440 (experiment)
```

### TCP Optimization

```bash
# Create /etc/sysctl.d/99-lte-optimization.conf
cat > /etc/sysctl.d/99-lte-optimization.conf << 'EOF'
# TCP congestion control
net.ipv4.tcp_congestion_control=bbr

# Buffer sizes for LTE
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864

# Enable window scaling
net.ipv4.tcp_window_scaling=1

# Enable timestamps
net.ipv4.tcp_timestamps=1

# Enable selective acknowledgements
net.ipv4.tcp_sack=1

# Fast retransmit
net.ipv4.tcp_fastopen=3
EOF

# Apply
sysctl -p /etc/sysctl.d/99-lte-optimization.conf
```

### QoS Configuration

**SQM for LTE:**

```bash
opkg install sqm-scripts luci-app-sqm

# Configure
uci set sqm.wwan=queue
uci set sqm.wwan.enabled='1'
uci set sqm.wwan.interface='wwan0'
uci set sqm.wwan.download='80000'  # 80% of max download in kbit/s
uci set sqm.wwan.upload='40000'     # 80% of max upload in kbit/s
uci set sqm.wwan.script='piece_of_cake.qos'
uci set sqm.wwan.qdisc='cake'
uci set sqm.wwan.linklayer='none'
uci commit sqm

/etc/init.d/sqm restart
```

---

## Troubleshooting

### Mode Switch Fails

**Symptoms:**
- Modem appears as CD-ROM
- No /dev/ttyUSB* or /dev/cdc-wdm* created

**Solutions:**

1. **Manual mode switch:**
```bash
lsusb  # Note vendor:product ID

# Huawei
usb_modeswitch -v 12d1 -p 1505 -M '55534243123456780000000000000611062000000000000000000000000000'

# ZTE
usb_modeswitch -v 19d2 -p 0166 -M '5553424312345678000000000000061b000000020000000000000000000000'
```

2. **Check usb-modeswitch is installed:**
```bash
opkg list-installed | grep usb-modeswitch
```

3. **Check dmesg for errors:**
```bash
dmesg | tail -50
```

### Wrong Serial Port Selection

**Symptoms:**
- Connection fails immediately
- AT commands don't respond
- PPP negotiation fails

**Solutions:**

**Test all ports:**
```bash
for port in /dev/ttyUSB*; do
    echo "=== Testing $port ==="
    echo -e "ATI\r" > $port
    timeout 2 cat $port 2>/dev/null | head -10
    echo ""
done
```

**Port Usage Guide:**
- **Huawei E398 u-18**: Use ttyUSB1 for AT, ttyUSB4 for PPP
- **Huawei E3272**: Use ttyUSB0 (only one port)
- **ZTE MF821D**: Use ttyUSB2 for both AT and PPP

### QMI Connection Fails

**Check device presence:**
```bash
ls -l /dev/cdc-wdm*
# Should exist after mode switch
```

**Manual QMI test:**
```bash
# Check if device responds
uqmi -d /dev/cdc-wdm0 --get-device-operating-mode

# If error, check kernel modules
lsmod | grep qmi

# Reload modules
rmmod qmi_wwan
insmod qmi_wwan
```

**Check logs:**
```bash
logread | grep -i "qmi\|wwan"
```

### NCM Connection Fails

**Check NCM device:**
```bash
ls -l /dev/cdc-wdm*
ifconfig -a | grep wwan
```

**Enable NCM interface (Huawei):**
```bash
# Some modems need AT command to enable NCM
echo -e 'AT^NDISDUP=1,1,"internet"\r' > /dev/ttyUSB0
```

**Check logs:**
```bash
logread | grep -i "ncm\|cdc"
```

### Slow Speeds on LTE

**Diagnose:**

1. **Check if using PPP:**
```bash
uci show network.wwan.proto
# If "3g", limited to ~30 Mbps
```

2. **Check signal quality:**
```bash
uqmi -d /dev/cdc-wdm0 --get-signal-info
# or
echo "AT+CSQ" > /dev/ttyUSB0; cat /dev/ttyUSB0
```

3. **Check connected technology:**
```bash
# Huawei
echo "AT^SYSINFOEX" > /dev/ttyUSB0; cat /dev/ttyUSB0

# ZTE
echo "AT+ZPAS?" > /dev/ttyUSB2; cat /dev/ttyUSB2
```

**Solutions:**

1. **Switch to QMI/NCM mode** (if using PPP)
2. **Improve signal** (external antenna, better position)
3. **Force LTE mode** (disable 3G fallback)
4. **Select best band**
5. **Check operator throttling** (data cap reached?)

### Random Disconnections

**Implement watchdog:**

```bash
cat > /root/lte-watchdog.sh << 'EOF'
#!/bin/bash

INTERFACE="wwan"
PING_HOST="8.8.8.8"
LOG="/var/log/lte-watchdog.log"

log_msg() {
    echo "[$(date)] $1" >> "$LOG"
}

# Ping test
if ! ping -c 3 -W 5 -I $INTERFACE $PING_HOST >/dev/null 2>&1; then
    log_msg "Connection lost, restarting interface"
    ifdown $INTERFACE
    sleep 5
    ifup $INTERFACE
else
    log_msg "Connection OK"
fi
EOF

chmod +x /root/lte-watchdog.sh

# Add to cron (every 2 minutes)
echo "*/2 * * * * /root/lte-watchdog.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

---

## Advanced Configuration

### Dual Modem Setup (Load Balancing)

**Use case:** Two LTE modems for increased bandwidth

```bash
# First modem
uci set network.wwan1=interface
uci set network.wwan1.proto='qmi'
uci set network.wwan1.device='/dev/cdc-wdm0'
uci set network.wwan1.apn='internet'
uci set network.wwan1.metric='10'

# Second modem
uci set network.wwan2=interface
uci set network.wwan2.proto='qmi'
uci set network.wwan2.device='/dev/cdc-wdm1'
uci set network.wwan2.apn='internet'
uci set network.wwan2.metric='20'

uci commit network

# Install load balancing
opkg install mwan3 luci-app-mwan3

# Configure mwan3 for load balancing (via LuCI)
```

### Carrier Aggregation

**Check if modem supports CA:**

```bash
# Huawei
echo "AT^CA_INFO?" > /dev/ttyUSB0; cat /dev/ttyUSB0

# Shows active carriers
```

**CA is automatic when:**
- Modem supports it (Cat 6+)
- Operator network supports it
- Signal quality is good
- Multiple bands available at cell site

### Band Locking Script

```bash
cat > /root/lock-best-band.sh << 'EOF'
#!/bin/bash

DEVICE="/dev/ttyUSB0"
BANDS=(3 7 20)  # Test these bands
BEST_BAND=0
BEST_SPEED=0

for band in "${BANDS[@]}"; do
    echo "Testing Band $band..."

    # Lock to band (Huawei)
    BAND_HEX=$(printf '%x' $((2**($band-1))))
    echo "AT^SYSCFGEX=\"03\",$BAND_HEX,1,2,$BAND_HEX,," > $DEVICE
    sleep 10

    # Run speed test (requires speedtest-cli)
    SPEED=$(speedtest-cli --simple 2>/dev/null | grep Download | awk '{print $2}')

    echo "Band $band: $SPEED Mbps"

    if (( $(echo "$SPEED > $BEST_SPEED" | bc -l) )); then
        BEST_SPEED=$SPEED
        BEST_BAND=$band
    fi
done

echo "Best band: $BEST_BAND with $BEST_SPEED Mbps"

# Lock to best band
BAND_HEX=$(printf '%x' $((2**($BEST_BAND-1))))
echo "AT^SYSCFGEX=\"03\",$BAND_HEX,1,2,$BAND_HEX,," > $DEVICE
EOF

chmod +x /root/lock-best-band.sh
```

### SMS Gateway via LTE Modem

```bash
# Install SMS tools
opkg install sms-tool

# Send SMS
uqmi -d /dev/cdc-wdm0 --send-message "Hello from OpenWRT" --send-message-target "+1234567890"

# Read SMS
uqmi -d /dev/cdc-wdm0 --list-messages
uqmi -d /dev/cdc-wdm0 --get-message 1

# Or via AT commands
echo 'AT+CMGF=1' > /dev/ttyUSB0  # Text mode
echo 'AT+CMGS="+1234567890"' > /dev/ttyUSB0
echo 'Message text' > /dev/ttyUSB0
echo -e '\x1A' > /dev/ttyUSB0  # Ctrl+Z
```

---

## Conclusion

This guide provides detailed, real-world configuration examples for popular LTE modems on OpenWRT. Key takeaways:

### Protocol Selection
1. **QMI** - Best choice for most Qualcomm-based modems
2. **NCM** - Good for Huawei modems without QMI
3. **MBIM** - For newer modems and multi-carrier scenarios
4. **PPP** - Fallback for compatibility
5. **RNDIS** - Simplest for HiLink-style modems

### Modem-Specific Notes
- **Huawei E398 u-18**: Use ttyUSB1 for AT, ttyUSB4 for PPP
- **Huawei E3272/E3276**: Single ttyUSB0, prefer NCM/QMI
- **ZTE MF821D**: Use ttyUSB2, excellent QMI support
- **Alcatel L800**: RNDIS mode, watch for IP conflicts

### Performance Tips
- ✅ Use external MIMO antennas when possible
- ✅ Select QMI/NCM over PPP for full speed
- ✅ Lock to best performing band
- ✅ Monitor signal quality regularly
- ✅ Optimize MTU and TCP parameters
- ✅ Implement connection watchdog

### Troubleshooting Priority
1. Verify mode switch completed
2. Identify correct serial port (ttyUSB0 vs 1 vs 2)
3. Check signal strength and network registration
4. Test with simplest protocol (PPP) first
5. Upgrade to faster protocol (QMI/NCM) once working

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-modemylte*
