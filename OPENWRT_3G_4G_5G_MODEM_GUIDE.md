# OpenWRT 3G/4G/5G Cellular Modem Configuration Guide

## Table of Contents
1. [Overview](#overview)
2. [Cellular Technology Speeds](#cellular-technology-speeds)
3. [Hardware Requirements](#hardware-requirements)
4. [Software Components](#software-components)
5. [Installation](#installation)
6. [Configuration Methods](#configuration-methods)
7. [Connection Protocols](#connection-protocols)
8. [Modem-Specific Configuration](#modem-specific-configuration)
9. [Advanced Features](#advanced-features)
10. [Troubleshooting](#troubleshooting)
11. [Operator APN Settings](#operator-apn-settings)
12. [Legacy Versions](#legacy-versions)

---

## Overview

This comprehensive guide covers configuring OpenWRT firmware to function as a cellular router supporting various mobile technologies including GPRS, EDGE, UMTS, HSPA, LTE (4G), and 5G networks. OpenWRT can transform a compatible router with a USB cellular modem into a fully functional wireless WAN gateway.

### Use Cases
- **Primary Internet Connection**: Rural areas without wired broadband
- **Backup WAN**: Failover when primary connection fails
- **Mobile/Portable Networking**: RVs, boats, temporary installations
- **IoT/M2M Applications**: Remote monitoring and control
- **Load Balancing**: Distribute traffic across multiple connections

### Supported Technologies
- **GPRS** (2G) - General Packet Radio Service
- **EDGE** (2.5G) - Enhanced Data rates for GSM Evolution
- **UMTS/3G** - Universal Mobile Telecommunications System
- **HSPA/HSPA+** (3.5G) - High-Speed Packet Access
- **LTE/4G** - Long-Term Evolution
- **5G NR** - Fifth Generation New Radio

---

## Cellular Technology Speeds

### Theoretical Maximum Speeds

| Technology | Generation | Download Speed | Upload Speed | Typical Real-World |
|------------|-----------|----------------|--------------|-------------------|
| GPRS | 2G | 56 Kbps | 28 Kbps | 30-40 Kbps |
| EDGE | 2.5G | 236 Kbps | 118 Kbps | 100-150 Kbps |
| UMTS | 3G | 384 Kbps | 128 Kbps | 200-300 Kbps |
| HSPA | 3.5G | 14.4 Mbps | 5.76 Mbps | 5-10 Mbps |
| HSPA+ | 3.75G | 42 Mbps | 11 Mbps | 10-20 Mbps |
| DC-HSPA+ | 3.9G | 84 Mbps | 22 Mbps | 20-40 Mbps |
| LTE Cat 3 | 4G | 100 Mbps | 50 Mbps | 30-70 Mbps |
| LTE Cat 4 | 4G | 150 Mbps | 50 Mbps | 40-100 Mbps |
| LTE Cat 6 | 4G | 300 Mbps | 50 Mbps | 80-200 Mbps |
| LTE-A Cat 9 | 4G+ | 450 Mbps | 50 Mbps | 150-300 Mbps |
| LTE-A Cat 16 | 4G+ | 1 Gbps | 150 Mbps | 300-600 Mbps |
| 5G NR | 5G | 10+ Gbps | 5+ Gbps | 500 Mbps-2 Gbps |

### Factors Affecting Real-World Speed
- **Signal Strength**: Distance from cell tower, obstacles
- **Network Congestion**: Number of concurrent users
- **Frequency Band**: Low bands (better coverage) vs. high bands (better speed)
- **Carrier Aggregation**: Combining multiple frequency bands
- **Weather Conditions**: Rain, fog can affect signal
- **Data Plan Throttling**: Operator-imposed speed limits

---

## Hardware Requirements

### OpenWRT Router
**Minimum Requirements:**
- USB 2.0 port (USB 3.0 recommended for 4G/5G)
- 8MB+ Flash storage (16MB+ recommended)
- 64MB+ RAM (128MB+ recommended for 4G/5G)
- CPU: 400MHz+ (600MHz+ for 4G/5G)

**Recommended Routers:**
- GL.iNet series (GL-AR300M, GL-MT300N-V2, GL-X750, GL-XE300)
- TP-Link TL-MR3020, TL-MR3220, TL-MR3420
- Netgear routers with USB ports
- Teltonika RUT series (industrial)
- MikroTik routers with USB

### USB Cellular Modems

**Popular Models:**

**Huawei:**
- E3372 (LTE Cat 4, HiLink mode)
- E3272 (LTE Cat 4)
- E3276 (LTE Cat 4)
- E398 (LTE, QMI mode)
- E173 (3G)

**ZTE:**
- MF823 (LTE)
- MF831 (LTE)
- MF190 (3G)

**Sierra Wireless:**
- MC7710 (LTE)
- MC7455 (LTE-A)
- EM7565 (LTE-A Pro)

**Quectel:**
- EC25 (LTE Cat 4)
- EC20 (LTE Cat 4)
- EP06 (LTE Cat 6)
- RM500Q (5G)
- RG500Q (5G)

**Telit:**
- LE910 series (LTE)
- FN980 (5G)

### Power Considerations

**Important**: Many 4G/5G modems draw significant power (500-1000mA), which may exceed USB port capabilities.

**Solutions:**
- Use powered USB hub
- Router with high-power USB ports
- External power injection cables
- PCIe/mPCIe adapters for internal installation

---

## Software Components

OpenWRT modem support requires four essential software layers:

### 1. USB Drivers

**Basic USB Support:**
```bash
opkg update
opkg install kmod-usb-core
opkg install kmod-usb2  # For USB 2.0
opkg install kmod-usb3  # For USB 3.0
```

**USB Serial Support:**
```bash
opkg install kmod-usb-serial
opkg install kmod-usb-serial-option
opkg install kmod-usb-serial-wwan
```

### 2. Mode-Switching Software

Many USB modems initially appear as CD-ROM drives (for Windows driver installation). Mode-switching converts them to modem mode.

**Modern OpenWRT (19.07+):**
```bash
opkg install usbutils
opkg install usb-modeswitch
```

**Check device before/after mode switch:**
```bash
lsusb
```

### 3. Protocol-Specific Drivers

Different modems use different communication protocols:

**QMI (Qualcomm MSM Interface):**
```bash
opkg install kmod-usb-net-qmi-wwan
opkg install uqmi
```

**MBIM (Mobile Broadband Interface Model):**
```bash
opkg install kmod-usb-net-cdc-mbim
opkg install umbim
```

**NCM (Network Control Model):**
```bash
opkg install kmod-usb-net-cdc-ncm
```

**RNDIS:**
```bash
opkg install kmod-usb-net-rndis
```

**PPP (for serial/RAS mode):**
```bash
opkg install ppp
opkg install kmod-ppp
opkg install kmod-usb-serial-option
opkg install comgt
```

**DirectIP (Sierra Wireless):**
```bash
opkg install kmod-usb-serial-sierrawireless
```

**HSO (Option modems):**
```bash
opkg install kmod-usb-net-hso
```

### 4. Connection Management

**Modern unified interface:**
```bash
opkg install wwan
```

**Or protocol-specific:**
```bash
opkg install comgt-ncm  # For NCM
opkg install luci-proto-qmi  # QMI web interface
opkg install luci-proto-mbim  # MBIM web interface
opkg install luci-proto-ncm  # NCM web interface
```

---

## Installation

### Complete Installation for Modern OpenWRT (21.02+)

```bash
# Update package lists
opkg update

# Install USB support
opkg install kmod-usb-core kmod-usb2 kmod-usb3
opkg install usbutils usb-modeswitch

# Install all modem protocols (choose based on your modem)
opkg install kmod-usb-net-qmi-wwan uqmi
opkg install kmod-usb-net-cdc-mbim umbim
opkg install kmod-usb-net-cdc-ncm
opkg install kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan

# Install connection management
opkg install wwan

# Install LuCI web interface support
opkg install luci-proto-qmi
opkg install luci-proto-mbim
opkg install luci-proto-ncm
opkg install luci-proto-3g

# Reboot
reboot
```

### Verify Installation

```bash
# Check USB devices
lsusb

# Expected output example:
# Bus 001 Device 003: ID 12d1:1506 Huawei Technologies Co., Ltd. Modem/Networkcard

# Check kernel modules
lsmod | grep qmi
lsmod | grep cdc

# Check network interfaces
ifconfig -a
# Should show wwan0 or similar interface
```

---

## Configuration Methods

### Method 1: LuCI Web Interface (Recommended for Beginners)

1. **Access LuCI**: Navigate to `http://192.168.1.1` (or your router IP)
2. **Login**: Default credentials (usually root/admin)
3. **Navigate**: Network → Interfaces
4. **Add Interface**:
   - Click "Add new interface"
   - Name: `wwan` or `cellular`
   - Protocol: Select appropriate protocol (QMI, MBIM, NCM, 3G/PPP)
   - Device: Select your modem device

5. **Configure Interface**:
   - **APN**: Enter operator's APN (e.g., `internet`)
   - **PIN**: Enter SIM PIN if required
   - **Authentication**: Usually `none` or `PAP`
   - **Username/Password**: If required by operator

6. **Firewall Settings**:
   - Assign to WAN zone
   - Enable masquerading
   - Enable MSS clamping

7. **Save & Apply**

### Method 2: UCI Command Line (Advanced)

**For QMI Modems:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci set network.wwan.auth='none'
uci set network.wwan.pdptype='ipv4'
uci commit network

# Add to firewall WAN zone
uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

# Restart network
/etc/init.d/network restart
```

**For MBIM Modems:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='mbim'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci set network.wwan.auth='none'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

**For NCM Modems:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='ncm'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci set network.wwan.auth='none'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

**For 3G/PPP (Serial) Modems:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci set network.wwan.service='umts'
uci commit network

uci add_list firewall.@zone[1].network='wwan'
uci commit firewall

/etc/init.d/network restart
```

### Method 3: Direct Configuration File Editing

Edit `/etc/config/network`:

```bash
config interface 'wwan'
    option proto 'qmi'
    option device '/dev/cdc-wdm0'
    option apn 'internet'
    option pincode '1234'
    option auth 'none'
    option pdptype 'ipv4'
    option delay '10'
```

Edit `/etc/config/firewall` - add wwan to WAN zone:

```bash
config zone
    option name 'wan'
    option input 'REJECT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option masq '1'
    option mtu_fix '1'
    list network 'wan'
    list network 'wwan'
```

---

## Connection Protocols

### QMI (Qualcomm MSM Interface)

**Best for**: Qualcomm-based modems (most Huawei, ZTE, Quectel)

**Advantages:**
- Native IP stack (fast)
- Good driver support
- Reliable connection management
- Low CPU usage

**Configuration:**
```bash
config interface 'wwan'
    option proto 'qmi'
    option device '/dev/cdc-wdm0'
    option apn 'internet'
    option pdptype 'ipv4v6'  # or 'ipv4' or 'ipv6'
    option autoconnect '1'
```

**Manual QMI Commands:**
```bash
# Check device
uqmi -d /dev/cdc-wdm0 --get-device-operating-mode

# Get network registration status
uqmi -d /dev/cdc-wdm0 --get-serving-system

# Get signal strength
uqmi -d /dev/cdc-wdm0 --get-signal-info

# Start network
uqmi -d /dev/cdc-wdm0 --start-network internet --autoconnect

# Get current settings
uqmi -d /dev/cdc-wdm0 --get-current-settings
```

### MBIM (Mobile Broadband Interface Model)

**Best for**: Modern LTE/5G modems, Microsoft-certified devices

**Advantages:**
- Industry standard
- Good Windows compatibility
- IPv6 support
- Multi-carrier support

**Configuration:**
```bash
config interface 'wwan'
    option proto 'mbim'
    option device '/dev/cdc-wdm0'
    option apn 'internet'
    option auth 'none'
    option pincode '1234'
    option pdptype 'ipv4v6'
```

**Manual MBIM Commands:**
```bash
# Check device
umbim -n -d /dev/cdc-wdm0 status

# Connect
umbim -n -d /dev/cdc-wdm0 connect internet
```

### NCM (Network Control Model)

**Best for**: Newer LTE modems with Ethernet-like interface

**Advantages:**
- Ethernet-like operation
- Simple configuration
- Good performance
- Low overhead

**Configuration:**
```bash
config interface 'wwan'
    option proto 'ncm'
    option device '/dev/cdc-wdm0'
    option apn 'internet'
    option pdptype 'IP'
    option delay '15'
```

### PPP/3G (Serial/RAS Mode)

**Best for**: Older 3G modems, fallback mode

**Advantages:**
- Universal compatibility
- Works with almost any modem
- Well-tested

**Disadvantages:**
- Speed limited to ~20-30 Mbps
- Higher CPU usage
- Higher latency

**Configuration:**
```bash
config interface 'wwan'
    option proto '3g'
    option device '/dev/ttyUSB0'
    option apn 'internet'
    option service 'umts'  # or 'cdma', 'evdo'
    option pincode '1234'
    option username ''
    option password ''
```

**Find correct TTY device:**
```bash
ls -l /dev/ttyUSB*
# Usually ttyUSB0 for AT commands, ttyUSB1 or ttyUSB2 for data
```

### HiLink Mode (Huawei)

**Best for**: Huawei modems with built-in router functionality

**Special**: Modem creates its own network (usually 192.168.8.x)

**Configuration:**
```bash
config interface 'wwan'
    option proto 'dhcp'
    option ifname 'eth1'  # or usb0
```

**Access Modem Web Interface:**
- Usually at `http://192.168.8.1`
- Configure APN, PIN in modem interface
- OpenWRT router acts as DHCP client

### DirectIP (Sierra Wireless)

**Best for**: Sierra Wireless modems

**Configuration:**
```bash
config interface 'wwan'
    option proto 'directip'
    option device '/dev/ttyUSB0'
    option apn 'internet'
```

### RNDIS (Microsoft)

**Best for**: Some Windows-compatible USB modems

**Configuration:**
```bash
config interface 'wwan'
    option proto 'dhcp'
    option ifname 'usb0'
```

---

## Modem-Specific Configuration

### Huawei E3372 (HiLink Mode)

**Default Mode**: HiLink (appears as network card)

```bash
# Configuration
uci set network.wwan=interface
uci set network.wwan.proto='dhcp'
uci set network.wwan.ifname='eth1'
uci commit network

# Add to WAN zone
uci add_list firewall.@zone[1].network='wwan'
uci commit firewall
```

**Switch to Stick Mode (QMI):**
```bash
# Install packages
opkg install kmod-usb-net-cdc-ether usb-modeswitch

# Use AT commands via modem web interface or:
# Download HiLink tool and switch mode
# After switch, use QMI configuration
```

### Huawei E3272 (NCM Mode)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='ncm'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='IP'
uci set network.wwan.delay='15'
uci commit network
```

### ZTE MF823 (QMI Mode)

```bash
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pincode='1234'
uci commit network
```

### Quectel EC25 (QMI Mode)

```bash
# Install required packages
opkg install kmod-usb-net-qmi-wwan uqmi
opkg install kmod-usb-serial-option

# Configuration
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci set network.wwan.pdptype='ipv4v6'
uci commit network

# For GPS support
opkg install gpsd kmod-usb-serial
```

### Sierra Wireless MC7710

```bash
# QMI mode configuration
uci set network.wwan=interface
uci set network.wwan.proto='qmi'
uci set network.wwan.device='/dev/cdc-wdm0'
uci set network.wwan.apn='internet'
uci commit network
```

---

## Advanced Features

### SIM PIN Management

**Set PIN in configuration:**
```bash
uci set network.wwan.pincode='1234'
uci commit network
```

**Manual PIN unlock (QMI):**
```bash
# Check PIN status
uqmi -d /dev/cdc-wdm0 --uim-get-sim-state

# Unlock PIN
uqmi -d /dev/cdc-wdm0 --verify-pin1 1234

# Disable PIN
uqmi -d /dev/cdc-wdm0 --disable-pin1 1234
```

**Manual PIN unlock (MBIM):**
```bash
umbim -n -d /dev/cdc-wdm0 unlock 1234
```

**⚠️ WARNING**: After 3 incorrect PIN attempts, SIM will be locked and require PUK code!

### Signal Strength Monitoring

**Create monitoring script** `/root/signal-monitor.sh`:

```bash
#!/bin/bash

# For QMI modems
if [ -c "/dev/cdc-wdm0" ]; then
    SIGNAL=$(uqmi -d /dev/cdc-wdm0 --get-signal-info)
    echo "QMI Signal: $SIGNAL"

    # Parse RSSI and other values
    RSSI=$(echo "$SIGNAL" | jsonfilter -e '@.rssi')
    RSRP=$(echo "$SIGNAL" | jsonfilter -e '@.rsrp')
    RSRQ=$(echo "$SIGNAL" | jsonfilter -e '@.rsrq')

    echo "RSSI: $RSSI dBm"
    echo "RSRP: $RSRP dBm"
    echo "RSRQ: $RSRQ dB"
fi

# For 3G modems using AT commands
if [ -c "/dev/ttyUSB0" ]; then
    gcom -d /dev/ttyUSB0 sig
fi
```

**Add to cron for periodic monitoring:**
```bash
# Edit crontab
crontab -e

# Add line (check every 5 minutes)
*/5 * * * * /root/signal-monitor.sh >> /var/log/signal.log
```

### Connection Watchdog

Create automatic reconnection script `/root/wwan-watchdog.sh`:

```bash
#!/bin/bash

PING_HOST="8.8.8.8"
INTERFACE="wwan"
LOG="/var/log/wwan-watchdog.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

# Check if interface is up
if ! ifconfig $INTERFACE | grep -q "inet addr"; then
    log_msg "Interface $INTERFACE is down, restarting..."
    ifdown $INTERFACE
    sleep 5
    ifup $INTERFACE
    sleep 10
fi

# Ping test
if ! ping -c 3 -W 5 -I $INTERFACE $PING_HOST > /dev/null 2>&1; then
    log_msg "Ping test failed, restarting interface..."
    ifdown $INTERFACE
    sleep 5
    ifup $INTERFACE
    sleep 10

    # If still failing, reboot modem (USB power cycle)
    if ! ping -c 3 -W 5 -I $INTERFACE $PING_HOST > /dev/null 2>&1; then
        log_msg "Still failing, power cycling modem..."
        # USB power cycle commands here if supported
    fi
fi
```

Make executable and add to cron:
```bash
chmod +x /root/wwan-watchdog.sh

# Add to crontab (check every 2 minutes)
echo "*/2 * * * * /root/wwan-watchdog.sh" >> /etc/crontabs/root
/etc/init.d/cron restart
```

### SMS Sending and Reading

**For QMI modems:**

Install SMS support:
```bash
opkg install sms-tool
```

**Send SMS:**
```bash
# Send via uqmi
uqmi -d /dev/cdc-wdm0 --send-message "Hello from OpenWRT" --send-message-target "+1234567890"
```

**Read SMS:**
```bash
# List messages
uqmi -d /dev/cdc-wdm0 --list-messages

# Read specific message
uqmi -d /dev/cdc-wdm0 --get-message 1
```

**For 3G modems (AT commands):**

Create script `/root/send-sms.sh`:
```bash
#!/bin/bash

DEVICE="/dev/ttyUSB0"
NUMBER="$1"
MESSAGE="$2"

if [ -z "$NUMBER" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: $0 <phone_number> <message>"
    exit 1
fi

# Send AT commands
(
echo "AT+CMGF=1"
sleep 1
echo "AT+CMGS=\"$NUMBER\""
sleep 1
echo "$MESSAGE"
sleep 1
echo -e "\x1A"
sleep 2
) > $DEVICE < $DEVICE
```

### USSD Codes

**For QMI modems:**
```bash
# Check balance (example for some operators)
uqmi -d /dev/cdc-wdm0 --send-ussd "*100#"

# Check data usage
uqmi -d /dev/cdc-wdm0 --send-ussd "*123#"
```

**For 3G modems:**
```bash
# Using AT commands
echo 'AT+CUSD=1,"*100#",15' > /dev/ttyUSB0
cat /dev/ttyUSB0
```

### Network Mode Selection

Force specific network mode (3G, 4G only):

**For QMI modems:**
```bash
# Auto (default)
uqmi -d /dev/cdc-wdm0 --set-network-modes all

# LTE only
uqmi -d /dev/cdc-wdm0 --set-network-modes lte

# 3G/UMTS only
uqmi -d /dev/cdc-wdm0 --set-network-modes umts

# Get current mode
uqmi -d /dev/cdc-wdm0 --get-network-modes
```

**Using AT commands:**
```bash
# LTE only
echo 'AT+QCFG="nwscanmode",3,1' > /dev/ttyUSB2

# Auto
echo 'AT+QCFG="nwscanmode",0,1' > /dev/ttyUSB2
```

### Band Selection

Lock to specific LTE bands:

```bash
# For Huawei modems (AT commands)
# Lock to Band 3 (1800 MHz)
echo 'AT^SYSCFGEX="03",3FFFFFFF,1,2,4,,' > /dev/ttyUSB0

# For Quectel modems
# Lock to Band 7
echo 'AT+QCFG="band",0,40,1' > /dev/ttyUSB2
```

### Data Usage Monitoring

Create data counter script `/root/data-usage.sh`:

```bash
#!/bin/bash

INTERFACE="wwan0"
COUNTER_FILE="/etc/wwan-data-counter.txt"
LOG_FILE="/var/log/data-usage.log"

# Get current RX/TX bytes
RX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo 0)

# Load previous counter
if [ -f "$COUNTER_FILE" ]; then
    source "$COUNTER_FILE"
else
    TOTAL_RX=0
    TOTAL_TX=0
fi

# Update totals
TOTAL_RX=$((TOTAL_RX + RX_BYTES))
TOTAL_TX=$((TOTAL_TX + TX_BYTES))

# Save counter
echo "TOTAL_RX=$TOTAL_RX" > "$COUNTER_FILE"
echo "TOTAL_TX=$TOTAL_TX" >> "$COUNTER_FILE"

# Convert to GB
RX_GB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_RX/1024/1024/1024}")
TX_GB=$(awk "BEGIN {printf \"%.2f\", $TOTAL_TX/1024/1024/1024}")
TOTAL_GB=$(awk "BEGIN {printf \"%.2f\", ($TOTAL_RX+$TOTAL_TX)/1024/1024/1024}")

# Log
echo "[$(date '+%Y-%m-%d %H:%M:%S')] RX: ${RX_GB}GB, TX: ${TX_GB}GB, Total: ${TOTAL_GB}GB" >> "$LOG_FILE"

# Display
echo "Downloaded: ${RX_GB} GB"
echo "Uploaded: ${TX_GB} GB"
echo "Total: ${TOTAL_GB} GB"
```

---

## Troubleshooting

### Device Not Recognized

**Check USB detection:**
```bash
lsusb
dmesg | tail -30
```

**If device shows as CD-ROM:**
```bash
# Install mode-switch
opkg install usb-modeswitch

# Check vendor:product ID
lsusb
# Example: Bus 001 Device 003: ID 12d1:1f01

# Force mode switch
usb_modeswitch -v 12d1 -p 1f01 -M '55534243123456780000000000000a11062000000000000100000000000000'

# Or edit /etc/usb-mode.json
```

### No /dev/cdc-wdm0 Device

**Check kernel modules:**
```bash
lsmod | grep qmi
lsmod | grep cdc

# If not loaded
insmod kmod-usb-net-qmi-wwan
insmod kmod-usb-net-cdc-mbim
```

**Check dmesg for errors:**
```bash
dmesg | grep -i "cdc\|qmi\|mbim\|wwan"
```

### Connection Fails Immediately

**Check logs:**
```bash
logread | grep -i "wwan\|qmi\|mbim"
```

**Common issues:**

1. **Wrong APN:**
   - Verify operator APN settings
   - Try alternative APNs

2. **SIM PIN locked:**
   - Check PIN status
   - Unlock SIM

3. **Wrong protocol:**
   - Try different proto (qmi → mbim → ncm → 3g)

4. **Network not available:**
   - Check signal strength
   - Verify SIM is activated

**Test manually:**
```bash
# QMI
uqmi -d /dev/cdc-wdm0 --get-serving-system
uqmi -d /dev/cdc-wdm0 --start-network internet --autoconnect

# MBIM
umbim -n -d /dev/cdc-wdm0 status
umbim -n -d /dev/cdc-wdm0 connect internet
```

### Slow Speeds

**Check signal quality:**
```bash
uqmi -d /dev/cdc-wdm0 --get-signal-info
```

**Good signal levels:**
- RSSI: > -70 dBm (better: > -60 dBm)
- RSRP: > -90 dBm (better: > -80 dBm)
- RSRQ: > -10 dB (better: > -8 dB)
- SINR: > 10 dB (better: > 15 dB)

**Optimization tips:**
1. **Improve antenna/position**: External antenna, better location
2. **Force LTE mode**: Disable 3G fallback
3. **Select best band**: Lock to strongest band
4. **Check data limits**: Operator throttling
5. **MTU optimization**: Adjust MTU size
6. **QoS settings**: Prioritize important traffic

**MTU adjustment:**
```bash
uci set network.wwan.mtu='1420'
uci commit network
ifup wwan
```

### Random Disconnections

**Enable keepalive:**
```bash
uci set network.wwan.delay='10'
uci set network.wwan.pdptype='ipv4'  # Try IPv4 only
uci commit network
```

**Implement watchdog** (see Advanced Features section)

**Check power supply:**
- Insufficient power can cause drops
- Use powered USB hub
- Check power consumption

**Temperature issues:**
- Modems can overheat
- Ensure adequate ventilation
- Add heatsink if needed

### PPP Connection Issues

**Check correct TTY device:**
```bash
ls -l /dev/ttyUSB*

# Try different devices
uci set network.wwan.device='/dev/ttyUSB1'
uci commit network
ifup wwan
```

**Enable debugging:**
```bash
uci set network.wwan.debug='1'
uci commit network
logread -f | grep ppp
```

**Common PPP errors:**

```
LCP timeout - Device not responding
→ Wrong TTY device or hardware issue

Authentication failed
→ Wrong username/password

No dial tone
→ No signal or SIM issue
```

---

## Operator APN Settings

### International Carriers

| Country | Operator | APN | Username | Password | Auth |
|---------|----------|-----|----------|----------|------|
| USA | AT&T | broadband | (none) | (none) | none |
| USA | T-Mobile | fast.t-mobile.com | (none) | (none) | none |
| USA | Verizon | vzwinternet | (none) | (none) | none |
| UK | EE | everywhere | eesecure | secure | chap |
| UK | Vodafone | internet | web | web | pap |
| UK | O2 | mobile.o2.co.uk | o2web | password | pap |
| Germany | Telekom | internet.t-mobile | t-mobile | tm | pap |
| Germany | Vodafone | web.vodafone.de | (none) | (none) | none |
| France | Orange | orange.fr | orange | orange | pap |
| France | SFR | sl2sfr | (none) | (none) | none |
| Spain | Movistar | movistar.es | movistar | movistar | pap |
| Italy | TIM | ibox.tim.it | (none) | (none) | none |
| Italy | Vodafone | mobile.vodafone.it | (none) | (none) | none |
| Poland | Play | internet | (none) | (none) | none |
| Poland | Orange | internet | internet | internet | pap |
| Poland | Plus | internet | (none) | (none) | none |
| Russia | MTS | internet.mts.ru | mts | mts | pap |
| Russia | Beeline | internet.beeline.ru | beeline | beeline | pap |
| Russia | MegaFon | internet | (none) | (none) | none |
| Turkey | Turkcell | internet | (none) | (none) | none |
| Turkey | Vodafone | internet | (none) | (none) | none |
| China | China Mobile | cmnet | (none) | (none) | none |
| China | China Unicom | 3gnet | (none) | (none) | none |
| India | Airtel | airtelgprs.com | (none) | (none) | none |
| India | Jio | jionet | (none) | (none) | none |
| Australia | Telstra | telstra.internet | (none) | (none) | none |
| Australia | Optus | internet | (none) | (none) | none |

### IoT/M2M APNs

Many operators offer special APNs for IoT devices:

| Operator | IoT APN | Notes |
|----------|---------|-------|
| AT&T | m2m.com.attz | M2M devices |
| T-Mobile | iot.t-mobile.nl | IoT specific |
| Vodafone | iot.vodafone.com | Global IoT |
| Deutsche Telekom | iot.telekom.com | IoT platform |

---

## Legacy Versions

### OpenWRT 15.05 (Chaos Calmer)

**Install packages:**
```bash
opkg update
opkg install kmod-usb-serial kmod-usb-serial-option
opkg install usb-modeswitch usb-modeswitch-data
opkg install comgt kmod-usb-net-cdc-ether

# For QMI
opkg install kmod-usb-net-qmi-wwan uqmi
```

**Configuration:**
```bash
uci set network.wwan=interface
uci set network.wwan.proto='3g'
uci set network.wwan.device='/dev/ttyUSB0'
uci set network.wwan.service='umts'
uci set network.wwan.apn='internet'
uci commit network
ifup wwan
```

### OpenWRT 14.07 (Barrier Breaker)

**Install packages:**
```bash
opkg update
opkg install kmod-usb-serial kmod-usb-serial-option kmod-usb-serial-wwan
opkg install comgt usb-modeswitch

# PPP support
opkg install ppp kmod-ppp
```

**Configuration:**
```bash
# Edit /etc/config/network
config interface 'wwan'
    option proto '3g'
    option device '/dev/ttyUSB0'
    option service 'umts'
    option apn 'internet'
    option defaultroute '1'
    option peerdns '1'
```

### OpenWRT 12.09 (Attitude Adjustment)

**Very limited support. Upgrade recommended.**

```bash
opkg install kmod-usb-serial
opkg install comgt chat

# Manual PPP configuration required
# /etc/ppp/peers/wwan
```

---

## Security Considerations

### Firewall Configuration

**Ensure modem interface is in WAN zone:**
```bash
uci show firewall | grep wwan

# If not present, add:
uci add_list firewall.@zone[1].network='wwan'
uci commit firewall
/etc/init.d/firewall restart
```

### Inbound Traffic Blocking

**⚠️ Important**: Most mobile operators use Carrier-Grade NAT (CGNAT), blocking inbound connections. You cannot run public servers on cellular connections without:

1. **Public static IP** (paid service from operator)
2. **VPN tunnel** (reverse tunnel for inbound access)
3. **Dynamic DNS + port forwarding** (if operator supports)

### VPN for Security

Recommended to use VPN when on cellular:

```bash
# Install OpenVPN
opkg install openvpn-openssl luci-app-openvpn

# Or WireGuard
opkg install wireguard luci-proto-wireguard
```

### Data Plan Monitoring

Set up alerts for data usage:

```bash
# Check current usage
cat /sys/class/net/wwan0/statistics/rx_bytes
cat /sys/class/net/wwan0/statistics/tx_bytes

# Create alert script
cat > /root/data-alert.sh << 'EOF'
#!/bin/bash
LIMIT_GB=10
USAGE=$(awk '{print int($1/1024/1024/1024)}' /sys/class/net/wwan0/statistics/rx_bytes)
if [ $USAGE -gt $LIMIT_GB ]; then
    echo "Data limit exceeded: ${USAGE}GB" | mail -s "Data Alert" admin@example.com
fi
EOF

# Add to cron
echo "0 */6 * * * /root/data-alert.sh" >> /etc/crontabs/root
```

---

## Performance Tuning

### TCP Optimization

```bash
# Edit /etc/sysctl.conf or create /etc/sysctl.d/99-cellular.conf
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=134217728
net.core.wmem_max=134217728
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
net.ipv4.tcp_sack=1

# Apply
sysctl -p
```

### QoS Configuration

Prioritize important traffic:

```bash
# Install SQM
opkg install sqm-scripts luci-app-sqm

# Configure via LuCI: Network → SQM QoS
# Or via UCI:
uci set sqm.wwan=queue
uci set sqm.wwan.enabled='1'
uci set sqm.wwan.interface='wwan0'
uci set sqm.wwan.download='50000'  # Your download speed in kbit/s
uci set sqm.wwan.upload='20000'    # Your upload speed in kbit/s
uci set sqm.wwan.script='piece_of_cake.qos'
uci commit sqm
/etc/init.d/sqm restart
```

### DNS Optimization

Use fast DNS servers:

```bash
# Edit /etc/config/dhcp
uci delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='1.1.1.1'
uci add_list dhcp.@dnsmasq[0].server='1.0.0.1'
uci add_list dhcp.@dnsmasq[0].server='8.8.8.8'
uci commit dhcp
/etc/init.d/dnsmasq restart
```

---

## Useful Scripts

### Complete Status Script

Create `/root/modem-status.sh`:

```bash
#!/bin/bash

echo "=== Modem Status ==="
echo ""

# Check device
if [ -c "/dev/cdc-wdm0" ]; then
    echo "Device: /dev/cdc-wdm0 (QMI/MBIM)"

    # Try QMI first
    if command -v uqmi >/dev/null 2>&1; then
        echo ""
        echo "--- QMI Information ---"

        # Device info
        echo "Device Mode:"
        uqmi -d /dev/cdc-wdm0 --get-device-operating-mode

        # Network registration
        echo ""
        echo "Network Registration:"
        uqmi -d /dev/cdc-wdm0 --get-serving-system

        # Signal info
        echo ""
        echo "Signal Information:"
        uqmi -d /dev/cdc-wdm0 --get-signal-info

        # Current settings
        echo ""
        echo "Current Settings:"
        uqmi -d /dev/cdc-wdm0 --get-current-settings

        # Data status
        echo ""
        echo "Data Connection Status:"
        uqmi -d /dev/cdc-wdm0 --get-data-status
    fi

    # Try MBIM
    if command -v umbim >/dev/null 2>&1; then
        echo ""
        echo "--- MBIM Information ---"
        umbim -n -d /dev/cdc-wdm0 status
    fi
else
    echo "No QMI/MBIM device found"
fi

# Check PPP/3G devices
if [ -c "/dev/ttyUSB0" ]; then
    echo ""
    echo "=== Serial Device Found ==="
    echo "Device: /dev/ttyUSB0"

    # Try AT commands
    if command -v gcom >/dev/null 2>&1; then
        echo ""
        echo "Signal Strength:"
        gcom -d /dev/ttyUSB0 sig
    fi
fi

# Network interface status
echo ""
echo "=== Network Interface ==="
ifconfig wwan0 2>/dev/null || ifconfig wwan 2>/dev/null || echo "No wwan interface"

# Data usage
echo ""
echo "=== Data Usage ==="
if [ -d "/sys/class/net/wwan0" ]; then
    RX=$(cat /sys/class/net/wwan0/statistics/rx_bytes)
    TX=$(cat /sys/class/net/wwan0/statistics/tx_bytes)
    echo "Downloaded: $(awk "BEGIN {printf \"%.2f MB\", $RX/1024/1024}")"
    echo "Uploaded: $(awk "BEGIN {printf \"%.2f MB\", $TX/1024/1024}")"
fi

# Connection test
echo ""
echo "=== Connectivity Test ==="
if ping -c 3 -W 5 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ Internet connectivity OK"
else
    echo "✗ No internet connectivity"
fi

echo ""
echo "=== End of Status ==="
```

Make executable:
```bash
chmod +x /root/modem-status.sh
```

---

## Conclusion

This guide provides comprehensive coverage of configuring OpenWRT as a cellular router. Key takeaways:

### Best Practices
- ✅ Use QMI or MBIM protocols for best performance
- ✅ Implement connection watchdog for reliability
- ✅ Monitor data usage to avoid overage charges
- ✅ Use external antenna for better signal
- ✅ Ensure adequate power supply
- ✅ Keep OpenWRT updated
- ✅ Configure firewall properly

### Common Pitfalls to Avoid
- ❌ Using PPP when faster protocols available
- ❌ Forgetting to add interface to firewall WAN zone
- ❌ Not monitoring data usage
- ❌ Inadequate power supply to USB modem
- ❌ Multiple incorrect PIN attempts
- ❌ Not implementing reconnection watchdog

### Performance Expectations
- **3G/HSPA**: 5-20 Mbps typical
- **LTE Cat 4**: 30-100 Mbps typical
- **LTE-A**: 100-300 Mbps typical
- **5G**: 500+ Mbps typical

### Further Resources
- OpenWRT Wiki: https://openwrt.org/docs/guide-user/network/wan/wwan/3gdongle
- SANE APNs Database: https://wiki.apnchanger.org/
- OpenWRT Forum: https://forum.openwrt.org/
- ModemManager: https://www.freedesktop.org/wiki/Software/ModemManager/

---

*Document Version: 1.0*
*Last Updated: 2025*
*Based on: https://eko.one.pl/?p=openwrt-3g*
