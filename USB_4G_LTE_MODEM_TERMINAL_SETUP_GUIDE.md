# USB 4G LTE Modem Terminal Setup Guide

## Table of Contents
1. [Overview](#overview)
2. [Hardware Compatibility](#hardware-compatibility)
3. [Software Requirements](#software-requirements)
4. [Prerequisites](#prerequisites)
5. [Installation](#installation)
6. [Understanding QMI Protocol](#understanding-qmi-protocol)
7. [Step-by-Step Configuration](#step-by-step-configuration)
8. [Network Connection Procedure](#network-connection-procedure)
9. [Testing and Verification](#testing-and-verification)
10. [Advanced Configuration](#advanced-configuration)
11. [Automation and Scripting](#automation-and-scripting)
12. [Troubleshooting](#troubleshooting)
13. [Using with Different Carriers](#using-with-different-carriers)
14. [Persistent Configuration](#persistent-configuration)
15. [Best Practices](#best-practices)
16. [References](#references)

---

## Overview

This guide provides detailed instructions for setting up and using USB 4G LTE modems on GNU/Linux systems using QMI (Qualcomm MSM Interface) protocol and command-line tools. Unlike graphical network managers, this method offers:

- **Direct control** over modem configuration
- **Minimal dependencies** (no GUI required)
- **Scriptable** for automation
- **Works on servers** and headless systems
- **Applicable to various modems** including ThinkPenguin TPE-USB4G2US and Quectel models

**Key Technologies:**
- QMI (Qualcomm MSM Interface) protocol
- qmicli command-line tool
- udhcpc DHCP client
- Linux kernel qmi_wwan driver

---

## Hardware Compatibility

### Supported Devices

**ThinkPenguin TPE-USB4G2US:**
- Based on this guide
- Fully supported on GNU/Linux
- Uses QMI protocol

**Other Compatible Modems:**
- Quectel EC25, EM12, RM500Q series
- Sierra Wireless MC7xxx series
- Huawei ME909s series
- Most QMI-capable USB LTE modems

### Identify Your Modem

**Check USB device:**
```bash
lsusb
```

**Expected output (example):**
```
Bus 001 Device 005: ID 2c7c:0125 Quectel Wireless Solutions Co., Ltd. EC25 LTE modem
```

**Check kernel detection:**
```bash
dmesg | tail -50
```

**Look for:**
```
usb 1-1: new high-speed USB device number 5 using xhci_hcd
option 1-1:1.0: GSM modem (1-port) converter detected
qmi_wwan 1-1:1.4: cdc-wdm0: USB WDM device
```

---

## Software Requirements

### Operating System Compatibility

**Tested distributions:**
- **Debian 12** (Bookworm)
- **Ubuntu 22.04** LTS
- **Trisquel 11**
- Other recent GNU/Linux distributions

**Kernel requirements:**
- Linux kernel 3.x or newer
- qmi_wwan driver support (usually built-in)

### Required Packages

**Minimum requirements:**
- `libqmi-utils` - QMI command-line tools (qmicli)
- `udhcpc` - Lightweight DHCP client

**Optional but recommended:**
- `ppp` - For PPP connections (alternative method)
- `net-tools` - Traditional networking tools
- `iproute2` - Modern networking tools (ip command)
- `dnsutils` or `bind-tools` - DNS testing (dig, nslookup)

---

## Prerequisites

### Check Kernel Module

**Verify qmi_wwan driver:**

```bash
lsmod | grep qmi_wwan
```

**Expected output:**
```
qmi_wwan               28672  0
cdc_wdm                20480  1 qmi_wwan
```

**If not loaded, load manually:**

```bash
sudo modprobe qmi_wwan
```

**Make permanent (if needed):**

```bash
echo "qmi_wwan" | sudo tee -a /etc/modules
```

### Verify USB Tree

**Check USB device tree:**

```bash
lsusb -t
```

**Look for qmi_wwan driver:**
```
/:  Bus 01.Port 1: Dev 1, Class=root_hub, Driver=xhci_hcd/4p, 480M
    |__ Port 1: Dev 5, If 0, Class=Vendor Specific Class, Driver=option, 480M
    |__ Port 1: Dev 5, If 1, Class=Vendor Specific Class, Driver=option, 480M
    |__ Port 1: Dev 5, If 2, Class=Vendor Specific Class, Driver=option, 480M
    |__ Port 1: Dev 5, If 3, Class=Vendor Specific Class, Driver=option, 480M
    |__ Port 1: Dev 5, If 4, Class=Vendor Specific Class, Driver=qmi_wwan, 480M
```

**Driver=qmi_wwan indicates proper detection**

---

## Installation

### Debian/Ubuntu/Trisquel

```bash
# Update package lists
sudo apt update

# Install required packages
sudo apt install libqmi-utils udhcpc

# Optional: Install additional tools
sudo apt install ppp net-tools dnsutils
```

### Fedora/Rocky/Alma

```bash
# Install QMI tools
sudo dnf install libqmi libqmi-utils

# Install DHCP client (may need udhcp from repositories or use dhclient)
sudo dnf install dhclient

# Optional tools
sudo dnf install ppp net-tools bind-utils
```

### Arch/EndeavorOS/Manjaro

```bash
# Install QMI tools
sudo pacman -S libqmi

# Install DHCP client
sudo pacman -S udhcp  # or dhclient

# Optional tools
sudo pacman -S ppp net-tools bind-tools
```

### Verify Installation

```bash
# Check qmicli version
qmicli --version

# Check udhcpc
which udhcpc

# Test QMI access (if modem connected)
sudo qmicli --device=/dev/cdc-wdm0 --device-open-proxy --dms-get-manufacturer
```

---

## Understanding QMI Protocol

### What is QMI

**QMI (Qualcomm MSM Interface):**
- Control protocol for Qualcomm-based cellular modems
- More powerful and feature-rich than AT commands
- Standard for modern LTE/5G USB modems
- Provides fine-grained control over modem functions

### QMI vs Other Protocols

| Protocol | Use Case | Complexity | Features |
|----------|----------|------------|----------|
| QMI | Modern LTE/5G modems | Medium | Extensive |
| AT Commands | Legacy modems, basic control | Low | Basic |
| MBIM | Windows-centric modems | Medium | Windows-focused |
| NCM | Network Control Model | Low | Limited |

### QMI Device Files

**Common QMI control devices:**
- `/dev/cdc-wdm0` - First QMI modem
- `/dev/cdc-wdm1` - Second QMI modem (if multiple)

**Network interfaces:**
- `wwan0` - Traditional naming
- `wwp0s20u1i4` - Predictable naming (systemd)

---

## Step-by-Step Configuration

### Step 1: Stop ModemManager (If Running)

**Why:** ModemManager may interfere with manual QMI control.

```bash
# Check if ModemManager is running
systemctl status ModemManager

# Stop ModemManager
sudo systemctl stop ModemManager

# Optional: Disable permanently
sudo systemctl disable ModemManager
```

**Alternative:** Configure ModemManager to ignore your modem (see Advanced Configuration).

### Step 2: Identify QMI Device

**Find QMI control device:**

```bash
ls -l /dev/cdc-wdm*
```

**Expected output:**
```
crw-rw---- 1 root root 180, 0 Oct 15 14:30 /dev/cdc-wdm0
```

**If no device found:**
- Check modem is plugged in
- Verify qmi_wwan driver loaded
- Check `dmesg` for errors

### Step 3: Get Network Interface Name

```bash
sudo qmicli --device=/dev/cdc-wdm0 --device-open-proxy --get-wwan-iface
```

**Expected output:**
```
wwan0
```

**Save this interface name:**
```bash
IFACE="wwan0"
```

### Step 4: Configure Raw IP Mode

**What is raw IP mode?**
- More efficient packet handling
- Required for some modems
- Recommended for all QMI connections

**Check current mode:**

```bash
cat /sys/class/net/$IFACE/qmi/raw_ip
```

**If output is `N`, enable raw IP mode:**

```bash
# Bring interface down
sudo ip link set dev $IFACE down

# Enable raw IP mode
sudo sh -c "echo Y > /sys/class/net/$IFACE/qmi/raw_ip"

# Bring interface up
sudo ip link set dev $IFACE up
```

**Verify:**
```bash
cat /sys/class/net/$IFACE/qmi/raw_ip
# Should show: Y
```

### Step 5: Verify Interface is Up

```bash
ip link show $IFACE
```

**Expected output:**
```
5: wwan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN mode DEFAULT group default qlen 1000
```

**Look for:** `state UP` or `state UNKNOWN` (UNKNOWN is normal for wwan)

---

## Network Connection Procedure

### Start Network Connection

**Basic command:**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="ip-type=4,apn=YOUR_APN_HERE" \
    --client-no-release-cid
```

**Replace `YOUR_APN_HERE` with your carrier's APN.**

**Example (AT&T):**
```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="ip-type=4,apn=broadband" \
    --client-no-release-cid
```

**Example (T-Mobile):**
```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="ip-type=4,apn=fast.t-mobile.com" \
    --client-no-release-cid
```

**Example (Verizon):**
```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="ip-type=4,apn=vzwinternet" \
    --client-no-release-cid
```

### Understanding the Command

**Parameters explained:**

- `--device=/dev/cdc-wdm0` - QMI control device
- `--device-open-proxy` - Use qmi-proxy for device access
- `--wds-start-network` - Start data connection
  - `ip-type=4` - IPv4 (use `6` for IPv6, `4-6` for dual-stack)
  - `apn=...` - Access Point Name (carrier-specific)
- `--client-no-release-cid` - Keep connection active after command exits

### Expected Output

```
[/dev/cdc-wdm0] Network started
	Packet data handle: '1234567890'
[/dev/cdc-wdm0] Client ID not released:
	Service: 'wds'
		CID: '42'
```

**Important:** Save the **Packet data handle** and **CID** for stopping the connection later.

### Obtain IP Address via DHCP

**Using udhcpc:**

```bash
sudo udhcpc -q -f -n -i $IFACE
```

**Parameters:**
- `-q` - Quiet mode
- `-f` - Foreground mode
- `-n` - Exit after obtaining lease (no-daemon)
- `-i $IFACE` - Interface name

**Expected output:**
```
udhcpc: started, v1.30.1
udhcpc: sending discover
udhcpc: sending select for 10.123.45.67
udhcpc: lease of 10.123.45.67 obtained, lease time 7200
```

**Alternative - Using dhclient:**

```bash
sudo dhclient $IFACE
```

### Verify IP Assignment

```bash
ip addr show $IFACE
```

**Expected output:**
```
5: wwan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UNKNOWN group default qlen 1000
    link/ether 02:50:f3:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 10.123.45.67/30 brd 10.123.45.67 scope global wwan0
       valid_lft forever preferred_lft forever
```

**Look for:** `inet` line with IP address

---

## Testing and Verification

### Test 1: Check Default Route

```bash
ip route show
```

**Expected:** Default route via wwan0

```
default via 10.123.45.65 dev wwan0
10.123.45.64/30 dev wwan0 proto kernel scope link src 10.123.45.67
```

### Test 2: Ping Gateway

```bash
ping -c 5 -I $IFACE 10.123.45.65
```

**Replace gateway IP with your actual gateway from `ip route`**

**Expected output:**
```
PING 10.123.45.65 (10.123.45.65) from 10.123.45.67 wwan0: 56(84) bytes of data.
64 bytes from 10.123.45.65: icmp_seq=1 ttl=64 time=35.2 ms
...
--- 10.123.45.65 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4005ms
```

**Look for:** `0% packet loss`

### Test 3: Ping Public DNS

```bash
ping -c 5 8.8.8.8
```

**Expected:** Successful pings to Google DNS

```
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=118 time=42.3 ms
...
--- 8.8.8.8 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4006ms
```

### Test 4: DNS Resolution

```bash
nslookup google.com
```

**Or using dig:**
```bash
dig google.com
```

**Expected:** Successful DNS lookup

### Test 5: HTTP Request

```bash
curl -I http://example.com
```

**Expected:** HTTP response headers

```
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
...
```

### Complete Test Sequence

```bash
#!/bin/bash
# Test network connectivity

IFACE="wwan0"

echo "=== Testing Gateway ==="
GATEWAY=$(ip route | grep default | grep $IFACE | awk '{print $3}')
ping -c 3 -I $IFACE $GATEWAY

echo ""
echo "=== Testing Public DNS ==="
ping -c 3 8.8.8.8

echo ""
echo "=== Testing DNS Resolution ==="
nslookup google.com

echo ""
echo "=== Testing HTTP ==="
curl -I http://example.com

echo ""
echo "=== All tests completed ==="
```

---

## Advanced Configuration

### IPv6 Support

**Enable IPv6:**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="ip-type=6,apn=YOUR_APN" \
    --client-no-release-cid
```

**Dual-stack (IPv4 + IPv6):**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="ip-type=4-6,apn=YOUR_APN" \
    --client-no-release-cid
```

### Authentication

**For APNs requiring username/password:**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="ip-type=4,apn=YOUR_APN,username=USER,password=PASS" \
    --client-no-release-cid
```

### Custom DNS

**Override automatic DNS:**

```bash
# After obtaining IP, manually set DNS
sudo sh -c "cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF"
```

**Or use systemd-resolved:**

```bash
sudo systemd-resolve --interface=$IFACE --set-dns=8.8.8.8 --set-dns=8.8.4.4
```

### Stopping the Connection

**Use saved Packet Data Handle (PDH) and CID:**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-stop-network="1234567890" \
    --client-cid="42"
```

**Replace:**
- `1234567890` with your Packet data handle
- `42` with your CID

---

## Automation and Scripting

### Complete Connection Script

```bash
#!/bin/bash
# connect-modem.sh - Establish QMI connection

set -e

# Configuration
QMI_DEVICE="/dev/cdc-wdm0"
APN="broadband"  # Change to your APN
IP_TYPE="4"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (sudo)"
fi

info "Stopping ModemManager..."
systemctl stop ModemManager 2>/dev/null || true

info "Getting interface name..."
IFACE=$(qmicli --device=$QMI_DEVICE --device-open-proxy --get-wwan-iface)
info "Interface: $IFACE"

info "Configuring raw IP mode..."
ip link set dev $IFACE down
echo Y > /sys/class/net/$IFACE/qmi/raw_ip
ip link set dev $IFACE up

info "Starting network connection..."
NETWORK_OUTPUT=$(qmicli \
    --device=$QMI_DEVICE \
    --device-open-proxy \
    --wds-start-network="ip-type=$IP_TYPE,apn=$APN" \
    --client-no-release-cid)

echo "$NETWORK_OUTPUT"

PDH=$(echo "$NETWORK_OUTPUT" | grep "Packet data handle" | awk '{print $4}')
CID=$(echo "$NETWORK_OUTPUT" | grep "CID:" | awk '{print $2}' | tr -d "'")

info "PDH: $PDH, CID: $CID"

# Save for disconnect script
cat > /tmp/qmi_connection.conf << EOF
PDH=$PDH
CID=$CID
IFACE=$IFACE
QMI_DEVICE=$QMI_DEVICE
EOF

info "Obtaining IP address..."
udhcpc -q -f -n -i $IFACE

info "Testing connectivity..."
if ping -c 3 8.8.8.8 > /dev/null 2>&1; then
    info "Connection successful!"
    ip addr show $IFACE | grep inet
else
    error "Connection failed - no internet"
fi

info "Connection established. Run 'sudo ./disconnect-modem.sh' to disconnect."
```

### Disconnect Script

```bash
#!/bin/bash
# disconnect-modem.sh - Stop QMI connection

set -e

# Load saved connection info
if [ ! -f /tmp/qmi_connection.conf ]; then
    echo "No active connection found"
    exit 1
fi

source /tmp/qmi_connection.conf

echo "Stopping network connection..."
qmicli \
    --device=$QMI_DEVICE \
    --device-open-proxy \
    --wds-stop-network="$PDH" \
    --client-cid="$CID"

echo "Bringing down interface..."
ip link set dev $IFACE down

echo "Restarting ModemManager..."
systemctl start ModemManager

rm /tmp/qmi_connection.conf

echo "Disconnected successfully"
```

### Make Scripts Executable

```bash
chmod +x connect-modem.sh disconnect-modem.sh
```

### Usage

```bash
# Connect
sudo ./connect-modem.sh

# Disconnect
sudo ./disconnect-modem.sh
```

---

## Troubleshooting

### Problem: No /dev/cdc-wdm0 Device

**Symptoms:**
```bash
ls /dev/cdc-wdm*
# No such file or directory
```

**Solutions:**

1. **Check modem is plugged in:**
   ```bash
   lsusb
   ```

2. **Load qmi_wwan driver:**
   ```bash
   sudo modprobe qmi_wwan
   ```

3. **Check dmesg:**
   ```bash
   dmesg | grep -i qmi
   ```

4. **Try different USB port**

### Problem: Interface Not Found

**Symptoms:**
```bash
sudo qmicli -d /dev/cdc-wdm0 --get-wwan-iface
# error: couldn't find WWAN iface
```

**Solutions:**

1. **Check interface exists:**
   ```bash
   ip link show
   # Look for wwan0 or similar
   ```

2. **Manual interface identification:**
   ```bash
   ls /sys/class/net/
   # Look for wwan or usb interfaces
   ```

3. **Use found interface directly**

### Problem: Network Start Fails

**Symptoms:**
```
error: couldn't start network
```

**Solutions:**

1. **Verify APN is correct:**
   - Check carrier documentation
   - Try without APN: `apn=''`

2. **Check SIM card:**
   ```bash
   sudo qmicli -d /dev/cdc-wdm0 --uim-get-card-status
   ```

3. **Check signal:**
   ```bash
   sudo qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength
   ```

4. **Check registration:**
   ```bash
   sudo qmicli -d /dev/cdc-wdm0 --nas-get-serving-system
   ```

### Problem: No IP Address Obtained

**Symptoms:**
```bash
udhcpc -i wwan0
# No lease obtained
```

**Solutions:**

1. **Check interface is up:**
   ```bash
   sudo ip link set wwan0 up
   ```

2. **Try dhclient instead:**
   ```bash
   sudo dhclient wwan0
   ```

3. **Manual IP configuration:**
   ```bash
   sudo qmicli -d /dev/cdc-wdm0 --wds-get-current-settings
   # Use output to manually configure IP
   ```

### Problem: ModemManager Conflicts

**Symptoms:**
- Connection drops
- Device busy errors

**Solution:**

**Stop ModemManager:**
```bash
sudo systemctl stop ModemManager
```

**Or blacklist modem in ModemManager:**

Create `/etc/udev/rules.d/99-modem-blacklist.rules`:
```
ATTRS{idVendor}=="2c7c", ATTRS{idProduct}=="0125", ENV{ID_MM_DEVICE_IGNORE}="1"
```

Reload:
```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## Using with Different Carriers

### AT&T

```bash
APN="broadband"
# Or: "phone" for phone plans
```

### T-Mobile

```bash
APN="fast.t-mobile.com"
# Or: "epc.tmobile.com" (older)
```

### Verizon

```bash
APN="vzwinternet"
```

### Sprint (now T-Mobile)

```bash
APN="sprint"
```

### Generic/MVNO

**Check with your carrier for correct APN**

**Common MVNOs:**
- Mint Mobile: `wholesale`
- Google Fi: `h2g2`
- Ting: `wholesale`

---

## Persistent Configuration

### systemd Service

**Create `/etc/systemd/system/qmi-modem.service`:**

```ini
[Unit]
Description=QMI Modem Connection
After=network.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/connect-modem.sh
ExecStop=/usr/local/bin/disconnect-modem.sh

[Install]
WantedBy=multi-user.target
```

**Install scripts:**
```bash
sudo cp connect-modem.sh /usr/local/bin/
sudo cp disconnect-modem.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/*.sh
```

**Enable service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable qmi-modem.service
sudo systemctl start qmi-modem.service
```

### NetworkManager Integration

**Create connection profile:**
```bash
nmcli connection add \
    type gsm \
    ifname wwan0 \
    con-name "Mobile Broadband" \
    apn "YOUR_APN"

# Activate
nmcli connection up "Mobile Broadband"
```

---

## Best Practices

### 1. Always Check Raw IP Mode

```bash
# Verify before connecting
cat /sys/class/net/wwan0/qmi/raw_ip
```

### 2. Save Connection Details

```bash
# Save PDH and CID for clean disconnection
echo "$NETWORK_OUTPUT" > /tmp/qmi_last_connection.log
```

### 3. Monitor Signal Strength

```bash
# Check periodically
sudo qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength
```

### 4. Use Correct APN

- Verify with carrier
- Different plans may use different APNs
- Wrong APN may work but be throttled

### 5. Clean Disconnection

- Always stop network properly
- Release CID
- Prevents orphaned connections

---

## References

### Official Documentation

**libqmi:**
- Project: https://gitlab.freedesktop.org/mobile-broadband/libqmi
- Documentation: https://www.freedesktop.org/software/libqmi/

**ThinkPenguin:**
- Original Guide: https://www.thinkpenguin.com/gnu-linux/using-your-usb-4g-lte-modem-terminal-tpe-usb4g2us

### Community Resources

- **ModemManager:** https://www.freedesktop.org/wiki/Software/ModemManager/
- **Quectel Modems:** https://www.quectel.com/
- **Linux Kernel Documentation:** https://www.kernel.org/doc/html/latest/

---

## Summary

USB 4G LTE modem setup via QMI protocol on GNU/Linux:

**Quick Setup:**
```bash
# 1. Install tools
sudo apt install libqmi-utils udhcpc

# 2. Stop ModemManager
sudo systemctl stop ModemManager

# 3. Configure raw IP
sudo ip link set wwan0 down
sudo sh -c "echo Y > /sys/class/net/wwan0/qmi/raw_ip"
sudo ip link set wwan0 up

# 4. Start network
sudo qmicli -d /dev/cdc-wdm0 --device-open-proxy \
    --wds-start-network="ip-type=4,apn=YOUR_APN" \
    --client-no-release-cid

# 5. Get IP
sudo udhcpc -q -f -n -i wwan0

# 6. Test
ping -c 5 8.8.8.8
```

**Key Points:**
- QMI protocol for modern LTE modems
- Raw IP mode recommended
- Correct APN critical for connection
- Stop ModemManager to prevent conflicts
- Save PDH and CID for clean disconnection

This method provides direct, scriptable control over USB LTE modems without requiring graphical network managers.

---

*This guide is based on ThinkPenguin documentation and libqmi project specifications.*
