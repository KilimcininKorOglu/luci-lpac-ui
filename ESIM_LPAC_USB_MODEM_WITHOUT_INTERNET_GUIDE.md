# eSIM Profile Download via USB Modem Without External Internet Guide

## Table of Contents
1. [Overview](#overview)
2. [Challenge and Solution](#challenge-and-solution)
3. [Prerequisites](#prerequisites)
4. [Required Tools and Packages](#required-tools-and-packages)
5. [Understanding QMI Protocol](#understanding-qmi-protocol)
6. [Complete Procedure](#complete-procedure)
7. [Step-by-Step Configuration](#step-by-step-configuration)
8. [Network Testing and Verification](#network-testing-and-verification)
9. [eSIM Profile Download](#esim-profile-download)
10. [Troubleshooting](#troubleshooting)
11. [Alternative Methods](#alternative-methods)
12. [Automation Script](#automation-script)
13. [Best Practices](#best-practices)
14. [References](#references)

---

## Overview

This guide explains how to download eSIM profiles using **only** a USB modem for internet connectivity, without requiring an external WiFi or Ethernet connection. This is particularly useful for:

- Systems with only cellular connectivity
- Remote deployments
- Embedded systems without additional network interfaces
- Bootstrapping eSIM profiles using an existing profile

**Key Requirement:** You must have at least **one working eSIM profile already installed** to establish the initial network connection needed to download additional profiles.

---

## Challenge and Solution

### The Problem

**Standard lpac usage requires internet:**
- Download eSIM profiles from SM-DP+ servers
- Requires active internet connection
- Typically uses WiFi/Ethernet

**On modem-only systems:**
- ModemManager manages the modem
- Direct lpac access conflicts with ModemManager
- Stopping ModemManager kills internet connection
- Catch-22: Need internet to download profiles, but can't access modem and maintain internet simultaneously

### The Solution

**Manual modem control using QMI:**
1. Stop ModemManager
2. Manually establish cellular connection using qmicli
3. Configure network interface manually
4. Download eSIM profile via lpac
5. Restart ModemManager

**Process Flow:**
```
Existing eSIM → Manual QMI Connection → Internet Access → lpac Download → New eSIM
```

---

## Prerequisites

### Hardware Requirements

**USB Modem:**
- QMI-capable modem (most modern LTE/5G USB modems)
- Examples: Quectel EC25, EM12, RM500Q
- At least one working eSIM already installed

**System:**
- Linux-based OS (tested on systemd-based distributions)
- USB port
- Root/sudo access

### Software Requirements

**Installed packages:**
- `qmi-utils` (qmicli command)
- `libqmi-glib`
- `iproute2` (ip command)
- `dnsutils` or `bind-tools` (dig command)
- `curl`
- `lpac` (built with AT APDU support)

### Information Needed

**Before starting, know:**
- Your carrier's APN (Access Point Name)
- Device paths (`/dev/cdc-wdm0`, `/dev/ttyUSB2`)
- Network interface name (will determine during process)

**Example APNs:**
- T-Mobile: `fast.t-mobile.com`
- AT&T: `broadband`
- Verizon: `vzwinternet`

---

## Required Tools and Packages

### Installation

#### Debian/Ubuntu

```bash
sudo apt-get update
sudo apt-get install libqmi-utils libqmi-glib5 iproute2 dnsutils curl
```

#### Fedora/Rocky/Alma

```bash
sudo dnf install libqmi libqmi-utils iproute bind-utils curl
```

#### Arch/EndeavorOS/Manjaro

```bash
sudo pacman -S libqmi iproute2 bind-tools curl
```

### Verify Installation

```bash
# Check qmicli
qmicli --version

# Check ip command
ip --version

# Check dig
dig -v

# Check curl
curl --version
```

---

## Understanding QMI Protocol

### What is QMI

**QMI (Qualcomm MSM Interface):**
- Protocol for controlling Qualcomm-based cellular modems
- Alternative to AT commands
- More powerful and feature-rich
- Standard on modern LTE/5G USB modems

**QMI vs AT Commands:**

| Feature | QMI | AT Commands |
|---------|-----|-------------|
| Complexity | Higher | Lower |
| Features | Extensive | Basic |
| Control | Fine-grained | Limited |
| Usage | Data connections | Legacy compatibility |

### QMI Device Files

**Common QMI devices:**
- `/dev/cdc-wdm0` - First QMI device (most common)
- `/dev/cdc-wdm1` - Second QMI device (if multiple modems)

**Network interfaces:**
- `wwan0` - Traditional name
- `wwp0s20f0u1` - Predictable network interface naming (systemd)
- Format varies by system

---

## Complete Procedure

### High-Level Overview

```
1. Stop ModemManager
2. Identify QMI interface
3. Configure raw IP mode
4. Bring up network interface
5. Start network connection with QMI
6. Configure IP, gateway, DNS
7. Test connectivity
8. Download eSIM profile with lpac
9. Restart ModemManager
```

---

## Step-by-Step Configuration

### Step 1: Stop ModemManager

```bash
# Stop ModemManager service
sudo systemctl stop ModemManager

# Verify it's stopped
systemctl status ModemManager
```

**Why:** ModemManager controls the modem. We need exclusive access.

### Step 2: Identify QMI Network Interface

```bash
# Query the modem for network interface name
sudo qmicli --device=/dev/cdc-wdm0 --device-open-proxy --get-wwan-iface
```

**Example output:**
```
wwan0
```

or

```
wwp0s20f0u1
```

**Save this interface name:**
```bash
IFACE="wwan0"  # Replace with your actual interface
```

### Step 3: Configure Raw IP Mode

**Check current mode:**

```bash
cat /sys/class/net/$IFACE/qmi/raw_ip
```

**Expected output:** `Y`

**If output is `N`, set to raw IP mode:**

```bash
sudo sh -c "echo Y > /sys/class/net/$IFACE/qmi/raw_ip"
```

**Verify:**
```bash
cat /sys/class/net/$IFACE/qmi/raw_ip
# Should now show: Y
```

**Why raw IP mode?**
- More efficient
- Direct IP packet handling
- Required for some modems

### Step 4: Bring Up Network Interface

```bash
# Bring interface up
sudo ip link set $IFACE up

# Verify interface is up
ip link show $IFACE

# Should show: ... state UP ...
```

### Step 5: Start Network Connection via QMI

**Start network with your APN:**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="apn='YOUR_APN_HERE',ip-type=4" \
    --client-no-release-cid
```

**Replace `YOUR_APN_HERE` with your carrier's APN.**

**Example (T-Mobile):**
```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-start-network="apn='fast.t-mobile.com',ip-type=4" \
    --client-no-release-cid
```

**Example output:**
```
[/dev/cdc-wdm0] Network started
    Packet data handle: 12345678
[/dev/cdc-wdm0] Client ID not released:
    Service: 'wds'
        CID: '20'
```

**Save the Packet data handle and CID for later!**

**Parameters explained:**
- `apn='...'` - Your carrier's Access Point Name
- `ip-type=4` - IPv4 only (use 6 for IPv6, 4-6 for dual-stack)
- `--client-no-release-cid` - Keep connection active after command exits

### Step 6: Configure IP Settings

**Query current settings from modem:**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-get-current-settings
```

**Example output:**
```
[/dev/cdc-wdm0] Current settings retrieved:
           IP Family: IPv4
        IPv4 address: 10.123.45.67
    IPv4 subnet mask: 255.255.255.252
IPv4 gateway address: 10.123.45.65
    IPv4 primary DNS: 8.8.8.8
  IPv4 secondary DNS: 8.8.4.4
                 MTU: 1500
```

**Extract values (adjust to your output):**
```bash
IP_ADDR="10.123.45.67"
SUBNET_MASK="255.255.255.252"
GATEWAY="10.123.45.65"
DNS1="8.8.8.8"
DNS2="8.8.4.4"
MTU="1500"
```

**Convert subnet mask to CIDR (if needed):**
- 255.255.255.252 = /30
- 255.255.255.0 = /24
- Use online converter if unsure

**Configure IP address on interface:**

```bash
sudo ip addr add $IP_ADDR/30 dev $IFACE
```

**Add default route via gateway:**

```bash
sudo ip route add default via $GATEWAY dev $IFACE
```

**Configure DNS (method 1 - resolv.conf):**

```bash
# Backup existing resolv.conf
sudo cp /etc/resolv.conf /etc/resolv.conf.backup

# Set DNS servers
sudo sh -c "cat > /etc/resolv.conf << EOF
nameserver $DNS1
nameserver $DNS2
EOF"
```

**Configure DNS (method 2 - systemd-resolved):**

```bash
sudo systemd-resolve --interface=$IFACE --set-dns=$DNS1 --set-dns=$DNS2
```

**Set MTU:**

```bash
sudo ip link set $IFACE mtu $MTU
```

---

## Network Testing and Verification

### Test 1: Ping Gateway

```bash
ping -c 4 -I $IFACE $GATEWAY
```

**Expected:** Successful ping responses

**Example output:**
```
PING 10.123.45.65 (10.123.45.65) from 10.123.45.67 wwan0: 56(84) bytes of data.
64 bytes from 10.123.45.65: icmp_seq=1 ttl=64 time=35.2 ms
64 bytes from 10.123.45.65: icmp_seq=2 ttl=64 time=32.8 ms
...
```

### Test 2: Ping Public IP

```bash
ping -c 4 -I $IFACE 8.8.8.8
```

**Expected:** Successful ping to Google DNS

### Test 3: DNS Resolution

```bash
dig @$DNS1 wiki.soprani.ca
```

**Expected:** Successful DNS query with answer

**Example output:**
```
; <<>> DiG 9.16.1 <<>> @8.8.8.8 wiki.soprani.ca
...
;; ANSWER SECTION:
wiki.soprani.ca.    300    IN    A    123.45.67.89
```

### Test 4: HTTP Request

```bash
curl -I http://example.com
```

**Expected:** HTTP response headers

**Example output:**
```
HTTP/1.1 200 OK
Content-Type: text/html; charset=UTF-8
...
```

### Test 5: HTTPS Request

```bash
curl -I https://example.com
```

**Expected:** HTTPS response (tests TLS/SSL)

---

## eSIM Profile Download

### Prepare lpac Environment

**Set environment variables:**

```bash
export LPAC_APDU=at
export AT_DEVICE=/dev/ttyUSB2
```

**Verify lpac can access modem:**

```bash
~/esim-tools/lpac/output/lpac chip info
```

**Expected:** eUICC chip information in JSON format

### Download eSIM Profile

**Basic download command:**

```bash
~/esim-tools/lpac/output/lpac profile download \
    -s "smdp.io" \
    -m "ACTIVATION-CODE-HERE"
```

**Replace:**
- `smdp.io` - SM-DP+ server address (from QR code or activation email)
- `ACTIVATION-CODE-HERE` - Your activation/matching code

**Example:**

```bash
~/esim-tools/lpac/output/lpac profile download \
    -s "smdp.example.com" \
    -m "K2-GH4JFI-D9JI"
```

**With confirmation code (if required):**

```bash
~/esim-tools/lpac/output/lpac profile download \
    -s "smdp.example.com" \
    -m "ACTIVATION-CODE" \
    -c "CONFIRMATION-CODE"
```

**Monitor download progress:**

The download process will:
1. Connect to SM-DP+ server via internet
2. Authenticate with activation code
3. Download encrypted profile
4. Install on eUICC
5. Display success message

**Expected output:**

```
Downloading profile...
Profile downloaded successfully
ICCID: 8901234567890123456
```

### Verify New Profile

**List all profiles:**

```bash
~/esim-tools/lpac/output/lpac profile list | jq
```

**Should show newly downloaded profile in list**

---

## Post-Download Cleanup

### Step 1: Stop Network Connection

**Find packet data handle and CID from earlier:**
- Packet data handle: 12345678
- CID: 20

**Stop network:**

```bash
sudo qmicli \
    --device=/dev/cdc-wdm0 \
    --device-open-proxy \
    --wds-stop-network="12345678" \
    --client-cid="20"
```

**Replace `12345678` with your actual packet data handle**

**Expected output:**
```
[/dev/cdc-wdm0] Network stopped
```

### Step 2: Bring Down Interface

```bash
sudo ip link set $IFACE down
```

### Step 3: Restore DNS (if modified)

```bash
sudo mv /etc/resolv.conf.backup /etc/resolv.conf
```

### Step 4: Restart ModemManager

```bash
sudo systemctl start ModemManager
```

**Verify it's running:**
```bash
systemctl status ModemManager
```

### Step 5: Enable New Profile (Optional)

**Via ModemManager (after restart):**

```bash
# Let ModemManager detect new profile
mmcli -L

# Enable new profile if desired
# (depends on your ModemManager/NetworkManager configuration)
```

**Or via lpac (before restarting ModemManager):**

```bash
~/esim-tools/lpac/output/lpac profile enable -i "NEW_ICCID"
```

---

## Troubleshooting

### Problem: Cannot Get WWAN Interface

**Symptom:**
```bash
sudo qmicli --device=/dev/cdc-wdm0 --get-wwan-iface
error: couldn't find WWAN iface
```

**Solutions:**

1. **Check device path:**
   ```bash
   ls -l /dev/cdc-wdm*
   # Try /dev/cdc-wdm1 if wdm0 doesn't exist
   ```

2. **Verify modem detected:**
   ```bash
   lsusb | grep -i quectel
   dmesg | grep -i qmi
   ```

3. **Check kernel modules:**
   ```bash
   lsmod | grep qmi
   # Should show: qmi_wwan, cdc_wdm
   ```

### Problem: Network Start Fails

**Symptom:**
```
error: couldn't start network
```

**Solutions:**

1. **Verify APN is correct:**
   - Check with carrier documentation
   - Try without APN: `apn=''`

2. **Check SIM registration:**
   ```bash
   sudo qmicli -d /dev/cdc-wdm0 --nas-get-serving-system
   ```

3. **Check signal strength:**
   ```bash
   sudo qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength
   ```

4. **Try different IP type:**
   ```bash
   # IPv6
   --wds-start-network="apn='YOUR_APN',ip-type=6"

   # Dual stack
   --wds-start-network="apn='YOUR_APN',ip-type=4-6"
   ```

### Problem: No IP Address Assigned

**Symptom:**
```bash
ip addr show $IFACE
# Shows no IP address
```

**Solutions:**

1. **Check qmicli current settings again:**
   ```bash
   sudo qmicli -d /dev/cdc-wdm0 --wds-get-current-settings
   ```

2. **Manually assign from modem output:**
   ```bash
   sudo ip addr add <IP>/<PREFIX> dev $IFACE
   ```

3. **Verify interface is up:**
   ```bash
   sudo ip link set $IFACE up
   ```

### Problem: DNS Not Working

**Symptom:**
```bash
ping 8.8.8.8  # Works
ping google.com  # Fails
```

**Solutions:**

1. **Check resolv.conf:**
   ```bash
   cat /etc/resolv.conf
   # Should have valid nameserver entries
   ```

2. **Manually set DNS:**
   ```bash
   sudo sh -c "echo 'nameserver 8.8.8.8' > /etc/resolv.conf"
   sudo sh -c "echo 'nameserver 8.8.4.4' >> /etc/resolv.conf"
   ```

3. **Test with explicit DNS:**
   ```bash
   dig @8.8.8.8 google.com
   ```

### Problem: Gateway Not Reachable

**Symptom:**
```bash
ping -I $IFACE $GATEWAY
# 100% packet loss
```

**Solutions:**

1. **Check raw IP mode:**
   ```bash
   cat /sys/class/net/$IFACE/qmi/raw_ip
   # Must be Y
   ```

2. **Re-establish connection:**
   - Stop network
   - Start network again
   - Reconfigure IP

3. **Try without specifying interface:**
   ```bash
   ping $GATEWAY
   ```

### Problem: lpac Cannot Access Modem

**Symptom:**
```
lpac: cannot access /dev/ttyUSB2
```

**Solutions:**

1. **Check device exists:**
   ```bash
   ls -l /dev/ttyUSB*
   ```

2. **Use correct AT port:**
   ```bash
   export AT_DEVICE=/dev/ttyUSB3  # Try different port
   ```

3. **Check permissions:**
   ```bash
   sudo chmod 666 /dev/ttyUSB2
   ```

---

## Alternative Methods

### Using AT Commands Instead of QMI

**If qmicli not available, use AT commands:**

```bash
# Via screen or minicom
sudo screen /dev/ttyUSB2 115200

# AT commands
AT+CGDCONT=1,"IP","YOUR_APN"
AT+CGACT=1,1
ATD*99#

# Then configure PPP
sudo pppd /dev/ttyUSB3 115200 noauth defaultroute usepeerdns
```

### Using ModemManager CLI

**Keep ModemManager running, use mmcli:**

```bash
# List modems
mmcli -L

# Create connection
mmcli -m 0 --simple-connect="apn=YOUR_APN"

# Then use lpac (may conflict, experimental)
```

---

## Automation Script

### Complete Automated Script

```bash
#!/bin/bash
# esim-download-modem-only.sh
# Download eSIM profile using only USB modem for internet

set -e

# Configuration
QMI_DEVICE="/dev/cdc-wdm0"
AT_DEVICE="/dev/ttyUSB2"
APN="fast.t-mobile.com"  # Change to your APN
SMDP_SERVER="smdp.io"
ACTIVATION_CODE=""  # Set or pass as argument

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (sudo)"
fi

# Check activation code
if [ -z "$ACTIVATION_CODE" ]; then
    if [ -z "$1" ]; then
        error "Usage: $0 <ACTIVATION_CODE>"
    fi
    ACTIVATION_CODE="$1"
fi

info "Stopping ModemManager..."
systemctl stop ModemManager

info "Identifying network interface..."
IFACE=$(qmicli --device=$QMI_DEVICE --device-open-proxy --get-wwan-iface)
info "Interface: $IFACE"

info "Setting raw IP mode..."
echo Y > /sys/class/net/$IFACE/qmi/raw_ip

info "Bringing up interface..."
ip link set $IFACE up

info "Starting network connection..."
NETWORK_OUTPUT=$(qmicli \
    --device=$QMI_DEVICE \
    --device-open-proxy \
    --wds-start-network="apn='$APN',ip-type=4" \
    --client-no-release-cid)

echo "$NETWORK_OUTPUT"

PDH=$(echo "$NETWORK_OUTPUT" | grep "Packet data handle" | awk '{print $4}')
CID=$(echo "$NETWORK_OUTPUT" | grep "CID:" | awk '{print $2}' | tr -d "'")

info "PDH: $PDH, CID: $CID"

info "Retrieving IP settings..."
SETTINGS=$(qmicli --device=$QMI_DEVICE --device-open-proxy --wds-get-current-settings)

IP_ADDR=$(echo "$SETTINGS" | grep "IPv4 address:" | awk '{print $3}')
GATEWAY=$(echo "$SETTINGS" | grep "IPv4 gateway" | awk '{print $4}')
DNS1=$(echo "$SETTINGS" | grep "IPv4 primary DNS:" | awk '{print $4}')
DNS2=$(echo "$SETTINGS" | grep "IPv4 secondary DNS:" | awk '{print $4}')

info "IP: $IP_ADDR, Gateway: $GATEWAY, DNS: $DNS1, $DNS2"

info "Configuring network..."
ip addr add $IP_ADDR/30 dev $IFACE
ip route add default via $GATEWAY dev $IFACE

# Backup and set DNS
cp /etc/resolv.conf /etc/resolv.conf.backup
cat > /etc/resolv.conf << EOF
nameserver $DNS1
nameserver $DNS2
EOF

info "Testing connectivity..."
if ! ping -c 2 -I $IFACE $GATEWAY > /dev/null 2>&1; then
    warn "Gateway ping failed, but continuing..."
fi

if ! ping -c 2 8.8.8.8 > /dev/null 2>&1; then
    error "Internet connectivity test failed"
fi

info "Internet connectivity verified"

info "Downloading eSIM profile..."
export LPAC_APDU=at
export AT_DEVICE=$AT_DEVICE

~/esim-tools/lpac/output/lpac profile download \
    -s "$SMDP_SERVER" \
    -m "$ACTIVATION_CODE"

info "Profile download complete!"

info "Listing profiles..."
~/esim-tools/lpac/output/lpac profile list | jq

info "Cleaning up..."
qmicli \
    --device=$QMI_DEVICE \
    --device-open-proxy \
    --wds-stop-network="$PDH" \
    --client-cid="$CID"

ip link set $IFACE down
mv /etc/resolv.conf.backup /etc/resolv.conf

info "Restarting ModemManager..."
systemctl start ModemManager

info "Done! New eSIM profile installed."
```

**Usage:**

```bash
chmod +x esim-download-modem-only.sh
sudo ./esim-download-modem-only.sh "ACTIVATION-CODE-HERE"
```

---

## Best Practices

### 1. Test First Profile Separately

```bash
# Ensure first eSIM works before downloading more
# Verify internet connectivity fully
```

### 2. Document Your Settings

```bash
# Save qmicli output to file
sudo qmicli -d /dev/cdc-wdm0 --wds-get-current-settings > ~/modem-settings.txt
```

### 3. Keep Backup Connectivity

- Have alternate eSIM ready
- Physical SIM as backup
- Know how to switch profiles

### 4. Automate Common Tasks

- Create scripts for repetitive operations
- Use environment variables for device paths
- Document APN for each carrier

### 5. Monitor Data Usage

```bash
# Check data usage before/after
sudo qmicli -d /dev/cdc-wdm0 --wds-get-packet-statistics
```

---

## References

### Official Documentation

**libqmi:**
- Repository: https://gitlab.freedesktop.org/mobile-broadband/libqmi
- Documentation: https://www.freedesktop.org/software/libqmi/

**lpac:**
- Repository: https://github.com/estkme-group/lpac

### Original Guide

**Soprani.ca Wiki:**
- URL: https://wiki.soprani.ca/eSIM%20Adapter/lpac%20via%20USB%20modem%20without%20internet

### Related Guides

- QMI protocol documentation
- Quectel modem AT command manuals
- NetworkManager QMI integration

---

## Summary

Downloading eSIM profiles using only USB modem connectivity:

**Requirements:**
- At least one working eSIM already installed
- QMI-capable USB modem
- Linux system with qmicli and lpac

**Key Steps:**
1. Stop ModemManager
2. Manually establish QMI connection with existing eSIM
3. Configure network (IP, gateway, DNS)
4. Test connectivity
5. Download new eSIM profile with lpac
6. Clean up and restart ModemManager

**Critical Points:**
- Must have working eSIM to bootstrap
- APN must be correct for carrier
- DNS configuration essential for profile download
- ModemManager must be stopped during process

**Complete Command Sequence:**

```bash
# Stop services
sudo systemctl stop ModemManager

# Get interface
IFACE=$(sudo qmicli -d /dev/cdc-wdm0 --get-wwan-iface)

# Configure
sudo sh -c "echo Y > /sys/class/net/$IFACE/qmi/raw_ip"
sudo ip link set $IFACE up

# Connect
sudo qmicli -d /dev/cdc-wdm0 --wds-start-network="apn='YOUR_APN'" --client-no-release-cid

# Configure network
sudo ip addr add IP/30 dev $IFACE
sudo ip route add default via GATEWAY dev $IFACE
echo "nameserver DNS" | sudo tee /etc/resolv.conf

# Download profile
export LPAC_APDU=at AT_DEVICE=/dev/ttyUSB2
lpac profile download -s "smdp" -m "CODE"

# Cleanup
# (stop network, restart ModemManager)
```

This advanced procedure enables eSIM management on systems with only cellular connectivity.

---

*This guide is based on the Soprani.ca wiki documentation and libqmi/lpac project specifications.*
